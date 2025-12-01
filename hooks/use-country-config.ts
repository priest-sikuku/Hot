import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { AFRICAN_COUNTRIES, CountryCode } from "@/lib/countries";

interface CountryConfig {
  countryCode: CountryCode;
  countryName: string;
  currencyCode: string;
  currencySymbol: string;
  exchangeRate: number;
}

export const useCountryConfig = () => {
  const supabase = createClient();
  const [config, setConfig] = useState<CountryConfig | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchUserCountry = async () => {
      try {
        const {
          data: { user },
        } = await supabase.auth.getUser();

        if (!user) {
          setLoading(false);
          return;
        }

        const { data: profile } = await supabase
          .from("profiles")
          .select("country_code, currency_code, currency_symbol")
          .eq("id", user.id)
          .single();

        if (profile && profile.country_code) {
          const countryCode = profile.country_code as CountryCode;
          const country = AFRICAN_COUNTRIES[countryCode];

          // Fetch current exchange rate
          const response = await fetch(
            `/api/exchange-rates?country=${countryCode}`
          );
          const rateData = await response.json();

          setConfig({
            countryCode,
            countryName: country.name,
            currencyCode: profile.currency_code || country.currency_code,
            currencySymbol: profile.currency_symbol || country.currency_symbol,
            exchangeRate: rateData.afx_price_in_currency || 13.5,
          });
        }
      } catch (error) {
        console.error("[v0] Error fetching country config:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchUserCountry();
  }, []);

  return { config, loading };
};
