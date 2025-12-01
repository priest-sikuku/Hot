"use client"

import Header from "@/components/header"
import Hero from "@/components/hero"
import Footer from "@/components/footer"
import { MobileBottomNav } from "@/components/mobile-bottom-nav"
import Link from "next/link"
import { FileText, Map } from 'lucide-react'

export default function Home() {
  return (
    <div className="min-h-screen flex flex-col pb-16 md:pb-0">
      <Header />
      <main className="flex-1">
        <div className="max-w-6xl mx-auto px-6 pt-8">
          <div className="flex items-center justify-center gap-6 mb-4">
            <Link
              href="/about/whitepaper"
              className="glass-card flex items-center gap-2 px-6 py-3 rounded-lg border border-green-500/20 hover:border-green-500/50 hover:bg-green-500/10 transition group"
            >
              <FileText className="w-5 h-5 text-green-400 group-hover:scale-110 transition" />
              <span className="font-semibold text-white">Whitepaper</span>
            </Link>
            <Link
              href="/about/roadmap"
              className="glass-card flex items-center gap-2 px-6 py-3 rounded-lg border border-blue-500/20 hover:border-blue-500/50 hover:bg-blue-500/10 transition group"
            >
              <Map className="w-5 h-5 text-blue-400 group-hover:scale-110 transition" />
              <span className="font-semibold text-white">Roadmap</span>
            </Link>
          </div>
        </div>
        <Hero />
      </main>
      <Footer />
      <MobileBottomNav />
    </div>
  )
}
