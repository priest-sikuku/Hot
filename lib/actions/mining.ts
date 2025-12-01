"use server"

import { createClient } from "@/lib/supabase/server"
import { revalidatePath } from "next/cache"

export async function claimMiningReward() {
  try {
    const supabase = await createClient()

    console.log("[v0] Starting mining claim process")

    // Get authenticated user
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser()

    if (authError || !user) {
      console.log("[v0] Auth error:", authError)
      return { success: false, error: "User not authenticated" }
    }

    console.log("[v0] User authenticated:", user.id)

    // Get user profile
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("id, last_mine, next_mine")
      .eq("id", user.id)
      .single()

    if (profileError || !profile) {
      console.log("[v0] Profile not found:", profileError)
      return { success: false, error: "Profile not found. Please refresh the page." }
    }

    console.log("[v0] Profile retrieved:", profile)

    // Check if user can mine (4 hours have passed)
    const now = new Date()
    const nextMine = profile.next_mine ? new Date(profile.next_mine) : null

    console.log("[v0] Mining check:", { now, nextMine, canMine: !nextMine || now >= nextMine })

    if (nextMine && now < nextMine) {
      const timeLeft = Math.ceil((nextMine.getTime() - now.getTime()) / 1000)
      console.log("[v0] Mining not available yet, time left:", timeLeft)
      return { success: false, error: "Mining not available yet", timeLeft }
    }

    // Get mining config
    const { data: miningConfig, error: configError } = await supabase.from("mining_config").select("*").single()

    console.log("[v0] Mining config:", { miningConfig, configError })

    const rewardAmount = miningConfig?.reward_amount || 0.25

    console.log("[v0] Inserting coin with amount:", rewardAmount)
    const { data: coin, error: coinError } = await supabase
      .from("coins")
      .insert({
        user_id: user.id,
        amount: rewardAmount,
        claim_type: "mining",
        status: "available",
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .select()
      .single()

    if (coinError) {
      console.error("[v0] Error inserting coin:", coinError)
      return { success: false, error: "Failed to claim reward. Please try again." }
    }

    console.log("[v0] Coin inserted successfully:", coin)

    const nextMiningTime = new Date(now.getTime() + 4 * 60 * 60 * 1000) // 4 hours from now

    const { error: updateError } = await supabase
      .from("profiles")
      .update({
        last_mine: now.toISOString(),
        next_mine: nextMiningTime.toISOString(),
      })
      .eq("id", user.id)

    if (updateError) {
      console.error("[v0] Error updating profile:", updateError)
      return { success: false, error: "Failed to update mining time" }
    }

    console.log("[v0] Profile updated with next mining time:", nextMiningTime)

    const { error: supplyError } = await supabase.rpc("deduct_from_global_supply", {
      mining_amount: rewardAmount,
    })

    if (supplyError) {
      console.error("[v0] Supply update error:", supplyError)
    } else {
      console.log("[v0] Global supply updated successfully")
    }

    revalidatePath("/dashboard")
    revalidatePath("/assets")

    console.log("[v0] Mining claim completed successfully")

    return {
      success: true,
      amount: rewardAmount,
      nextMining: nextMiningTime.toISOString(),
    }
  } catch (error) {
    console.error("[v0] Mining claim error:", error)
    return { success: false, error: "An unexpected error occurred. Please try again." }
  }
}

export async function getMiningStatus() {
  try {
    const supabase = await createClient()

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser()

    if (authError || !user) {
      return { canMine: false, timeLeft: 0, error: "Not authenticated" }
    }

    const { data: profile } = await supabase.from("profiles").select("next_mine").eq("id", user.id).single()

    if (!profile) {
      return { canMine: true, timeLeft: 0 }
    }

    const now = new Date()
    const nextMine = profile.next_mine ? new Date(profile.next_mine) : null

    if (!nextMine || now >= nextMine) {
      return { canMine: true, timeLeft: 0 }
    }

    const timeLeft = Math.ceil((nextMine.getTime() - now.getTime()) / 1000)
    return { canMine: false, timeLeft }
  } catch (error) {
    console.error("[v0] Error getting mining status:", error)
    return { canMine: false, timeLeft: 0, error: "Failed to get status" }
  }
}
