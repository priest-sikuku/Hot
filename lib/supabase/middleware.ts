import { createServerClient } from "@supabase/ssr"
import { NextResponse, type NextRequest } from "next/server"

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({
    request,
  })

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  // If Supabase credentials are not configured, allow all requests through
  if (!supabaseUrl || !supabaseAnonKey) {
    return supabaseResponse
  }

  const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll()
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
        supabaseResponse = NextResponse.next({
          request,
        })
        cookiesToSet.forEach(({ name, value, options }) => supabaseResponse.cookies.set(name, value, options))
      },
    },
  })

  const {
    data: { user },
  } = await supabase.auth.getUser()

  const guestAllowedRoutes = ["/", "/dashboard", "/p2p", "/assets", "/transactions", "/profile", "/auth", "/_next"]

  const isGuestAllowed = guestAllowedRoutes.some((route) => request.nextUrl.pathname.startsWith(route))

  if (!user && !isGuestAllowed) {
    const url = request.nextUrl.clone()
    url.pathname = "/auth/sign-in"
    url.searchParams.set("next", request.nextUrl.pathname)
    return NextResponse.redirect(url)
  }

  return supabaseResponse
}
