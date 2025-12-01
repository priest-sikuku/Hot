"use client"

import { useEffect, useState, useRef } from "react"
import { useParams, useRouter } from 'next/navigation'
import { ArrowLeft, User, CheckCircle, XCircle, Send, Clock, AlertCircle } from 'lucide-react'
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import Header from "@/components/header"
import Footer from "@/components/footer"
import { createClient } from "@/lib/supabase/client"

interface Trade {
  id: string
  ad_id: string
  buyer_id: string
  seller_id: string
  afx_amount: number // Renamed from gx_amount to afx_amount
  escrow_amount: number
  status: string
  is_paid: boolean | null // Added for two-step confirmation
  paid_at: string | null // Added for payment timestamp
  payment_confirmed_at: string | null
  coins_released_at: string | null
  released_at: string | null // Added for release timestamp
  expires_at: string
  expired_at: string | null // Added for expiry tracking
  cancelled_by: string | null // Added to track who cancelled
  cancelled_at: string | null // Added for cancellation timestamp
  created_at: string
  buyer_username?: string | null
  buyer_email?: string | null
  seller_username?: string | null
  seller_email?: string | null
  ad_account_number?: string | null
  ad_mpesa_number?: string | null
  ad_paybill_number?: string | null
  ad_airtel_money?: string | null
  ad_terms_of_trade?: string | null
  ad_full_name?: string | null
  ad_bank_name?: string | null
  ad_account_name?: string | null
  disputed_at?: string | null // Added for dispute timestamp
}

interface Message {
  id: string
  trade_id: string
  sender_id: string
  message: string
  created_at: string
}

export default function TradePage() {
  const params = useParams()
  const router = useRouter()
  const supabase = createClient()
  const [trade, setTrade] = useState<Trade | null>(null)
  const [loading, setLoading] = useState(true)
  const [currentUserId, setCurrentUserId] = useState<string | null>(null)
  const [actionLoading, setActionLoading] = useState(false)
  const [messages, setMessages] = useState<Message[]>([])
  const [newMessage, setNewMessage] = useState("")
  const [sendingMessage, setSendingMessage] = useState(false)
  const messagesEndRef = useRef<HTMLDivElement>(null)

  const [showRatingForm, setShowRatingForm] = useState(false)
  const [rating, setRating] = useState(0)
  const [ratingComment, setRatingComment] = useState("")
  const [submittingRating, setSubmittingRating] = useState(false)
  const [existingRating, setExistingRating] = useState<any>(null)

  const [timeRemaining, setTimeRemaining] = useState<string>("")

  const [showDisputeDialog, setShowDisputeDialog] = useState(false)
  const [disputeReason, setDisputeReason] = useState("")
  const [submittingDispute, setSubmittingDispute] = useState(false)

  useEffect(() => {
    fetchTrade()
    getCurrentUser()
    fetchMessages()
    checkExistingRating()
    const unsubscribe = subscribeToMessages()
    return () => {
      unsubscribe()
    }
  }, [params.id])

  useEffect(() => {
    if (!trade || trade.status === "completed" || trade.status === "cancelled" || trade.status === "expired") {
      return
    }

    const updateCountdown = () => {
      if (!trade.expires_at) return

      const now = new Date().getTime()
      const expiryTime = new Date(trade.expires_at).getTime()
      const distance = expiryTime - now

      if (distance < 0) {
        setTimeRemaining("Expired")
        return
      }

      const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60))
      const seconds = Math.floor((distance % (1000 * 60)) / 1000)

      setTimeRemaining(`${minutes}m ${seconds}s`)
    }

    updateCountdown()
    const interval = setInterval(updateCountdown, 1000)

    return () => clearInterval(interval)
  }, [trade])

  const [scrollToBottomTimeout, setScrollToBottomTimeout] = useState<NodeJS.Timeout | null>(null)

  useEffect(() => {
    if (scrollToBottomTimeout) {
      clearTimeout(scrollToBottomTimeout)
    }
    setScrollToBottomTimeout(setTimeout(scrollToBottom, 100))
  }, [messages])

  function scrollToBottom() {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" })
  }

  async function getCurrentUser() {
    const {
      data: { user },
    } = await supabase.auth.getUser()
    setCurrentUserId(user?.id || null)
  }

  async function fetchTrade() {
    try {
      const { data: tradeData, error: tradeError } = await supabase
        .from("p2p_trades")
        .select("*")
        .eq("id", params.id)
        .single()

      if (tradeError) {
        console.error("[v0] Error fetching trade:", tradeError)
        setLoading(false)
        return
      }

      if (!tradeData) {
        setLoading(false)
        return
      }

      // Fetch buyer profile
      const { data: buyerData } = await supabase
        .from("profiles")
        .select("username, email")
        .eq("id", tradeData.buyer_id)
        .single()

      // Fetch seller profile
      const { data: sellerData } = await supabase
        .from("profiles")
        .select("username, email")
        .eq("id", tradeData.seller_id)
        .single()

      // Fetch ad details
      const { data: adData } = await supabase
        .from("p2p_ads")
        .select(
          "account_number, mpesa_number, paybill_number, airtel_money, terms_of_trade, full_name, bank_name, account_name",
        )
        .eq("id", tradeData.ad_id)
        .single()

      // Combine all data
      const combinedTrade: Trade = {
        ...tradeData,
        buyer_username: buyerData?.username || null,
        buyer_email: buyerData?.email || null,
        seller_username: sellerData?.username || null,
        seller_email: sellerData?.email || null,
        ad_account_number: adData?.account_number || null,
        ad_mpesa_number: adData?.mpesa_number || null,
        ad_paybill_number: adData?.paybill_number || null,
        ad_airtel_money: adData?.airtel_money || null,
        ad_terms_of_trade: adData?.terms_of_trade || null,
        ad_full_name: adData?.full_name || null,
        ad_bank_name: adData?.bank_name || null,
        ad_account_name: adData?.account_name || null,
      }

      setTrade(combinedTrade)
    } catch (error) {
      console.error("[v0] Error:", error)
    } finally {
      setLoading(false)
    }
  }

  async function fetchMessages() {
    try {
      const { data, error } = await supabase
        .from("trade_messages")
        .select("*")
        .eq("trade_id", params.id)
        .order("created_at", { ascending: true })

      if (error) {
        console.error("[v0] Error fetching messages:", error)
        return
      }

      setMessages(data || [])
    } catch (error) {
      console.error("[v0] Error:", error)
    }
  }

  function subscribeToMessages() {
    const channel = supabase
      .channel(`trade_messages:${params.id}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "trade_messages",
          filter: `trade_id=eq.${params.id}`,
        },
        (payload) => {
          setMessages((prev) => [...prev, payload.new as Message])
        },
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }

  async function sendMessage() {
    if (!newMessage.trim() || !currentUserId) return

    try {
      setSendingMessage(true)
      const { error } = await supabase.from("trade_messages").insert({
        trade_id: params.id,
        sender_id: currentUserId,
        message: newMessage.trim(),
      })

      if (error) {
        console.error("[v0] Error sending message:", error)
        alert("Failed to send message")
        return
      }

      setNewMessage("")
    } catch (error) {
      console.error("[v0] Error:", error)
      alert("Failed to send message")
    } finally {
      setSendingMessage(false)
    }
  }

  async function markPaymentSent() {
    if (!trade || !currentUserId) return

    try {
      setActionLoading(true)
      const { error } = await supabase.rpc("mark_payment_sent", {
        p_trade_id: trade.id,
        p_buyer_id: currentUserId,
      })

      if (error) {
        alert(error.message || "Failed to mark payment as sent")
        return
      }

      alert("Payment marked as sent! Waiting for seller to release coins.")
      fetchTrade()
    } catch (error) {
      console.error("[v0] Error:", error)
      alert("Failed to mark payment as sent")
    } finally {
      setActionLoading(false)
    }
  }

  async function releaseCoins() {
    if (!trade || !currentUserId) return

    try {
      setActionLoading(true)
      const { error } = await supabase.rpc("release_p2p_coins", {
        p_trade_id: trade.id,
        p_seller_id: currentUserId,
      })

      if (error) {
        alert(error.message || "Failed to release coins")
        return
      }

      alert("Coins released successfully! Trade completed.")
      fetchTrade()
    } catch (error) {
      console.error("[v0] Error:", error)
      alert("Failed to release coins")
    } finally {
      setActionLoading(false)
    }
  }

  async function cancelTrade() {
    if (!trade || !currentUserId) return

    if (!confirm("Are you sure you want to cancel this trade? Coins will be returned to the seller.")) {
      return
    }

    try {
      setActionLoading(true)
      const { error } = await supabase.rpc("cancel_p2p_trade", {
        p_trade_id: trade.id,
        p_user_id: currentUserId,
      })

      if (error) {
        alert(error.message || "Failed to cancel trade")
        return
      }

      alert("Trade cancelled successfully")
      router.push("/p2p")
    } catch (error) {
      console.error("[v0] Error:", error)
      alert("Failed to cancel trade")
    } finally {
      setActionLoading(false)
    }
  }

  async function checkExistingRating() {
    const {
      data: { user },
    } = await supabase.auth.getUser()

    if (!user) return

    const { data } = await supabase
      .from("p2p_ratings")
      .select("*")
      .eq("trade_id", params.id)
      .eq("rater_id", user.id)
      .single()

    if (data) {
      setExistingRating(data)
    }
  }

  async function submitRating() {
    if (!trade || !currentUserId || rating === 0) return

    try {
      setSubmittingRating(true)
      const ratedUserId = currentUserId === trade.buyer_id ? trade.seller_id : trade.buyer_id

      const { error } = await supabase.from("p2p_ratings").insert({
        trade_id: trade.id,
        rater_id: currentUserId,
        rated_user_id: ratedUserId,
        rating: rating,
        comment: ratingComment.trim() || null,
      })

      if (error) {
        alert(error.message || "Failed to submit rating")
        return
      }

      alert("Rating submitted successfully!")
      setShowRatingForm(false)
      checkExistingRating()
    } catch (error) {
      console.error("[v0] Error:", error)
      alert("Failed to submit rating")
    } finally {
      setSubmittingRating(false)
    }
  }

  function getStatusBadge(status: string) {
    const statusConfig: Record<string, { label: string; color: string; icon: any }> = {
      pending: { label: "Pending", color: "bg-yellow-500/10 text-yellow-500 border-yellow-500/20", icon: Clock },
      escrowed: { label: "In Escrow", color: "bg-blue-500/10 text-blue-500 border-blue-500/20", icon: Clock },
      payment_sent: {
        label: "Payment Sent",
        color: "bg-cyan-500/10 text-cyan-500 border-cyan-500/20",
        icon: CheckCircle,
      },
      completed: { label: "Completed", color: "bg-green-500/10 text-green-500 border-green-500/20", icon: CheckCircle },
      cancelled: { label: "Cancelled", color: "bg-red-500/10 text-red-500 border-red-500/20", icon: XCircle },
      expired: { label: "Expired", color: "bg-gray-500/10 text-gray-500 border-gray-500/20", icon: AlertCircle },
      disputed: {
        label: "Disputed",
        color: "bg-orange-500/10 text-orange-500 border-orange-500/20",
        icon: AlertCircle,
      },
    }
    const config = statusConfig[status] || {
      label: status,
      color: "bg-white/10 text-white border-white/20",
      icon: Clock,
    }
    const Icon = config.icon

    return (
      <Badge variant="outline" className={`${config.color} flex items-center gap-1`}>
        <Icon size={14} />
        {config.label}
      </Badge>
    )
  }

  function getPaymentMethods() {
    if (!trade) return []

    const methods: Array<{ type: string; label: string; value: string; copyable: boolean }> = []

    if (trade.ad_mpesa_number) {
      methods.push({
        type: "M-Pesa Personal",
        label: "M-Pesa Number",
        value: trade.ad_mpesa_number,
        copyable: true,
      })
      if (trade.ad_full_name) {
        methods.push({
          type: "M-Pesa Personal",
          label: "Full Name",
          value: trade.ad_full_name,
          copyable: true,
        })
      }
    }

    if (trade.ad_paybill_number) {
      methods.push({
        type: "M-Pesa Paybill",
        label: "Paybill Number",
        value: trade.ad_paybill_number,
        copyable: true,
      })
      if (trade.ad_account_number) {
        methods.push({
          type: "M-Pesa Paybill",
          label: "Account Number",
          value: trade.ad_account_number,
          copyable: true,
        })
      }
    }

    if (trade.ad_bank_name) {
      methods.push({
        type: "Bank Transfer",
        label: "Bank Name",
        value: trade.ad_bank_name,
        copyable: false,
      })
      if (trade.ad_account_number) {
        methods.push({
          type: "Bank Transfer",
          label: "Account Number",
          value: trade.ad_account_number,
          copyable: true,
        })
      }
      if (trade.ad_account_name) {
        methods.push({
          type: "Bank Transfer",
          label: "Account Name",
          value: trade.ad_account_name,
          copyable: true,
        })
      }
    }

    if (trade.ad_airtel_money) {
      methods.push({
        type: "Airtel Money",
        label: "Airtel Number",
        value: trade.ad_airtel_money,
        copyable: true,
      })
      if (trade.ad_full_name) {
        methods.push({
          type: "Airtel Money",
          label: "Full Name",
          value: trade.ad_full_name,
          copyable: true,
        })
      }
    }

    return methods
  }

  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard
      .writeText(text)
      .then(() => {
        alert(`${label} copied to clipboard!`)
      })
      .catch(() => {
        alert("Failed to copy to clipboard")
      })
  }

  async function raiseDispute() {
    if (!trade || !currentUserId || !disputeReason.trim()) return

    if (!confirm("Are you sure you want to raise a dispute? This will halt the trade and notify admins.")) {
      return
    }

    try {
      setSubmittingDispute(true)
      const { error } = await supabase.rpc("raise_p2p_dispute", {
        p_trade_id: trade.id,
        p_user_id: currentUserId,
        p_reason: disputeReason.trim(),
      })

      if (error) {
        alert(error.message || "Failed to raise dispute")
        return
      }

      alert("Dispute raised successfully! An admin will review your case.")
      setShowDisputeDialog(false)
      setDisputeReason("")
      fetchTrade()
    } catch (error) {
      console.error("[v0] Error:", error)
      alert("Failed to raise dispute")
    } finally {
      setSubmittingDispute(false)
    }
  }

  const isBuyer = currentUserId === trade?.buyer_id
  const isSeller = currentUserId === trade?.seller_id

  if (loading) {
    return (
      <div className="min-h-screen flex flex-col bg-black">
        <Header />
        <main className="flex-1 flex items-center justify-center">
          <p className="text-gray-400">Loading trade...</p>
        </main>
        <Footer />
      </div>
    )
  }

  if (!trade) {
    return (
      <div className="min-h-screen flex flex-col bg-black">
        <Header />
        <main className="flex-1 flex items-center justify-center">
          <div className="text-center">
            <p className="text-gray-400 mb-4">Trade not found</p>
            <Button onClick={() => router.push("/p2p")}>Back to P2P</Button>
          </div>
        </main>
        <Footer />
      </div>
    )
  }

  return (
    <div className="min-h-screen flex flex-col bg-black">
      <Header />
      <main className="flex-1">
        <div className="max-w-7xl mx-auto px-6 py-12">
          <Button variant="ghost" className="mb-6 hover:bg-white/5" onClick={() => router.push("/p2p")}>
            <ArrowLeft size={20} className="mr-2" />
            Back to P2P
          </Button>

          <div className="mb-8">
            <div className="flex items-center justify-between mb-2">
              <h1 className="text-4xl font-bold">Trade Details</h1>
              {getStatusBadge(trade.status)}
            </div>
            <p className="text-gray-400">Trade ID: {trade.id}</p>
          </div>

          {trade.status !== "completed" &&
            trade.status !== "cancelled" &&
            trade.status !== "expired" &&
            timeRemaining && (
              <div className="glass-card p-4 rounded-xl border border-yellow-500/30 bg-yellow-500/10 mb-6">
                <div className="flex items-center gap-3">
                  <Clock size={20} className="text-yellow-400" />
                  <div>
                    <p className="font-semibold text-yellow-400">Time Remaining</p>
                    <p className="text-sm text-gray-300">{timeRemaining} until trade expires</p>
                  </div>
                </div>
              </div>
            )}

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div className="glass-card p-6 rounded-xl border border-white/10">
              <p className="text-gray-400 text-sm mb-2">Trade Amount</p>
              <p className="text-3xl font-bold text-green-400">{trade.afx_amount} AFX</p>
            </div>
            <div className="glass-card p-6 rounded-xl border border-white/10">
              <p className="text-gray-400 text-sm mb-2">Escrow Amount</p>
              <p className="text-3xl font-bold text-yellow-400">{trade.escrow_amount} AFX</p>
            </div>
            <div className="glass-card p-6 rounded-xl border border-white/10">
              <p className="text-gray-400 text-sm mb-2">Status</p>
              <div className="mt-2">{getStatusBadge(trade.status)}</div>
            </div>
          </div>

          {trade.is_paid && trade.status === "payment_sent" && (
            <div className="glass-card p-6 rounded-xl border border-cyan-500/30 bg-cyan-500/10 mb-6">
              <div className="flex items-center gap-3">
                <CheckCircle size={24} className="text-cyan-400" />
                <div className="flex-1">
                  <p className="font-semibold text-cyan-400">Payment Marked as Sent</p>
                  <p className="text-sm text-gray-300">
                    {isBuyer
                      ? "Waiting for seller to confirm and release coins"
                      : "Please confirm payment received and release coins to buyer"}
                  </p>
                </div>
                {trade.paid_at && <p className="text-xs text-gray-400">{new Date(trade.paid_at).toLocaleString()}</p>}
              </div>
            </div>
          )}

          <div className="glass-card p-8 rounded-xl border border-white/10 mb-6">
            <h3 className="text-xl font-semibold mb-4">Trade Information</h3>
            <div className="grid md:grid-cols-2 gap-6">
              <div className="space-y-4">
                <div>
                  <p className="text-sm text-gray-400 mb-1">Buyer</p>
                  <div className="flex items-center gap-2 p-3 bg-white/5 rounded-lg">
                    <User size={16} className="text-green-400" />
                    <p className="font-semibold">{trade.buyer_username || trade.buyer_email || "Anonymous"}</p>
                    {isBuyer && <span className="text-xs bg-blue-500/20 text-blue-400 px-2 py-1 rounded">You</span>}
                  </div>
                </div>
                <div>
                  <p className="text-sm text-gray-400 mb-1">Seller</p>
                  <div className="flex items-center gap-2 p-3 bg-white/5 rounded-lg">
                    <User size={16} className="text-red-400" />
                    <p className="font-semibold">{trade.seller_username || trade.seller_email || "Anonymous"}</p>
                    {isSeller && <span className="text-xs bg-blue-500/20 text-blue-400 px-2 py-1 rounded">You</span>}
                  </div>
                </div>
              </div>

              <div className="space-y-4">
                <div>
                  <p className="text-sm text-gray-400 mb-1">Created</p>
                  <p className="text-sm p-3 bg-white/5 rounded-lg">{new Date(trade.created_at).toLocaleString()}</p>
                </div>
                {trade.expires_at && (
                  <div>
                    <p className="text-sm text-gray-400 mb-1">Expires</p>
                    <p className="text-sm p-3 bg-white/5 rounded-lg">{new Date(trade.expires_at).toLocaleString()}</p>
                  </div>
                )}
              </div>
            </div>
          </div>

          <div className="glass-card p-8 rounded-xl border border-white/10 mb-6">
            <h3 className="text-xl font-semibold mb-4">Payment Details</h3>
            {getPaymentMethods().length > 0 ? (
              <div className="space-y-3">
                {getPaymentMethods().map((method, index) => (
                  <div
                    key={index}
                    className="flex items-center justify-between p-3 bg-white/5 rounded-lg border border-white/5"
                  >
                    <div className="flex-1">
                      <p className="text-xs text-gray-400 mb-1">{method.label}</p>
                      <p className="text-sm font-semibold text-white">{method.value}</p>
                    </div>
                    {method.copyable && (
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => copyToClipboard(method.value, method.label)}
                        className="ml-4 border-white/10 hover:bg-white/10"
                      >
                        Copy
                      </Button>
                    )}
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-sm text-gray-400">No payment details specified</p>
            )}

            {trade.ad_terms_of_trade && (
              <div className="mt-4">
                <p className="text-sm text-gray-400 mb-2">Terms of Trade</p>
                <p className="text-sm p-3 bg-white/5 rounded-lg border border-white/10">{trade.ad_terms_of_trade}</p>
              </div>
            )}
          </div>

          <div className="glass-card p-8 rounded-xl border border-white/10 mb-6">
            <h3 className="text-xl font-semibold mb-4">Trade Chat</h3>
            <div className="bg-black/20 rounded-lg p-4 h-64 overflow-y-auto mb-4 border border-white/5">
              {messages.length === 0 ? (
                <p className="text-center text-gray-500 text-sm">No messages yet. Start the conversation!</p>
              ) : (
                <div className="space-y-3">
                  {messages.map((msg) => (
                    <div
                      key={msg.id}
                      className={`flex ${msg.sender_id === currentUserId ? "justify-end" : "justify-start"}`}
                    >
                      <div
                        className={`max-w-[70%] rounded-lg p-3 ${
                          msg.sender_id === currentUserId ? "bg-blue-600 text-white" : "bg-white/10 text-gray-200"
                        }`}
                      >
                        <p className="text-sm">{msg.message}</p>
                        <p className="text-xs opacity-70 mt-1">{new Date(msg.created_at).toLocaleTimeString()}</p>
                      </div>
                    </div>
                  ))}
                  <div ref={messagesEndRef} />
                </div>
              )}
            </div>
            <div className="flex gap-2">
              <Input
                placeholder="Type your message..."
                value={newMessage}
                onChange={(e) => setNewMessage(e.target.value)}
                onKeyPress={(e) => e.key === "Enter" && sendMessage()}
                disabled={
                  sendingMessage ||
                  trade.status === "completed" ||
                  trade.status === "cancelled" ||
                  trade.status === "expired"
                }
                className="bg-white/5 border-white/10"
              />
              <Button
                onClick={sendMessage}
                disabled={
                  sendingMessage ||
                  !newMessage.trim() ||
                  trade.status === "completed" ||
                  trade.status === "cancelled" ||
                  trade.status === "expired"
                }
                className="bg-gradient-to-r from-green-500 to-green-600 text-black hover:shadow-lg hover:shadow-green-500/50 transition"
              >
                <Send size={18} />
              </Button>
            </div>
          </div>

          {/* Action Buttons */}
          {trade.status !== "completed" && trade.status !== "cancelled" && trade.status !== "expired" && trade.status !== "disputed" && (
            <div className="glass-card p-6 rounded-lg border border-white/10 mb-6">
              <h3 className="text-lg font-semibold mb-4">Actions</h3>
              <div className="flex flex-wrap gap-3">
                {isBuyer && (trade.status === "pending" || trade.status === "escrowed") && !trade.is_paid && (
                  <Button
                    onClick={markPaymentSent}
                    disabled={actionLoading}
                    className="bg-gradient-to-r from-green-500 to-green-600 text-black hover:shadow-lg hover:shadow-green-500/50 transition"
                  >
                    <CheckCircle size={18} className="mr-2" />
                    {actionLoading ? "Processing..." : "I Have Paid"}
                  </Button>
                )}

                {isSeller && (trade.status === "payment_sent" || trade.status === "escrowed") && (
                  <Button
                    onClick={releaseCoins}
                    disabled={actionLoading || !trade.is_paid}
                    className="bg-gradient-to-r from-blue-600 to-blue-700 hover:shadow-lg hover:shadow-blue-500/50 transition text-white disabled:opacity-50 disabled:cursor-not-allowed"
                    title={!trade.is_paid ? "Waiting for buyer to mark payment as sent" : "Release coins to buyer"}
                  >
                    <CheckCircle size={18} className="mr-2" />
                    {actionLoading ? "Processing..." : "Release Coins"}
                  </Button>
                )}

                {(!trade.is_paid || isSeller) && (
                  <Button
                    onClick={cancelTrade}
                    disabled={actionLoading}
                    variant="destructive"
                    title={
                      trade.is_paid && isBuyer ? "Cannot cancel after marking payment as sent" : "Cancel this trade"
                    }
                  >
                    <XCircle size={18} className="mr-2" />
                    {actionLoading ? "Processing..." : "Cancel Trade"}
                  </Button>
                )}

                {(isBuyer || isSeller) && (
                  <Button
                    onClick={() => setShowDisputeDialog(true)}
                    disabled={actionLoading}
                    variant="outline"
                    className="border-orange-500/50 text-orange-400 hover:bg-orange-500/10"
                  >
                    <AlertCircle size={18} className="mr-2" />
                    Report Problem
                  </Button>
                )}

                {trade.is_paid && isBuyer && (
                  <p className="text-sm text-gray-400 flex items-center gap-2">
                    <AlertCircle size={16} />
                    Cannot cancel after marking payment as sent
                  </p>
                )}
              </div>
            </div>
          )}

          {trade.status === "disputed" && (
            <div className="glass-card p-6 bg-orange-500/10 border-orange-500/20 rounded-lg mb-6">
              <div className="flex items-center gap-3">
                <AlertCircle size={24} className="text-orange-400" />
                <div className="flex-1">
                  <p className="font-semibold text-orange-400">Trade Under Dispute</p>
                  <p className="text-sm text-gray-300">
                    This trade has been disputed and is under admin review. Funds are securely held in escrow.
                  </p>
                  {trade.disputed_at && (
                    <p className="text-xs text-gray-400 mt-1">
                      Disputed at: {new Date(trade.disputed_at).toLocaleString()}
                    </p>
                  )}
                </div>
              </div>
            </div>
          )}

          {showDisputeDialog && (
            <div className="fixed inset-0 bg-black/80 flex items-center justify-center p-4 z-50">
              <div className="glass-card p-6 rounded-lg border border-white/10 max-w-md w-full">
                <h3 className="text-xl font-semibold mb-4 flex items-center gap-2">
                  <AlertCircle size={24} className="text-orange-400" />
                  Report a Problem
                </h3>
                <p className="text-sm text-gray-400 mb-4">
                  Raising a dispute will halt this trade and notify our admins. Funds will remain securely in escrow until resolved.
                </p>
                <div className="space-y-4">
                  <div>
                    <label className="text-sm text-gray-400 mb-2 block">Describe the issue:</label>
                    <textarea
                      value={disputeReason}
                      onChange={(e) => setDisputeReason(e.target.value)}
                      placeholder="E.g., Payment sent but seller not responding, wrong amount received, etc."
                      className="w-full p-3 bg-white/5 border border-white/10 rounded-lg text-white resize-none"
                      rows={4}
                    />
                  </div>
                  <div className="flex gap-3">
                    <Button
                      onClick={raiseDispute}
                      disabled={submittingDispute || !disputeReason.trim()}
                      className="flex-1 bg-gradient-to-r from-orange-500 to-orange-600 text-white hover:shadow-lg hover:shadow-orange-500/50 transition"
                    >
                      {submittingDispute ? "Submitting..." : "Submit Dispute"}
                    </Button>
                    <Button
                      onClick={() => {
                        setShowDisputeDialog(false)
                        setDisputeReason("")
                      }}
                      variant="outline"
                      className="border-white/10 hover:bg-white/10"
                    >
                      Cancel
                    </Button>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Completed Message */}
          {trade.status === "completed" && (
            <div className="glass-card p-8 bg-green-500/10 border-green-500/20 rounded-lg mb-6">
              <div className="flex items-center gap-3">
                <CheckCircle size={24} className="text-green-400" />
                <div>
                  <p className="font-semibold text-green-400">Trade Completed!</p>
                  <p className="text-sm text-gray-400">AFX coins have been successfully transferred to the buyer.</p>
                  {trade.released_at && (
                    <p className="text-xs text-gray-500 mt-1">
                      Released at: {new Date(trade.released_at).toLocaleString()}
                    </p>
                  )}
                </div>
              </div>
            </div>
          )}

          {trade.status === "cancelled" && (
            <div className="glass-card p-8 bg-red-500/10 border-red-500/20 rounded-lg mb-6">
              <div className="flex items-center gap-3">
                <XCircle size={24} className="text-red-400" />
                <div>
                  <p className="font-semibold text-red-400">Trade Cancelled</p>
                  <p className="text-sm text-gray-400">This trade has been cancelled and coins returned to seller.</p>
                  {trade.cancelled_at && (
                    <p className="text-xs text-gray-500 mt-1">
                      Cancelled at: {new Date(trade.cancelled_at).toLocaleString()}
                    </p>
                  )}
                </div>
              </div>
            </div>
          )}

          {trade.status === "expired" && (
            <div className="glass-card p-8 bg-gray-500/10 border-gray-500/20 rounded-lg mb-6">
              <div className="flex items-center gap-3">
                <AlertCircle size={24} className="text-gray-400" />
                <div>
                  <p className="font-semibold text-gray-400">Trade Expired</p>
                  <p className="text-sm text-gray-400">
                    This trade expired after 30 minutes and coins were returned to seller.
                  </p>
                  {trade.expired_at && (
                    <p className="text-xs text-gray-500 mt-1">
                      Expired at: {new Date(trade.expired_at).toLocaleString()}
                    </p>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* Rating Section */}
          {trade.status === "completed" && (isBuyer || isSeller) && (
            <div className="glass-card p-8 rounded-lg border border-white/10 mb-6">
              <h3 className="text-xl font-semibold mb-4">Rate Your Trading Partner</h3>

              {existingRating ? (
                <div className="bg-green-500/10 border border-green-500/20 rounded-lg p-4">
                  <p className="text-green-400 font-semibold mb-2">You rated this trade</p>
                  <div className="flex items-center gap-2 mb-2">
                    {[1, 2, 3, 4, 5].map((star) => (
                      <span key={star} className={star <= existingRating.rating ? "text-yellow-400" : "text-gray-600"}>
                        ★
                      </span>
                    ))}
                    <span className="text-sm text-gray-400">({existingRating.rating}/5)</span>
                  </div>
                  {existingRating.comment && <p className="text-sm text-gray-300 mt-2">{existingRating.comment}</p>}
                </div>
              ) : showRatingForm ? (
                <div className="space-y-4">
                  <div>
                    <p className="text-sm text-gray-400 mb-2">Select Rating</p>
                    <div className="flex gap-2">
                      {[1, 2, 3, 4, 5].map((star) => (
                        <button
                          key={star}
                          onClick={() => setRating(star)}
                          className={`text-4xl transition ${
                            star <= rating ? "text-yellow-400" : "text-gray-600 hover:text-yellow-400"
                          }`}
                        >
                          ★
                        </button>
                      ))}
                    </div>
                  </div>

                  <div>
                    <p className="text-sm text-gray-400 mb-2">Comment (Optional)</p>
                    <Input
                      placeholder="Share your experience..."
                      value={ratingComment}
                      onChange={(e) => setRatingComment(e.target.value)}
                      className="bg-white/5 border-white/10"
                    />
                  </div>

                  <div className="flex gap-3">
                    <Button
                      onClick={submitRating}
                      disabled={submittingRating || rating === 0}
                      className="bg-gradient-to-r from-green-500 to-green-600 text-black hover:shadow-lg hover:shadow-green-500/50 transition"
                    >
                      {submittingRating ? "Submitting..." : "Submit Rating"}
                    </Button>
                    <Button
                      onClick={() => setShowRatingForm(false)}
                      variant="outline"
                      className="border-white/10 hover:bg-white/10"
                    >
                      Cancel
                    </Button>
                  </div>
                </div>
              ) : (
                <Button
                  onClick={() => setShowRatingForm(true)}
                  className="bg-gradient-to-r from-blue-600 to-blue-700 hover:shadow-lg hover:shadow-blue-500/50 transition text-white"
                >
                  Rate {isBuyer ? "Seller" : "Buyer"}
                </Button>
              )}
            </div>
          )}
        </div>
      </main>
      <Footer />
    </div>
  )
}
