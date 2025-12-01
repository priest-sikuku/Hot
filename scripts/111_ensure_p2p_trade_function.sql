-- Ensure initiate_p2p_trade_v2 function exists
-- This function is needed for P2P trade initiation

DROP FUNCTION IF EXISTS initiate_p2p_trade_v2(uuid, uuid, numeric);

CREATE OR REPLACE FUNCTION initiate_p2p_trade_v2(
  p_ad_id uuid,
  p_buyer_id uuid,
  p_afx_amount numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ad p2p_ads%ROWTYPE;
  v_seller_id uuid;
  v_trade_id uuid;
  v_seller_balance numeric;
  v_coins_to_lock numeric;
BEGIN
  -- Get ad details
  SELECT * INTO v_ad
  FROM p2p_ads
  WHERE id = p_ad_id
    AND status = 'active'
    AND expires_at > NOW();
    
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ad not found or expired';
  END IF;
  
  -- Validate amount
  IF p_afx_amount < v_ad.min_amount OR p_afx_amount > v_ad.max_amount THEN
    RAISE EXCEPTION 'Amount must be between % and %', v_ad.min_amount, v_ad.max_amount;
  END IF;
  
  IF p_afx_amount > v_ad.remaining_amount THEN
    RAISE EXCEPTION 'Insufficient remaining amount in ad';
  END IF;
  
  -- Determine seller based on ad type
  IF v_ad.ad_type = 'sell' THEN
    v_seller_id := v_ad.user_id;
    
    -- Check seller has enough balance
    SELECT COALESCE(SUM(amount), 0) INTO v_seller_balance
    FROM coins
    WHERE user_id = v_seller_id AND status = 'available';
    
    IF v_seller_balance < p_afx_amount THEN
      RAISE EXCEPTION 'Seller has insufficient balance';
    END IF;
    
    -- Lock seller's coins in escrow by updating status
    v_coins_to_lock := p_afx_amount;
    
    UPDATE coins
    SET status = 'locked',
        updated_at = NOW()
    WHERE id IN (
      SELECT id FROM coins
      WHERE user_id = v_seller_id 
        AND status = 'available'
      ORDER BY created_at
      FOR UPDATE
    )
    AND v_coins_to_lock > 0
    RETURNING amount INTO v_coins_to_lock;
      
  ELSE -- buy ad (buyer is actually selling their AFX)
    v_seller_id := p_buyer_id;
    
    -- Check seller (who is responding to buy ad) has enough balance
    SELECT COALESCE(SUM(amount), 0) INTO v_seller_balance
    FROM coins
    WHERE user_id = v_seller_id AND status = 'available';
    
    IF v_seller_balance < p_afx_amount THEN
      RAISE EXCEPTION 'You have insufficient balance to sell';
    END IF;
    
    -- Lock seller's coins in escrow
    v_coins_to_lock := p_afx_amount;
    
    UPDATE coins
    SET status = 'locked',
        updated_at = NOW()
    WHERE id IN (
      SELECT id FROM coins
      WHERE user_id = v_seller_id 
        AND status = 'available'
      ORDER BY created_at
      FOR UPDATE
    )
    AND v_coins_to_lock > 0;
  END IF;
  
  -- Create trade
  INSERT INTO p2p_trades (
    ad_id,
    buyer_id,
    seller_id,
    afx_amount,
    escrow_amount,
    status,
    expires_at
  ) VALUES (
    p_ad_id,
    p_buyer_id,
    v_seller_id,
    p_afx_amount,
    p_afx_amount,
    'pending',
    NOW() + INTERVAL '30 minutes'
  )
  RETURNING id INTO v_trade_id;
  
  -- Update ad remaining amount
  UPDATE p2p_ads
  SET remaining_amount = remaining_amount - p_afx_amount,
      updated_at = NOW()
  WHERE id = p_ad_id;
  
  -- Create transaction records
  INSERT INTO transactions (user_id, type, amount, description, status, related_id)
  VALUES 
    (v_seller_id, 'p2p_escrow', -p_afx_amount, 'AFX locked in P2P escrow', 'pending', v_trade_id),
    (p_buyer_id, 'p2p_pending', p_afx_amount, 'P2P trade initiated', 'pending', v_trade_id);
  
  RETURN v_trade_id;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION initiate_p2p_trade_v2(uuid, uuid, numeric) TO authenticated;

COMMENT ON FUNCTION initiate_p2p_trade_v2 IS 'Initiates P2P trade - locks seller AFX in escrow and creates trade record';
