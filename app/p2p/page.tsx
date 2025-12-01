"use client"

import { Shield, Star, Plus, TrendingUp, History, ListChecks } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import Header from "@/components/header"
import Footer from "@/components/footer"
import { useRouter } from "next/navigation"
import Link from "next/link"
import { useEffect, useState } from "react"
import { createClient } from "@/lib/supabase/client"
import { BalanceTransferModal } from "@/components/balance-transfer-modal"
import { fetchAdsWithFilters, type AdFilters } from "@/lib/p2p-filters"

interface Ad {
  id: string
  user_id: string
  ad_type: string
  afx_amount: number
  min_amount: number
  max_amount: number
  account_number: string | null
  mpesa_number: string | null
  paybill_number: string | null
  airtel_money: string | null
  payment_methods_selected?: Array<{ id: string; code: string; name: string }> | null
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

interface UserStats {
  total_trades: number
  completed_trades: number
  completion_rate: number
  average_rating: number
  total_ratings: number
}

export default function P2PMarket() {
  const router = useRouter()
  const supabase = createClient()

  const [activeTab, setActiveTab] = useState<"buy" | "sell">("buy")
  const [ads, setAds] = useState<Ad[]>([])
  const [loading, setLoading] = useState(true)
  const [p2pBalance, setP2pBalance] = useState<number>(0)
  const [dashboardBalance, setDashboardBalance] = useState<number>(0)
  const [showTransferModal, setShowTransferModal] = useState(false)
  const [isLoading, setIsLoading] = useState(true)
  const [currentUserId, setCurrentUserId] = useState<string | null>(null)
  const [initiatingTrade, setInitiatingTrade] = useState<string | null>(null)
  const [tradeAmounts, setTradeAmounts] = useState<{ [key: string]: string }>({})

  const [userStats, setUserStats] = useState<{ [key: string]: UserStats }>({})
  const [filters, setFilters] = useState<AdFilters>({})

  const fetchBalance = async () => {
    const {
      data: { user },
    } = await supabase.auth.getUser()

    if (!user) {
      setIsLoading(false)
      return
    }

    const { data: coins } = await supabase
      .from("coins")
      .select("amount")
      .eq("user_id", user.id)
      .eq("status", "available")

    if (coins) {
      const totalBalance = coins.reduce((sum, coin) => sum + Number(coin.amount), 0)
      setDashboardBalance(totalBalance)
    }

    const { data: tradeCoins } = await supabase
      .from("trade_coins")
      .select("amount")
      .eq("user_id", user.id)
      .eq("status", "available")

    if (tradeCoins) {
      const totalP2PBalance = tradeCoins.reduce((sum, coin) => sum + Number(coin.amount), 0)
      setP2pBalance(totalP2PBalance)
    }

    setIsLoading(false)
  }

  useEffect(() => {
    fetchBalance()
    getCurrentUser()
    const interval = setInterval(fetchBalance, 5000)
    return () => clearInterval(interval)
  }, [])

  useEffect(() => {
    fetchAds()
  }, [activeTab, filters])

  async function getCurrentUser() {
    const {
      data: { user },
    } = await supabase.auth.getUser()
    setCurrentUserId(user?.id || null)
  }

  async function fetchAds() {
    setLoading(true)
    try {
      const adType = activeTab === "buy" ? "sell" : "buy"

      const data = await fetchAdsWithFilters(adType, filters)

      setAds(data || [])

      if (data && data.length > 0) {
        const uniqueUserIds = [...new Set(data.map((ad) => ad.user_id))]
        await fetchUserStats(uniqueUserIds)
      }
    } catch (error) {
      console.error("[v0] Error:", error)
    } finally {
      setLoading(false)
    }
  }

  async function fetchUserStats(userIds: string[]) {
    const statsPromises = userIds.map(async (userId) => {
      const { data, error } = await supabase.rpc("get_user_p2p_stats", { p_user_id: userId }).single()

      if (error) {
        console.error(`[v0] Error fetching stats for user ${userId}:`, error)
        return { userId, stats: null }
      }

      return { userId, stats: data }
    })

    const results = await Promise.all(statsPromises)
    const statsMap: { [key: string]: UserStats } = {}

    results.forEach(({ userId, stats }) => {
      if (stats) {
        statsMap[userId] = stats
      }
    })

    setUserStats(statsMap)
  }

  async function initiateTrade(ad: Ad) {
    try {
      setInitiatingTrade(ad.id)

      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) {
        router.push(`/auth/sign-in?next=/p2p&message=Please log in to start trading`)
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
        p_buyer_id: user.id,
        p_afx_amount: tradeAmount,
      })

      if (error) {
        console.error("[v0] Error initiating trade:", error)
        alert(error.message || "Failed to initiate trade")
        return
      }

      router.push(`/p2p/trade/${tradeId}`)
    } catch (error) {
      console.error("[v0] Error:", error)
      alert("Failed to initiate trade")
    } finally {
      setInitiatingTrade(null)
    }
  }

  function getPaymentMethods(ad: Ad): { name: string; color: string }[] {
    const methods: { name: string; color: string }[] = []

    if (
      ad.payment_methods_selected &&
      Array.isArray(ad.payment_methods_selected) &&
      ad.payment_methods_selected.length > 0
    ) {
      ad.payment_methods_selected.forEach((method: any) => {
        if (method.code === "mpesa") {
          methods.push({ name: "M-Pesa", color: "bg-green-500" })
        } else if (method.code === "mpesa_paybill") {
          methods.push({ name: "M-Pesa Paybill", color: "bg-yellow-500" })
        } else if (method.code === "bank_transfer") {
          methods.push({ name: "Bank Transfer", color: "bg-blue-500" })
        } else if (method.code === "airtel_money") {
          methods.push({ name: "Airtel Money", color: "bg-red-500" })
        }
      })
      return methods
    }

    // Fallback to individual payment method fields for legacy ads
    if (ad.mpesa_number) {
      methods.push({ name: "M-Pesa", color: "bg-green-500" })
    }
    if (ad.paybill_number) {
      methods.push({ name: "M-Pesa Paybill", color: "bg-yellow-500" })
    }
    if (ad.airtel_money) {
      methods.push({ name: "Airtel Money", color: "bg-red-500" })
    }
    if (ad.account_number) {
      methods.push({ name: "Bank Transfer", color: "bg-blue-500" })
    }

    return methods
  }

  function renderStarRating(rating: number) {
    const stars = []
    const fullStars = Math.floor(rating)
    const hasHalfStar = rating % 1 >= 0.5

    for (let i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.push(<Star key={i} size={12} className="fill-yellow-500 text-yellow-500" />)
      } else if (i === fullStars && hasHalfStar) {
        stars.push(<Star key={i} size={12} className="fill-yellow-500/50 text-yellow-500" />)
      } else {
        stars.push(<Star key={i} size={12} className="text-gray-600" />)
      }
    }

    return stars
  }

  return (
    <div className="min-h-screen flex flex-col bg-black">
      <Header />
      <main className="flex-1">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 py-8">
          <div className="mb-8">
            <h1 className="text-3xl md:text-4xl font-bold mb-2">P2P Trading</h1>
            <p className="text-gray-400">Kenya Only • Buy and Sell AFX with KES</p>
          </div>

          <div className="flex flex-wrap gap-3 mb-8">
            <Link href="/p2p/post-ad">
              <Button className="bg-green-500 hover:bg-green-600 text-black font-semibold gap-2">
                <Plus size={18} />
                Post Ad
              </Button>
            </Link>
            <button
              onClick={() => setShowTransferModal(true)}
              className="px-4 py-2 rounded-lg bg-blue-500/20 hover:bg-blue-500/30 text-blue-400 border border-blue-500/50 font-semibold gap-2 inline-flex items-center transition"
            >
              <TrendingUp size={18} />
              Transfer Balance
            </button>
            <Link href="/p2p/my-trades">
              <Button className="px-4 py-2 rounded-lg bg-purple-500/20 hover:bg-purple-500/30 text-purple-400 border border-purple-500/50 font-semibold gap-2 transition">
                <History size={18} />
                My Trades
              </Button>
            </Link>
            <Link href="/p2p/my-ads">
              <Button className="px-4 py-2 rounded-lg bg-yellow-500/20 hover:bg-yellow-500/30 text-yellow-400 border border-yellow-500/50 font-semibold gap-2 transition">
                <ListChecks size={18} />
                My Ads
              </Button>
            </Link>
          </div>

          {/* Tabs */}
          <div className="flex gap-4 mb-8 border-b border-white/10">
            <button
              onClick={() => setActiveTab("buy")}
              className={`px-4 py-3 font-semibold transition-colors border-b-2 ${
                activeTab === "buy"
                  ? "border-[#0ecb81] text-[#0ecb81]"
                  : "border-transparent text-gray-400 hover:text-white"
              }`}
            >
              Buy AFX
            </button>
            <button
              onClick={() => setActiveTab("sell")}
              className={`px-4 py-3 font-semibold transition-colors border-b-2 ${
                activeTab === "sell"
                  ? "border-[#f6465d] text-[#f6465d]"
                  : "border-transparent text-gray-400 hover:text-white"
              }`}
            >
              Sell AFX
            </button>
          </div>

          {/* Main content */}
          <div className="w-full">
            {loading ? (
              <div className="text-center py-20">
                <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-[#0ecb81]" />
                <p className="text-gray-400 mt-4">Loading offers...</p>
              </div>
            ) : ads.length === 0 ? (
              <div className="text-center py-20 bg-[#1a1d24] rounded-xl border border-white/5">
                <p className="text-gray-400 mb-2">No {activeTab === "buy" ? "sell" : "buy"} offers available</p>
                <p className="text-sm text-gray-500">Be the first to post an ad!</p>
              </div>
            ) : (
              <div className="space-y-3">
                {ads.map((ad, index) => {
                  const isPromoted = index === 0
                  const stats = userStats[ad.user_id] || {
                    total_trades: 0,
                    completed_trades: 0,
                    completion_rate: 0,
                    average_rating: 0,
                    total_ratings: 0,
                  }

                  return (
                    <div
                      key={ad.id}
                      className={`bg-[#1a1d24] rounded-xl p-5 border transition-all hover:border-white/20 ${
                        isPromoted ? "border-yellow-500/50 shadow-lg shadow-yellow-500/10" : "border-white/5"
                      }`}
                    >
                      {isPromoted && (
                        <div className="mb-3 flex items-center gap-2">
                          <div className="bg-yellow-500/20 text-yellow-500 text-xs font-semibold px-2 py-1 rounded">
                            ⭐ PROMOTED
                          </div>
                        </div>
                      )}

                      <div className="flex flex-col lg:flex-row gap-6">
                        <div className="flex-shrink-0 lg:w-48">
                          <div className="flex items-start gap-3 mb-3">
                            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-[#0ecb81] to-[#0ea76f] flex items-center justify-center text-white font-bold">
                              {(ad.profiles?.username || ad.profiles?.email || "A")[0].toUpperCase()}
                            </div>
                            <div className="flex-1">
                              <div className="flex items-center gap-2 mb-1">
                                <span className="font-semibold text-white text-sm">
                                  {ad.profiles?.username || ad.profiles?.email?.split("@")[0] || "Anonymous"}
                                </span>
                              </div>
                              {currentUserId === ad.user_id && (
                                <span className="text-xs bg-blue-500/20 text-blue-400 px-2 py-0.5 rounded">
                                  Your Ad
                                </span>
                              )}
                            </div>
                          </div>

                          <div className="space-y-1.5 text-xs">
                            <div className="flex items-center gap-1.5 text-gray-400">
                              <span>{stats.total_trades} trades</span>
                              <span className="text-gray-600">|</span>
                              <span className="text-[#0ecb81]">{stats.completion_rate.toFixed(1)}%</span>
                            </div>
                            <div className="flex items-center gap-1.5">
                              <div className="flex gap-0.5">{renderStarRating(stats.average_rating)}</div>
                              <span className="text-gray-400">
                                {stats.average_rating > 0 ? stats.average_rating.toFixed(1) : "No ratings"}
                              </span>
                              {stats.total_ratings > 0 && (
                                <span className="text-gray-600">({stats.total_ratings})</span>
                              )}
                            </div>
                          </div>
                        </div>

                        <div className="flex-1 border-l border-white/5 pl-6">
                          <div className="mb-4">
                            <div className="text-2xl font-bold text-white mb-1">
                              KSh {ad.price_per_afx || "16.29"} <span className="text-base text-gray-400">/ AFX</span>
                            </div>
                            <div className="flex items-center gap-4 text-xs text-gray-400">
                              <div>
                                <span className="text-gray-500">Available </span>
                                <span className="text-white font-medium">
                                  {ad.remaining_amount || ad.afx_amount} AFX
                                </span>
                              </div>
                              <div>
                                <span className="text-gray-500">Limit </span>
                                <span className="text-white font-medium">
                                  {ad.min_amount}-{ad.max_amount || ad.afx_amount} AFX
                                </span>
                              </div>
                            </div>
                          </div>

                          <div className="mb-4">
                            <div className="text-xs text-gray-500 mb-2">Payment</div>
                            <div className="flex flex-wrap gap-2">
                              {getPaymentMethods(ad).length > 0 ? (
                                getPaymentMethods(ad).map((method, index) => (
                                  <div
                                    key={index}
                                    className="flex items-center gap-1.5 bg-white/5 px-3 py-1.5 rounded-full border border-white/10"
                                  >
                                    <div className={`w-2 h-2 rounded-full ${method.color}`} />
                                    <span className="text-xs text-gray-300">{method.name}</span>
                                  </div>
                                ))
                              ) : (
                                <span className="text-xs text-gray-500">No payment method selected</span>
                              )}
                            </div>
                          </div>

                          {ad.terms_of_trade && (
                            <div className="text-xs text-gray-400 italic">"{ad.terms_of_trade}"</div>
                          )}
                        </div>

                        <div className="flex-shrink-0 lg:w-56 flex flex-col justify-between gap-3">
                          {currentUserId !== ad.user_id && (
                            <>
                              <div>
                                <Label htmlFor={`amount-${ad.id}`} className="text-xs text-gray-400 mb-2 block">
                                  Enter amount (AFX)
                                </Label>
                                <Input
                                  id={`amount-${ad.id}`}
                                  type="number"
                                  min="2"
                                  max={ad.remaining_amount || ad.afx_amount}
                                  step="0.01"
                                  placeholder={`${ad.min_amount}-${ad.remaining_amount || ad.afx_amount}`}
                                  value={tradeAmounts[ad.id] || ""}
                                  onChange={(e) => setTradeAmounts((prev) => ({ ...prev, [ad.id]: e.target.value }))}
                                  className="bg-white/5 border-white/10 text-white h-10"
                                />
                              </div>
                              <Button
                                className={`w-full h-11 rounded-lg font-semibold transition-all ${
                                  activeTab === "buy"
                                    ? "bg-[#0ecb81] text-black hover:bg-[#0ecb81]/90 hover:shadow-lg hover:shadow-[#0ecb81]/20"
                                    : "bg-[#f6465d] text-white hover:bg-[#f6465d]/90 hover:shadow-lg hover:shadow-[#f6465d]/20"
                                }`}
                                onClick={() => initiateTrade(ad)}
                                disabled={initiatingTrade === ad.id}
                              >
                                {initiatingTrade === ad.id
                                  ? "Processing..."
                                  : activeTab === "buy"
                                    ? "Buy AFX"
                                    : "Sell AFX"}
                              </Button>
                            </>
                          )}
                          {currentUserId === ad.user_id && (
                            <div className="flex items-center justify-center h-full">
                              <div className="text-center">
                                <Shield size={24} className="text-blue-400 mx-auto mb-2" />
                                <p className="text-sm text-gray-400">Your Ad</p>
                              </div>
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        </div>
      </main>
      <Footer />

      {/* BalanceTransferModal */}
      <BalanceTransferModal
        open={showTransferModal}
        onOpenChange={setShowTransferModal}
        dashboardBalance={dashboardBalance}
        p2pBalance={p2pBalance}
        onTransferComplete={fetchBalance}
      />
    </div>
  )
}
