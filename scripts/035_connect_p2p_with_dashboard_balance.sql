-- Connect P2P marketplace with dashboard balance system
-- This script ensures that P2P ads and trades use the same balance (total_mined) displayed in dashboard

-- Function to post a SELL ad and move coins to escrow
CREATE OR REPLACE FUNCTION post_sell_ad_with_escrow(
  p_user_id uuid,
  p_gx_amount numeric,
  p_price_per_gx numeric,
  p_min_amount numeric,
  p_max_amount numeric,
  p_account_number text DEFAULT NULL,
  p_mpesa_number text DEFAULT NULL,
  p_paybill_number text DEFAULT NULL,
  p_airtel_money text DEFAULT NULL,
  p_terms_of_trade text DEFAULT NULL
) RETURNS uuid AS $$
DECLARE
  v_ad_id uuid;
  v_user_balance numeric;
BEGIN
  -- Check user has enough balance
  SELECT total_mined INTO v_user_balance
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_user_balance IS NULL THEN
    RAISE EXCEPTION 'User profile not found';
  END IF;

  IF v_user_balance < p_gx_amount THEN
    RAISE EXCEPTION 'Insufficient balance. You have % GX but trying to sell % GX', v_user_balance, p_gx_amount;
  END IF;

  -- Check minimum amount
  IF p_gx_amount < 50 THEN
    RAISE EXCEPTION 'Minimum amount to post an ad is 50 GX';
  END IF;

  -- Create the ad
  INSERT INTO public.p2p_ads (
    user_id, ad_type, gx_amount, remaining_amount, price_per_gx,
    min_amount, max_amount, account_number, mpesa_number,
    paybill_number, airtel_money, terms_of_trade, status
  ) VALUES (
    p_user_id, 'sell', p_gx_amount, p_gx_amount, p_price_per_gx,
    p_min_amount, p_max_amount, p_account_number, p_mpesa_number,
    p_paybill_number, p_airtel_money, p_terms_of_trade, 'active'
  ) RETURNING id INTO v_ad_id;

  -- Deduct coins from user balance immediately when posting SELL ad
  UPDATE public.profiles
  SET total_mined = total_mined - p_gx_amount,
      updated_at = now()
  WHERE id = p_user_id;

  -- Record transaction
  INSERT INTO public.transactions (user_id, type, amount, description, related_id, status)
  VALUES (p_user_id, 'p2p_ad_escrow', -p_gx_amount, 'Coins locked for P2P sell ad', v_ad_id, 'completed');

  RETURN v_ad_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to cancel/expire ad and return coins to seller
CREATE OR REPLACE FUNCTION return_coins_from_ad(
  p_ad_id uuid
) RETURNS void AS $$
DECLARE
  v_user_id uuid;
  v_remaining_amount numeric;
  v_ad_type text;
BEGIN
  -- Get ad details
  SELECT user_id, remaining_amount, ad_type
  INTO v_user_id, v_remaining_amount, v_ad_type
  FROM public.p2p_ads
  WHERE id = p_ad_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ad not found';
  END IF;

  -- Only return coins for SELL ads
  IF v_ad_type = 'sell' AND v_remaining_amount > 0 THEN
    -- Return remaining coins to user
    UPDATE public.profiles
    SET total_mined = total_mined + v_remaining_amount,
        updated_at = now()
    WHERE id = v_user_id;

    -- Record transaction
    INSERT INTO public.transactions (user_id, type, amount, description, related_id, status)
    VALUES (v_user_id, 'p2p_ad_return', v_remaining_amount, 'Coins returned from cancelled/expired ad', p_ad_id, 'completed');
  END IF;

  -- Update ad status
  UPDATE public.p2p_ads
  SET status = 'expired',
      updated_at = now()
  WHERE id = p_ad_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the initiate_p2p_trade function to decrease remaining_amount on ad
CREATE OR REPLACE FUNCTION initiate_p2p_trade_v2(
  p_ad_id uuid,
  p_buyer_id uuid,
  p_gx_amount numeric
) RETURNS uuid AS $$
DECLARE
  v_trade_id uuid;
  v_seller_id uuid;
  v_ad_type text;
  v_remaining_amount numeric;
  v_seller_balance numeric;
BEGIN
  -- Get ad details
  SELECT user_id, ad_type, remaining_amount
  INTO v_seller_id, v_ad_type, v_remaining_amount
  FROM public.p2p_ads
  WHERE id = p_ad_id AND status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ad not found or not active';
  END IF;

  -- Check minimum trade amount
  IF p_gx_amount < 2 THEN
    RAISE EXCEPTION 'Minimum trade amount is 2 GX';
  END IF;

  -- Check if enough coins available on ad
  IF p_gx_amount > v_remaining_amount THEN
    RAISE EXCEPTION 'Not enough coins available on this ad. Available: % GX', v_remaining_amount;
  END IF;

  -- Prevent self-trading
  IF p_buyer_id = v_seller_id THEN
    RAISE EXCEPTION 'You cannot trade with yourself';
  END IF;

  -- For SELL ads, coins are already in escrow from ad posting
  -- For BUY ads, we need to check seller has balance
  IF v_ad_type = 'buy' THEN
    -- In this case, the buyer from the ad is actually selling to the initiator
    SELECT total_mined INTO v_seller_balance
    FROM public.profiles
    WHERE id = p_buyer_id;

    IF v_seller_balance < p_gx_amount THEN
      RAISE EXCEPTION 'Insufficient balance to sell';
    END IF;

    -- Deduct from seller (the trade initiator)
    UPDATE public.profiles
    SET total_mined = total_mined - p_gx_amount,
        updated_at = now()
    WHERE id = p_buyer_id;

    -- Create trade (roles are swapped for BUY ads)
    INSERT INTO public.p2p_trades (ad_id, buyer_id, seller_id, gx_amount, escrow_amount, status)
    VALUES (p_ad_id, v_seller_id, p_buyer_id, p_gx_amount, p_gx_amount, 'escrowed')
    RETURNING id INTO v_trade_id;
  ELSE
    -- SELL ad: coins already in escrow, just create trade
    INSERT INTO public.p2p_trades (ad_id, buyer_id, seller_id, gx_amount, escrow_amount, status)
    VALUES (p_ad_id, p_buyer_id, v_seller_id, p_gx_amount, p_gx_amount, 'escrowed')
    RETURNING id INTO v_trade_id;
  END IF;

  -- Decrease remaining_amount on the ad
  UPDATE public.p2p_ads
  SET remaining_amount = remaining_amount - p_gx_amount,
      updated_at = now()
  WHERE id = p_ad_id;

  -- If no coins left, mark ad as completed
  UPDATE public.p2p_ads
  SET status = 'completed'
  WHERE id = p_ad_id AND remaining_amount <= 0;

  RETURN v_trade_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION post_sell_ad_with_escrow TO authenticated;
GRANT EXECUTE ON FUNCTION return_coins_from_ad TO authenticated;
GRANT EXECUTE ON FUNCTION initiate_p2p_trade_v2 TO authenticated;
