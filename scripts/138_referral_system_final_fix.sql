-- =====================================================
-- COMPLETE REFERRAL SYSTEM REPAIR - FINAL VERSION
-- =====================================================
-- This script ensures the referral system works end-to-end:
-- 1. Auto-detect referral code from signup URL
-- 2. Track upline/downline relationships
-- 3. Award 1 AFX when downline completes first mining
-- 4. Award 2 AFX when downline completes P2P trade
-- 5. Prevent self-referral and duplicate rewards
-- =====================================================

-- =====================================================
-- STEP 1: ENSURE DATABASE SCHEMA
-- =====================================================

-- Profiles table - referral tracking columns
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referred_by UUID REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_referrals INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_commission NUMERIC DEFAULT 0;

-- Referrals table - reward tracking
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'referrals' AND schemaname = 'public') THEN
    CREATE TABLE referrals (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      referrer_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
      referred_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
      referral_code TEXT,
      status TEXT DEFAULT 'active',
      first_mining_reward_given BOOLEAN DEFAULT FALSE,
      signup_reward_given BOOLEAN DEFAULT FALSE,
      total_trading_commission NUMERIC DEFAULT 0,
      total_claim_commission NUMERIC DEFAULT 0,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      UNIQUE(referrer_id, referred_id)
    );
  ELSE
    ALTER TABLE referrals ADD COLUMN IF NOT EXISTS first_mining_reward_given BOOLEAN DEFAULT FALSE;
    ALTER TABLE referrals ADD COLUMN IF NOT EXISTS signup_reward_given BOOLEAN DEFAULT FALSE;
    ALTER TABLE referrals ADD COLUMN IF NOT EXISTS total_trading_commission NUMERIC DEFAULT 0;
    ALTER TABLE referrals ADD COLUMN IF NOT EXISTS total_claim_commission NUMERIC DEFAULT 0;
  END IF;
END $$;

-- Referral commissions table
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'referral_commissions' AND schemaname = 'public') THEN
    CREATE TABLE referral_commissions (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      referrer_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
      referred_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
      amount NUMERIC NOT NULL,
      commission_type TEXT NOT NULL CHECK (commission_type IN ('trading', 'claim', 'signup_mining')),
      source_id UUID,
      status TEXT DEFAULT 'completed',
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );
  ELSE
    -- Update commission types if needed
    ALTER TABLE referral_commissions DROP CONSTRAINT IF EXISTS referral_commissions_commission_type_check;
    ALTER TABLE referral_commissions 
      ADD CONSTRAINT referral_commissions_commission_type_check 
      CHECK (commission_type IN ('trading', 'claim', 'signup_mining'));
  END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_profiles_referral_code ON profiles(referral_code);
CREATE INDEX IF NOT EXISTS idx_profiles_referred_by ON profiles(referred_by);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred ON referrals(referred_id);
CREATE INDEX IF NOT EXISTS idx_referral_commissions_referrer ON referral_commissions(referrer_id);

-- =====================================================
-- STEP 2: REFERRAL CODE GENERATION
-- =====================================================

CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_code TEXT;
  v_exists BOOLEAN;
  v_counter INTEGER := 0;
BEGIN
  LOOP
    -- Generate 8-character uppercase alphanumeric code
    v_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || CLOCK_TIMESTAMP()::TEXT) FROM 1 FOR 8));
    
    -- Check if code exists
    SELECT EXISTS(SELECT 1 FROM profiles WHERE referral_code = v_code) INTO v_exists;
    
    EXIT WHEN NOT v_exists;
    
    v_counter := v_counter + 1;
    IF v_counter > 10 THEN
      RAISE EXCEPTION 'Failed to generate unique referral code after 10 attempts';
    END IF;
  END LOOP;
  
  RETURN v_code;
END;
$$;

-- Auto-generate referral code on profile creation
CREATE OR REPLACE FUNCTION auto_generate_referral_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.referral_code IS NULL OR NEW.referral_code = '' THEN
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

-- Backfill referral codes for existing users
UPDATE profiles 
SET referral_code = generate_referral_code()
WHERE referral_code IS NULL OR referral_code = '';

-- =====================================================
-- STEP 3: LINK REFERRAL ON SIGNUP
-- =====================================================

CREATE OR REPLACE FUNCTION link_referral(
  p_user_id UUID,
  p_referral_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_referrer_id UUID;
  v_result JSONB;
BEGIN
  -- Input validation
  IF p_referral_code IS NULL OR TRIM(p_referral_code) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Referral code is required');
  END IF;
  
  -- Find referrer by code (case-insensitive)
  SELECT id INTO v_referrer_id
  FROM profiles
  WHERE UPPER(referral_code) = UPPER(TRIM(p_referral_code));
  
  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid referral code');
  END IF;
  
  -- Prevent self-referral
  IF v_referrer_id = p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot refer yourself');
  END IF;
  
  -- Check if user already has a referrer
  IF EXISTS (SELECT 1 FROM profiles WHERE id = p_user_id AND referred_by IS NOT NULL) THEN
    RETURN jsonb_build_object('success', false, 'error', 'User already has a referrer');
  END IF;
  
  -- Update user's referred_by
  UPDATE profiles
  SET referred_by = v_referrer_id,
      updated_at = NOW()
  WHERE id = p_user_id;
  
  -- Increment referrer's total_referrals
  UPDATE profiles
  SET total_referrals = COALESCE(total_referrals, 0) + 1,
      updated_at = NOW()
  WHERE id = v_referrer_id;
  
  -- Create referral record
  INSERT INTO referrals (
    referrer_id, 
    referred_id, 
    referral_code,
    status, 
    first_mining_reward_given,
    signup_reward_given
  )
  VALUES (
    v_referrer_id, 
    p_user_id, 
    UPPER(TRIM(p_referral_code)),
    'active',
    FALSE,
    FALSE
  )
  ON CONFLICT (referrer_id, referred_id) 
  DO UPDATE SET 
    status = 'active',
    updated_at = NOW();
  
  -- Return success with referrer info
  v_result := jsonb_build_object(
    'success', true,
    'referrer_id', v_referrer_id,
    'referred_id', p_user_id,
    'message', 'Referral linked successfully'
  );
  
  RAISE NOTICE 'Referral linked: User % referred by % (code: %)', p_user_id, v_referrer_id, p_referral_code;
  
  RETURN v_result;
END;
$$;

-- =====================================================
-- STEP 4: AWARD 1 AFX ON FIRST MINING COMPLETION
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
  -- Only process mining claims
  IF NEW.claim_type IS NULL OR NEW.claim_type != 'mining' THEN
    RETURN NEW;
  END IF;
  
  -- Get the user's referrer
  SELECT referred_by INTO v_referrer_id
  FROM profiles
  WHERE id = NEW.user_id;
  
  -- No referrer, skip
  IF v_referrer_id IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Check if reward already given
  SELECT first_mining_reward_given INTO v_already_rewarded
  FROM referrals
  WHERE referrer_id = v_referrer_id AND referred_id = NEW.user_id;
  
  -- Already rewarded, skip
  IF v_already_rewarded IS TRUE THEN
    RETURN NEW;
  END IF;
  
  -- Award 1 AFX to referrer's P2P balance (trade_coins)
  INSERT INTO trade_coins (user_id, amount, status, source, reference_id, created_at)
  VALUES (v_referrer_id, v_reward_amount, 'available', 'referral_commission', NEW.id, NOW());
  
  -- Record the commission
  INSERT INTO referral_commissions (
    referrer_id, 
    referred_id, 
    amount, 
    commission_type, 
    source_id, 
    status,
    created_at
  ) VALUES (
    v_referrer_id, 
    NEW.user_id, 
    v_reward_amount, 
    'signup_mining', 
    NEW.id, 
    'completed',
    NOW()
  );
  
  -- Mark as rewarded in referrals table
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
  
  -- Create transaction record for transparency
  INSERT INTO transactions (user_id, type, amount, description, related_id, status, created_at)
  VALUES (
    v_referrer_id, 
    'referral_commission', 
    v_reward_amount, 
    format('Referral bonus: %s AFX (downline completed first mining)', v_reward_amount), 
    NEW.user_id, 
    'completed',
    NOW()
  );
  
  RAISE NOTICE 'Awarded % AFX mining bonus to referrer % for user %', v_reward_amount, v_referrer_id, NEW.user_id;
  
  RETURN NEW;
END;
$$;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS trigger_referral_mining_bonus ON coins;
CREATE TRIGGER trigger_referral_mining_bonus
  AFTER INSERT ON coins
  FOR EACH ROW
  WHEN (NEW.claim_type = 'mining')
  EXECUTE FUNCTION award_referral_mining_bonus();

-- =====================================================
-- STEP 5: AWARD 2 AFX ON P2P TRADE COMPLETION
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
  v_commission_amount NUMERIC := 2.0; -- Fixed 2 AFX per trade
  v_escrow_record RECORD;
  v_seller_coin_id UUID;
BEGIN
  -- Get trade details
  SELECT * INTO v_trade
  FROM p2p_trades
  WHERE id = p_trade_id AND seller_id = p_seller_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trade not found or you are not the seller';
  END IF;

  -- Validate trade state
  IF v_trade.is_paid IS NOT TRUE THEN
    RAISE EXCEPTION 'Buyer must mark payment as sent before you can release coins';
  END IF;

  IF v_trade.status NOT IN ('payment_sent', 'escrowed', 'pending') THEN
    RAISE EXCEPTION 'Trade is not in a state to release coins. Current status: %', v_trade.status;
  END IF;

  -- Update trade status to completed
  UPDATE p2p_trades
  SET 
    status = 'completed',
    released_at = NOW(),
    coins_released_at = NOW(),
    updated_at = NOW()
  WHERE id = p_trade_id;

  -- Try to transfer locked coins first
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

  -- If no locked coins, deduct from available balance
  IF NOT FOUND THEN
    -- Find seller's coin record with sufficient balance
    SELECT id INTO v_seller_coin_id
    FROM trade_coins
    WHERE user_id = v_trade.seller_id 
      AND status = 'available'
      AND amount >= v_trade.afx_amount
    ORDER BY created_at ASC
    LIMIT 1
    FOR UPDATE;
    
    IF v_seller_coin_id IS NULL THEN
      RAISE EXCEPTION 'Seller has insufficient available balance';
    END IF;
    
    -- Deduct from seller
    UPDATE trade_coins
    SET amount = amount - v_trade.afx_amount,
        updated_at = NOW()
    WHERE id = v_seller_coin_id;

    -- Credit buyer
    INSERT INTO trade_coins (user_id, amount, status, source, reference_id, created_at)
    VALUES (v_trade.buyer_id, v_trade.afx_amount, 'available', 'p2p_trade', p_trade_id, NOW());
  END IF;

  -- Log the release action
  INSERT INTO trade_logs (trade_id, user_id, action, amount, details, timestamp)
  VALUES (
    p_trade_id, 
    p_seller_id, 
    'coins_released', 
    v_trade.afx_amount,
    jsonb_build_object('buyer_id', v_trade.buyer_id, 'timestamp', NOW()),
    NOW()
  );

  -- Record transactions
  INSERT INTO transactions (user_id, type, amount, description, related_id, status, created_at)
  VALUES 
    (v_trade.buyer_id, 'p2p_buy', v_trade.afx_amount, 'Received AFX from P2P trade', p_trade_id, 'completed', NOW()),
    (v_trade.seller_id, 'p2p_sell', -v_trade.afx_amount, 'Sold AFX in P2P trade', p_trade_id, 'completed', NOW());

  -- Process 2 AFX referral commission for buyer's upline
  SELECT referred_by INTO v_buyer_referrer
  FROM profiles
  WHERE id = v_trade.buyer_id;

  IF v_buyer_referrer IS NOT NULL THEN
    -- Credit 2 AFX to referrer's P2P balance
    INSERT INTO trade_coins (user_id, amount, status, source, reference_id, created_at)
    VALUES (v_buyer_referrer, v_commission_amount, 'available', 'referral_commission', p_trade_id, NOW());
    
    -- Record commission
    INSERT INTO referral_commissions (
      referrer_id, 
      referred_id, 
      amount, 
      commission_type, 
      source_id, 
      status,
      created_at
    ) VALUES (
      v_buyer_referrer, 
      v_trade.buyer_id, 
      v_commission_amount, 
      'trading', 
      p_trade_id, 
      'completed',
      NOW()
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
    INSERT INTO transactions (user_id, type, amount, description, related_id, status, created_at)
    VALUES (
      v_buyer_referrer, 
      'referral_commission', 
      v_commission_amount, 
      format('Referral P2P trade bonus: %s AFX', v_commission_amount), 
      p_trade_id, 
      'completed',
      NOW()
    );
    
    RAISE NOTICE 'Awarded % AFX P2P commission to referrer % for user % trade %', v_commission_amount, v_buyer_referrer, v_trade.buyer_id, p_trade_id;
  END IF;
  
  RAISE NOTICE 'Trade % completed successfully', p_trade_id;
END;
$$;

-- =====================================================
-- STEP 6: PERMISSIONS AND POLICIES
-- =====================================================

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION generate_referral_code() TO authenticated;
GRANT EXECUTE ON FUNCTION auto_generate_referral_code() TO authenticated;
GRANT EXECUTE ON FUNCTION link_referral(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION award_referral_mining_bonus() TO authenticated;
GRANT EXECUTE ON FUNCTION release_p2p_coins(UUID, UUID) TO authenticated;

-- RLS policies for referral code lookup (needed for signup page)
DROP POLICY IF EXISTS "Anyone can lookup referral codes" ON profiles;
CREATE POLICY "Anyone can lookup referral codes" ON profiles
  FOR SELECT
  USING (referral_code IS NOT NULL);

-- RLS for referrals table
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'referrals' AND policyname = 'Users can view their own referrals'
  ) THEN
    CREATE POLICY "Users can view their own referrals" ON referrals
      FOR SELECT
      USING (referrer_id = auth.uid() OR referred_id = auth.uid());
  END IF;
END $$;

-- =====================================================
-- STEP 7: COMMENTS AND DOCUMENTATION
-- =====================================================

COMMENT ON FUNCTION link_referral IS 'Links new user to referrer using referral code. Validates against self-referral and duplicates.';
COMMENT ON FUNCTION award_referral_mining_bonus IS 'Awards 1 AFX to upline when downline completes their first mining claim';
COMMENT ON FUNCTION release_p2p_coins IS 'Releases coins from seller to buyer. Awards fixed 2 AFX referral commission to buyer upline.';
COMMENT ON TRIGGER trigger_referral_mining_bonus ON coins IS 'Automatically triggers 1 AFX reward to upline on downline first mining';
COMMENT ON TABLE referrals IS 'Tracks referral relationships and reward status between users';
COMMENT ON TABLE referral_commissions IS 'Records all referral commission payments with type and source';

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Verify all required columns exist
DO $$
BEGIN
  -- Check profiles columns
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'referral_code') THEN
    RAISE EXCEPTION 'Column profiles.referral_code is missing!';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'referred_by') THEN
    RAISE EXCEPTION 'Column profiles.referred_by is missing!';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'total_referrals') THEN
    RAISE EXCEPTION 'Column profiles.total_referrals is missing!';
  END IF;
  
  -- Check referrals table
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'referrals') THEN
    RAISE EXCEPTION 'Table referrals is missing!';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'referrals' AND column_name = 'first_mining_reward_given') THEN
    RAISE EXCEPTION 'Column referrals.first_mining_reward_given is missing!';
  END IF;
  
  RAISE NOTICE 'Referral system verification passed!';
END $$;
