-- Create trade_coins table for P2P balance
CREATE TABLE IF NOT EXISTS trade_coins (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'locked', 'in_trade')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  source TEXT DEFAULT 'transfer', -- 'transfer' or 'trade_completion'
  reference_id UUID -- reference to transfer or trade
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_trade_coins_user_id ON trade_coins(user_id);
CREATE INDEX IF NOT EXISTS idx_trade_coins_status ON trade_coins(status);
CREATE INDEX IF NOT EXISTS idx_trade_coins_user_status ON trade_coins(user_id, status);

-- Enable RLS
ALTER TABLE trade_coins ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own trade coins"
  ON trade_coins FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own trade coins"
  ON trade_coins FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own trade coins"
  ON trade_coins FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own trade coins"
  ON trade_coins FOR DELETE
  USING (auth.uid() = user_id);

-- Create p2p_transfers table for logging transfers
CREATE TABLE IF NOT EXISTS p2p_transfers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  direction TEXT NOT NULL CHECK (direction IN ('to_p2p', 'from_p2p')),
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  coins_record_id UUID, -- reference to coins table record
  trade_coins_record_id UUID -- reference to trade_coins table record
);

-- Create index for transfers
CREATE INDEX IF NOT EXISTS idx_p2p_transfers_user_id ON p2p_transfers(user_id);
CREATE INDEX IF NOT EXISTS idx_p2p_transfers_created_at ON p2p_transfers(created_at DESC);

-- Enable RLS
ALTER TABLE p2p_transfers ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own transfers"
  ON p2p_transfers FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own transfers"
  ON p2p_transfers FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Function to get P2P balance from trade_coins table
CREATE OR REPLACE FUNCTION get_p2p_balance(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  v_balance NUMERIC;
BEGIN
  SELECT COALESCE(SUM(amount), 0)
  INTO v_balance
  FROM trade_coins
  WHERE user_id = p_user_id
    AND status = 'available';
  
  RETURN v_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to transfer coins from dashboard (coins table) to P2P (trade_coins table)
CREATE OR REPLACE FUNCTION transfer_to_p2p(p_user_id UUID, p_amount NUMERIC)
RETURNS JSONB AS $$
DECLARE
  v_dashboard_balance NUMERIC;
  v_coins_to_transfer RECORD;
  v_remaining_amount NUMERIC := p_amount;
  v_coins_record_id UUID;
  v_trade_coins_record_id UUID;
  v_transfer_id UUID;
BEGIN
  -- Validate amount
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transfer amount must be greater than 0';
  END IF;

  -- Get dashboard balance from coins table
  SELECT COALESCE(SUM(amount), 0)
  INTO v_dashboard_balance
  FROM coins
  WHERE user_id = p_user_id
    AND status = 'available';

  -- Check if user has sufficient balance
  IF v_dashboard_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient dashboard balance. Available: %, Requested: %', v_dashboard_balance, p_amount;
  END IF;

  -- Transfer coins from coins table to trade_coins table
  -- We'll deduct from coins table and add to trade_coins table
  FOR v_coins_to_transfer IN
    SELECT id, amount
    FROM coins
    WHERE user_id = p_user_id
      AND status = 'available'
    ORDER BY created_at ASC
  LOOP
    EXIT WHEN v_remaining_amount <= 0;

    IF v_coins_to_transfer.amount <= v_remaining_amount THEN
      -- Delete entire coin record
      DELETE FROM coins WHERE id = v_coins_to_transfer.id;
      v_remaining_amount := v_remaining_amount - v_coins_to_transfer.amount;
      v_coins_record_id := v_coins_to_transfer.id;
    ELSE
      -- Reduce coin amount
      UPDATE coins
      SET amount = amount - v_remaining_amount,
          updated_at = NOW()
      WHERE id = v_coins_to_transfer.id;
      v_coins_record_id := v_coins_to_transfer.id;
      v_remaining_amount := 0;
    END IF;
  END LOOP;

  -- Add to trade_coins table
  INSERT INTO trade_coins (user_id, amount, status, source)
  VALUES (p_user_id, p_amount, 'available', 'transfer')
  RETURNING id INTO v_trade_coins_record_id;

  -- Log the transfer
  INSERT INTO p2p_transfers (user_id, amount, direction, status, coins_record_id, trade_coins_record_id)
  VALUES (p_user_id, p_amount, 'to_p2p', 'completed', v_coins_record_id, v_trade_coins_record_id)
  RETURNING id INTO v_transfer_id;

  RETURN jsonb_build_object(
    'success', true,
    'transfer_id', v_transfer_id,
    'amount', p_amount,
    'new_dashboard_balance', get_dashboard_balance(p_user_id),
    'new_p2p_balance', get_p2p_balance(p_user_id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to transfer coins from P2P (trade_coins table) to dashboard (coins table)
CREATE OR REPLACE FUNCTION transfer_from_p2p(p_user_id UUID, p_amount NUMERIC)
RETURNS JSONB AS $$
DECLARE
  v_p2p_balance NUMERIC;
  v_trade_coins_to_transfer RECORD;
  v_remaining_amount NUMERIC := p_amount;
  v_coins_record_id UUID;
  v_trade_coins_record_id UUID;
  v_transfer_id UUID;
BEGIN
  -- Validate amount
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transfer amount must be greater than 0';
  END IF;

  -- Get P2P balance from trade_coins table
  v_p2p_balance := get_p2p_balance(p_user_id);

  -- Check if user has sufficient P2P balance
  IF v_p2p_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient P2P balance. Available: %, Requested: %', v_p2p_balance, p_amount;
  END IF;

  -- Transfer coins from trade_coins table to coins table
  FOR v_trade_coins_to_transfer IN
    SELECT id, amount
    FROM trade_coins
    WHERE user_id = p_user_id
      AND status = 'available'
    ORDER BY created_at ASC
  LOOP
    EXIT WHEN v_remaining_amount <= 0;

    IF v_trade_coins_to_transfer.amount <= v_remaining_amount THEN
      -- Delete entire trade coin record
      DELETE FROM trade_coins WHERE id = v_trade_coins_to_transfer.id;
      v_remaining_amount := v_remaining_amount - v_trade_coins_to_transfer.amount;
      v_trade_coins_record_id := v_trade_coins_to_transfer.id;
    ELSE
      -- Reduce trade coin amount
      UPDATE trade_coins
      SET amount = amount - v_remaining_amount,
          updated_at = NOW()
      WHERE id = v_trade_coins_to_transfer.id;
      v_trade_coins_record_id := v_trade_coins_to_transfer.id;
      v_remaining_amount := 0;
    END IF;
  END LOOP;

  -- Add to coins table
  INSERT INTO coins (user_id, amount, status, claim_type)
  VALUES (p_user_id, p_amount, 'available', 'transfer')
  RETURNING id INTO v_coins_record_id;

  -- Log the transfer
  INSERT INTO p2p_transfers (user_id, amount, direction, status, coins_record_id, trade_coins_record_id)
  VALUES (p_user_id, p_amount, 'from_p2p', 'completed', v_coins_record_id, v_trade_coins_record_id)
  RETURNING id INTO v_transfer_id;

  RETURN jsonb_build_object(
    'success', true,
    'transfer_id', v_transfer_id,
    'amount', p_amount,
    'new_dashboard_balance', get_dashboard_balance(p_user_id),
    'new_p2p_balance', get_p2p_balance(p_user_id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update initiate_p2p_trade_v2 to use trade_coins table instead of profiles.p2p_balance
CREATE OR REPLACE FUNCTION initiate_p2p_trade_v2(
  p_ad_id UUID,
  p_afx_amount NUMERIC,
  p_buyer_id UUID
)
RETURNS UUID AS $$
DECLARE
  v_ad RECORD;
  v_trade_id UUID;
  v_seller_p2p_balance NUMERIC;
BEGIN
  -- Get ad details
  SELECT * INTO v_ad
  FROM p2p_ads
  WHERE id = p_ad_id AND status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ad not found or not active';
  END IF;

  -- Prevent self-trading
  IF v_ad.user_id = p_buyer_id THEN
    RAISE EXCEPTION 'Cannot trade with yourself';
  END IF;

  -- Validate amount
  IF p_afx_amount < v_ad.min_amount OR p_afx_amount > v_ad.max_amount THEN
    RAISE EXCEPTION 'Amount must be between % and %', v_ad.min_amount, v_ad.max_amount;
  END IF;

  IF p_afx_amount > v_ad.remaining_amount THEN
    RAISE EXCEPTION 'Insufficient remaining amount in ad';
  END IF;

  -- Check seller's P2P balance from trade_coins table instead of profiles
  v_seller_p2p_balance := get_p2p_balance(v_ad.user_id);

  IF v_seller_p2p_balance < p_afx_amount THEN
    RAISE EXCEPTION 'Seller has insufficient P2P balance. Available: %, Required: %', v_seller_p2p_balance, p_afx_amount;
  END IF;

  -- Lock coins in trade_coins table (change status to 'in_trade')
  UPDATE trade_coins
  SET status = 'in_trade',
      updated_at = NOW()
  WHERE user_id = v_ad.user_id
    AND status = 'available'
    AND id IN (
      SELECT id FROM trade_coins
      WHERE user_id = v_ad.user_id AND status = 'available'
      ORDER BY created_at ASC
      LIMIT (
        SELECT COUNT(*) FROM trade_coins
        WHERE user_id = v_ad.user_id
          AND status = 'available'
          AND amount <= p_afx_amount
      )
    );

  -- Create trade
  INSERT INTO p2p_trades (
    ad_id,
    buyer_id,
    seller_id,
    afx_amount,
    status,
    escrow_amount,
    expires_at
  ) VALUES (
    p_ad_id,
    p_buyer_id,
    v_ad.user_id,
    p_afx_amount,
    'pending',
    p_afx_amount,
    NOW() + INTERVAL '30 minutes'
  ) RETURNING id INTO v_trade_id;

  -- Update ad remaining amount
  UPDATE p2p_ads
  SET remaining_amount = remaining_amount - p_afx_amount,
      status = CASE
        WHEN remaining_amount - p_afx_amount <= 0 THEN 'completed'
        ELSE status
      END
  WHERE id = p_ad_id;

  -- Log trade initiation
  INSERT INTO trade_logs (trade_id, user_id, action, amount, details)
  VALUES (
    v_trade_id,
    v_ad.user_id,
    'trade_initiated',
    p_afx_amount,
    jsonb_build_object(
      'buyer_id', p_buyer_id,
      'seller_id', v_ad.user_id,
      'escrow_amount', p_afx_amount
    )
  );

  RETURN v_trade_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
