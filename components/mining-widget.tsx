"use client"

import { useState, useEffect } from "react"
import { Pickaxe, Coins, Clock, Zap } from "lucide-react"
import { Button } from "@/components/ui/button"
import { claimMiningReward, getMiningStatus } from "@/lib/actions/mining"
import { useRouter } from "next/navigation"

export function MiningWidget() {
  const router = useRouter()
  const [canMine, setCanMine] = useState(false)
  const [timeLeft, setTimeLeft] = useState(0)
  const [isClaiming, setIsClaiming] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [showSuccess, setShowSuccess] = useState(false)

  useEffect(() => {
    checkMiningStatus()
    const interval = setInterval(checkMiningStatus, 1000)
    return () => clearInterval(interval)
  }, [])

  async function checkMiningStatus() {
    const status = await getMiningStatus()
    setCanMine(status.canMine)
    setTimeLeft(status.timeLeft)
  }

  async function handleClaim() {
    setIsClaiming(true)
    setError(null)

    const result = await claimMiningReward()

    if (result.success) {
      setShowSuccess(true)
      setTimeout(() => setShowSuccess(false), 3000)
      checkMiningStatus()
      router.refresh()
    } else {
      setError(result.error || "Failed to claim reward")
    }

    setIsClaiming(false)
  }

  function formatTime(seconds: number) {
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    const secs = seconds % 60
    return `${hours}h ${minutes}m ${secs}s`
  }

  const progress = canMine ? 100 : Math.max(0, ((14400 - timeLeft) / 14400) * 100)

  return (
    <div className="relative overflow-hidden glass-card rounded-2xl border border-green-500/20 p-6">
      {/* Animated background gradient */}
      <div className="absolute inset-0 bg-gradient-to-br from-green-500/5 via-yellow-500/5 to-green-500/5 animate-pulse-slow" />

      {/* Content */}
      <div className="relative z-10">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="p-3 rounded-xl bg-gradient-to-br from-green-500/20 to-yellow-500/20 border border-green-500/30">
              <Pickaxe className="w-6 h-6 text-green-400" />
            </div>
            <div>
              <h3 className="text-xl font-bold text-white">AFX Mining</h3>
              <p className="text-sm text-gray-400">Claim every 4 hours</p>
            </div>
          </div>
          <div className="text-right">
            <div className="flex items-center gap-1.5">
              <Coins className="w-5 h-5 text-yellow-400" />
              <span className="text-2xl font-bold text-yellow-400">0.25</span>
            </div>
            <p className="text-xs text-gray-400">AFX Reward</p>
          </div>
        </div>

        {/* Progress Bar */}
        <div className="mb-6">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm text-gray-400 flex items-center gap-2">
              <Clock className="w-4 h-4" />
              {canMine ? "Ready to mine!" : `Next claim: ${formatTime(timeLeft)}`}
            </span>
            <span className="text-sm font-semibold text-green-400">{Math.round(progress)}%</span>
          </div>
          <div className="h-3 bg-gray-800/50 rounded-full overflow-hidden border border-gray-700/50">
            <div
              className="h-full bg-gradient-to-r from-green-500 via-yellow-400 to-green-500 transition-all duration-1000 ease-out relative"
              style={{ width: `${progress}%` }}
            >
              <div className="absolute inset-0 bg-white/20 animate-shimmer" />
            </div>
          </div>
        </div>

        {/* Claim Button */}
        <Button
          onClick={handleClaim}
          disabled={!canMine || isClaiming}
          className={`w-full h-14 text-lg font-bold rounded-xl transition-all ${
            canMine
              ? "bg-gradient-to-r from-green-500 to-yellow-500 hover:from-green-600 hover:to-yellow-600 text-gray-900 shadow-lg shadow-green-500/50"
              : "bg-gray-700/50 text-gray-400 cursor-not-allowed"
          }`}
        >
          {isClaiming ? (
            <div className="flex items-center gap-2">
              <div className="w-5 h-5 border-2 border-gray-900 border-t-transparent rounded-full animate-spin" />
              <span>Claiming...</span>
            </div>
          ) : canMine ? (
            <div className="flex items-center gap-2">
              <Zap className="w-5 h-5" />
              <span>Claim 0.25 AFX Now</span>
            </div>
          ) : (
            <span>Mining in Progress</span>
          )}
        </Button>

        {/* Error Message */}
        {error && (
          <div className="mt-4 p-3 bg-red-500/10 border border-red-500/30 rounded-lg">
            <p className="text-sm text-red-400 text-center">{error}</p>
          </div>
        )}

        {/* Success Animation */}
        {showSuccess && (
          <div className="mt-4 p-4 bg-green-500/10 border border-green-500/30 rounded-lg animate-slide-up">
            <p className="text-sm text-green-400 text-center font-semibold flex items-center justify-center gap-2">
              <Coins className="w-5 h-5 animate-bounce" />
              Successfully claimed 0.25 AFX!
            </p>
          </div>
        )}

        {/* Info Cards */}
        <div className="grid grid-cols-3 gap-3 mt-6">
          <div className="bg-gray-800/30 rounded-lg p-3 border border-gray-700/50">
            <div className="flex items-center gap-1.5 mb-1">
              <Clock className="w-4 h-4 text-blue-400" />
              <p className="text-xs text-gray-400">Interval</p>
            </div>
            <p className="text-sm font-bold text-white">4 Hours</p>
          </div>
          <div className="bg-gray-800/30 rounded-lg p-3 border border-gray-700/50">
            <div className="flex items-center gap-1.5 mb-1">
              <Coins className="w-4 h-4 text-yellow-400" />
              <p className="text-xs text-gray-400">Reward</p>
            </div>
            <p className="text-sm font-bold text-white">0.25 AFX</p>
          </div>
          <div className="bg-gray-800/30 rounded-lg p-3 border border-gray-700/50">
            <div className="flex items-center gap-1.5 mb-1">
              <Zap className="w-4 h-4 text-green-400" />
              <p className="text-xs text-gray-400">Status</p>
            </div>
            <p className="text-sm font-bold text-white">{canMine ? "Ready" : "Mining"}</p>
          </div>
        </div>
      </div>
    </div>
  )
}
