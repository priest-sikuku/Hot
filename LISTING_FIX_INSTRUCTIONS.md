# Listing Creation Fix Instructions

## Issue
Users were getting "Failed to create listing" error because:
1. Database schema uses `seller_id` but code was using `user_id`
2. Missing columns: `listing_type`, `terms`, `payment_account`

## Solution

### Step 1: Run SQL Migration
Execute the SQL script `scripts/019_fix_listings_schema.sql` in your Supabase SQL Editor:

\`\`\`sql
-- Add missing columns to listings table
ALTER TABLE public.listings 
ADD COLUMN IF NOT EXISTS listing_type text NOT NULL DEFAULT 'sell',
ADD COLUMN IF NOT EXISTS terms text,
ADD COLUMN IF NOT EXISTS payment_account text;

-- Add check constraint for listing_type
ALTER TABLE public.listings 
ADD CONSTRAINT listings_type_check 
CHECK (listing_type IN ('buy', 'sell'));

-- Update RLS policies
DROP POLICY IF EXISTS "listings_select_all" ON public.listings;
CREATE POLICY "listings_select_all"
  ON public.listings FOR SELECT
  USING (status = 'active' OR auth.uid() = seller_id);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_listings_type_status ON public.listings(listing_type, status);
CREATE INDEX IF NOT EXISTS idx_listings_price ON public.listings(price_per_coin);
\`\`\`

### Step 2: Verify Changes
After running the migration:
1. Try creating a new listing
2. Check if it appears in the marketplace
3. Verify the listing shows in "My Orders"

### Step 3: Test Features
- Create a sell listing with terms and payment account
- Create a buy listing
- Verify listings appear sorted by price
- Check that payment account can be copied
- Test edit and delete functionality

## What Was Fixed
1. Changed `user_id` to `seller_id` in create-listing page
2. Added `listing_type`, `terms`, `payment_account` columns to database
3. Fixed market page to join with `seller_id` instead of `user_id`
4. Added better error messages showing actual error details
5. Added indexes for better query performance

## Expected Behavior
- Listings save successfully to database
- Listings appear immediately in marketplace
- Buy orders show lowest to highest price
- Sell orders show highest to lowest price
- Payment account and terms are displayed
- Users can edit and delete their own listings
