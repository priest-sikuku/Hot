-- Enhance P2P Payment Methods System
-- This script safely adds missing fields and functions without dropping existing data

-- Add payment method fields to p2p_ads if they don't exist
ALTER TABLE public.p2p_ads 
  ADD COLUMN IF NOT EXISTS bank_name TEXT,
  ADD COLUMN IF NOT EXISTS account_name TEXT,
  ADD COLUMN IF NOT EXISTS full_name TEXT;

-- Add seller payment details to p2p_trades if it doesn't exist
ALTER TABLE public.p2p_trades 
  ADD COLUMN IF NOT EXISTS seller_payment_details JSONB;

-- Add remaining_amount and price_per_afx to p2p_ads if they don't exist
ALTER TABLE public.p2p_ads
  ADD COLUMN IF NOT EXISTS remaining_amount NUMERIC,
  ADD COLUMN IF NOT EXISTS price_per_afx NUMERIC;

-- Update remaining_amount for existing ads
UPDATE public.p2p_ads
SET remaining_amount = afx_amount
WHERE remaining_amount IS NULL;

-- Create or replace function to post sell ad with payment details
CREATE OR REPLACE FUNCTION post_sell_ad_with_payment_details(
  p_user_id UUID,
  p_afx_amount NUMERIC,
  p_price_per_afx NUMERIC,
  p_min_amount NUMERIC,
  p_max_amount NUMERIC,
  p_payment_method TEXT,
  p_mpesa_number TEXT DEFAULT NULL,
  p_full_name TEXT DEFAULT NULL,
  p_paybill_number TEXT DEFAULT NULL,
  p_account_number TEXT DEFAULT NULL,
  p_bank_name TEXT DEFAULT NULL,
  p_account_name TEXT DEFAULT NULL,
  p_airtel_number TEXT DEFAULT NULL,
  p_terms_of_trade TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_ad_id UUID;
  v_user_balance NUMERIC;
BEGIN
  -- Check user has enough balance in coins table
  SELECT COALESCE(SUM(amount), 0) INTO v_user_balance
  FROM public.coins
  WHERE user_id = p_user_id AND status = 'available';

  IF v_user_balance < p_afx_amount THEN
    RAISE EXCEPTION 'Insufficient balance. You have % AFX available', v_user_balance;
  END IF;

  -- Create the ad
  INSERT INTO public.p2p_ads (
    user_id,
    ad_type,
    afx_amount,
    remaining_amount,
    price_per_afx,
    min_amount,
    max_amount,
    mpesa_number,
    full_name,
    paybill_number,
    account_number,
    bank_name,
    account_name,
    airtel_money,
    terms_of_trade,
    status,
    expires_at
  ) VALUES (
    p_user_id,
    'sell',
    p_afx_amount,
    p_afx_amount,
    p_price_per_afx,
    p_min_amount,
    p_max_amount,
    p_mpesa_number,
    p_full_name,
    p_paybill_number,
    p_account_number,
    p_bank_name,
    p_account_name,
    p_airtel_number,
    p_terms_of_trade,
    'active',
    NOW() + INTERVAL '7 days'
  ) RETURNING id INTO v_ad_id;

  -- Lock the coins for this ad
  UPDATE public.coins
  SET status = 'locked',
      updated_at = NOW()
  WHERE user_id = p_user_id 
    AND status = 'available'
    AND id IN (
      SELECT id FROM public.coins
      WHERE user_id = p_user_id AND status = 'available'
      ORDER BY created_at ASC
      LIMIT (
        SELECT COUNT(*) FROM public.coins
        WHERE user_id = p_user_id AND status = 'available'
        AND amount <= p_afx_amount
      )
    );

  -- Record transaction
  INSERT INTO public.transactions (
    user_id,
    type,
    amount,
    description,
    related_id,
    status
  ) VALUES (
    p_user_id,
    'p2p_ad_created',
    -p_afx_amount,
    'Created sell ad - coins locked',
    v_ad_id,
    'completed'
  );

  RETURN v_ad_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION post_sell_ad_with_payment_details TO authenticated;

COMMENT ON FUNCTION post_sell_ad_with_payment_details IS 'Creates a sell ad with structured payment method details and locks seller coins';
