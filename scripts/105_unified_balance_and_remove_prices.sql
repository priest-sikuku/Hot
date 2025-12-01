-- =====================================================
-- PART 1: CREATE UNIFIED BALANCE SYSTEM
-- =====================================================

-- Drop existing balance functions if they exist
DROP FUNCTION IF EXISTS get_user_balance(uuid);
DROP FUNCTION IF EXISTS get_available_balance(uuid);
DROP FUNCTION IF EXISTS get_locked_balance(uuid);

-- Create comprehensive balance function that calculates total balance
-- Includes: mining rewards, referral commissions, P2P trades
CREATE OR REPLACE FUNCTION get_user_balance(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_balance numeric := 0;
BEGIN
  -- Sum all coins for the user (available + locked)
  SELECT COALESCE(SUM(amount), 0)
  INTO v_total_balance
  FROM coins
  WHERE user_id = p_user_id;
  
  RETURN v_total_balance;
END;
$$;

-- Create function to get available balance (excluding locked P2P funds)
CREATE OR REPLACE FUNCTION get_available_balance(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_available_balance numeric := 0;
BEGIN
  -- Sum only available coins (not locked in P2P escrow)
  SELECT COALESCE(SUM(amount), 0)
  INTO v_available_balance
  FROM coins
  WHERE user_id = p_user_id
    AND status = 'available';
  
  RETURN v_available_balance;
END;
$$;

-- Create function to get locked balance (P2P escrow)
CREATE OR REPLACE FUNCTION get_locked_balance(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_locked_balance numeric := 0;
BEGIN
  -- Sum locked coins (in P2P escrow)
  SELECT COALESCE(SUM(amount), 0)
  INTO v_locked_balance
  FROM coins
  WHERE user_id = p_user_id
    AND status = 'locked';
  
  RETURN v_locked_balance;
END;
$$;

-- Create view for user balance summary
CREATE OR REPLACE VIEW user_balance_summary AS
SELECT 
  p.id as user_id,
  p.username,
  p.email,
  get_user_balance(p.id) as total_balance,
  get_available_balance(p.id) as available_balance,
  get_locked_balance(p.id) as locked_balance,
  p.total_commission as referral_earnings,
  p.rating,
  p.total_referrals
FROM profiles p;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_user_balance(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_balance(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_locked_balance(uuid) TO authenticated;
GRANT SELECT ON user_balance_summary TO authenticated;

-- =====================================================
-- PART 2: REMOVE ALL PRICE-RELATED FUNCTIONALITY
-- =====================================================

-- Drop price-related views
DROP VIEW IF EXISTS v_current_afx_price CASCADE;
DROP VIEW IF EXISTS price_history_5days CASCADE;

-- Drop price-related functions
DROP FUNCTION IF EXISTS get_current_afx_price_with_auto_update() CASCADE;
DROP FUNCTION IF EXISTS manual_price_update() CASCADE;
DROP FUNCTION IF EXISTS update_afx_price() CASCADE;
DROP FUNCTION IF EXISTS calculate_new_price() CASCADE;

-- Drop price-related triggers
DROP TRIGGER IF EXISTS update_price_daily ON afx_price_references CASCADE;

-- Drop price-related tables
DROP TABLE IF EXISTS afx_price_history CASCADE;
DROP TABLE IF EXISTS afx_current_price CASCADE;
DROP TABLE IF EXISTS afx_price_references CASCADE;

-- Remove price_per_afx column from p2p_ads (we'll keep it for now but make it optional)
-- Users can set their own prices without system validation
COMMENT ON COLUMN p2p_ads.price_per_afx IS 'User-defined price per AFX (no system validation)';

-- Update P2P trade initiation function to remove price validation
CREATE OR REPLACE FUNCTION initiate_p2p_trade_v2(
  p_ad_id uuid,
  p_buyer_id uuid,
  p_afx_amount numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ad p2p_ads%ROWTYPE;
  v_seller_id uuid;
  v_trade_id uuid;
  v_seller_balance numeric;
BEGIN
  -- Get ad details
  SELECT * INTO v_ad
  FROM p2p_ads
  WHERE id = p_ad_id
    AND status = 'active'
    AND expires_at > NOW();
    
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ad not found or expired';
  END IF;
  
  -- Validate amount
  IF p_afx_amount < v_ad.min_amount OR p_afx_amount > v_ad.max_amount THEN
    RAISE EXCEPTION 'Amount must be between % and %', v_ad.min_amount, v_ad.max_amount;
  END IF;
  
  IF p_afx_amount > v_ad.remaining_amount THEN
    RAISE EXCEPTION 'Insufficient remaining amount in ad';
  END IF;
  
  -- Determine seller based on ad type
  IF v_ad.ad_type = 'sell' THEN
    v_seller_id := v_ad.user_id;
    
    -- Check seller has enough balance
    SELECT get_available_balance(v_seller_id) INTO v_seller_balance;
    IF v_seller_balance < p_afx_amount THEN
      RAISE EXCEPTION 'Seller has insufficient balance';
    END IF;
    
    -- Lock seller's coins in escrow
    UPDATE coins
    SET status = 'locked'
    WHERE user_id = v_seller_id
      AND status = 'available'
      AND id IN (
        SELECT id FROM coins
        WHERE user_id = v_seller_id AND status = 'available'
        ORDER BY created_at
        LIMIT (
          SELECT COUNT(*) FROM coins
          WHERE user_id = v_seller_id AND status = 'available'
          AND amount <= p_afx_amount
        )
      );
      
  ELSE -- buy ad
    v_seller_id := p_buyer_id;
    
    -- Check seller (who is responding to buy ad) has enough balance
    SELECT get_available_balance(v_seller_id) INTO v_seller_balance;
    IF v_seller_balance < p_afx_amount THEN
      RAISE EXCEPTION 'You have insufficient balance to sell';
    END IF;
    
    -- Lock seller's coins in escrow
    UPDATE coins
    SET status = 'locked'
    WHERE user_id = v_seller_id
      AND status = 'available'
      AND id IN (
        SELECT id FROM coins
        WHERE user_id = v_seller_id AND status = 'available'
        ORDER BY created_at
        LIMIT (
          SELECT COUNT(*) FROM coins
          WHERE user_id = v_seller_id AND status = 'available'
          AND amount <= p_afx_amount
        )
      );
  END IF;
  
  -- Create trade
  INSERT INTO p2p_trades (
    ad_id,
    buyer_id,
    seller_id,
    afx_amount,
    escrow_amount,
    status,
    expires_at
  ) VALUES (
    p_ad_id,
    p_buyer_id,
    v_seller_id,
    p_afx_amount,
    p_afx_amount,
    'pending',
    NOW() + INTERVAL '30 minutes'
  )
  RETURNING id INTO v_trade_id;
  
  -- Update ad remaining amount
  UPDATE p2p_ads
  SET remaining_amount = remaining_amount - p_afx_amount
  WHERE id = p_ad_id;
  
  -- Create transaction records
  INSERT INTO transactions (user_id, type, amount, description, status, related_id)
  VALUES 
    (v_seller_id, 'p2p_escrow', p_afx_amount, 'AFX locked in P2P escrow', 'pending', v_trade_id),
    (p_buyer_id, 'p2p_pending', p_afx_amount, 'P2P trade initiated', 'pending', v_trade_id);
  
  RETURN v_trade_id;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION initiate_p2p_trade_v2(uuid, uuid, numeric) TO authenticated;

COMMENT ON FUNCTION initiate_p2p_trade_v2 IS 'Initiates P2P trade without price validation - users set their own prices';
