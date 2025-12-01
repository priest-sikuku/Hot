import Header from "@/components/header"
import Footer from "@/components/footer"
import { FileText, Map, Target, Rocket, Shield, Users, TrendingUp, Globe } from 'lucide-react'
import Link from "next/link"

export default function AboutPage() {
  return (
    <div className="min-h-screen flex flex-col pb-20 md:pb-0">
      <Header />
      <main className="flex-1 bg-gradient-to-b from-gray-950 to-black">
        <div className="max-w-6xl mx-auto px-6 py-12">
          {/* Hero Section */}
          <div className="text-center mb-16">
            <h1 className="text-4xl md:text-6xl font-bold mb-4 bg-gradient-to-r from-green-400 via-yellow-400 to-green-500 bg-clip-text text-transparent">
              About AfriX
            </h1>
            <p className="text-lg text-gray-400 max-w-3xl mx-auto">
              The revolutionary digital currency designed for Africa's growing economy. Built on transparency, security, and community-driven growth.
            </p>
          </div>

          {/* Quick Links */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-16">
            <Link href="/about/whitepaper" className="glass-card p-6 rounded-xl border border-green-500/20 hover:border-green-500/50 transition group">
              <FileText className="w-12 h-12 text-green-400 mb-4" />
              <h3 className="text-2xl font-bold mb-2 group-hover:text-green-400 transition">Whitepaper</h3>
              <p className="text-gray-400">Read our comprehensive technical documentation and vision</p>
            </Link>
            
            <Link href="/about/roadmap" className="glass-card p-6 rounded-xl border border-blue-500/20 hover:border-blue-500/50 transition group">
              <Map className="w-12 h-12 text-blue-400 mb-4" />
              <h3 className="text-2xl font-bold mb-2 group-hover:text-blue-400 transition">Roadmap</h3>
              <p className="text-gray-400">Explore our development milestones and future plans</p>
            </Link>
          </div>

          {/* Mission & Vision */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-16">
            <div className="glass-card p-6 rounded-xl border border-purple-500/20">
              <Target className="w-10 h-10 text-purple-400 mb-4" />
              <h2 className="text-2xl font-bold mb-3">Our Mission</h2>
              <p className="text-gray-300">
                To empower every African with accessible digital currency that enables seamless peer-to-peer transactions, 
                fair mining opportunities, and financial independence across the continent.
              </p>
            </div>

            <div className="glass-card p-6 rounded-xl border border-yellow-500/20">
              <Rocket className="w-10 h-10 text-yellow-400 mb-4" />
              <h2 className="text-2xl font-bold mb-3">Our Vision</h2>
              <p className="text-gray-300">
                To become Africa's leading decentralized digital currency, fostering economic growth through transparent, 
                secure, and community-driven financial ecosystems.
              </p>
            </div>
          </div>

          {/* Key Features */}
          <div className="mb-16">
            <h2 className="text-3xl font-bold mb-8 text-center">Why AfriX?</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="glass-card p-5 rounded-lg border border-white/10">
                <Shield className="w-8 h-8 text-green-400 mb-3" />
                <h3 className="text-lg font-bold mb-2">Secure & Transparent</h3>
                <p className="text-sm text-gray-400">
                  Built with robust security measures and transparent blockchain technology
                </p>
              </div>

              <div className="glass-card p-5 rounded-lg border border-white/10">
                <Users className="w-8 h-8 text-blue-400 mb-3" />
                <h3 className="text-lg font-bold mb-2">Community Driven</h3>
                <p className="text-sm text-gray-400">
                  Powered by a growing community with referral rewards and P2P trading
                </p>
              </div>

              <div className="glass-card p-5 rounded-lg border border-white/10">
                <TrendingUp className="w-8 h-8 text-yellow-400 mb-3" />
                <h3 className="text-lg font-bold mb-2">Fair Mining</h3>
                <p className="text-sm text-gray-400">
                  Accessible mining system with referral boosts and limited supply of 1M AFX
                </p>
              </div>

              <div className="glass-card p-5 rounded-lg border border-white/10">
                <Globe className="w-8 h-8 text-purple-400 mb-3" />
                <h3 className="text-lg font-bold mb-2">Pan-African Reach</h3>
                <p className="text-sm text-gray-400">
                  Designed specifically for Africa's unique economic landscape and needs
                </p>
              </div>

              <div className="glass-card p-5 rounded-lg border border-white/10">
                <FileText className="w-8 h-8 text-red-400 mb-3" />
                <h3 className="text-lg font-bold mb-2">P2P Marketplace</h3>
                <p className="text-sm text-gray-400">
                  Buy and sell AFX directly with other users using local payment methods
                </p>
              </div>

              <div className="glass-card p-5 rounded-lg border border-white/10">
                <Rocket className="w-8 h-8 text-cyan-400 mb-3" />
                <h3 className="text-lg font-bold mb-2">Growing Ecosystem</h3>
                <p className="text-sm text-gray-400">
                  Continuous development with new features and partnerships
                </p>
              </div>
            </div>
          </div>

          {/* Call to Action */}
          <div className="glass-card p-8 rounded-xl border border-green-500/30 text-center">
            <h2 className="text-3xl font-bold mb-4">Join the AfriX Revolution</h2>
            <p className="text-gray-300 mb-6 max-w-2xl mx-auto">
              Start mining, trading, and earning with Africa's most accessible digital currency today.
            </p>
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
