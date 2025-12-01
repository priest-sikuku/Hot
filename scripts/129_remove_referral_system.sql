-- Remove all referral-related functionality from the system
-- This script safely removes referral tables, columns, and logic

-- Drop referral tables
DROP TABLE IF EXISTS public.referral_commissions CASCADE;
DROP TABLE IF EXISTS public.referrals CASCADE;

-- Remove referral columns from profiles table
ALTER TABLE public.profiles 
  DROP COLUMN IF EXISTS referral_code,
  DROP COLUMN IF EXISTS referred_by,
  DROP COLUMN IF EXISTS total_referrals,
  DROP COLUMN IF EXISTS total_commission;

-- Remove referral commission logic from trade functions
-- This will be handled by updating the trade completion functions in subsequent scripts

-- Clean up any referral-related indexes
DROP INDEX IF EXISTS idx_referral_commissions_referrer;
DROP INDEX IF EXISTS idx_referrals_referrer;
DROP INDEX IF EXISTS idx_referrals_referred;

-- Remove referral commission transactions
DELETE FROM public.transactions WHERE type = 'referral_commission';

COMMENT ON SCRIPT IS 'Removes all referral system functionality including tables, columns, and related data';
