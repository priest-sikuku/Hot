export type CountryCode = "KE"

export interface Country {
  code: CountryCode
  name: string
  currency_code: string
  currency_name: string
  currency_symbol: string
  phone_prefix: string
}

export interface PaymentGateway {
  code: string
  name: string
  type: "mobile_money" | "bank" | "wallet"
  fields: Record<string, string>
}

export const AFRICAN_COUNTRIES: Record<CountryCode, Country> = {
  KE: {
    code: "KE",
    name: "Kenya",
    currency_code: "KES",
    currency_name: "Kenyan Shilling",
    currency_symbol: "KSh",
    phone_prefix: "+254",
  },
}

export const PAYMENT_GATEWAYS_BY_COUNTRY: Record<CountryCode, PaymentGateway[]> = {
  KE: [
    {
      code: "mpesa_personal",
      name: "M-Pesa",
      type: "mobile_money",
      fields: { phone: "M-Pesa Phone Number", name: "Full Name" },
    },
    {
      code: "mpesa_paybill",
      name: "M-Pesa Paybill",
      type: "mobile_money",
      fields: { paybill: "Paybill Number", account: "Account Number" },
    },
    {
      code: "airtel_money",
      name: "Airtel Money",
      type: "mobile_money",
      fields: { phone: "Airtel Money Phone Number", name: "Full Name" },
    },
    {
      code: "bank_transfer",
      name: "Bank Transfer",
      type: "bank",
      fields: { bank: "Bank Name", account: "Account Number", name: "Account Holder Name" },
    },
  ],
}

export const getCountryList = (): Country[] => {
  return Object.values(AFRICAN_COUNTRIES)
}

export const getCountryByCode = (code: CountryCode): Country | undefined => {
  return AFRICAN_COUNTRIES[code]
}

export const getPaymentGatewaysByCountry = (code: CountryCode): PaymentGateway[] => {
  return PAYMENT_GATEWAYS_BY_COUNTRY[code] || []
}
