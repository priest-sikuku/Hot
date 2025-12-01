-- Add mining halving event configuration
-- This script creates a table to store mining configuration including halving events

-- Create mining_config table to store mining parameters
CREATE TABLE IF NOT EXISTS mining_config (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  reward_amount NUMERIC NOT NULL DEFAULT 0.5,
  interval_hours INTEGER NOT NULL DEFAULT 5,
  halving_date TIMESTAMP WITH TIME ZONE,
  post_halving_reward NUMERIC NOT NULL DEFAULT 0.15,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert initial mining configuration
-- Set halving date to 7 days from now
INSERT INTO mining_config (reward_amount, interval_hours, halving_date, post_halving_reward)
VALUES (
  0.5, -- Current reward: 0.5 AFX
  5,   -- Interval: 5 hours
  NOW() + INTERVAL '7 days', -- Halving in 7 days
  0.15 -- Post-halving reward: 0.15 AFX
)
ON CONFLICT DO NOTHING;

-- Create function to get current mining reward based on halving event
CREATE OR REPLACE FUNCTION get_current_mining_reward()
RETURNS TABLE (
  reward_amount NUMERIC,
  interval_hours INTEGER,
  halving_date TIMESTAMP WITH TIME ZONE,
  is_halved BOOLEAN
) AS $$
DECLARE
  v_config RECORD;
  v_now TIMESTAMP WITH TIME ZONE := NOW();
BEGIN
  -- Get the latest mining config
  SELECT * INTO v_config
  FROM mining_config
  ORDER BY created_at DESC
  LIMIT 1;
  
  -- Check if halving has occurred
  IF v_config.halving_date IS NOT NULL AND v_now >= v_config.halving_date THEN
    -- After halving
    RETURN QUERY SELECT 
      v_config.post_halving_reward,
      v_config.interval_hours,
      v_config.halving_date,
      TRUE;
  ELSE
    -- Before halving
    RETURN QUERY SELECT 
      v_config.reward_amount,
      v_config.interval_hours,
      v_config.halving_date,
      FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS on mining_config
ALTER TABLE mining_config ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read mining config
CREATE POLICY "Anyone can read mining config"
  ON mining_config
  FOR SELECT
  TO authenticated, anon
  USING (true);

COMMENT ON TABLE mining_config IS 'Stores mining reward configuration including halving events';
COMMENT ON FUNCTION get_current_mining_reward IS 'Returns current mining reward amount based on halving event status';
