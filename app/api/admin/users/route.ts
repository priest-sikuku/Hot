import { type NextRequest, NextResponse } from "next/server"
import { createClient } from "@/lib/supabase/server"
import { requireAdmin } from "@/lib/admin/check-admin"

export async function GET(request: NextRequest) {
  try {
    const { user } = await requireAdmin()
    const supabase = await createClient()

    const searchParams = request.nextUrl.searchParams
    const page = Number.parseInt(searchParams.get("page") || "1")
    const limit = Number.parseInt(searchParams.get("limit") || "20")
    const search = searchParams.get("search") || ""
    const role = searchParams.get("role") || ""
    const disabled = searchParams.get("disabled")

    const offset = (page - 1) * limit

    let query = supabase.from("profiles").select("*", { count: "exact" }).order("created_at", { ascending: false })

    if (search) {
      query = query.or(`username.ilike.%${search}%,email.ilike.%${search}%`)
    }

    if (role) {
      query = query.eq("role", role)
    }

    if (disabled !== null) {
      query = query.eq("disabled", disabled === "true")
    }

    const { data, error, count } = await query.range(offset, offset + limit - 1)

    if (error) throw error

    return NextResponse.json({
      users: data,
      total: count,
      page,
      limit,
      totalPages: Math.ceil((count || 0) / limit),
    })
  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: error.message.includes("Unauthorized") ? 403 : 500 })
  }
}

export async function PATCH(request: NextRequest) {
  try {
    const { user } = await requireAdmin()
    const supabase = await createClient()
    const body = await request.json()

    const { userId, updates } = body

    if (!userId) {
      return NextResponse.json({ error: "User ID required" }, { status: 400 })
    }

    const { data, error } = await supabase.rpc("admin_update_user", {
      p_admin_id: user.id,
      p_user_id: userId,
      p_is_admin: updates.is_admin,
      p_role: updates.role,
      p_admin_note: updates.admin_note,
      p_ip_address: request.headers.get("x-forwarded-for") || request.headers.get("x-real-ip"),
      p_user_agent: request.headers.get("user-agent"),
    })

    if (error) throw error

    return NextResponse.json(data)
  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: error.message.includes("Unauthorized") ? 403 : 500 })
  }
}
