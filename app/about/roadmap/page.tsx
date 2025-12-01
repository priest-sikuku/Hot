import Header from "@/components/header"
import Footer from "@/components/footer"
import { Map, Check, Clock, Rocket } from 'lucide-react'
import Link from "next/link"

export default function RoadmapPage() {
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
              <Map className="w-12 h-12 text-blue-400" />
              <h1 className="text-4xl md:text-5xl font-bold">AfriX Roadmap</h1>
            </div>
            <p className="text-gray-400 text-lg">Our journey to revolutionize digital finance in Africa</p>
          </div>

          {/* Roadmap Timeline */}
          <div className="space-y-8">
            {/* Q4 2024 - COMPLETED */}
            <div className="glass-card p-6 rounded-xl border border-green-500/50">
              <div className="flex items-start gap-4">
                <div className="flex-shrink-0 w-12 h-12 rounded-full bg-green-500 flex items-center justify-center">
                  <Check className="w-6 h-6 text-black" />
                </div>
                <div className="flex-1">
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="text-2xl font-bold">Q4 2024</h3>
                    <span className="px-3 py-1 bg-green-500/20 text-green-400 rounded-full text-sm font-semibold">
                      Completed
                    </span>
                  </div>
                  <ul className="space-y-2 text-gray-300">
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-green-400 flex-shrink-0" />
                      Platform launch with core features
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-green-400 flex-shrink-0" />
                      Mining system with 5-hour intervals
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-green-400 flex-shrink-0" />
                      P2P marketplace with escrow protection
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-green-400 flex-shrink-0" />
                      Referral system with mining boosts
                    </li>
                    <li className="flex items-center gap-2">
                      <Check className="w-4 h-4 text-green-400 flex-shrink-0" />
                      Mobile-first responsive design
                    </li>
                  </ul>
                </div>
              </div>
            </div>

            {/* Q1 2025 - IN PROGRESS */}
            <div className="glass-card p-6 rounded-xl border border-blue-500/50">
              <div className="flex items-start gap-4">
                <div className="flex-shrink-0 w-12 h-12 rounded-full bg-blue-500 flex items-center justify-center">
                  <Clock className="w-6 h-6 text-black" />
                </div>
                <div className="flex-1">
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="text-2xl font-bold">Q1 2025</h3>
                    <span className="px-3 py-1 bg-blue-500/20 text-blue-400 rounded-full text-sm font-semibold">
                      In Progress
                    </span>
                  </div>
                  <ul className="space-y-2 text-gray-300">
                    <li className="flex items-center gap-2">
                      <Clock className="w-4 h-4 text-blue-400 flex-shrink-0" />
                      Mobile app launch (iOS & Android)
                    </li>
                    <li className="flex items-center gap-2">
                      <Clock className="w-4 h-4 text-blue-400 flex-shrink-0" />
                      Enhanced security features
                    </li>
                    <li className="flex items-center gap-2">
                      <Clock className="w-4 h-4 text-blue-400 flex-shrink-0" />
                      Advanced trading analytics
                    </li>
                    <li className="flex items-center gap-2">
                      <Clock className="w-4 h-4 text-blue-400 flex-shrink-0" />
                      Community governance features
                    </li>
                    <li className="flex items-center gap-2">
                      <Clock className="w-4 h-4 text-blue-400 flex-shrink-0" />
                      Multi-language support
                    </li>
                  </ul>
                </div>
              </div>
            </div>

            {/* Q2 2025 - PLANNED */}
            <div className="glass-card p-6 rounded-xl border border-purple-500/30">
              <div className="flex items-start gap-4">
                <div className="flex-shrink-0 w-12 h-12 rounded-full bg-purple-500/30 border-2 border-purple-500 flex items-center justify-center">
                  <Rocket className="w-6 h-6 text-purple-400" />
                </div>
                <div className="flex-1">
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="text-2xl font-bold">Q2 2025</h3>
                    <span className="px-3 py-1 bg-purple-500/20 text-purple-400 rounded-full text-sm font-semibold">
                      Planned
                    </span>
                  </div>
                  <ul className="space-y-2 text-gray-300">
                    <li className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-purple-400 flex-shrink-0" />
                      Staking and yield farming features
                    </li>
                    <li className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-purple-400 flex-shrink-0" />
                      Strategic partnerships with African businesses
                    </li>
                    <li className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-purple-400 flex-shrink-0" />
                      Merchant payment integration
                    </li>
                    <li className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-purple-400 flex-shrink-0" />
                      Advanced P2P features (bulk trading, API)
                    </li>
                  </ul>
                </div>
              </div>
            </div>

            {/* Q3 2025 - PLANNED */}
            <div className="glass-card p-6 rounded-xl border border-yellow-500/30">
              <div className="flex items-start gap-4">
                <div className="flex-shrink-0 w-12 h-12 rounded-full bg-yellow-500/30 border-2 border-yellow-500 flex items-center justify-center">
                  <Rocket className="w-6 h-6 text-yellow-400" />
                </div>
                <div className="flex-1">
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="text-2xl font-bold">Q3 2025</h3>
                    <span className="px-3 py-1 bg-yellow-500/20 text-yellow-400 rounded-full text-sm font-semibold">
                      Planned
                    </span>
                  </div>
                  <ul className="space-y-2 text-gray-300">
                    <li className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-yellow-400 flex-shrink-0" />
                      DeFi ecosystem expansion
                    </li>
                    <li className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-yellow-400 flex-shrink-0" />
                      Cross-chain bridge to major blockchains
                    </li>
                    <li className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-yellow-400 flex-shrink-0" />
                      NFT marketplace integration
                    </li>
                    <li className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-yellow-400 flex-shrink-0" />
                      Enhanced governance and DAO features
                    </li>
                  </ul>
                </div>
              </div>
            </div>

            {/* Q4 2025 - PLANNED */}
            <div className="glass-card p-6 rounded-xl border border-red-500/30">
              <div className="flex items-start gap-4">
                <div className="flex-shrink-0 w-12 h-12 rounded-full bg-red-500/30 border-2 border-red-500 flex items-center justify-center">
                  <Rocket className="w-6 h-6 text-red-400" />
                </div>
                <div className="flex-1">
                  <div className="flex items-center justify-between mb-2">
                    <h3 className="text-2xl font-bold">Q4 2025</h3>
                    <span className="px-3 py-1 bg-red-500/20 text-red-400 rounded-full text-sm font-semibold">
                      Planned
                    </span>
                  </div>
                  <ul className="space-y-2 text-gray-300">
                    <li className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-red-400 flex-shrink-0" />
                      Major exchange listings
                    </li>
                    <li className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-red-400 flex-shrink-0" />
                      Pan-African expansion campaign
                    </li>
                    <li className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-red-400 flex-shrink-0" />
                      Enterprise solutions for businesses
                    </li>
                    <li className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-red-400 flex-shrink-0" />
                      AfriX 2.0 platform upgrade
                    </li>
                  </ul>
                </div>
              </div>
            </div>
          </div>

          {/* Footer CTA */}
          <div className="mt-16 glass-card p-8 rounded-xl border border-green-500/30 text-center">
            <h2 className="text-3xl font-bold mb-4">Be Part of Our Journey</h2>
            <p className="text-gray-300 mb-6">
              Join thousands of Africans building the future of digital finance together.
            </p>
            <div className="flex gap-4 justify-center flex-wrap">
              <Link
                href="/auth/sign-up"
                className="px-8 py-3 rounded-lg bg-gradient-to-r from-green-500 to-green-600 text-black font-bold hover:shadow-lg hover:shadow-green-500/50 transition"
              >
                Get Started
              </Link>
              <Link
                href="/about/whitepaper"
                className="px-8 py-3 rounded-lg border border-green-500/30 text-green-400 hover:bg-green-500/10 transition font-bold"
              >
                Read Whitepaper
              </Link>
            </div>
          </div>
        </div>
      </main>
      <Footer />
    </div>
  )
}
