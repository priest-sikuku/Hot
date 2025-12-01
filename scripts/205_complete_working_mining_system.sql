-- Complete Mining System Repair with correct rewards
-- Current reward: 0.25 AFX
-- Post-halving reward: 0.15 AFX
-- Halving in 27 days from now

-- Step 1: Ensure mining_config table exists with correct structure
CREATE TABLE IF NOT EXISTS mining_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reward_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.25,
  post_halving_reward NUMERIC(10, 2) NOT NULL DEFAULT 0.15,
  interval_hours INTEGER NOT NULL DEFAULT 5,
  halving_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Step 2: Initialize mining config with halving in 27 days
INSERT INTO mining_config (id, reward_amount, post_halving_reward, interval_hours, halving_date, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  0.25,
  0.15,
  5,
  NOW() + INTERVAL '27 days',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  reward_amount = 0.25,
  post_halving_reward = 0.15,
  interval_hours = 5,
  halving_date = NOW() + INTERVAL '27 days',
  updated_at = NOW();

-- If no config exists at all, insert one
INSERT INTO mining_config (reward_amount, post_halving_reward, interval_hours, halving_date)
SELECT 0.25, 0.15, 5, NOW() + INTERVAL '27 days'
WHERE NOT EXISTS (SELECT 1 FROM mining_config LIMIT 1);

-- Step 3: Ensure global_supply table exists
CREATE TABLE IF NOT EXISTS global_supply (
  id INTEGER PRIMARY KEY DEFAULT 1,
  total_supply NUMERIC(20, 2) NOT NULL DEFAULT 21000000,
  mined_supply NUMERIC(20, 2) NOT NULL DEFAULT 0,
  remaining_supply NUMERIC(20, 2) NOT NULL DEFAULT 21000000,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Initialize global supply if not exists
INSERT INTO global_supply (id, total_supply, mined_supply, remaining_supply, updated_at)
VALUES (1, 21000000, 0, 21000000, NOW())
ON CONFLICT (id) DO NOTHING;

-- Step 4: Ensure profiles table has mining fields
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_mine TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS next_mine TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_referrals INTEGER DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_commission NUMERIC(10, 2) DEFAULT 0;

-- Set next_mine to NOW for all users so they can mine immediately
UPDATE profiles SET next_mine = NOW() WHERE next_mine IS NULL OR next_mine > NOW() + INTERVAL '1 year';

-- Step 5: Ensure referrals table has commission tracking
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS total_trading_commission NUMERIC(10, 2) DEFAULT 0;
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS total_claim_commission NUMERIC(10, 2) DEFAULT 0;
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS signup_reward_given BOOLEAN DEFAULT FALSE;
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS first_mining_reward_given BOOLEAN DEFAULT FALSE;

-- Step 6: Enable RLS on all tables
ALTER TABLE mining_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE global_supply ENABLE ROW LEVEL SECURITY;

-- Step 7: Create RLS policies for mining_config
DROP POLICY IF EXISTS "Anyone can read mining config" ON mining_config;
CREATE POLICY "Anyone can read mining config"
ON mining_config FOR SELECT
TO authenticated, anon
USING (true);

-- Step 8: Create RLS policies for global_supply
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

-- Step 9: Create RPC function to get current mining reward
CREATE OR REPLACE FUNCTION get_current_mining_reward()
RETURNS TABLE (
  reward_amount NUMERIC,
  interval_hours INTEGER,
  halving_date TIMESTAMPTZ,
  is_halved BOOLEAN
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  config RECORD;
  current_reward NUMERIC;
BEGIN
  -- Get mining config
  SELECT * INTO config FROM mining_config LIMIT 1;
  
  -- If no config, return defaults
  IF config IS NULL THEN
    RETURN QUERY SELECT 0.25::NUMERIC, 5, NULL::TIMESTAMPTZ, FALSE;
    RETURN;
  END IF;
  
  -- Check if halving has occurred
  IF config.halving_date IS NOT NULL AND NOW() >= config.halving_date THEN
    current_reward := config.post_halving_reward;
    
    -- Update the config to reflect halving has occurred
    UPDATE mining_config 
    SET reward_amount = post_halving_reward, 
        updated_at = NOW()
    WHERE id = config.id;
    
    RETURN QUERY SELECT config.post_halving_reward, config.interval_hours, config.halving_date, TRUE;
  ELSE
    RETURN QUERY SELECT config.reward_amount, config.interval_hours, config.halving_date, FALSE;
  END IF;
END;
$$;

-- Step 10: Create RPC function to compute boosted mining rate
CREATE OR REPLACE FUNCTION compute_boosted_mining_rate(p_user_id UUID)
RETURNS TABLE (
  base_rate NUMERIC,
  referral_count INTEGER,
  boost_percentage NUMERIC,
  final_rate NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_base_rate NUMERIC;
  v_referral_count INTEGER;
  v_boost_percentage NUMERIC;
  v_final_rate NUMERIC;
BEGIN
  -- Get current base rate from mining config
  SELECT reward_amount INTO v_base_rate FROM mining_config LIMIT 1;
  
  -- If no config, use default
  IF v_base_rate IS NULL THEN
    v_base_rate := 0.25;
  END IF;
  
  -- Count active referrals (users who have mined at least once)
  SELECT COUNT(*) INTO v_referral_count
  FROM referrals r
  INNER JOIN profiles p ON p.id = r.referred_id
  WHERE r.referrer_id = p_user_id
    AND r.status = 'active'
    AND p.last_mine IS NOT NULL;
  
  -- Calculate boost: 10% per referral
  v_boost_percentage := v_referral_count * 10;
  
  -- Calculate final rate with boost
  v_final_rate := v_base_rate * (1 + (v_boost_percentage / 100.0));
  
  RETURN QUERY SELECT v_base_rate, v_referral_count, v_boost_percentage, v_final_rate;
END;
$$;

-- Step 11: Create RPC function to deduct from global supply
CREATE OR REPLACE FUNCTION deduct_from_global_supply(mining_amount NUMERIC)
RETURNS TABLE (
  success BOOLEAN,
  remaining NUMERIC,
  message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_remaining NUMERIC;
  actual_amount NUMERIC;
BEGIN
  -- Get current remaining supply
  SELECT remaining_supply INTO current_remaining FROM global_supply WHERE id = 1;
  
  -- Check if enough supply is available
  IF current_remaining >= mining_amount THEN
    actual_amount := mining_amount;
  ELSIF current_remaining > 0 THEN
    actual_amount := current_remaining;
  ELSE
    RETURN QUERY SELECT FALSE, 0::NUMERIC, 'Global supply exhausted'::TEXT;
    RETURN;
  END IF;
  
  -- Deduct from supply
  UPDATE global_supply 
  SET mined_supply = mined_supply + actual_amount,
      remaining_supply = remaining_supply - actual_amount,
      updated_at = NOW()
  WHERE id = 1;
  
  RETURN QUERY SELECT TRUE, actual_amount, 'Success'::TEXT;
END;
$$;

-- Step 12: Create RPC function to add claim commission for referrers
CREATE OR REPLACE FUNCTION add_claim_commission(
  p_referred_id UUID,
  p_claim_amount NUMERIC,
  p_coin_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_referrer_id UUID;
  v_commission_amount NUMERIC;
BEGIN
  -- Get the referrer
  SELECT referrer_id INTO v_referrer_id
  FROM referrals
  WHERE referred_id = p_referred_id AND status = 'active'
  LIMIT 1;
  
  -- If no referrer, exit
  IF v_referrer_id IS NULL THEN
    RETURN;
  END IF;
  
  -- Calculate 5% commission
  v_commission_amount := p_claim_amount * 0.05;
  
  -- Add commission to referrer's balance
  INSERT INTO coins (user_id, amount, claim_type, status, created_at, updated_at)
  VALUES (v_referrer_id, v_commission_amount, 'referral_commission', 'available', NOW(), NOW());
  
  -- Update referral record
  UPDATE referrals
  SET total_claim_commission = COALESCE(total_claim_commission, 0) + v_commission_amount,
      updated_at = NOW()
  WHERE referrer_id = v_referrer_id AND referred_id = p_referred_id;
  
  -- Update referrer profile
  UPDATE profiles
  SET total_commission = COALESCE(total_commission, 0) + v_commission_amount,
      updated_at = NOW()
  WHERE id = v_referrer_id;
END;
$$;

-- Step 13: Grant execute permissions on RPC functions
GRANT EXECUTE ON FUNCTION get_current_mining_reward() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION compute_boosted_mining_rate(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION deduct_from_global_supply(NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION add_claim_commission(UUID, NUMERIC, UUID) TO authenticated;
