-- Create a function to be called by a cron job or manually to update daily reference price
-- This should be run at 3pm daily (15:00 EAT)

-- Function to check and update reference price if it's 3pm or later
CREATE OR REPLACE FUNCTION check_and_update_reference_price()
RETURNS void AS $$
DECLARE
  current_hour INTEGER;
  today_date DATE := CURRENT_DATE;
  existing_ref RECORD;
BEGIN
  -- Get current hour
  current_hour := EXTRACT(HOUR FROM NOW());
  
  -- Check if it's 3pm or later
  IF current_hour >= 15 THEN
    -- Check if we already have a reference for today
    SELECT * INTO existing_ref
    FROM gx_price_references
    WHERE reference_date = today_date;
    
    -- If no reference for today, create one
    IF existing_ref IS NULL THEN
      PERFORM update_daily_reference_price();
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- You can manually run this to update the reference price:
-- SELECT check_and_update_reference_price();

-- Or set up a cron job in Supabase to run this daily at 3pm
