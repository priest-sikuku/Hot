-- =====================================================
-- FIX COMPLETE REFERRAL SYSTEM
-- =====================================================
-- Consolidates and fixes all referral functionality:
-- 1. 1 AFX when downline completes first mining circle
-- 2. 2 AFX when downline completes P2P trade
-- 3. Proper tracking and commission crediting
-- =====================================================

-- Ensure all required columns exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referred_by UUID REFERENCES profiles(id);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_referrals INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_commission NUMERIC DEFAULT 0;

-- Ensure referrals table has tracking columns
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS first_mining_reward_given BOOLEAN DEFAULT FALSE;
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS signup_reward_given BOOLEAN DEFAULT FALSE;
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS total_trading_commission NUMERIC DEFAULT 0;
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS total_claim_commission NUMERIC DEFAULT 0;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_profiles_referral_code ON profiles(referral_code);
CREATE INDEX IF NOT EXISTS idx_profiles_referred_by ON profiles(referred_by);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred ON referrals(referred_id);

-- =====================================================
-- PART 1: REFERRAL CODE GENERATION
-- =====================================================

CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_code TEXT;
  v_exists BOOLEAN;
BEGIN
  LOOP
    v_code := upper(substring(md5(random()::text) from 1 for 8));
    SELECT EXISTS(SELECT 1 FROM profiles WHERE referral_code = v_code) INTO v_exists;
    EXIT WHEN NOT v_exists;
  END LOOP;
  RETURN v_code;
END;
$$;

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

-- =====================================================
-- PART 2: LINK REFERRAL ON SIGNUP
-- =====================================================

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
  WHERE referral_code = UPPER(p_referral_code);
  
  IF v_referrer_id IS NULL THEN
    RAISE EXCEPTION 'Invalid referral code';
  END IF;
  
  IF v_referrer_id = p_user_id THEN
    RAISE EXCEPTION 'Cannot refer yourself';
  END IF;
  
  -- Check if user already has a referrer
  IF EXISTS (SELECT 1 FROM profiles WHERE id = p_user_id AND referred_by IS NOT NULL) THEN
    RAISE EXCEPTION 'User already has a referrer';
  END IF;
  
  -- Update user's referred_by
  UPDATE profiles
  SET referred_by = v_referrer_id,
      updated_at = NOW()
  WHERE id = p_user_id;
  
  -- Increment referrer's count
  UPDATE profiles
  SET total_referrals = total_referrals + 1,
      updated_at = NOW()
  WHERE id = v_referrer_id;
  
  -- Create or update referral record
  INSERT INTO referrals (
    referrer_id, 
    referred_id, 
    status, 
    first_mining_reward_given,
    signup_reward_given
  )
  VALUES (
    v_referrer_id, 
    p_user_id, 
    'active',
    FALSE,
    FALSE
  )
  ON CONFLICT (referrer_id, referred_id) 
  DO UPDATE SET 
    status = 'active',
    updated_at = NOW();
    
  RAISE NOTICE '[v0] Referral linked: User % referred by % (code: %)', p_user_id, v_referrer_id, p_referral_code;
END;
$$;

-- =====================================================
-- PART 3: AWARD 1 AFX ON FIRST MINING CIRCLE
-- =====================================================

CREATE OR REPLACE FUNCTION award_referral_mining_bonus()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_referrer_id UUID;
  v_reward_amount NUMERIC := 1.0;
  v_already_rewarded BOOLEAN;
BEGIN
  -- Only for mining claims
  IF NEW.claim_type != 'mining' THEN
    RETURN NEW;
  END IF;
  
  -- Get referrer
  SELECT referred_by INTO v_referrer_id
  FROM profiles
  WHERE id = NEW.user_id;
  
  IF v_referrer_id IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Check if reward already given
  SELECT first_mining_reward_given INTO v_already_rewarded
  FROM referrals
  WHERE referrer_id = v_referrer_id AND referred_id = NEW.user_id;
  
  IF v_already_rewarded THEN
    RETURN NEW;
  END IF;
  
  -- Award 1 AFX to referrer's P2P balance
  INSERT INTO trade_coins (user_id, amount, status, source, reference_id)
  VALUES (v_referrer_id, v_reward_amount, 'available', 'referral_commission', NEW.id);
  
  -- Record commission
  INSERT INTO referral_commissions (
    referrer_id, 
    referred_id, 
    amount, 
    commission_type, 
    source_id, 
    status
  ) VALUES (
    v_referrer_id, 
    NEW.user_id, 
    v_reward_amount, 
    'signup_mining', 
    NEW.id, 
    'completed'
  );
  
  -- Mark as rewarded
  UPDATE referrals
  SET first_mining_reward_given = TRUE,
      total_claim_commission = COALESCE(total_claim_commission, 0) + v_reward_amount,
      updated_at = NOW()
  WHERE referrer_id = v_referrer_id AND referred_id = NEW.user_id;
  
  -- Update profile commission total
  UPDATE profiles
  SET total_commission = COALESCE(total_commission, 0) + v_reward_amount,
      updated_at = NOW()
  WHERE id = v_referrer_id;
  
  -- Record transaction
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES (
    v_referrer_id, 
    'referral_commission', 
    v_reward_amount, 
    'Referral bonus: 1 AFX (downline completed first mining)', 
    NEW.user_id, 
    'completed'
  );
  
  RAISE NOTICE '[v0] Awarded 1 AFX mining bonus to referrer % for user %', v_referrer_id, NEW.user_id;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_referral_mining_bonus ON coins;
CREATE TRIGGER trigger_referral_mining_bonus
  AFTER INSERT ON coins
  FOR EACH ROW
  WHEN (NEW.claim_type = 'mining')
  EXECUTE FUNCTION award_referral_mining_bonus();

-- =====================================================
-- PART 4: AWARD 2 AFX ON P2P TRADE COMPLETION
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
  v_commission_amount NUMERIC := 2.0; -- Fixed 2 AFX
  v_escrow_record RECORD;
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
    RAISE EXCEPTION 'Trade is not in a state to release coins. Current status: %', v_trade.status;
  END IF;

  -- Update trade status
  UPDATE p2p_trades
  SET 
    status = 'completed',
    released_at = NOW(),
    coins_released_at = NOW(),
    updated_at = NOW()
  WHERE id = p_trade_id;

  -- Transfer locked coins to buyer
  UPDATE trade_coins
  SET 
    user_id = v_trade.buyer_id,
    status = 'available',
    locked_at = NULL,
    locked_for_trade_id = NULL,
    updated_at = NOW()
  WHERE user_id = v_trade.seller_id
    AND status = 'locked'
    AND locked_for_trade_id = p_trade_id
  RETURNING * INTO v_escrow_record;

  -- If no locked coins, deduct from available
  IF NOT FOUND THEN
    WITH seller_coin AS (
      SELECT id FROM trade_coins
      WHERE user_id = v_trade.seller_id 
        AND status = 'available'
        AND amount >= v_trade.afx_amount
      ORDER BY created_at ASC
      LIMIT 1
      FOR UPDATE
    )
    UPDATE trade_coins
    SET amount = amount - v_trade.afx_amount,
        updated_at = NOW()
    WHERE id = (SELECT id FROM seller_coin);

    -- Credit buyer
    INSERT INTO trade_coins (user_id, amount, status, source, reference_id)
    VALUES (v_trade.buyer_id, v_trade.afx_amount, 'available', 'p2p_trade', p_trade_id);
  END IF;

  -- Log action
  INSERT INTO trade_logs (trade_id, user_id, action, amount, details)
  VALUES (
    p_trade_id, 
    p_seller_id, 
    'coins_released', 
    v_trade.afx_amount,
    jsonb_build_object('buyer_id', v_trade.buyer_id, 'timestamp', NOW())
  );

  -- Record transactions
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES 
    (v_trade.buyer_id, 'p2p_buy', v_trade.afx_amount, 'Received AFX from P2P trade', p_trade_id, 'completed'),
    (v_trade.seller_id, 'p2p_sell', -v_trade.afx_amount, 'Sold AFX in P2P trade', p_trade_id, 'completed');

  -- Process 2 AFX referral commission
  SELECT referred_by INTO v_buyer_referrer
  FROM profiles
  WHERE id = v_trade.buyer_id;

  IF v_buyer_referrer IS NOT NULL THEN
    -- Credit 2 AFX to referrer's P2P balance
    INSERT INTO trade_coins (user_id, amount, status, source, reference_id)
    VALUES (v_buyer_referrer, v_commission_amount, 'available', 'referral_commission', p_trade_id);
    
    -- Record commission
    INSERT INTO referral_commissions (
      referrer_id, 
      referred_id, 
      amount, 
      commission_type, 
      source_id, 
      status
    ) VALUES (
      v_buyer_referrer, 
      v_trade.buyer_id, 
      v_commission_amount, 
      'trading', 
      p_trade_id, 
      'completed'
    );
    
    -- Update referral totals
    UPDATE referrals
    SET total_trading_commission = COALESCE(total_trading_commission, 0) + v_commission_amount,
        updated_at = NOW()
    WHERE referrer_id = v_buyer_referrer AND referred_id = v_trade.buyer_id;
    
    -- Update profile commission
    UPDATE profiles
    SET total_commission = COALESCE(total_commission, 0) + v_commission_amount,
        updated_at = NOW()
    WHERE id = v_buyer_referrer;
    
    -- Record transaction
    INSERT INTO transactions (user_id, type, amount, description, related_id, status)
    VALUES (
      v_buyer_referrer, 
      'referral_commission', 
      v_commission_amount, 
      'Referral P2P trade bonus: 2 AFX', 
      p_trade_id, 
      'completed'
    );
    
    RAISE NOTICE '[v0] Awarded 2 AFX P2P commission to referrer % for user % trade', v_buyer_referrer, v_trade.buyer_id;
  END IF;
  
  RAISE NOTICE '[v0] Trade % completed successfully', p_trade_id;
END;
$$;

-- =====================================================
-- PERMISSIONS AND POLICIES
-- =====================================================

GRANT EXECUTE ON FUNCTION generate_referral_code() TO authenticated;
GRANT EXECUTE ON FUNCTION auto_generate_referral_code() TO authenticated;
GRANT EXECUTE ON FUNCTION link_referral(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION award_referral_mining_bonus() TO authenticated;
GRANT EXECUTE ON FUNCTION release_p2p_coins(UUID, UUID) TO authenticated;

-- RLS policy for referral code lookup
DROP POLICY IF EXISTS "Anyone can lookup referral codes" ON profiles;
CREATE POLICY "Anyone can lookup referral codes" ON profiles
  FOR SELECT
  USING (referral_code IS NOT NULL);

-- =====================================================
-- UPDATE COMMISSION TYPE CONSTRAINT
-- =====================================================

ALTER TABLE referral_commissions 
  DROP CONSTRAINT IF EXISTS referral_commissions_commission_type_check;

ALTER TABLE referral_commissions 
  ADD CONSTRAINT referral_commissions_commission_type_check 
  CHECK (commission_type IN ('trading', 'claim', 'signup_mining'));

-- =====================================================
-- COMMENTS
-- =====================================================

COMMENT ON FUNCTION link_referral IS 'Links a new user to their referrer using referral code. Creates referral record.';
COMMENT ON FUNCTION award_referral_mining_bonus IS 'Awards 1 AFX to upline when downline completes first mining claim';
COMMENT ON FUNCTION release_p2p_coins IS 'Releases coins from seller to buyer. Awards fixed 2 AFX referral commission to upline.';
COMMENT ON TRIGGER trigger_referral_mining_bonus ON coins IS 'Triggers 1 AFX reward to upline on first mining claim';

-- Add unique constraint to prevent duplicate referrals
ALTER TABLE referrals DROP CONSTRAINT IF EXISTS referrals_referrer_referred_unique;
ALTER TABLE referrals ADD CONSTRAINT referrals_referrer_referred_unique UNIQUE (referrer_id, referred_id);
