"use client"

import { useState, useEffect } from "react"
import Link from "next/link"
import { createClient } from "@/lib/supabase/client"
import { Star } from 'lucide-react'

export function BalancePanel() {
  const [balance, setBalance] = useState(0)
  const [userRating, setUserRating] = useState(0)
  const [userTrades, setUserTrades] = useState(0)

  useEffect(() => {
    const loadUserData = async () => {
      const supabase = createClient()
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (user) {
        const { data: balanceData } = await supabase.rpc("get_user_balance", { p_user_id: user.id })
        if (balanceData !== null) {
          setBalance(Number(balanceData))
        }

        const { data: profile } = await supabase
          .from("profiles")
          .select("rating, total_trades")
          .eq("id", user.id)
          .single()
        if (profile) {
          setUserRating(Number(profile.rating) || 0)
          setUserTrades(Number(profile.total_trades) || 0)
        }
      }
    }

    loadUserData()
  }, [])

  return (
    <div className="space-y-4">
      {/* Balance Card */}
      <div className="glass-card p-6 rounded-2xl border border-white/5">
        <div className="grid grid-cols-2 gap-4 mb-6">
          <div>
            <div className="text-xs text-gray-400 mb-1">Your Balance</div>
            <div className="text-2xl font-bold text-white">{balance ? balance.toFixed(2) : "0.00"} AFX</div>
          </div>
          <div className="text-right">
            <div className="text-xs text-gray-400 mb-1">Daily Growth</div>
            <div className="text-2xl font-bold text-green-400">+3%</div>
          </div>
        </div>
      </div>

      {/* User Stats Card */}
      <div className="glass-card p-6 rounded-2xl border border-white/5">
        <h4 className="font-bold text-white mb-4">Your Stats</h4>
        <div className="space-y-3">
          <div className="flex justify-between items-center">
            <span className="text-sm text-gray-400">Rating</span>
            <div className="flex items-center gap-1">
              {[1, 2, 3, 4, 5].map((star) => (
                <Star
                  key={star}
                  size={14}
                  className={
                    star <= Math.floor(userRating)
                      ? "fill-yellow-400 text-yellow-400"
                      : star === Math.ceil(userRating) && userRating % 1 >= 0.5
                        ? "fill-yellow-400/50 text-yellow-400"
                        : "text-gray-600"
                  }
                />
              ))}
              <span className="ml-1 font-semibold text-yellow-400">{userRating ? userRating.toFixed(1) : "0.0"}</span>
            </div>
          </div>
          <div className="flex justify-between items-center">
            <span className="text-sm text-gray-400">Trades</span>
            <span className="font-semibold text-green-400">{userTrades ? userTrades : "0"}</span>
          </div>
        </div>
      </div>

      {/* P2P Market Card */}
      <div className="glass-card p-6 rounded-2xl border border-white/5">
        <h4 className="font-bold text-white mb-2">P2P Market</h4>
        <p className="text-sm text-gray-400 mb-4">
          Buy or sell AFX with M-Pesa or bank transfer. Escrow-secured trades.
        </p>
        <div className="flex gap-3">
          <Link
            href="/market?tab=buy"
            className="flex-1 px-4 py-2 rounded-lg btn-ghost-afx font-semibold border hover:bg-green-500/10 transition text-sm text-center"
          >
            Buy AFX
          </Link>
          <Link
            href="/market?tab=sell"
            className="flex-1 px-4 py-2 rounded-lg btn-ghost-afx font-semibold border hover:bg-green-500/10 transition text-sm text-center"
          >
            Sell AFX
          </Link>
        </div>
      </div>
    </div>
  )
}
