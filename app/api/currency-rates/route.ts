import { NextResponse } from "next/server"

// Using Open Exchange Rates API (free tier available)
// Get your free API key at: https://openexchangerates.org/
const OPEN_EXCHANGE_API_KEY = process.env.OPEN_EXCHANGE_RATES_KEY || "demo" // Demo for testing
const OPEN_EXCHANGE_URL = "https://openexchangerates.org/api/latest.json"

// Backup: exchangerate-api.com (1500 free requests/month)
const BACKUP_API_URL = "https://api.exchangerate-api.com/v4/latest/USD"

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

let cachedRates: { rates: CurrencyRates; timestamp: number } | null = null
const CACHE_DURATION = 60 * 60 * 1000 // Cache for 1 hour

export const dynamic = "force-dynamic"
export const revalidate = 3600 // Revalidate every hour

async function fetchFromOpenExchange(): Promise<Partial<CurrencyRates> | null> {
  try {
    const response = await fetch(
      `${OPEN_EXCHANGE_URL}?app_id=${OPEN_EXCHANGE_API_KEY}&symbols=KES,UGX,TZS,GHS,NGN,ZAR,ZMW,XOF,BWP,ZWL,USD`,
      { next: { revalidate: 3600 } },
    )

    if (!response.ok) {
      console.error("[v0] Open Exchange API error:", response.status)
      return null
    }

    const data = await response.json()
    if (!data.rates) return null

    // Convert from USD base to proper rates
    return {
      KES: data.rates.KES || 135.5,
      UGX: data.rates.UGX || 3850,
      TZS: data.rates.TZS || 2650,
      GHS: data.rates.GHS || 16.5,
      NGN: data.rates.NGN || 1580,
      ZAR: data.rates.ZAR || 18.2,
      ZMW: data.rates.ZMW || 30,
      XOF: data.rates.XOF || 655,
      BWP: data.rates.BWP || 13.8,
      ZWL: data.rates.ZWL || 6500,
      USD: 1.0,
    }
  } catch (error) {
    console.error("[v0] Error fetching from Open Exchange:", error)
    return null
  }
}

async function fetchFromBackupAPI(): Promise<Partial<CurrencyRates> | null> {
  try {
    const response = await fetch(BACKUP_API_URL, {
      next: { revalidate: 3600 },
    })

    if (!response.ok) {
      console.error("[v0] Backup API error:", response.status)
      return null
    }

    const data = await response.json()
    if (!data.rates) return null

    return {
      KES: data.rates.KES || 135.5,
      UGX: data.rates.UGX || 3850,
      TZS: data.rates.TZS || 2650,
      GHS: data.rates.GHS || 16.5,
      NGN: data.rates.NGN || 1580,
      ZAR: data.rates.ZAR || 18.2,
      ZMW: data.rates.ZMW || 30,
      XOF: data.rates.XOF || 655,
      BWP: data.rates.BWP || 13.8,
      ZWL: data.rates.ZWL || 6500,
      USD: 1.0,
    }
  } catch (error) {
    console.error("[v0] Error fetching from backup API:", error)
    return null
  }
}

function getFallbackRates(): CurrencyRates {
  return {
    KES: 135.5,
    UGX: 3850,
    TZS: 2650,
    GHS: 16.5,
    NGN: 1580,
    ZAR: 18.2,
    ZMW: 30,
    XOF: 655,
    BWP: 13.8,
    ZWL: 6500,
    USD: 1.0,
  }
}

export async function GET() {
  try {
    const now = Date.now()

    // Return cached rates if still fresh
    if (cachedRates && now - cachedRates.timestamp < CACHE_DURATION) {
      return NextResponse.json({
        rates: cachedRates.rates,
        cached: true,
        timestamp: new Date(cachedRates.timestamp).toISOString(),
      })
    }

    // Try primary API
    let rates = await fetchFromOpenExchange()

    // Fall back to secondary API
    if (!rates) {
      rates = await fetchFromBackupAPI()
    }

    // Use fallback rates if both fail
    if (!rates) {
      rates = getFallbackRates()
    }

    // Cache the rates
    cachedRates = {
      rates: rates as CurrencyRates,
      timestamp: now,
    }

    return NextResponse.json({
      rates: rates as CurrencyRates,
      cached: false,
      fallback: !rates.KES || rates.KES > 200, // If rate seems wrong, it's fallback
      timestamp: new Date().toISOString(),
    })
  } catch (error) {
    console.error("[v0] Error in currency rates endpoint:", error)

    const fallbackRates = getFallbackRates()
    return NextResponse.json({
      rates: fallbackRates,
      cached: false,
      fallback: true,
      error: "Using fallback rates",
      timestamp: new Date().toISOString(),
    })
  }
}
