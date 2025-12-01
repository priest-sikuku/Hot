-- Drop existing P2P tables and rebuild from scratch
DROP TABLE IF EXISTS trade_messages CASCADE;
DROP TABLE IF EXISTS ratings CASCADE;
DROP TABLE IF EXISTS trades CASCADE;
DROP TABLE IF EXISTS listings CASCADE;

-- Create listings table (ads) - Binance/Bybit style
CREATE TABLE listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ad_type TEXT NOT NULL CHECK (ad_type IN ('buy', 'sell')),
  coin_amount NUMERIC NOT NULL CHECK (coin_amount > 0),
  price_per_coin NUMERIC NOT NULL CHECK (price_per_coin > 0),
  min_order_amount NUMERIC NOT NULL DEFAULT 1 CHECK (min_order_amount > 0),
  max_order_amount NUMERIC NOT NULL CHECK (max_order_amount > 0),
  payment_methods TEXT[] NOT NULL,
  payment_details JSONB, -- Store payment account details
  terms TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'expired')),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '3 days'),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create trades table
CREATE TABLE trades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  buyer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  seller_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  coin_amount NUMERIC NOT NULL CHECK (coin_amount > 0),
  price_per_coin NUMERIC NOT NULL CHECK (price_per_coin > 0),
  total_price NUMERIC NOT NULL CHECK (total_price > 0),
  payment_method TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'released', 'cancelled', 'expired', 'disputed')),
  buyer_paid_at TIMESTAMP WITH TIME ZONE,
  seller_released_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '30 minutes'),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create trade messages table for chat
CREATE TABLE trade_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_id UUID NOT NULL REFERENCES trades(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create ratings table
CREATE TABLE ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_id UUID NOT NULL REFERENCES trades(id) ON DELETE CASCADE,
  rater_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rated_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(trade_id, rater_id)
);

-- Create indexes
CREATE INDEX idx_listings_user_id ON listings(user_id);
CREATE INDEX idx_listings_ad_type ON listings(ad_type);
CREATE INDEX idx_listings_status ON listings(status);
CREATE INDEX idx_listings_expires_at ON listings(expires_at);
CREATE INDEX idx_trades_listing_id ON trades(listing_id);
CREATE INDEX idx_trades_buyer_id ON trades(buyer_id);
CREATE INDEX idx_trades_seller_id ON trades(seller_id);
CREATE INDEX idx_trades_status ON trades(status);
CREATE INDEX idx_trades_expires_at ON trades(expires_at);
CREATE INDEX idx_trade_messages_trade_id ON trade_messages(trade_id);
CREATE INDEX idx_ratings_rated_user_id ON ratings(rated_user_id);

-- Enable RLS
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE trades ENABLE ROW LEVEL SECURITY;
ALTER TABLE trade_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;

-- RLS Policies for listings
CREATE POLICY "Anyone can view active listings"
  ON listings FOR SELECT
  USING (status = 'active' AND expires_at > NOW());

CREATE POLICY "Users can create their own listings"
  ON listings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own listings"
  ON listings FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own listings"
  ON listings FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policies for trades
CREATE POLICY "Users can view their own trades"
  ON trades FOR SELECT
  USING (auth.uid() = buyer_id OR auth.uid() = seller_id);

CREATE POLICY "Users can create trades"
  ON trades FOR INSERT
  WITH CHECK (auth.uid() = buyer_id OR auth.uid() = seller_id);

CREATE POLICY "Trade participants can update trades"
  ON trades FOR UPDATE
  USING (auth.uid() = buyer_id OR auth.uid() = seller_id);

-- RLS Policies for trade messages
CREATE POLICY "Trade participants can view messages"
  ON trade_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM trades
      WHERE trades.id = trade_messages.trade_id
      AND (trades.buyer_id = auth.uid() OR trades.seller_id = auth.uid())
    )
  );

CREATE POLICY "Trade participants can send messages"
  ON trade_messages FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM trades
      WHERE trades.id = trade_messages.trade_id
      AND (trades.buyer_id = auth.uid() OR trades.seller_id = auth.uid())
    )
  );

-- RLS Policies for ratings
CREATE POLICY "Anyone can view ratings"
  ON ratings FOR SELECT
  USING (true);

CREATE POLICY "Trade participants can create ratings"
  ON ratings FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM trades
      WHERE trades.id = ratings.trade_id
      AND (trades.buyer_id = auth.uid() OR trades.seller_id = auth.uid())
      AND trades.status = 'released'
    )
  );

-- Function to auto-expire listings after 3 days
CREATE OR REPLACE FUNCTION expire_old_listings()
RETURNS void AS $$
BEGIN
  UPDATE listings
  SET status = 'expired'
  WHERE status = 'active'
  AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to auto-expire trades after 30 minutes
CREATE OR REPLACE FUNCTION expire_old_trades()
RETURNS void AS $$
BEGIN
  UPDATE trades
  SET status = 'expired'
  WHERE status = 'pending'
  AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to update listing amount after trade
CREATE OR REPLACE FUNCTION update_listing_amount()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'released' THEN
    UPDATE listings
    SET coin_amount = coin_amount - NEW.coin_amount,
        updated_at = NOW()
    WHERE id = NEW.listing_id;
    
    -- Deactivate listing if no coins left
    UPDATE listings
    SET status = 'inactive'
    WHERE id = NEW.listing_id
    AND coin_amount <= 0;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_listing_after_trade
AFTER UPDATE ON trades
FOR EACH ROW
EXECUTE FUNCTION update_listing_amount();

-- Function to calculate user rating
CREATE OR REPLACE FUNCTION get_user_rating(p_user_id UUID)
RETURNS NUMERIC AS $$
DECLARE
  avg_rating NUMERIC;
BEGIN
  SELECT COALESCE(AVG(rating), 0)
  INTO avg_rating
  FROM ratings
  WHERE rated_user_id = p_user_id;
  
  RETURN ROUND(avg_rating, 1);
END;
$$ LANGUAGE plpgsql;

-- Function to get user trade count
CREATE OR REPLACE FUNCTION get_user_trade_count(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  trade_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO trade_count
  FROM trades
  WHERE (buyer_id = p_user_id OR seller_id = p_user_id)
  AND status = 'released';
  
  RETURN trade_count;
END;
$$ LANGUAGE plpgsql;

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER listings_updated_at
BEFORE UPDATE ON listings
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trades_updated_at
BEFORE UPDATE ON trades
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();
