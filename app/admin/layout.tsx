import type React from "react"
import { redirect } from "next/navigation"
import { createClient } from "@/lib/supabase/server"
import { AdminSidebar } from "@/components/admin/admin-sidebar"

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) {
    redirect("/auth/sign-in")
  }

  const { data: profile } = await supabase.from("profiles").select("is_admin, disabled").eq("id", user.id).single()

  if (!profile?.is_admin || profile.disabled) {
    redirect("/dashboard")
  }

  return (
    <div className="flex min-h-screen bg-gradient-to-br from-gray-900 via-black to-gray-900">
      <AdminSidebar />
      <main className="flex-1 p-8 overflow-auto">{children}</main>
    </div>
  )
}
