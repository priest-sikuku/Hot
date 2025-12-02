-- Remove all referral and commission system
-- This script drops:
-- 1. Referral and referral_commissions tables
-- 2. Referral-related columns from profiles
-- 3. Related functions and triggers

-- Step 1: Drop dependent objects
DROP FUNCTION IF EXISTS compute_boosted_mining_rate(UUID) CASCADE;
DROP FUNCTION IF EXISTS add_claim_commission(UUID, NUMERIC, UUID) CASCADE;

-- Step 2: Drop referral tables
DROP TABLE IF EXISTS referral_commissions CASCADE;
DROP TABLE IF EXISTS referrals CASCADE;

-- Step 3: Remove referral columns from profiles
ALTER TABLE profiles DROP COLUMN IF EXISTS total_referrals;
ALTER TABLE profiles DROP COLUMN IF EXISTS total_commission;
ALTER TABLE profiles DROP COLUMN IF EXISTS referral_code;
ALTER TABLE profiles DROP COLUMN IF EXISTS referred_by;

-- Step 4: Drop referral-related functions if they exist
DROP FUNCTION IF EXISTS link_referral(text) CASCADE;
DROP FUNCTION IF EXISTS get_referral_status() CASCADE;

-- Step 5: Update mining config to remove referral-related settings
-- The mining system now works without referral boosts
-- Base rate remains constant: 0.25 AFX (or 0.15 after halving)

COMMIT;
