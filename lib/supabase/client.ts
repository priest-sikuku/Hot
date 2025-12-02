import { createBrowserClient as createSupabaseBrowserClient } from "@supabase/ssr"

export function createBrowserClient() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  if (!supabaseUrl || !supabaseAnonKey) {
    // During build time, we may not have env vars available
    // Return a dummy client that won't be used
    console.warn("[v0] Supabase environment variables not found, using fallback")
    return createSupabaseBrowserClient("https://placeholder.supabase.co", "placeholder-key")
  }

  return createSupabaseBrowserClient(supabaseUrl, supabaseAnonKey)
}

export function createClient() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  if (!supabaseUrl || !supabaseAnonKey) {
    console.warn("[v0] Supabase environment variables not found, using fallback")
    return createSupabaseBrowserClient("https://placeholder.supabase.co", "placeholder-key")
  }

  return createSupabaseBrowserClient(supabaseUrl, supabaseAnonKey)
}
