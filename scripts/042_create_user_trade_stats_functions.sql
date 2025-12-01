-- Function to get user's P2P trade statistics
CREATE OR REPLACE FUNCTION get_user_p2p_stats(p_user_id UUID)
RETURNS TABLE (
  total_trades BIGINT,
  completed_trades BIGINT,
  completion_rate NUMERIC,
  average_rating NUMERIC,
  total_ratings BIGINT
) AS $$
BEGIN
  RETURN QUERY
  WITH trade_stats AS (
    SELECT
      COUNT(*) as total,
      COUNT(*) FILTER (WHERE status = 'completed') as completed
    FROM p2p_trades
    WHERE (buyer_id = p_user_id OR seller_id = p_user_id)
      AND status IN ('completed', 'cancelled', 'disputed')
  ),
  rating_stats AS (
    SELECT
      COALESCE(AVG(rating), 0) as avg_rating,
      COUNT(*) as rating_count
    FROM p2p_ratings
    WHERE rated_user_id = p_user_id
  )
  SELECT
    ts.total,
    ts.completed,
    CASE 
      WHEN ts.total > 0 THEN ROUND((ts.completed::NUMERIC / ts.total::NUMERIC) * 100, 2)
      ELSE 0
    END as completion_rate,
    ROUND(rs.avg_rating, 1) as avg_rating,
    rs.rating_count
  FROM trade_stats ts
  CROSS JOIN rating_stats rs;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_user_p2p_stats(UUID) TO authenticated;

-- Function to update user's overall rating in profiles table
CREATE OR REPLACE FUNCTION update_user_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE profiles
  SET rating = (
    SELECT COALESCE(AVG(rating), 0)
    FROM p2p_ratings
    WHERE rated_user_id = NEW.rated_user_id
  )
  WHERE id = NEW.rated_user_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to auto-update user rating when new rating is added
DROP TRIGGER IF EXISTS trigger_update_user_rating ON p2p_ratings;
CREATE TRIGGER trigger_update_user_rating
AFTER INSERT OR UPDATE ON p2p_ratings
FOR EACH ROW
EXECUTE FUNCTION update_user_rating();

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_p2p_ratings_rated_user ON p2p_ratings(rated_user_id);
CREATE INDEX IF NOT EXISTS idx_p2p_trades_user_status ON p2p_trades(buyer_id, seller_id, status);
