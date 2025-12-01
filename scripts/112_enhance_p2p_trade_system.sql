-- =====================================================
-- PART 1: ADD MISSING COLUMNS TO P2P_TRADES
-- =====================================================

-- Add payment confirmation columns
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS is_paid BOOLEAN DEFAULT FALSE;
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS paid_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS released_at TIMESTAMP WITH TIME ZONE;

-- Add cancellation tracking columns
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS cancelled_by UUID REFERENCES profiles(id);
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP WITH TIME ZONE;

-- Add expiry tracking column
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS expired_at TIMESTAMP WITH TIME ZONE;

-- Ensure escrow_amount column exists
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS escrow_amount NUMERIC DEFAULT 0;

-- =====================================================
-- PART 2: CREATE TRADE LOGS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS trade_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  trade_id UUID REFERENCES p2p_trades(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id),
  action TEXT NOT NULL,
  amount NUMERIC,
  details JSONB,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_trade_logs_trade_id ON trade_logs(trade_id);
CREATE INDEX IF NOT EXISTS idx_trade_logs_timestamp ON trade_logs(timestamp);

-- Enable RLS
ALTER TABLE trade_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view logs for their trades
CREATE POLICY "Users can view logs for their trades"
  ON trade_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM p2p_trades
      WHERE p2p_trades.id = trade_logs.trade_id
        AND (p2p_trades.buyer_id = auth.uid() OR p2p_trades.seller_id = auth.uid())
    )
  );

-- =====================================================
-- PART 3: UPDATE MARK_PAYMENT_SENT FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION mark_payment_sent(
  p_trade_id UUID,
  p_buyer_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trade p2p_trades%ROWTYPE;
BEGIN
  -- Get trade details
  SELECT * INTO v_trade
  FROM p2p_trades
  WHERE id = p_trade_id AND buyer_id = p_buyer_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trade not found or you are not the buyer';
  END IF;

  IF v_trade.status NOT IN ('pending', 'escrowed') THEN
    RAISE EXCEPTION 'Trade is not in a state to mark payment';
  END IF;

  -- Update trade with payment confirmation
  UPDATE p2p_trades
  SET 
    status = 'payment_sent',
    is_paid = TRUE,
    paid_at = NOW(),
    payment_confirmed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_trade_id;

  -- Log the action
  INSERT INTO trade_logs (trade_id, user_id, action, amount)
  VALUES (p_trade_id, p_buyer_id, 'payment_sent', v_trade.afx_amount);

  -- Record transaction
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES (p_buyer_id, 'p2p_payment_sent', 0, 'Marked payment as sent for P2P trade', p_trade_id, 'completed');
END;
$$;

-- =====================================================
-- PART 4: UPDATE RELEASE_P2P_COINS FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION release_p2p_coins(
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

  -- Require payment to be marked as sent first
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

  -- Unlock seller's coins and transfer to buyer
  UPDATE coins
  SET status = 'available',
      user_id = v_trade.buyer_id,
      updated_at = NOW()
  WHERE user_id = v_trade.seller_id
    AND status = 'locked'
    AND id IN (
      SELECT id FROM coins
      WHERE user_id = v_trade.seller_id AND status = 'locked'
      ORDER BY created_at
      LIMIT (
        SELECT COUNT(*) FROM coins
        WHERE user_id = v_trade.seller_id AND status = 'locked'
        AND amount <= v_trade.afx_amount
      )
    );

  -- Log the action
  INSERT INTO trade_logs (trade_id, user_id, action, amount)
  VALUES (p_trade_id, p_seller_id, 'coins_released', v_trade.afx_amount);

  -- Record transactions
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES 
    (v_trade.buyer_id, 'p2p_buy', v_trade.afx_amount, 'Received AFX from P2P trade', p_trade_id, 'completed'),
    (v_trade.seller_id, 'p2p_sell', -v_trade.afx_amount, 'Sold AFX in P2P trade', p_trade_id, 'completed');

  -- Process referral commission (2% of trade amount)
  SELECT referred_by INTO v_buyer_referrer
  FROM profiles
  WHERE id = v_trade.buyer_id;

  IF v_buyer_referrer IS NOT NULL THEN
    v_commission_amount := v_trade.afx_amount * 0.02;
    
    INSERT INTO coins (user_id, amount, claim_type, status)
    VALUES (v_buyer_referrer, v_commission_amount, 'referral_commission', 'available');
    
    INSERT INTO referral_commissions (referrer_id, referred_id, amount, commission_type, source_id, status)
    VALUES (v_buyer_referrer, v_trade.buyer_id, v_commission_amount, 'trading', p_trade_id, 'completed');
    
    UPDATE referrals
    SET total_trading_commission = total_trading_commission + v_commission_amount,
        updated_at = NOW()
    WHERE referrer_id = v_buyer_referrer AND referred_id = v_trade.buyer_id;
    
    INSERT INTO transactions (user_id, type, amount, description, related_id, status)
    VALUES (v_buyer_referrer, 'referral_commission', v_commission_amount, 'Referral commission from P2P trade', p_trade_id, 'completed');
  END IF;
END;
$$;

-- =====================================================
-- PART 5: UPDATE CANCEL_P2P_TRADE FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION cancel_p2p_trade(
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
  -- Get trade details
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

  -- Prevent buyer from cancelling after marking payment as sent
  IF v_trade.is_paid = TRUE AND v_trade.buyer_id = p_user_id THEN
    RAISE EXCEPTION 'Cannot cancel after marking payment as sent. Please contact seller or support.';
  END IF;

  -- Update trade status
  UPDATE p2p_trades
  SET 
    status = 'cancelled',
    cancelled_by = p_user_id,
    cancelled_at = NOW(),
    updated_at = NOW()
  WHERE id = p_trade_id;

  -- Unlock seller's coins (return from escrow)
  UPDATE coins
  SET status = 'available',
      updated_at = NOW()
  WHERE user_id = v_trade.seller_id
    AND status = 'locked'
    AND id IN (
      SELECT id FROM coins
      WHERE user_id = v_trade.seller_id AND status = 'locked'
      ORDER BY created_at
      LIMIT (
        SELECT COUNT(*) FROM coins
        WHERE user_id = v_trade.seller_id AND status = 'locked'
        AND amount <= v_trade.afx_amount
      )
    );

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

  -- Record refund transaction
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES (v_trade.seller_id, 'p2p_refund', v_trade.afx_amount, 'Coins returned from cancelled P2P trade', p_trade_id, 'completed');
END;
$$;

-- =====================================================
-- PART 6: CREATE AUTO-EXPIRY FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION expire_old_p2p_trades()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_expired_count INTEGER := 0;
  v_trade RECORD;
BEGIN
  -- Find and expire old trades
  FOR v_trade IN
    SELECT * FROM p2p_trades
    WHERE status IN ('pending', 'escrowed', 'payment_sent')
      AND expires_at < NOW()
      AND expired_at IS NULL
  LOOP
    -- Update trade status to expired
    UPDATE p2p_trades
    SET 
      status = 'expired',
      expired_at = NOW(),
      updated_at = NOW()
    WHERE id = v_trade.id;

    -- Unlock seller's coins
    UPDATE coins
    SET status = 'available',
        updated_at = NOW()
    WHERE user_id = v_trade.seller_id
      AND status = 'locked'
      AND id IN (
        SELECT id FROM coins
        WHERE user_id = v_trade.seller_id AND status = 'locked'
        ORDER BY created_at
        LIMIT (
          SELECT COUNT(*) FROM coins
          WHERE user_id = v_trade.seller_id AND status = 'locked'
          AND amount <= v_trade.afx_amount
        )
      );

    -- Return amount to ad
    IF v_trade.ad_id IS NOT NULL THEN
      UPDATE p2p_ads
      SET remaining_amount = remaining_amount + v_trade.afx_amount,
          updated_at = NOW()
      WHERE id = v_trade.ad_id;
    END IF;

    -- Log the expiry
    INSERT INTO trade_logs (trade_id, user_id, action, amount)
    VALUES (v_trade.id, v_trade.seller_id, 'trade_expired', v_trade.afx_amount);

    -- Record refund transaction
    INSERT INTO transactions (user_id, type, amount, description, related_id, status)
    VALUES (v_trade.seller_id, 'p2p_refund', v_trade.afx_amount, 'Coins returned from expired P2P trade', v_trade.id, 'completed');

    v_expired_count := v_expired_count + 1;
  END LOOP;

  RETURN v_expired_count;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION mark_payment_sent(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION release_p2p_coins(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_p2p_trade(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION expire_old_p2p_trades() TO authenticated;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_p2p_trades_expires_at ON p2p_trades(expires_at) WHERE status IN ('pending', 'escrowed', 'payment_sent');
CREATE INDEX IF NOT EXISTS idx_p2p_trades_status_expires ON p2p_trades(status, expires_at);

COMMENT ON FUNCTION mark_payment_sent IS 'Buyer marks payment as sent - enables two-step confirmation';
COMMENT ON FUNCTION release_p2p_coins IS 'Seller releases coins after confirming payment received';
COMMENT ON FUNCTION cancel_p2p_trade IS 'Cancel trade and refund escrowed coins to seller';
COMMENT ON FUNCTION expire_old_p2p_trades IS 'Auto-expire trades after 30 minutes and refund coins';
