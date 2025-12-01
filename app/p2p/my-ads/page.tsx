"use client"

import { useEffect, useState } from "react"
import { ArrowLeft, Edit, Trash2, Clock } from "lucide-react"
import { Button } from "@/components/ui/button"
import Header from "@/components/header"
import Footer from "@/components/footer"
import { createClient } from "@/lib/supabase/client"
import { useRouter } from "next/navigation"

interface Ad {
  id: string
  ad_type: string
  afx_amount: number
  remaining_amount: number
  min_amount: number
  max_amount: number
  price_per_afx: number
  status: string
  created_at: string
  expires_at: string
}

export default function MyAdsPage() {
  const [ads, setAds] = useState<Ad[]>([])
  const [loading, setLoading] = useState(true)
  const [deletingId, setDeletingId] = useState<string | null>(null)
  const router = useRouter()
  const supabase = createClient()

  useEffect(() => {
    fetchMyAds()
  }, [])

  async function fetchMyAds() {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) return

      const { data, error } = await supabase
        .from("p2p_ads")
        .select("*")
        .eq("user_id", user.id)
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

  async function deleteAd(adId: string) {
    if (!confirm("Are you sure you want to delete this ad?")) return

    try {
      setDeletingId(adId)
      const { error } = await supabase.from("p2p_ads").delete().eq("id", adId)

      if (error) {
        alert("Failed to delete ad: " + error.message)
        return
      }

      alert("Ad deleted successfully")
      fetchMyAds()
    } catch (error) {
      console.error("[v0] Error:", error)
      alert("Failed to delete ad")
    } finally {
      setDeletingId(null)
    }
  }

  return (
    <div className="min-h-screen flex flex-col">
      <Header />
      <main className="flex-1">
        <div className="max-w-7xl mx-auto px-6 py-12">
          <Button variant="ghost" className="mb-6 hover:bg-white/5" onClick={() => router.push("/p2p")}>
            <ArrowLeft size={20} className="mr-2" />
            Back to P2P
          </Button>

          <div className="mb-8">
            <h1 className="text-4xl font-bold mb-2">My Ads</h1>
            <p className="text-gray-400">Manage your buy and sell advertisements</p>
          </div>

          <div className="glass-card p-8 rounded-xl border border-white/10">
            {loading ? (
              <div className="text-center py-12">
                <p className="text-gray-400">Loading ads...</p>
              </div>
            ) : ads.length === 0 ? (
              <div className="text-center py-12">
                <p className="text-gray-400 mb-4">You haven't posted any ads yet</p>
                <Button onClick={() => router.push("/p2p/post-ad")} className="btn-primary-gx">
                  Post Your First Ad
                </Button>
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
                        <div className="flex items-center gap-2 mb-2">
                          <span
                            className={`px-3 py-1 rounded-full text-xs font-semibold ${
                              ad.ad_type === "sell" ? "bg-green-500/20 text-green-400" : "bg-red-500/20 text-red-400"
                            }`}
                          >
                            {ad.ad_type.toUpperCase()}
                          </span>
                          <span
                            className={`px-3 py-1 rounded-full text-xs font-semibold ${
                              ad.status === "active" ? "bg-blue-500/20 text-blue-400" : "bg-gray-500/20 text-gray-400"
                            }`}
                          >
                            {ad.status.toUpperCase()}
                          </span>
                        </div>

                        <div className="grid grid-cols-2 gap-4 mb-2">
                          <div>
                            <p className="text-sm text-gray-400">Amount</p>
                            <p className="font-semibold">
                              {ad.remaining_amount} / {ad.afx_amount} AFX
                            </p>
                          </div>
                          <div>
                            <p className="text-sm text-gray-400">Price</p>
                            <p className="font-semibold">{ad.price_per_afx} KES/AFX</p>
                          </div>
                        </div>

                        <div className="flex items-center gap-2 text-xs text-gray-500">
                          <Clock size={14} />
                          <span>Expires {new Date(ad.expires_at).toLocaleDateString()}</span>
                        </div>
                      </div>

                      <div className="flex gap-2">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => router.push(`/p2p/edit-ad/${ad.id}`)}
                          className="bg-white/5 border-white/10 hover:bg-white/10"
                        >
                          <Edit size={16} className="mr-1" />
                          Edit
                        </Button>
                        <Button
                          variant="destructive"
                          size="sm"
                          onClick={() => deleteAd(ad.id)}
                          disabled={deletingId === ad.id}
                        >
                          <Trash2 size={16} className="mr-1" />
                          {deletingId === ad.id ? "Deleting..." : "Delete"}
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
