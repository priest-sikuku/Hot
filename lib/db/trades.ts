import { createClient } from "@/lib/supabase/server"

export async function createTrade(
  adId: string,
  buyerId: string,
  sellerId: string,
  afxAmount: number,
  totalPrice: number,
  paymentMethod: string,
) {
  const supabase = await createClient()
  const { data, error } = await supabase.from("p2p_trades").insert({
    ad_id: adId,
    buyer_id: buyerId,
    seller_id: sellerId,
    afx_amount: afxAmount,
    total_amount: totalPrice,
    payment_method: paymentMethod,
    status: "pending",
  })

  if (error) throw error
  return data
}

export async function getUserTrades(userId: string) {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from("p2p_trades")
    .select("*")
    .or(`buyer_id.eq.${userId},seller_id.eq.${userId}`)

  if (error) throw error
  return data
}

export async function updateTradeStatus(tradeId: string, status: string) {
  const supabase = await createClient()
  const updateData: any = { status }

  const { data, error } = await supabase.from("p2p_trades").update(updateData).eq("id", tradeId)

  if (error) throw error
  return data
}
