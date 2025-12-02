import Header from "@/components/header"
import Footer from "@/components/footer"
import { FileText, Lock, Globe, Shield, TrendingUp, Coins } from "lucide-react"
import Link from "next/link"

export default function WhitepaperPage() {
  return (
    <div className="min-h-screen flex flex-col pb-20 md:pb-0">
      <Header />
      <main className="flex-1 bg-gradient-to-b from-gray-950 to-black">
        <div className="max-w-4xl mx-auto px-6 py-12">
          {/* Header */}
          <div className="mb-12">
            <Link href="/about" className="text-green-400 hover:underline mb-4 inline-block">
              ← Back to About
            </Link>
            <div className="flex items-center gap-4 mb-4">
              <FileText className="w-12 h-12 text-green-400" />
              <h1 className="text-4xl md:text-5xl font-bold">AfriX Whitepaper</h1>
            </div>
            <p className="text-gray-400 text-lg">Technical Documentation v1.0</p>
          </div>

          {/* Table of Contents */}
          <div className="glass-card p-6 rounded-xl border border-white/10 mb-12">
            <h2 className="text-2xl font-bold mb-4">Table of Contents</h2>
            <ul className="space-y-2 text-gray-300">
              <li>
                <a href="#abstract" className="hover:text-green-400 transition">
                  1. Abstract
                </a>
              </li>
              <li>
                <a href="#introduction" className="hover:text-green-400 transition">
                  2. Introduction
                </a>
              </li>
              <li>
                <a href="#tokenomics" className="hover:text-green-400 transition">
                  3. Tokenomics
                </a>
              </li>
              <li>
                <a href="#mining" className="hover:text-green-400 transition">
                  4. Mining System
                </a>
              </li>
              <li>
                <a href="#p2p" className="hover:text-green-400 transition">
                  5. P2P Marketplace
                </a>
              </li>
              <li>
                <a href="#security" className="hover:text-green-400 transition">
                  6. Security & Privacy
                </a>
              </li>
              <li>
                <a href="#roadmap" className="hover:text-green-400 transition">
                  7. Future Development
                </a>
              </li>
            </ul>
          </div>

          {/* Content Sections */}
          <div className="space-y-12">
            {/* Abstract */}
            <section id="abstract" className="glass-card p-6 rounded-xl border border-green-500/20">
              <h2 className="text-3xl font-bold mb-4 flex items-center gap-3">
                <FileText className="w-8 h-8 text-green-400" />
                1. Abstract
              </h2>
              <p className="text-gray-300 leading-relaxed">
                AfriX (AFX) is a revolutionary digital currency designed specifically for Africa's growing digital
                economy. Built on principles of accessibility, transparency, and community empowerment, AfriX provides a
                decentralized platform for peer-to-peer transactions, fair mining opportunities, and financial inclusion
                across the continent. With a fixed supply of 1,000,000 AFX tokens and an accessible mining system, AfriX
                aims to democratize digital finance in Africa.
              </p>
            </section>

            {/* Introduction */}
            <section id="introduction" className="glass-card p-6 rounded-xl border border-blue-500/20">
              <h2 className="text-3xl font-bold mb-4 flex items-center gap-3">
                <Globe className="w-8 h-8 text-blue-400" />
                2. Introduction
              </h2>
              <div className="space-y-4 text-gray-300 leading-relaxed">
                <p>
                  Africa's digital economy is experiencing unprecedented growth, yet millions remain excluded from
                  traditional financial systems. AfriX addresses this gap by providing an accessible, transparent, and
                  secure digital currency that empowers individuals to participate in the global digital economy.
                </p>
                <p>Our platform combines three core pillars:</p>
                <ul className="list-disc list-inside space-y-2 ml-4">
                  <li>
                    <strong>Accessible Mining:</strong> Fair distribution through time-based mining
                  </li>
                  <li>
                    <strong>P2P Marketplace:</strong> Direct peer-to-peer trading with local payment methods
                  </li>
                  <li>
                    <strong>Community Growth:</strong> Platform that rewards user adoption and participation
                  </li>
                </ul>
              </div>
            </section>

            {/* Tokenomics */}
            <section id="tokenomics" className="glass-card p-6 rounded-xl border border-yellow-500/20">
              <h2 className="text-3xl font-bold mb-4 flex items-center gap-3">
                <Coins className="w-8 h-8 text-yellow-400" />
                3. Tokenomics
              </h2>
              <div className="space-y-4 text-gray-300 leading-relaxed">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div className="bg-black/30 p-4 rounded-lg">
                    <p className="text-sm text-gray-400">Total Supply</p>
                    <p className="text-2xl font-bold text-yellow-400">1,000,000 AFX</p>
                  </div>
                  <div className="bg-black/30 p-4 rounded-lg">
                    <p className="text-sm text-gray-400">Mining Interval</p>
                    <p className="text-2xl font-bold text-green-400">5 Hours</p>
                  </div>
                  <div className="bg-black/30 p-4 rounded-lg">
                    <p className="text-sm text-gray-400">Base Mining Rate</p>
                    <p className="text-2xl font-bold text-blue-400">0.15 AFX</p>
                  </div>
                  <div className="bg-black/30 p-4 rounded-lg">
                    <p className="text-sm text-gray-400">Mining Halving</p>
                    <p className="text-2xl font-bold text-purple-400">Post-Halving Rate</p>
                  </div>
                </div>
                <p className="mt-4">
                  The fixed supply of 1,000,000 AFX ensures scarcity and value preservation. As the supply depletes
                  through mining, the remaining tokens become increasingly valuable, incentivizing early adoption and
                  long-term holding.
                </p>
              </div>
            </section>

            {/* Mining System */}
            <section id="mining" className="glass-card p-6 rounded-xl border border-purple-500/20">
              <h2 className="text-3xl font-bold mb-4 flex items-center gap-3">
                <TrendingUp className="w-8 h-8 text-purple-400" />
                4. Mining System
              </h2>
              <div className="space-y-4 text-gray-300 leading-relaxed">
                <p>
                  AfriX employs a time-based mining system that rewards consistent participation rather than
                  computational power, making it accessible to everyone regardless of technical capabilities or
                  resources.
                </p>
                <h3 className="text-xl font-bold text-white mt-6 mb-3">Mining Mechanics</h3>
                <ul className="list-disc list-inside space-y-2 ml-4">
                  <li>
                    <strong>Base Reward:</strong> 0.15 AFX every 5 hours
                  </li>
                  <li>
                    <strong>Halving Event:</strong> Post-halving reward of 0.1 AFX
                  </li>
                  <li>
                    <strong>Fair Distribution:</strong> Time-based rewards for consistent participation
                  </li>
                </ul>
                <p className="mt-4">
                  The mining system encourages long-term participation and community growth through accessible
                  participation mechanisms.
                </p>
              </div>
            </section>

            {/* P2P Marketplace */}
            <section id="p2p" className="glass-card p-6 rounded-xl border border-red-500/20">
              <h2 className="text-3xl font-bold mb-4 flex items-center gap-3">
                <TrendingUp className="w-8 h-8 text-red-400" />
                5. P2P Marketplace
              </h2>
              <div className="space-y-4 text-gray-300 leading-relaxed">
                <p>
                  The AfriX P2P marketplace enables direct transactions between users without intermediaries, supporting
                  local payment methods and ensuring liquidity across the platform.
                </p>
                <h3 className="text-xl font-bold text-white mt-6 mb-3">Key Features</h3>
                <ul className="list-disc list-inside space-y-2 ml-4">
                  <li>Support for M-Pesa, Airtel Money, and bank transfers</li>
                  <li>Escrow protection for secure transactions</li>
                  <li>Rating system for trust and reputation</li>
                  <li>Flexible pricing based on market dynamics</li>
                  <li>Real-time trade matching and notifications</li>
                </ul>
              </div>
            </section>

            {/* Security */}
            <section id="security" className="glass-card p-6 rounded-xl border border-orange-500/20">
              <h2 className="text-3xl font-bold mb-4 flex items-center gap-3">
                <Shield className="w-8 h-8 text-orange-400" />
                6. Security & Privacy
              </h2>
              <div className="space-y-4 text-gray-300 leading-relaxed">
                <p>
                  Security is paramount in the AfriX ecosystem. We employ industry-standard practices and cutting-edge
                  technologies to protect user assets and data.
                </p>
                <h3 className="text-xl font-bold text-white mt-6 mb-3">Security Measures</h3>
                <ul className="list-disc list-inside space-y-2 ml-4">
                  <li>Row-Level Security (RLS) on all database tables</li>
                  <li>Encrypted authentication with Supabase</li>
                  <li>Escrow protection for P2P trades</li>
                  <li>Rate limiting and abuse prevention</li>
                  <li>Regular security audits and updates</li>
                </ul>
              </div>
            </section>

            {/* Future Development */}
            <section id="roadmap" className="glass-card p-6 rounded-xl border border-pink-500/20">
              <h2 className="text-3xl font-bold mb-4 flex items-center gap-3">
                <Lock className="w-8 h-8 text-pink-400" />
                7. Future Development
              </h2>
              <div className="space-y-4 text-gray-300 leading-relaxed">
                <p>
                  AfriX is committed to continuous innovation and expansion. Our development roadmap includes enhanced
                  features, strategic partnerships, and broader ecosystem integration.
                </p>
                <Link
                  href="/about/roadmap"
                  className="inline-block mt-4 px-6 py-3 bg-gradient-to-r from-green-500 to-blue-500 rounded-lg font-bold hover:shadow-lg transition"
                >
                  View Full Roadmap →
                </Link>
              </div>
            </section>
          </div>

          {/* Footer CTA */}
          <div className="mt-16 glass-card p-8 rounded-xl border border-green-500/30 text-center">
            <h2 className="text-3xl font-bold mb-4">Ready to Join AfriX?</h2>
            <p className="text-gray-300 mb-6">Start mining and trading with Africa's revolutionary digital currency.</p>
            <Link
              href="/auth/sign-up"
              className="inline-block px-8 py-3 rounded-lg bg-gradient-to-r from-green-500 to-green-600 text-black font-bold hover:shadow-lg hover:shadow-green-500/50 transition"
            >
              Get Started Now
            </Link>
          </div>
        </div>
      </main>
      <Footer />
    </div>
  )
}
