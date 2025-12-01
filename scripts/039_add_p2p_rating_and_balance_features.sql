-- Add rating system for P2P trades
CREATE TABLE IF NOT EXISTS p2p_ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_id UUID NOT NULL REFERENCES p2p_trades(id) ON DELETE CASCADE,
  rater_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  rated_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(trade_id, rater_id)
);

-- Enable RLS
ALTER TABLE p2p_ratings ENABLE ROW LEVEL SECURITY;

-- RLS Policies for ratings
CREATE POLICY "Users can view all ratings"
  ON p2p_ratings FOR SELECT
  USING (true);

CREATE POLICY "Users can create ratings for their trades"
  ON p2p_ratings FOR INSERT
  WITH CHECK (
    auth.uid() = rater_id AND
    EXISTS (
      SELECT 1 FROM p2p_trades
      WHERE id = trade_id
      AND (buyer_id = auth.uid() OR seller_id = auth.uid())
      AND status = 'completed'
    )
  );

-- Function to calculate user's average rating
CREATE OR REPLACE FUNCTION get_user_average_rating(user_id UUID)
RETURNS NUMERIC AS $$
BEGIN
  RETURN (
    SELECT COALESCE(AVG(rating), 0)
    FROM p2p_ratings
    WHERE rated_user_id = user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user's rating in profiles table
CREATE OR REPLACE FUNCTION update_user_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE profiles
  SET rating = get_user_average_rating(NEW.rated_user_id)
  WHERE id = NEW.rated_user_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-update user rating
DROP TRIGGER IF EXISTS trigger_update_user_rating ON p2p_ratings;
CREATE TRIGGER trigger_update_user_rating
  AFTER INSERT ON p2p_ratings
  FOR EACH ROW
  EXECUTE FUNCTION update_user_rating();

-- Drop existing function first to avoid parameter name conflicts
DROP FUNCTION IF EXISTS get_available_balance(UUID);

-- Function to get available balance (total_mined - locked in active sell ads)
CREATE FUNCTION get_available_balance(user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  total_balance NUMERIC;
  locked_balance NUMERIC;
BEGIN
  -- Get total balance
  SELECT COALESCE(total_mined, 0) INTO total_balance
  FROM profiles
  WHERE id = user_id;
  
  -- Get locked balance from active sell ads
  SELECT COALESCE(SUM(remaining_amount), 0) INTO locked_balance
  FROM p2p_ads
  WHERE user_id = get_available_balance.user_id
  AND ad_type = 'sell'
  AND status = 'active'
  AND expires_at > NOW();
  
  RETURN total_balance - locked_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_user_average_rating(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_balance(UUID) TO authenticated;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_p2p_ratings_rated_user ON p2p_ratings(rated_user_id);
CREATE INDEX IF NOT EXISTS idx_p2p_ratings_trade ON p2p_ratings(trade_id);
CREATE INDEX IF NOT EXISTS idx_p2p_ads_user_status ON p2p_ads(user_id, status, ad_type);
