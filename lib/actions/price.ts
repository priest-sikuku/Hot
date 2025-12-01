"use server"

import { createClient } from "@/lib/supabase/server"

interface PriceTick {
  price: number
  high: number
  low: number
  average: number
  reference_date: string
}

interface PriceUpdate {
  success: boolean
  price?: number
  high?: number
  low?: number
  average?: number
  error?: string
}

export async function insertPriceTick(tick: PriceTick): Promise<PriceUpdate> {
  try {
    const supabase = await createClient()

    // Check if a tick with the same or newer timestamp exists
    const { data: latestTick } = await supabase
      .from("coin_ticks")
      .select("tick_timestamp")
      .order("tick_timestamp", { ascending: false })
      .limit(1)
      .single()

    // Only insert if this is a new tick (prevent duplicates)
    const now = new Date()
    if (latestTick && new Date(latestTick.tick_timestamp) >= now) {
      return {
        success: false,
        error: "Duplicate tick prevented",
      }
    }

    // Insert the new tick
    const { data, error } = await supabase
      .from("coin_ticks")
      .insert({
        price: tick.price,
        high: tick.high,
        low: tick.low,
        average: tick.average,
        reference_date: tick.reference_date,
        tick_timestamp: now.toISOString(),
      })
      .select()
      .single()

    if (error) {
      console.error("[v0] Error inserting price tick:", error)
      return { success: false, error: error.message }
    }

    return {
      success: true,
      price: data.price,
      high: data.high,
      low: data.low,
      average: data.average,
    }
  } catch (error) {
    console.error("[v0] Error in insertPriceTick:", error)
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    }
  }
}

export async function getLatestPrice() {
  try {
    const supabase = await createClient()

    const { data, error } = await supabase
      .from("coin_ticks")
      .select("price, high, low, average, tick_timestamp, reference_date")
      .order("tick_timestamp", { ascending: false })
      .limit(1)
      .single()

    if (error) {
      console.error("[v0] Error fetching latest price:", error)
      return null
    }

    return data
  } catch (error) {
    console.error("[v0] Error in getLatestPrice:", error)
    return null
  }
}

export async function getRecentTicks(secondsAgo = 60) {
  try {
    const supabase = await createClient()

    const cutoffTime = new Date(Date.now() - secondsAgo * 1000).toISOString()

    const { data, error } = await supabase
      .from("coin_ticks")
      .select("price, high, low, average, tick_timestamp")
      .gte("tick_timestamp", cutoffTime)
      .order("tick_timestamp", { ascending: true })

    if (error) {
      console.error("[v0] Error fetching recent ticks:", error)
      return []
    }

    return data || []
  } catch (error) {
    console.error("[v0] Error in getRecentTicks:", error)
    return []
  }
}

export async function storeDailySummary(summary: {
  reference_date: string
  opening_price: number
  closing_price: number
  high_price: number
  low_price: number
  growth_percent: number
  target_growth_percent: number
  total_ticks: number
}) {
  try {
    const supabase = await createClient()

    const { error } = await supabase.from("coin_summary").upsert(
      {
        reference_date: summary.reference_date,
        opening_price: summary.opening_price,
        closing_price: summary.closing_price,
        high_price: summary.high_price,
        low_price: summary.low_price,
        growth_percent: summary.growth_percent,
        target_growth_percent: summary.target_growth_percent,
        total_ticks: summary.total_ticks,
      },
      { onConflict: "reference_date" },
    )

    if (error) {
      console.error("[v0] Error storing daily summary:", error)
      return { success: false, error: error.message }
    }

    return { success: true }
  } catch (error) {
    console.error("[v0] Error in storeDailySummary:", error)
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    }
  }
}
