-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Update p2p_ads table to track ad creation costs and selected payment methods
ALTER TABLE p2p_ads
ADD COLUMN IF NOT EXISTS payment_methods_selected JSONB DEFAULT NULL,
ADD COLUMN IF NOT EXISTS ad_creation_cost NUMERIC DEFAULT 10,
ADD COLUMN IF NOT EXISTS bank_name TEXT DEFAULT NULL;

-- Update columns to ensure payment details are stored properly
UPDATE p2p_ads SET payment_methods_selected = '[]'::JSONB WHERE payment_methods_selected IS NULL;

-- Create a function to deduct coins when a sell ad is created
CREATE OR REPLACE FUNCTION deduct_coins_for_ad(
  p_user_id UUID,
  p_amount NUMERIC
)
RETURNS JSONB AS $$
DECLARE
  v_current_coins NUMERIC;
  v_result JSONB;
BEGIN
  -- Get current available coins
  SELECT amount INTO v_current_coins
  FROM coins
  WHERE user_id = p_user_id
  AND status = 'available'
  LIMIT 1;

  -- If no coins record exists or insufficient coins
  IF v_current_coins IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'No available coins found',
      'available_amount', 0
    );
  END IF;

  IF v_current_coins < p_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Insufficient coins',
      'available_amount', v_current_coins,
      'required_amount', p_amount
    );
  END IF;

  -- Deduct coins
  UPDATE coins
  SET amount = amount - p_amount,
      updated_at = NOW()
  WHERE user_id = p_user_id
  AND status = 'available'
  LIMIT 1;

  -- Log the transaction
  INSERT INTO transactions (
    user_id,
    type,
    amount,
    description,
    status,
    created_at
  ) VALUES (
    p_user_id,
    'p2p_ad_creation',
    p_amount,
    'Deduction for P2P sell ad creation',
    'completed',
    NOW()
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Coins deducted successfully',
    'amount_deducted', p_amount,
    'remaining_amount', v_current_coins - p_amount
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION deduct_coins_for_ad TO authenticated;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_p2p_ads_user_created ON p2p_ads(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_p2p_ads_status_type ON p2p_ads(status, ad_type);
CREATE INDEX IF NOT EXISTS idx_p2p_ads_expires ON p2p_ads(expires_at) WHERE status = 'active';

-- Update existing RLS policies for p2p_ads to ensure security
DROP POLICY IF EXISTS "Users can create their own ads" ON p2p_ads;

CREATE POLICY "Users can create their own ads"
ON p2p_ads FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Create a view to track P2P ad statistics
CREATE OR REPLACE VIEW p2p_ad_stats AS
SELECT
  user_id,
  COUNT(*) as total_ads,
  COUNT(*) FILTER (WHERE status = 'active') as active_ads,
  COUNT(*) FILTER (WHERE ad_type = 'sell') as sell_ads,
  COUNT(*) FILTER (WHERE ad_type = 'buy') as buy_ads,
  SUM(afx_amount) FILTER (WHERE status = 'active') as total_active_afx,
  SUM(ad_creation_cost) as total_ad_costs
FROM p2p_ads
GROUP BY user_id;

-- Grant SELECT on the view
GRANT SELECT ON p2p_ad_stats TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION deduct_coins_for_ad IS 'Deducts coins from a user account when creating a P2P sell ad. Returns JSON with success status and remaining balance.';
COMMENT ON TABLE p2p_ads IS 'Stores all P2P ads (buy and sell). Sell ads require 10 coins to create.';
