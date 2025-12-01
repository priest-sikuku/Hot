-- =====================================================
-- COMPREHENSIVE REBRANDING FROM GX TO AFX
-- AND REFERRAL SYSTEM FIX
-- =====================================================

-- PART 1: RENAME TABLES (GX → AFX)
-- =====================================================

-- Rename price tables
ALTER TABLE IF EXISTS gx_current_price RENAME TO afx_current_price;
ALTER TABLE IF EXISTS gx_price_history RENAME TO afx_price_history;
ALTER TABLE IF EXISTS gx_price_references RENAME TO afx_price_references;

-- Rename view
DROP VIEW IF EXISTS v_current_gx_price;
CREATE OR REPLACE VIEW v_current_afx_price AS
SELECT 
  current_price,
  previous_price,
  change_percent,
  updated_at,
  (EXTRACT(EPOCH FROM (NOW() - updated_at)) > 3600) AS needs_update
FROM afx_current_price
ORDER BY updated_at DESC
LIMIT 1;

-- PART 2: RENAME COLUMNS IN P2P_ADS (gx_amount → afx_amount, price_per_gx → price_per_afx)
-- =====================================================

ALTER TABLE p2p_ads RENAME COLUMN gx_amount TO afx_amount;
ALTER TABLE p2p_ads RENAME COLUMN price_per_gx TO price_per_afx;

-- PART 3: RENAME COLUMNS IN P2P_TRADES (gx_amount → afx_amount)
-- =====================================================

ALTER TABLE p2p_trades RENAME COLUMN gx_amount TO afx_amount;

-- PART 4: UPDATE BALANCE FUNCTIONS TO USE COINS TABLE
-- =====================================================

-- Function to get user's total balance from coins table
CREATE OR REPLACE FUNCTION get_user_balance(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  v_balance NUMERIC;
BEGIN
  SELECT COALESCE(SUM(amount), 0)
  INTO v_balance
  FROM coins
  WHERE user_id = p_user_id
    AND status IN ('available', 'locked');
  
  RETURN v_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's available balance (excluding locked coins in P2P)
CREATE OR REPLACE FUNCTION get_available_balance(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  v_available NUMERIC;
BEGIN
  SELECT COALESCE(SUM(amount), 0)
  INTO v_available
  FROM coins
  WHERE user_id = p_user_id
    AND status = 'available';
  
  RETURN v_available;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- PART 5: FIX REFERRAL SYSTEM - PROPER UPLINE/DOWNLINE TRACKING
-- =====================================================

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

-- Create improved function to handle new user signup with referral tracking
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_referrer_id UUID;
  v_referral_code TEXT;
BEGIN
  -- Generate 6-character alphanumeric referral code
  v_referral_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || NEW.id::TEXT) FROM 1 FOR 6));
  
  -- Ensure uniqueness
  WHILE EXISTS (SELECT 1 FROM profiles WHERE referral_code = v_referral_code) LOOP
    v_referral_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || NEW.id::TEXT || NOW()::TEXT) FROM 1 FOR 6));
  END LOOP;
  
  -- Insert profile with referral code
  INSERT INTO profiles (id, email, referral_code, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    v_referral_code,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET referral_code = v_referral_code
  WHERE profiles.referral_code IS NULL;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Function to create referral relationship (called from sign-up)
CREATE OR REPLACE FUNCTION create_referral_relationship(
  p_referrer_code TEXT,
  p_referred_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_referrer_id UUID;
BEGIN
  -- Find referrer by code
  SELECT id INTO v_referrer_id
  FROM profiles
  WHERE referral_code = p_referrer_code;
  
  IF v_referrer_id IS NULL THEN
    RETURN FALSE;
  END IF;
  
  -- Update referred user's profile
  UPDATE profiles
  SET referred_by = v_referrer_id,
      updated_at = NOW()
  WHERE id = p_referred_id;
  
  -- Create referral record
  INSERT INTO referrals (
    referrer_id,
    referred_id,
    referral_code,
    status,
    total_trading_commission,
    total_claim_commission,
    created_at,
    updated_at
  )
  VALUES (
    v_referrer_id,
    p_referred_id,
    p_referrer_code,
    'active',
    0,
    0,
    NOW(),
    NOW()
  )
  ON CONFLICT DO NOTHING;
  
  -- Update referrer's total referrals count
  UPDATE profiles
  SET total_referrals = total_referrals + 1,
      updated_at = NOW()
  WHERE id = v_referrer_id;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- PART 6: REFERRAL COMMISSION TRACKING FUNCTIONS
-- =====================================================

-- Function to add trading commission (2% of trade amount)
CREATE OR REPLACE FUNCTION add_trading_commission(
  p_referred_id UUID,
  p_trade_amount NUMERIC,
  p_trade_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_referrer_id UUID;
  v_commission NUMERIC;
BEGIN
  -- Get referrer
  SELECT referred_by INTO v_referrer_id
  FROM profiles
  WHERE id = p_referred_id;
  
  IF v_referrer_id IS NULL THEN
    RETURN;
  END IF;
  
  -- Calculate 2% commission
  v_commission := p_trade_amount * 0.02;
  
  -- Add commission to referrer's coins
  INSERT INTO coins (user_id, amount, claim_type, status, created_at, updated_at)
  VALUES (v_referrer_id, v_commission, 'referral_trading', 'available', NOW(), NOW());
  
  -- Record commission
  INSERT INTO referral_commissions (
    referrer_id,
    referred_id,
    commission_type,
    amount,
    source_id,
    status,
    created_at,
    updated_at
  )
  VALUES (
    v_referrer_id,
    p_referred_id,
    'trading',
    v_commission,
    p_trade_id,
    'completed',
    NOW(),
    NOW()
  );
  
  -- Update referral totals
  UPDATE referrals
  SET total_trading_commission = total_trading_commission + v_commission,
      updated_at = NOW()
  WHERE referrer_id = v_referrer_id AND referred_id = p_referred_id;
  
  -- Update profile total commission
  UPDATE profiles
  SET total_commission = COALESCE(total_commission, 0) + v_commission,
      updated_at = NOW()
  WHERE id = v_referrer_id;
  
  -- Create transaction record
  INSERT INTO transactions (user_id, type, amount, description, status, related_id, created_at)
  VALUES (
    v_referrer_id,
    'referral_commission',
    v_commission,
    'Trading commission from referral',
    'completed',
    p_trade_id,
    NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to add mining/claim commission (1% of claimed amount)
CREATE OR REPLACE FUNCTION add_claim_commission(
  p_referred_id UUID,
  p_claim_amount NUMERIC,
  p_coin_id UUID
)
RETURNS VOID AS $$
DECLARE
  v_referrer_id UUID;
  v_commission NUMERIC;
BEGIN
  -- Get referrer
  SELECT referred_by INTO v_referrer_id
  FROM profiles
  WHERE id = p_referred_id;
  
  IF v_referrer_id IS NULL THEN
    RETURN;
  END IF;
  
  -- Calculate 1% commission
  v_commission := p_claim_amount * 0.01;
  
  -- Add commission to referrer's coins
  INSERT INTO coins (user_id, amount, claim_type, status, created_at, updated_at)
  VALUES (v_referrer_id, v_commission, 'referral_mining', 'available', NOW(), NOW());
  
  -- Record commission
  INSERT INTO referral_commissions (
    referrer_id,
    referred_id,
    commission_type,
    amount,
    source_id,
    status,
    created_at,
    updated_at
  )
  VALUES (
    v_referrer_id,
    p_referred_id,
    'claim',
    v_commission,
    p_coin_id,
    'completed',
    NOW(),
    NOW()
  );
  
  -- Update referral totals
  UPDATE referrals
  SET total_claim_commission = total_claim_commission + v_commission,
      updated_at = NOW()
  WHERE referrer_id = v_referrer_id AND referred_id = p_referred_id;
  
  -- Update profile total commission
  UPDATE profiles
  SET total_commission = COALESCE(total_commission, 0) + v_commission,
      updated_at = NOW()
  WHERE id = v_referrer_id;
  
  -- Create transaction record
  INSERT INTO transactions (user_id, type, amount, description, status, related_id, created_at)
  VALUES (
    v_referrer_id,
    'referral_commission',
    v_commission,
    'Mining commission from referral',
    'completed',
    p_coin_id,
    NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- PART 7: UPDATE P2P FUNCTIONS TO USE NEW COLUMN NAMES AND ADD COMMISSION TRACKING
-- =====================================================

-- Update post_sell_ad_with_escrow function
CREATE OR REPLACE FUNCTION post_sell_ad_with_escrow(
  p_user_id UUID,
  p_afx_amount NUMERIC,
  p_price_per_afx NUMERIC,
  p_min_amount NUMERIC,
  p_max_amount NUMERIC,
  p_account_number TEXT DEFAULT NULL,
  p_mpesa_number TEXT DEFAULT NULL,
  p_paybill_number TEXT DEFAULT NULL,
  p_airtel_money TEXT DEFAULT NULL,
  p_terms_of_trade TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_ad_id UUID;
  v_available_balance NUMERIC;
BEGIN
  -- Check available balance
  v_available_balance := get_available_balance(p_user_id);
  
  IF v_available_balance < p_afx_amount THEN
    RAISE EXCEPTION 'Insufficient available balance';
  END IF;
  
  -- Lock coins for this ad
  UPDATE coins
  SET status = 'locked',
      updated_at = NOW()
  WHERE user_id = p_user_id
    AND status = 'available'
    AND id IN (
      SELECT id FROM coins
      WHERE user_id = p_user_id AND status = 'available'
      ORDER BY created_at
      LIMIT (
        SELECT COUNT(*) FROM coins
        WHERE user_id = p_user_id AND status = 'available'
        AND amount <= p_afx_amount
      )
    );
  
  -- Create ad
  INSERT INTO p2p_ads (
    user_id,
    ad_type,
    afx_amount,
    remaining_amount,
    price_per_afx,
    min_amount,
    max_amount,
    account_number,
    mpesa_number,
    paybill_number,
    airtel_money,
    terms_of_trade,
    status,
    created_at,
    updated_at
  )
  VALUES (
    p_user_id,
    'sell',
    p_afx_amount,
    p_afx_amount,
    p_price_per_afx,
    p_min_amount,
    p_max_amount,
    p_account_number,
    p_mpesa_number,
    p_paybill_number,
    p_airtel_money,
    p_terms_of_trade,
    'active',
    NOW(),
    NOW()
  )
  RETURNING id INTO v_ad_id;
  
  RETURN v_ad_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update release_coins_from_escrow to add commission tracking
CREATE OR REPLACE FUNCTION release_coins_from_escrow(
  p_trade_id UUID,
  p_seller_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_trade RECORD;
  v_buyer_id UUID;
  v_afx_amount NUMERIC;
BEGIN
  -- Get trade details
  SELECT * INTO v_trade
  FROM p2p_trades
  WHERE id = p_trade_id AND seller_id = p_seller_id AND status = 'payment_confirmed';
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  v_buyer_id := v_trade.buyer_id;
  v_afx_amount := v_trade.afx_amount;
  
  -- Transfer coins from seller (locked) to buyer (available)
  -- Remove from seller
  DELETE FROM coins
  WHERE user_id = p_seller_id
    AND status = 'locked'
    AND id IN (
      SELECT id FROM coins
      WHERE user_id = p_seller_id AND status = 'locked'
      ORDER BY created_at
      LIMIT 1
    );
  
  -- Add to buyer
  INSERT INTO coins (user_id, amount, claim_type, status, created_at, updated_at)
  VALUES (v_buyer_id, v_afx_amount, 'p2p_buy', 'available', NOW(), NOW());
  
  -- Update trade status
  UPDATE p2p_trades
  SET status = 'completed',
      coins_released_at = NOW(),
      updated_at = NOW()
  WHERE id = p_trade_id;
  
  -- Create transaction records
  INSERT INTO transactions (user_id, type, amount, description, status, related_id, created_at)
  VALUES 
    (v_buyer_id, 'buy', v_afx_amount, 'Bought AFX via P2P', 'completed', p_trade_id, NOW()),
    (p_seller_id, 'sell', -v_afx_amount, 'Sold AFX via P2P', 'completed', p_trade_id, NOW());
  
  -- Add trading commission for buyer's referrer (2%)
  PERFORM add_trading_commission(v_buyer_id, v_afx_amount, p_trade_id);
  
  -- Add trading commission for seller's referrer (2%)
  PERFORM add_trading_commission(p_seller_id, v_afx_amount, p_trade_id);
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- PART 8: GRANT PERMISSIONS
-- =====================================================

GRANT SELECT ON afx_current_price TO authenticated;
GRANT SELECT ON afx_price_history TO authenticated;
GRANT SELECT ON afx_price_references TO authenticated;
GRANT SELECT ON v_current_afx_price TO authenticated;

GRANT EXECUTE ON FUNCTION get_user_balance(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_balance(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION create_referral_relationship(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION add_trading_commission(UUID, NUMERIC, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION add_claim_commission(UUID, NUMERIC, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION post_sell_ad_with_escrow(UUID, NUMERIC, NUMERIC, NUMERIC, NUMERIC, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION release_coins_from_escrow(UUID, UUID) TO authenticated;

-- =====================================================
-- REBRANDING COMPLETE
-- =====================================================
