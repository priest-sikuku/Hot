import type React from "react"
import { redirect } from "next/navigation"
import { createClient } from "@/lib/supabase/server"

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) {
    redirect("/auth/sign-in")
  }

  return <>{children}</>
}
