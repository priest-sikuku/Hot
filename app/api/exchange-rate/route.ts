import { NextResponse } from "next/server"

// Using ExchangeRate-API (free tier - 1500 requests/month)
// Alternative: https://api.exchangerate.host (also free)
const EXCHANGE_API_URL = "https://api.exchangerate-api.com/v4/latest/USD"

export const dynamic = "force-dynamic"
export const revalidate = 0

let cachedRate: { rate: number; timestamp: number } | null = null
const CACHE_DURATION = 60 * 1000 // Cache for 1 minute to avoid API limits

export async function GET() {
  try {
    const now = Date.now()
    
    // Return cached rate if fresh (less than 1 minute old)
    if (cachedRate && now - cachedRate.timestamp < CACHE_DURATION) {
      return NextResponse.json({
        usd_to_kes: cachedRate.rate,
        kes_to_usd: 1 / cachedRate.rate,
        cached: true,
        timestamp: new Date(cachedRate.timestamp).toISOString(),
      })
    }

    // Fetch live exchange rate
    const response = await fetch(EXCHANGE_API_URL, {
      next: { revalidate: 60 }, // Revalidate every minute
    })

    if (!response.ok) {
      console.error("[v0] Exchange rate API error:", response.status)
      // Fallback to your specified rate
      return NextResponse.json({
        usd_to_kes: 129.5,
        kes_to_usd: 1 / 129.5,
        cached: false,
        fallback: true,
        timestamp: new Date().toISOString(),
      })
    }

    const data = await response.json()
    const kesRate = data.rates?.KES || 129.5

    // Cache the rate
    cachedRate = {
      rate: kesRate,
      timestamp: now,
    }

    return NextResponse.json({
      usd_to_kes: kesRate,
      kes_to_usd: 1 / kesRate,
      cached: false,
      fallback: false,
      timestamp: new Date().toISOString(),
    })
  } catch (error) {
    console.error("[v0] Error fetching exchange rate:", error)
    
    // Return fallback rate
    return NextResponse.json({
      usd_to_kes: 129.5,
      kes_to_usd: 1 / 129.5,
      cached: false,
      fallback: true,
      error: "Using fallback rate",
      timestamp: new Date().toISOString(),
    })
  }
}
