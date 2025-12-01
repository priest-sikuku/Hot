-- Add admin dispute resolution function
CREATE OR REPLACE FUNCTION admin_resolve_dispute(
  p_admin_id UUID,
  p_trade_id UUID,
  p_favor_buyer BOOLEAN,
  p_resolution_notes TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trade RECORD;
  v_result JSONB;
BEGIN
  -- Check admin permission
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  -- Get trade details
  SELECT * INTO v_trade
  FROM p2p_trades
  WHERE id = p_trade_id AND status = 'disputed';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trade not found or not in disputed status';
  END IF;

  -- Resolve dispute based on decision
  IF p_favor_buyer THEN
    -- Release coins to buyer
    UPDATE p2p_trades
    SET 
      status = 'completed',
      released_at = NOW(),
      dispute_resolved_by = p_admin_id,
      dispute_resolved_at = NOW(),
      dispute_resolution_notes = p_resolution_notes
    WHERE id = p_trade_id;

    -- Transfer coins from escrow to buyer
    UPDATE trade_coins
    SET status = 'available', locked_for_trade_id = NULL
    WHERE locked_for_trade_id = p_trade_id AND user_id = v_trade.buyer_id;

    -- Log transaction
    INSERT INTO transactions (user_id, amount, type, status, description)
    VALUES (v_trade.buyer_id, v_trade.afx_amount, 'p2p_receive', 'completed', 
            'Dispute resolved in favor of buyer - Trade #' || SUBSTRING(p_trade_id::TEXT, 1, 8));

  ELSE
    -- Refund coins to seller
    UPDATE p2p_trades
    SET 
      status = 'refunded',
      dispute_resolved_by = p_admin_id,
      dispute_resolved_at = NOW(),
      dispute_resolution_notes = p_resolution_notes
    WHERE id = p_trade_id;

    -- Return coins to seller
    UPDATE trade_coins
    SET status = 'available', locked_for_trade_id = NULL
    WHERE locked_for_trade_id = p_trade_id AND user_id = v_trade.seller_id;

    -- Log transaction
    INSERT INTO transactions (user_id, amount, type, status, description)
    VALUES (v_trade.seller_id, v_trade.afx_amount, 'p2p_refund', 'completed', 
            'Dispute resolved in favor of seller - Trade #' || SUBSTRING(p_trade_id::TEXT, 1, 8));
  END IF;

  -- Log admin action
  PERFORM log_admin_action(
    p_admin_id,
    'DISPUTE_RESOLVED',
    'p2p_trades',
    p_trade_id,
    jsonb_build_object(
      'favor_buyer', p_favor_buyer,
      'resolution_notes', p_resolution_notes,
      'trade_id', p_trade_id
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Dispute resolved successfully',
    'trade_id', p_trade_id,
    'resolved_in_favor_of', CASE WHEN p_favor_buyer THEN 'buyer' ELSE 'seller' END
  );
END;
$$;
