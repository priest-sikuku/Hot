-- Create coin_ticks table for storing every price update (every 2 seconds)
CREATE TABLE IF NOT EXISTS coin_ticks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tick_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  price NUMERIC(10, 4) NOT NULL,
  high NUMERIC(10, 4) NOT NULL,
  low NUMERIC(10, 4) NOT NULL,
  average NUMERIC(10, 4) NOT NULL,
  reference_date DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_coin_ticks_timestamp ON coin_ticks(tick_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_coin_ticks_reference_date ON coin_ticks(reference_date DESC);

-- Create coin_summary table for daily summaries (stored at 3 PM daily)
CREATE TABLE IF NOT EXISTS coin_summary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_date DATE NOT NULL UNIQUE,
  opening_price NUMERIC(10, 4) NOT NULL,
  closing_price NUMERIC(10, 4) NOT NULL,
  high_price NUMERIC(10, 4) NOT NULL,
  low_price NUMERIC(10, 4) NOT NULL,
  growth_percent NUMERIC(6, 2) NOT NULL,
  target_growth_percent NUMERIC(6, 2) NOT NULL,
  total_ticks INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_coin_summary_reference_date ON coin_summary(reference_date DESC);

-- Enable RLS
ALTER TABLE coin_ticks ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_summary ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access
DROP POLICY IF EXISTS "Anyone can read coin ticks" ON coin_ticks;
CREATE POLICY "Anyone can read coin ticks" ON coin_ticks FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can read coin summary" ON coin_summary;
CREATE POLICY "Anyone can read coin summary" ON coin_summary FOR SELECT USING (true);

-- Function to get the latest price tick
CREATE OR REPLACE FUNCTION get_latest_price_tick()
RETURNS TABLE (
  price NUMERIC,
  high NUMERIC,
  low NUMERIC,
  average NUMERIC,
  tick_timestamp TIMESTAMPTZ,
  reference_date DATE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ct.price,
    ct.high,
    ct.low,
    ct.average,
    ct.tick_timestamp,
    ct.reference_date
  FROM coin_ticks ct
  ORDER BY ct.tick_timestamp DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get price ticks for the last N seconds
CREATE OR REPLACE FUNCTION get_recent_price_ticks(seconds_ago INTEGER DEFAULT 60)
RETURNS TABLE (
  price NUMERIC,
  high NUMERIC,
  low NUMERIC,
  average NUMERIC,
  tick_timestamp TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ct.price,
    ct.high,
    ct.low,
    ct.average,
    ct.tick_timestamp
  FROM coin_ticks ct
  WHERE ct.tick_timestamp >= NOW() - (seconds_ago || ' seconds')::INTERVAL
  ORDER BY ct.tick_timestamp ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get today's summary
CREATE OR REPLACE FUNCTION get_today_summary()
RETURNS TABLE (
  opening_price NUMERIC,
  closing_price NUMERIC,
  high_price NUMERIC,
  low_price NUMERIC,
  growth_percent NUMERIC,
  target_growth_percent NUMERIC,
  reference_date DATE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cs.opening_price,
    cs.closing_price,
    cs.high_price,
    cs.low_price,
    cs.growth_percent,
    cs.target_growth_percent,
    cs.reference_date
  FROM coin_summary cs
  WHERE cs.reference_date = CURRENT_DATE
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Initialize with base price if no data exists
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM coin_ticks LIMIT 1) THEN
    INSERT INTO coin_ticks (price, high, low, average, reference_date)
    VALUES (16.00, 16.00, 16.00, 16.00, CURRENT_DATE);
  END IF;
END $$;
