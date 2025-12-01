"use client"

import { useEffect, useState, useRef } from "react"
import { createClient } from "@/lib/supabase/client"

interface PriceData {
  price: number
  high: number
  low: number
  average: number
  changePercent: number
}

interface ChartData {
  timestamp: string
  price: number
}

export function useRealtimePrice() {
  const [priceData, setPriceData] = useState<PriceData>({
    price: 0,
    high: 0,
    low: 0,
    average: 0,
    changePercent: 0,
  })
  const [chartData, setChartData] = useState<ChartData[]>([])
  const [isConnected, setIsConnected] = useState(true)
  const [priceChanged, setPriceChanged] = useState(false)

  const previousPriceRef = useRef(0)

  useEffect(() => {
    const supabase = createClient()

    const fetchLatestPrice = async () => {
      try {
        console.log("[v0] Fetching latest price from database...")

        // Get latest price tick
        const { data: latestTick, error: tickError } = await supabase
          .from("coin_ticks")
          .select("*")
          .order("tick_timestamp", { ascending: false })
          .limit(1)
          .single()

        if (tickError) {
          console.error("[v0] Error fetching price:", tickError)
          setIsConnected(false)
          return
        }

        if (latestTick) {
          const currentDate = new Date().toISOString().split("T")[0]

          // Get opening price for change calculation
          const { data: dayOpening } = await supabase
            .from("coin_ticks")
            .select("price")
            .eq("reference_date", currentDate)
            .order("tick_timestamp", { ascending: true })
            .limit(1)
            .single()

          const openingPrice = dayOpening ? Number(dayOpening.price) : Number(latestTick.price)
          const newPrice = Number(latestTick.price)
          const changePercent = ((newPrice - openingPrice) / openingPrice) * 100

          if (newPrice !== previousPriceRef.current) {
            setPriceChanged(true)
            setTimeout(() => setPriceChanged(false), 500)
            previousPriceRef.current = newPrice
          }

          setPriceData({
            price: newPrice,
            high: Number(latestTick.high),
            low: Number(latestTick.low),
            average: Number(latestTick.average),
            changePercent,
          })

          console.log("[v0] Price updated:", newPrice)
          setIsConnected(true)
        }

        // Get recent ticks for chart (last 2 minutes = 40 ticks at 3-second intervals)
        const { data: recentTicks } = await supabase
          .from("coin_ticks")
          .select("price, tick_timestamp")
          .order("tick_timestamp", { ascending: false })
          .limit(40)

        if (recentTicks && recentTicks.length > 0) {
          setChartData(
            recentTicks.reverse().map((tick) => ({
              timestamp: tick.tick_timestamp,
              price: Number(tick.price),
            })),
          )
        }
      } catch (error) {
        console.error("[v0] Failed to fetch price:", error)
        setIsConnected(false)
      }
    }

    const triggerPriceUpdate = async () => {
      try {
        await fetch("/api/price-tick")
      } catch (error) {
        console.error("[v0] Failed to trigger price update:", error)
      }
    }

    // Initial fetch
    fetchLatestPrice()
    triggerPriceUpdate()

    const pollingInterval = setInterval(fetchLatestPrice, 2000)

    const triggerInterval = setInterval(triggerPriceUpdate, 3000)

    const channel = supabase
      .channel("price-updates")
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "coin_ticks",
        },
        () => {
          console.log("[v0] Real-time update received, fetching latest price...")
          fetchLatestPrice()
        },
      )
      .subscribe()

    return () => {
      clearInterval(pollingInterval)
      clearInterval(triggerInterval)
      channel.unsubscribe()
    }
  }, [])

  return {
    priceData,
    chartData,
    isConnected,
    priceChanged,
  }
}
