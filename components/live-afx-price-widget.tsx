"use client"

import { useEffect, useState } from "react"
import { createClient } from "@/lib/supabase/client"
import { TrendingUp, TrendingDown, DollarSign } from 'lucide-react'
import { useExchangeRate, convertKEStoUSD } from "@/lib/hooks/use-exchange-rate"

export function LiveAfxPriceWidget() {
  const [price, setPrice] = useState<number | null>(null)
  const [change24h, setChange24h] = useState<number>(0)
  const [targetPrice, setTargetPrice] = useState<number | null>(null)
  const [loading, setLoading] = useState(true)
  const { exchangeRate } = useExchangeRate()
  const supabase = createClient()

  useEffect(() => {
    const fetchPrice = async () => {
      try {
        const { data: latestTick } = await supabase
          .from("coin_ticks")
          .select("price, created_at")
          .order("created_at", { ascending: false })
          .limit(1)
          .single()

        if (latestTick) {
          setPrice(latestTick.price)

          const currentDate = new Date().toISOString().split("T")[0]
          const { data: openingTick } = await supabase
            .from("coin_ticks")
            .select("price")
            .eq("reference_date", currentDate)
            .order("created_at", { ascending: true })
            .limit(1)
            .single()

          if (openingTick) {
            const openingPrice = Number(openingTick.price)
            const todayTarget = openingPrice + 1.0 // +1 KES target

            setTargetPrice(todayTarget)

            const change = ((latestTick.price - openingPrice) / openingPrice) * 100
            setChange24h(change)
          }
        }
      } catch (error) {
        console.error("[v0] Error fetching AFX price:", error)
      } finally {
        setLoading(false)
      }
    }

    fetchPrice()
    const interval = setInterval(fetchPrice, 3000)

    return () => clearInterval(interval)
  }, [supabase])

  if (loading) {
    return (
      <div className="glass-card p-6 rounded-xl border border-white/5 animate-pulse">
        <div className="h-20 bg-white/5 rounded"></div>
      </div>
    )
  }

  const isPositive = change24h >= 0
  const priceUSD = price ? convertKEStoUSD(price, exchangeRate.usd_to_kes) : 0

  return (
    <div className="glass-card p-6 rounded-xl border border-white/5 hover:border-green-500/30 transition">
      <div className="flex items-center justify-between mb-2">
        <h4 className="font-bold text-white">AFX Price</h4>
        <div className="flex items-center gap-1">
          {isPositive ? (
            <TrendingUp className="w-4 h-4 text-green-400" />
          ) : (
            <TrendingDown className="w-4 h-4 text-red-400" />
          )}
          <span className={`text-sm font-semibold ${isPositive ? "text-green-400" : "text-red-400"}`}>
            {isPositive ? "+" : ""}
            {change24h.toFixed(2)}%
          </span>
        </div>
      </div>
      <div className="flex items-baseline gap-2 mb-1">
        <DollarSign className="w-6 h-6 text-green-400" />
        <div className="text-3xl font-bold text-white">${priceUSD.toFixed(4)}</div>
      </div>
      <div className="text-sm text-gray-400 mb-1">
        {price ? price.toFixed(2) : "0.00"} KES
      </div>
      <div className="text-xs text-gray-500">
        1 USD = {exchangeRate.usd_to_kes.toFixed(2)} KES
        {exchangeRate.fallback && " (fallback)"}
      </div>
    </div>
  )
}
