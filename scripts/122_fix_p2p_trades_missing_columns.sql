-- =====================================================
-- FIX P2P TRADES SYSTEM - ADD MISSING COLUMNS AND UPDATE FUNCTIONS
-- =====================================================

-- Add missing columns to p2p_trades table
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS price_per_afx NUMERIC;
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS total_amount NUMERIC;
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS payment_method TEXT;
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS payment_details JSONB;

-- Update existing trades to have default values
UPDATE p2p_trades 
SET price_per_afx = 1.0 
WHERE price_per_afx IS NULL;

UPDATE p2p_trades 
SET total_amount = afx_amount * COALESCE(price_per_afx, 1.0)
WHERE total_amount IS NULL;

-- =====================================================
-- UPDATE RELEASE_P2P_COINS TO USE TRADE_COINS TABLE
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

  IF v_trade.status NOT IN ('payment_sent', 'escrowed', 'pending') THEN
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

  -- Transfer coins from seller's trade_coins to buyer's trade_coins
  -- Unlock seller's locked coins and transfer to buyer
  UPDATE trade_coins
  SET 
    user_id = v_trade.buyer_id,
    status = 'available',
    locked_at = NULL,
    locked_for_trade_id = NULL,
    updated_at = NOW()
  WHERE user_id = v_trade.seller_id
    AND status = 'locked'
    AND locked_for_trade_id = p_trade_id;

  -- If no locked coins found, try to deduct from available coins
  IF NOT FOUND THEN
    -- Deduct from seller's available trade_coins
    UPDATE trade_coins
    SET amount = amount - v_trade.afx_amount,
        updated_at = NOW()
    WHERE user_id = v_trade.seller_id
      AND status = 'available'
      AND amount >= v_trade.afx_amount
      AND id = (
        SELECT id FROM trade_coins
        WHERE user_id = v_trade.seller_id 
          AND status = 'available'
          AND amount >= v_trade.afx_amount
        ORDER BY created_at ASC
        LIMIT 1
      );

    -- Add to buyer's trade_coins
    INSERT INTO trade_coins (user_id, amount, status, source, reference_id)
    VALUES (v_trade.buyer_id, v_trade.afx_amount, 'available', 'p2p_trade', p_trade_id);
  END IF;

  -- Log the action
  INSERT INTO trade_logs (trade_id, user_id, action, amount)
  VALUES (p_trade_id, p_seller_id, 'coins_released', v_trade.afx_amount);

  -- Record transactions
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES 
    (v_trade.buyer_id, 'p2p_buy', v_trade.afx_amount, 'Received AFX from P2P trade', p_trade_id, 'completed'),
    (v_trade.seller_id, 'p2p_sell', -v_trade.afx_amount, 'Sold AFX in P2P trade', p_trade_id, 'completed');

  -- Process referral commission (1.5% of trade amount to upline's P2P balance)
  SELECT referred_by INTO v_buyer_referrer
  FROM profiles
  WHERE id = v_trade.buyer_id;

  IF v_buyer_referrer IS NOT NULL THEN
    v_commission_amount := v_trade.afx_amount * 0.015;  -- 1.5% commission
    
    -- Credit commission to upline's trade_coins (P2P balance)
    INSERT INTO trade_coins (user_id, amount, status, source, reference_id)
    VALUES (v_buyer_referrer, v_commission_amount, 'available', 'referral_commission', p_trade_id);
    
    INSERT INTO referral_commissions (referrer_id, referred_id, amount, commission_type, source_id, status)
    VALUES (v_buyer_referrer, v_trade.buyer_id, v_commission_amount, 'trading', p_trade_id, 'completed');
    
    UPDATE referrals
    SET total_trading_commission = total_trading_commission + v_commission_amount,
        updated_at = NOW()
    WHERE referrer_id = v_buyer_referrer AND referred_id = v_trade.buyer_id;
    
    INSERT INTO transactions (user_id, type, amount, description, related_id, status)
    VALUES (v_buyer_referrer, 'referral_commission', v_commission_amount, 'Referral commission from P2P trade (1.5%)', p_trade_id, 'completed');
  END IF;
END;
$$;

-- =====================================================
-- UPDATE CANCEL_P2P_TRADE TO USE TRADE_COINS TABLE
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

  -- Unlock seller's coins in trade_coins table
  UPDATE trade_coins
  SET 
    status = 'available',
    locked_at = NULL,
    locked_for_trade_id = NULL,
    updated_at = NOW()
  WHERE user_id = v_trade.seller_id
    AND status = 'locked'
    AND locked_for_trade_id = p_trade_id;

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
-- UPDATE EXPIRE_OLD_P2P_TRADES TO USE TRADE_COINS TABLE
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

    -- Unlock seller's coins in trade_coins table
    UPDATE trade_coins
    SET 
      status = 'available',
      locked_at = NULL,
      locked_for_trade_id = NULL,
      updated_at = NOW()
    WHERE user_id = v_trade.seller_id
      AND status = 'locked'
      AND locked_for_trade_id = v_trade.id;

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
GRANT EXECUTE ON FUNCTION release_p2p_coins(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_p2p_trade(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION expire_old_p2p_trades() TO authenticated;

-- Add comments
COMMENT ON FUNCTION release_p2p_coins IS 'Release coins from seller to buyer using trade_coins table. Awards 1.5% referral commission to upline P2P balance.';
COMMENT ON FUNCTION cancel_p2p_trade IS 'Cancel trade and unlock coins in trade_coins table';
COMMENT ON FUNCTION expire_old_p2p_trades IS 'Auto-expire old trades and unlock coins in trade_coins table';

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_trade_coins_locked_for_trade ON trade_coins(locked_for_trade_id) WHERE locked_for_trade_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_trade_coins_user_status ON trade_coins(user_id, status);
