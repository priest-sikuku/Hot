-- ============================================
-- COMPLETE MINING SYSTEM REPAIR
-- Ensures mining rewards work: 0.25 AFX now, 0.15 AFX after halving in 27 days
-- ============================================

-- Drop existing functions to avoid conflicts
DROP FUNCTION IF EXISTS get_current_mining_reward() CASCADE;
DROP FUNCTION IF EXISTS compute_boosted_mining_rate(uuid) CASCADE;
DROP FUNCTION IF EXISTS deduct_from_global_supply(numeric) CASCADE;
DROP FUNCTION IF EXISTS add_claim_commission(uuid, numeric, uuid) CASCADE;

-- Ensure mining_config table exists with correct structure
CREATE TABLE IF NOT EXISTS mining_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reward_amount NUMERIC NOT NULL DEFAULT 0.25,
    post_halving_reward NUMERIC NOT NULL DEFAULT 0.15,
    interval_hours INTEGER NOT NULL DEFAULT 5,
    halving_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Initialize mining config with halving date 27 days from now
INSERT INTO mining_config (reward_amount, post_halving_reward, interval_hours, halving_date)
VALUES (0.25, 0.15, 5, NOW() + INTERVAL '27 days')
ON CONFLICT (id) DO UPDATE SET
    reward_amount = EXCLUDED.reward_amount,
    post_halving_reward = EXCLUDED.post_halving_reward,
    halving_date = EXCLUDED.halving_date,
    updated_at = NOW();

-- Ensure global_supply table exists
CREATE TABLE IF NOT EXISTS global_supply (
    id INTEGER PRIMARY KEY DEFAULT 1,
    total_supply NUMERIC NOT NULL DEFAULT 21000000,
    mined_supply NUMERIC NOT NULL DEFAULT 0,
    remaining_supply NUMERIC NOT NULL DEFAULT 21000000,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Initialize global supply
INSERT INTO global_supply (id, total_supply, mined_supply, remaining_supply)
VALUES (1, 21000000, 0, 21000000)
ON CONFLICT (id) DO NOTHING;

-- Ensure profiles has mining fields
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS last_mine TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS next_mine TIMESTAMP WITH TIME ZONE;

-- Set next_mine to NOW for users who have never mined (allows immediate first claim)
UPDATE profiles 
SET next_mine = NOW() 
WHERE next_mine IS NULL;

-- Ensure referrals has commission tracking columns
ALTER TABLE referrals
ADD COLUMN IF NOT EXISTS total_claim_commission NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_trading_commission NUMERIC DEFAULT 0;

-- ============================================
-- RPC FUNCTION 1: Get Current Mining Reward
-- Returns current reward based on whether halving has occurred
-- ============================================
CREATE OR REPLACE FUNCTION get_current_mining_reward()
RETURNS TABLE (
    reward_amount NUMERIC,
    interval_hours INTEGER,
    halving_date TIMESTAMP WITH TIME ZONE,
    is_halved BOOLEAN
) AS $$
DECLARE
    config_row mining_config%ROWTYPE;
    has_halved BOOLEAN;
BEGIN
    SELECT * INTO config_row FROM mining_config LIMIT 1;
    
    -- Check if halving has occurred
    has_halved := (config_row.halving_date IS NOT NULL AND NOW() >= config_row.halving_date);
    
    -- If halving occurred, automatically update reward_amount to post_halving_reward
    IF has_halved AND config_row.reward_amount != config_row.post_halving_reward THEN
        UPDATE mining_config 
        SET reward_amount = post_halving_reward,
            updated_at = NOW();
        
        config_row.reward_amount := config_row.post_halving_reward;
    END IF;
    
    RETURN QUERY SELECT 
        config_row.reward_amount,
        config_row.interval_hours,
        config_row.halving_date,
        has_halved;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- RPC FUNCTION 2: Compute Boosted Mining Rate
-- Calculates final mining reward with 10% boost per active referral
-- ============================================
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
    v_is_halved BOOLEAN;
BEGIN
    -- Get current mining reward (automatically accounts for halving)
    SELECT r.reward_amount, r.is_halved INTO v_base_rate, v_is_halved
    FROM get_current_mining_reward() r;
    
    -- Count active referrals for this user
    SELECT COUNT(*) INTO v_referral_count
    FROM referrals
    WHERE referrer_id = p_user_id 
    AND status = 'active';
    
    -- Calculate boost (10% per referral, max 100%)
    v_boost_percentage := LEAST(v_referral_count * 10, 100);
    
    -- Calculate final rate with boost
    v_final_rate := v_base_rate * (1 + (v_boost_percentage / 100.0));
    
    RETURN QUERY SELECT 
        v_base_rate,
        v_referral_count,
        v_boost_percentage,
        v_final_rate;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- RPC FUNCTION 3: Deduct from Global Supply
-- Ensures mining doesn't exceed remaining supply
-- ============================================
CREATE OR REPLACE FUNCTION deduct_from_global_supply(mining_amount NUMERIC)
RETURNS TABLE (
    success BOOLEAN,
    remaining NUMERIC,
    message TEXT
) AS $$
DECLARE
    current_remaining NUMERIC;
    actual_amount NUMERIC;
BEGIN
    -- Get current remaining supply
    SELECT remaining_supply INTO current_remaining
    FROM global_supply
    WHERE id = 1
    FOR UPDATE;
    
    -- Check if enough supply remains
    IF current_remaining <= 0 THEN
        RETURN QUERY SELECT FALSE, 0::NUMERIC, 'Global supply exhausted'::TEXT;
        RETURN;
    END IF;
    
    -- Calculate actual amount to mine (cap at remaining)
    actual_amount := LEAST(mining_amount, current_remaining);
    
    -- Deduct from supply
    UPDATE global_supply
    SET 
        mined_supply = mined_supply + actual_amount,
        remaining_supply = remaining_supply - actual_amount,
        updated_at = NOW()
    WHERE id = 1;
    
    RETURN QUERY SELECT TRUE, actual_amount, 'Success'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- RPC FUNCTION 4: Add Claim Commission
-- Gives 10% commission to referrer when referred user claims mining
-- ============================================
CREATE OR REPLACE FUNCTION add_claim_commission(
    p_referred_id UUID,
    p_claim_amount NUMERIC,
    p_coin_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_referrer_id UUID;
    v_commission_amount NUMERIC;
BEGIN
    -- Find the referrer
    SELECT referrer_id INTO v_referrer_id
    FROM referrals
    WHERE referred_id = p_referred_id 
    AND status = 'active'
    LIMIT 1;
    
    -- If no referrer, exit
    IF v_referrer_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Calculate 10% commission
    v_commission_amount := p_claim_amount * 0.10;
    
    -- Add commission to referrer's balance
    INSERT INTO coins (user_id, amount, claim_type, status, created_at, updated_at)
    VALUES (v_referrer_id, v_commission_amount, 'referral_commission', 'available', NOW(), NOW());
    
    -- Track commission in referrals table
    UPDATE referrals
    SET 
        total_claim_commission = COALESCE(total_claim_commission, 0) + v_commission_amount,
        updated_at = NOW()
    WHERE referrer_id = v_referrer_id 
    AND referred_id = p_referred_id;
    
    -- Create commission record
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
        p_referred_id,
        v_commission_amount,
        'mining_claim',
        p_coin_id,
        'completed',
        NOW()
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- RLS POLICIES
-- ============================================
ALTER TABLE mining_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE global_supply ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read mining config" ON mining_config;
CREATE POLICY "Anyone can read mining config" ON mining_config FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can view global supply" ON global_supply;
CREATE POLICY "Anyone can view global supply" ON global_supply FOR SELECT USING (true);

-- ============================================
-- GRANT PERMISSIONS
-- ============================================
GRANT EXECUTE ON FUNCTION get_current_mining_reward() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION compute_boosted_mining_rate(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION deduct_from_global_supply(NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION add_claim_commission(UUID, NUMERIC, UUID) TO authenticated;

GRANT SELECT ON mining_config TO authenticated, anon;
GRANT SELECT ON global_supply TO authenticated, anon;
GRANT UPDATE ON global_supply TO authenticated;
GRANT UPDATE ON mining_config TO authenticated;

-- ============================================
-- VERIFICATION
-- ============================================
DO $$
DECLARE
    config_record RECORD;
    supply_record RECORD;
BEGIN
    -- Verify mining config
    SELECT * INTO config_record FROM mining_config LIMIT 1;
    RAISE NOTICE 'Mining Config: reward=%, halving_date=%, interval=%hrs', 
        config_record.reward_amount, 
        config_record.halving_date,
        config_record.interval_hours;
    
    -- Verify global supply
    SELECT * INTO supply_record FROM global_supply WHERE id = 1;
    RAISE NOTICE 'Global Supply: total=%, remaining=%', 
        supply_record.total_supply,
        supply_record.remaining_supply;
    
    RAISE NOTICE '✓ Mining system fully configured and operational!';
END $$;
