"use client"

import { useEffect, useState } from "react"

interface ExchangeRate {
  usd_to_kes: number
  kes_to_usd: number
  cached: boolean
  fallback?: boolean
  timestamp: string
}

export function useExchangeRate() {
  const [exchangeRate, setExchangeRate] = useState<ExchangeRate>({
    usd_to_kes: 129.5,
    kes_to_usd: 1 / 129.5,
    cached: true,
    fallback: true,
    timestamp: new Date().toISOString(),
  })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchRate = async () => {
      try {
        const response = await fetch("/api/exchange-rate")
        const data = await response.json()
        setExchangeRate(data)
        setLoading(false)
      } catch (error) {
        console.error("[v0] Error fetching exchange rate:", error)
        setLoading(false)
      }
    }

    // Initial fetch
    fetchRate()

    // Refresh every minute
    const interval = setInterval(fetchRate, 60 * 1000)

    return () => clearInterval(interval)
  }, [])

  return { exchangeRate, loading }
}

export function convertKEStoUSD(kes: number, rate: number): number {
  return kes / rate
}

export function convertUSDtoKES(usd: number, rate: number): number {
  return usd * rate
}
