-- Add functions for managing P2P ads

-- Function to safely delete an ad (returns coins to user if it's a sell ad)
CREATE OR REPLACE FUNCTION delete_p2p_ad(ad_id_param UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  ad_record RECORD;
  result JSONB;
BEGIN
  -- Get the ad details
  SELECT * INTO ad_record
  FROM p2p_ads
  WHERE id = ad_id_param;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ad not found');
  END IF;

  -- Check if user owns this ad
  IF ad_record.user_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- If it's a sell ad with remaining amount, return coins to user
  IF ad_record.ad_type = 'sell' AND ad_record.remaining_amount > 0 THEN
    UPDATE profiles
    SET total_mined = total_mined + ad_record.remaining_amount,
        updated_at = NOW()
    WHERE id = ad_record.user_id;
  END IF;

  -- Delete the ad
  DELETE FROM p2p_ads WHERE id = ad_id_param;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Ad deleted successfully',
    'coins_returned', ad_record.remaining_amount
  );
END;
$$;

-- Function to update an ad
CREATE OR REPLACE FUNCTION update_p2p_ad(
  ad_id_param UUID,
  new_gx_amount NUMERIC,
  new_min_amount NUMERIC,
  new_max_amount NUMERIC,
  new_price_per_gx NUMERIC,
  new_account_number TEXT,
  new_mpesa_number TEXT,
  new_paybill_number TEXT,
  new_airtel_money TEXT,
  new_terms_of_trade TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  ad_record RECORD;
  amount_difference NUMERIC;
BEGIN
  -- Get the ad details
  SELECT * INTO ad_record
  FROM p2p_ads
  WHERE id = ad_id_param;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Ad not found');
  END IF;

  -- Check if user owns this ad
  IF ad_record.user_id != auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- If it's a sell ad and amount is being increased, check user balance
  IF ad_record.ad_type = 'sell' THEN
    amount_difference := new_gx_amount - ad_record.gx_amount;
    
    IF amount_difference > 0 THEN
      -- Check if user has enough balance
      IF (SELECT total_mined FROM profiles WHERE id = ad_record.user_id) < amount_difference THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
      END IF;
      
      -- Deduct additional amount from user balance
      UPDATE profiles
      SET total_mined = total_mined - amount_difference,
          updated_at = NOW()
      WHERE id = ad_record.user_id;
      
      -- Update remaining amount
      UPDATE p2p_ads
      SET remaining_amount = remaining_amount + amount_difference
      WHERE id = ad_id_param;
    ELSIF amount_difference < 0 THEN
      -- Return excess amount to user
      UPDATE profiles
      SET total_mined = total_mined + ABS(amount_difference),
          updated_at = NOW()
      WHERE id = ad_record.user_id;
      
      -- Update remaining amount
      UPDATE p2p_ads
      SET remaining_amount = remaining_amount + amount_difference
      WHERE id = ad_id_param;
    END IF;
  END IF;

  -- Update the ad
  UPDATE p2p_ads
  SET 
    gx_amount = new_gx_amount,
    min_amount = new_min_amount,
    max_amount = new_max_amount,
    price_per_gx = new_price_per_gx,
    account_number = new_account_number,
    mpesa_number = new_mpesa_number,
    paybill_number = new_paybill_number,
    airtel_money = new_airtel_money,
    terms_of_trade = new_terms_of_trade,
    updated_at = NOW()
  WHERE id = ad_id_param;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Ad updated successfully'
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION delete_p2p_ad TO authenticated;
GRANT EXECUTE ON FUNCTION update_p2p_ad TO authenticated;
