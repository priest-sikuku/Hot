-- Comprehensive Mining System Repair
-- This script ensures all tables, columns, functions, and data exist for mining to work

-- Step 1: Ensure profiles table has mining fields
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS last_mine TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS next_mine TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS total_referrals INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS referral_code TEXT,
ADD COLUMN IF NOT EXISTS referred_by UUID REFERENCES profiles(id);

-- Create index for mining queries
CREATE INDEX IF NOT EXISTS idx_profiles_mining ON profiles(next_mine);
CREATE INDEX IF NOT EXISTS idx_profiles_referral_code ON profiles(referral_code);

-- Initialize next_mine for existing users who haven't mined yet
UPDATE profiles
SET next_mine = NOW()
WHERE next_mine IS NULL;

-- Step 2: Ensure mining_config table exists with data
CREATE TABLE IF NOT EXISTS mining_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reward_amount NUMERIC NOT NULL DEFAULT 0.15,
  interval_hours INTEGER NOT NULL DEFAULT 5,
  halving_date TIMESTAMP WITH TIME ZONE,
  post_halving_reward NUMERIC DEFAULT 0.075,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert default mining config if not exists
INSERT INTO mining_config (reward_amount, interval_hours, post_halving_reward)
VALUES (0.15, 5, 0.075)
ON CONFLICT (id) DO NOTHING;

-- Ensure at least one config exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM mining_config LIMIT 1) THEN
    INSERT INTO mining_config (reward_amount, interval_hours, post_halving_reward)
    VALUES (0.15, 5, 0.075);
  END IF;
END $$;

-- Step 3: Ensure global_supply table exists
CREATE TABLE IF NOT EXISTS global_supply (
  id INTEGER PRIMARY KEY DEFAULT 1,
  total_supply NUMERIC NOT NULL DEFAULT 21000000,
  remaining_supply NUMERIC NOT NULL DEFAULT 21000000,
  mined_supply NUMERIC NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT chk_single_row CHECK (id = 1)
);

-- Initialize global supply if not exists
INSERT INTO global_supply (id, total_supply, remaining_supply, mined_supply)
VALUES (1, 21000000, 21000000, 0)
ON CONFLICT (id) DO NOTHING;

-- Step 4: Ensure coins table exists
CREATE TABLE IF NOT EXISTS coins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL DEFAULT 0,
  claim_type TEXT NOT NULL DEFAULT 'mining',
  status TEXT NOT NULL DEFAULT 'available',
  locked_until TIMESTAMP WITH TIME ZONE,
  lock_period_days INTEGER,
  bonus_percentage NUMERIC DEFAULT 0,
  max_supply NUMERIC,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for coins table
CREATE INDEX IF NOT EXISTS idx_coins_user_id ON coins(user_id);
CREATE INDEX IF NOT EXISTS idx_coins_status ON coins(status);
CREATE INDEX IF NOT EXISTS idx_coins_claim_type ON coins(claim_type);

-- Step 5: Ensure referrals table has required columns
ALTER TABLE referrals
ADD COLUMN IF NOT EXISTS total_claim_commission NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_trading_commission NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS signup_reward_given BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS first_mining_reward_given BOOLEAN DEFAULT FALSE;

-- Step 6: Enable RLS on all mining tables
ALTER TABLE mining_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE global_supply ENABLE ROW LEVEL SECURITY;
ALTER TABLE coins ENABLE ROW LEVEL SECURITY;

-- Step 7: Create RLS policies

-- Mining config policies
DROP POLICY IF EXISTS "Anyone can read mining config" ON mining_config;
CREATE POLICY "Anyone can read mining config"
ON mining_config FOR SELECT
TO authenticated, anon
USING (true);

-- Global supply policies
DROP POLICY IF EXISTS "Anyone can view global supply" ON global_supply;
CREATE POLICY "Anyone can view global supply"
ON global_supply FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Only system can update global supply" ON global_supply;
CREATE POLICY "Only system can update global supply"
ON global_supply FOR UPDATE
TO authenticated
USING (true);

-- Coins policies
DROP POLICY IF EXISTS "coins_select_own" ON coins;
CREATE POLICY "coins_select_own"
ON coins FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "coins_insert_own" ON coins;
CREATE POLICY "coins_insert_own"
ON coins FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "coins_update_own" ON coins;
CREATE POLICY "coins_update_own"
ON coins FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "coins_delete_own" ON coins;
CREATE POLICY "coins_delete_own"
ON coins FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Step 8: Recreate mining functions (drop first to avoid conflicts)

DROP FUNCTION IF EXISTS get_current_mining_reward() CASCADE;
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
    RETURN QUERY SELECT 0.15::NUMERIC, 5::INTEGER, NULL::TIMESTAMP WITH TIME ZONE, FALSE;
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

GRANT EXECUTE ON FUNCTION get_current_mining_reward() TO authenticated, anon;

DROP FUNCTION IF EXISTS compute_boosted_mining_rate(UUID) CASCADE;
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
  -- Get base mining rate
  SELECT reward_amount INTO v_base_rate
  FROM (SELECT * FROM get_current_mining_reward() LIMIT 1) AS config;
  
  IF v_base_rate IS NULL THEN
    v_base_rate := 0.15;
  END IF;
  
  -- Count active referrals who have mined at least once
  SELECT COUNT(*)
  INTO v_referral_count
  FROM referrals r
  INNER JOIN profiles p ON p.id = r.referred_id
  WHERE r.referrer_id = p_user_id
    AND r.status = 'active'
    AND p.last_mine IS NOT NULL;
  
  -- Calculate boost: 10% per referral, max 100%
  v_boost_percentage := LEAST(v_referral_count * 10, 100);
  v_final_rate := v_base_rate * (1 + v_boost_percentage / 100.0);
  
  RETURN QUERY SELECT 
    v_base_rate,
    v_referral_count,
    v_boost_percentage,
    v_final_rate;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION compute_boosted_mining_rate(UUID) TO authenticated;

DROP FUNCTION IF EXISTS deduct_from_global_supply(NUMERIC) CASCADE;
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
  -- Lock the row for update
  SELECT remaining_supply INTO v_remaining
  FROM global_supply
  WHERE id = 1
  FOR UPDATE;
  
  -- Initialize if missing
  IF v_remaining IS NULL THEN
    v_remaining := 21000000;
    INSERT INTO global_supply (id, total_supply, remaining_supply, mined_supply)
    VALUES (1, 21000000, 21000000, 0)
    ON CONFLICT (id) DO NOTHING;
  END IF;
  
  -- Check if supply exhausted
  IF v_remaining <= 0 THEN
    RETURN QUERY SELECT FALSE, 0::NUMERIC, 'Global supply exhausted'::TEXT;
    RETURN;
  END IF;
  
  -- Calculate actual amount (might be less than requested if supply low)
  v_actual_amount := LEAST(mining_amount, v_remaining);
  
  -- Deduct from supply
  UPDATE global_supply
  SET 
    remaining_supply = remaining_supply - v_actual_amount,
    mined_supply = mined_supply + v_actual_amount,
    updated_at = NOW()
  WHERE id = 1;
  
  RETURN QUERY SELECT TRUE, v_actual_amount, 'Supply deducted successfully'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION deduct_from_global_supply(NUMERIC) TO authenticated;

DROP FUNCTION IF EXISTS add_claim_commission(UUID, NUMERIC, UUID) CASCADE;
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
  -- Find referrer
  SELECT referrer_id INTO v_referrer_id
  FROM referrals
  WHERE referred_id = p_referred_id
    AND status = 'active';
  
  IF v_referrer_id IS NULL THEN
    RETURN;
  END IF;
  
  -- Calculate 10% commission
  v_commission_amount := p_claim_amount * 0.10;
  
  -- Add commission to referrer's trade_coins
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
  
  -- Update referrals table
  UPDATE referrals
  SET 
    total_claim_commission = COALESCE(total_claim_commission, 0) + v_commission_amount,
    updated_at = NOW()
  WHERE referrer_id = v_referrer_id
    AND referred_id = p_referred_id;
  
  -- Update referrer's profile
  UPDATE profiles
  SET 
    total_commission = COALESCE(total_commission, 0) + v_commission_amount,
    updated_at = NOW()
  WHERE id = v_referrer_id;
  
  -- Log commission
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

GRANT EXECUTE ON FUNCTION add_claim_commission(UUID, NUMERIC, UUID) TO authenticated;

-- Step 9: Ensure transactions table exists for logging
CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'completed',
  related_id UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at DESC);

-- Enable RLS on transactions
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "transactions_select_own" ON transactions;
CREATE POLICY "transactions_select_own"
ON transactions FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "transactions_insert_own" ON transactions;
CREATE POLICY "transactions_insert_own"
ON transactions FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Step 10: Verification query
DO $$
DECLARE
  mining_config_count INTEGER;
  global_supply_count INTEGER;
  function_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO mining_config_count FROM mining_config;
  SELECT COUNT(*) INTO global_supply_count FROM global_supply;
  
  SELECT COUNT(*) INTO function_count
  FROM pg_proc
  WHERE proname IN ('get_current_mining_reward', 'compute_boosted_mining_rate', 'deduct_from_global_supply', 'add_claim_commission');
  
  RAISE NOTICE 'Mining System Status:';
  RAISE NOTICE '  Mining Configs: %', mining_config_count;
  RAISE NOTICE '  Global Supply Records: %', global_supply_count;
  RAISE NOTICE '  Mining Functions: %', function_count;
  
  IF mining_config_count = 0 THEN
    RAISE WARNING 'No mining config found! Mining may not work.';
  END IF;
  
  IF global_supply_count = 0 THEN
    RAISE WARNING 'No global supply record found! Mining may not work.';
  END IF;
  
  IF function_count < 4 THEN
    RAISE WARNING 'Missing mining functions! Expected 4, found %', function_count;
  END IF;
END $$;

-- Success message
SELECT 'Mining system setup complete!' AS status;
