-- Admin System Setup
-- This script creates the complete admin infrastructure

-- Step 1: Add admin columns to profiles table
DO $$ 
BEGIN
  -- Add is_admin column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'is_admin'
  ) THEN
    ALTER TABLE profiles ADD COLUMN is_admin BOOLEAN DEFAULT FALSE;
  END IF;

  -- Add role column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'role'
  ) THEN
    ALTER TABLE profiles ADD COLUMN role TEXT DEFAULT 'user';
  END IF;

  -- Add admin_note column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'admin_note'
  ) THEN
    ALTER TABLE profiles ADD COLUMN admin_note TEXT;
  END IF;

  -- Add disabled column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'disabled'
  ) THEN
    ALTER TABLE profiles ADD COLUMN disabled BOOLEAN DEFAULT FALSE;
  END IF;

  -- Add disabled_at column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'disabled_at'
  ) THEN
    ALTER TABLE profiles ADD COLUMN disabled_at TIMESTAMP;
  END IF;

  -- Add disabled_by column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'disabled_by'
  ) THEN
    ALTER TABLE profiles ADD COLUMN disabled_by UUID REFERENCES profiles(id);
  END IF;
END $$;

-- Create indexes for admin queries
CREATE INDEX IF NOT EXISTS idx_profiles_is_admin ON profiles(is_admin) WHERE is_admin = TRUE;
CREATE INDEX IF NOT EXISTS idx_profiles_disabled ON profiles(disabled) WHERE disabled = TRUE;
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);

-- Step 2: Create admin_audit_logs table
CREATE TABLE IF NOT EXISTS admin_audit_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  admin_id UUID NOT NULL REFERENCES profiles(id),
  action TEXT NOT NULL,
  target_table TEXT,
  target_id UUID,
  details JSONB,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_admin_id ON admin_audit_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created_at ON admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_action ON admin_audit_logs(action);

-- Enable RLS on admin_audit_logs
ALTER TABLE admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admins can view audit logs" ON admin_audit_logs;
DROP POLICY IF EXISTS "System can insert audit logs" ON admin_audit_logs;

-- Only admins can view audit logs
CREATE POLICY "Admins can view audit logs"
  ON admin_audit_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.is_admin = TRUE
      AND profiles.disabled = FALSE
    )
  );

-- System can insert audit logs
CREATE POLICY "System can insert audit logs"
  ON admin_audit_logs FOR INSERT
  WITH CHECK (TRUE);

-- Step 3: Create admin_settings table
CREATE TABLE IF NOT EXISTS admin_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value JSONB NOT NULL,
  description TEXT,
  updated_by UUID REFERENCES profiles(id),
  updated_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_settings_key ON admin_settings(key);

-- Enable RLS on admin_settings
ALTER TABLE admin_settings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admins can view settings" ON admin_settings;
DROP POLICY IF EXISTS "Admins can update settings" ON admin_settings;
DROP POLICY IF EXISTS "Admins can insert settings" ON admin_settings;

-- Only admins can manage settings
CREATE POLICY "Admins can view settings"
  ON admin_settings FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.is_admin = TRUE
      AND profiles.disabled = FALSE
    )
  );

CREATE POLICY "Admins can update settings"
  ON admin_settings FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.is_admin = TRUE
      AND profiles.disabled = FALSE
    )
  );

CREATE POLICY "Admins can insert settings"
  ON admin_settings FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.is_admin = TRUE
      AND profiles.disabled = FALSE
    )
  );

-- Insert default admin settings
INSERT INTO admin_settings (key, value, description) VALUES
  ('trade_auto_expire_minutes', '30', 'Minutes before unpaid trades auto-expire'),
  ('max_active_ads_per_user', '10', 'Maximum active ads per user'),
  ('min_trade_amount', '1', 'Minimum AFX amount per trade'),
  ('max_trade_amount', '10000', 'Maximum AFX amount per trade'),
  ('platform_fee_percent', '0', 'Platform fee percentage'),
  ('maintenance_mode', 'false', 'Enable/disable maintenance mode')
ON CONFLICT (key) DO NOTHING;

-- Step 4: Create admin helper functions

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin(p_user_id UUID DEFAULT NULL)
RETURNS BOOLEAN AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := COALESCE(p_user_id, auth.uid());
  
  RETURN EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = v_user_id 
    AND is_admin = TRUE 
    AND disabled = FALSE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to log admin actions
CREATE OR REPLACE FUNCTION log_admin_action(
  p_action TEXT,
  p_target_table TEXT DEFAULT NULL,
  p_target_id UUID DEFAULT NULL,
  p_details JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_log_id UUID;
  v_admin_id UUID;
BEGIN
  v_admin_id := auth.uid();
  
  -- Verify user is admin
  IF NOT is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Unauthorized: User is not an admin';
  END IF;
  
  -- Insert audit log
  INSERT INTO admin_audit_logs (
    admin_id,
    action,
    target_table,
    target_id,
    details
  ) VALUES (
    v_admin_id,
    p_action,
    p_target_table,
    p_target_id,
    p_details
  ) RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get admin dashboard stats
CREATE OR REPLACE FUNCTION admin_get_dashboard_stats()
RETURNS JSONB AS $$
DECLARE
  v_admin_id UUID;
  v_stats JSONB;
BEGIN
  v_admin_id := auth.uid();
  
  -- Verify admin
  IF NOT is_admin(v_admin_id) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;
  
  SELECT jsonb_build_object(
    'total_users', (SELECT COUNT(*) FROM profiles WHERE disabled = FALSE),
    'disabled_users', (SELECT COUNT(*) FROM profiles WHERE disabled = TRUE),
    'total_admins', (SELECT COUNT(*) FROM profiles WHERE is_admin = TRUE),
    'active_trades', (SELECT COUNT(*) FROM p2p_trades WHERE status IN ('pending', 'paid')),
    'completed_trades_today', (
      SELECT COUNT(*) FROM p2p_trades 
      WHERE status = 'completed' 
      AND released_at >= CURRENT_DATE
    ),
    'active_ads', (SELECT COUNT(*) FROM p2p_ads WHERE status = 'active'),
    'total_afx_in_circulation', (SELECT COALESCE(SUM(amount), 0) FROM coins WHERE status = 'available'),
    'total_afx_in_p2p', (SELECT COALESCE(SUM(amount), 0) FROM trade_coins WHERE status = 'available'),
    'total_afx_locked', (SELECT COALESCE(SUM(amount), 0) FROM trade_coins WHERE status = 'locked')
  ) INTO v_stats;
  
  RETURN v_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update admin settings
CREATE OR REPLACE FUNCTION admin_update_setting(
  p_admin_id UUID,
  p_key TEXT,
  p_value JSONB
) RETURNS VOID AS $$
BEGIN
  -- Verify admin
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;
  
  -- Update or insert setting
  INSERT INTO admin_settings (key, value, updated_by, updated_at)
  VALUES (p_key, p_value, p_admin_id, NOW())
  ON CONFLICT (key) 
  DO UPDATE SET 
    value = EXCLUDED.value,
    updated_by = EXCLUDED.updated_by,
    updated_at = EXCLUDED.updated_at;
    
  -- Log action
  PERFORM log_admin_action(
    'SETTING_UPDATED',
    'admin_settings',
    NULL,
    jsonb_build_object('key', p_key, 'value', p_value)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
