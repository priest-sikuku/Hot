-- Add reputation system and available balance calculation

-- Function to calculate available balance (total_mined minus locked in sell ads)
CREATE OR REPLACE FUNCTION get_available_balance(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  total_balance NUMERIC;
  locked_balance NUMERIC;
BEGIN
  -- Get total balance
  SELECT COALESCE(total_mined, 0)
  INTO total_balance
  FROM profiles
  WHERE id = p_user_id;
  
  -- Get locked balance from active sell ads
  SELECT COALESCE(SUM(remaining_amount), 0)
  INTO locked_balance
  FROM p2p_ads
  WHERE user_id = p_user_id
    AND ad_type = 'sell'
    AND status = 'active'
    AND expires_at > NOW();
  
  RETURN total_balance - locked_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user reputation stats
CREATE OR REPLACE FUNCTION get_user_reputation(p_user_id UUID)
RETURNS TABLE (
  average_rating NUMERIC,
  total_ratings INTEGER,
  total_trades INTEGER,
  completed_trades INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(ROUND(AVG(r.rating), 1), 0) as average_rating,
    COALESCE(COUNT(DISTINCT r.id)::INTEGER, 0) as total_ratings,
    COALESCE(COUNT(DISTINCT t.id)::INTEGER, 0) as total_trades,
    COALESCE(COUNT(DISTINCT CASE WHEN t.status = 'completed' THEN t.id END)::INTEGER, 0) as completed_trades
  FROM profiles p
  LEFT JOIN ratings r ON p.id = r.rated_user_id
  LEFT JOIN p2p_trades t ON (p.id = t.buyer_id OR p.id = t.seller_id)
  WHERE p.id = p_user_id
  GROUP BY p.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_available_balance(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_reputation(UUID) TO authenticated;
