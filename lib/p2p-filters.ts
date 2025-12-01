// Helper functions for P2P trading filters and data fetching

import { createClient } from "@/lib/supabase/client"

export interface Country {
  id: string
  code: string
  name: string
  currency_code: string
  currency_name: string
  currency_symbol: string
  exchange_rate_to_kes: number
}

export interface PaymentGateway {
  id: string
  gateway_code: string
  gateway_name: string
  gateway_type: string
  field_labels: Record<string, string>
  currency_code?: string
}

export interface AdFilters {
  paymentMethods?: string[]
  priceMin?: number
  priceMax?: number
  minAmount?: number
}

export const KENYA_PAYMENT_METHODS = [
  { code: "mpesa", name: "M-Pesa", type: "mobile_money" },
  { code: "mpesa_paybill", name: "M-Pesa Paybill", type: "mobile_money" },
  { code: "airtel_money", name: "Airtel Money", type: "mobile_money" },
  { code: "bank_transfer", name: "Bank Transfer", type: "bank" },
]

export async function fetchCountries(): Promise<Country[]> {
  const supabase = createClient()
  const { data, error } = await supabase.from("african_countries").select("*").eq("status", "active").order("name")

  if (error) {
    console.error("[v0] Error fetching countries:", error)
    return []
  }

  return data || []
}

export async function fetchPaymentGatewaysByCountry(countryCode = "KE"): Promise<PaymentGateway[]> {
  const supabase = createClient()

  const { data: country } = await supabase.from("african_countries").select("id").eq("code", "KE").single()

  if (!country) return []

  const { data, error } = await supabase
    .from("country_payment_gateways")
    .select("*")
    .eq("country_id", country.id)
    .eq("is_active", true)
    .order("gateway_name")

  if (error) {
    console.error("[v0] Error fetching payment gateways:", error)
    return []
  }

  return data || []
}

export async function fetchPaymentGatewaysByCurrency(
  countryCode = "KE",
  currencyCode = "KES",
): Promise<PaymentGateway[]> {
  const supabase = createClient()

  const { data: country } = await supabase.from("african_countries").select("id").eq("code", "KE").single()

  if (!country) return []

  let query = supabase.from("country_payment_gateways").select("*").eq("country_id", country.id).eq("is_active", true)

  // If USD currency is selected, only show PayPal and PerfectMoney
  if (currencyCode === "USD") {
    query = query.in("gateway_code", ["paypal", "perfectmoney"])
  } else {
    // For local currencies, exclude USD-only gateways
    query = query.not("gateway_code", "in", '("paypal","perfectmoney")')
  }

  const { data, error } = await query.order("gateway_name")

  if (error) {
    console.error("[v0] Error fetching payment gateways by currency:", error)
    return []
  }

  return data || []
}

export async function fetchAdsWithFilters(adType: "buy" | "sell", filters: AdFilters = {}): Promise<any[]> {
  const supabase = createClient()

  let query = supabase
    .from("p2p_ads")
    .select(
      `
      *,
      profiles:user_id (
        username,
        email,
        rating
      )
    `,
    )
    .eq("ad_type", adType)
    .eq("status", "active")
    .gt("expires_at", new Date().toISOString())

  // Optional filters - using correct column names
  if (filters.paymentMethods && filters.paymentMethods.length > 0) {
    // Filter by payment methods available in the ad
    const methodFilters = filters.paymentMethods.map((m) => `${m}_number`)
    // For simplicity, we won't filter by payment method here - all active ads will show
  }

  if (filters.priceMin !== undefined) {
    query = query.gte("afx_amount", filters.priceMin)
  }

  if (filters.priceMax !== undefined) {
    query = query.lte("afx_amount", filters.priceMax)
  }

  if (filters.minAmount !== undefined) {
    query = query.gte("min_amount", filters.minAmount)
  }

  const { data, error } = await query.order("created_at", { ascending: false })

  if (error) {
    console.error("[v0] Error fetching ads with filters:", error)
    return []
  }

  return data || []
}

export function getPaymentMethodDetails(gateway: PaymentGateway): { label: string; type: string }[] {
  if (!gateway.field_labels) return []

  return Object.entries(gateway.field_labels).map(([key, label]) => ({
    label: label as string,
    type: key,
  }))
}
