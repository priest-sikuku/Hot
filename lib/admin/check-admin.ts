import { createClient } from "@/lib/supabase/server"

export async function checkIsAdmin() {
  const supabase = await createClient()

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser()

  if (authError || !user) {
    return { isAdmin: false, user: null, error: "Not authenticated" }
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("is_admin, role, disabled")
    .eq("id", user.id)
    .single()

  if (profileError || !profile) {
    return { isAdmin: false, user, error: "Profile not found" }
  }

  if (profile.disabled) {
    return { isAdmin: false, user, error: "Account disabled" }
  }

  return {
    isAdmin: profile.is_admin === true,
    user,
    profile,
    error: null,
  }
}

export async function requireAdmin() {
  const { isAdmin, user, profile, error } = await checkIsAdmin()

  if (!isAdmin) {
    throw new Error(error || "Unauthorized: Admin access required")
  }

  return { user, profile }
}
