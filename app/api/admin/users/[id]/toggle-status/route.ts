import { type NextRequest, NextResponse } from "next/server"
import { createClient } from "@/lib/supabase/server"
import { requireAdmin } from "@/lib/admin/check-admin"

export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    const { user } = await requireAdmin()
    const supabase = await createClient()
    const body = await request.json()

    const { disabled, reason } = body

    const { data, error } = await supabase.rpc("admin_toggle_user_status", {
      p_admin_id: user.id,
      p_user_id: params.id,
      p_disabled: disabled,
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
