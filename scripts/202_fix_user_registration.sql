-- ============================================================================
-- FIX USER REGISTRATION - ENSURE PROFILE TRIGGER PROVIDES ALL REQUIRED FIELDS
-- ============================================================================

-- Drop and recreate the profile creation trigger with all required fields
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;

-- Create improved function that handles all required profile fields
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_username TEXT;
  v_referral_code TEXT;
BEGIN
  -- Generate username from email or metadata
  v_username := COALESCE(
    new.raw_user_meta_data->>'username',
    split_part(new.email, '@', 1)
  );
  
  -- Generate unique referral code (6 uppercase alphanumeric characters)
  v_referral_code := UPPER(
    SUBSTRING(MD5(RANDOM()::TEXT || new.id::TEXT) FROM 1 FOR 6)
  );
  
  -- Insert profile with all required fields and safe defaults
  INSERT INTO public.profiles (
    id,
    email,
    username,
    referral_code,
    country_code,
    country_name,
    currency_code,
    currency_symbol,
    role,
    is_admin,
    disabled,
    total_referrals,
    total_commission,
    rating,
    created_at,
    updated_at
  )
  VALUES (
    new.id,
    new.email,
    v_username,
    v_referral_code,
    'KE',                    -- Default to Kenya
    'Kenya',                 -- Default country name
    'KES',                   -- Default to Kenyan Shilling
    'KSh',                   -- Currency symbol
    'user',                  -- Default role
    false,                   -- Not admin by default
    false,                   -- Not disabled
    0,                       -- No referrals yet
    0,                       -- No commission yet
    0,                       -- No rating yet
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    username = EXCLUDED.username,
    updated_at = NOW();

  RETURN new;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't block user creation
    RAISE WARNING 'Error creating profile for user %: %', new.id, SQLERRM;
    RETURN new;
END;
$$;

-- Create the trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- ENSURE ALL PROFILES TABLE COLUMNS EXIST WITH PROPER DEFAULTS
-- ============================================================================

-- Add any missing columns to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS country_code VARCHAR(2) DEFAULT 'KE',
ADD COLUMN IF NOT EXISTS country_name VARCHAR(100) DEFAULT 'Kenya',
ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3) DEFAULT 'KES',
ADD COLUMN IF NOT EXISTS currency_symbol VARCHAR(10) DEFAULT 'KSh',
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user',
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS disabled BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS disabled_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS disabled_by UUID,
ADD COLUMN IF NOT EXISTS admin_note TEXT,
ADD COLUMN IF NOT EXISTS total_referrals INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_commission NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS rating NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_mine TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS next_mine TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS max_supply_limit NUMERIC,
ADD COLUMN IF NOT EXISTS avatar_url TEXT,
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS wallet_address TEXT,
ADD COLUMN IF NOT EXISTS referred_by UUID REFERENCES profiles(id),
ADD COLUMN IF NOT EXISTS buyer_id UUID,
ADD COLUMN IF NOT EXISTS seller_id UUID,
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Update existing profiles without referral codes
UPDATE profiles
SET referral_code = UPPER(SUBSTRING(MD5(RANDOM()::TEXT || id::TEXT) FROM 1 FOR 6))
WHERE referral_code IS NULL;

-- Update existing profiles without country info
UPDATE profiles
SET 
  country_code = 'KE',
  country_name = 'Kenya',
  currency_code = 'KES',
  currency_symbol = 'KSh'
WHERE country_code IS NULL;

-- Create index on referral_code for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_referral_code ON profiles(referral_code);

-- ============================================================================
-- ENSURE REFERRALS TABLE IS READY
-- ============================================================================

-- Make sure referrals table exists and has all required columns
CREATE TABLE IF NOT EXISTS referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  referred_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  referral_code TEXT NOT NULL,
  status TEXT DEFAULT 'active',
  signup_reward_given BOOLEAN DEFAULT false,
  first_mining_reward_given BOOLEAN DEFAULT false,
  total_trading_commission NUMERIC DEFAULT 0,
  total_claim_commission NUMERIC DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(referred_id)
);

-- Create indexes for referrals
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred ON referrals(referred_id);

-- ============================================================================
-- RECREATE link_referral FUNCTION
-- ============================================================================

DROP FUNCTION IF EXISTS link_referral(UUID, TEXT) CASCADE;

CREATE OR REPLACE FUNCTION link_referral(
  p_user_id UUID,
  p_referral_code TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_referrer_id UUID;
  v_already_linked BOOLEAN;
BEGIN
  -- Check if user already has a referrer
  SELECT EXISTS(
    SELECT 1 FROM referrals WHERE referred_id = p_user_id
  ) INTO v_already_linked;
  
  IF v_already_linked THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'User already linked to a referrer'
    );
  END IF;
  
  -- Find the referrer by code
  SELECT id INTO v_referrer_id
  FROM profiles
  WHERE referral_code = UPPER(p_referral_code)
    AND id != p_user_id;  -- Can't refer yourself
  
  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Invalid referral code'
    );
  END IF;
  
  -- Create referral link
  INSERT INTO referrals (
    referrer_id,
    referred_id,
    referral_code,
    status,
    created_at
  )
  VALUES (
    v_referrer_id,
    p_user_id,
    UPPER(p_referral_code),
    'active',
    NOW()
  );
  
  -- Update profile's referred_by field
  UPDATE profiles
  SET referred_by = v_referrer_id
  WHERE id = p_user_id;
  
  -- Increment referrer's total_referrals count
  UPDATE profiles
  SET total_referrals = total_referrals + 1
  WHERE id = v_referrer_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Referral linked successfully',
    'referrer_id', v_referrer_id
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION link_referral(UUID, TEXT) TO authenticated;

-- ============================================================================
-- ENSURE RLS POLICIES ARE CORRECT
-- ============================================================================

-- Enable RLS on profiles if not already enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies and recreate them
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
DROP POLICY IF EXISTS "Anyone can lookup referral codes" ON profiles;

-- Allow users to read their own profile
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- Allow system to insert profiles (for trigger)
CREATE POLICY "profiles_insert_own" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Allow anyone to lookup referral codes (needed for referral system)
CREATE POLICY "Anyone can lookup referral codes" ON profiles
  FOR SELECT USING (true);

COMMENT ON TABLE profiles IS 'User profiles with Kenya as default country, no geolocation tracking';
