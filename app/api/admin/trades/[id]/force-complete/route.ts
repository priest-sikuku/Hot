import { type NextRequest, NextResponse } from "next/server"
import { createClient } from "@/lib/supabase/server"
import { requireAdmin } from "@/lib/admin/check-admin"

export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    const { user } = await requireAdmin()
    const supabase = await createClient()
    const body = await request.json()

    const { reason } = body

    if (!reason) {
      return NextResponse.json({ error: "Reason required" }, { status: 400 })
    }

    const { data, error } = await supabase.rpc("admin_force_complete_trade", {
      p_admin_id: user.id,
      p_trade_id: params.id,
      p_reason: reason,
      p_ip_address: request.headers.get("x-forwarded-for") || request.headers.get("x-real-ip"),
      p_user_agent: request.headers.get("user-agent"),
    })

    if (error) throw error

    return NextResponse.json(data)
  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: error.message.includes("Unauthorized") ? 403 : 500 })
  }
}
