"use client"

import { useState, useEffect } from "react"
import { ArrowUpRight, Gift, Coins } from "lucide-react"
import { createClient } from "@/lib/supabase/client"

interface Transaction {
  id: string
  type: string
  amount: number
  time: string
  status: string
}

export function TransactionHistory() {
  const [transactions, setTransactions] = useState<Transaction[]>([])
  const [loading, setLoading] = useState(true)

  const loadTransactions = async () => {
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
        .limit(5)

      if (transactionsData && transactionsData.length > 0) {
        const formattedTransactions = transactionsData.map((tx) => ({
          id: tx.id,
          type: tx.type,
          amount: Number(tx.amount),
          time: new Date(tx.created_at).toLocaleString(),
          status: tx.status,
        }))
        setTransactions(formattedTransactions)
      }
    }
    setLoading(false)
  }

  useEffect(() => {
    loadTransactions()
    // Auto-refresh every 10 seconds
    const interval = setInterval(loadTransactions, 10000)
    return () => clearInterval(interval)
  }, [])

  const getIcon = (type: string) => {
    switch (type) {
      case "mining":
        return <Coins className="w-4 h-4 text-yellow-400" />
      case "p2p_trade":
        return <ArrowUpRight className="w-4 h-4 text-green-400" />
      case "claim":
        return <Gift className="w-4 h-4 text-purple-400" />
      default:
        return <ArrowUpRight className="w-4 h-4 text-gray-400" />
    }
  }

  const getLabel = (type: string) => {
    switch (type) {
      case "mining":
        return "Mining Reward"
      case "p2p_trade":
        return "P2P Trade"
      case "claim":
        return "Coins Claimed"
      default:
        return "Transaction"
    }
  }

  const getBackgroundColor = (type: string) => {
    switch (type) {
      case "mining":
        return "bg-yellow-500/10"
      case "p2p_trade":
        return "bg-green-500/10"
      case "claim":
        return "bg-purple-500/10"
      default:
        return "bg-gray-500/10"
    }
  }

  return (
    <div className="glass-card p-6 rounded-2xl border border-white/5">
      <h3 className="text-xl font-bold mb-6">Recent Activity</h3>

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-green-500" />
        </div>
      ) : transactions.length === 0 ? (
        <div className="text-center py-12">
          <div className="text-gray-400 mb-2">No transactions yet</div>
          <p className="text-sm text-gray-500">Start trading to see your activity here</p>
        </div>
      ) : (
        <div className="space-y-4">
          {transactions.map((tx) => (
            <div
              key={tx.id}
              className="flex items-center justify-between p-4 bg-white/5 rounded-lg hover:bg-white/10 transition"
            >
              <div className="flex items-center gap-3">
                <div className={`p-2 rounded-lg ${getBackgroundColor(tx.type)}`}>{getIcon(tx.type)}</div>
                <div>
                  <p className="text-sm font-semibold">{getLabel(tx.type)}</p>
                  <p className="text-xs text-gray-400">{tx.time}</p>
                </div>
              </div>
              <div className="text-right">
                <p className={`font-bold ${tx.amount > 0 ? "text-green-400" : "text-red-400"}`}>
                  {tx.amount > 0 ? "+" : ""}
                  {tx.amount.toFixed(2)} AFX
                </p>
                <p className="text-xs text-gray-400 capitalize">{tx.status}</p>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
