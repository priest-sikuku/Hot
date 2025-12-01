-- Create GX price tracking system with 3pm daily reference and dynamic volatility

-- Table to store daily 3pm reference prices
CREATE TABLE IF NOT EXISTS gx_price_references (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_date DATE NOT NULL UNIQUE,
  reference_time TIMESTAMPTZ NOT NULL, -- 3pm timestamp
  price DECIMAL(10, 2) NOT NULL,
  previous_price DECIMAL(10, 2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table to store current live price with volatility
CREATE TABLE IF NOT EXISTS gx_current_price (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  price DECIMAL(10, 2) NOT NULL,
  previous_price DECIMAL(10, 2),
  change_percent DECIMAL(5, 2),
  volatility_factor DECIMAL(5, 4) DEFAULT 0.0000, -- Based on trading activity
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table to track price history for charts
CREATE TABLE IF NOT EXISTS gx_price_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  price DECIMAL(10, 2) NOT NULL,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Initialize with base price of 16 KES
INSERT INTO gx_current_price (price, previous_price, change_percent)
VALUES (16.00, 16.00, 0.00)
ON CONFLICT DO NOTHING;

-- Initialize first reference price (today at 3pm)
INSERT INTO gx_price_references (reference_date, reference_time, price, previous_price)
VALUES (
  CURRENT_DATE,
  (CURRENT_DATE + TIME '15:00:00')::TIMESTAMPTZ,
  16.00,
  16.00
)
ON CONFLICT (reference_date) DO NOTHING;

-- Function to calculate next day's 3pm reference price (3% increase)
CREATE OR REPLACE FUNCTION calculate_next_reference_price()
RETURNS DECIMAL AS $$
DECLARE
  latest_ref DECIMAL;
BEGIN
  SELECT price INTO latest_ref
  FROM gx_price_references
  ORDER BY reference_date DESC
  LIMIT 1;
  
  RETURN latest_ref * 1.03; -- 3% increase
END;
$$ LANGUAGE plpgsql;

-- Function to update reference price at 3pm daily
CREATE OR REPLACE FUNCTION update_daily_reference_price()
RETURNS void AS $$
DECLARE
  today_date DATE := CURRENT_DATE;
  today_3pm TIMESTAMPTZ := (CURRENT_DATE + TIME '15:00:00')::TIMESTAMPTZ;
  new_price DECIMAL;
  prev_price DECIMAL;
BEGIN
  -- Get previous reference price
  SELECT price INTO prev_price
  FROM gx_price_references
  ORDER BY reference_date DESC
  LIMIT 1;
  
  -- Calculate new price (3% increase)
  new_price := prev_price * 1.03;
  
  -- Insert new reference price
  INSERT INTO gx_price_references (reference_date, reference_time, price, previous_price)
  VALUES (today_date, today_3pm, new_price, prev_price)
  ON CONFLICT (reference_date) 
  DO UPDATE SET price = new_price, previous_price = prev_price;
  
  -- Update current price to match reference at 3pm
  UPDATE gx_current_price
  SET price = new_price,
      previous_price = prev_price,
      change_percent = 3.00,
      updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to calculate volatility based on recent trading activity
CREATE OR REPLACE FUNCTION calculate_volatility()
RETURNS DECIMAL AS $$
DECLARE
  recent_trades_count INTEGER;
  base_volatility DECIMAL := 0.02; -- 2% base volatility
  max_volatility DECIMAL := 0.20; -- 20% max volatility
  volatility DECIMAL;
BEGIN
  -- Count trades in last hour
  SELECT COUNT(*) INTO recent_trades_count
  FROM trades
  WHERE created_at > NOW() - INTERVAL '1 hour';
  
  -- Calculate volatility: more trades = more volatility
  volatility := base_volatility + (recent_trades_count * 0.01);
  
  -- Cap at max volatility
  IF volatility > max_volatility THEN
    volatility := max_volatility;
  END IF;
  
  RETURN volatility;
END;
$$ LANGUAGE plpgsql;

-- Enable RLS
ALTER TABLE gx_price_references ENABLE ROW LEVEL SECURITY;
ALTER TABLE gx_current_price ENABLE ROW LEVEL SECURITY;
ALTER TABLE gx_price_history ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read prices
CREATE POLICY "Anyone can read price references" ON gx_price_references FOR SELECT TO authenticated USING (true);
CREATE POLICY "Anyone can read current price" ON gx_current_price FOR SELECT TO authenticated USING (true);
CREATE POLICY "Anyone can read price history" ON gx_price_history FOR SELECT TO authenticated USING (true);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_price_references_date ON gx_price_references(reference_date DESC);
CREATE INDEX IF NOT EXISTS idx_price_history_timestamp ON gx_price_history(timestamp DESC);
