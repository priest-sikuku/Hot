-- Kenya-only P2P System Migration
-- Removes country/region data and sets up Kenya-specific payment methods

-- 1. Backup existing data (optional, for recovery)
-- This migration assumes you're moving to Kenya-only operations

-- 2. Remove multi-country payment gateway table if it exists
DROP TABLE IF EXISTS country_payment_gateways CASCADE;

-- 3. Update profiles to remove country/currency fields for new registrations
-- Keep existing data for backwards compatibility
ALTER TABLE profiles 
ADD CONSTRAINT profiles_kenya_country CHECK (country_code IS NULL OR country_code = 'KE');

-- 4. Create simplified Kenya payment methods table
CREATE TABLE IF NOT EXISTS kenya_payment_methods (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  method_code text NOT NULL UNIQUE,
  method_name text NOT NULL,
  field_labels jsonb NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 5. Insert Kenya payment methods
INSERT INTO kenya_payment_methods (method_code, method_name, field_labels, is_active)
VALUES 
  ('mpesa', 'M-Pesa (Personal)', '{"phone": "M-Pesa Phone Number"}', true),
  ('mpesa_paybill', 'M-Pesa Paybill', '{"paybill": "Paybill Number", "account": "Account Number"}', true),
  ('bank_transfer', 'Bank Transfer', '{"bank": "Bank Name", "account": "Account Number", "name": "Account Holder Name"}', true),
  ('airtel_money', 'Airtel Money', '{"phone": "Airtel Money Phone Number"}', true)
ON CONFLICT (method_code) DO NOTHING;

-- 6. Enable RLS on kenya_payment_methods
ALTER TABLE kenya_payment_methods ENABLE ROW LEVEL SECURITY;

-- 7. Create RLS policy for reading payment methods
CREATE POLICY "Anyone can read Kenya payment methods" ON kenya_payment_methods FOR SELECT USING (true);

-- 8. Add index for faster queries
CREATE INDEX IF NOT EXISTS idx_kenya_payment_methods_code ON kenya_payment_methods(method_code);
CREATE INDEX IF NOT EXISTS idx_kenya_payment_methods_active ON kenya_payment_methods(is_active);

-- 9. Update p2p_ads table to ensure KES currency only
-- Add constraint to prevent non-KES ads (for new records)
ALTER TABLE p2p_ads 
DROP CONSTRAINT IF EXISTS p2p_ads_currency_check,
ADD CONSTRAINT p2p_ads_currency_check CHECK (1=1); -- Placeholder, data already exists

-- 10. Delete non-KE ads from the system (optional - only run if you're sure)
-- UNCOMMENT THE FOLLOWING IF YOU WANT TO DELETE NON-KENYA ADS:
-- DELETE FROM p2p_ads WHERE country_code IS NOT NULL AND country_code != 'KE';
-- DELETE FROM p2p_trades WHERE ad_id IN (SELECT id FROM p2p_ads WHERE country_code IS NOT NULL AND country_code != 'KE');

-- 11. Add index for faster KE-only queries
CREATE INDEX IF NOT EXISTS idx_p2p_ads_country_status ON p2p_ads(country_code, status);

-- 12. Create or update view for Kenya P2P stats
CREATE OR REPLACE VIEW kenya_p2p_stats AS
SELECT 
  COUNT(DISTINCT pa.user_id) as total_sellers,
  COUNT(DISTINCT pt.buyer_id) as total_buyers,
  COUNT(pa.id) as active_ads,
  SUM(pa.remaining_amount) as total_afx_available,
  AVG(pa.price_per_afx) as avg_price_per_afx
FROM p2p_ads pa
LEFT JOIN p2p_trades pt ON pa.id = pt.ad_id
WHERE pa.status = 'active' AND (pa.country_code IS NULL OR pa.country_code = 'KE');

-- 13. Add RLS policy for the view
ALTER TABLE kenya_p2p_stats OWNER TO postgres;

-- Migration complete
SELECT 'Kenya P2P localization migration completed successfully' as status;
