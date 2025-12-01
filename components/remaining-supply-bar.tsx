"use client"

import { useEffect, useState } from "react"
import { createBrowserClient } from "@supabase/ssr"
import { Package, TrendingDown } from 'lucide-react'

const TOTAL_SUPPLY = 1000000

export function RemainingSupplyBar() {
  const [supplyData, setSupplyData] = useState<{
    remaining: number
    mined: number
    percentage: number
  } | null>(null)
  const [loading, setLoading] = useState(true)

  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  )

  useEffect(() => {
    fetchRemainingSupply()
    
    const interval = setInterval(fetchRemainingSupply, 10000)
    return () => clearInterval(interval)
  }, [])

  const fetchRemainingSupply = async () => {
    try {
      const { data, error } = await supabase
        .from("global_supply")
        .select("*")
        .eq("id", 1)
        .single()

      if (error) {
        console.error("[v0] Error fetching global supply:", error)
        setLoading(false)
        return
      }

      const remaining = Number(data.remaining_supply || 0)
      const mined = Number(data.mined_supply || 0)
      const percentage = (remaining / TOTAL_SUPPLY) * 100

      console.log("[v0] Global supply status:", {
        totalSupply: TOTAL_SUPPLY,
        mined,
        remaining,
        percentage: percentage.toFixed(2),
      })

      setSupplyData({ remaining, mined, percentage })
    } catch (error) {
      console.error("[v0] Exception fetching supply:", error)
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="w-full max-w-4xl mx-auto h-10 bg-white/5 rounded-xl animate-pulse" />
    )
  }

  if (!supplyData) {
    return null
  }

  const { remaining, mined, percentage } = supplyData
  const barColor = percentage > 50 ? "bg-green-500" : percentage > 25 ? "bg-yellow-500" : "bg-red-500"
  const glowColor = percentage > 50 ? "shadow-green-500/50" : percentage > 25 ? "shadow-yellow-500/50" : "shadow-red-500/50"

  return (
    <div className="w-full max-w-4xl mx-auto bg-black/40 rounded-xl h-10 border border-white/10 overflow-hidden backdrop-blur-md relative shadow-lg">
      <div className="relative h-full flex items-center px-6">
        <div 
          className={`absolute left-0 top-0 h-full ${barColor} opacity-30 transition-all duration-700 ease-out ${glowColor} shadow-lg`} 
          style={{ width: `${percentage}%` }}
        >
          {/* Shimmer effect */}
          <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent animate-shimmer" />
        </div>
        
        {/* Content */}
        <div className="relative flex items-center justify-between w-full gap-4">
          <div className="flex items-center gap-3">
            <Package className="w-5 h-5 text-green-400" />
            <span className="text-base font-bold text-white">
              Remaining Supply: {remaining.toLocaleString()} AFX
            </span>
          </div>
          
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2 text-sm text-gray-300">
              <TrendingDown className="w-4 h-4" />
              <span>Mined: {mined.toLocaleString()}</span>
            </div>
            <span className="text-sm font-semibold text-gray-200 bg-black/30 px-3 py-1 rounded-full">
              {percentage.toFixed(2)}%
            </span>
          </div>
        </div>
      </div>
    </div>
  )
}
