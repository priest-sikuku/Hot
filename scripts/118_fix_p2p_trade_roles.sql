-- Fix P2P trade buyer/seller role assignment
-- The issue: parameter naming was confusing - p_buyer_id was actually "initiator_id"
-- For SELL ads: initiator is buyer, ad creator is seller
-- For BUY ads: initiator is seller, ad creator is buyer

DROP FUNCTION IF EXISTS initiate_p2p_trade_v2(uuid, uuid, numeric);

CREATE OR REPLACE FUNCTION initiate_p2p_trade_v2(
  p_ad_id uuid,
  p_initiator_id uuid,  -- Renamed from p_buyer_id to be clearer
  p_afx_amount numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ad p2p_ads%ROWTYPE;
  v_buyer_id uuid;
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
  
  -- Fix buyer/seller assignment based on ad type
  IF v_ad.ad_type = 'sell' THEN
    -- SELL ad: Ad creator is selling, initiator is buying
    v_seller_id := v_ad.user_id;
    v_buyer_id := p_initiator_id;
  ELSE
    -- BUY ad: Ad creator is buying, initiator is selling
    v_buyer_id := v_ad.user_id;
    v_seller_id := p_initiator_id;
  END IF;
  
  -- Check seller has enough balance in trade_coins table
  SELECT COALESCE(SUM(amount), 0) INTO v_seller_balance
  FROM trade_coins
  WHERE user_id = v_seller_id AND status = 'available';
  
  IF v_seller_balance < p_afx_amount THEN
    RAISE EXCEPTION 'Seller has insufficient P2P balance. Current balance: %. Please transfer from Dashboard Balance first.', v_seller_balance;
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
  
  -- Create trade with correct buyer and seller
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
    v_buyer_id,
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
    (v_buyer_id, 'p2p_pending', p_afx_amount, 'P2P trade initiated', 'pending', v_trade_id);
  
  RETURN v_trade_id;
END;
$$;

-- Update release function to transfer to buyer's trade_coins (not coins table)
CREATE OR REPLACE FUNCTION release_p2p_coins(
  p_trade_id UUID,
  p_seller_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trade p2p_trades%ROWTYPE;
  v_buyer_referrer UUID;
  v_commission_amount NUMERIC;
BEGIN
  -- Get trade details
  SELECT * INTO v_trade
  FROM p2p_trades
  WHERE id = p_trade_id AND seller_id = p_seller_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trade not found or you are not the seller';
  END IF;

  IF v_trade.is_paid IS NOT TRUE THEN
    RAISE EXCEPTION 'Buyer must mark payment as sent before you can release coins';
  END IF;

  IF v_trade.status NOT IN ('payment_sent', 'escrowed', 'pending') THEN
    RAISE EXCEPTION 'Trade is not in a state to release coins';
  END IF;

  -- Update trade status to completed
  UPDATE p2p_trades
  SET 
    status = 'completed',
    released_at = NOW(),
    coins_released_at = NOW(),
    updated_at = NOW()
  WHERE id = p_trade_id;

  -- Transfer locked coins from seller to buyer in trade_coins table
  UPDATE trade_coins
  SET 
    status = 'available',
    user_id = v_trade.buyer_id,
    updated_at = NOW()
  WHERE user_id = v_trade.seller_id
    AND status = 'locked'
    AND id IN (
      SELECT id FROM trade_coins
      WHERE user_id = v_trade.seller_id AND status = 'locked'
      ORDER BY created_at
      LIMIT (
        SELECT COUNT(*) FROM trade_coins
        WHERE user_id = v_trade.seller_id AND status = 'locked'
        AND amount <= v_trade.afx_amount
      )
    );

  -- Log the action
  INSERT INTO trade_logs (trade_id, user_id, action, amount)
  VALUES (p_trade_id, p_seller_id, 'coins_released', v_trade.afx_amount);

  -- Record transactions
  INSERT INTO transactions (user_id, type, amount, description, related_id, status)
  VALUES 
    (v_trade.buyer_id, 'p2p_buy', v_trade.afx_amount, 'Received AFX from P2P trade', p_trade_id, 'completed'),
    (v_trade.seller_id, 'p2p_sell', -v_trade.afx_amount, 'Sold AFX in P2P trade', p_trade_id, 'completed');

  -- Process referral commission (1.5% of trade amount to P2P balance)
  SELECT referred_by INTO v_buyer_referrer
  FROM profiles
  WHERE id = v_trade.buyer_id;

  IF v_buyer_referrer IS NOT NULL THEN
    v_commission_amount := v_trade.afx_amount * 0.015;  -- 1.5%
    
    -- Credit commission to referrer's P2P balance (trade_coins table)
    INSERT INTO trade_coins (user_id, amount, source, status)
    VALUES (v_buyer_referrer, v_commission_amount, 'referral_commission', 'available');
    
    INSERT INTO referral_commissions (referrer_id, referred_id, amount, commission_type, source_id, status)
    VALUES (v_buyer_referrer, v_trade.buyer_id, v_commission_amount, 'trading', p_trade_id, 'completed');
    
    UPDATE referrals
    SET total_trading_commission = COALESCE(total_trading_commission, 0) + v_commission_amount,
        updated_at = NOW()
    WHERE referrer_id = v_buyer_referrer AND referred_id = v_trade.buyer_id;
    
    INSERT INTO transactions (user_id, type, amount, description, related_id, status)
    VALUES (v_buyer_referrer, 'referral_commission', v_commission_amount, 'P2P referral commission (1.5%)', p_trade_id, 'completed');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION initiate_p2p_trade_v2(uuid, uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION release_p2p_coins(UUID, UUID) TO authenticated;

COMMENT ON FUNCTION initiate_p2p_trade_v2 IS 'Initiates P2P trade with correct buyer/seller roles. For SELL ads: initiator=buyer, ad_creator=seller. For BUY ads: initiator=seller, ad_creator=buyer';
