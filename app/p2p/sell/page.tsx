"use client"

import { useEffect, useState } from "react"
import { ArrowLeft, User, Clock, Star } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import Header from "@/components/header"
import Footer from "@/components/footer"
import { createClient } from "@/lib/supabase/client"
import { useRouter } from "next/navigation"

interface Ad {
  id: string
  user_id: string
  afx_amount: number
  min_amount: number
  max_amount: number
  account_number: string | null
  mpesa_number: string | null
  paybill_number: string | null
  airtel_money: string | null
  terms_of_trade: string | null
  created_at: string
  profiles: {
    username: string | null
    email: string | null
    rating: number | null
  }
  remaining_amount?: number
  price_per_afx?: number
}

export default function SellAFXPage() {
  const [ads, setAds] = useState<Ad[]>([])
  const [loading, setLoading] = useState(true)
  const [initiatingTrade, setInitiatingTrade] = useState<string | null>(null)
  const [currentUserId, setCurrentUserId] = useState<string | null>(null)
  const [tradeAmounts, setTradeAmounts] = useState<{ [key: string]: string }>({})
  const router = useRouter()
  const supabase = createClient()

  useEffect(() => {
    fetchBuyAds()
    getCurrentUser()
  }, [])

  async function getCurrentUser() {
    const {
      data: { user },
    } = await supabase.auth.getUser()
    setCurrentUserId(user?.id || null)
  }

  async function fetchBuyAds() {
    try {
      const { data, error } = await supabase
        .from("p2p_ads")
        .select(`
          *,
          profiles:user_id (
            username,
            email,
            rating
          )
        `)
        .eq("ad_type", "buy")
        .eq("status", "active")
        .gt("expires_at", new Date().toISOString())
        .order("created_at", { ascending: false })

      if (error) {
        console.error("[v0] Error fetching ads:", error)
        return
      }

      setAds(data || [])
    } catch (error) {
      console.error("[v0] Error:", error)
    } finally {
      setLoading(false)
    }
  }

  async function initiateTrade(ad: Ad) {
    try {
      setInitiatingTrade(ad.id)

      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) {
        alert("Please sign in to trade")
        return
      }

      if (user.id === ad.user_id) {
        alert("You cannot trade with yourself")
        setInitiatingTrade(null)
        return
      }

      const customAmount = Number.parseFloat(tradeAmounts[ad.id] || "0")
      const tradeAmount = customAmount > 0 ? customAmount : ad.min_amount
      const availableAmount = ad.remaining_amount || ad.afx_amount

      if (tradeAmount < 2) {
        alert("Minimum trade amount is 2 AFX")
        setInitiatingTrade(null)
        return
      }

      if (tradeAmount > availableAmount) {
        alert(`Maximum available amount is ${availableAmount} AFX`)
        setInitiatingTrade(null)
        return
      }

      const { data: tradeId, error } = await supabase.rpc("initiate_p2p_trade_v2", {
        p_ad_id: ad.id,
        p_initiator_id: user.id,
        p_afx_amount: tradeAmount,
      })

      if (error) {
        console.error("[v0] Error initiating trade:", error)
        alert(error.message || "Failed to initiate trade")
        return
      }

      console.log("[v0] Trade initiated successfully, redirecting to trade page")
      router.push(`/p2p/trade/${tradeId}`)
    } catch (error) {
      console.error("[v0] Error:", error)
      alert("Failed to initiate trade")
    } finally {
      setInitiatingTrade(null)
    }
  }

  function getPaymentMethods(ad: Ad): string {
    const methods: string[] = []

    if (ad.mpesa_number) methods.push("M-Pesa")
    if (ad.paybill_number) methods.push("M-Pesa Paybill")
    if (ad.airtel_money) methods.push("Airtel Money")

    // Parse account_number for concatenated payment methods
    if (ad.account_number) {
      const accountStr = ad.account_number.toLowerCase()

      if (accountStr.includes("m-pesa") && !ad.mpesa_number) {
        if (accountStr.includes("paybill")) {
          methods.push("M-Pesa Paybill")
        } else {
          methods.push("M-Pesa")
        }
      }
      if (accountStr.includes("bank")) {
        methods.push("Bank Transfer")
      }
      if (accountStr.includes("airtel") && !ad.airtel_money) {
        methods.push("Airtel Money")
      }

      // If no keywords found, treat as bank account
      if (methods.length === 0 && ad.account_number.length > 0) {
        methods.push("Bank Transfer")
      }
    }

    return methods.length > 0 ? methods.join(", ") : "Not specified"
  }

  return (
    <div className="min-h-screen flex flex-col">
      <Header />
      <main className="flex-1">
        <div className="max-w-7xl mx-auto px-6 py-12">
          <div className="mb-8">
            <Button variant="ghost" className="mb-4 hover:bg-white/5" onClick={() => router.push("/p2p")}>
              <ArrowLeft size={20} className="mr-2" />
              Back to P2P
            </Button>
            <h1 className="text-4xl font-bold mb-2">Sell AFX</h1>
            <p className="text-gray-400">Browse available buy offers and sell AFX to other users</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div className="glass-card p-8 rounded-xl border border-white/10">
              <div className="text-center">
                <div className="text-5xl font-bold text-red-400 mb-2">{ads.length}</div>
                <p className="text-gray-400">Available Ads</p>
              </div>
            </div>
            <div className="glass-card p-8 rounded-xl border border-white/10">
              <div className="text-center">
                <div className="text-5xl font-bold text-purple-400 mb-2">
                  {ads.reduce((sum, ad) => sum + (ad.remaining_amount || ad.afx_amount), 0).toFixed(2)}
                </div>
                <p className="text-gray-400">Total AFX Wanted</p>
              </div>
            </div>
            <div className="glass-card p-8 rounded-xl border border-white/10">
              <div className="text-center">
                <div className="text-5xl font-bold text-yellow-400 mb-2">
                  {ads.length > 0
                    ? (ads.reduce((sum, ad) => sum + (ad.remaining_amount || ad.afx_amount), 0) / ads.length).toFixed(2)
                    : "0"}
                </div>
                <p className="text-gray-400">Avg. Amount</p>
              </div>
            </div>
          </div>

          <div className="glass-card p-8 rounded-xl border border-white/10">
            <h2 className="text-2xl font-bold mb-6">Available Buy Offers</h2>

            {loading ? (
              <div className="text-center py-12">
                <p className="text-gray-400">Loading ads...</p>
              </div>
            ) : ads.length === 0 ? (
              <div className="text-center py-12">
                <p className="text-gray-400 mb-4">No buy ads available at the moment</p>
              </div>
            ) : (
              <div className="space-y-4">
                {ads.map((ad) => (
                  <div
                    key={ad.id}
                    className="p-4 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition"
                  >
                    <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                      <div className="flex-1">
                        <div className="flex items-center gap-3 mb-3">
                          <div className="p-2 rounded-lg bg-red-500/10">
                            <User size={20} className="text-red-400" />
                          </div>
                          <div className="flex-1">
                            <div className="flex items-center gap-2">
                              <span className="font-semibold text-white">
                                {ad.profiles?.username || ad.profiles?.email || "Anonymous"}
                              </span>
                              {currentUserId === ad.user_id && (
                                <span className="text-xs bg-blue-500/20 text-blue-400 px-2 py-1 rounded">Your Ad</span>
                              )}
                            </div>
                            <div className="flex items-center gap-1 mt-1">
                              {[1, 2, 3, 4, 5].map((star) => (
                                <Star
                                  key={star}
                                  size={14}
                                  className={
                                    star <= Math.floor(Number(ad.profiles?.rating || 0))
                                      ? "fill-yellow-400 text-yellow-400"
                                      : "text-gray-600"
                                  }
                                />
                              ))}
                              <span className="text-sm text-gray-400 ml-1">
                                {ad.profiles?.rating ? Number(ad.profiles.rating).toFixed(1) : "No ratings"}
                              </span>
                            </div>
                          </div>
                        </div>

                        <div className="grid grid-cols-2 gap-4 mb-3">
                          <div>
                            <p className="text-sm text-gray-400">Amount</p>
                            <p className="font-bold text-lg text-red-400">{ad.remaining_amount || ad.afx_amount} AFX</p>
                            <p className="text-xs text-gray-500">Available</p>
                          </div>
                          <div>
                            <p className="text-sm text-gray-400">Price per AFX</p>
                            <p className="font-semibold text-white">{ad.price_per_afx || "N/A"} KES</p>
                          </div>
                        </div>

                        <div className="mb-3">
                          <p className="text-sm text-gray-400">Payment Methods</p>
                          <p className="text-sm text-white">{getPaymentMethods(ad)}</p>
                        </div>

                        {ad.terms_of_trade && (
                          <div className="mb-3">
                            <p className="text-sm text-gray-400">Terms</p>
                            <p className="text-sm text-gray-300 italic">"{ad.terms_of_trade}"</p>
                          </div>
                        )}

                        <div className="flex items-center gap-2 text-xs text-gray-500">
                          <Clock size={14} />
                          <span>Posted {new Date(ad.created_at).toLocaleDateString()}</span>
                        </div>
                      </div>

                      <div className="flex flex-col gap-3">
                        {currentUserId !== ad.user_id && (
                          <div className="space-y-2">
                            <Label htmlFor={`amount-${ad.id}`} className="text-sm text-gray-400">
                              Amount to sell (AFX)
                            </Label>
                            <Input
                              id={`amount-${ad.id}`}
                              type="number"
                              min="2"
                              max={ad.remaining_amount || ad.afx_amount}
                              step="0.01"
                              placeholder={`Min: 2, Max: ${ad.remaining_amount || ad.afx_amount}`}
                              value={tradeAmounts[ad.id] || ""}
                              onChange={(e) => setTradeAmounts((prev) => ({ ...prev, [ad.id]: e.target.value }))}
                              className="bg-white/5 border-white/10 text-white"
                            />
                          </div>
                        )}
                        <Button
                          className="px-6 py-3 rounded-lg bg-gradient-to-r from-red-600 to-red-700 text-white font-semibold hover:shadow-lg hover:shadow-red-500/50 transition"
                          onClick={() => initiateTrade(ad)}
                          disabled={initiatingTrade === ad.id || currentUserId === ad.user_id}
                        >
                          {currentUserId === ad.user_id
                            ? "Your Ad"
                            : initiatingTrade === ad.id
                              ? "Initiating..."
                              : "Sell Now"}
                        </Button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </main>
      <Footer />
    </div>
  )
}
