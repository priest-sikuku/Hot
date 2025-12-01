-- Fix RLS policies for trades table to ensure users can read their own trades

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own trades" ON trades;
DROP POLICY IF EXISTS "Users can insert trades" ON trades;
DROP POLICY IF EXISTS "Users can update their own trades" ON trades;

-- Create new comprehensive policies
CREATE POLICY "Users can view trades they are part of"
ON trades FOR SELECT
USING (
  auth.uid() = buyer_id OR 
  auth.uid() = seller_id
);

CREATE POLICY "Authenticated users can create trades"
ON trades FOR INSERT
WITH CHECK (
  auth.uid() IS NOT NULL AND
  (auth.uid() = buyer_id OR auth.uid() = seller_id)
);

CREATE POLICY "Trade participants can update trades"
ON trades FOR UPDATE
USING (
  auth.uid() = buyer_id OR 
  auth.uid() = seller_id
)
WITH CHECK (
  auth.uid() = buyer_id OR 
  auth.uid() = seller_id
);

-- Ensure RLS is enabled
ALTER TABLE trades ENABLE ROW LEVEL SECURITY;

-- Fix trade_messages RLS policies
DROP POLICY IF EXISTS "Users can view messages in their trades" ON trade_messages;
DROP POLICY IF EXISTS "Users can send messages in their trades" ON trade_messages;

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
  auth.uid() = sender_id AND
  EXISTS (
    SELECT 1 FROM trades
    WHERE trades.id = trade_messages.trade_id
    AND (trades.buyer_id = auth.uid() OR trades.seller_id = auth.uid())
  )
);

ALTER TABLE trade_messages ENABLE ROW LEVEL SECURITY;

-- Fix listings RLS policies
DROP POLICY IF EXISTS "Anyone can view active listings" ON listings;
DROP POLICY IF EXISTS "Users can create listings" ON listings;
DROP POLICY IF EXISTS "Users can update their own listings" ON listings;

CREATE POLICY "Anyone can view active listings"
ON listings FOR SELECT
USING (status = 'active' OR auth.uid() = user_id);

CREATE POLICY "Authenticated users can create listings"
ON listings FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own listings"
ON listings FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
