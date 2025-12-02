"use client"

import Link from "next/link"
import { BalancePanel } from "./balance-panel"
import { LiveAfxPriceWidget } from "./live-afx-price-widget"
import { UserCountWidget } from "./user-count-widget"
import { useEffect, useState } from "react"
import { createClient } from "@/lib/supabase/client"

export default function Hero() {
  const [isLoggedIn, setIsLoggedIn] = useState(false)
  const [loading, setLoading] = useState(true)
  const [supabase, setSupabase] = useState<ReturnType<typeof createClient> | null>(null)

  useEffect(() => {
    const client = createClient()
    setSupabase(client)

    const checkAuth = async () => {
      try {
        const {
          data: { user },
        } = await client.auth.getUser()
        setIsLoggedIn(!!user)
      } catch (error) {
        console.error("Auth check error:", error)
        setIsLoggedIn(false)
      } finally {
        setLoading(false)
      }
    }

    checkAuth()

    // Subscribe to auth changes
    const {
      data: { subscription },
    } = client.auth.onAuthStateChange((event, session) => {
      setIsLoggedIn(!!session?.user)
    })

    return () => subscription?.unsubscribe()
  }, [])

  return (
    <div className="max-w-6xl mx-auto px-6 py-12">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Left Content */}
        <div className="lg:col-span-2 space-y-8">
          {/* Main Card */}
          <div className="glass-card p-8 rounded-2xl border border-white/5">
            <h1 className="text-4xl md:text-5xl font-bold mb-4">AfriX — The Coin That Never Sleeps</h1>
            <p className="text-gray-400 text-lg leading-relaxed mb-6">
              Earn <strong className="text-white">daily</strong> growth on your holdings. Trade peer‑to‑peer across
              Africa and beyond. Built for continuous growth and community.
            </p>
            <div className="flex flex-col sm:flex-row gap-3 mb-8">
              <Link
                href={isLoggedIn ? "/dashboard" : "/auth/sign-up"}
                className="px-6 py-3 rounded-lg btn-primary-afx font-semibold hover:shadow-lg hover:shadow-green-500/50 transition text-center"
              >
                {isLoggedIn ? "Go to Dashboard" : "Get Started"}
              </Link>
              <Link
                href={isLoggedIn ? "/market" : "/auth/sign-up"}
                className="px-6 py-3 rounded-lg btn-ghost-afx font-semibold border hover:bg-green-500/10 transition text-center"
              >
                P2P Market
              </Link>
            </div>
          </div>

          {/* Live Price and User Count Widgets */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <LiveAfxPriceWidget />
            <UserCountWidget />
          </div>
        </div>

        {/* Right Panel */}
        {!loading && isLoggedIn && <BalancePanel />}
      </div>
    </div>
  )
}
