-- =====================================================
-- SIMPLE REFERRAL SYSTEM
-- =====================================================
-- This script sets up a simple referral system:
-- 1. Auto-detects referral codes in signup
-- 2. Tracks P2P trades and gives 1% commission
-- 3. Shows referral count to upline
-- 4. Credits commission to referral balance (trade_coins)
-- =====================================================

-- Ensure profiles table has referral columns
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referred_by UUID REFERENCES profiles(id);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_referrals INTEGER DEFAULT 0;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_referral_code ON profiles(referral_code);
CREATE INDEX IF NOT EXISTS idx_profiles_referred_by ON profiles(referred_by);

-- Function to generate unique referral code
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_code TEXT;
  v_exists BOOLEAN;
BEGIN
  LOOP
    -- Generate 8 character code
    v_code := upper(substring(md5(random()::text) from 1 for 8));
    
    -- Check if it exists
    SELECT EXISTS(SELECT 1 FROM profiles WHERE referral_code = v_code) INTO v_exists;
    
    EXIT WHEN NOT v_exists;
  END LOOP;
  
  RETURN v_code;
END;
$$;

-- Trigger to auto-generate referral code on profile creation
CREATE OR REPLACE FUNCTION auto_generate_referral_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.referral_code IS NULL THEN
    NEW.referral_code := generate_referral_code();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_auto_generate_referral_code ON profiles;
CREATE TRIGGER trigger_auto_generate_referral_code
  BEFORE INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION auto_generate_referral_code();

-- Function to link referral on signup
CREATE OR REPLACE FUNCTION link_referral(
  p_user_id UUID,
  p_referral_code TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_referrer_id UUID;
BEGIN
  -- Find referrer by code
  SELECT id INTO v_referrer_id
  FROM profiles
  WHERE referral_code = p_referral_code;
  
  IF v_referrer_id IS NULL THEN
    RAISE EXCEPTION 'Invalid referral code';
  END IF;
  
  IF v_referrer_id = p_user_id THEN
    RAISE EXCEPTION 'Cannot refer yourself';
  END IF;
  
  -- Update user's referred_by
  UPDATE profiles
  SET referred_by = v_referrer_id
  WHERE id = p_user_id;
  
  -- Increment referrer's count
  UPDATE profiles
  SET total_referrals = total_referrals + 1
  WHERE id = v_referrer_id;
  
  -- Create referral record
  INSERT INTO referrals (referrer_id, referred_id, status)
  VALUES (v_referrer_id, p_user_id, 'active')
  ON CONFLICT DO NOTHING;
END;
$$;

-- Update release_p2p_coins to give 1% commission (instead of 1.5%)
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

  -- Transfer coins from seller to buyer
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

  IF NOT FOUND THEN
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

  -- Process 1% referral commission to upline's P2P balance
  SELECT referred_by INTO v_buyer_referrer
  FROM profiles
  WHERE id = v_trade.buyer_id;

  IF v_buyer_referrer IS NOT NULL THEN
    v_commission_amount := v_trade.afx_amount * 0.01;  -- 1% commission
    
    -- Credit commission to upline's trade_coins (P2P balance)
    INSERT INTO trade_coins (user_id, amount, status, source, reference_id)
    VALUES (v_buyer_referrer, v_commission_amount, 'available', 'referral_commission', p_trade_id);
    
    -- Record commission
    INSERT INTO referral_commissions (referrer_id, referred_id, amount, commission_type, source_id, status)
    VALUES (v_buyer_referrer, v_trade.buyer_id, v_commission_amount, 'trading', p_trade_id, 'completed');
    
    -- Update referral totals
    UPDATE referrals
    SET total_trading_commission = COALESCE(total_trading_commission, 0) + v_commission_amount,
        updated_at = NOW()
    WHERE referrer_id = v_buyer_referrer AND referred_id = v_trade.buyer_id;
    
    -- Record transaction
    INSERT INTO transactions (user_id, type, amount, description, related_id, status)
    VALUES (v_buyer_referrer, 'referral_commission', v_commission_amount, 'Referral commission from P2P trade (1%)', p_trade_id, 'completed');
  END IF;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION generate_referral_code() TO authenticated;
GRANT EXECUTE ON FUNCTION link_referral(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION release_p2p_coins(UUID, UUID) TO authenticated;

-- Add RLS policy for referral code lookup
DROP POLICY IF EXISTS "Anyone can lookup referral codes" ON profiles;
CREATE POLICY "Anyone can lookup referral codes" ON profiles
  FOR SELECT
  USING (referral_code IS NOT NULL);

COMMENT ON FUNCTION link_referral IS 'Link a new user to their referrer using referral code';
COMMENT ON FUNCTION release_p2p_coins IS 'Release coins from seller to buyer. Awards 1% referral commission to upline P2P balance.';
