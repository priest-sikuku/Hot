"use client"
import { useEffect, useState } from "react"
import { createClient } from "@/lib/supabase/client"
import { useRouter } from "next/navigation"
import Header from "@/components/header"
import Footer from "@/components/footer"
import { DashboardStats } from "@/components/dashboard-stats"
import { GuestBanner } from "@/components/guest-banner"
import { Button } from "@/components/ui/button"
import { UserTransferModal } from "@/components/user-transfer-modal"
import { Users } from "lucide-react"

export default function AssetsPage() {
  const router = useRouter()
  const [user, setUser] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const [currentBalance, setCurrentBalance] = useState(0)
  const [showTransferModal, setShowTransferModal] = useState(false)
  const [walletAddress, setWalletAddress] = useState("")

  useEffect(() => {
    const checkUser = async () => {
      const supabase = createClient()
      const {
        data: { user },
      } = await supabase.auth.getUser()

      setUser(user)

      if (user) {
        const { data: profile } = await supabase.from("profiles").select("wallet_address").eq("id", user.id).single()

        if (profile?.wallet_address) {
          setWalletAddress(profile.wallet_address)
        }

        // Get current balance
        const { data: coins } = await supabase
          .from("coins")
          .select("amount")
          .eq("user_id", user.id)
          .eq("claim_type", "dashboard")
          .eq("status", "unlocked")
          .limit(1)
          .single()

        if (coins) {
          setCurrentBalance(coins.amount)
        }
      }

      setLoading(false)
    }

    checkUser()
  }, [])

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center pb-20 md:pb-0">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-green-500" />
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-[#0a0f1c] via-[#0d1b2a] to-[#051428] pb-20 md:pb-0">
      <Header />
      <GuestBanner />
      <main className="max-w-6xl mx-auto px-4 py-8">
        <div className="mb-8">
          <h1 className="text-3xl md:text-4xl font-bold mb-2 bg-gradient-to-r from-green-400 to-yellow-400 bg-clip-text text-transparent">
            My Assets
          </h1>
          <p className="text-gray-400">Manage your digital assets and cryptocurrency holdings</p>
        </div>

        {user ? (
          <>
            <DashboardStats />

            <div className="mt-8 grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Wallet Info Section */}
              <div className="bg-gradient-to-br from-gray-800/50 to-gray-900/50 backdrop-blur-sm border border-white/10 rounded-xl p-6">
                <h3 className="text-lg font-semibold mb-4">Wallet Information</h3>
                <div className="space-y-3">
                  <div>
                    <p className="text-sm text-gray-400 mb-1">Wallet Address</p>
                    <p className="font-mono text-sm bg-gray-900/50 p-2 rounded text-green-400 break-all">
                      {walletAddress || "Not set"}
                    </p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-400 mb-1">Available Balance</p>
                    <p className="text-2xl font-bold text-green-400">{currentBalance.toFixed(2)} AFX</p>
                  </div>
                </div>
              </div>

              {/* Transfer Section */}
              <div className="bg-gradient-to-br from-gray-800/50 to-gray-900/50 backdrop-blur-sm border border-white/10 rounded-xl p-6">
                <h3 className="text-lg font-semibold mb-4">Send AFX to User</h3>
                <p className="text-sm text-gray-400 mb-4">
                  Transfer AFX directly to another user's account. Minimum 10 AFX per transfer.
                </p>
                <Button
                  onClick={() => setShowTransferModal(true)}
                  className="w-full bg-emerald-500 hover:bg-emerald-600 text-white font-semibold gap-2"
                >
                  <Users size={18} />
                  Send AFX to User
                </Button>
              </div>
            </div>
          </>
        ) : (
          <div className="bg-gradient-to-br from-gray-800/50 to-gray-900/50 backdrop-blur-sm border border-white/10 rounded-xl p-8 text-center">
            <p className="text-gray-400 mb-4">Sign in to view your asset balances</p>
            <Button
              onClick={() => router.push("/auth/sign-in?next=/assets")}
              className="bg-green-500 hover:bg-green-600"
            >
              Sign In
            </Button>
          </div>
        )}

        <div className="mt-8 bg-gradient-to-br from-gray-800/50 to-gray-900/50 backdrop-blur-sm border border-white/10 rounded-xl p-6">
          <h2 className="text-xl font-bold mb-4">Asset Management</h2>
          <p className="text-gray-400 mb-4">
            Your asset dashboard displays real-time balances from the blockchain and database.
          </p>
          <div className="grid gap-4 md:grid-cols-2">
            <div className="flex items-start gap-3">
              <div className="w-8 h-8 bg-green-500/20 rounded-lg flex items-center justify-center flex-shrink-0 mt-1">
                ✓
              </div>
              <div>
                <h3 className="font-semibold mb-1">Real-time Tracking</h3>
                <p className="text-sm text-gray-400">Monitor your asset values in real-time</p>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <div className="w-8 h-8 bg-blue-500/20 rounded-lg flex items-center justify-center flex-shrink-0 mt-1">
                ✓
              </div>
              <div>
                <h3 className="font-semibold mb-1">Secure Storage</h3>
                <p className="text-sm text-gray-400">Your assets are protected with industry-standard security</p>
              </div>
            </div>
          </div>
        </div>
      </main>

      {user && (
        <UserTransferModal
          open={showTransferModal}
          onOpenChange={setShowTransferModal}
          currentUserBalance={currentBalance}
          onTransferComplete={() => {
            // Refresh balance after transfer
            const checkBalance = async () => {
              const supabase = createClient()
              const { data: coins } = await supabase
                .from("coins")
                .select("amount")
                .eq("user_id", user.id)
                .eq("claim_type", "dashboard")
                .eq("status", "unlocked")
                .limit(1)
                .single()

              if (coins) {
                setCurrentBalance(coins.amount)
              }
            }
            checkBalance()
          }}
        />
      )}

      <Footer />
    </div>
  )
}
