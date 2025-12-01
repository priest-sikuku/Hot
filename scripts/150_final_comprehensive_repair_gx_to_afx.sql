-- =====================================================
-- FINAL COMPREHENSIVE REPAIR: GX → AFX MIGRATION
-- =====================================================
-- This script fixes all remaining database inconsistencies
-- and ensures complete rebranding from GX to AFX
-- =====================================================

-- PART 1: VERIFY AND RENAME TABLES (if not already done)
-- =====================================================

DO $$
BEGIN
  -- Check and rename price tables
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'gx_current_price') THEN
    ALTER TABLE gx_current_price RENAME TO afx_current_price;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'gx_price_history') THEN
    ALTER TABLE gx_price_history RENAME TO afx_price_history;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'gx_price_references') THEN
    ALTER TABLE gx_price_references RENAME TO afx_price_references;
  END IF;
END $$;

-- PART 2: FIX P2P_ADS TABLE COLUMNS
-- =====================================================

DO $$
BEGIN
  -- Rename gx_amount to afx_amount if it still exists
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'p2p_ads' AND column_name = 'gx_amount'
  ) THEN
    ALTER TABLE p2p_ads RENAME COLUMN gx_amount TO afx_amount;
  END IF;
  
  -- Rename price_per_gx to price_per_afx if it still exists
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'p2p_ads' AND column_name = 'price_per_gx'
  ) THEN
    ALTER TABLE p2p_ads RENAME COLUMN price_per_gx TO price_per_afx;
  END IF;
  
  -- Ensure afx_amount column exists and add if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'p2p_ads' AND column_name = 'afx_amount'
  ) THEN
    ALTER TABLE p2p_ads ADD COLUMN afx_amount NUMERIC NOT NULL DEFAULT 0;
  END IF;
  
  -- Ensure price_per_afx column exists and add if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'p2p_ads' AND column_name = 'price_per_afx'
  ) THEN
    ALTER TABLE p2p_ads ADD COLUMN price_per_afx NUMERIC;
  END IF;
END $$;

-- PART 3: FIX P2P_TRADES TABLE COLUMNS
-- =====================================================

DO $$
BEGIN
  -- Rename gx_amount to afx_amount if it still exists
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'p2p_trades' AND column_name = 'gx_amount'
  ) THEN
    ALTER TABLE p2p_trades RENAME COLUMN gx_amount TO afx_amount;
  END IF;
  
  -- Ensure afx_amount column exists and add if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'p2p_trades' AND column_name = 'afx_amount'
  ) THEN
    ALTER TABLE p2p_trades ADD COLUMN afx_amount NUMERIC NOT NULL DEFAULT 0;
  END IF;
END $$;

-- PART 4: DROP ORPHANED CONSTRAINTS
-- =====================================================

DO $$
BEGIN
  -- Drop old check constraint if it exists
  ALTER TABLE IF EXISTS p2p_ads DROP CONSTRAINT IF EXISTS check_min_gx_amount;
  ALTER TABLE IF EXISTS p2p_ads DROP CONSTRAINT IF EXISTS check_min_trade_amount;
  ALTER TABLE IF EXISTS p2p_trades DROP CONSTRAINT IF EXISTS check_min_gx_amount;
END $$;

-- PART 5: ADD PROPER CONSTRAINTS TO AFX COLUMNS
-- =====================================================

DO $$
BEGIN
  -- Add check constraint for afx_amount minimum on p2p_ads
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'check_min_afx_amount' AND table_name = 'p2p_ads'
  ) THEN
    ALTER TABLE p2p_ads ADD CONSTRAINT check_min_afx_amount CHECK (afx_amount >= 5);
  END IF;
  
  -- Add check constraint for afx_amount minimum on p2p_trades
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'check_min_afx_trade_amount' AND table_name = 'p2p_trades'
  ) THEN
    ALTER TABLE p2p_trades ADD CONSTRAINT check_min_afx_trade_amount CHECK (afx_amount >= 1);
  END IF;
END $$;

-- PART 6: FIX REMAINING DATA INCONSISTENCIES
-- =====================================================

-- Ensure all ads have remaining_amount set
UPDATE p2p_ads 
SET remaining_amount = afx_amount 
WHERE remaining_amount IS NULL OR remaining_amount = 0;

-- Ensure price_per_afx is set (default to 0 if missing)
UPDATE p2p_ads 
SET price_per_afx = 0 
WHERE price_per_afx IS NULL;

-- PART 7: RECREATE VIEWS WITH AFX NAMING
-- =====================================================

DROP VIEW IF EXISTS v_current_gx_price;
DROP VIEW IF EXISTS v_current_afx_price;

CREATE VIEW v_current_afx_price AS
SELECT 
  price as current_price,
  previous_price,
  change_percent,
  updated_at,
  (EXTRACT(EPOCH FROM (NOW() - updated_at)) > 3600) AS needs_update
FROM afx_current_price
ORDER BY updated_at DESC
LIMIT 1;

-- PART 8: GRANT PERMISSIONS ON AFX TABLES AND VIEWS
-- =====================================================

GRANT SELECT ON afx_current_price TO authenticated;
GRANT SELECT ON afx_price_history TO authenticated;
GRANT SELECT ON afx_price_references TO authenticated;
GRANT SELECT ON v_current_afx_price TO authenticated;

-- PART 9: UPDATE COMMENTS TO REFLECT REBRANDING
-- =====================================================

COMMENT ON TABLE afx_current_price IS 'Current AFX price (rebranded from GX)';
COMMENT ON TABLE afx_price_history IS 'AFX price history (rebranded from GX)';
COMMENT ON TABLE afx_price_references IS 'AFX price references (rebranded from GX)';
COMMENT ON COLUMN p2p_ads.afx_amount IS 'Amount of AFX in this ad (rebranded from gx_amount)';
COMMENT ON COLUMN p2p_ads.price_per_afx IS 'Price per AFX (rebranded from price_per_gx)';
COMMENT ON COLUMN p2p_trades.afx_amount IS 'Amount of AFX in this trade (rebranded from gx_amount)';

-- =====================================================
-- VERIFICATION AND COMPLETION
-- =====================================================

-- Verify all GX references are gone from column names
SELECT COUNT(*) as orphaned_gx_columns
FROM information_schema.columns
WHERE column_name LIKE '%gx%' 
  AND table_name IN ('p2p_ads', 'p2p_trades');

-- This script is now complete. All GX references should be AFX.
