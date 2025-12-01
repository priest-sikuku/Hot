"use client"

import { useEffect, useState } from "react"

export function AnimatedMiner({ isActive }: { isActive: boolean }) {
  const [digDirection, setDigDirection] = useState<"left" | "right">("right")

  useEffect(() => {
    if (!isActive) return

    const interval = setInterval(() => {
      setDigDirection((prev) => (prev === "left" ? "right" : "left"))
    }, 800)

    return () => clearInterval(interval)
  }, [isActive])

  return (
    <div className="relative w-64 h-64 mx-auto">
      <div className="absolute bottom-8 left-1/2 -translate-x-1/2 w-40 h-16">
        <svg viewBox="0 0 120 50" className="w-full h-full">
          {/* Coin pile base */}
          <ellipse cx="60" cy="40" rx="50" ry="15" fill="#F59E0B" opacity="0.3" />

          {/* Individual glowing coins */}
          {[...Array(8)].map((_, i) => (
            <g key={i} opacity={isActive ? "1" : "0.5"}>
              <circle
                cx={40 + i * 10}
                cy={35 - Math.random() * 10}
                r="6"
                fill="url(#coinGradient)"
                className={isActive ? "animate-pulse-slow" : ""}
              />
              {/* AFX label on coins */}
              <text
                x={40 + i * 10}
                y={35 - Math.random() * 10}
                fontSize="4"
                fill="#92400E"
                textAnchor="middle"
                fontWeight="bold"
              >
                A
              </text>
            </g>
          ))}

          {/* Gradient definition for golden coins */}
          <defs>
            <radialGradient id="coinGradient">
              <stop offset="0%" stopColor="#FCD34D" />
              <stop offset="50%" stopColor="#F59E0B" />
              <stop offset="100%" stopColor="#D97706" />
            </radialGradient>
          </defs>

          {/* Glow effect */}
          {isActive && (
            <ellipse cx="60" cy="35" rx="45" ry="12" fill="#FCD34D" opacity="0.2" className="animate-pulse" />
          )}
        </svg>
      </div>

      <svg viewBox="0 0 200 200" className="w-full h-full">
        {/* Shadow */}
        <ellipse cx="100" cy="185" rx="40" ry="6" fill="rgba(0,0,0,0.3)" />

        {/* Legs - bent position for digging */}
        <g className={isActive ? "animate-bounce-subtle" : ""}>
          <path d="M 85 140 Q 80 160 75 180 L 78 185 L 88 185 L 90 165 Z" fill="#2C3E50" />
          <path d="M 115 140 Q 120 160 125 180 L 122 185 L 112 185 L 110 165 Z" fill="#2C3E50" />

          {/* Work boots */}
          <rect x="73" y="182" width="18" height="10" rx="2" fill="#5D4E37" />
          <rect x="109" y="182" width="18" height="10" rx="2" fill="#5D4E37" />
        </g>

        {/* Body - bent forward digging position */}
        <g className={isActive ? "animate-bounce-subtle" : ""}>
          {/* Torso bent forward */}
          <ellipse cx="100" cy="120" rx="25" ry="30" fill="#DC2626" transform="rotate(-10 100 120)" />

          {/* Muscular back definition */}
          <path d="M 85 110 Q 100 115 115 110" stroke="#B91C1C" strokeWidth="3" fill="none" />
        </g>

        {/* Head bent down watching the dig */}
        <g className={isActive ? "animate-bounce-subtle" : ""}>
          <circle cx="100" cy="85" r="18" fill="#D4A574" />

          {/* Hair */}
          <path d="M 82 80 Q 82 65 100 62 Q 118 65 118 80 Z" fill="#2d2d2d" />

          {/* Face looking down */}
          <circle cx="94" cy="84" r="2" fill="#1e293b" />
          <circle cx="106" cy="84" r="2" fill="#1e293b" />
          <path d="M 94 90 Q 100 92 106 90" stroke="#8B4513" strokeWidth="1.5" fill="none" />
        </g>

        <g
          className="transition-all duration-800 ease-in-out"
          style={{
            transformOrigin: "100px 110px",
            transform: digDirection === "left" ? "rotate(-15deg)" : "rotate(15deg)",
          }}
        >
          {/* Left arm extended */}
          <ellipse cx="70" cy="115" rx="10" ry="28" fill="#C9996B" transform="rotate(-25 70 115)" />

          {/* Right arm extended */}
          <ellipse cx="130" cy="115" rx="10" ry="28" fill="#C9996B" transform="rotate(25 130 115)" />

          {/* Hands gripping jembe handle */}
          <circle cx="80" cy="140" r="8" fill="#C9996B" />
          <circle cx="120" cy="140" r="8" fill="#C9996B" />

          {/* Long wooden handle */}
          <rect x="97" y="100" width="6" height="100" rx="3" fill="#8B4513" className="transition-all duration-800" />

          {/* Wood grain detail */}
          <rect x="98" y="102" width="2" height="96" rx="1" fill="#654321" opacity="0.6" />

          {/* Jembe blade (wide hoe blade at angle) */}
          <g transform="translate(100, 165)">
            <path
              d="M -25 0 L -20 -8 L 20 -8 L 25 0 L 20 3 L -20 3 Z"
              fill="#718096"
              stroke="#4A5568"
              strokeWidth="1"
            />
            {/* Metal shine */}
            <rect x="-18" y="-6" width="36" height="2" rx="1" fill="white" opacity="0.5" />
          </g>
        </g>
      </svg>

      {isActive && <CoinParticles />}
    </div>
  )
}

function CoinParticles() {
  const [particles, setParticles] = useState<number[]>([])

  useEffect(() => {
    const interval = setInterval(() => {
      setParticles((prev) => [...prev, Date.now()])
      setTimeout(() => {
        setParticles((prev) => prev.slice(1))
      }, 2000)
    }, 500)

    return () => clearInterval(interval)
  }, [])

  return (
    <div className="absolute inset-0 pointer-events-none">
      {particles.map((id, index) => (
        <div
          key={id}
          className="absolute animate-coin-pop"
          style={{
            left: `${35 + Math.random() * 30}%`,
            top: "60%",
            animationDelay: `${index * 0.08}s`,
          }}
        >
          <div className="relative">
            {/* Glow halo */}
            <div className="absolute inset-0 w-10 h-10 rounded-full bg-yellow-400 blur-md opacity-60"></div>

            {/* Coin */}
            <div className="relative w-8 h-8 rounded-full bg-gradient-to-br from-yellow-200 via-yellow-400 to-yellow-600 shadow-xl flex items-center justify-center border-2 border-yellow-300">
              <div className="absolute inset-0 rounded-full bg-gradient-to-tr from-transparent via-white to-transparent opacity-40"></div>
              <span className="text-xs font-black text-yellow-900 z-10 drop-shadow-sm">AFX</span>
            </div>

            {/* Sparkle effects */}
            <div className="absolute top-0 right-0 w-2 h-2">
              <div className="absolute w-1 h-1 bg-white rounded-full animate-ping"></div>
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}
