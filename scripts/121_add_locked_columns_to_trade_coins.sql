-- Add missing locked_at and locked_for_trade_id columns to trade_coins table
-- These columns are needed for the initiate_p2p_trade_v2 function to lock coins during trades

-- Add locked_at column to track when coins were locked
ALTER TABLE trade_coins 
ADD COLUMN IF NOT EXISTS locked_at TIMESTAMP WITH TIME ZONE;

-- Add locked_for_trade_id column to reference which trade the coins are locked for
ALTER TABLE trade_coins 
ADD COLUMN IF NOT EXISTS locked_for_trade_id UUID REFERENCES p2p_trades(id) ON DELETE SET NULL;

-- Create index for faster queries on locked trades
CREATE INDEX IF NOT EXISTS idx_trade_coins_locked_for_trade ON trade_coins(locked_for_trade_id) WHERE locked_for_trade_id IS NOT NULL;

-- Add comment
COMMENT ON COLUMN trade_coins.locked_at IS 'Timestamp when coins were locked for a trade';
COMMENT ON COLUMN trade_coins.locked_for_trade_id IS 'Reference to the trade that locked these coins';
