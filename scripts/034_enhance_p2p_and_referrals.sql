-- Add price field to p2p_ads table with ±4% range validation
ALTER TABLE p2p_ads ADD COLUMN IF NOT EXISTS price_per_gx DECIMAL(10, 2);
ALTER TABLE p2p_ads ADD COLUMN IF NOT EXISTS remaining_amount DECIMAL(10, 2);

-- Update remaining_amount to match gx_amount for existing ads
UPDATE p2p_ads SET remaining_amount = gx_amount WHERE remaining_amount IS NULL;

-- Update existing ads with gx_amount < 50 to meet new minimum requirement
UPDATE p2p_ads SET gx_amount = 50, remaining_amount = 50 WHERE gx_amount < 50;

-- Add check constraint for minimum amounts
ALTER TABLE p2p_ads DROP CONSTRAINT IF EXISTS check_min_gx_amount;
ALTER TABLE p2p_ads ADD CONSTRAINT check_min_gx_amount CHECK (gx_amount >= 50);

-- Update existing trades with gx_amount < 2 to meet new minimum requirement
UPDATE p2p_trades SET gx_amount = 2 WHERE gx_amount < 2;

ALTER TABLE p2p_trades DROP CONSTRAINT IF EXISTS check_min_trade_amount;
ALTER TABLE p2p_trades ADD CONSTRAINT check_min_trade_amount CHECK (gx_amount >= 2);

-- Function to validate price is within ±4% of current GX price
CREATE OR REPLACE FUNCTION validate_p2p_price(ad_price DECIMAL, gx_price DECIMAL)
RETURNS BOOLEAN AS $$
DECLARE
  min_price DECIMAL;
  max_price DECIMAL;
BEGIN
  min_price := gx_price * 0.96; -- -4%
  max_price := gx_price * 1.04; -- +4%
  
  RETURN ad_price >= min_price AND ad_price <= max_price;
END;
$$ LANGUAGE plpgsql;

-- Update initiate_p2p_trade function to decrease remaining_amount on ad
CREATE OR REPLACE FUNCTION initiate_p2p_trade(
  p_ad_id UUID,
  p_buyer_id UUID,
  p_seller_id UUID,
  p_gx_amount DECIMAL
)
RETURNS UUID AS $$
DECLARE
  v_trade_id UUID;
  v_ad_remaining DECIMAL;
  v_seller_balance DECIMAL;
BEGIN
  -- Check minimum trade amount
  IF p_gx_amount < 2 THEN
    RAISE EXCEPTION 'Minimum trade amount is 2 GX';
  END IF;

  -- Prevent self-trading
  IF p_buyer_id = p_seller_id THEN
    RAISE EXCEPTION 'Cannot trade with yourself';
  END IF;

  -- Get ad remaining amount
  SELECT remaining_amount INTO v_ad_remaining
  FROM p2p_ads
  WHERE id = p_ad_id AND status = 'active';

  IF v_ad_remaining IS NULL THEN
    RAISE EXCEPTION 'Ad not found or inactive';
  END IF;

  IF p_gx_amount > v_ad_remaining THEN
    RAISE EXCEPTION 'Requested amount exceeds available amount';
  END IF;

  -- Get seller balance
  SELECT total_mined INTO v_seller_balance
  FROM profiles
  WHERE id = p_seller_id;

  IF v_seller_balance < p_gx_amount THEN
    RAISE EXCEPTION 'Seller has insufficient balance';
  END IF;

  -- Deduct from seller balance (move to escrow)
  UPDATE profiles
  SET total_mined = total_mined - p_gx_amount
  WHERE id = p_seller_id;

  -- Create trade
  INSERT INTO p2p_trades (
    ad_id,
    buyer_id,
    seller_id,
    gx_amount,
    escrow_amount,
    status,
    expires_at
  ) VALUES (
    p_ad_id,
    p_buyer_id,
    p_seller_id,
    p_gx_amount,
    p_gx_amount,
    'pending',
    NOW() + INTERVAL '30 minutes'
  ) RETURNING id INTO v_trade_id;

  -- Decrease remaining_amount on the ad
  UPDATE p2p_ads
  SET remaining_amount = remaining_amount - p_gx_amount,
      status = CASE 
        WHEN remaining_amount - p_gx_amount <= 0 THEN 'completed'
        ELSE status
      END
  WHERE id = p_ad_id;

  RETURN v_trade_id;
END;
$$ LANGUAGE plpgsql;

-- Function to auto-award upline with total referrals count
CREATE OR REPLACE FUNCTION update_referrer_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Update total_referrals count for the referrer
  UPDATE profiles
  SET total_referrals = (
    SELECT COUNT(*)
    FROM referrals
    WHERE referrer_id = NEW.referrer_id
  )
  WHERE id = NEW.referrer_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-update referrer stats
DROP TRIGGER IF EXISTS trigger_update_referrer_stats ON referrals;
CREATE TRIGGER trigger_update_referrer_stats
AFTER INSERT ON referrals
FOR EACH ROW
EXECUTE FUNCTION update_referrer_stats();

-- Backfill total_referrals for existing users
UPDATE profiles p
SET total_referrals = (
  SELECT COUNT(*)
  FROM referrals r
  WHERE r.referrer_id = p.id
);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_p2p_ads_remaining ON p2p_ads(remaining_amount) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals(referrer_id);
