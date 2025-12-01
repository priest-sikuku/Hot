"use client"

import { useEffect, useState } from "react"
import { createClient } from "@/lib/supabase/client"
import { TrendingUp, Award, CheckCircle } from "lucide-react"

interface TradeStats {
  total_trades: number
  completed_trades: number
  cancelled_trades: number
  total_volume: number
  average_rating: number
  total_ratings: number
  success_rate: number
}

export function UserTradeStats({ userId }: { userId: string }) {
  const [stats, setStats] = useState<TradeStats | null>(null)
  const [loading, setLoading] = useState(true)
  const supabase = createClient()

  useEffect(() => {
    fetchStats()
  }, [userId])

  async function fetchStats() {
    try {
      const { data, error } = await supabase.rpc("get_user_trade_stats", {
        p_user_id: userId,
      })

      if (error) {
        console.error("[v0] Error fetching trade stats:", error)
        return
      }

      if (data && data.length > 0) {
        setStats(data[0])
      }
    } catch (error) {
      console.error("[v0] Error:", error)
    } finally {
      setLoading(false)
    }
  }

  if (loading) {
    return (
      <div className="glass-card p-6 rounded-xl border border-white/10">
        <p className="text-gray-400 text-sm">Loading stats...</p>
      </div>
    )
  }

  if (!stats) {
    return null
  }

  return (
    <div className="glass-card p-6 rounded-xl border border-white/10">
      <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
        <TrendingUp size={20} className="text-green-400" />
        Trading Statistics
      </h3>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-white/5 p-4 rounded-lg">
          <p className="text-xs text-gray-400 mb-1">Total Trades</p>
          <p className="text-2xl font-bold">{stats.total_trades}</p>
        </div>

        <div className="bg-white/5 p-4 rounded-lg">
          <div className="flex items-center gap-2 mb-1">
            <CheckCircle size={14} className="text-green-400" />
            <p className="text-xs text-gray-400">Completed</p>
          </div>
          <p className="text-2xl font-bold text-green-400">{stats.completed_trades}</p>
        </div>

        <div className="bg-white/5 p-4 rounded-lg">
          <div className="flex items-center gap-2 mb-1">
            <Award size={14} className="text-yellow-400" />
            <p className="text-xs text-gray-400">Rating</p>
          </div>
          <div className="flex items-center gap-1">
            <p className="text-2xl font-bold text-yellow-400">{stats.average_rating.toFixed(1)}</p>
            <span className="text-yellow-400">★</span>
            <span className="text-xs text-gray-400">({stats.total_ratings})</span>
          </div>
        </div>

        <div className="bg-white/5 p-4 rounded-lg">
          <p className="text-xs text-gray-400 mb-1">Success Rate</p>
          <p className="text-2xl font-bold text-blue-400">{stats.success_rate.toFixed(0)}%</p>
        </div>
      </div>

      <div className="mt-4 bg-white/5 p-4 rounded-lg">
        <p className="text-xs text-gray-400 mb-1">Total Volume Traded</p>
        <p className="text-xl font-bold text-green-400">{stats.total_volume.toFixed(2)} AFX</p>
      </div>
    </div>
  )
}
