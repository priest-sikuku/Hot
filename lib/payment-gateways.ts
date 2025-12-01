import { AFRICAN_COUNTRIES, PAYMENT_GATEWAYS_BY_COUNTRY, CountryCode } from './countries';

export interface PaymentFieldConfig {
  fieldName: string;
  label: string;
  type: 'text' | 'tel' | 'email' | 'number';
  required: boolean;
  placeholder?: string;
  validation?: (value: string) => boolean;
}

export interface PaymentGatewayConfig {
  code: string;
  name: string;
  countryCode: CountryCode;
  type: 'mobile_money' | 'bank' | 'wallet' | 'ussd';
  fields: PaymentFieldConfig[];
  hints?: string;
}

// Payment field validators
const validators = {
  phoneNumber: (value: string) => /^[0-9+\-\s()]{10,20}$/.test(value),
  accountNumber: (value: string) => /^[a-zA-Z0-9]{8,20}$/.test(value),
  bankCode: (value: string) => /^[0-9]{3,10}$/.test(value),
  name: (value: string) => value.length >= 3 && value.length <= 100,
};

export const getPaymentGatewayConfig = (countryCode: CountryCode, gatewayCode: string): PaymentGatewayConfig | null => {
  const gateways = PAYMENT_GATEWAYS_BY_COUNTRY[countryCode];
  const gateway = gateways?.find(g => g.code === gatewayCode);
  
  if (!gateway) return null;

  // Map gateway configurations with field details
  const configMap: Record<string, PaymentGatewayConfig> = {
    // Kenya
    'KE_mpesa_personal': {
      code: 'mpesa_personal',
      name: 'M-Pesa Personal',
      countryCode: 'KE',
      type: 'mobile_money',
      fields: [
        {
          fieldName: 'phone',
          label: 'M-Pesa Phone Number',
          type: 'tel',
          required: true,
          placeholder: '0712345678',
          validation: validators.phoneNumber,
        },
        {
          fieldName: 'fullName',
          label: 'Full Name (as registered on M-Pesa)',
          type: 'text',
          required: true,
          placeholder: 'John Doe',
          validation: validators.name,
        },
      ],
      hints: 'Must match your M-Pesa registered name exactly',
    },
    'KE_mpesa_paybill': {
      code: 'mpesa_paybill',
      name: 'M-Pesa Paybill',
      countryCode: 'KE',
      type: 'mobile_money',
      fields: [
        {
          fieldName: 'paybillNumber',
          label: 'Paybill Number',
          type: 'text',
          required: true,
          placeholder: '123456',
          validation: validators.bankCode,
        },
        {
          fieldName: 'accountNumber',
          label: 'Account Number',
          type: 'text',
          required: true,
          placeholder: 'ACC123456',
          validation: validators.accountNumber,
        },
      ],
      hints: 'Enter your paybill business number and account reference',
    },
    'KE_airtel_money': {
      code: 'airtel_money',
      name: 'Airtel Money',
      countryCode: 'KE',
      type: 'mobile_money',
      fields: [
        {
          fieldName: 'phone',
          label: 'Airtel Money Phone Number',
          type: 'tel',
          required: true,
          placeholder: '0712345678',
          validation: validators.phoneNumber,
        },
        {
          fieldName: 'fullName',
          label: 'Full Name',
          type: 'text',
          required: true,
          placeholder: 'John Doe',
          validation: validators.name,
        },
      ],
      hints: 'Provide your registered Airtel account details',
    },
    // Uganda
    'UG_mtn_mobile_money': {
      code: 'mtn_mobile_money',
      name: 'MTN Mobile Money',
      countryCode: 'UG',
      type: 'mobile_money',
      fields: [
        {
          fieldName: 'phone',
          label: 'MTN Mobile Money Number',
          type: 'tel',
          required: true,
          placeholder: '0700123456',
          validation: validators.phoneNumber,
        },
        {
          fieldName: 'fullName',
          label: 'Full Name',
          type: 'text',
          required: true,
          placeholder: 'John Doe',
          validation: validators.name,
        },
      ],
    },
    // Nigeria
    'NG_ussd_transfer': {
      code: 'ussd_transfer',
      name: 'USSD Transfer',
      countryCode: 'NG',
      type: 'ussd',
      fields: [
        {
          fieldName: 'bankName',
          label: 'Bank Name',
          type: 'text',
          required: true,
          placeholder: 'First Bank of Nigeria',
          validation: validators.name,
        },
        {
          fieldName: 'ussdCode',
          label: 'USSD Code',
          type: 'text',
          required: true,
          placeholder: '*894#',
          validation: (val) => /^\*[0-9]+#$/.test(val),
        },
      ],
      hints: 'USSD codes vary by bank. Check your bank website for the correct code.',
    },
  };

  const key = `${countryCode}_${gatewayCode}`;
  return configMap[key] || null;
};

export const validatePaymentDetails = (
  countryCode: CountryCode,
  gatewayCode: string,
  details: Record<string, string>
): { valid: boolean; errors: string[] } => {
  const config = getPaymentGatewayConfig(countryCode, gatewayCode);
  const errors: string[] = [];

  if (!config) {
    return { valid: false, errors: ['Invalid payment gateway configuration'] };
  }

  for (const field of config.fields) {
    const value = details[field.fieldName];

    if (field.required && (!value || value.trim() === '')) {
      errors.push(`${field.label} is required`);
      continue;
    }

    if (value && field.validation && !field.validation(value)) {
      errors.push(`${field.label} format is invalid`);
    }
  }

  return { valid: errors.length === 0, errors };
};
