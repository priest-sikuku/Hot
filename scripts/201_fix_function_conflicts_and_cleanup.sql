-- ============================================================================
-- FIX FUNCTION CONFLICTS AND REMOVE GEOLOCATION
-- This script drops existing functions before recreating them to avoid conflicts
-- and removes all geolocation-related database structures
-- ============================================================================

-- ============================================================================
-- PART 1: DROP ALL EXISTING FUNCTIONS TO AVOID CONFLICTS
-- ============================================================================

DROP FUNCTION IF EXISTS get_user_balance(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_available_balance(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_locked_balance(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_current_mining_reward() CASCADE;
DROP FUNCTION IF EXISTS compute_boosted_mining_rate(UUID) CASCADE;
DROP FUNCTION IF EXISTS deduct_from_global_supply(NUMERIC) CASCADE;
DROP FUNCTION IF EXISTS add_claim_commission(UUID, NUMERIC, UUID) CASCADE;
DROP FUNCTION IF EXISTS post_sell_ad_with_payment_details(UUID, NUMERIC, NUMERIC, NUMERIC, NUMERIC, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, VARCHAR, VARCHAR, TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_total_user_count() CASCADE;
DROP FUNCTION IF EXISTS get_user_p2p_stats(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_user_trade_stats(UUID) CASCADE;
DROP FUNCTION IF EXISTS link_referral(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS update_user_location_from_ip(UUID, VARCHAR, VARCHAR, TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_user_regional_p2p_ads(UUID, VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS get_daily_price_target() CASCADE;
DROP FUNCTION IF EXISTS update_daily_closing_price() CASCADE;
DROP FUNCTION IF EXISTS admin_get_dashboard_stats() CASCADE;
DROP FUNCTION IF EXISTS admin_toggle_user_status(UUID, UUID, BOOLEAN, TEXT) CASCADE;
DROP FUNCTION IF EXISTS admin_update_user(UUID, UUID, JSONB) CASCADE;

-- ============================================================================
-- PART 2: REMOVE ALL GEOLOCATION-RELATED STRUCTURES
-- ============================================================================

-- Drop geolocation tables
DROP TABLE IF EXISTS user_geolocation CASCADE;
DROP TABLE IF EXISTS ip_geolocation_reference CASCADE;

-- Remove geolocation columns from profiles
ALTER TABLE profiles DROP COLUMN IF EXISTS detected_country_code CASCADE;
ALTER TABLE profiles DROP COLUMN IF EXISTS ip_address CASCADE;

-- Remove geolocation columns from p2p_trades
ALTER TABLE p2p_trades DROP COLUMN IF EXISTS buyer_country_code CASCADE;
ALTER TABLE p2p_trades DROP COLUMN IF EXISTS seller_country_code CASCADE;

-- ============================================================================
-- PART 3: REMOVE OBSOLETE TABLES
-- ============================================================================

DROP TABLE IF EXISTS listings CASCADE;
DROP TABLE IF EXISTS trades CASCADE;
DROP TABLE IF EXISTS ratings CASCADE;
DROP TABLE IF EXISTS supply_tracking CASCADE;
DROP TABLE IF EXISTS user_stats CASCADE;
DROP TABLE IF EXISTS system_config CASCADE;
DROP TABLE IF EXISTS country_payment_gateways CASCADE;
DROP VIEW IF EXISTS user_balance_summary CASCADE;
DROP VIEW IF EXISTS total_coins_in_circulation CASCADE;

-- ============================================================================
-- PART 4: ENSURE CORE TABLES HAVE REQUIRED COLUMNS (NO GEOLOCATION)
-- ============================================================================

-- Ensure profiles has all required columns WITHOUT geolocation fields
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS last_mine TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS next_mine TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS total_referrals INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_commission NUMERIC DEFAULT 0;

-- Set default country to KE for all users (no geolocation detection)
UPDATE profiles 
SET country_code = 'KE', 
    currency_code = 'KES', 
    currency_symbol = 'KSh',
    country_name = 'Kenya'
WHERE country_code IS NULL;

-- Ensure p2p_trades has required columns
ALTER TABLE p2p_trades
ADD COLUMN IF NOT EXISTS payment_method TEXT,
ADD COLUMN IF NOT EXISTS seller_payment_details JSONB;

-- Ensure referrals table has commission tracking
ALTER TABLE referrals
ADD COLUMN IF NOT EXISTS total_trading_commission NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_claim_commission NUMERIC DEFAULT 0;

-- ============================================================================
-- PART 5: RECREATE ALL RPC FUNCTIONS (WITHOUT GEOLOCATION)
-- ============================================================================

-- Function: get_user_balance
CREATE OR REPLACE FUNCTION get_user_balance(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  v_balance NUMERIC;
BEGIN
  SELECT COALESCE(SUM(amount), 0)
  INTO v_balance
  FROM coins
  WHERE user_id = p_user_id
    AND status = 'available';
  
  RETURN v_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: get_available_balance
CREATE OR REPLACE FUNCTION get_available_balance(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  v_balance NUMERIC;
BEGIN
  SELECT COALESCE(SUM(amount), 0)
  INTO v_balance
  FROM coins
  WHERE user_id = p_user_id
    AND status = 'available';
  
  RETURN v_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: get_locked_balance
CREATE OR REPLACE FUNCTION get_locked_balance(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  v_balance NUMERIC;
BEGIN
  SELECT COALESCE(SUM(amount), 0)
  INTO v_balance
  FROM coins
  WHERE user_id = p_user_id
    AND status = 'locked';
  
  v_balance := v_balance + COALESCE((
    SELECT SUM(amount)
    FROM trade_coins
    WHERE user_id = p_user_id
      AND status = 'locked'
  ), 0);
  
  RETURN v_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: get_current_mining_reward
CREATE OR REPLACE FUNCTION get_current_mining_reward()
RETURNS TABLE (
  reward_amount NUMERIC,
  interval_hours INTEGER,
  halving_date TIMESTAMP WITH TIME ZONE,
  is_halved BOOLEAN
) AS $$
DECLARE
  v_config RECORD;
  v_is_halved BOOLEAN;
BEGIN
  SELECT * INTO v_config FROM mining_config ORDER BY created_at DESC LIMIT 1;
  
  IF v_config IS NULL THEN
    RETURN QUERY SELECT 0.15::NUMERIC, 3::INTEGER, NULL::TIMESTAMP WITH TIME ZONE, FALSE;
    RETURN;
  END IF;
  
  v_is_halved := v_config.halving_date IS NOT NULL AND NOW() >= v_config.halving_date;
  
  RETURN QUERY SELECT 
    CASE WHEN v_is_halved THEN v_config.post_halving_reward ELSE v_config.reward_amount END,
    v_config.interval_hours,
    v_config.halving_date,
    v_is_halved;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: compute_boosted_mining_rate
CREATE OR REPLACE FUNCTION compute_boosted_mining_rate(p_user_id UUID)
RETURNS TABLE (
  base_rate NUMERIC,
  referral_count INTEGER,
  boost_percentage NUMERIC,
  final_rate NUMERIC
) AS $$
DECLARE
  v_base_rate NUMERIC;
  v_referral_count INTEGER;
  v_boost_percentage NUMERIC;
  v_final_rate NUMERIC;
BEGIN
  SELECT reward_amount INTO v_base_rate
  FROM (SELECT * FROM get_current_mining_reward() LIMIT 1) AS config;
  
  IF v_base_rate IS NULL THEN
    v_base_rate := 0.15;
  END IF;
  
  SELECT COUNT(*)
  INTO v_referral_count
  FROM referrals r
  INNER JOIN profiles p ON p.id = r.referred_id
  WHERE r.referrer_id = p_user_id
    AND r.status = 'active'
    AND p.last_mine IS NOT NULL;
  
  v_boost_percentage := LEAST(v_referral_count * 5, 100);
  v_final_rate := v_base_rate * (1 + v_boost_percentage / 100.0);
  
  RETURN QUERY SELECT 
    v_base_rate,
    v_referral_count,
    v_boost_percentage,
    v_final_rate;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: deduct_from_global_supply
CREATE OR REPLACE FUNCTION deduct_from_global_supply(mining_amount NUMERIC)
RETURNS TABLE (
  success BOOLEAN,
  remaining NUMERIC,
  message TEXT
) AS $$
DECLARE
  v_remaining NUMERIC;
  v_actual_amount NUMERIC;
BEGIN
  SELECT remaining_supply INTO v_remaining
  FROM global_supply
  WHERE id = 1
  FOR UPDATE;
  
  IF v_remaining IS NULL THEN
    v_remaining := 21000000;
    INSERT INTO global_supply (id, total_supply, remaining_supply, mined_supply)
    VALUES (1, 21000000, 21000000, 0)
    ON CONFLICT (id) DO NOTHING;
  END IF;
  
  IF v_remaining <= 0 THEN
    RETURN QUERY SELECT FALSE, 0::NUMERIC, 'Global supply exhausted'::TEXT;
    RETURN;
  END IF;
  
  v_actual_amount := LEAST(mining_amount, v_remaining);
  
  UPDATE global_supply
  SET 
    remaining_supply = remaining_supply - v_actual_amount,
    mined_supply = mined_supply + v_actual_amount,
    updated_at = NOW()
  WHERE id = 1;
  
  RETURN QUERY SELECT TRUE, v_actual_amount, 'Supply deducted successfully'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: add_claim_commission
CREATE OR REPLACE FUNCTION add_claim_commission(
  p_referred_id UUID,
  p_claim_amount NUMERIC,
  p_coin_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_referrer_id UUID;
  v_commission_amount NUMERIC;
BEGIN
  SELECT referrer_id INTO v_referrer_id
  FROM referrals
  WHERE referred_id = p_referred_id
    AND status = 'active';
  
  IF v_referrer_id IS NULL THEN
    RETURN;
  END IF;
  
  v_commission_amount := p_claim_amount * 0.10;
  
  INSERT INTO trade_coins (user_id, amount, source, reference_id, status, created_at, updated_at)
  VALUES (
    v_referrer_id,
    v_commission_amount,
    'referral_commission',
    p_coin_id,
    'available',
    NOW(),
    NOW()
  );
  
  UPDATE referrals
  SET 
    total_claim_commission = COALESCE(total_claim_commission, 0) + v_commission_amount,
    updated_at = NOW()
  WHERE referrer_id = v_referrer_id
    AND referred_id = p_referred_id;
  
  UPDATE profiles
  SET 
    total_commission = COALESCE(total_commission, 0) + v_commission_amount,
    updated_at = NOW()
  WHERE id = v_referrer_id;
  
  INSERT INTO referral_commissions (
    referrer_id,
    referred_id,
    source_id,
    amount,
    commission_type,
    status,
    created_at,
    updated_at
  ) VALUES (
    v_referrer_id,
    p_referred_id,
    p_coin_id,
    v_commission_amount,
    'mining',
    'completed',
    NOW(),
    NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: post_sell_ad_with_payment_details
CREATE OR REPLACE FUNCTION post_sell_ad_with_payment_details(
  p_user_id UUID,
  p_afx_amount NUMERIC,
  p_price_per_afx NUMERIC,
  p_min_amount NUMERIC,
  p_max_amount NUMERIC,
  p_payment_method TEXT,
  p_full_name TEXT,
  p_bank_name TEXT,
  p_account_number TEXT,
  p_account_name TEXT,
  p_mpesa_number TEXT,
  p_paybill_number TEXT,
  p_airtel_money TEXT,
  p_country_code VARCHAR,
  p_currency_code VARCHAR,
  p_terms_of_trade TEXT
)
RETURNS UUID AS $$
DECLARE
  v_ad_id UUID;
  v_available_balance NUMERIC;
BEGIN
  SELECT get_available_balance(p_user_id) INTO v_available_balance;
  
  IF v_available_balance < p_afx_amount THEN
    RAISE EXCEPTION 'Insufficient balance';
  END IF;
  
  INSERT INTO p2p_ads (
    user_id,
    ad_type,
    afx_amount,
    remaining_amount,
    price_per_afx,
    min_amount,
    max_amount,
    payment_method,
    full_name,
    bank_name,
    account_number,
    account_name,
    mpesa_number,
    paybill_number,
    airtel_money,
    country_code,
    currency_code,
    terms_of_trade,
    status,
    created_at,
    updated_at
  ) VALUES (
    p_user_id,
    'sell',
    p_afx_amount,
    p_afx_amount,
    p_price_per_afx,
    p_min_amount,
    p_max_amount,
    p_payment_method,
    p_full_name,
    p_bank_name,
    p_account_number,
    p_account_name,
    p_mpesa_number,
    p_paybill_number,
    p_airtel_money,
    p_country_code,
    p_currency_code,
    p_terms_of_trade,
    'active',
    NOW(),
    NOW()
  ) RETURNING id INTO v_ad_id;
  
  RETURN v_ad_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: get_total_user_count
CREATE OR REPLACE FUNCTION get_total_user_count()
RETURNS INTEGER AS $$
DECLARE
  v_real_count INTEGER;
  v_base_count INTEGER;
  v_total INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_real_count FROM profiles;
  
  SELECT COALESCE(base_count, 50000) INTO v_base_count
  FROM user_count_config
  ORDER BY created_at DESC
  LIMIT 1;
  
  v_total := v_base_count + v_real_count;
  
  RETURN v_total;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: get_user_p2p_stats
CREATE OR REPLACE FUNCTION get_user_p2p_stats(p_user_id UUID)
RETURNS TABLE (
  total_trades INTEGER,
  completed_trades INTEGER,
  total_volume NUMERIC,
  avg_rating NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::INTEGER,
    COUNT(*) FILTER (WHERE status = 'completed')::INTEGER,
    COALESCE(SUM(afx_amount), 0),
    COALESCE(AVG(r.rating), 0)
  FROM p2p_trades t
  LEFT JOIN p2p_ratings r ON r.rated_user_id = p_user_id
  WHERE t.buyer_id = p_user_id OR t.seller_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: get_user_trade_stats
CREATE OR REPLACE FUNCTION get_user_trade_stats(p_user_id UUID)
RETURNS TABLE (
  total_trades INTEGER,
  completed_trades INTEGER,
  cancelled_trades INTEGER,
  disputed_trades INTEGER,
  total_volume NUMERIC,
  total_bought NUMERIC,
  total_sold NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*)::INTEGER,
    COUNT(*) FILTER (WHERE status = 'completed')::INTEGER,
    COUNT(*) FILTER (WHERE status = 'cancelled')::INTEGER,
    COUNT(*) FILTER (WHERE status = 'disputed')::INTEGER,
    COALESCE(SUM(afx_amount), 0),
    COALESCE(SUM(afx_amount) FILTER (WHERE buyer_id = p_user_id), 0),
    COALESCE(SUM(afx_amount) FILTER (WHERE seller_id = p_user_id), 0)
  FROM p2p_trades
  WHERE buyer_id = p_user_id OR seller_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: link_referral
CREATE OR REPLACE FUNCTION link_referral(
  p_user_id UUID,
  p_referral_code TEXT
)
RETURNS VOID AS $$
DECLARE
  v_referrer_id UUID;
BEGIN
  SELECT id INTO v_referrer_id
  FROM profiles
  WHERE referral_code = p_referral_code
    AND id != p_user_id;
  
  IF v_referrer_id IS NULL THEN
    RETURN;
  END IF;
  
  INSERT INTO referrals (
    referrer_id,
    referred_id,
    referral_code,
    status,
    created_at,
    updated_at
  ) VALUES (
    v_referrer_id,
    p_user_id,
    p_referral_code,
    'active',
    NOW(),
    NOW()
  ) ON CONFLICT DO NOTHING;
  
  UPDATE profiles
  SET 
    referred_by = v_referrer_id,
    updated_at = NOW()
  WHERE id = p_user_id;
  
  UPDATE profiles
  SET 
    total_referrals = COALESCE(total_referrals, 0) + 1,
    updated_at = NOW()
  WHERE id = v_referrer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Removed update_user_location_from_ip function (geolocation removed)

-- Function without geolocation filtering
CREATE OR REPLACE FUNCTION get_user_regional_p2p_ads(
  p_user_id UUID,
  p_country_code VARCHAR
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  ad_type TEXT,
  afx_amount NUMERIC,
  remaining_amount NUMERIC,
  price_per_afx NUMERIC,
  min_amount NUMERIC,
  max_amount NUMERIC,
  payment_method TEXT,
  country_code VARCHAR,
  currency_code VARCHAR,
  status TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  username TEXT,
  rating NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    a.id,
    a.user_id,
    a.ad_type,
    a.afx_amount,
    a.remaining_amount,
    a.price_per_afx,
    a.min_amount,
    a.max_amount,
    a.payment_method,
    a.country_code,
    a.currency_code,
    a.status,
    a.created_at,
    p.username,
    COALESCE(p.rating, 0)
  FROM p2p_ads a
  INNER JOIN profiles p ON p.id = a.user_id
  WHERE a.status = 'active'
    AND a.country_code = p_country_code
    AND a.user_id != p_user_id
    AND a.remaining_amount > 0
  ORDER BY a.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: get_daily_price_target
CREATE OR REPLACE FUNCTION get_daily_price_target()
RETURNS TABLE (
  target_price NUMERIC,
  opening_price NUMERIC,
  target_growth NUMERIC
) AS $$
DECLARE
  v_summary RECORD;
BEGIN
  SELECT * INTO v_summary
  FROM coin_summary
  WHERE reference_date = CURRENT_DATE;
  
  IF v_summary IS NULL THEN
    RETURN QUERY SELECT 1.0::NUMERIC, 1.0::NUMERIC, 0.03::NUMERIC;
    RETURN;
  END IF;
  
  RETURN QUERY SELECT 
    v_summary.opening_price * (1 + v_summary.target_growth_percent / 100.0),
    v_summary.opening_price,
    v_summary.target_growth_percent;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: update_daily_closing_price
CREATE OR REPLACE FUNCTION update_daily_closing_price()
RETURNS VOID AS $$
DECLARE
  v_latest_price NUMERIC;
BEGIN
  SELECT price INTO v_latest_price
  FROM coin_ticks
  WHERE reference_date = CURRENT_DATE
  ORDER BY tick_timestamp DESC
  LIMIT 1;
  
  IF v_latest_price IS NULL THEN
    RETURN;
  END IF;
  
  UPDATE coin_summary
  SET 
    closing_price = v_latest_price,
    updated_at = NOW()
  WHERE reference_date = CURRENT_DATE;
  
  UPDATE afx_current_price
  SET 
    price_usd = v_latest_price,
    last_updated = NOW()
  WHERE id = (SELECT id FROM afx_current_price ORDER BY last_updated DESC LIMIT 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: admin_get_dashboard_stats
CREATE OR REPLACE FUNCTION admin_get_dashboard_stats()
RETURNS TABLE (
  total_users INTEGER,
  active_ads INTEGER,
  active_trades INTEGER,
  disputed_trades INTEGER,
  total_volume NUMERIC,
  total_supply NUMERIC,
  remaining_supply NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (SELECT COUNT(*)::INTEGER FROM profiles),
    (SELECT COUNT(*)::INTEGER FROM p2p_ads WHERE status = 'active'),
    (SELECT COUNT(*)::INTEGER FROM p2p_trades WHERE status IN ('pending', 'paid')),
    (SELECT COUNT(*)::INTEGER FROM p2p_trades WHERE status = 'disputed'),
    (SELECT COALESCE(SUM(afx_amount), 0) FROM p2p_trades WHERE status = 'completed'),
    (SELECT COALESCE(total_supply, 21000000) FROM global_supply WHERE id = 1),
    (SELECT COALESCE(remaining_supply, 21000000) FROM global_supply WHERE id = 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: admin_toggle_user_status
CREATE OR REPLACE FUNCTION admin_toggle_user_status(
  p_admin_id UUID,
  p_user_id UUID,
  p_disable BOOLEAN,
  p_reason TEXT
)
RETURNS VOID AS $$
BEGIN
  UPDATE profiles
  SET 
    disabled = p_disable,
    disabled_at = CASE WHEN p_disable THEN NOW() ELSE NULL END,
    disabled_by = CASE WHEN p_disable THEN p_admin_id ELSE NULL END,
    admin_note = p_reason,
    updated_at = NOW()
  WHERE id = p_user_id;
  
  INSERT INTO admin_audit_logs (
    admin_id,
    action,
    target_table,
    target_id,
    details
  ) VALUES (
    p_admin_id,
    CASE WHEN p_disable THEN 'disable_user' ELSE 'enable_user' END,
    'profiles',
    p_user_id,
    jsonb_build_object('reason', p_reason)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: admin_update_user
CREATE OR REPLACE FUNCTION admin_update_user(
  p_admin_id UUID,
  p_user_id UUID,
  p_updates JSONB
)
RETURNS VOID AS $$
BEGIN
  UPDATE profiles
  SET 
    username = COALESCE((p_updates->>'username')::TEXT, username),
    email = COALESCE((p_updates->>'email')::TEXT, email),
    is_admin = COALESCE((p_updates->>'is_admin')::BOOLEAN, is_admin),
    disabled = COALESCE((p_updates->>'disabled')::BOOLEAN, disabled),
    updated_at = NOW()
  WHERE id = p_user_id;
  
  INSERT INTO admin_audit_logs (
    admin_id,
    action,
    target_table,
    target_id,
    details
  ) VALUES (
    p_admin_id,
    'update_user',
    'profiles',
    p_user_id,
    p_updates
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 6: SET DEFAULT VALUES
-- ============================================================================

-- Set Kenya as default for all users
UPDATE profiles 
SET 
  country_code = COALESCE(country_code, 'KE'),
  currency_code = COALESCE(currency_code, 'KES'),
  currency_symbol = COALESCE(currency_symbol, 'KSh'),
  country_name = COALESCE(country_name, 'Kenya')
WHERE country_code IS NULL OR currency_code IS NULL;

UPDATE p2p_ads
SET 
  country_code = COALESCE(country_code, 'KE'),
  currency_code = COALESCE(currency_code, 'KES')
WHERE country_code IS NULL;

UPDATE p2p_trades
SET 
  country_code = COALESCE(country_code, 'KE'),
  currency_code = COALESCE(currency_code, 'KES')
WHERE country_code IS NULL;
