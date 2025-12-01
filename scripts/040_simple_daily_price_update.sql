-- Simple daily price update system using UTC time
-- Prices increase by 3% every 24 hours

-- Drop existing problematic functions
DROP FUNCTION IF EXISTS update_daily_reference_price() CASCADE;
DROP FUNCTION IF EXISTS check_and_update_reference_price() CASCADE;
DROP FUNCTION IF EXISTS auto_update_price_on_read() CASCADE;
DROP FUNCTION IF EXISTS get_current_gx_price_with_auto_update() CASCADE;
DROP FUNCTION IF EXISTS manual_price_update() CASCADE;
DROP TRIGGER IF EXISTS trigger_auto_price_update ON gx_current_price;
DROP VIEW IF EXISTS current_gx_price_view CASCADE;

-- Simple function to update daily price with 3% increase
CREATE OR REPLACE FUNCTION update_daily_gx_price()
RETURNS TABLE(
  success BOOLEAN, 
  message TEXT, 
  new_price NUMERIC, 
  old_price NUMERIC
) AS $$
DECLARE
  today_date DATE := CURRENT_DATE;
  new_ref_price NUMERIC;
  prev_ref_price NUMERIC;
  existing_ref RECORD;
BEGIN
  -- Check if we already have a price for today
  SELECT * INTO existing_ref
  FROM gx_price_references
  WHERE reference_date = today_date;
  
  IF existing_ref IS NOT NULL THEN
    -- Already updated today
    RETURN QUERY 
    SELECT 
      false, 
      'Price already updated for today'::TEXT, 
      existing_ref.price, 
      existing_ref.previous_price;
    RETURN;
  END IF;
  
  -- Get the most recent price
  SELECT price INTO prev_ref_price
  FROM gx_price_references
  ORDER BY reference_date DESC
  LIMIT 1;
  
  -- If no previous price, start with 16.00
  IF prev_ref_price IS NULL THEN
    prev_ref_price := 16.00;
  END IF;
  
  -- Calculate new price with 3% increase
  new_ref_price := ROUND(prev_ref_price * 1.03, 2);
  
  -- Insert new reference price for today
  INSERT INTO gx_price_references (
    reference_date, 
    reference_time, 
    price, 
    previous_price
  )
  VALUES (
    today_date,
    NOW(), -- Use current UTC time
    new_ref_price,
    prev_ref_price
  );
  
  -- Update current price table
  UPDATE gx_current_price
  SET 
    price = new_ref_price,
    previous_price = prev_ref_price,
    change_percent = 3.00,
    updated_at = NOW();
  
  -- Log to price history
  INSERT INTO gx_price_history (price, timestamp)
  VALUES (new_ref_price, NOW());
  
  RETURN QUERY 
  SELECT 
    true, 
    'Price updated successfully'::TEXT, 
    new_ref_price, 
    prev_ref_price;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get current price and check if update is needed
CREATE OR REPLACE FUNCTION get_gx_price_with_check()
RETURNS TABLE(
  current_price NUMERIC,
  prev_price NUMERIC,
  change_pct NUMERIC,
  last_update TIMESTAMPTZ,
  needs_update BOOLEAN
) AS $$
DECLARE
  today_date DATE := CURRENT_DATE;
  latest_ref_date DATE;
  should_update BOOLEAN := false;
BEGIN
  -- Get the latest reference date
  SELECT reference_date INTO latest_ref_date
  FROM gx_price_references
  ORDER BY reference_date DESC
  LIMIT 1;
  
  -- Check if we need an update (no price for today)
  IF latest_ref_date IS NULL OR latest_ref_date < today_date THEN
    should_update := true;
    -- Automatically update
    PERFORM update_daily_gx_price();
  END IF;
  
  -- Return current price info
  RETURN QUERY
  SELECT 
    gcp.price,
    gcp.previous_price,
    gcp.change_percent,
    gcp.updated_at,
    should_update
  FROM gx_current_price gcp
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Backfill missing dates with 3% daily increases
DO $$
DECLARE
  earliest_date DATE;
  current_date_iter DATE;
  end_date DATE := CURRENT_DATE;
  iter_price NUMERIC;
  iter_prev_price NUMERIC;
BEGIN
  -- Get the earliest reference date
  SELECT reference_date, price 
  INTO earliest_date, iter_price
  FROM gx_price_references
  ORDER BY reference_date ASC
  LIMIT 1;
  
  -- If no reference exists, start from 30 days ago with base price
  IF earliest_date IS NULL THEN
    earliest_date := CURRENT_DATE - INTERVAL '30 days';
    iter_price := 16.00;
    
    -- Insert the starting reference
    INSERT INTO gx_price_references (
      reference_date, 
      reference_time, 
      price, 
      previous_price
    )
    VALUES (
      earliest_date,
      earliest_date::TIMESTAMPTZ,
      iter_price,
      iter_price
    );
  END IF;
  
  -- Fill in all missing dates from earliest to today
  current_date_iter := earliest_date + INTERVAL '1 day';
  
  WHILE current_date_iter <= end_date LOOP
    -- Check if this date already has a reference
    IF NOT EXISTS (
      SELECT 1 FROM gx_price_references 
      WHERE reference_date = current_date_iter
    ) THEN
      -- Get previous day's price
      SELECT price INTO iter_prev_price
      FROM gx_price_references
      WHERE reference_date = current_date_iter - INTERVAL '1 day';
      
      -- Calculate new price (3% increase)
      iter_price := ROUND(iter_prev_price * 1.03, 2);
      
      -- Insert new reference
      INSERT INTO gx_price_references (
        reference_date, 
        reference_time, 
        price, 
        previous_price
      )
      VALUES (
        current_date_iter,
        current_date_iter::TIMESTAMPTZ,
        iter_price,
        iter_prev_price
      );
    ELSE
      -- Get the existing price for next iteration
      SELECT price INTO iter_price
      FROM gx_price_references
      WHERE reference_date = current_date_iter;
    END IF;
    
    current_date_iter := current_date_iter + INTERVAL '1 day';
  END LOOP;
  
  -- Update current price to today's value
  SELECT price, previous_price 
  INTO iter_price, iter_prev_price
  FROM gx_price_references
  WHERE reference_date = end_date;
  
  IF iter_price IS NOT NULL THEN
    UPDATE gx_current_price
    SET 
      price = iter_price,
      previous_price = COALESCE(iter_prev_price, iter_price),
      change_percent = 3.00,
      updated_at = NOW();
  END IF;
END $$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_gx_price_with_check() TO authenticated;
GRANT EXECUTE ON FUNCTION update_daily_gx_price() TO authenticated;

-- Create a simple view for current price
CREATE OR REPLACE VIEW v_current_gx_price AS
SELECT 
  price as current_price,
  previous_price,
  change_percent,
  updated_at,
  CASE 
    WHEN NOT EXISTS (
      SELECT 1 FROM gx_price_references 
      WHERE reference_date = CURRENT_DATE
    )
    THEN true
    ELSE false
  END as needs_update
FROM gx_current_price
LIMIT 1;

GRANT SELECT ON v_current_gx_price TO authenticated;

-- Create a function that can be called via API to manually trigger update
CREATE OR REPLACE FUNCTION trigger_price_update()
RETURNS JSON AS $$
DECLARE
  result RECORD;
BEGIN
  SELECT * INTO result FROM update_daily_gx_price();
  RETURN json_build_object(
    'success', result.success,
    'message', result.message,
    'new_price', result.new_price,
    'old_price', result.old_price
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION trigger_price_update() TO authenticated;
