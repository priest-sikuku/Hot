"use client"

import { useEffect, useState } from "react"
import { createClient } from "@/lib/supabase/client"
import { useRouter } from "next/navigation"
import Header from "@/components/header"
import Footer from "@/components/footer"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { ArrowLeft, Clock, CheckCircle, XCircle, Loader2 } from "lucide-react"

interface Trade {
  id: string
  ad_id: string
  buyer_id: string
  seller_id: string
  afx_amount: number // Renamed from gx_amount to afx_amount
  escrow_amount: number
  status: string
  created_at: string
  updated_at: string
  payment_confirmed_at: string | null
  coins_released_at: string | null
  expires_at: string
  buyer_profile: {
    username: string
    email: string
  }
  seller_profile: {
    username: string
    email: string
  }
  ad: {
    ad_type: string
    account_number: string
    mpesa_number: string
    paybill_number: string
    airtel_money: string
  }
}

export default function MyTrades() {
  const router = useRouter()
  const [trades, setTrades] = useState<Trade[]>([])
  const [loading, setLoading] = useState(true)
  const [userId, setUserId] = useState<string | null>(null)

  useEffect(() => {
    fetchTrades()
  }, [])

  async function fetchTrades() {
    try {
      const supabase = createClient()

      // Get current user
      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) {
        router.push("/auth/sign-in")
        return
      }

      setUserId(user.id)

      // Fetch all trades where user is buyer or seller
      const { data, error } = await supabase
        .from("p2p_trades")
        .select(`
          *,
          buyer_profile:profiles!p2p_trades_buyer_id_fkey(username, email),
          seller_profile:profiles!p2p_trades_seller_id_fkey(username, email),
          ad:p2p_ads(ad_type, account_number, mpesa_number, paybill_number, airtel_money)
        `)
        .or(`buyer_id.eq.${user.id},seller_id.eq.${user.id}`)
        .order("created_at", { ascending: false })

      if (error) {
        console.error("[v0] Error fetching trades:", error)
        return
      }

      console.log("[v0] Fetched trades:", data)
      setTrades(data || [])
    } catch (error) {
      console.error("[v0] Error:", error)
    } finally {
      setLoading(false)
    }
  }

  const getStatusBadge = (status: string) => {
    switch (status) {
      case "pending":
        return (
          <Badge variant="outline" className="bg-yellow-500/10 text-yellow-500 border-yellow-500/20">
            <Clock size={14} className="mr-1" />
            Pending
          </Badge>
        )
      case "payment_sent":
        return (
          <Badge variant="outline" className="bg-blue-500/10 text-blue-500 border-blue-500/20">
            <Clock size={14} className="mr-1" />
            Payment Sent
          </Badge>
        )
      case "completed":
        return (
          <Badge variant="outline" className="bg-green-500/10 text-green-500 border-green-500/20">
            <CheckCircle size={14} className="mr-1" />
            Completed
          </Badge>
        )
      case "cancelled":
        return (
          <Badge variant="outline" className="bg-red-500/10 text-red-500 border-red-500/20">
            <XCircle size={14} className="mr-1" />
            Cancelled
          </Badge>
        )
      case "expired":
        return (
          <Badge variant="outline" className="bg-gray-500/10 text-gray-500 border-gray-500/20">
            <XCircle size={14} className="mr-1" />
            Expired
          </Badge>
        )
      default:
        return <Badge variant="outline">{status}</Badge>
    }
  }

  const filterTradesByStatus = (status: string) => {
    if (status === "all") return trades
    return trades.filter((trade) => trade.status === status)
  }

  const renderTradeCard = (trade: Trade) => {
    const isBuyer = trade.buyer_id === userId
    const counterparty = isBuyer ? trade.seller_profile : trade.buyer_profile
    const role = isBuyer ? "Buyer" : "Seller"

    return (
      <div
        key={trade.id}
        className="p-4 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition cursor-pointer"
        onClick={() => router.push(`/p2p/trade/${trade.id}`)}
      >
        <div className="flex items-start justify-between mb-3">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <span className="font-semibold text-lg">{trade.afx_amount} AFX</span>
              {getStatusBadge(trade.status)}
            </div>
            <p className="text-sm text-gray-400">
              {isBuyer ? "Buying from" : "Selling to"}: {counterparty?.username || counterparty?.email || "Unknown"}
            </p>
          </div>
          <Badge variant="secondary" className="text-xs">
            {role}
          </Badge>
        </div>

        <div className="grid grid-cols-2 gap-2 text-sm">
          <div>
            <p className="text-gray-400">Trade ID</p>
            <p className="font-mono text-xs">{trade.id.slice(0, 8)}...</p>
          </div>
          <div>
            <p className="text-gray-400">Created</p>
            <p>{new Date(trade.created_at).toLocaleDateString()}</p>
          </div>
        </div>

        {trade.status === "pending" && (
          <div className="mt-3 pt-3 border-t border-white/10">
            <p className="text-xs text-yellow-500">⏱ Expires: {new Date(trade.expires_at).toLocaleString()}</p>
          </div>
        )}
      </div>
    )
  }

  if (loading) {
    return (
      <div className="min-h-screen flex flex-col">
        <Header />
        <main className="flex-1 flex items-center justify-center">
          <Loader2 className="animate-spin" size={32} />
        </main>
        <Footer />
      </div>
    )
  }

  const pendingTrades = filterTradesByStatus("pending")
  const paymentSentTrades = filterTradesByStatus("payment_sent")
  const completedTrades = filterTradesByStatus("completed")
  const cancelledTrades = filterTradesByStatus("cancelled")
  const expiredTrades = filterTradesByStatus("expired")

  return (
    <div className="min-h-screen flex flex-col">
      <Header />
      <main className="flex-1">
        <div className="max-w-7xl mx-auto px-6 py-12">
          <div className="mb-8">
            <Button variant="ghost" className="mb-4 hover:bg-white/5" onClick={() => router.push("/p2p")}>
              <ArrowLeft size={16} className="mr-2" />
              Back to P2P Market
            </Button>
            <h1 className="text-4xl font-bold mb-2">My Trades</h1>
            <p className="text-gray-400">View and manage all your P2P trades</p>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-5 gap-6 mb-8">
            <div className="glass-card p-6 rounded-xl border border-white/10">
              <p className="text-gray-400 text-sm mb-2">Total Trades</p>
              <p className="text-3xl font-bold text-white">{trades.length}</p>
            </div>
            <div className="glass-card p-6 rounded-xl border border-white/10">
              <p className="text-gray-400 text-sm mb-2">Pending</p>
              <p className="text-3xl font-bold text-yellow-400">{pendingTrades.length}</p>
            </div>
            <div className="glass-card p-6 rounded-xl border border-white/10">
              <p className="text-gray-400 text-sm mb-2">Payment Sent</p>
              <p className="text-3xl font-bold text-blue-400">{paymentSentTrades.length}</p>
            </div>
            <div className="glass-card p-6 rounded-xl border border-white/10">
              <p className="text-gray-400 text-sm mb-2">Completed</p>
              <p className="text-3xl font-bold text-green-400">{completedTrades.length}</p>
            </div>
            <div className="glass-card p-6 rounded-xl border border-white/10">
              <p className="text-gray-400 text-sm mb-2">Cancelled</p>
              <p className="text-3xl font-bold text-red-400">{cancelledTrades.length + expiredTrades.length}</p>
            </div>
          </div>

          <Tabs defaultValue="all" className="w-full">
            <TabsList className="mb-6 bg-white/5 border border-white/10">
              <TabsTrigger value="all">All</TabsTrigger>
              <TabsTrigger value="pending">Pending</TabsTrigger>
              <TabsTrigger value="payment_sent">Payment Sent</TabsTrigger>
              <TabsTrigger value="completed">Completed</TabsTrigger>
              <TabsTrigger value="cancelled">Cancelled</TabsTrigger>
              <TabsTrigger value="expired">Expired</TabsTrigger>
            </TabsList>

            <TabsContent value="all" className="glass-card p-8 rounded-xl border border-white/10">
              <h2 className="text-2xl font-bold mb-6">All Trades</h2>
              {trades.length === 0 ? (
                <div className="text-center py-12">
                  <p className="text-gray-400">No trades yet</p>
                </div>
              ) : (
                <div className="space-y-4">{trades.map((trade) => renderTradeCard(trade))}</div>
              )}
            </TabsContent>

            <TabsContent value="pending" className="glass-card p-8 rounded-xl border border-white/10">
              <h2 className="text-2xl font-bold mb-6">Pending Trades</h2>
              {pendingTrades.length === 0 ? (
                <div className="text-center py-12">
                  <p className="text-gray-400">No pending trades</p>
                </div>
              ) : (
                <div className="space-y-4">{pendingTrades.map((trade) => renderTradeCard(trade))}</div>
              )}
            </TabsContent>

            <TabsContent value="payment_sent" className="glass-card p-8 rounded-xl border border-white/10">
              <h2 className="text-2xl font-bold mb-6">Payment Sent Trades</h2>
              {paymentSentTrades.length === 0 ? (
                <div className="text-center py-12">
                  <p className="text-gray-400">No trades with payment sent</p>
                </div>
              ) : (
                <div className="space-y-4">{paymentSentTrades.map((trade) => renderTradeCard(trade))}</div>
              )}
            </TabsContent>

            <TabsContent value="completed" className="glass-card p-8 rounded-xl border border-white/10">
              <h2 className="text-2xl font-bold mb-6">Completed Trades</h2>
              {completedTrades.length === 0 ? (
                <div className="text-center py-12">
                  <p className="text-gray-400">No completed trades</p>
                </div>
              ) : (
                <div className="space-y-4">{completedTrades.map((trade) => renderTradeCard(trade))}</div>
              )}
            </TabsContent>

            <TabsContent value="cancelled" className="glass-card p-8 rounded-xl border border-white/10">
              <h2 className="text-2xl font-bold mb-6">Cancelled Trades</h2>
              {cancelledTrades.length === 0 ? (
                <div className="text-center py-12">
                  <p className="text-gray-400">No cancelled trades</p>
                </div>
              ) : (
                <div className="space-y-4">{cancelledTrades.map((trade) => renderTradeCard(trade))}</div>
              )}
            </TabsContent>

            <TabsContent value="expired" className="glass-card p-8 rounded-xl border border-white/10">
              <h2 className="text-2xl font-bold mb-6">Expired Trades</h2>
              {expiredTrades.length === 0 ? (
                <div className="text-center py-12">
                  <p className="text-gray-400">No expired trades</p>
                </div>
              ) : (
                <div className="space-y-4">{expiredTrades.map((trade) => renderTradeCard(trade))}</div>
              )}
            </TabsContent>
          </Tabs>
        </div>
      </main>
      <Footer />
    </div>
  )
}
