-- Fix initiate_p2p_trade_v2 to use p_buyer_id parameter name for backward compatibility
-- This ensures the frontend doesn't need to change

-- Drop all existing versions
DROP FUNCTION IF EXISTS initiate_p2p_trade_v2(uuid, uuid, numeric);
DROP FUNCTION IF EXISTS public.initiate_p2p_trade_v2(uuid, uuid, numeric);

-- Create the function with p_buyer_id parameter (but it's actually the initiator)
CREATE OR REPLACE FUNCTION initiate_p2p_trade_v2(
    p_ad_id UUID,
    p_buyer_id UUID,  -- This is actually the trade initiator, not always the buyer
    p_afx_amount NUMERIC
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ad RECORD;
    v_seller_id UUID;
    v_buyer_id UUID;
    v_trade_id UUID;
    v_seller_balance NUMERIC;
    v_total_cost NUMERIC;
BEGIN
    -- Get ad details
    SELECT * INTO v_ad
    FROM p2p_ads
    WHERE id = p_ad_id AND status = 'active';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ad not found or not active';
    END IF;

    -- Validate amount
    IF p_afx_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be greater than 0';
    END IF;

    IF p_afx_amount > v_ad.remaining_amount THEN
        RAISE EXCEPTION 'Amount exceeds available amount in ad';
    END IF;

    -- Determine actual buyer and seller based on ad type
    IF v_ad.ad_type = 'sell' THEN
        -- SELL ad: ad creator is selling, initiator is buying
        v_seller_id := v_ad.user_id;
        v_buyer_id := p_buyer_id;  -- initiator is the buyer
    ELSE
        -- BUY ad: ad creator is buying, initiator is selling
        v_seller_id := p_buyer_id;  -- initiator is the seller
        v_buyer_id := v_ad.user_id;
    END IF;

    -- Prevent self-trading
    IF v_seller_id = v_buyer_id THEN
        RAISE EXCEPTION 'Cannot trade with yourself';
    END IF;

    -- Check seller's trade_coins balance
    SELECT COALESCE(SUM(amount), 0) INTO v_seller_balance
    FROM trade_coins
    WHERE user_id = v_seller_id AND status = 'available';

    IF v_seller_balance < p_afx_amount THEN
        RAISE EXCEPTION 'Insufficient P2P balance. You have % AFX in P2P balance but need % AFX. Please transfer funds from Dashboard Balance to P2P Balance first.', 
            v_seller_balance, p_afx_amount;
    END IF;

    -- Calculate total cost
    v_total_cost := p_afx_amount * v_ad.price_per_afx;

    -- Lock seller's coins in escrow (mark as locked in trade_coins)
    UPDATE trade_coins
    SET status = 'locked',
        locked_at = NOW(),
        locked_for_trade_id = gen_random_uuid()  -- temporary, will update with actual trade_id
    WHERE user_id = v_seller_id 
      AND status = 'available'
      AND id IN (
          SELECT id FROM trade_coins
          WHERE user_id = v_seller_id AND status = 'available'
          ORDER BY created_at ASC
          LIMIT (SELECT COUNT(*) FROM trade_coins WHERE user_id = v_seller_id AND status = 'available' AND amount <= p_afx_amount)
      );

    -- Create trade record
    INSERT INTO p2p_trades (
        ad_id,
        seller_id,
        buyer_id,
        afx_amount,
        price_per_afx,
        total_amount,
        status,
        escrow_amount,
        payment_method,
        seller_payment_details,
        created_at
    ) VALUES (
        p_ad_id,
        v_seller_id,
        v_buyer_id,
        p_afx_amount,
        v_ad.price_per_afx,
        v_total_cost,
        'pending',
        p_afx_amount,
        v_ad.payment_method,
        v_ad.payment_details,
        NOW()
    ) RETURNING id INTO v_trade_id;

    -- Update the locked coins with the actual trade_id
    UPDATE trade_coins
    SET locked_for_trade_id = v_trade_id
    WHERE user_id = v_seller_id 
      AND status = 'locked'
      AND locked_for_trade_id IS NOT NULL
      AND locked_for_trade_id != v_trade_id;

    -- Update ad remaining amount
    UPDATE p2p_ads
    SET remaining_amount = remaining_amount - p_afx_amount,
        status = CASE 
            WHEN remaining_amount - p_afx_amount <= 0 THEN 'completed'
            ELSE status
        END
    WHERE id = p_ad_id;

    -- Log the trade initiation
    INSERT INTO trade_logs (trade_id, user_id, action, amount, timestamp)
    VALUES (v_trade_id, v_seller_id, 'trade_initiated', p_afx_amount, NOW());

    RETURN v_trade_id;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION initiate_p2p_trade_v2(uuid, uuid, numeric) TO authenticated;

-- Add comment
COMMENT ON FUNCTION initiate_p2p_trade_v2 IS 'Initiates P2P trade with correct buyer/seller roles. Parameter p_buyer_id is the trade initiator (not always the buyer). For SELL ads: initiator=buyer, ad_creator=seller. For BUY ads: initiator=seller, ad_creator=buyer. Uses trade_coins table for P2P balance.';
