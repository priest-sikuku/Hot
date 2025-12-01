-- =====================================================
-- AFX ADMIN PANEL - ROLE SYSTEM & AUDIT INFRASTRUCTURE
-- =====================================================
-- This script creates the admin role system with audit logging
-- and soft-delete support for safe data management.

-- 1. Add admin role columns to profiles table
ALTER TABLE IF EXISTS profiles 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user',
ADD COLUMN IF NOT EXISTS admin_note TEXT,
ADD COLUMN IF NOT EXISTS disabled BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS disabled_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS disabled_by UUID;

-- Create index for admin queries
CREATE INDEX IF NOT EXISTS idx_profiles_is_admin ON profiles(is_admin) WHERE is_admin = TRUE;
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_disabled ON profiles(disabled) WHERE disabled = TRUE;

-- 2. Create admin audit logs table
CREATE TABLE IF NOT EXISTS admin_audit_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    admin_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    target_table TEXT,
    target_id UUID,
    details JSONB,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_admin_id ON admin_audit_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_action ON admin_audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created_at ON admin_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_target ON admin_audit_logs(target_table, target_id);

-- 3. Create admin settings table
CREATE TABLE IF NOT EXISTS admin_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    key TEXT UNIQUE NOT NULL,
    value JSONB,
    description TEXT,
    updated_by UUID REFERENCES profiles(id),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Insert default settings
INSERT INTO admin_settings (key, value, description) VALUES
    ('trade_auto_expire_minutes', '30', 'Minutes before unpaid trades auto-expire'),
    ('min_trade_amount', '10', 'Minimum AFX amount per trade'),
    ('max_trade_amount', '10000', 'Maximum AFX amount per trade'),
    ('platform_fee_percent', '0', 'Platform fee percentage on trades'),
    ('maintenance_mode', 'false', 'Enable maintenance mode')
ON CONFLICT (key) DO NOTHING;

-- 4. Create admin notifications table
CREATE TABLE IF NOT EXISTS admin_notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT,
    type TEXT DEFAULT 'info',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_notifications_user_id ON admin_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_notifications_is_read ON admin_notifications(is_read) WHERE is_read = FALSE;

-- 5. Add soft-delete columns to key tables
ALTER TABLE IF EXISTS p2p_ads 
ADD COLUMN IF NOT EXISTS disabled BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS disabled_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS disabled_by UUID REFERENCES profiles(id);

ALTER TABLE IF EXISTS p2p_trades
ADD COLUMN IF NOT EXISTS admin_note TEXT,
ADD COLUMN IF NOT EXISTS force_completed_by UUID REFERENCES profiles(id),
ADD COLUMN IF NOT EXISTS force_completed_at TIMESTAMP;

-- 6. Create RLS policies for admin tables
ALTER TABLE admin_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_notifications ENABLE ROW LEVEL SECURITY;

-- Admin audit logs: Only admins can read
CREATE POLICY IF NOT EXISTS "Admins can view audit logs"
ON admin_audit_logs FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.is_admin = TRUE
    )
);

-- Admin settings: Only admins can read/write
CREATE POLICY IF NOT EXISTS "Admins can view settings"
ON admin_settings FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.is_admin = TRUE
    )
);

CREATE POLICY IF NOT EXISTS "Admins can update settings"
ON admin_settings FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.is_admin = TRUE
    )
);

-- Admin notifications: Users can read their own
CREATE POLICY IF NOT EXISTS "Users can view their notifications"
ON admin_notifications FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY IF NOT EXISTS "Users can update their notifications"
ON admin_notifications FOR UPDATE
TO authenticated
USING (user_id = auth.uid());

-- 7. Create helper function to log admin actions
CREATE OR REPLACE FUNCTION log_admin_action(
    p_admin_id UUID,
    p_action TEXT,
    p_target_table TEXT DEFAULT NULL,
    p_target_id UUID DEFAULT NULL,
    p_details JSONB DEFAULT NULL,
    p_ip_address TEXT DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    -- Verify admin
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_admin_id AND is_admin = TRUE) THEN
        RAISE EXCEPTION 'User is not an admin';
    END IF;

    -- Insert audit log
    INSERT INTO admin_audit_logs (
        admin_id, action, target_table, target_id, 
        details, ip_address, user_agent
    ) VALUES (
        p_admin_id, p_action, p_target_table, p_target_id,
        p_details, p_ip_address, p_user_agent
    ) RETURNING id INTO v_log_id;

    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Create function to check if user is admin
CREATE OR REPLACE FUNCTION is_user_admin(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = p_user_id 
        AND is_admin = TRUE 
        AND disabled = FALSE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
