"use client"

import { useEffect, useState } from "react"
import { createBrowserClient } from "@supabase/ssr"
import { TrendingUp, Award, Settings, Package, Star } from "lucide-react"
import Link from "next/link"

interface UserStats {
  rating: number
  total_roi: number
}

interface SupplyData {
  remaining_supply: number
  total_supply: number
}

export function UserStatsCard() {
  const [stats, setStats] = useState<UserStats | null>(null)
  const [supply, setSupply] = useState<SupplyData | null>(null)
  const [loading, setLoading] = useState(true)

  const [supabase, setSupabase] = useState<any>(null)

  useEffect(() => {
    // Initialize Supabase client only on client side
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

    if (supabaseUrl && supabaseAnonKey) {
      const client = createBrowserClient(supabaseUrl, supabaseAnonKey)
      setSupabase(client)
      fetchUserStats(client)
      fetchSupply(client)
    } else {
      setLoading(false)
    }

    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const fetchUserStats = async (client: any) => {
    try {
      const {
        data: { user },
      } = await client.auth.getUser()
      if (!user) {
        setLoading(false)
        return
      }

      const { data: profileData, error: profileError } = await client
        .from("profiles")
        .select("rating, total_trades")
        .eq("id", user.id)
        .single()

      if (profileError) {
        console.error("[v0] Error fetching profile stats:", profileError)
        setLoading(false)
        return
      }

      const { data: statsData, error: statsError } = await client
        .from("user_stats")
        .select("total_roi")
        .eq("user_id", user.id)
        .single()

      const combinedStats: UserStats = {
        rating: profileData?.rating ?? 0,
        total_roi: statsData?.total_roi ?? 0,
      }

      console.log("[v0] User stats loaded:", combinedStats)
      setStats(combinedStats)
    } catch (error) {
      console.error("[v0] Error:", error)
    } finally {
      setLoading(false)
    }
  }

  const fetchSupply = async (client: any) => {
    try {
      const { data, error } = await client.from("supply_tracking").select("*").single()

      if (error) {
        console.error("[v0] Error fetching supply:", error)
        return
      }

      setSupply(data)
    } catch (error) {
      console.error("[v0] Error:", error)
    }
  }

  if (loading) {
    return (
      <div className="glass-card p-8 rounded-2xl border border-white/5">
        <div className="animate-pulse space-y-4">
          <div className="h-6 bg-white/5 rounded w-1/3"></div>
          <div className="h-20 bg-white/5 rounded"></div>
          <div className="h-20 bg-white/5 rounded"></div>
        </div>
      </div>
    )
  }

  const roiColor = (stats?.total_roi ?? 0) >= 0 ? "text-green-400" : "text-red-400"
  const roiSign = (stats?.total_roi ?? 0) >= 0 ? "+" : ""

  return (
    <div className="glass-card p-8 rounded-2xl border border-white/5">
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-2xl font-bold">Your Stats</h2>
        <Link
          href="/dashboard/settings"
          className="p-2 hover:bg-white/5 rounded-lg transition"
          title="Account Settings"
        >
          <Settings className="w-5 h-5 text-gray-400" />
        </Link>
      </div>

      <div className="space-y-4">
        {/* ROI */}
        <div className="flex items-center justify-between p-4 rounded-lg bg-white/5">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-purple-500/10 rounded-lg">
              <TrendingUp className="w-5 h-5 text-purple-400" />
            </div>
            <div>
              <p className="text-sm text-gray-400">P2P Trading ROI</p>
              <p className={`text-xl font-bold ${roiColor}`}>
                {roiSign}
                {(stats?.total_roi ?? 0).toFixed(2)} KES
              </p>
            </div>
          </div>
        </div>

        {/* Reputation */}
        <div className="flex items-center justify-between p-4 rounded-lg bg-white/5">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-yellow-500/10 rounded-lg">
              <Award className="w-5 h-5 text-yellow-400" />
            </div>
            <div>
              <p className="text-sm text-gray-400">Reputation</p>
              <div className="flex items-center gap-2">
                <p className="text-xl font-bold">{(stats?.rating ?? 0).toFixed(1)} / 5.0</p>
                <div className="flex gap-0.5">
                  {[1, 2, 3, 4, 5].map((star) => (
                    <Star
                      key={star}
                      size={12}
                      className={
                        star <= Math.floor(stats?.rating ?? 0) ? "fill-yellow-400 text-yellow-400" : "text-gray-600"
                      }
                    />
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Remaining Supply */}
        <div className="flex items-center justify-between p-4 rounded-lg bg-white/5">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-orange-500/10 rounded-lg">
              <Package className="w-5 h-5 text-orange-400" />
            </div>
            <div>
              <p className="text-sm text-gray-400">Remaining AFX Supply</p>
              <p className="text-xl font-bold">
                {(supply?.remaining_supply ?? 0).toLocaleString()} / {(supply?.total_supply ?? 0).toLocaleString()}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
