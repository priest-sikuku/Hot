"use client"

import { useEffect, useState } from "react"
import { createClient } from "@/lib/supabase/client"
import { Users, Copy, Check } from "lucide-react"

export function ReferralBalanceWidget() {
  const [referralBalance, setReferralBalance] = useState(0)
  const [referralCount, setReferralCount] = useState(0)
  const [referralCode, setReferralCode] = useState("")
  const [copied, setCopied] = useState(false)
  const [signupRewards, setSignupRewards] = useState(0)
  const [tradeRewards, setTradeRewards] = useState(0)

  useEffect(() => {
    const fetchReferralData = async () => {
      const supabase = createClient()
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (user) {
        // Get referral balance from trade_coins where source is referral_commission
        const { data: commissions } = await supabase
          .from("trade_coins")
          .select("amount")
          .eq("user_id", user.id)
          .eq("source", "referral_commission")
          .eq("status", "available")

        if (commissions) {
          const total = commissions.reduce((sum, item) => sum + Number(item.amount), 0)
          setReferralBalance(total)
        }

        const { data: signupData } = await supabase
          .from("referral_commissions")
          .select("amount")
          .eq("referrer_id", user.id)
          .eq("commission_type", "signup_mining")
          .eq("status", "completed")

        if (signupData) {
          const signupTotal = signupData.reduce((sum, item) => sum + Number(item.amount), 0)
          setSignupRewards(signupTotal)
        }

        const { data: tradeData } = await supabase
          .from("referral_commissions")
          .select("amount")
          .eq("referrer_id", user.id)
          .eq("commission_type", "trading")
          .eq("status", "completed")

        if (tradeData) {
          const tradeTotal = tradeData.reduce((sum, item) => sum + Number(item.amount), 0)
          setTradeRewards(tradeTotal)
        }

        // Get profile data
        const { data: profile } = await supabase
          .from("profiles")
          .select("referral_code, total_referrals")
          .eq("id", user.id)
          .single()

        if (profile) {
          setReferralCode(profile.referral_code || "")
          setReferralCount(profile.total_referrals || 0)
        }
      }
    }

    fetchReferralData()
    const interval = setInterval(fetchReferralData, 10000)
    return () => clearInterval(interval)
  }, [])

  const copyReferralLink = () => {
    const link = `${window.location.origin}/auth/sign-up?ref=${referralCode}`
    navigator.clipboard.writeText(link)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <div className="glass-card p-6 rounded-2xl border border-white/5">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold">Referral Rewards</h3>
        <div className="p-2 bg-purple-500/10 rounded-lg">
          <Users className="w-5 h-5 text-purple-400" />
        </div>
      </div>

      {/* Referral Balance */}
      <div className="mb-4">
        <p className="text-gray-400 text-sm mb-1">Total Referral Earnings</p>
        <p className="text-3xl font-bold text-purple-400">{referralBalance.toFixed(2)}</p>
        <p className="text-xs text-gray-500 mt-1">AFX Coins (in P2P Balance)</p>

        <div className="mt-3 grid grid-cols-2 gap-2">
          <div className="p-2 bg-white/5 rounded-lg">
            <p className="text-xs text-gray-400">Signup Rewards</p>
            <p className="text-lg font-bold text-green-400">{signupRewards.toFixed(1)} AFX</p>
          </div>
          <div className="p-2 bg-white/5 rounded-lg">
            <p className="text-xs text-gray-400">Trade Rewards</p>
            <p className="text-lg font-bold text-blue-400">{tradeRewards.toFixed(1)} AFX</p>
          </div>
        </div>
      </div>

      {/* Referral Count */}
      <div className="mb-4 p-4 bg-white/5 rounded-lg">
        <div className="flex items-center justify-between">
          <span className="text-gray-400 text-sm">Total Referrals</span>
          <span className="text-2xl font-bold text-white">{referralCount}</span>
        </div>
      </div>

      {/* Referral Code */}
      {referralCode && (
        <div>
          <p className="text-gray-400 text-sm mb-2">Your Referral Code</p>
          <div className="flex items-center gap-2">
            <div className="flex-1 px-4 py-2 bg-white/5 border border-white/10 rounded-lg font-mono text-white">
              {referralCode}
            </div>
            <button
              onClick={copyReferralLink}
              className="p-2 bg-purple-500/20 hover:bg-purple-500/30 rounded-lg transition"
              title="Copy referral link"
            >
              {copied ? <Check className="w-5 h-5 text-green-400" /> : <Copy className="w-5 h-5 text-purple-400" />}
            </button>
          </div>
          <p className="text-xs text-gray-500 mt-2">
            Earn 1 AFX when referrals complete their first mining + 2 AFX per P2P trade!
          </p>
        </div>
      )}
    </div>
  )
}
