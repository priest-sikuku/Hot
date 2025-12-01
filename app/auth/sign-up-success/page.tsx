"use client"

import Link from "next/link"
import Header from "@/components/header"
import Footer from "@/components/footer"
import { CheckCircle } from "lucide-react"

export default function SignUpSuccess() {
  return (
    <div className="min-h-screen flex flex-col">
      <Header />
      <main className="flex-1 flex items-center justify-center py-12 px-4">
        <div className="glass-card p-8 rounded-2xl border border-white/5 w-full max-w-md text-center">
          <CheckCircle className="w-16 h-16 text-green-500 mx-auto mb-4" />
          <h1 className="text-3xl font-bold mb-2">Account Created!</h1>
          <p className="text-gray-400 mb-6">
            Please check your email to confirm your account. Once confirmed, you can sign in and start trading GrowX
            coins.
          </p>

          <div className="space-y-3">
            <Link
              href="/auth/sign-in"
              className="block w-full px-4 py-3 rounded-lg btn-primary-gx font-semibold hover:shadow-lg hover:shadow-green-500/50 transition"
            >
              Go to Sign In
            </Link>
            <Link
              href="/"
              className="block w-full px-4 py-3 rounded-lg btn-ghost-gx font-semibold hover:bg-white/5 transition"
            >
              Back to Home
            </Link>
          </div>
        </div>
      </main>
      <Footer />
    </div>
  )
}
