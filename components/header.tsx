"use client"

import { useState, useEffect } from "react"
import Link from "next/link"
import { useRouter } from "next/navigation"
import { User, ChevronDown } from "lucide-react"

export default function Header() {
  const router = useRouter()
  const [supabase, setSupabase] = useState<ReturnType<typeof import("@/lib/supabase/client").createClient> | null>(null)
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [isLoggedIn, setIsLoggedIn] = useState(false)
  const [loading, setLoading] = useState(true)
  const [username, setUsername] = useState<string | null>(null)
  const [profileDropdownOpen, setProfileDropdownOpen] = useState(false)

  useEffect(() => {
    const { createClient } = require("@/lib/supabase/client")
    setSupabase(createClient())
  }, [])

  useEffect(() => {
    if (!supabase) return

    const checkAuth = async () => {
      try {
        const {
          data: { user },
        } = await supabase.auth.getUser()
        setIsLoggedIn(!!user)

        if (user) {
          const { data: profile } = await supabase.from("profiles").select("username").eq("id", user.id).single()

          if (profile?.username) {
            setUsername(profile.username)
          }
        }
      } catch (error) {
        console.error("Auth check error:", error)
        setIsLoggedIn(false)
      } finally {
        setLoading(false)
      }
    }

    checkAuth()

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, session) => {
      setIsLoggedIn(!!session?.user)
      if (!session?.user) {
        setUsername(null)
      }
    })

    return () => subscription?.unsubscribe()
  }, [supabase])

  const handleSignOut = async () => {
    if (!supabase) return
    try {
      await supabase.auth.signOut()
      setIsLoggedIn(false)
      setUsername(null)
      router.push("/")
    } catch (error) {
      console.error("Sign out error:", error)
    }
  }

  return (
    <header className={`border-b border-white/5 ${isLoggedIn ? "hidden md:block" : "block"}`}>
      <div className="max-w-6xl mx-auto px-6 py-4">
        <div className="flex items-center justify-between">
          {/* Logo */}
          <Link href="/" className="flex items-center gap-3">
            <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg" className="w-12 h-12" aria-hidden="true">
              <defs>
                <linearGradient id="g1" x1="0" x2="1">
                  <stop offset="0%" stopColor="#FFD700" />
                  <stop offset="100%" stopColor="#00C853" />
                </linearGradient>
                <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
                  <feDropShadow dx="0" dy="6" stdDeviation="10" floodColor="#051428" floodOpacity="0.6" />
                </filter>
              </defs>
              <g filter="url(#shadow)">
                <path d="M18 62 L40 30 L50 40 L28 72 Z" fill="url(#g1)" />
                <path d="M82 62 L60 30 L50 40 L72 72 Z" fill="url(#g1)" />
                <circle cx="50" cy="55" r="9" fill="rgba(255,255,255,0.06)" />
              </g>
            </svg>
            <div>
              <div className="font-bold text-lg">
                AfriX <span className="text-yellow-400">AFX</span>
              </div>
              <div className="text-xs text-gray-400">The Coin That Never Sleeps</div>
            </div>
          </Link>

          {/* Desktop Navigation */}
          <div className="hidden md:flex items-center gap-6">
            {!loading && isLoggedIn ? (
              <>
                <Link href="/dashboard" className="text-sm hover:text-green-400 transition">
                  Home
                </Link>
                <Link href="/p2p" className="text-sm hover:text-green-400 transition">
                  P2P
                </Link>
                <Link href="/assets" className="text-sm hover:text-green-400 transition">
                  Assets
                </Link>
                <Link href="/about" className="text-sm hover:text-green-400 transition">
                  About
                </Link>

                <div className="relative">
                  <button
                    onClick={() => setProfileDropdownOpen(!profileDropdownOpen)}
                    className="flex items-center gap-2 px-4 py-2 rounded-lg border border-green-500/30 text-green-400 hover:bg-green-500/10 transition text-sm"
                  >
                    <User size={18} />
                    <span>Profile</span>
                    <ChevronDown size={16} />
                  </button>

                  {profileDropdownOpen && (
                    <div className="absolute right-0 mt-2 w-48 bg-gray-900 border border-white/10 rounded-lg shadow-lg py-2 z-50">
                      {username && (
                        <div className="px-4 py-2 border-b border-white/10">
                          <p className="text-xs text-gray-400">Signed in as</p>
                          <p className="text-sm font-semibold text-green-400">{username}</p>
                        </div>
                      )}
                      <Link
                        href="/profile"
                        className="block px-4 py-2 text-sm hover:bg-green-500/10 transition"
                        onClick={() => setProfileDropdownOpen(false)}
                      >
                        View Profile
                      </Link>
                      <Link
                        href="/transactions"
                        className="block px-4 py-2 text-sm hover:bg-green-500/10 transition"
                        onClick={() => setProfileDropdownOpen(false)}
                      >
                        Transaction History
                      </Link>
                      <button
                        onClick={() => {
                          setProfileDropdownOpen(false)
                          handleSignOut()
                        }}
                        className="w-full text-left px-4 py-2 text-sm text-red-400 hover:bg-red-500/10 transition"
                      >
                        Sign Out
                      </button>
                    </div>
                  )}
                </div>
              </>
            ) : (
              <>
                <Link
                  href="/auth/sign-in"
                  className="px-4 py-2 rounded-lg border border-green-500/30 text-green-400 hover:bg-green-500/10 transition text-sm"
                >
                  Sign In
                </Link>
                <Link
                  href="/auth/sign-up"
                  className="px-4 py-2 rounded-lg bg-gradient-to-r from-green-500 to-green-600 text-black font-semibold hover:shadow-lg hover:shadow-green-500/50 transition text-sm"
                >
                  Get Started
                </Link>
              </>
            )}
          </div>

          {!loading && isLoggedIn ? (
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className="md:hidden p-2 flex items-center gap-2 border border-green-500/30 rounded-lg"
            >
              <User size={20} />
              {username && <span className="text-sm">{username}</span>}
            </button>
          ) : (
            <div className="md:hidden flex gap-2">
              <Link
                href="/auth/sign-in"
                className="px-3 py-1.5 rounded-lg border border-green-500/30 text-green-400 text-xs"
              >
                Sign In
              </Link>
            </div>
          )}
        </div>

        {/* Mobile Menu */}
        {mobileMenuOpen && isLoggedIn && (
          <div className="md:hidden mt-4 pb-4 border-t border-white/5 pt-4 flex flex-col gap-3">
            {username && (
              <div className="px-4 py-2 bg-green-500/5 rounded-lg border border-green-500/20">
                <p className="text-xs text-gray-400">Signed in as</p>
                <p className="text-sm font-semibold text-green-400">{username}</p>
              </div>
            )}
            <Link href="/dashboard" className="text-sm hover:text-green-400 transition">
              Home
            </Link>
            <Link href="/p2p" className="text-sm hover:text-green-400 transition">
              P2P
            </Link>
            <Link href="/assets" className="text-sm hover:text-green-400 transition">
              Assets
            </Link>
            <Link href="/about" className="text-sm hover:text-green-400 transition">
              About
            </Link>
            <Link href="/profile" className="text-sm hover:text-green-400 transition">
              Profile
            </Link>
            <button
              onClick={handleSignOut}
              className="px-4 py-2 rounded-lg border border-red-500/30 text-red-400 hover:bg-red-500/10 transition text-sm"
            >
              Sign Out
            </button>
          </div>
        )}
      </div>
    </header>
  )
}
