"use client"

import { useEffect, useState } from "react"
import { Wallet, Lock, RefreshCw } from "lucide-react"
import { createClient } from "@/lib/supabase/client"

interface BalanceDisplayProps {
  variant?: "compact" | "full"
  showRefresh?: boolean
}

export function BalanceDisplay({ variant = "full", showRefresh = true }: BalanceDisplayProps) {
  const [totalBalance, setTotalBalance] = useState<number>(0)
  const [availableBalance, setAvailableBalance] = useState<number>(0)
  const [lockedBalance, setLockedBalance] = useState<number>(0)
  const [loading, setLoading] = useState(true)
  const [refreshing, setRefreshing] = useState(false)

  const fetchBalance = async () => {
    const supabase = createClient()
    const {
      data: { user },
    } = await supabase.auth.getUser()

    if (!user) {
      setLoading(false)
      return
    }

    try {
      // Fetch total balance
      const { data: totalData, error: totalError } = await supabase.rpc("get_user_balance", {
        p_user_id: user.id,
      })

      if (totalError) throw totalError
      setTotalBalance(Number(totalData) || 0)

      // Fetch available balance
      const { data: availData, error: availError } = await supabase.rpc("get_available_balance", {
        p_user_id: user.id,
      })

      if (availError) throw availError
      setAvailableBalance(Number(availData) || 0)

      // Fetch locked balance
      const { data: lockedData, error: lockedError } = await supabase.rpc("get_locked_balance", {
        p_user_id: user.id,
      })

      if (lockedError) throw lockedError
      setLockedBalance(Number(lockedData) || 0)
    } catch (error) {
      console.error("[v0] Error fetching balance:", error)
    } finally {
      setLoading(false)
      setRefreshing(false)
    }
  }

  useEffect(() => {
    fetchBalance()
    // Refresh every 5 seconds
    const interval = setInterval(fetchBalance, 5000)
    return () => clearInterval(interval)
  }, [])

  const handleRefresh = async () => {
    setRefreshing(true)
    await fetchBalance()
  }

  if (variant === "compact") {
    return (
      <div className="flex items-center gap-3 px-4 py-2 rounded-lg bg-white/5 border border-white/10">
        <Wallet className="w-5 h-5 text-green-400" />
        <div>
          <p className="text-xs text-gray-400">Available Balance</p>
          <p className="text-lg font-bold text-white">{loading ? "..." : `${availableBalance.toFixed(2)} AFX`}</p>
        </div>
        {showRefresh && (
          <button
            onClick={handleRefresh}
            disabled={refreshing}
            className="ml-auto p-2 hover:bg-white/10 rounded-lg transition"
            title="Refresh balance"
          >
            <RefreshCw className={`w-4 h-4 text-gray-400 ${refreshing ? "animate-spin" : ""}`} />
          </button>
        )}
      </div>
    )
  }

  return (
    <div className="glass-card p-6 rounded-2xl border border-white/5">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-bold">Your Balance</h3>
        {showRefresh && (
          <button
            onClick={handleRefresh}
            disabled={refreshing}
            className="p-2 hover:bg-white/10 rounded-lg transition"
            title="Refresh balance"
          >
            <RefreshCw className={`w-4 h-4 text-gray-400 ${refreshing ? "animate-spin" : ""}`} />
          </button>
        )}
      </div>

      <div className="space-y-4">
        {/* Total Balance */}
        <div className="p-4 rounded-lg bg-gradient-to-r from-green-500/10 to-green-600/10 border border-green-500/20">
          <div className="flex items-center gap-3 mb-2">
            <Wallet className="w-5 h-5 text-green-400" />
            <p className="text-sm text-gray-400">Total Balance</p>
          </div>
          <p className="text-3xl font-bold text-white">{loading ? "..." : `${totalBalance.toFixed(2)} AFX`}</p>
          <p className="text-xs text-gray-500 mt-1">Includes referrals & trades</p>
        </div>

        {/* Available Balance */}
        <div className="p-4 rounded-lg bg-white/5">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-400 mb-1">Available for Trading</p>
              <p className="text-xl font-bold text-green-400">
                {loading ? "..." : `${availableBalance.toFixed(2)} AFX`}
              </p>
            </div>
            <Wallet className="w-6 h-6 text-green-400" />
          </div>
        </div>

        {/* Locked Balance */}
        {lockedBalance > 0 && (
          <div className="p-4 rounded-lg bg-white/5">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-400 mb-1">Locked in P2P Escrow</p>
                <p className="text-xl font-bold text-yellow-400">
                  {loading ? "..." : `${lockedBalance.toFixed(2)} AFX`}
                </p>
              </div>
              <Lock className="w-6 h-6 text-yellow-400" />
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
