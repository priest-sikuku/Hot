-- Admin Balance Management Functions
-- Purpose: Allow admins to safely update user balances with audit logging

-- Function to update user's dashboard balance
CREATE OR REPLACE FUNCTION admin_update_dashboard_balance(
  p_admin_id UUID,
  p_user_id UUID,
  p_new_amount NUMERIC,
  p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_old_amount NUMERIC;
  v_result JSONB;
BEGIN
  -- Check if caller is admin
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_admin_id AND is_admin = TRUE) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  -- Get current balance
  SELECT COALESCE(SUM(amount), 0) INTO v_old_amount
  FROM coins
  WHERE user_id = p_user_id AND status = 'available';

  -- Delete existing available coins
  DELETE FROM coins
  WHERE user_id = p_user_id AND status = 'available';

  -- Insert new balance
  IF p_new_amount > 0 THEN
    INSERT INTO coins (user_id, amount, status, claim_type)
    VALUES (p_user_id, p_new_amount, 'available', 'admin_adjustment');
  END IF;

  -- Log the action
  INSERT INTO admin_audit_logs (admin_id, action, target_table, target_id, details)
  VALUES (
    p_admin_id,
    'update_dashboard_balance',
    'coins',
    p_user_id,
    jsonb_build_object(
      'old_amount', v_old_amount,
      'new_amount', p_new_amount,
      'reason', p_reason
    )
  );

  v_result := jsonb_build_object(
    'success', TRUE,
    'old_amount', v_old_amount,
    'new_amount', p_new_amount
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user's P2P balance
CREATE OR REPLACE FUNCTION admin_update_p2p_balance(
  p_admin_id UUID,
  p_user_id UUID,
  p_new_amount NUMERIC,
  p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_old_amount NUMERIC;
  v_result JSONB;
BEGIN
  -- Check if caller is admin
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_admin_id AND is_admin = TRUE) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  -- Get current P2P balance
  SELECT COALESCE(SUM(amount), 0) INTO v_old_amount
  FROM trade_coins
  WHERE user_id = p_user_id AND status = 'available';

  -- Delete existing available trade coins
  DELETE FROM trade_coins
  WHERE user_id = p_user_id AND status = 'available';

  -- Insert new P2P balance
  IF p_new_amount > 0 THEN
    INSERT INTO trade_coins (user_id, amount, status, source)
    VALUES (p_user_id, p_new_amount, 'available', 'admin_adjustment');
  END IF;

  -- Log the action
  INSERT INTO admin_audit_logs (admin_id, action, target_table, target_id, details)
  VALUES (
    p_admin_id,
    'update_p2p_balance',
    'trade_coins',
    p_user_id,
    jsonb_build_object(
      'old_amount', v_old_amount,
      'new_amount', p_new_amount,
      'reason', p_reason
    )
  );

  v_result := jsonb_build_object(
    'success', TRUE,
    'old_amount', v_old_amount,
    'new_amount', p_new_amount
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user balances
CREATE OR REPLACE FUNCTION admin_get_user_balances(
  p_admin_id UUID,
  p_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_dashboard_balance NUMERIC;
  v_p2p_balance NUMERIC;
  v_result JSONB;
BEGIN
  -- Check if caller is admin
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_admin_id AND is_admin = TRUE) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  -- Get dashboard balance
  SELECT COALESCE(SUM(amount), 0) INTO v_dashboard_balance
  FROM coins
  WHERE user_id = p_user_id AND status = 'available';

  -- Get P2P balance
  SELECT COALESCE(SUM(amount), 0) INTO v_p2p_balance
  FROM trade_coins
  WHERE user_id = p_user_id AND status = 'available';

  v_result := jsonb_build_object(
    'dashboard_balance', v_dashboard_balance,
    'p2p_balance', v_p2p_balance
  );

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION admin_update_dashboard_balance IS 'Allows admins to update user dashboard balance with audit logging';
COMMENT ON FUNCTION admin_update_p2p_balance IS 'Allows admins to update user P2P balance with audit logging';
COMMENT ON FUNCTION admin_get_user_balances IS 'Retrieves user balances for admin review';
