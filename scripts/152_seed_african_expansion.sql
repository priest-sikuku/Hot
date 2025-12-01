-- This script seeds the database with African countries, payment gateways, and initial exchange rates
-- Run this after script 151_african_expansion_schema.sql

-- Delete existing data if needed (for reset)
-- DELETE FROM afx_exchange_rates;
-- DELETE FROM country_payment_gateways;
-- DELETE FROM african_countries;

-- Verify countries are inserted (they should be from script 151)
SELECT COUNT(*) as country_count FROM african_countries;

-- Verify payment gateways are inserted
SELECT COUNT(*) as gateway_count FROM country_payment_gateways;

-- Seed initial AFX exchange rates (current as of deployment)
-- These will be updated by automated processes
INSERT INTO afx_exchange_rates (country_code, currency_code, afx_price_in_currency, recorded_at)
SELECT 
  ac.code,
  ac.currency_code,
  CASE 
    WHEN ac.code = 'KE' THEN 13.50
    WHEN ac.code = 'UG' THEN 53.20
    WHEN ac.code = 'TZ' THEN 8050.00
    WHEN ac.code = 'GH' THEN 114.50
    WHEN ac.code = 'NG' THEN 2084.00
    WHEN ac.code = 'ZA' THEN 51.80
    WHEN ac.code = 'ZM' THEN 0.33
    WHEN ac.code = 'BJ' THEN 74.30
  END as initial_price,
  now()
FROM african_countries ac
WHERE NOT EXISTS (
  SELECT 1 FROM afx_exchange_rates WHERE country_code = ac.code
);

-- Create view for getting current exchange rates by country
CREATE OR REPLACE VIEW v_current_exchange_rates AS
SELECT DISTINCT ON (country_code)
  country_code,
  currency_code,
  afx_price_in_currency,
  recorded_at
FROM afx_exchange_rates
ORDER BY country_code, recorded_at DESC;

-- Log the seeding completion
SELECT 'African expansion seeding completed successfully' as status,
  (SELECT COUNT(*) FROM african_countries) as total_countries,
  (SELECT COUNT(*) FROM country_payment_gateways) as total_gateways,
  (SELECT COUNT(*) FROM afx_exchange_rates) as exchange_rate_records;
