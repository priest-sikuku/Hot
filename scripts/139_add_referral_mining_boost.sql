-- Add referral-based mining boost system
-- This script adds helper functions to compute dynamic mining rates based on referral count
-- Formula: mining_rate = base_rate * (1 + (referral_count * 0.10))

-- Helper function to get user's referral count
CREATE OR REPLACE FUNCTION get_user_referral_count(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  -- Get total_referrals from profiles table
  SELECT COALESCE(total_referrals, 0)
  INTO v_count
  FROM profiles
  WHERE id = p_user_id;
  
  RETURN COALESCE(v_count, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to compute boosted mining rate
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
  v_boost_multiplier NUMERIC;
  v_final_rate NUMERIC;
  v_config RECORD;
  v_now TIMESTAMP WITH TIME ZONE := NOW();
BEGIN
  -- Get current mining config (with halving logic)
  SELECT * INTO v_config
  FROM mining_config
  ORDER BY created_at DESC
  LIMIT 1;
  
  -- Determine base rate based on halving event
  IF v_config.halving_date IS NOT NULL AND v_now >= v_config.halving_date THEN
    v_base_rate := v_config.post_halving_reward; -- 0.15 AFX after halving
  ELSE
    v_base_rate := v_config.reward_amount; -- 0.5 AFX before halving
  END IF;
  
  -- Get user's referral count
  v_referral_count := get_user_referral_count(p_user_id);
  
  -- Calculate boost: each referral = +10%
  -- Formula: final_rate = base_rate * (1 + (referral_count * 0.10))
  v_boost_multiplier := 1.0 + (v_referral_count * 0.10);
  v_final_rate := v_base_rate * v_boost_multiplier;
  
  -- Return breakdown
  RETURN QUERY SELECT 
    v_base_rate,
    v_referral_count,
    (v_referral_count * 10.0) AS boost_percentage,
    v_final_rate;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_user_referral_count IS 'Returns total number of referrals for a user';
COMMENT ON FUNCTION compute_boosted_mining_rate IS 'Computes mining rate with 10% boost per referral';
