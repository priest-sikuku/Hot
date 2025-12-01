-- Adding comprehensive mining system removal including new tables and functions
-- Remove all mining-related functionality from the database

-- Drop mining-related triggers first
DROP TRIGGER IF EXISTS on_mine_update_supply ON public.coins;

-- Drop ALL mining-related functions
DROP FUNCTION IF EXISTS update_supply_on_mine();
DROP FUNCTION IF EXISTS validate_mining_claim(UUID);
DROP FUNCTION IF EXISTS process_mining_claim(UUID, NUMERIC);
DROP FUNCTION IF EXISTS get_mining_status(UUID);
DROP FUNCTION IF EXISTS get_current_mining_reward();
DROP FUNCTION IF EXISTS compute_boosted_mining_rate(UUID);
DROP FUNCTION IF EXISTS deduct_from_global_supply(NUMERIC);
DROP FUNCTION IF EXISTS add_claim_commission(UUID, NUMERIC, UUID);
DROP FUNCTION IF EXISTS process_referral_commission_on_mining();

-- Drop ALL mining-related tables
DROP TABLE IF EXISTS public.supply_tracking CASCADE;
DROP TABLE IF EXISTS public.mining_config CASCADE;
DROP TABLE IF EXISTS public.global_supply CASCADE;

-- Remove mining-related columns from profiles table
ALTER TABLE public.profiles
DROP COLUMN IF EXISTS last_mined_at,
DROP COLUMN IF EXISTS next_mine_at,
DROP COLUMN IF EXISTS total_mined,
DROP COLUMN IF EXISTS mining_streak,
DROP COLUMN IF EXISTS last_claim_time,
DROP COLUMN IF EXISTS next_claim_time,
DROP COLUMN IF EXISTS last_mine,
DROP COLUMN IF EXISTS next_mine,
DROP COLUMN IF EXISTS total_commission;

-- Remove mining commission columns from referrals
ALTER TABLE public.referrals
DROP COLUMN IF EXISTS total_claim_commission,
DROP COLUMN IF EXISTS first_mining_reward_given;

-- Remove mining-related indexes
DROP INDEX IF EXISTS idx_profiles_next_claim_time;
DROP INDEX IF EXISTS idx_profiles_last_claim_time;

-- Delete mining transactions from transactions table
DELETE FROM public.transactions WHERE type = 'mining';

-- Delete mining coins from coins table
DELETE FROM public.coins WHERE claim_type = 'mining';

-- Update any remaining coins with claim_type 'mining' to 'claim'
UPDATE public.coins SET claim_type = 'claim' WHERE claim_type = 'mining';
