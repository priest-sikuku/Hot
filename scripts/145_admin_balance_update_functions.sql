-- Admin function to update dashboard balance
CREATE OR REPLACE FUNCTION admin_update_dashboard_balance(
  p_admin_id UUID,
  p_user_id UUID,
  p_new_amount NUMERIC,
  p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_balance NUMERIC;
  v_difference NUMERIC;
BEGIN
  -- Check admin permission
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  -- Calculate current balance
  SELECT COALESCE(SUM(amount), 0) INTO v_current_balance
  FROM coins
  WHERE user_id = p_user_id AND status = 'available';

  v_difference := p_new_amount - v_current_balance;

  -- If there's a difference, create adjustment record
  IF v_difference != 0 THEN
    INSERT INTO coins (user_id, amount, status, claim_type)
    VALUES (
      p_user_id,
      ABS(v_difference),
      CASE WHEN v_difference > 0 THEN 'available' ELSE 'withdrawn' END,
      'admin_adjustment'
    );

    -- Log transaction
    INSERT INTO transactions (user_id, amount, type, status, description)
    VALUES (
      p_user_id,
      ABS(v_difference),
      CASE WHEN v_difference > 0 THEN 'admin_credit' ELSE 'admin_debit' END,
      'completed',
      'Admin balance adjustment: ' || p_reason
    );

    -- Log admin action
    PERFORM log_admin_action(
      p_admin_id,
      'DASHBOARD_BALANCE_UPDATE',
      'coins',
      p_user_id,
      jsonb_build_object(
        'old_balance', v_current_balance,
        'new_balance', p_new_amount,
        'difference', v_difference,
        'reason', p_reason
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'old_balance', v_current_balance,
    'new_balance', p_new_amount,
    'difference', v_difference
  );
END;
$$;

-- Admin function to update P2P balance
CREATE OR REPLACE FUNCTION admin_update_p2p_balance(
  p_admin_id UUID,
  p_user_id UUID,
  p_new_amount NUMERIC,
  p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_balance NUMERIC;
  v_difference NUMERIC;
BEGIN
  -- Check admin permission
  IF NOT is_admin(p_admin_id) THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  -- Calculate current balance
  SELECT COALESCE(SUM(amount), 0) INTO v_current_balance
  FROM trade_coins
  WHERE user_id = p_user_id AND status = 'available';

  v_difference := p_new_amount - v_current_balance;

  -- If there's a difference, create adjustment record
  IF v_difference != 0 THEN
    INSERT INTO trade_coins (user_id, amount, status, source)
    VALUES (
      p_user_id,
      ABS(v_difference),
      CASE WHEN v_difference > 0 THEN 'available' ELSE 'withdrawn' END,
      'admin_adjustment'
    );

    -- Log admin action
    PERFORM log_admin_action(
      p_admin_id,
      'P2P_BALANCE_UPDATE',
      'trade_coins',
      p_user_id,
      jsonb_build_object(
        'old_balance', v_current_balance,
        'new_balance', p_new_amount,
        'difference', v_difference,
        'reason', p_reason
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'old_balance', v_current_balance,
    'new_balance', p_new_amount,
    'difference', v_difference
  );
END;
$$;
