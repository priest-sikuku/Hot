-- Fix payment method access in initiate_p2p_trade_v2 function
-- This script updates the function to properly construct payment details from p2p_ads columns

DROP FUNCTION IF EXISTS initiate_p2p_trade_v2(UUID, UUID, NUMERIC);

CREATE OR REPLACE FUNCTION initiate_p2p_trade_v2(
  p_ad_id UUID,
  p_buyer_id UUID,
  p_afx_amount NUMERIC
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trade_id UUID;
  v_ad RECORD;
  v_seller_id UUID;
  v_buyer_id UUID;
  v_total_amount NUMERIC;
  v_available_balance NUMERIC;
  v_payment_details JSONB;
BEGIN
  -- Get ad details
  SELECT * INTO v_ad FROM p2p_ads WHERE id = p_ad_id AND status = 'active';
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ad not found or not active';
  END IF;

  -- Validate amount is within ad limits
  IF p_afx_amount < v_ad.min_amount OR p_afx_amount > v_ad.max_amount THEN
    RAISE EXCEPTION 'Amount must be between % and %', v_ad.min_amount, v_ad.max_amount;
  END IF;

  -- Check if ad has enough remaining amount
  IF p_afx_amount > v_ad.remaining_amount THEN
    RAISE EXCEPTION 'Insufficient remaining amount in ad. Available: %', v_ad.remaining_amount;
  END IF;

  -- Construct payment details from individual ad columns
  v_payment_details := jsonb_build_object(
    'mpesa_number', v_ad.mpesa_number,
    'airtel_money', v_ad.airtel_money,
    'paybill_number', v_ad.paybill_number,
    'account_number', v_ad.account_number,
    'account_name', v_ad.account_name,
    'bank_name', v_ad.bank_name,
    'full_name', v_ad.full_name
  );

  -- Determine buyer and seller based on ad type
  IF v_ad.ad_type = 'sell' THEN
    -- Ad creator is selling, trade initiator is buying
    v_seller_id := v_ad.user_id;
    v_buyer_id := p_buyer_id;
  ELSE
    -- Ad creator is buying, trade initiator is selling
    v_buyer_id := v_ad.user_id;
    v_seller_id := p_buyer_id;
  END IF;

  -- Calculate total amount
  v_total_amount := p_afx_amount * v_ad.price_per_afx;

  -- Check seller's P2P balance (from trade_coins table)
  SELECT COALESCE(SUM(amount), 0) INTO v_available_balance
  FROM trade_coins
  WHERE user_id = v_seller_id 
    AND status = 'available';

  IF v_available_balance < p_afx_amount THEN
    RAISE EXCEPTION 'Insufficient P2P balance. You have % AFX but need % AFX. Please transfer from Dashboard Balance first.', 
      v_available_balance, p_afx_amount;
  END IF;

  -- Lock the coins in trade_coins table
  UPDATE trade_coins
  SET status = 'locked',
      locked_at = NOW(),
      locked_for_trade_id = gen_random_uuid()
  WHERE user_id = v_seller_id 
    AND status = 'available'
    AND id IN (
      SELECT id FROM trade_coins
      WHERE user_id = v_seller_id AND status = 'available'
      ORDER BY created_at ASC
      LIMIT (
        SELECT COUNT(*) FROM trade_coins
        WHERE user_id = v_seller_id AND status = 'available'
        AND amount <= p_afx_amount
      )
    );

  -- Create the trade
  INSERT INTO p2p_trades (
    ad_id,
    buyer_id,
    seller_id,
    afx_amount,
    price_per_afx,
    total_amount,
    payment_details,
    seller_payment_details,
    status,
    is_paid,
    expires_at,
    created_at
  ) VALUES (
    p_ad_id,
    v_buyer_id,
    v_seller_id,
    p_afx_amount,
    v_ad.price_per_afx,
    v_total_amount,
    v_payment_details,
    v_payment_details,
    'pending',
    FALSE,
    NOW() + INTERVAL '30 minutes',
    NOW()
  ) RETURNING id INTO v_trade_id;

  -- Update ad remaining amount
  UPDATE p2p_ads
  SET remaining_amount = remaining_amount - p_afx_amount,
      updated_at = NOW()
  WHERE id = p_ad_id;

  -- Log the trade initiation
  INSERT INTO trade_logs (trade_id, user_id, action, amount, details, timestamp)
  VALUES (
    v_trade_id,
    v_seller_id,
    'trade_initiated',
    p_afx_amount,
    jsonb_build_object(
      'buyer_id', v_buyer_id,
      'seller_id', v_seller_id,
      'total_amount', v_total_amount
    ),
    NOW()
  );

  RETURN v_trade_id;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION initiate_p2p_trade_v2(UUID, UUID, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION initiate_p2p_trade_v2(UUID, UUID, NUMERIC) TO anon;
