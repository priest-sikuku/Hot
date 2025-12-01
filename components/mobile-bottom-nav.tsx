"use client"

import { usePathname, useRouter } from "next/navigation"
import { useState, useEffect } from "react"
import Link from "next/link"
import { Home, ArrowLeftRight, User, Clock, Wallet } from "lucide-react"
import { createClient } from "@/lib/supabase/client"

export function MobileBottomNav() {
  const pathname = usePathname()
  const router = useRouter()
  const supabase = createClient()
  const [showProfileMenu, setShowProfileMenu] = useState(false)
  const [username, setUsername] = useState<string | null>(null)

  useEffect(() => {
    const getUser = async () => {
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
    getUser()
  }, [supabase])

  const handleSignOut = async () => {
    await supabase.auth.signOut()
    router.push("/")
  }

  const navItems = [
    { href: "/dashboard", icon: Home, label: "Home" },
    { href: "/p2p", icon: ArrowLeftRight, label: "P2P" },
    { href: "/assets", icon: Wallet, label: "Assets" },
    { href: "/transactions", icon: Clock, label: "History" },
  ]

  // Hide bottom nav on auth pages and admin pages
  if (pathname?.startsWith("/auth") || pathname?.startsWith("/admin")) {
    return null
  }

  return (
    <>
      <nav className="md:hidden fixed bottom-0 left-0 right-0 bg-[#0d1b2a]/95 backdrop-blur-lg border-t border-white/10 z-40 safe-area-inset-bottom">
        <div className="flex items-center justify-around h-16">
          {navItems.map((item) => {
            const isActive = pathname === item.href || (item.href !== "/dashboard" && pathname?.startsWith(item.href))
            const Icon = item.icon

            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex flex-col items-center justify-center flex-1 h-full transition-all ${
                  isActive ? "text-green-400" : "text-gray-400 hover:text-gray-200"
                }`}
              >
                <Icon size={22} strokeWidth={isActive ? 2.5 : 2} />
                <span className={`text-xs mt-1 ${isActive ? "font-semibold" : "font-normal"}`}>{item.label}</span>
              </Link>
            )
          })}

          <button
            onClick={() => setShowProfileMenu(!showProfileMenu)}
            className={`flex flex-col items-center justify-center flex-1 h-full transition-all ${
              pathname === "/profile" ? "text-green-400" : "text-gray-400 hover:text-gray-200"
            }`}
          >
            <User size={22} strokeWidth={pathname === "/profile" ? 2.5 : 2} />
            <span className={`text-xs mt-1 ${pathname === "/profile" ? "font-semibold" : "font-normal"}`}>Profile</span>
          </button>
        </div>
      </nav>

      {showProfileMenu && (
        <>
          <div className="md:hidden fixed inset-0 bg-black/50 z-40" onClick={() => setShowProfileMenu(false)} />
          <div className="md:hidden fixed bottom-16 right-4 bg-gray-900 border border-white/10 rounded-lg shadow-lg py-2 z-50 w-48">
            {username && (
              <div className="px-4 py-2 border-b border-white/10">
                <p className="text-xs text-gray-400">Signed in as</p>
                <p className="text-sm font-semibold text-green-400">{username}</p>
              </div>
            )}
            <Link
              href="/profile"
              className="block px-4 py-2 text-sm hover:bg-green-500/10 transition"
              onClick={() => setShowProfileMenu(false)}
            >
              View Profile
            </Link>
            <button
              onClick={() => {
                setShowProfileMenu(false)
                handleSignOut()
              }}
              className="w-full text-left px-4 py-2 text-sm text-red-400 hover:bg-red-500/10 transition"
            >
              Sign Out
            </button>
          </div>
        </>
      )}
    </>
  )
}
