-- Create African Countries and Payment Methods Table
CREATE TABLE IF NOT EXISTS african_countries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(3) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL,
  currency_code VARCHAR(3) NOT NULL,
  currency_name VARCHAR(100) NOT NULL,
  currency_symbol VARCHAR(10) NOT NULL,
  exchange_rate_to_kes NUMERIC(15, 4) NOT NULL,
  phone_prefix VARCHAR(5),
  status TEXT DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create Payment Gateways per Country
CREATE TABLE IF NOT EXISTS country_payment_gateways (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  country_id UUID NOT NULL REFERENCES african_countries(id) ON DELETE CASCADE,
  gateway_code VARCHAR(50) NOT NULL,
  gateway_name VARCHAR(100) NOT NULL,
  gateway_type VARCHAR(50), -- 'mobile_money', 'bank', 'wallet', 'ussd'
  field_labels JSONB, -- Dynamic fields required for this gateway
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Modify profiles table to include country selection
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS country_code VARCHAR(3);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS country_name VARCHAR(100);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS currency_symbol VARCHAR(10);

-- Update P2P ads to support multi-currency
ALTER TABLE p2p_ads ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3) DEFAULT 'KES';
ALTER TABLE p2p_ads ADD COLUMN IF NOT EXISTS country_code VARCHAR(3) DEFAULT 'KE';
ALTER TABLE p2p_ads ADD COLUMN IF NOT EXISTS payment_gateway_code VARCHAR(50);
ALTER TABLE p2p_ads ADD COLUMN IF NOT EXISTS price_currency_fiat NUMERIC(15, 2);

-- Update P2P trades to support multi-currency
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3) DEFAULT 'KES';
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS country_code VARCHAR(3) DEFAULT 'KE';
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS fiat_amount_required NUMERIC(15, 2);
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS exchange_rate_used NUMERIC(15, 4);

-- Create Exchange Rates History Table
CREATE TABLE IF NOT EXISTS afx_exchange_rates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  country_code VARCHAR(3) NOT NULL,
  currency_code VARCHAR(3) NOT NULL,
  afx_price_in_currency NUMERIC(15, 4) NOT NULL,
  recorded_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_african_countries_code ON african_countries(code);
CREATE INDEX IF NOT EXISTS idx_country_payment_gateways_country ON country_payment_gateways(country_id);
CREATE INDEX IF NOT EXISTS idx_p2p_ads_country ON p2p_ads(country_code);
CREATE INDEX IF NOT EXISTS idx_profiles_country ON profiles(country_code);
CREATE INDEX IF NOT EXISTS idx_exchange_rates_country ON afx_exchange_rates(country_code, currency_code);

-- Enable RLS for new tables
ALTER TABLE african_countries ENABLE ROW LEVEL SECURITY;
ALTER TABLE country_payment_gateways ENABLE ROW LEVEL SECURITY;
ALTER TABLE afx_exchange_rates ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Anyone can read countries" ON african_countries FOR SELECT USING (true);
CREATE POLICY "Anyone can read payment gateways" ON country_payment_gateways FOR SELECT USING (true);
CREATE POLICY "Anyone can read exchange rates" ON afx_exchange_rates FOR SELECT USING (true);

-- Insert African Countries Data
INSERT INTO african_countries (code, name, currency_code, currency_name, currency_symbol, exchange_rate_to_kes, phone_prefix, status)
VALUES 
  ('KE', 'Kenya', 'KES', 'Kenyan Shilling', 'KSh', 1.0000, '+254', 'active'),
  ('UG', 'Uganda', 'UGX', 'Ugandan Shilling', 'USh', 0.0188, '+256', 'active'),
  ('TZ', 'Tanzania', 'TZS', 'Tanzanian Shilling', 'TSh', 0.0016, '+255', 'active'),
  ('GH', 'Ghana', 'GHS', 'Ghanaian Cedi', 'GH₵', 8.50, '+233', 'active'),
  ('NG', 'Nigeria', 'NGN', 'Nigerian Naira', '₦', 0.0065, '+234', 'active'),
  ('ZA', 'South Africa', 'ZAR', 'South African Rand', 'R', 3.85, '+27', 'active'),
  ('ZM', 'Zambia', 'ZMW', 'Zambian Kwacha', 'ZK', 0.032, '+260', 'active'),
  ('BJ', 'Benin', 'XOF', 'West African CFA Franc', 'CFA', 0.122, '+229', 'active');

-- Insert Payment Gateways for Each Country
-- Kenya Gateways
INSERT INTO country_payment_gateways (country_id, gateway_code, gateway_name, gateway_type, field_labels, is_active)
SELECT id, 'mpesa_personal', 'M-Pesa Personal', 'mobile_money', 
  '{"phone":"Phone Number","name":"Full Name (as in M-Pesa)"}', true
FROM african_countries WHERE code = 'KE'
UNION ALL
SELECT id, 'mpesa_paybill', 'M-Pesa Paybill', 'mobile_money',
  '{"paybill":"Paybill Number","account":"Account Number"}', true
FROM african_countries WHERE code = 'KE'
UNION ALL
SELECT id, 'airtel_money', 'Airtel Money', 'mobile_money',
  '{"phone":"Phone Number","name":"Full Name"}', true
FROM african_countries WHERE code = 'KE'
UNION ALL
SELECT id, 'bank_transfer', 'Bank Transfer', 'bank',
  '{"bank":"Bank Name","account":"Account Number","name":"Account Name"}', true
FROM african_countries WHERE code = 'KE'
UNION ALL
-- Uganda Gateways
SELECT id, 'mtn_mobile_money', 'MTN Mobile Money', 'mobile_money',
  '{"phone":"Phone Number","name":"Full Name"}', true
FROM african_countries WHERE code = 'UG'
UNION ALL
SELECT id, 'airtel_money_ug', 'Airtel Money Uganda', 'mobile_money',
  '{"phone":"Phone Number","name":"Full Name"}', true
FROM african_countries WHERE code = 'UG'
UNION ALL
SELECT id, 'bank_transfer_ug', 'Bank Transfer', 'bank',
  '{"bank":"Bank Name","account":"Account Number","name":"Account Name"}', true
FROM african_countries WHERE code = 'UG'
UNION ALL
-- Tanzania Gateways
SELECT id, 'vodacom_mpesa', 'Vodacom M-Pesa', 'mobile_money',
  '{"phone":"Phone Number","name":"Full Name"}', true
FROM african_countries WHERE code = 'TZ'
UNION ALL
SELECT id, 'tigo_pesa', 'Tigo Pesa', 'mobile_money',
  '{"phone":"Phone Number","name":"Full Name"}', true
FROM african_countries WHERE code = 'TZ'
UNION ALL
-- Ghana Gateways
SELECT id, 'mtn_ghana', 'MTN Mobile Money', 'mobile_money',
  '{"phone":"Phone Number","name":"Full Name"}', true
FROM african_countries WHERE code = 'GH'
UNION ALL
SELECT id, 'vodafone_cash', 'Vodafone Cash', 'mobile_money',
  '{"phone":"Phone Number","name":"Full Name"}', true
FROM african_countries WHERE code = 'GH'
UNION ALL
-- Nigeria Gateways
SELECT id, 'ussd_transfer', 'USSD Transfer', 'ussd',
  '{"provider":"Bank/Provider","code":"USSD Code"}', true
FROM african_countries WHERE code = 'NG'
UNION ALL
SELECT id, 'transfer_bank', 'Bank Transfer', 'bank',
  '{"bank":"Bank Name","account":"Account Number","name":"Account Name"}', true
FROM african_countries WHERE code = 'NG'
UNION ALL
-- South Africa Gateways
SELECT id, 'bank_transfer_za', 'Bank Transfer', 'bank',
  '{"bank":"Bank Name","account":"Account Number","name":"Account Name"}', true
FROM african_countries WHERE code = 'ZA'
UNION ALL
SELECT id, 'eft_transfer', 'EFT Transfer', 'bank',
  '{"bank":"Bank Name","account":"Account Number","name":"Account Name"}', true
FROM african_countries WHERE code = 'ZA'
UNION ALL
-- Zambia Gateways
SELECT id, 'mtn_zambia', 'MTN Mobile Money', 'mobile_money',
  '{"phone":"Phone Number","name":"Full Name"}', true
FROM african_countries WHERE code = 'ZM'
UNION ALL
-- Benin Gateways
SELECT id, 'wave_money', 'Wave Money', 'mobile_money',
  '{"phone":"Phone Number","name":"Full Name"}', true
FROM african_countries WHERE code = 'BJ'
UNION ALL
SELECT id, 'mtn_benin', 'MTN Money', 'mobile_money',
  '{"phone":"Phone Number","name":"Full Name"}', true
FROM african_countries WHERE code = 'BJ';
