-- Drop all P2P marketplace tables and related objects
DROP TABLE IF EXISTS trade_messages CASCADE;
DROP TABLE IF EXISTS ratings CASCADE;
DROP TABLE IF EXISTS trades CASCADE;
DROP TABLE IF EXISTS listings CASCADE;

-- Drop any P2P-related functions
DROP FUNCTION IF EXISTS expire_old_trades() CASCADE;
DROP FUNCTION IF EXISTS expire_old_listings() CASCADE;
DROP FUNCTION IF EXISTS update_listings_updated_at() CASCADE;
DROP FUNCTION IF EXISTS lock_escrow(uuid, numeric) CASCADE;
DROP FUNCTION IF EXISTS release_escrow(uuid, uuid, numeric) CASCADE;

-- Remove P2P-related columns from profiles if they exist
ALTER TABLE profiles DROP COLUMN IF EXISTS total_trades;

-- Note: Run this script in your Supabase SQL editor to completely remove all P2P functionality
