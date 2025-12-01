"use client"

import { useState, useEffect } from "react"
import { ArrowUpRight, ArrowDownLeft, Gift, TrendingUp } from "lucide-react"
import { createClient } from "@/lib/supabase/client"

interface Activity {
  id: string
  type: string
  amount: number
  time: string
  created_at: string
  status: string
}

export function RecentActivity() {
  const [activities, setActivities] = useState<Activity[]>([])
  const [loading, setLoading] = useState(true)

  const loadActivities = async () => {
    const supabase = createClient()
    const {
      data: { user },
    } = await supabase.auth.getUser()

    if (user) {
      const { data: transactionsData } = await supabase
        .from("transactions")
        .select("*")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false })
        .limit(5) // Limit to only 5 most recent activities

      if (transactionsData && transactionsData.length > 0) {
        const formattedActivities = transactionsData.map((tx) => ({
          id: tx.id,
          type: tx.type,
          amount: Number(tx.amount),
          time: new Date(tx.created_at).toLocaleString(),
          created_at: tx.created_at,
          status: tx.status,
        }))
        setActivities(formattedActivities)
      }
    }
    setLoading(false)
  }

  useEffect(() => {
    loadActivities()
    // Auto-refresh every 10 seconds
    const interval = setInterval(loadActivities, 10000)
    return () => clearInterval(interval)
  }, [])

  const getIcon = (type: string) => {
    switch (type) {
      case "p2p_trade":
        return <TrendingUp className="w-4 h-4 text-green-400" />
      case "claim":
        return <Gift className="w-4 h-4 text-purple-400" />
      case "buy":
        return <ArrowDownLeft className="w-4 h-4 text-blue-400" />
      case "sell":
        return <ArrowUpRight className="w-4 h-4 text-orange-400" />
      case "referral_commission":
        return <Gift className="w-4 h-4 text-green-400" />
      default:
        return <ArrowUpRight className="w-4 h-4 text-gray-400" />
    }
  }

  const getLabel = (type: string) => {
    switch (type) {
      case "p2p_trade":
        return "P2P Trade"
      case "claim":
        return "Coins Claimed"
      case "buy":
        return "Bought AFX"
      case "sell":
        return "Sold AFX"
      case "referral_commission":
        return "Referral Commission"
      default:
        return "Transaction"
    }
  }

  const getBackgroundColor = (type: string) => {
    switch (type) {
      case "p2p_trade":
        return "bg-green-500/10"
      case "claim":
        return "bg-purple-500/10"
      case "buy":
        return "bg-blue-500/10"
      case "sell":
        return "bg-orange-500/10"
      case "referral_commission":
        return "bg-green-500/10"
      default:
        return "bg-gray-500/10"
    }
  }

  const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    const now = new Date()
    const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000)

    if (diffInSeconds < 60) return `${diffInSeconds}s ago`
    if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m ago`
    if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h ago`
    if (diffInSeconds < 604800) return `${Math.floor(diffInSeconds / 86400)}d ago`

    return date.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: date.getFullYear() !== now.getFullYear() ? "numeric" : undefined,
    })
  }

  return (
    <div className="glass-card p-6 rounded-2xl border border-white/5">
      <div className="flex items-center justify-between mb-6">
        <h3 className="text-xl font-bold">Recent Activity</h3>
        <p className="text-sm text-gray-400">{activities.length} activities</p>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-green-500" />
        </div>
      ) : activities.length === 0 ? (
        <div className="text-center py-12">
          <div className="text-gray-400 mb-2">No activities yet</div>
          <p className="text-sm text-gray-500">Start trading to see your activity here</p>
        </div>
      ) : (
        <div className="space-y-3 max-h-[600px] overflow-y-auto custom-scrollbar">
          {activities.map((activity) => (
            <div
              key={activity.id}
              className="flex items-center justify-between p-4 bg-white/5 rounded-lg hover:bg-white/10 transition"
            >
              <div className="flex items-center gap-3">
                <div className={`p-2 rounded-lg ${getBackgroundColor(activity.type)}`}>{getIcon(activity.type)}</div>
                <div>
                  <p className="text-sm font-semibold">{getLabel(activity.type)}</p>
                  <p className="text-xs text-gray-400">{formatDate(activity.created_at)}</p>
                </div>
              </div>
              <div className="text-right">
                <p className={`font-bold ${activity.amount > 0 ? "text-green-400" : "text-red-400"}`}>
                  {activity.amount > 0 ? "+" : ""}
                  {activity.amount.toFixed(2)} AFX
                </p>
                <p className="text-xs text-gray-400 capitalize">{activity.status}</p>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
