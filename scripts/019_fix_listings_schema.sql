-- Add missing columns to listings table
ALTER TABLE public.listings 
ADD COLUMN IF NOT EXISTS listing_type text NOT NULL DEFAULT 'sell',
ADD COLUMN IF NOT EXISTS terms text,
ADD COLUMN IF NOT EXISTS payment_account text;

-- Add check constraint for listing_type
ALTER TABLE public.listings 
ADD CONSTRAINT listings_type_check 
CHECK (listing_type IN ('buy', 'sell'));

-- Update RLS policies to work with both buy and sell listings
DROP POLICY IF EXISTS "listings_select_all" ON public.listings;
CREATE POLICY "listings_select_all"
  ON public.listings FOR SELECT
  USING (status = 'active' OR auth.uid() = seller_id);

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_listings_type_status ON public.listings(listing_type, status);
CREATE INDEX IF NOT EXISTS idx_listings_price ON public.listings(price_per_coin);
