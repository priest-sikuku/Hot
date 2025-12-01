-- Ensure coin_ticks table has correct structure for server-side price generation
-- This script is idempotent and safe to run multiple times

-- Verify coin_ticks table exists with correct columns
DO $$ 
BEGIN
  -- Add tick_timestamp column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'coin_ticks' AND column_name = 'tick_timestamp'
  ) THEN
    ALTER TABLE coin_ticks ADD COLUMN tick_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW();
  END IF;

  -- Ensure RLS is enabled
  ALTER TABLE coin_ticks ENABLE ROW LEVEL SECURITY;
  
  -- Drop existing policy if it exists
  DROP POLICY IF EXISTS "Anyone can read coin ticks" ON coin_ticks;
  
  -- Create read policy for all users
  CREATE POLICY "Anyone can read coin ticks"
    ON coin_ticks
    FOR SELECT
    TO public
    USING (true);

  -- Drop existing insert policy if it exists
  DROP POLICY IF EXISTS "Service can insert coin ticks" ON coin_ticks;
  
  -- Create insert policy (authenticated users can insert via API)
  CREATE POLICY "Service can insert coin ticks"
    ON coin_ticks
    FOR INSERT
    TO authenticated
    WITH CHECK (true);
END $$;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_coin_ticks_timestamp 
  ON coin_ticks(tick_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_coin_ticks_reference_date 
  ON coin_ticks(reference_date);

-- Verify coin_summary table exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'coin_summary') THEN
    CREATE TABLE coin_summary (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      reference_date DATE NOT NULL UNIQUE,
      opening_price NUMERIC NOT NULL,
      closing_price NUMERIC NOT NULL,
      high_price NUMERIC NOT NULL,
      low_price NUMERIC NOT NULL,
      growth_percent NUMERIC NOT NULL,
      target_growth_percent NUMERIC NOT NULL,
      total_ticks INTEGER NOT NULL,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );
    
    ALTER TABLE coin_summary ENABLE ROW LEVEL SECURITY;
    
    CREATE POLICY "Anyone can read coin summary"
      ON coin_summary
      FOR SELECT
      TO public
      USING (true);
  END IF;
END $$;

-- Function to get latest price (used by clients)
CREATE OR REPLACE FUNCTION get_latest_afx_price()
RETURNS TABLE (
  price NUMERIC,
  high NUMERIC,
  low NUMERIC,
  average NUMERIC,
  tick_timestamp TIMESTAMP WITH TIME ZONE,
  change_percent NUMERIC
) AS $$
DECLARE
  opening_price NUMERIC;
  current_date_val DATE;
BEGIN
  current_date_val := CURRENT_DATE;
  
  -- Get opening price for today
  SELECT ct.price INTO opening_price
  FROM coin_ticks ct
  WHERE ct.reference_date = current_date_val
  ORDER BY ct.tick_timestamp ASC
  LIMIT 1;
  
  -- If no opening price found, use latest price as opening
  IF opening_price IS NULL THEN
    SELECT ct.price INTO opening_price
    FROM coin_ticks ct
    ORDER BY ct.tick_timestamp DESC
    LIMIT 1;
  END IF;
  
  -- Return latest tick with calculated change percent
  RETURN QUERY
  SELECT 
    ct.price,
    ct.high,
    ct.low,
    ct.average,
    ct.tick_timestamp,
    CASE 
      WHEN opening_price IS NOT NULL AND opening_price > 0 
      THEN ((ct.price - opening_price) / opening_price * 100)
      ELSE 0
    END as change_percent
  FROM coin_ticks ct
  ORDER BY ct.tick_timestamp DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_latest_afx_price() TO authenticated, anon;

COMMENT ON TABLE coin_ticks IS 'Stores real-time AFX price ticks generated server-side every 3 seconds';
COMMENT ON TABLE coin_summary IS 'Stores daily price summaries with growth targets';
COMMENT ON FUNCTION get_latest_afx_price() IS 'Returns the latest AFX price with calculated 24h change percentage';
