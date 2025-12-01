import { createClient } from '@/lib/supabase/client';
import { CountryCode, AFRICAN_COUNTRIES } from './countries';

export interface ExchangeRate {
  countryCode: CountryCode;
  currencyCode: string;
  afxPrice: number;
  recordedAt: string;
}

// Cache for exchange rates (refresh every 5 minutes)
let exchangeRateCache: Record<CountryCode, number> = {};
let lastCacheUpdate = 0;
const CACHE_DURATION = 5 * 60 * 1000; // 5 minutes

export const getExchangeRate = async (countryCode: CountryCode): Promise<number> => {
  const now = Date.now();
  
  // Return cached value if still valid
  if (exchangeRateCache[countryCode] && (now - lastCacheUpdate) < CACHE_DURATION) {
    return exchangeRateCache[countryCode];
  }

  try {
    const supabase = createClient();
    const { data, error } = await supabase
      .from('afx_exchange_rates')
      .select('afx_price_in_currency')
      .eq('country_code', countryCode)
      .order('recorded_at', { ascending: false })
      .limit(1)
      .single();

    if (error || !data) {
      console.warn(`[v0] Could not fetch exchange rate for ${countryCode}, using fallback`);
      return getFallbackExchangeRate(countryCode);
    }

    exchangeRateCache[countryCode] = data.afx_price_in_currency;
    lastCacheUpdate = now;
    
    return data.afx_price_in_currency;
  } catch (err) {
    console.error('[v0] Error fetching exchange rate:', err);
    return getFallbackExchangeRate(countryCode);
  }
};

export const getAllExchangeRates = async (): Promise<Record<CountryCode, number>> => {
  const rates: Record<CountryCode, number> = {} as Record<CountryCode, number>;
  
  for (const countryCode of Object.keys(AFRICAN_COUNTRIES) as CountryCode[]) {
    rates[countryCode] = await getExchangeRate(countryCode);
  }
  
  return rates;
};

export const convertAfxToLocalCurrency = async (
  afxAmount: number,
  countryCode: CountryCode
): Promise<number> => {
  const rate = await getExchangeRate(countryCode);
  return afxAmount * rate;
};

export const convertLocalCurrencyToAfx = async (
  localAmount: number,
  countryCode: CountryCode
): Promise<number> => {
  const rate = await getExchangeRate(countryCode);
  return localAmount / rate;
};

export const getFallbackExchangeRate = (countryCode: CountryCode): number => {
  const fallbackRates: Record<CountryCode, number> = {
    KE: 13.50,
    UG: 53.20,
    TZ: 8050.00,
    GH: 114.50,
    NG: 2084.00,
    ZA: 51.80,
    ZM: 0.33,
    BJ: 74.30,
  };

  return fallbackRates[countryCode] || 13.50;
};

export const recordExchangeRate = async (
  countryCode: CountryCode,
  currencyCode: string,
  afxPrice: number
): Promise<boolean> => {
  try {
    const supabase = createClient();
    const { error } = await supabase.from('afx_exchange_rates').insert({
      country_code: countryCode,
      currency_code: currencyCode,
      afx_price_in_currency: afxPrice,
    });

    if (error) {
      console.error('[v0] Error recording exchange rate:', error);
      return false;
    }

    // Invalidate cache
    lastCacheUpdate = 0;
    return true;
  } catch (err) {
    console.error('[v0] Error in recordExchangeRate:', err);
    return false;
  }
};
