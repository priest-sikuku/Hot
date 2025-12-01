import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function GET(request: Request) {
  const cookieStore = await cookies();
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
      },
    }
  );

  const { searchParams } = new URL(request.url);
  const countryCode = searchParams.get("country");

  if (!countryCode) {
    return Response.json({ error: "Country code required" }, { status: 400 });
  }

  const { data, error } = await supabase
    .from("afx_exchange_rates")
    .select("afx_price_in_currency, recorded_at")
    .eq("country_code", countryCode)
    .order("recorded_at", { ascending: false })
    .limit(1)
    .single();

  if (error) {
    console.error("[v0] Error fetching exchange rate:", error);
    // Return fallback rates if no data found
    const fallbackRates: Record<string, number> = {
      KE: 13.5,
      UG: 53.2,
      TZ: 8050.0,
      GH: 114.5,
      NG: 2084.0,
      ZA: 51.8,
      ZM: 0.33,
      BJ: 74.3,
    };

    return Response.json({
      afx_price_in_currency: fallbackRates[countryCode] || 13.5,
      recorded_at: new Date().toISOString(),
      isFallback: true,
    });
  }

  return Response.json(data);
}
