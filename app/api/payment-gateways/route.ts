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
    .from("country_payment_gateways")
    .select(`
      id,
      gateway_code,
      gateway_name,
      gateway_type,
      field_labels,
      is_active
    `)
    .eq(
      "country_id",
      `(SELECT id FROM african_countries WHERE code = '${countryCode}')`
    )
    .eq("is_active", true);

  if (error) {
    console.error("[v0] Error fetching payment gateways:", error);
    return Response.json({ error: error.message }, { status: 500 });
  }

  return Response.json({ gateways: data });
}
