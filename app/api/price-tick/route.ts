import { createClient } from "@/lib/supabase/server"
import { NextResponse } from "next/server"

const DEFAULT_BASE_PRICE_KES = 13.0 // Starting price in KES
const VOLATILITY = 0.08 // ±8% for realistic intraday swings
const DAILY_TARGET_INCREASE_KES = 1.0 // Guaranteed +1 KES per 24 hours
const DRIFT_STRENGTH = 0.08 // 8% of gap per tick - stronger pull to target
const DAILY_RESET_HOUR = 15 // 3 PM UTC

export async function GET() {
  try {
    const supabase = await createClient()

    const { data: targetData, error: targetError } = await supabase.rpc("get_daily_price_target")

    if (targetError) {
      console.error("[v0] Error fetching price target:", targetError)
    }

    const dailyTarget = targetData?.[0]

    const { data: latestTick } = await supabase
      .from("coin_ticks")
      .select("*")
      .order("tick_timestamp", { ascending: false })
      .limit(1)
      .single()

    const now = new Date()
    const currentDate = now.toISOString().split("T")[0]

    let currentPriceKes = DEFAULT_BASE_PRICE_KES
    let openingPriceKes = DEFAULT_BASE_PRICE_KES
    let targetPriceKes = DEFAULT_BASE_PRICE_KES + DAILY_TARGET_INCREASE_KES
    let progressRatio = 0

    if (dailyTarget) {
      openingPriceKes = Number(dailyTarget.opening_price_kes)
      targetPriceKes = Number(dailyTarget.target_price_kes)
      progressRatio = Number(dailyTarget.current_progress)
    }

    if (latestTick) {
      currentPriceKes = Number(latestTick.price)

      // Check if this is a new day
      const latestDate = new Date(latestTick.tick_timestamp).toISOString().split("T")[0]
      const latestHour = new Date(latestTick.tick_timestamp).getHours()
      const currentHour = now.getHours()

      // If new day after 3 PM UTC, reset to new opening price
      if (latestDate !== currentDate && currentHour >= DAILY_RESET_HOUR) {
        currentPriceKes = targetPriceKes // Yesterday's target becomes today's opening
        openingPriceKes = targetPriceKes
        targetPriceKes = openingPriceKes + DAILY_TARGET_INCREASE_KES

        // Update closing price for yesterday
        await supabase.rpc("update_daily_closing_price")
      }
    }

    // The price should gradually increase from opening to target (opening + 1 KES)
    const expectedPriceKes = openingPriceKes + DAILY_TARGET_INCREASE_KES * progressRatio

    const priceDrift = (expectedPriceKes - currentPriceKes) * DRIFT_STRENGTH

    const volatilityFactor = (Math.random() - 0.5) * 2 * VOLATILITY // Range: -8% to +8%
    const volatilityChange = currentPriceKes * volatilityFactor

    const newPriceKes = currentPriceKes + priceDrift + volatilityChange

    const randomHigh = newPriceKes * (1 + VOLATILITY * Math.random())
    const randomLow = newPriceKes * (1 - VOLATILITY * Math.random())
    const average = (randomHigh + randomLow) / 2

    const finalPriceKes = Math.max(0.01, Number(newPriceKes.toFixed(4)))

    const { error: insertError } = await supabase.from("coin_ticks").insert({
      price: finalPriceKes,
      high: Number(randomHigh.toFixed(4)),
      low: Number(randomLow.toFixed(4)),
      average: Number(average.toFixed(4)),
      reference_date: currentDate,
      tick_timestamp: now.toISOString(),
    })

    if (insertError) {
      console.error("[v0] Error inserting price tick:", insertError)
      return NextResponse.json({ error: "Failed to store price" }, { status: 500 })
    }

    const changePercent = ((finalPriceKes - openingPriceKes) / openingPriceKes) * 100

    return NextResponse.json({
      price: finalPriceKes,
      high: Number(randomHigh.toFixed(4)),
      low: Number(randomLow.toFixed(4)),
      average: Number(average.toFixed(4)),
      changePercent,
      openingPrice: openingPriceKes,
      targetPrice: targetPriceKes,
      expectedPrice: Number(expectedPriceKes.toFixed(4)),
      progressRatio: Number((progressRatio * 100).toFixed(2)),
      timestamp: now.toISOString(),
    })
  } catch (error) {
    console.error("[v0] Price tick error:", error)
    return NextResponse.json({ error: "Internal server error" }, { status: 500 })
  }
}
