"use client"

import { useState, useEffect } from "react"

interface CurrencyRates {
  KES: number
  UGX: number
  TZS: number
  GHS: number
  NGN: number
  ZAR: number
  ZMW: number
  XOF: number
  BWP: number
  ZWL: number
  USD: number
}

interface RatesResponse {
  rates: CurrencyRates
  cached: boolean
  fallback?: boolean
  timestamp: string
}

export function useCurrencyRates() {
  const [rates, setRates] = useState<CurrencyRates | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchRates = async () => {
      try {
        setLoading(true)
        const response = await fetch("/api/currency-rates")

        if (!response.ok) {
          throw new Error(`Failed to fetch rates: ${response.status}`)
        }

        const data: RatesResponse = await response.json()
        setRates(data.rates)
        setError(null)
      } catch (err) {
        console.error("[v0] Error fetching currency rates:", err)
        setError(err instanceof Error ? err.message : "Unknown error")
      } finally {
        setLoading(false)
      }
    }

    fetchRates()

    // Refresh rates every hour
    const interval = setInterval(fetchRates, 60 * 60 * 1000)
    return () => clearInterval(interval)
  }, [])

  return { rates, loading, error }
}

export function getExchangeRate(currencyCode: string, rates: CurrencyRates | null): number {
  if (!rates) return 1

  const rate = rates[currencyCode as keyof CurrencyRates]
  return rate || 1
}

export function convertCurrency(
  amount: number,
  fromCurrency: string,
  toCurrency: string,
  rates: CurrencyRates | null,
): number {
  if (!rates) return amount

  const fromRate = getExchangeRate(fromCurrency, rates)
  const toRate = getExchangeRate(toCurrency, rates)

  return (amount / fromRate) * toRate
}
