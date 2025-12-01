"use client"

import { useEffect, useState } from "react"

interface FourSegmentCountdownProps {
  timeRemaining: number // milliseconds
  totalTime: number // milliseconds (5 hours = 18000000ms)
  onComplete?: () => void
}

export function FourSegmentCountdown({ timeRemaining, totalTime, onComplete }: FourSegmentCountdownProps) {
  const [progress, setProgress] = useState(0)
  const [animatedProgress, setAnimatedProgress] = useState(0)

  useEffect(() => {
    // Calculate progress (0-100)
    const percent = Math.max(0, Math.min(100, ((totalTime - timeRemaining) / totalTime) * 100))
    setProgress(percent)

    // Smooth animation every 3 seconds
    const interval = setInterval(() => {
      setAnimatedProgress((prev) => {
        const target = ((totalTime - timeRemaining) / totalTime) * 100
        const diff = target - prev
        return prev + diff * 0.1
      })
    }, 100)

    if (timeRemaining <= 0 && onComplete) {
      onComplete()
    }

    return () => clearInterval(interval)
  }, [timeRemaining, totalTime, onComplete])

  const size = 280
  const strokeWidth = 20
  const radius = (size - strokeWidth) / 2
  const circumference = 2 * Math.PI * radius
  const center = size / 2

  // Calculate stroke dash offset for progress
  const offset = circumference - (animatedProgress / 100) * circumference

  // Determine current color segment
  const getSegmentColor = () => {
    if (animatedProgress < 25) return "#3B82F6" // Blue
    if (animatedProgress < 50) return "#10B981" // Green
    if (animatedProgress < 75) return "#FFD700" // Gold
    return "#EF4444" // Red
  }

  // Format time remaining
  const formatTime = (ms: number) => {
    const totalSeconds = Math.floor(ms / 1000)
    const hours = Math.floor(totalSeconds / 3600)
    const minutes = Math.floor((totalSeconds % 3600) / 60)
    const seconds = totalSeconds % 60
    return `${hours.toString().padStart(2, "0")}:${minutes.toString().padStart(2, "0")}:${seconds.toString().padStart(2, "0")}`
  }

  return (
    <div className="relative inline-flex items-center justify-center">
      <svg width={size} height={size} className="transform -rotate-90">
        {/* Background segments with gradients */}
        <defs>
          {/* Blue gradient (0-25%) */}
          <linearGradient id="blueGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#3B82F6" />
            <stop offset="100%" stopColor="#60A5FA" />
          </linearGradient>
          {/* Green gradient (25-50%) */}
          <linearGradient id="greenGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#10B981" />
            <stop offset="100%" stopColor="#34D399" />
          </linearGradient>
          {/* Gold gradient (50-75%) */}
          <linearGradient id="goldGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#FFD700" />
            <stop offset="100%" stopColor="#FFA500" />
          </linearGradient>
          {/* Red gradient (75-100%) */}
          <linearGradient id="redGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#EF4444" />
            <stop offset="100%" stopColor="#F87171" />
          </linearGradient>

          {/* Pulsing glow filter */}
          <filter id="glow">
            <feGaussianBlur stdDeviation="4" result="coloredBlur" />
            <feMerge>
              <feMergeNode in="coloredBlur" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>

        {/* Background circle */}
        <circle
          cx={center}
          cy={center}
          r={radius}
          stroke="rgba(255,255,255,0.1)"
          strokeWidth={strokeWidth}
          fill="none"
        />

        {/* Progress circle with gradient */}
        <circle
          cx={center}
          cy={center}
          r={radius}
          stroke={`url(#${animatedProgress < 25 ? "blueGrad" : animatedProgress < 50 ? "greenGrad" : animatedProgress < 75 ? "goldGrad" : "redGrad"})`}
          strokeWidth={strokeWidth}
          fill="none"
          strokeDasharray={circumference}
          strokeDashoffset={offset}
          strokeLinecap="round"
          filter="url(#glow)"
          className="transition-all duration-300 ease-out animate-pulse-slow"
        />
      </svg>

      {/* Center content */}
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <div className="text-5xl font-bold text-white mb-2 animate-pulse-slow">{Math.round(animatedProgress)}%</div>
        <div className="text-lg text-gray-300 font-mono">{formatTime(timeRemaining)}</div>
        <div className="mt-2 text-sm text-gray-400">
          {animatedProgress < 25
            ? "🔵 Starting"
            : animatedProgress < 50
              ? "🟢 Progress"
              : animatedProgress < 75
                ? "🟡 Almost"
                : "🔴 Ready"}
        </div>
      </div>
    </div>
  )
}
