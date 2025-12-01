import { NextRequest, NextResponse } from "next/server"
import { createServerClient } from "@supabase/ssr"

export async function GET(request: NextRequest) {
  try {
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() {
            return request.cookies.getAll()
          },
          setAll(cookiesToSet) {
            const response = NextResponse.next();
            cookiesToSet.forEach(({ name, value, options }) =>
              response.cookies.set(name, value, options)
            )
            return response;
          },
        },
      }
    );

    // Get authenticated user
    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const { data, error } = await supabase.rpc('get_user_regional_p2p_ads', {
      p_user_id: user.id,
    });

    if (error) throw error;

    return NextResponse.json({
      success: true,
      ads: data || [],
      count: (data || []).length,
    });
  } catch (error) {
    console.error('[v0] P2P ads fetch error:', error);
    return NextResponse.json(
      { error: "Failed to fetch ads" },
      { status: 500 }
    );
  }
}
