-- Create global supply tracking system with 1,000,000 AFX max supply

-- Create global_supply table to track total AFX supply
CREATE TABLE IF NOT EXISTS global_supply (
  id INTEGER PRIMARY KEY DEFAULT 1,
  total_supply DECIMAL(20, 8) NOT NULL DEFAULT 1000000.00,
  mined_supply DECIMAL(20, 8) NOT NULL DEFAULT 0.00,
  remaining_supply DECIMAL(20, 8) NOT NULL DEFAULT 1000000.00,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT only_one_row CHECK (id = 1)
);

-- Initialize global supply with current mined amount
INSERT INTO global_supply (id, total_supply, mined_supply, remaining_supply)
SELECT 
  1,
  1000000.00,
  COALESCE(SUM(amount), 0),
  1000000.00 - COALESCE(SUM(amount), 0)
FROM coins
WHERE claim_type = 'mining'
ON CONFLICT (id) DO UPDATE
SET 
  mined_supply = EXCLUDED.mined_supply,
  remaining_supply = EXCLUDED.remaining_supply,
  updated_at = NOW();

-- Function to check and deduct from global supply
CREATE OR REPLACE FUNCTION deduct_from_global_supply(mining_amount DECIMAL)
RETURNS TABLE(success BOOLEAN, remaining DECIMAL, message TEXT) AS $$
DECLARE
  current_remaining DECIMAL;
  actual_award DECIMAL;
BEGIN
  -- Get current remaining supply
  SELECT remaining_supply INTO current_remaining
  FROM global_supply
  WHERE id = 1
  FOR UPDATE;

  -- Check if supply is available
  IF current_remaining <= 0 THEN
    RETURN QUERY SELECT FALSE, 0::DECIMAL, 'Mining ended - maximum supply reached'::TEXT;
    RETURN;
  END IF;

  -- Calculate actual award (limit to remaining if necessary)
  IF mining_amount > current_remaining THEN
    actual_award := current_remaining;
  ELSE
    actual_award := mining_amount;
  END IF;

  -- Update global supply
  UPDATE global_supply
  SET 
    mined_supply = mined_supply + actual_award,
    remaining_supply = remaining_supply - actual_award,
    updated_at = NOW()
  WHERE id = 1;

  RETURN QUERY SELECT TRUE, actual_award, 'Success'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update global supply when mining occurs
CREATE OR REPLACE FUNCTION update_global_supply_on_mining()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.claim_type = 'mining' THEN
    UPDATE global_supply
    SET 
      mined_supply = mined_supply + NEW.amount,
      remaining_supply = total_supply - (mined_supply + NEW.amount),
      updated_at = NOW()
    WHERE id = 1;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_global_supply ON coins;
CREATE TRIGGER trigger_update_global_supply
AFTER INSERT ON coins
FOR EACH ROW
EXECUTE FUNCTION update_global_supply_on_mining();

-- Grant permissions
GRANT SELECT, UPDATE ON global_supply TO authenticated;
GRANT EXECUTE ON FUNCTION deduct_from_global_supply TO authenticated;

-- Add RLS policies
ALTER TABLE global_supply ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view global supply" ON global_supply
  FOR SELECT USING (true);

CREATE POLICY "Only system can update global supply" ON global_supply
  FOR UPDATE USING (false);
