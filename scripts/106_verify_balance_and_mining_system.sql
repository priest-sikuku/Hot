-- =====================================================
-- VERIFY AND FIX BALANCE & MINING SYSTEM
-- =====================================================

-- Ensure coins table has correct structure
ALTER TABLE coins 
  ALTER COLUMN status SET DEFAULT 'available';

-- Add index for faster balance queries
CREATE INDEX IF NOT EXISTS idx_coins_user_status ON coins(user_id, status);
CREATE INDEX IF NOT EXISTS idx_coins_user_available ON coins(user_id) WHERE status = 'available';

-- Verify balance functions exist and work correctly
-- These should already exist from script 105, but let's ensure they're correct

CREATE OR REPLACE FUNCTION get_user_balance(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_total_balance numeric := 0;
BEGIN
  -- Sum all coins for the user (available + locked)
  SELECT COALESCE(SUM(amount), 0)
  INTO v_total_balance
  FROM coins
  WHERE user_id = p_user_id;
  
  RETURN v_total_balance;
END;
$$;

CREATE OR REPLACE FUNCTION get_available_balance(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_available_balance numeric := 0;
BEGIN
  -- Sum only available coins (not locked in P2P escrow)
  SELECT COALESCE(SUM(amount), 0)
  INTO v_available_balance
  FROM coins
  WHERE user_id = p_user_id
    AND status = 'available';
  
  RETURN v_available_balance;
END;
$$;

CREATE OR REPLACE FUNCTION get_locked_balance(p_user_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_locked_balance numeric := 0;
BEGIN
  -- Sum locked coins (in P2P escrow)
  SELECT COALESCE(SUM(amount), 0)
  INTO v_locked_balance
  FROM coins
  WHERE user_id = p_user_id
    AND status = 'locked';
  
  RETURN v_locked_balance;
END;
$$;

-- Create a function to verify mining claim and balance update
CREATE OR REPLACE FUNCTION verify_mining_claim(p_user_id uuid)
RETURNS TABLE (
  total_balance numeric,
  available_balance numeric,
  locked_balance numeric,
  mining_count bigint,
  last_mine timestamp with time zone,
  next_mine timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    get_user_balance(p_user_id) as total_balance,
    get_available_balance(p_user_id) as available_balance,
    get_locked_balance(p_user_id) as locked_balance,
    (SELECT COUNT(*) FROM coins WHERE user_id = p_user_id AND claim_type = 'mining') as mining_count,
    p.last_mine,
    p.next_mine
  FROM profiles p
  WHERE p.id = p_user_id;
END;
$$;

-- Ensure AFX price table exists with default data
CREATE TABLE IF NOT EXISTS afx_current_price (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  price numeric NOT NULL DEFAULT 16.29,
  previous_price numeric NOT NULL DEFAULT 16.29,
  change_percent numeric NOT NULL DEFAULT 0,
  volatility_factor numeric DEFAULT 0.02,
  updated_at timestamp with time zone DEFAULT now()
);

-- Enable RLS on price table
ALTER TABLE afx_current_price ENABLE ROW LEVEL SECURITY;

-- Drop existing policy before creating to avoid duplicate error
DROP POLICY IF EXISTS "Anyone can read current price" ON afx_current_price;

-- Allow anyone to read current price
CREATE POLICY "Anyone can read current price"
  ON afx_current_price FOR SELECT
  USING (true);

-- Insert default price if table is empty
INSERT INTO afx_current_price (price, previous_price, change_percent, updated_at)
SELECT 16.29, 16.29, 0, now()
WHERE NOT EXISTS (SELECT 1 FROM afx_current_price);

-- Create price history table for tracking
CREATE TABLE IF NOT EXISTS afx_price_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  price numeric NOT NULL,
  timestamp timestamp with time zone DEFAULT now()
);

-- Enable RLS on price history
ALTER TABLE afx_price_history ENABLE ROW LEVEL SECURITY;

-- Drop existing policy before creating to avoid duplicate error
DROP POLICY IF EXISTS "Anyone can read price history" ON afx_price_history;

-- Allow anyone to read price history
CREATE POLICY "Anyone can read price history"
  ON afx_price_history FOR SELECT
  USING (true);

-- Create function to update AFX price (can be called manually or via cron)
CREATE OR REPLACE FUNCTION update_afx_price()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_price numeric;
  v_new_price numeric;
  v_change_percent numeric;
  v_volatility numeric := 0.02; -- 2% volatility
BEGIN
  -- Get current price
  SELECT price INTO v_current_price
  FROM afx_current_price
  LIMIT 1;
  
  -- Calculate new price with random volatility
  v_new_price := v_current_price * (1 + (random() * v_volatility * 2 - v_volatility));
  v_new_price := ROUND(v_new_price, 2);
  
  -- Calculate change percent
  v_change_percent := ((v_new_price - v_current_price) / v_current_price) * 100;
  
  -- Update current price
  UPDATE afx_current_price
  SET 
    previous_price = v_current_price,
    price = v_new_price,
    change_percent = v_change_percent,
    updated_at = now();
  
  -- Add to history
  INSERT INTO afx_price_history (price, timestamp)
  VALUES (v_new_price, now());
  
  -- Keep only last 30 days of history
  DELETE FROM afx_price_history
  WHERE timestamp < now() - INTERVAL '30 days';
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_user_balance(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_balance(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION get_locked_balance(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_mining_claim(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION update_afx_price() TO authenticated;
GRANT SELECT ON afx_current_price TO authenticated;
GRANT SELECT ON afx_price_history TO authenticated;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_afx_price_history_timestamp ON afx_price_history(timestamp DESC);

COMMENT ON FUNCTION get_user_balance IS 'Returns total balance including mining, referrals, and P2P trades';
COMMENT ON FUNCTION get_available_balance IS 'Returns available balance for trading (excludes locked P2P funds)';
COMMENT ON FUNCTION get_locked_balance IS 'Returns balance locked in P2P escrow';
COMMENT ON FUNCTION verify_mining_claim IS 'Verifies mining claim and returns complete balance breakdown';
COMMENT ON FUNCTION update_afx_price IS 'Updates AFX price with simulated market volatility';
