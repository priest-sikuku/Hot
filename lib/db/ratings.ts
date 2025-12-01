import { createClient } from "@/lib/supabase/server"

export async function createRating(
  tradeId: string,
  raterId: string,
  ratedUserId: string,
  rating: number,
  comment?: string,
) {
  const supabase = await createClient()
  const { data, error } = await supabase.from("p2p_ratings").insert({
    trade_id: tradeId,
    rater_id: raterId,
    rated_user_id: ratedUserId,
    rating,
    comment,
  })

  if (error) throw error
  return data
}

export async function getUserRatings(userId: string) {
  const supabase = await createClient()
  const { data, error } = await supabase.from("p2p_ratings").select("*").eq("rated_user_id", userId)

  if (error) throw error
  return data
}

export async function getAverageRating(userId: string) {
  const supabase = await createClient()
  const { data, error } = await supabase.from("p2p_ratings").select("rating").eq("rated_user_id", userId)

  if (error) throw error
  if (!data || data.length === 0) return 0
  return data.reduce((sum, r) => sum + r.rating, 0) / data.length
}
