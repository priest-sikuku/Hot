-- Add referral tracking columns to profiles if not exists
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS referred_by uuid REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS total_referrals integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS commission_earned numeric DEFAULT 0.00;

-- Create a view for user statistics
CREATE OR REPLACE VIEW public.user_stats AS
SELECT 
  p.id as user_id,
  p.username,
  p.rating,
  p.total_trades,
  p.total_referrals,
  p.commission_earned,
  -- Calculate ROI from completed trades
  COALESCE(
    (SELECT 
      SUM(CASE 
        WHEN t.buyer_id = p.id THEN (t.coin_amount * gp.price) - t.total_price
        WHEN t.seller_id = p.id THEN t.total_price - (t.coin_amount * gp.price)
        ELSE 0
      END)
    FROM trades t
    CROSS JOIN LATERAL (
      SELECT price FROM gx_price_history 
      WHERE DATE(created_at) = DATE(t.created_at)
      ORDER BY created_at DESC LIMIT 1
    ) gp
    WHERE (t.buyer_id = p.id OR t.seller_id = p.id) 
    AND t.status = 'completed'
    ), 0
  ) as total_roi
FROM profiles p;

-- Grant access to the view
GRANT SELECT ON public.user_stats TO authenticated;

-- Create function to update referral count
CREATE OR REPLACE FUNCTION update_referral_count()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.referred_by IS NOT NULL THEN
    UPDATE profiles 
    SET total_referrals = total_referrals + 1
    WHERE id = NEW.referred_by;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for referral count
DROP TRIGGER IF EXISTS on_referral_signup ON profiles;
CREATE TRIGGER on_referral_signup
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_referral_count();

-- Create view for price history (last 5 days)
CREATE OR REPLACE VIEW public.price_history_5days AS
SELECT 
  DATE(created_at) as date,
  AVG(price) as avg_price,
  MIN(price) as min_price,
  MAX(price) as max_price,
  MAX(created_at) as last_updated
FROM gx_price_history
WHERE created_at >= NOW() - INTERVAL '5 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- Grant access to price history view
GRANT SELECT ON public.price_history_5days TO authenticated;
