-- Fix initiate_p2p_trade_v2 function conflict
-- Drop all existing versions and create one definitive version

-- Drop all possible variations of the function
DROP FUNCTION IF EXISTS initiate_p2p_trade_v2(uuid, uuid, numeric);
DROP FUNCTION IF EXISTS initiate_p2p_trade_v2(uuid, numeric, uuid);
DROP FUNCTION IF EXISTS public.initiate_p2p_trade_v2(uuid, uuid, numeric);
DROP FUNCTION IF EXISTS public.initiate_p2p_trade_v2(uuid, numeric, uuid);

-- Create the definitive version with consistent parameter order
-- Order: p_ad_id, p_buyer_id, p_afx_amount (matches frontend calls)
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
    
    -- Check seller has enough balance in trade_coins table
    SELECT COALESCE(SUM(amount), 0) INTO v_seller_balance
    FROM trade_coins
    WHERE user_id = v_seller_id AND status = 'available';
    
    IF v_seller_balance < p_afx_amount THEN
      RAISE EXCEPTION 'Seller has insufficient P2P balance. Current balance: %', v_seller_balance;
    END IF;
    
    -- Lock seller's coins in escrow
    UPDATE trade_coins
    SET status = 'locked',
        updated_at = NOW()
    WHERE id IN (
      SELECT id FROM trade_coins
      WHERE user_id = v_seller_id 
        AND status = 'available'
      ORDER BY created_at
      LIMIT (SELECT COUNT(*) FROM trade_coins WHERE user_id = v_seller_id AND status = 'available' AND amount <= p_afx_amount)
      FOR UPDATE
    );
      
  ELSE -- buy ad (buyer is actually selling their AFX)
    v_seller_id := p_buyer_id;
    
    -- Check seller (who is responding to buy ad) has enough balance
    SELECT COALESCE(SUM(amount), 0) INTO v_seller_balance
    FROM trade_coins
    WHERE user_id = v_seller_id AND status = 'available';
    
    IF v_seller_balance < p_afx_amount THEN
      RAISE EXCEPTION 'You have insufficient P2P balance to sell. Current balance: %. Please transfer from Dashboard Balance first.', v_seller_balance;
    END IF;
    
    -- Lock seller's coins in escrow
    UPDATE trade_coins
    SET status = 'locked',
        updated_at = NOW()
    WHERE id IN (
      SELECT id FROM trade_coins
      WHERE user_id = v_seller_id 
        AND status = 'available'
      ORDER BY created_at
      LIMIT (SELECT COUNT(*) FROM trade_coins WHERE user_id = v_seller_id AND status = 'available' AND amount <= p_afx_amount)
      FOR UPDATE
    );
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
  
  -- Log the trade initiation
  INSERT INTO trade_logs (trade_id, user_id, action, amount)
  VALUES (v_trade_id, v_seller_id, 'trade_initiated', p_afx_amount);
  
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

COMMENT ON FUNCTION initiate_p2p_trade_v2 IS 'Initiates P2P trade - locks seller AFX from trade_coins in escrow. Parameters: ad_id, buyer_id, afx_amount';
