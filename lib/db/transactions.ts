import { createClient } from "@/lib/supabase/server"

export async function createTransaction(
  userId: string,
  type: string,
  amount: number,
  description?: string,
  relatedId?: string,
) {
  const supabase = await createClient()
  const { data, error } = await supabase.from("transactions").insert({
    user_id: userId,
    type,
    amount,
    description,
    related_id: relatedId,
    status: "completed",
  })

  if (error) throw error
  return data
}

export async function getUserTransactions(userId: string) {
  const supabase = await createClient()
  const { data, error } = await supabase
    .from("transactions")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })

  if (error) throw error
  return data
}
