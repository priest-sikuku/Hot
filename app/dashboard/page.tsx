"use client"

import { useState, useEffect } from "react"
import Link from "next/link"
import Header from "@/components/header"
import Footer from "@/components/footer"
import { RemainingSupplyBar } from "@/components/remaining-supply-bar"
import { MiningWidget } from "@/components/mining-widget"
import { createClient } from "@/lib/supabase/client"
import { Sparkles, TrendingUp, Users, FileText, Map } from "lucide-react"
import { GuestBanner } from "@/components/guest-banner"

export default function Dashboard() {
  const [username, setUsername] = useState<string | null>(null)

  useEffect(() => {
    const fetchUserData = async () => {
      const supabase = createClient()
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (user) {
        const { data: profile } = await supabase.from("profiles").select("username").eq("id", user.id).single()

        if (profile?.username) {
          setUsername(profile.username)
        }
      }
    }

    fetchUserData()
  }, [])

  return (
    <div className="min-h-screen flex flex-col pb-20 md:pb-0">
      <Header />
      <GuestBanner />
      <main className="flex-1">
        <div className="max-w-7xl mx-auto px-6 py-8">
          {/* Hero Section */}
          <div className="mb-8 text-center">
            <h1 className="text-5xl md:text-6xl font-bold mb-4 bg-gradient-to-r from-green-400 via-yellow-400 to-green-500 bg-clip-text text-transparent">
              Welcome{username ? ` ${username}` : ""}!
            </h1>
            <p className="text-lg text-gray-400 mb-6">Mine AFX and grow your digital assets</p>

            {/* Remaining Supply Bar */}
            <div className="mb-6 max-w-4xl mx-auto">
              <RemainingSupplyBar />
            </div>

            {/* Quick Stats Cards */}
            <div className="grid grid-cols-3 gap-3 max-w-4xl mx-auto">
              <div className="glass-card p-3 rounded-lg border border-blue-500/20">
                <TrendingUp className="w-6 h-6 text-blue-400 mx-auto mb-1.5" />
                <p className="text-xs text-gray-400">P2P Market</p>
                <p className="text-base font-bold text-white">Live</p>
              </div>
              <div className="glass-card p-3 rounded-lg border border-purple-500/20">
                <Users className="w-6 h-6 text-purple-400 mx-auto mb-1.5" />
                <p className="text-xs text-gray-400">Community</p>
                <p className="text-base font-bold text-white">Growing</p>
              </div>
              <div className="glass-card p-3 rounded-lg border border-yellow-500/20">
                <Sparkles className="w-6 h-6 text-yellow-400 mx-auto mb-1.5" />
                <p className="text-xs text-gray-400">Rewards</p>
                <p className="text-base font-bold text-white">Active</p>
              </div>
            </div>

            {/* Mining Widget */}
            <div className="max-w-2xl mx-auto mb-8">
              <MiningWidget />
            </div>

            {/* Quick Links */}
            <div className="mt-8 grid grid-cols-1 md:grid-cols-3 gap-4">
              <Link
                href="/assets"
                className="glass-card p-4 rounded-lg border border-white/10 hover:border-green-500/50 transition group"
              >
                <h3 className="text-lg font-bold mb-1.5 group-hover:text-green-400 transition">View Assets</h3>
                <p className="text-gray-400 text-xs">Check your balances and manage your funds</p>
              </Link>
              <Link
                href="/p2p"
                className="glass-card p-4 rounded-lg border border-white/10 hover:border-blue-500/50 transition group"
              >
                <h3 className="text-lg font-bold mb-1.5 group-hover:text-blue-400 transition">P2P Trading</h3>
                <p className="text-gray-400 text-xs">Buy and sell AFX with other users</p>
              </Link>
              <Link
                href="/transactions"
                className="glass-card p-4 rounded-lg border border-white/10 hover:border-purple-500/50 transition group"
              >
                <h3 className="text-lg font-bold mb-1.5 group-hover:text-purple-400 transition">Transaction History</h3>
                <p className="text-gray-400 text-xs">Track all your activities and earnings</p>
              </Link>
            </div>

            <div className="mt-8 pt-6 border-t border-white/10">
              <div className="flex items-center justify-center gap-6">
                <Link
                  href="/about/whitepaper"
                  className="glass-card flex items-center gap-2 px-5 py-3 rounded-lg border border-green-500/20 hover:border-green-500/50 hover:bg-green-500/10 transition group"
                >
                  <FileText className="w-5 h-5 text-green-400 group-hover:scale-110 transition" />
                  <div className="text-left">
                    <p className="font-semibold text-white text-sm">Whitepaper</p>
                    <p className="text-xs text-gray-400">Learn about AfriX</p>
                  </div>
                </Link>
                <Link
                  href="/about/roadmap"
                  className="glass-card flex items-center gap-2 px-5 py-3 rounded-lg border border-blue-500/20 hover:border-blue-500/50 hover:bg-blue-500/10 transition group"
                >
                  <Map className="w-5 h-5 text-blue-400 group-hover:scale-110 transition" />
                  <div className="text-left">
                    <p className="font-semibold text-white text-sm">Roadmap</p>
                    <p className="text-xs text-gray-400">Our development plan</p>
                  </div>
                </Link>
              </div>
            </div>
          </div>
        </div>
      </main>
      <Footer />
    </div>
  )
}
