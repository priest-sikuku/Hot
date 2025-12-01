-- Add user count tracking starting from 1239
-- This creates a function to get the total user count with a base offset

-- Create a table to store the base user count offset
CREATE TABLE IF NOT EXISTS user_count_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  base_count INTEGER NOT NULL DEFAULT 1239,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert initial config if not exists
INSERT INTO user_count_config (base_count)
SELECT 1239
WHERE NOT EXISTS (SELECT 1 FROM user_count_config);

-- Function to get total user count (base + actual users)
CREATE OR REPLACE FUNCTION get_total_user_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_base_count INTEGER;
  v_actual_count INTEGER;
  v_total_count INTEGER;
BEGIN
  -- Get base count from config
  SELECT base_count INTO v_base_count
  FROM user_count_config
  LIMIT 1;
  
  -- If no config exists, use default
  IF v_base_count IS NULL THEN
    v_base_count := 1239;
  END IF;
  
  -- Get actual user count from profiles
  SELECT COUNT(*) INTO v_actual_count
  FROM profiles;
  
  -- Calculate total
  v_total_count := v_base_count + v_actual_count;
  
  RETURN v_total_count;
END;
$$;

-- Enable RLS on user_count_config
ALTER TABLE user_count_config ENABLE ROW LEVEL SECURITY;

-- Policy to allow anyone to read the config
CREATE POLICY "Anyone can read user count config"
ON user_count_config
FOR SELECT
TO public
USING (true);

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION get_total_user_count() TO authenticated, anon;
