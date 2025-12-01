"use client"

/**
 * Currency Exchange Utilities - Uses real-time rates from /api/currency-rates
 */

export interface CurrencyRates {
  KES: number
  UGX: number
  TZS: number
  GHS: number
  NGN: number
  ZAR: number
  ZMW: number
  XOF: number
  BWP: number
  ZWL: number
  USD: number
}

/**
 * Get USD to local currency exchange rate from real-time API
 * This converts from USD (base) to the target currency
 */
export const getUSDToLocalRate = (currencyCode: string, rates: CurrencyRates | null): number => {
  if (!rates) return 1
  return rates[currencyCode as keyof CurrencyRates] || 1
}

/**
 * Convert AFX price (assumed in USD) to local currency
 * AFX price in local currency = AFX price in USD * USD to local rate
 */
export const convertAFXToLocalCurrency = (
  afxPriceInUSD: number,
  currencyCode: string,
  rates: CurrencyRates | null,
): number => {
  if (currencyCode === "USD" || !rates) {
    return afxPriceInUSD
  }

  const usdToLocalRate = getUSDToLocalRate(currencyCode, rates)
  return afxPriceInUSD * usdToLocalRate
}

/**
 * Updated to use real-time rates - converts AFX price to target currency
 */
export const getAFXPriceInCurrency = (
  afxPriceInUSD: number,
  currencyCode: string,
  rates: CurrencyRates | null,
): number => {
  return convertAFXToLocalCurrency(afxPriceInUSD, currencyCode, rates)
}

/**
 * Updated validation to work with real-time rates
 */
export const validatePriceRange = (
  pricePerAFX: number,
  afxPriceInUSD: number,
  currencyCode: string,
  rates: CurrencyRates | null,
  percentage = 4,
): boolean => {
  const priceInCurrency = getAFXPriceInCurrency(afxPriceInUSD, currencyCode, rates)
  const minAllowed = priceInCurrency * (1 - percentage / 100)
  const maxAllowed = priceInCurrency * (1 + percentage / 100)

  return pricePerAFX >= minAllowed && pricePerAFX <= maxAllowed
}

/**
 * Updated to work with real-time rates
 */
export const getPriceRange = (
  afxPriceInUSD: number,
  currencyCode: string,
  rates: CurrencyRates | null,
  percentage = 4,
): { min: number; max: number } => {
  const priceInCurrency = getAFXPriceInCurrency(afxPriceInUSD, currencyCode, rates)
  const min = priceInCurrency * (1 - percentage / 100)
  const max = priceInCurrency * (1 + percentage / 100)

  return { min, max }
}

/**
 * Get the exchange rate used at time of ad creation for record-keeping
 */
export const getExchangeRateForStorage = (currencyCode: string, rates: CurrencyRates | null): number => {
  if (!rates) return 1
  return currencyCode === "USD" ? 1 : rates[currencyCode as keyof CurrencyRates] || 1
}
