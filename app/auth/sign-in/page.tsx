"use client"

import type React from "react"

import { useState, Suspense } from "react"
import Link from "next/link"
import { useRouter, useSearchParams } from 'next/navigation'
import Header from "@/components/header"
import Footer from "@/components/footer"
import { Eye, EyeOff } from 'lucide-react'
import { createClient } from "@/lib/supabase/client"

function SignInForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const supabase = createClient()
  const [showPassword, setShowPassword] = useState(false)
  const [formData, setFormData] = useState({
    email: "",
    password: "",
    rememberMe: false,
  })
  const [error, setError] = useState("")
  const [loading, setLoading] = useState(false)

  const nextUrl = searchParams.get("next") || "/dashboard"
  const actionMessage = searchParams.get("action")
  const guestMessage = searchParams.get("message")

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value, type, checked } = e.target
    setFormData((prev) => ({
      ...prev,
      [name]: type === "checkbox" ? checked : value,
    }))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError("")
    setLoading(true)

    if (!formData.email || !formData.password) {
      setError("Email and password are required")
      setLoading(false)
      return
    }

    try {
      const { error: signInError } = await supabase.auth.signInWithPassword({
        email: formData.email,
        password: formData.password,
      })

      if (signInError) throw signInError

      router.push(nextUrl)
    } catch (err) {
      setError(err instanceof Error ? err.message : "An error occurred during sign in")
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="glass-card p-8 rounded-2xl border border-white/5 w-full max-w-md">
      <h1 className="text-3xl font-bold mb-2">Welcome Back</h1>
      <p className="text-gray-400 mb-8">Sign in to your AfriX account</p>

      {guestMessage && (
        <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-4 mb-6 text-yellow-400 text-sm">
          {guestMessage}
        </div>
      )}

      {actionMessage === "mine" && (
        <div className="bg-green-500/10 border border-green-500/30 rounded-lg p-4 mb-6 text-green-400 text-sm">
          Sign in to start mining AFX and earn rewards!
        </div>
      )}

      {error && (
        <div className="bg-red-500/10 border border-red-500/30 rounded-lg p-4 mb-6 text-red-400 text-sm">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Email */}
        <div>
          <label className="block text-sm text-gray-400 mb-2">Email</label>
          <input
            type="email"
            name="email"
            value={formData.email}
            onChange={handleChange}
            placeholder="you@example.com"
            className="w-full px-4 py-3 rounded-lg bg-white/5 border border-white/10 text-white placeholder-gray-500 focus:outline-none focus:border-green-500/50 transition"
          />
        </div>

        {/* Password */}
        <div>
          <label className="block text-sm text-gray-400 mb-2">Password</label>
          <div className="relative">
            <input
              type={showPassword ? "text" : "password"}
              name="password"
              value={formData.password}
              onChange={handleChange}
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

        {/* Remember Me */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <input
              type="checkbox"
              name="rememberMe"
              checked={formData.rememberMe}
              onChange={handleChange}
              className="w-4 h-4 rounded border-white/10 bg-white/5 text-green-500 cursor-pointer"
            />
            <label className="text-sm text-gray-400">Remember me</label>
          </div>
          <Link href="/auth/forgot-password" className="text-sm text-green-400 hover:underline">
            Forgot password?
          </Link>
        </div>

        {/* Submit */}
        <button
          type="submit"
          disabled={loading}
          className="w-full px-4 py-3 rounded-lg btn-primary-gx font-semibold hover:shadow-lg hover:shadow-green-500/50 transition disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {loading ? "Signing In..." : "Sign In"}
        </button>
      </form>

      {/* Sign Up Link */}
      <p className="text-center text-gray-400 text-sm mt-6">
        Don't have an account?{" "}
        <Link href="/auth/sign-up" className="text-green-400 hover:underline font-semibold">
          Create one
        </Link>
      </p>
    </div>
  )
}

export default function SignIn() {
  return (
    <div className="min-h-screen flex flex-col">
      <Header />
      <main className="flex-1 flex items-center justify-center py-12 px-4">
        <Suspense fallback={
          <div className="glass-card p-8 rounded-2xl border border-white/5 w-full max-w-md">
            <div className="animate-pulse space-y-4">
              <div className="h-8 bg-white/10 rounded w-3/4"></div>
              <div className="h-4 bg-white/10 rounded w-1/2"></div>
              <div className="h-12 bg-white/10 rounded"></div>
              <div className="h-12 bg-white/10 rounded"></div>
              <div className="h-12 bg-white/10 rounded"></div>
            </div>
          </div>
        }>
          <SignInForm />
        </Suspense>
      </main>
      <Footer />
    </div>
  )
}
