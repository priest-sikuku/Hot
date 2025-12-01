import { createClient } from "@/lib/supabase/server"

export async function createListing(
  sellerId: string,
  coinAmount: number,
  pricePerCoin: number,
  paymentMethods: string[],
) {
  const supabase = await createClient()
  const { data, error } = await supabase.from("p2p_ads").insert({
    user_id: sellerId,
    ad_type: "sell",
    afx_amount: coinAmount,
    remaining_amount: coinAmount,
    price_per_afx: pricePerCoin,
    payment_method: paymentMethods[0], // Use first payment method
    status: "active",
  })

  if (error) throw error
  return data
}

export async function getActiveListings() {
  const supabase = await createClient()
  const { data, error } = await supabase.from("p2p_ads").select("*").eq("status", "active")

  if (error) throw error
  return data
}

export async function getUserListings(userId: string) {
  const supabase = await createClient()
  const { data, error } = await supabase.from("p2p_ads").select("*").eq("user_id", userId)

  if (error) throw error
  return data
}

export async function updateListingStatus(listingId: string, status: string) {
  const supabase = await createClient()
  const { data, error } = await supabase.from("p2p_ads").update({ status }).eq("id", listingId)

  if (error) throw error
  return data
}
