-- =====================================================
-- P2P DISPUTE SYSTEM
-- =====================================================

-- Add dispute tracking columns to p2p_trades
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS disputed_by UUID REFERENCES profiles(id);
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS disputed_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS dispute_reason TEXT;
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS dispute_resolved_by UUID REFERENCES profiles(id);
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS dispute_resolved_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE p2p_trades ADD COLUMN IF NOT EXISTS dispute_resolution_notes TEXT;

-- Create function to raise a dispute
CREATE OR REPLACE FUNCTION raise_p2p_dispute(
  p_trade_id UUID,
  p_user_id UUID,
  p_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trade p2p_trades%ROWTYPE;
BEGIN
  -- Get trade details
  SELECT * INTO v_trade
  FROM p2p_trades
  WHERE id = p_trade_id 
    AND (buyer_id = p_user_id OR seller_id = p_user_id);

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trade not found or you are not authorized';
  END IF;

  -- Can only dispute trades that are in progress
  IF v_trade.status NOT IN ('pending', 'escrowed', 'payment_sent') THEN
    RAISE EXCEPTION 'Cannot dispute a trade with status: %', v_trade.status;
  END IF;

  -- Check if already disputed
  IF v_trade.status = 'disputed' THEN
    RAISE EXCEPTION 'Trade is already disputed';
  END IF;

  -- Update trade to disputed status
  UPDATE p2p_trades
  SET 
    status = 'disputed',
    disputed_by = p_user_id,
    disputed_at = NOW(),
    dispute_reason = p_reason,
    updated_at = NOW()
  WHERE id = p_trade_id;

  -- Log the dispute action
  INSERT INTO trade_logs (trade_id, user_id, action, amount, details)
  VALUES (
    p_trade_id, 
    p_user_id, 
    'trade_disputed', 
    v_trade.afx_amount,
    jsonb_build_object(
      'reason', p_reason,
      'disputed_by_role', CASE WHEN p_user_id = v_trade.buyer_id THEN 'buyer' ELSE 'seller' END
    )
  );

  -- Send notification transaction
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES (
    p_user_id, 
    'p2p_dispute', 
    0, 
    'Raised dispute for P2P trade', 
    p_trade_id, 
    'pending'
  );

  -- Notify the other party
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES (
    CASE WHEN p_user_id = v_trade.buyer_id THEN v_trade.seller_id ELSE v_trade.buyer_id END,
    'p2p_dispute_notification',
    0,
    'Your P2P trade has been disputed - Admin will review',
    p_trade_id,
    'pending'
  );

END;
$$;

-- Create function to resolve a dispute (admin only)
CREATE OR REPLACE FUNCTION resolve_p2p_dispute(
  p_trade_id UUID,
  p_admin_id UUID,
  p_resolution TEXT,
  p_winner TEXT -- 'buyer' or 'seller' or 'cancel'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trade p2p_trades%ROWTYPE;
  v_is_admin BOOLEAN;
BEGIN
  -- Check if user is admin
  SELECT is_admin INTO v_is_admin
  FROM profiles
  WHERE id = p_admin_id;

  IF v_is_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'Only admins can resolve disputes';
  END IF;

  -- Get trade details
  SELECT * INTO v_trade
  FROM p2p_trades
  WHERE id = p_trade_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trade not found';
  END IF;

  IF v_trade.status != 'disputed' THEN
    RAISE EXCEPTION 'Trade is not in disputed status';
  END IF;

  -- Resolve based on winner
  IF p_winner = 'buyer' THEN
    -- Release coins to buyer
    UPDATE coins
    SET status = 'available',
        user_id = v_trade.buyer_id,
        updated_at = NOW()
    WHERE user_id = v_trade.seller_id
      AND status = 'locked'
      AND id IN (
        SELECT id FROM coins
        WHERE user_id = v_trade.seller_id AND status = 'locked'
        ORDER BY created_at
        LIMIT (SELECT COUNT(*) FROM coins WHERE user_id = v_trade.seller_id AND status = 'locked' AND amount <= v_trade.afx_amount)
      );

    UPDATE p2p_trades
    SET 
      status = 'completed',
      dispute_resolved_by = p_admin_id,
      dispute_resolved_at = NOW(),
      dispute_resolution_notes = p_resolution,
      coins_released_at = NOW(),
      updated_at = NOW()
    WHERE id = p_trade_id;

    INSERT INTO transactions (user_id, type, amount, description, related_id, status)
    VALUES 
      (v_trade.buyer_id, 'p2p_buy', v_trade.afx_amount, 'Received AFX from disputed trade (admin resolution)', p_trade_id, 'completed'),
      (v_trade.seller_id, 'p2p_sell', -v_trade.afx_amount, 'Sold AFX in disputed trade (admin resolution)', p_trade_id, 'completed');

  ELSIF p_winner = 'seller' THEN
    -- Return coins to seller
    UPDATE coins
    SET status = 'available',
        updated_at = NOW()
    WHERE user_id = v_trade.seller_id
      AND status = 'locked'
      AND id IN (
        SELECT id FROM coins
        WHERE user_id = v_trade.seller_id AND status = 'locked'
        ORDER BY created_at
        LIMIT (SELECT COUNT(*) FROM coins WHERE user_id = v_trade.seller_id AND status = 'locked' AND amount <= v_trade.afx_amount)
      );

    -- Return amount to ad
    IF v_trade.ad_id IS NOT NULL THEN
      UPDATE p2p_ads
      SET remaining_amount = remaining_amount + v_trade.afx_amount,
          updated_at = NOW()
      WHERE id = v_trade.ad_id;
    END IF;

    UPDATE p2p_trades
    SET 
      status = 'cancelled',
      dispute_resolved_by = p_admin_id,
      dispute_resolved_at = NOW(),
      dispute_resolution_notes = p_resolution,
      updated_at = NOW()
    WHERE id = p_trade_id;

    INSERT INTO transactions (user_id, type, amount, description, related_id, status)
    VALUES (v_trade.seller_id, 'p2p_refund', v_trade.afx_amount, 'Coins returned from disputed trade (admin resolution)', p_trade_id, 'completed');

  ELSE -- cancel
    -- Return coins to seller and cancel
    UPDATE coins
    SET status = 'available',
        updated_at = NOW()
    WHERE user_id = v_trade.seller_id
      AND status = 'locked'
      AND id IN (
        SELECT id FROM coins
        WHERE user_id = v_trade.seller_id AND status = 'locked'
        ORDER BY created_at
        LIMIT (SELECT COUNT(*) FROM coins WHERE user_id = v_trade.seller_id AND status = 'locked' AND amount <= v_trade.afx_amount)
      );

    IF v_trade.ad_id IS NOT NULL THEN
      UPDATE p2p_ads
      SET remaining_amount = remaining_amount + v_trade.afx_amount,
          updated_at = NOW()
      WHERE id = v_trade.ad_id;
    END IF;

    UPDATE p2p_trades
    SET 
      status = 'cancelled',
      dispute_resolved_by = p_admin_id,
      dispute_resolved_at = NOW(),
      dispute_resolution_notes = p_resolution,
      updated_at = NOW()
    WHERE id = p_trade_id;

    INSERT INTO transactions (user_id, type, amount, description, related_id, status)
    VALUES (v_trade.seller_id, 'p2p_refund', v_trade.afx_amount, 'Coins returned from disputed trade (admin cancellation)', p_trade_id, 'completed');
  END IF;

  -- Log resolution
  INSERT INTO trade_logs (trade_id, user_id, action, amount, details)
  VALUES (
    p_trade_id, 
    p_admin_id, 
    'dispute_resolved', 
    v_trade.afx_amount,
    jsonb_build_object(
      'winner', p_winner,
      'resolution', p_resolution
    )
  );

END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION raise_p2p_dispute(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION resolve_p2p_dispute(UUID, UUID, TEXT, TEXT) TO authenticated;

-- Create index for disputed trades
CREATE INDEX IF NOT EXISTS idx_p2p_trades_disputed ON p2p_trades(status, disputed_at) WHERE status = 'disputed';

COMMENT ON FUNCTION raise_p2p_dispute IS 'Allows buyer or seller to raise a dispute - returns funds to escrow and blocks trade completion';
COMMENT ON FUNCTION resolve_p2p_dispute IS 'Admin function to resolve disputes by awarding coins to buyer, seller, or cancelling the trade';
