import { type NextRequest, NextResponse } from "next/server"
import { createClient } from "@/lib/supabase/server"
import { requireAdmin } from "@/lib/admin/check-admin"

export async function GET(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    const { user: adminUser } = await requireAdmin()
    const supabase = await createClient()

    const { data: dashboardCoins, error: dashboardError } = await supabase
      .from("coins")
      .select("amount")
      .eq("user_id", params.id)
      .eq("status", "available")

    if (dashboardError) {
      console.error("[v0] Error fetching dashboard balance:", dashboardError)
      return NextResponse.json({ error: dashboardError.message }, { status: 500 })
    }

    const dashboard_balance = dashboardCoins?.reduce((sum, coin) => sum + Number(coin.amount), 0) || 0

    const { data: p2pCoins, error: p2pError } = await supabase
      .from("trade_coins")
      .select("amount")
      .eq("user_id", params.id)
      .eq("status", "available")

    if (p2pError) {
      console.error("[v0] Error fetching P2P balance:", p2pError)
      return NextResponse.json({ error: p2pError.message }, { status: 500 })
    }

    const p2p_balance = p2pCoins?.reduce((sum, coin) => sum + Number(coin.amount), 0) || 0

    return NextResponse.json({
      dashboard_balance,
      p2p_balance,
    })
  } catch (error: any) {
    console.error("[v0] Error in GET balances:", error)
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
}

export async function PATCH(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    const { user: adminUser } = await requireAdmin()
    const supabase = await createClient()
    const body = await request.json()

    const { dashboard_balance, p2p_balance, reason } = body

    if (!reason || reason.trim() === "") {
      return NextResponse.json({ error: "Reason is required" }, { status: 400 })
    }

    const { error: dashboardError } = await supabase.rpc("admin_update_dashboard_balance", {
      p_admin_id: adminUser.id,
      p_user_id: params.id,
      p_new_amount: dashboard_balance,
      p_reason: reason,
    })

    if (dashboardError) {
      return NextResponse.json({ error: dashboardError.message }, { status: 500 })
    }

    const { error: p2pError } = await supabase.rpc("admin_update_p2p_balance", {
      p_admin_id: adminUser.id,
      p_user_id: params.id,
      p_new_amount: p2p_balance,
      p_reason: reason,
    })

    if (p2pError) {
      return NextResponse.json({ error: p2pError.message }, { status: 500 })
    }

    return NextResponse.json({ success: true })
  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
}
