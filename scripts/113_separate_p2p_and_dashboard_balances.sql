-- =====================================================
-- COMPREHENSIVE P2P & DASHBOARD BALANCE SEPARATION
-- =====================================================

-- =====================================================
-- PART 1: ADD BALANCE COLUMNS TO PROFILES
-- =====================================================

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS dashboard_balance NUMERIC DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS p2p_balance NUMERIC DEFAULT 0;

-- Migrate existing balance from coins table to dashboard_balance
-- This is a one-time migration that sums up all available coins
DO $$
DECLARE
  v_user RECORD;
  v_total_balance NUMERIC;
BEGIN
  FOR v_user IN SELECT DISTINCT user_id FROM coins WHERE status = 'available'
  LOOP
    SELECT COALESCE(SUM(amount), 0) INTO v_total_balance
    FROM coins
    WHERE user_id = v_user.user_id AND status = 'available';
    
    UPDATE profiles
    SET dashboard_balance = v_total_balance,
        p2p_balance = 0
    WHERE id = v_user.user_id;
  END LOOP;
END $$;

-- =====================================================
-- PART 2: CREATE P2P_TRANSFERS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS p2p_transfers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  direction TEXT NOT NULL CHECK (direction IN ('to_p2p', 'from_p2p')),
  from_balance TEXT NOT NULL,
  to_balance TEXT NOT NULL,
  status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_p2p_transfers_user_id ON p2p_transfers(user_id);
CREATE INDEX IF NOT EXISTS idx_p2p_transfers_created_at ON p2p_transfers(created_at);

-- Enable RLS
ALTER TABLE p2p_transfers ENABLE ROW LEVEL SECURITY;

-- Added DROP POLICY IF EXISTS to prevent duplicate policy errors
-- RLS Policy: Users can view their own transfers
DROP POLICY IF EXISTS "Users can view their own transfers" ON p2p_transfers;
CREATE POLICY "Users can view their own transfers"
  ON p2p_transfers FOR SELECT
  USING (user_id = auth.uid());

-- RLS Policy: Users can insert their own transfers
DROP POLICY IF EXISTS "Users can insert their own transfers" ON p2p_transfers;
CREATE POLICY "Users can insert their own transfers"
  ON p2p_transfers FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- =====================================================
-- PART 3: CREATE TRANSFER FUNCTIONS
-- =====================================================

-- Function to transfer from dashboard to P2P balance
CREATE OR REPLACE FUNCTION transfer_to_p2p(
  p_user_id UUID,
  p_amount NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_dashboard_balance NUMERIC;
  v_transfer_id UUID;
BEGIN
  -- Validate amount
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transfer amount must be greater than 0';
  END IF;

  -- Get current dashboard balance
  SELECT dashboard_balance INTO v_dashboard_balance
  FROM profiles
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  -- Check sufficient balance
  IF v_dashboard_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient dashboard balance. Available: %, Requested: %', v_dashboard_balance, p_amount;
  END IF;

  -- Update balances
  UPDATE profiles
  SET 
    dashboard_balance = dashboard_balance - p_amount,
    p2p_balance = p2p_balance + p_amount,
    updated_at = NOW()
  WHERE id = p_user_id;

  -- Log the transfer
  INSERT INTO p2p_transfers (user_id, amount, direction, from_balance, to_balance, status)
  VALUES (p_user_id, p_amount, 'to_p2p', 'dashboard', 'p2p', 'completed')
  RETURNING id INTO v_transfer_id;

  -- Record transaction
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES (p_user_id, 'transfer_to_p2p', p_amount, 'Transferred from Dashboard to P2P balance', v_transfer_id, 'completed');

  RETURN jsonb_build_object(
    'success', true,
    'transfer_id', v_transfer_id,
    'amount', p_amount,
    'new_dashboard_balance', v_dashboard_balance - p_amount,
    'new_p2p_balance', (SELECT p2p_balance FROM profiles WHERE id = p_user_id)
  );
END;
$$;

-- Function to transfer from P2P to dashboard balance
CREATE OR REPLACE FUNCTION transfer_from_p2p(
  p_user_id UUID,
  p_amount NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_p2p_balance NUMERIC;
  v_transfer_id UUID;
BEGIN
  -- Validate amount
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transfer amount must be greater than 0';
  END IF;

  -- Get current P2P balance
  SELECT p2p_balance INTO v_p2p_balance
  FROM profiles
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  -- Check sufficient balance
  IF v_p2p_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient P2P balance. Available: %, Requested: %', v_p2p_balance, p_amount;
  END IF;

  -- Update balances
  UPDATE profiles
  SET 
    p2p_balance = p2p_balance - p_amount,
    dashboard_balance = dashboard_balance + p_amount,
    updated_at = NOW()
  WHERE id = p_user_id;

  -- Log the transfer
  INSERT INTO p2p_transfers (user_id, amount, direction, from_balance, to_balance, status)
  VALUES (p_user_id, p_amount, 'from_p2p', 'p2p', 'dashboard', 'completed')
  RETURNING id INTO v_transfer_id;

  -- Record transaction
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES (p_user_id, 'transfer_from_p2p', p_amount, 'Transferred from P2P to Dashboard balance', v_transfer_id, 'completed');

  RETURN jsonb_build_object(
    'success', true,
    'transfer_id', v_transfer_id,
    'amount', p_amount,
    'new_p2p_balance', v_p2p_balance - p_amount,
    'new_dashboard_balance', (SELECT dashboard_balance FROM profiles WHERE id = p_user_id)
  );
END;
$$;

-- =====================================================
-- PART 4: UPDATE P2P TRADE INITIATION TO USE P2P BALANCE
-- =====================================================

CREATE OR REPLACE FUNCTION initiate_p2p_trade_v2(
  p_ad_id UUID,
  p_afx_amount NUMERIC,
  p_buyer_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ad p2p_ads%ROWTYPE;
  v_trade_id UUID;
  v_seller_p2p_balance NUMERIC;
BEGIN
  -- Get ad details
  SELECT * INTO v_ad FROM p2p_ads WHERE id = p_ad_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ad not found';
  END IF;
  
  IF v_ad.status != 'active' THEN
    RAISE EXCEPTION 'Ad is not active';
  END IF;
  
  IF v_ad.user_id = p_buyer_id THEN
    RAISE EXCEPTION 'Cannot trade with yourself';
  END IF;
  
  IF p_afx_amount < v_ad.min_amount OR p_afx_amount > v_ad.max_amount THEN
    RAISE EXCEPTION 'Amount must be between % and %', v_ad.min_amount, v_ad.max_amount;
  END IF;
  
  IF p_afx_amount > v_ad.remaining_amount THEN
    RAISE EXCEPTION 'Insufficient remaining amount in ad';
  END IF;
  
  -- Check seller's P2P balance instead of coins table
  SELECT p2p_balance INTO v_seller_p2p_balance
  FROM profiles
  WHERE id = v_ad.user_id;
  
  IF v_seller_p2p_balance < p_afx_amount THEN
    RAISE EXCEPTION 'Seller has insufficient P2P balance. Available: %, Required: %', v_seller_p2p_balance, p_afx_amount;
  END IF;
  
  -- Lock seller's P2P balance (move to escrow)
  UPDATE profiles
  SET p2p_balance = p2p_balance - p_afx_amount,
      updated_at = NOW()
  WHERE id = v_ad.user_id;
  
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
    v_ad.user_id,
    p_afx_amount,
    p_afx_amount,
    'escrowed',
    NOW() + INTERVAL '30 minutes'
  ) RETURNING id INTO v_trade_id;
  
  -- Update ad remaining amount
  UPDATE p2p_ads
  SET remaining_amount = remaining_amount - p_afx_amount,
      updated_at = NOW()
  WHERE id = p_ad_id;
  
  -- Log the trade initiation
  INSERT INTO trade_logs (trade_id, user_id, action, amount)
  VALUES (v_trade_id, v_ad.user_id, 'trade_initiated', p_afx_amount);
  
  RETURN v_trade_id;
END;
$$;

-- =====================================================
-- PART 5: UPDATE RELEASE FUNCTION WITH 1.5% COMMISSION
-- =====================================================

CREATE OR REPLACE FUNCTION release_p2p_coins_v3(
  p_trade_id UUID,
  p_seller_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trade p2p_trades%ROWTYPE;
  v_buyer_referrer UUID;
  v_commission_amount NUMERIC;
BEGIN
  -- Get trade details
  SELECT * INTO v_trade
  FROM p2p_trades
  WHERE id = p_trade_id AND seller_id = p_seller_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trade not found or you are not the seller';
  END IF;

  IF v_trade.is_paid IS NOT TRUE THEN
    RAISE EXCEPTION 'Buyer must mark payment as sent before you can release coins';
  END IF;

  IF v_trade.status NOT IN ('payment_sent', 'escrowed') THEN
    RAISE EXCEPTION 'Trade is not in a state to release coins';
  END IF;

  -- Update trade status to completed
  UPDATE p2p_trades
  SET 
    status = 'completed',
    released_at = NOW(),
    coins_released_at = NOW(),
    updated_at = NOW()
  WHERE id = p_trade_id;

  -- Transfer AFX from escrow to buyer's P2P balance
  UPDATE profiles
  SET p2p_balance = p2p_balance + v_trade.afx_amount,
      updated_at = NOW()
  WHERE id = v_trade.buyer_id;

  -- Log the action
  INSERT INTO trade_logs (trade_id, user_id, action, amount)
  VALUES (p_trade_id, p_seller_id, 'coins_released', v_trade.afx_amount);

  -- Record transactions
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES 
    (v_trade.buyer_id, 'p2p_buy', v_trade.afx_amount, 'Received AFX from P2P trade', p_trade_id, 'completed'),
    (v_trade.seller_id, 'p2p_sell', -v_trade.afx_amount, 'Sold AFX in P2P trade', p_trade_id, 'completed');

  -- Process referral commission (1.5% of trade amount, not 2%)
  SELECT referred_by INTO v_buyer_referrer
  FROM profiles
  WHERE id = v_trade.buyer_id;

  IF v_buyer_referrer IS NOT NULL THEN
    v_commission_amount := v_trade.afx_amount * 0.015; -- 1.5% commission
    
    -- Credit commission to referrer's P2P balance
    UPDATE profiles
    SET p2p_balance = p2p_balance + v_commission_amount,
        total_commission = total_commission + v_commission_amount,
        updated_at = NOW()
    WHERE id = v_buyer_referrer;
    
    INSERT INTO referral_commissions (referrer_id, referred_id, amount, commission_type, source_id, status)
    VALUES (v_buyer_referrer, v_trade.buyer_id, v_commission_amount, 'trading', p_trade_id, 'completed');
    
    UPDATE referrals
    SET total_trading_commission = COALESCE(total_trading_commission, 0) + v_commission_amount,
        updated_at = NOW()
    WHERE referrer_id = v_buyer_referrer AND referred_id = v_trade.buyer_id;
    
    INSERT INTO transactions (user_id, type, amount, description, related_id, status)
    VALUES (v_buyer_referrer, 'referral_commission', v_commission_amount, 'Referral commission (1.5%) from P2P trade', p_trade_id, 'completed');
    
    -- Log commission award
    INSERT INTO trade_logs (trade_id, user_id, action, amount, details)
    VALUES (p_trade_id, v_buyer_referrer, 'commission_awarded', v_commission_amount, 
            jsonb_build_object('commission_rate', '1.5%', 'trade_amount', v_trade.afx_amount));
  END IF;
END;
$$;

-- =====================================================
-- PART 6: UPDATE CANCEL FUNCTION TO REFUND P2P BALANCE
-- =====================================================

CREATE OR REPLACE FUNCTION cancel_p2p_trade_v2(
  p_trade_id UUID,
  p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trade p2p_trades%ROWTYPE;
BEGIN
  SELECT * INTO v_trade
  FROM p2p_trades
  WHERE id = p_trade_id 
    AND (buyer_id = p_user_id OR seller_id = p_user_id);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trade not found or you are not authorized';
  END IF;

  IF v_trade.status = 'completed' THEN
    RAISE EXCEPTION 'Cannot cancel completed trade';
  END IF;

  IF v_trade.is_paid = TRUE AND v_trade.buyer_id = p_user_id THEN
    RAISE EXCEPTION 'Cannot cancel after marking payment as sent';
  END IF;

  -- Update trade status
  UPDATE p2p_trades
  SET 
    status = 'cancelled',
    cancelled_by = p_user_id,
    cancelled_at = NOW(),
    updated_at = NOW()
  WHERE id = p_trade_id;

  -- Return escrowed amount to seller's P2P balance
  UPDATE profiles
  SET p2p_balance = p2p_balance + v_trade.escrow_amount,
      updated_at = NOW()
  WHERE id = v_trade.seller_id;

  -- Return amount to ad
  IF v_trade.ad_id IS NOT NULL THEN
    UPDATE p2p_ads
    SET remaining_amount = remaining_amount + v_trade.afx_amount,
        updated_at = NOW()
    WHERE id = v_trade.ad_id;
  END IF;

  -- Log the action
  INSERT INTO trade_logs (trade_id, user_id, action, amount, details)
  VALUES (
    p_trade_id, 
    p_user_id, 
    'trade_cancelled', 
    v_trade.afx_amount,
    jsonb_build_object('cancelled_by_role', CASE WHEN p_user_id = v_trade.buyer_id THEN 'buyer' ELSE 'seller' END)
  );

  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES (v_trade.seller_id, 'p2p_refund', v_trade.afx_amount, 'P2P balance returned from cancelled trade', p_trade_id, 'completed');
END;
$$;

-- =====================================================
-- PART 7: UPDATE MINING REWARDS TO CREDIT DASHBOARD BALANCE
-- =====================================================

CREATE OR REPLACE FUNCTION record_mining_reward(
  p_user_id UUID,
  p_amount NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Credit mining rewards to dashboard balance
  UPDATE profiles
  SET dashboard_balance = dashboard_balance + p_amount,
      updated_at = NOW()
  WHERE id = p_user_id;
  
  -- Record transaction
  INSERT INTO transactions (user_id, type, amount, description, status)
  VALUES (p_user_id, 'mining', p_amount, 'Mining reward', 'completed');
  
  -- Also insert into coins table for backward compatibility
  INSERT INTO coins (user_id, amount, claim_type, status)
  VALUES (p_user_id, p_amount, 'mining', 'available');
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION transfer_to_p2p(UUID, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION transfer_from_p2p(UUID, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION initiate_p2p_trade_v2(UUID, NUMERIC, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION release_p2p_coins_v3(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_p2p_trade_v2(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION record_mining_reward(UUID, NUMERIC) TO authenticated;

-- Create view for easy balance checking
CREATE OR REPLACE VIEW user_balances AS
SELECT 
  id as user_id,
  username,
  email,
  dashboard_balance,
  p2p_balance,
  (dashboard_balance + p2p_balance) as total_balance,
  total_commission,
  total_referrals
FROM profiles;

COMMENT ON FUNCTION transfer_to_p2p IS 'Transfer funds from dashboard balance to P2P balance';
COMMENT ON FUNCTION transfer_from_p2p IS 'Transfer funds from P2P balance to dashboard balance';
COMMENT ON FUNCTION initiate_p2p_trade_v2 IS 'Initiate P2P trade using seller P2P balance';
COMMENT ON FUNCTION release_p2p_coins_v3 IS 'Release coins with 1.5% referral commission';
COMMENT ON FUNCTION cancel_p2p_trade_v2 IS 'Cancel trade and refund to P2P balance';
COMMENT ON FUNCTION record_mining_reward IS 'Record mining reward to dashboard balance';
