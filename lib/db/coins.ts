import { createClient } from "@/lib/supabase/server"

export async function getUserCoins(userId: string) {
  const supabase = await createClient()
  const { data, error } = await supabase.from("coins").select("*").eq("user_id", userId)

  if (error) throw error
  return data
}

export async function getTotalCoins(userId: string) {
  const supabase = await createClient()
  const { data, error } = await supabase.from("coins").select("amount").eq("user_id", userId).eq("status", "active")

  if (error) throw error
  return data?.reduce((sum, coin) => sum + Number(coin.amount), 0) || 0
}

export async function claimCoins(userId: string, amount: number, lockPeriodDays = 7) {
  const supabase = await createClient()
  const lockedUntil = new Date()
  lockedUntil.setDate(lockedUntil.getDate() + lockPeriodDays)

  const { data, error } = await supabase.from("coins").insert({
    user_id: userId,
    amount,
    claim_type: "claim",
    locked_until: lockedUntil.toISOString(),
    lock_period_days: lockPeriodDays,
    status: "locked",
  })

  if (error) throw error
  return data
}

export async function unclaimCoins(coinId: string) {
  const supabase = await createClient()
  const { data, error } = await supabase.from("coins").update({ status: "active" }).eq("id", coinId)

  if (error) throw error
  return data
}

export async function getDashboardBalance(userId: string) {
  const supabase = await createClient()

  // Sum all available coins (rewards and other claims)
  const { data, error } = await supabase.from("coins").select("amount").eq("user_id", userId).eq("status", "available")

  if (error) {
    console.error("[v0] Error fetching dashboard balance:", error)
    throw error
  }

  const balance = data?.reduce((sum, coin) => sum + Number(coin.amount), 0) || 0
  return balance
}
