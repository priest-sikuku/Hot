"use client"

import { useState, useEffect } from "react"
import { AlertCircle, X } from "lucide-react"
import { createClient } from "@/lib/supabase/client"
import Link from "next/link"

export function GuestBanner() {
  const [isGuest, setIsGuest] = useState(false)
  const [isVisible, setIsVisible] = useState(true)

  useEffect(() => {
    const checkAuth = async () => {
      const supabase = createClient()
      const {
        data: { user },
      } = await supabase.auth.getUser()
      setIsGuest(!user)
    }
    checkAuth()
  }, [])

  if (!isGuest || !isVisible) return null

  return (
    <div className="bg-gradient-to-r from-yellow-900/50 to-orange-900/50 border-b border-yellow-500/30 backdrop-blur-sm">
      <div className="max-w-7xl mx-auto px-4 py-3">
        <div className="flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <AlertCircle className="w-5 h-5 text-yellow-400 flex-shrink-0" />
            <p className="text-sm text-yellow-100">
              You're viewing as a guest.{" "}
              <Link href="/auth/sign-in" className="font-semibold underline hover:text-yellow-200">
                Log in
              </Link>{" "}
              to start mining and trading AFX.
            </p>
          </div>
          <button
            onClick={() => setIsVisible(false)}
            className="text-yellow-300 hover:text-yellow-100 transition p-1"
            aria-label="Dismiss"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  )
}
