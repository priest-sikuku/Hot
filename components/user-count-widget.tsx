"use client"

import { useEffect, useState } from "react"
import { createClient } from "@/lib/supabase/client"
import { Users } from "lucide-react"

export function UserCountWidget() {
  const [userCount, setUserCount] = useState<number>(1239)
  const [loading, setLoading] = useState(true)
  const supabase = createClient()

  useEffect(() => {
    const fetchUserCount = async () => {
      try {
        // Call the function to get total user count
        const { data, error } = await supabase.rpc("get_total_user_count")

        if (error) {
          console.error("Error fetching user count:", error)
          return
        }

        if (data) {
          setUserCount(data)
        }
      } catch (error) {
        console.error("Error fetching user count:", error)
      } finally {
        setLoading(false)
      }
    }

    fetchUserCount()
    // Update every 1 minute
    const interval = setInterval(fetchUserCount, 60000)

    return () => clearInterval(interval)
  }, [supabase])

  if (loading) {
    return (
      <div className="glass-card p-6 rounded-xl border border-white/5 animate-pulse">
        <div className="h-20 bg-white/5 rounded"></div>
      </div>
    )
  }

  return (
    <div className="glass-card p-6 rounded-xl border border-white/5 hover:border-green-500/30 transition">
      <div className="flex items-center gap-3 mb-2">
        <div className="p-2 rounded-lg bg-green-500/10">
          <Users className="w-5 h-5 text-green-400" />
        </div>
        <h4 className="font-bold text-white">Active Users</h4>
      </div>
      <div className="text-3xl font-bold text-white mb-1">{userCount.toLocaleString()}</div>
      <p className="text-xs text-gray-400">Total Registered Users</p>
    </div>
  )
}
