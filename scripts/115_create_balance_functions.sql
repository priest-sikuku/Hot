-- Create helper function to get dashboard balance from coins table
CREATE OR REPLACE FUNCTION get_dashboard_balance(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  v_balance NUMERIC;
BEGIN
  -- Sum all available coins for the user
  SELECT COALESCE(SUM(amount), 0)
  INTO v_balance
  FROM coins
  WHERE user_id = p_user_id
    AND status = 'available';
  
  RETURN v_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create helper function to get mining rewards history
CREATE OR REPLACE FUNCTION get_mining_rewards(p_user_id UUID)
RETURNS TABLE (
  id UUID,
  amount NUMERIC,
  created_at TIMESTAMP WITH TIME ZONE,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.amount,
    c.created_at,
    c.status
  FROM coins c
  WHERE c.user_id = p_user_id
    AND c.claim_type = 'mining'
  ORDER BY c.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_dashboard_balance(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_mining_rewards(UUID) TO authenticated;
