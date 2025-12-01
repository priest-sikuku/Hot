-- Add trade messages table for in-trade chat
CREATE TABLE IF NOT EXISTS trade_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_id UUID NOT NULL REFERENCES trades(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_trade_messages_trade_id ON trade_messages(trade_id);
CREATE INDEX IF NOT EXISTS idx_trade_messages_created_at ON trade_messages(created_at);

-- Add expires_at column to trades table
ALTER TABLE trades ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE;

-- Add expires_at column to listings table
ALTER TABLE listings ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE;

-- Update existing trades to expire 30 minutes from creation
UPDATE trades 
SET expires_at = created_at + INTERVAL '30 minutes'
WHERE expires_at IS NULL AND status NOT IN ('completed', 'cancelled');

-- Update existing listings to expire 3 days from creation
UPDATE listings 
SET expires_at = created_at + INTERVAL '3 days'
WHERE expires_at IS NULL AND status = 'active';

-- Function to auto-expire trades after 30 minutes
CREATE OR REPLACE FUNCTION expire_old_trades()
RETURNS void AS $$
BEGIN
  UPDATE trades
  SET status = 'expired'
  WHERE status IN ('pending', 'payment_pending', 'escrow')
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to auto-expire listings after 3 days
CREATE OR REPLACE FUNCTION expire_old_listings()
RETURNS void AS $$
BEGIN
  UPDATE listings
  SET status = 'expired'
  WHERE status = 'active'
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Enable Row Level Security
ALTER TABLE trade_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for trade_messages
CREATE POLICY "Users can view messages in their trades"
  ON trade_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM trades
      WHERE trades.id = trade_messages.trade_id
        AND (trades.buyer_id = auth.uid() OR trades.seller_id = auth.uid())
    )
  );

CREATE POLICY "Users can send messages in their trades"
  ON trade_messages FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM trades
      WHERE trades.id = trade_messages.trade_id
        AND (trades.buyer_id = auth.uid() OR trades.seller_id = auth.uid())
    )
    AND sender_id = auth.uid()
  );
