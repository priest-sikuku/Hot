-- Create P2P Ads/Listings Table
CREATE TABLE IF NOT EXISTS public.p2p_ads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  ad_type TEXT NOT NULL CHECK (ad_type IN ('buy', 'sell')),
  gx_amount NUMERIC NOT NULL CHECK (gx_amount > 0),
  min_amount NUMERIC NOT NULL CHECK (min_amount > 0),
  max_amount NUMERIC NOT NULL CHECK (max_amount >= min_amount),
  account_number TEXT,
  mpesa_number TEXT,
  paybill_number TEXT,
  airtel_money TEXT,
  terms_of_trade TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'completed', 'cancelled')),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '3 days'),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_p2p_ads_user_id ON public.p2p_ads(user_id);
CREATE INDEX IF NOT EXISTS idx_p2p_ads_ad_type ON public.p2p_ads(ad_type);
CREATE INDEX IF NOT EXISTS idx_p2p_ads_status ON public.p2p_ads(status);
CREATE INDEX IF NOT EXISTS idx_p2p_ads_expires_at ON public.p2p_ads(expires_at);

-- Enable Row Level Security
ALTER TABLE public.p2p_ads ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Anyone can view active ads
CREATE POLICY "Anyone can view active ads"
  ON public.p2p_ads
  FOR SELECT
  USING (status = 'active' AND expires_at > NOW());

-- Users can view their own ads
CREATE POLICY "Users can view their own ads"
  ON public.p2p_ads
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can create their own ads
CREATE POLICY "Users can create their own ads"
  ON public.p2p_ads
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own ads
CREATE POLICY "Users can update their own ads"
  ON public.p2p_ads
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own ads
CREATE POLICY "Users can delete their own ads"
  ON public.p2p_ads
  FOR DELETE
  USING (auth.uid() = user_id);

-- Function to auto-expire old ads
CREATE OR REPLACE FUNCTION expire_old_p2p_ads()
RETURNS void AS $$
BEGIN
  UPDATE public.p2p_ads
  SET status = 'inactive'
  WHERE status = 'active' 
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_p2p_ads_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_p2p_ads_updated_at_trigger
  BEFORE UPDATE ON public.p2p_ads
  FOR EACH ROW
  EXECUTE FUNCTION update_p2p_ads_updated_at();
