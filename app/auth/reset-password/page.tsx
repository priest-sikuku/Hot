"use client"

import type React from "react"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import Link from "next/link"
import Header from "@/components/header"
import Footer from "@/components/footer"
import { Eye, EyeOff } from "lucide-react"
import { createClient } from "@/lib/supabase/client"

export default function ResetPassword() {
  const router = useRouter()
  const supabase = createClient()
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const [password, setPassword] = useState("")
  const [confirmPassword, setConfirmPassword] = useState("")
  const [error, setError] = useState("")
  const [loading, setLoading] = useState(false)
  const [isValidToken, setIsValidToken] = useState(false)
  const [checkingToken, setCheckingToken] = useState(true)

  useEffect(() => {
    // Check if user has a valid reset token
    const verifyToken = async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (user) {
        setIsValidToken(true)
      } else {
        setError("Invalid or expired reset link")
      }
      setCheckingToken(false)
    }
    verifyToken()
  }, [supabase.auth])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError("")

    if (!password || !confirmPassword) {
      setError("Both password fields are required")
      return
    }

    if (password !== confirmPassword) {
      setError("Passwords do not match")
      return
    }

    if (password.length < 6) {
      setError("Password must be at least 6 characters")
      return
    }

    setLoading(true)

    try {
      const { error: updateError } = await supabase.auth.updateUser({
        password: password,
      })

      if (updateError) throw updateError

      // Password updated successfully
      router.push("/auth/sign-in?message=password-reset-success")
    } catch (err) {
      setError(err instanceof Error ? err.message : "An error occurred while resetting password")
    } finally {
      setLoading(false)
    }
  }

  if (checkingToken) {
    return (
      <div className="min-h-screen flex flex-col bg-black">
        <Header />
        <main className="flex-1 flex items-center justify-center py-12 px-4">
          <div className="glass-card p-8 rounded-2xl border border-white/5 w-full max-w-md text-center">
            <p className="text-gray-400">Verifying reset link...</p>
          </div>
        </main>
        <Footer />
      </div>
    )
  }

  if (!isValidToken) {
    return (
      <div className="min-h-screen flex flex-col bg-black">
        <Header />
        <main className="flex-1 flex items-center justify-center py-12 px-4">
          <div className="glass-card p-8 rounded-2xl border border-white/5 w-full max-w-md">
            <h1 className="text-3xl font-bold mb-2">Invalid Link</h1>
            <p className="text-gray-400 mb-6">This password reset link is invalid or has expired.</p>
            <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-4 mb-6">
              <p className="text-red-400 text-sm">Please request a new password reset link.</p>
            </div>
            <Link
              href="/auth/forgot-password"
              className="block w-full px-4 py-3 rounded-lg btn-primary-gx font-semibold text-center hover:shadow-lg hover:shadow-green-500/50 transition"
            >
              Request New Link
            </Link>
          </div>
        </main>
        <Footer />
      </div>
    )
  }

  return (
    <div className="min-h-screen flex flex-col bg-black">
      <Header />
      <main className="flex-1 flex items-center justify-center py-12 px-4">
        <div className="glass-card p-8 rounded-2xl border border-white/5 w-full max-w-md">
          <h1 className="text-3xl font-bold mb-2">Reset Password</h1>
          <p className="text-gray-400 mb-8">Enter your new password below</p>

          {error && (
            <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-4 mb-6 text-red-400 text-sm">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {/* New Password */}
            <div>
              <label className="block text-sm text-gray-400 mb-2">New Password</label>
              <div className="relative">
                <input
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full px-4 py-3 rounded-lg bg-white/5 border border-white/10 text-white placeholder-gray-500 focus:outline-none focus:border-green-500/50 transition"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-3 text-gray-400 hover:text-gray-300"
                >
                  {showPassword ? <EyeOff size={20} /> : <Eye size={20} />}
                </button>
              </div>
            </div>

            {/* Confirm Password */}
            <div>
              <label className="block text-sm text-gray-400 mb-2">Confirm Password</label>
              <div className="relative">
                <input
                  type={showConfirmPassword ? "text" : "password"}
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full px-4 py-3 rounded-lg bg-white/5 border border-white/10 text-white placeholder-gray-500 focus:outline-none focus:border-green-500/50 transition"
                />
                <button
                  type="button"
                  onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                  className="absolute right-3 top-3 text-gray-400 hover:text-gray-300"
                >
                  {showConfirmPassword ? <EyeOff size={20} /> : <Eye size={20} />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full px-4 py-3 rounded-lg btn-primary-gx font-semibold hover:shadow-lg hover:shadow-green-500/50 transition disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? "Resetting..." : "Reset Password"}
            </button>
          </form>
        </div>
      </main>
      <Footer />
    </div>
  )
}
