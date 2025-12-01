-- Fix AFX Price Policies and Verify Balance System
-- This script handles existing policies gracefully and ensures balance tracking works

-- ============================================================================
-- PART 1: Fix Price Table Policies (Handle Existing Policies)
-- ============================================================================

-- Drop existing policies if they exist
DO $$ 
BEGIN
    -- Drop policies on afx_current_price
    IF EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'afx_current_price' 
        AND policyname = 'Anyone can read current price'
    ) THEN
        DROP POLICY "Anyone can read current price" ON afx_current_price;
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'afx_current_price' 
        AND policyname = 'Service role can update price'
    ) THEN
        DROP POLICY "Service role can update price" ON afx_current_price;
    END IF;

    -- Drop policies on afx_price_history
    IF EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'afx_price_history' 
        AND policyname = 'Anyone can read price history'
    ) THEN
        DROP POLICY "Anyone can read price history" ON afx_price_history;
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'afx_price_history' 
        AND policyname = 'Service role can insert price history'
    ) THEN
        DROP POLICY "Service role can insert price history" ON afx_price_history;
    END IF;
END $$;

-- Recreate policies
CREATE POLICY "Anyone can read current price"
    ON afx_current_price FOR SELECT
    USING (true);

CREATE POLICY "Service role can update price"
    ON afx_current_price FOR ALL
    USING (true);

CREATE POLICY "Anyone can read price history"
    ON afx_price_history FOR SELECT
    USING (true);

CREATE POLICY "Service role can insert price history"
    ON afx_price_history FOR INSERT
    WITH CHECK (true);

-- ============================================================================
-- PART 2: Ensure Balance Functions Are Correct
-- ============================================================================

-- Drop and recreate get_user_balance function
DROP FUNCTION IF EXISTS get_user_balance(UUID);

CREATE OR REPLACE FUNCTION get_user_balance(user_id_param UUID)
RETURNS NUMERIC AS $$
DECLARE
    total_balance NUMERIC;
BEGIN
    -- Sum all available coins for the user
    SELECT COALESCE(SUM(amount), 0)
    INTO total_balance
    FROM coins
    WHERE user_id = user_id_param
    AND status = 'available';
    
    RETURN total_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and recreate get_available_balance function
DROP FUNCTION IF EXISTS get_available_balance(UUID);

CREATE OR REPLACE FUNCTION get_available_balance(user_id_param UUID)
RETURNS NUMERIC AS $$
DECLARE
    total_balance NUMERIC;
    locked_balance NUMERIC;
BEGIN
    -- Get total balance
    SELECT COALESCE(SUM(amount), 0)
    INTO total_balance
    FROM coins
    WHERE user_id = user_id_param
    AND status = 'available';
    
    -- Get locked balance from active P2P trades
    SELECT COALESCE(SUM(afx_amount), 0)
    INTO locked_balance
    FROM p2p_trades
    WHERE seller_id = user_id_param
    AND status IN ('pending', 'paid', 'in_escrow');
    
    RETURN total_balance - locked_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and recreate get_locked_balance function
DROP FUNCTION IF EXISTS get_locked_balance(UUID);

CREATE OR REPLACE FUNCTION get_locked_balance(user_id_param UUID)
RETURNS NUMERIC AS $$
DECLARE
    locked_balance NUMERIC;
BEGIN
    -- Get locked balance from active P2P trades
    SELECT COALESCE(SUM(afx_amount), 0)
    INTO locked_balance
    FROM p2p_trades
    WHERE seller_id = user_id_param
    AND status IN ('pending', 'paid', 'in_escrow');
    
    RETURN locked_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 3: Verify Mining Reward Storage
-- ============================================================================

-- Ensure mining rewards are properly stored in coins table
-- This function is called by the mining action
DROP FUNCTION IF EXISTS record_mining_reward(UUID, NUMERIC);

CREATE OR REPLACE FUNCTION record_mining_reward(
    user_id_param UUID,
    amount_param NUMERIC
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Insert mining reward into coins table
    INSERT INTO coins (user_id, amount, claim_type, status, created_at)
    VALUES (
        user_id_param,
        amount_param,
        'mining',
        'available',
        NOW()
    );
    
    -- Update profile's last_mine and next_mine
    UPDATE profiles
    SET 
        last_mine = NOW(),
        next_mine = NOW() + INTERVAL '3 hours',
        updated_at = NOW()
    WHERE id = user_id_param;
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 4: Create Indexes for Performance
-- ============================================================================

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_coins_user_status ON coins(user_id, status);
CREATE INDEX IF NOT EXISTS idx_coins_claim_type ON coins(claim_type);
CREATE INDEX IF NOT EXISTS idx_p2p_trades_seller_status ON p2p_trades(seller_id, status);
CREATE INDEX IF NOT EXISTS idx_profiles_mining ON profiles(last_mine, next_mine);

-- ============================================================================
-- PART 5: Initialize Price Data (If Empty)
-- ============================================================================

-- Insert initial price if table is empty
INSERT INTO afx_current_price (id, price, previous_price, change_percent, updated_at)
SELECT 1, 16.29, 16.29, 0, NOW()
WHERE NOT EXISTS (SELECT 1 FROM afx_current_price WHERE id = 1);

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify functions exist
SELECT 
    'get_user_balance' as function_name,
    EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_user_balance') as exists
UNION ALL
SELECT 
    'get_available_balance',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_available_balance')
UNION ALL
SELECT 
    'get_locked_balance',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'get_locked_balance')
UNION ALL
SELECT 
    'record_mining_reward',
    EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'record_mining_reward');

-- Verify policies exist
SELECT 
    schemaname,
    tablename,
    policyname
FROM pg_policies
WHERE tablename IN ('afx_current_price', 'afx_price_history')
ORDER BY tablename, policyname;
