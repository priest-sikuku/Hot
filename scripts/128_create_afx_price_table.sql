-- =====================================================
-- AFX PRICE TRACKING TABLE
-- =====================================================
-- Creates the missing afx_current_price table referenced by other scripts

CREATE TABLE IF NOT EXISTS afx_current_price (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    price_usd NUMERIC(10, 6) NOT NULL DEFAULT 0.10,
    price_kes NUMERIC(10, 2) NOT NULL DEFAULT 13.00,
    last_updated TIMESTAMP DEFAULT NOW(),
    updated_by TEXT DEFAULT 'system',
    change_24h NUMERIC(10, 2) DEFAULT 0,
    volume_24h NUMERIC(15, 2) DEFAULT 0
);

-- Insert initial price
INSERT INTO afx_current_price (price_usd, price_kes, last_updated)
VALUES (0.10, 13.00, NOW())
ON CONFLICT DO NOTHING;

-- Create index for quick lookups
CREATE INDEX IF NOT EXISTS idx_afx_current_price_updated ON afx_current_price(last_updated DESC);

-- Enable RLS
ALTER TABLE afx_current_price ENABLE ROW LEVEL SECURITY;

-- Allow everyone to read prices
DROP POLICY IF EXISTS "Anyone can view AFX prices" ON afx_current_price;
CREATE POLICY "Anyone can view AFX prices"
ON afx_current_price FOR SELECT
TO authenticated
USING (true);

-- Only admins can update prices
DROP POLICY IF EXISTS "Only admins can update prices" ON afx_current_price;
CREATE POLICY "Only admins can update prices"
ON afx_current_price FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE profiles.id = auth.uid() 
        AND profiles.is_admin = TRUE
    )
);

-- Function to get current AFX price
CREATE OR REPLACE FUNCTION get_current_afx_price()
RETURNS NUMERIC AS $$
DECLARE
    v_price NUMERIC;
BEGIN
    SELECT price_usd INTO v_price
    FROM afx_current_price
    ORDER BY last_updated DESC
    LIMIT 1;
    
    RETURN COALESCE(v_price, 0.10);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update AFX price (admin only)
CREATE OR REPLACE FUNCTION update_afx_price(
    p_admin_id UUID,
    p_price_usd NUMERIC,
    p_price_kes NUMERIC DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_old_price NUMERIC;
    v_new_price_kes NUMERIC;
BEGIN
    -- Verify admin
    IF NOT is_user_admin(p_admin_id) THEN
        RAISE EXCEPTION 'Unauthorized: User is not an admin';
    END IF;

    -- Get old price
    SELECT price_usd INTO v_old_price FROM afx_current_price ORDER BY last_updated DESC LIMIT 1;

    -- Calculate KES price if not provided (assuming 1 USD = 130 KES)
    v_new_price_kes := COALESCE(p_price_kes, p_price_usd * 130);

    -- Insert new price record
    INSERT INTO afx_current_price (price_usd, price_kes, updated_by, last_updated)
    VALUES (p_price_usd, v_new_price_kes, p_admin_id::TEXT, NOW());

    -- Log action
    PERFORM log_admin_action(
        p_admin_id,
        'UPDATE_AFX_PRICE',
        'afx_current_price',
        NULL,
        jsonb_build_object('old_price', v_old_price, 'new_price', p_price_usd),
        NULL,
        NULL
    );

    RETURN jsonb_build_object(
        'success', true,
        'old_price', v_old_price,
        'new_price', p_price_usd,
        'price_kes', v_new_price_kes
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_current_afx_price() TO authenticated;
GRANT EXECUTE ON FUNCTION update_afx_price(UUID, NUMERIC, NUMERIC) TO authenticated;
