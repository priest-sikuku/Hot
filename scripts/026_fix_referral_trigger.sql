-- Fix the referral trigger to work properly
-- Drop existing trigger and function
DROP TRIGGER IF EXISTS on_referral_signup ON profiles;
DROP FUNCTION IF EXISTS update_referral_count();

-- Create improved function to update referral count
CREATE OR REPLACE FUNCTION update_referral_count()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update if referred_by is set and this is a new insert or the referred_by changed
  IF NEW.referred_by IS NOT NULL AND (TG_OP = 'INSERT' OR OLD.referred_by IS DISTINCT FROM NEW.referred_by) THEN
    -- Update the referrer's total_referrals count
    UPDATE profiles 
    SET total_referrals = (
      SELECT COUNT(*) 
      FROM profiles 
      WHERE referred_by = NEW.referred_by
    )
    WHERE id = NEW.referred_by;
    
    -- Log the update
    RAISE NOTICE 'Updated referral count for user %', NEW.referred_by;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for both INSERT and UPDATE
CREATE TRIGGER on_referral_signup
  AFTER INSERT OR UPDATE OF referred_by ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_referral_count();

-- Backfill existing referral counts
UPDATE profiles p
SET total_referrals = (
  SELECT COUNT(*) 
  FROM profiles 
  WHERE referred_by = p.id
)
WHERE EXISTS (
  SELECT 1 
  FROM profiles 
  WHERE referred_by = p.id
);

-- Add comment
COMMENT ON FUNCTION update_referral_count() IS 'Automatically updates referrer total_referrals count when a new user signs up with a referral code';
