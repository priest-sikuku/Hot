# P2P Marketplace Setup Instructions

## Database Setup

Run the following SQL script in your Supabase SQL Editor:

### Script: `scripts/020_fix_listings_table.sql`

This script will:
1. Drop the old listings table (if it exists)
2. Create a new listings table with the correct structure
3. Add proper indexes for performance
4. Set up Row Level Security (RLS) policies
5. Add an auto-update trigger for `updated_at`

## Key Changes Made

### Database Schema
- **user_id**: Stores the user who created the listing (buyer or seller)
- **listing_type**: Either 'buy' or 'sell'
- **payment_account**: Only required for sell listings (where seller receives payment)
- **terms**: Optional terms of trade
- **payment_methods**: Array of accepted payment methods

### Buy vs Sell Listings

**Buy Listings** (User wants to buy GX):
- Required fields: amount, price, payment methods, terms (optional)
- NO payment account needed (buyer doesn't provide account)

**Sell Listings** (User wants to sell GX):
- Required fields: amount, price, payment account, payment methods, terms (optional)
- Payment account IS required (seller needs to provide where to receive payment)

### Display Logic
- When user clicks "Buy GX" tab → Shows SELL listings (lowest to highest price)
- When user clicks "Sell GX" tab → Shows BUY listings (highest to lowest price)

## Testing

1. Run the SQL script in Supabase
2. Create a sell listing with payment account
3. Create a buy listing without payment account
4. Verify listings appear in the correct tabs
5. Check that listings are sorted by price correctly

## Troubleshooting

If you see errors:
- **"seller_id does not exist"**: Run the SQL script to recreate the table
- **"payment_acc column not found"**: The column is now called `payment_account`
- **Listings not showing**: Check browser console for errors and verify RLS policies
