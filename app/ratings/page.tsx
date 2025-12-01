"use client"

import { useState, useEffect } from "react"
import Link from "next/link"
import Header from "@/components/header"
import Footer from "@/components/footer"
import { Star } from 'lucide-react'
import { createClient } from "@/lib/supabase/client"

interface Trade {
  id: string
  type: "buy" | "sell"
  sellerId: string
  sellerName: string
  sellerRating: number
  sellerTrades: number
  amount: number
  pricePerCoin: number
  totalPrice: number
  paymentMethod: string
  status: "active" | "pending" | "completed" | "cancelled"
  createdAt: string
  completedAt?: string
  buyerRating?: number
  buyerReview?: string
}

export default function RatingsPage() {
  const [isLoggedIn, setIsLoggedIn] = useState(true)
  const [userRating, setUserRating] = useState(0)
  const [userTrades, setUserTrades] = useState(0)
  const [activeTrades, setActiveTrades] = useState<Trade[]>([])

  useEffect(() => {
    const loadUserData = async () => {
      const supabase = createClient()
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (user) {
        // Load user profile
        const { data: profile } = await supabase
          .from("profiles")
          .select("rating, total_trades")
          .eq("id", user.id)
          .single()

        if (profile) {
          setUserRating(Number(profile.rating) || 0)
          setUserTrades(Number(profile.total_trades) || 0)
        }

        // Load completed trades with ratings
        const { data: trades } = await supabase
          .from("p2p_trades")
          .select(`
            *,
            p2p_ratings (
              rating,
              comment
            )
          `)
          .or(`buyer_id.eq.${user.id},seller_id.eq.${user.id}`)
          .eq("status", "completed")
          .order("created_at", { ascending: false })

        if (trades) {
          // Format trades data
          const formattedTrades: Trade[] = trades.map((trade) => ({
            id: trade.id,
            type: trade.buyer_id === user.id ? "buy" : "sell",
            sellerId: trade.seller_id,
            sellerName: "User", // You may want to join with profiles to get actual names
            sellerRating: 0,
            sellerTrades: 0,
            amount: Number(trade.afx_amount),
            pricePerCoin: Number(trade.afx_amount) > 0 ? Number(trade.escrow_amount) / Number(trade.afx_amount) : 0,
            totalPrice: Number(trade.escrow_amount),
            paymentMethod: "M-Pesa",
            status: "completed",
            createdAt: new Date(trade.created_at).toLocaleString(),
            completedAt: trade.coins_released_at ? new Date(trade.coins_released_at).toLocaleString() : undefined,
            buyerRating: trade.p2p_ratings?.[0]?.rating,
            buyerReview: trade.p2p_ratings?.[0]?.comment,
          }))
          setActiveTrades(formattedTrades)
        }
      }
    }

    loadUserData()
  }, [])

  const completedTrades = activeTrades.filter((t) => t.status === "completed" && t.buyerRating)

  return (
    <div className="min-h-screen flex flex-col">
      <Header isLoggedIn={isLoggedIn} setIsLoggedIn={setIsLoggedIn} />

      <main className="flex-1">
        <div className="max-w-7xl mx-auto px-6 py-12">
          {/* Header */}
          <div className="mb-8">
            <h1 className="text-4xl font-bold mb-2">Your Ratings & Reviews</h1>
            <p className="text-gray-400">Build trust in the AfriX community with your trading history</p>
          </div>

          {/* Rating Summary */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            {/* Overall Rating */}
            <div className="glass-card p-8 rounded-xl border border-white/10">
              <div className="text-center">
                <div className="text-5xl font-bold text-yellow-400 mb-2">{userRating.toFixed(1)}</div>
                <div className="flex justify-center gap-1 mb-4">
                  {[...Array(5)].map((_, i) => (
                    <Star
                      key={i}
                      size={20}
                      className={i < Math.floor(userRating) ? "fill-yellow-400 text-yellow-400" : "text-gray-600"}
                    />
                  ))}
                </div>
                <p className="text-gray-400">Overall Rating</p>
              </div>
            </div>

            {/* Total Trades */}
            <div className="glass-card p-8 rounded-xl border border-white/10">
              <div className="text-center">
                <div className="text-5xl font-bold text-green-400 mb-2">{userTrades}</div>
                <p className="text-gray-400">Completed Trades</p>
              </div>
            </div>

            {/* Positive Reviews */}
            <div className="glass-card p-8 rounded-xl border border-white/10">
              <div className="text-center">
                <div className="text-5xl font-bold text-blue-400 mb-2">{completedTrades.length}</div>
                <p className="text-gray-400">Rated Trades</p>
              </div>
            </div>
          </div>

          {/* Reviews List */}
          <div className="glass-card p-8 rounded-xl border border-white/10">
            <h2 className="text-2xl font-bold mb-6">Recent Reviews</h2>

            {completedTrades.length === 0 ? (
              <div className="text-center py-12">
                <p className="text-gray-400 mb-4">No reviews yet. Complete trades to earn ratings.</p>
                <Link
                  href="/p2p"
                  className="inline-block px-6 py-3 rounded-lg bg-gradient-to-r from-green-500 to-green-600 text-black font-semibold hover:shadow-lg hover:shadow-green-500/50 transition"
                >
                  Start Trading
                </Link>
              </div>
            ) : (
              <div className="space-y-4">
                {completedTrades.map((trade) => (
                  <div
                    key={trade.id}
                    className="p-4 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 transition"
                  >
                    <div className="flex justify-between items-start mb-3">
                      <div>
                        <h3 className="font-semibold text-white">{trade.sellerName}</h3>
                        <p className="text-sm text-gray-400">
                          {trade.type === "buy" ? "Bought" : "Sold"} {trade.amount} AFX at KES{" "}
                          {trade.pricePerCoin.toFixed(2)}
                        </p>
                      </div>
                      <div className="text-right">
                        <div className="flex gap-1 justify-end mb-1">
                          {[...Array(5)].map((_, i) => (
                            <Star
                              key={i}
                              size={16}
                              className={
                                i < (trade.buyerRating || 0) ? "fill-yellow-400 text-yellow-400" : "text-gray-600"
                              }
                            />
                          ))}
                        </div>
                        <p className="text-sm text-gray-400">{trade.completedAt}</p>
                      </div>
                    </div>

                    {trade.buyerReview && <p className="text-sm text-gray-300 italic">"{trade.buyerReview}"</p>}
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Tips Section */}
          <div className="mt-8 glass-card p-8 rounded-xl border border-blue-500/30 bg-blue-500/10">
            <h3 className="font-bold text-white mb-4">Tips to Maintain High Ratings</h3>
            <ul className="space-y-2 text-sm text-gray-300">
              <li>Complete trades promptly and communicate clearly</li>
              <li>Use secure payment methods and verify transactions</li>
              <li>Leave honest reviews to help the community</li>
              <li>Respond to disputes professionally and fairly</li>
            </ul>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  )
}
