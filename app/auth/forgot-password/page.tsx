"use client"

import type React from "react"

import { useState } from "react"
import Link from "next/link"
import Header from "@/components/header"
import Footer from "@/components/footer"
import { createClient } from "@/lib/supabase/client"

export default function ForgotPassword() {
  const supabase = createClient()
  const [email, setEmail] = useState("")
  const [error, setError] = useState("")
  const [success, setSuccess] = useState(false)
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError("")
    setLoading(true)

    if (!email) {
      setError("Email is required")
      setLoading(false)
      return
    }

    try {
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: process.env.NEXT_PUBLIC_DEV_SUPABASE_REDIRECT_URL
          ? `${process.env.NEXT_PUBLIC_DEV_SUPABASE_REDIRECT_URL}/auth/reset-password`
          : `${window.location.origin}/auth/reset-password`,
      })

      if (resetError) throw resetError

      setSuccess(true)
    } catch (err) {
      setError(err instanceof Error ? err.message : "An error occurred while sending reset email")
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex flex-col bg-black">
      <Header />
      <main className="flex-1 flex items-center justify-center py-12 px-4">
        <div className="glass-card p-8 rounded-2xl border border-white/5 w-full max-w-md">
          {success ? (
            <>
              <h1 className="text-3xl font-bold mb-2">Check Your Email</h1>
              <p className="text-gray-400 mb-6">
                We've sent a password reset link to <span className="text-green-400">{email}</span>
              </p>
              <div className="bg-green-500/10 border border-green-500/30 rounded-lg p-4 mb-6">
                <p className="text-green-400 text-sm">
                  Click the link in the email to reset your password. The link expires in 24 hours.
                </p>
              </div>
              <Link
                href="/auth/sign-in"
                className="block w-full px-4 py-3 rounded-lg btn-primary-gx font-semibold text-center hover:shadow-lg hover:shadow-green-500/50 transition"
              >
                Back to Sign In
              </Link>
            </>
          ) : (
            <>
              <h1 className="text-3xl font-bold mb-2">Forgot Password?</h1>
              <p className="text-gray-400 mb-8">
                Enter your email address and we'll send you a link to reset your password
              </p>

              {error && (
                <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-4 mb-6 text-red-400 text-sm">
                  {error}
                </div>
              )}

              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-2">Email</label>
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@example.com"
                    className="w-full px-4 py-3 rounded-lg bg-white/5 border border-white/10 text-white placeholder-gray-500 focus:outline-none focus:border-green-500/50 transition"
                  />
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full px-4 py-3 rounded-lg btn-primary-gx font-semibold hover:shadow-lg hover:shadow-green-500/50 transition disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {loading ? "Sending..." : "Send Reset Link"}
                </button>
              </form>

              <p className="text-center text-gray-400 text-sm mt-6">
                Remember your password?{" "}
                <Link href="/auth/sign-in" className="text-green-400 hover:underline font-semibold">
                  Sign In
                </Link>
              </p>
            </>
          )}
        </div>
      </main>
      <Footer />
    </div>
  )
}
