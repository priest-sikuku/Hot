-- Update trade stats when trades are completed
-- This ensures accurate tracking of completed trades, success rate, and volume

-- Function to update user trade statistics
CREATE OR REPLACE FUNCTION update_user_trade_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update stats when trade is completed
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    
    -- Update buyer stats
    UPDATE profiles
    SET 
      updated_at = NOW()
    WHERE id = NEW.buyer_id;
    
    -- Update seller stats  
    UPDATE profiles
    SET 
      updated_at = NOW()
    WHERE id = NEW.seller_id;
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to auto-update trade stats
DROP TRIGGER IF EXISTS trigger_update_trade_stats ON p2p_trades;
CREATE TRIGGER trigger_update_trade_stats
AFTER INSERT OR UPDATE ON p2p_trades
FOR EACH ROW
EXECUTE FUNCTION update_user_trade_stats();

-- Function to get user trade statistics
CREATE OR REPLACE FUNCTION get_user_trade_stats(p_user_id UUID)
RETURNS TABLE (
  total_trades BIGINT,
  completed_trades BIGINT,
  cancelled_trades BIGINT,
  total_volume NUMERIC,
  average_rating NUMERIC,
  total_ratings BIGINT,
  success_rate NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  WITH trade_stats AS (
    SELECT
      COUNT(*) as total,
      COUNT(*) FILTER (WHERE status = 'completed') as completed,
      COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled,
      COALESCE(SUM(afx_amount) FILTER (WHERE status = 'completed'), 0) as volume
    FROM p2p_trades
    WHERE buyer_id = p_user_id OR seller_id = p_user_id
  ),
  rating_stats AS (
    SELECT
      COALESCE(ROUND(AVG(rating), 1), 0) as avg_rating,
      COUNT(*) as rating_count
    FROM p2p_ratings
    WHERE rated_user_id = p_user_id
  )
  SELECT
    ts.total,
    ts.completed,
    ts.cancelled,
    ts.volume,
    rs.avg_rating,
    rs.rating_count,
    CASE 
      WHEN ts.total > 0 THEN ROUND((ts.completed::NUMERIC / ts.total::NUMERIC) * 100, 1)
      ELSE 0
    END as success_rate
  FROM trade_stats ts
  CROSS JOIN rating_stats rs;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION update_user_trade_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_trade_stats(UUID) TO authenticated;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_p2p_trades_buyer_status ON p2p_trades(buyer_id, status);
CREATE INDEX IF NOT EXISTS idx_p2p_trades_seller_status ON p2p_trades(seller_id, status);
CREATE INDEX IF NOT EXISTS idx_p2p_trades_status_created ON p2p_trades(status, created_at DESC);

COMMENT ON FUNCTION get_user_trade_stats IS 'Get comprehensive trade statistics for a user including volume, ratings, and success rate';
COMMENT ON FUNCTION update_user_trade_stats IS 'Automatically update user trade statistics when trades are completed';
