-- Add trade messages table for chat functionality
CREATE TABLE IF NOT EXISTS trade_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_id UUID NOT NULL REFERENCES p2p_trades(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_trade_messages_trade_id ON trade_messages(trade_id);
CREATE INDEX IF NOT EXISTS idx_trade_messages_created_at ON trade_messages(created_at);

-- Enable RLS
ALTER TABLE trade_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for trade_messages
CREATE POLICY "Users can view messages in their trades"
  ON trade_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM p2p_trades
      WHERE p2p_trades.id = trade_messages.trade_id
      AND (p2p_trades.buyer_id = auth.uid() OR p2p_trades.seller_id = auth.uid())
    )
  );

CREATE POLICY "Users can send messages in their trades"
  ON trade_messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM p2p_trades
      WHERE p2p_trades.id = trade_messages.trade_id
      AND (p2p_trades.buyer_id = auth.uid() OR p2p_trades.seller_id = auth.uid())
    )
  );

-- Update initiate_p2p_trade function to prevent self-trading
CREATE OR REPLACE FUNCTION initiate_p2p_trade(
  p_ad_id UUID,
  p_buyer_id UUID,
  p_seller_id UUID,
  p_gx_amount NUMERIC
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trade_id UUID;
  v_seller_balance NUMERIC;
BEGIN
  -- Prevent self-trading
  IF p_buyer_id = p_seller_id THEN
    RAISE EXCEPTION 'You cannot trade with yourself';
  END IF;

  -- Check if seller has enough balance
  SELECT total_mined INTO v_seller_balance
  FROM profiles
  WHERE id = p_seller_id;

  IF v_seller_balance IS NULL OR v_seller_balance < p_gx_amount THEN
    RAISE EXCEPTION 'Seller does not have enough GX balance';
  END IF;

  -- Deduct from seller's balance (move to escrow)
  UPDATE profiles
  SET total_mined = total_mined - p_gx_amount,
      updated_at = NOW()
  WHERE id = p_seller_id;

  -- Create trade record
  INSERT INTO p2p_trades (
    ad_id,
    buyer_id,
    seller_id,
    gx_amount,
    escrow_amount,
    status,
    expires_at
  ) VALUES (
    p_ad_id,
    p_buyer_id,
    p_seller_id,
    p_gx_amount,
    p_gx_amount,
    'escrowed',
    NOW() + INTERVAL '30 minutes'
  )
  RETURNING id INTO v_trade_id;

  RETURN v_trade_id;
END;
$$;
