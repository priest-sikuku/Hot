# GrowX Supabase Setup Guide

## Overview
This guide explains how to set up and use Supabase with the GrowX application for user authentication, coin management, P2P trading, and ratings.

## Database Schema

### Tables Created

1. **profiles** - User profile information
   - id (UUID, references auth.users)
   - email (TEXT)
   - username (TEXT, unique)
   - avatar_url (TEXT)
   - bio (TEXT)
   - created_at, updated_at (TIMESTAMPS)

2. **coins** - Track claimed and mined coins
   - id (UUID)
   - user_id (UUID, references auth.users)
   - amount (NUMERIC)
   - claim_type (TEXT: mining, trading, bonus)
   - locked_until (TIMESTAMP)
   - lock_period_days (INTEGER)
   - bonus_percentage (NUMERIC)
   - status (TEXT: active, locked, claimed)
   - created_at, updated_at (TIMESTAMPS)

3. **listings** - P2P sell listings
   - id (UUID)
   - seller_id (UUID, references auth.users)
   - coin_amount (NUMERIC)
   - price_per_coin (NUMERIC)
   - currency (TEXT, default: KES)
   - payment_methods (TEXT[])
   - status (TEXT: active, sold, cancelled)
   - created_at, updated_at (TIMESTAMPS)

4. **trades** - P2P trade transactions
   - id (UUID)
   - listing_id (UUID, references listings)
   - buyer_id (UUID, references auth.users)
   - seller_id (UUID, references auth.users)
   - coin_amount (NUMERIC)
   - total_price (NUMERIC)
   - payment_method (TEXT)
   - status (TEXT: pending, escrow, completed, cancelled)
   - buyer_confirmed (BOOLEAN)
   - seller_confirmed (BOOLEAN)
   - created_at, updated_at (TIMESTAMPS)

5. **ratings** - User ratings and reviews
   - id (UUID)
   - trade_id (UUID, references trades)
   - rater_id (UUID, references auth.users)
   - rated_user_id (UUID, references auth.users)
   - rating (INTEGER: 1-5)
   - review (TEXT)
   - created_at (TIMESTAMP)

6. **transactions** - Transaction history
   - id (UUID)
   - user_id (UUID, references auth.users)
   - type (TEXT: mining, claim, buy, sell, bonus)
   - amount (NUMERIC)
   - description (TEXT)
   - related_id (UUID)
   - status (TEXT: pending, completed, failed)
   - created_at (TIMESTAMP)

## Running SQL Scripts

All SQL migration scripts are in the `/scripts` folder:

1. `001_create_profiles.sql` - User profiles table
2. `002_create_coins.sql` - Coins/claims table
3. `003_create_listings.sql` - P2P listings table
4. `004_create_trades.sql` - Trade transactions table
5. `005_create_ratings.sql` - Ratings/reviews table
6. `006_create_transactions.sql` - Transaction history table
7. `007_create_profile_trigger.sql` - Auto-create profile on signup
8. `008_create_user_stats_view.sql` - User statistics view

Run these scripts in order in your Supabase SQL editor or use the v0 script execution feature.

## Authentication Flow

### Sign Up
1. User enters email, password, and name
2. `supabase.auth.signUp()` creates auth user
3. Trigger auto-creates profile row
4. Email confirmation required
5. Redirect to sign-up-success page

### Sign In
1. User enters email and password
2. `supabase.auth.signInWithPassword()` authenticates
3. Session created and stored in cookies
4. Redirect to dashboard

### Protected Routes
- Middleware checks authentication on every request
- Unauthenticated users redirected to `/auth/sign-in`
- Protected pages use server components with `createClient()`

## Key Features

### Mining System
- Users mine coins every 2 hours
- Mining transactions stored in `transactions` table
- Rewards tracked in `coins` table
- 3% daily compound growth applied

### Coin Claiming
- Users can claim coins for 7-day lock period
- Locked coins stored in `coins` table with `status: 'locked'`
- After lock period, coins become `status: 'active'`
- Bonus rewards applied during lock period

### P2P Trading
- Sellers create listings in `listings` table
- Buyers initiate trades in `trades` table
- Escrow protection with buyer/seller confirmation
- Payment methods: M-Pesa, Bank Transfer, Airtel Money

### Rating System
- After trade completion, users can rate each other
- Ratings stored in `ratings` table
- Average rating calculated from all ratings
- Reputation system for traders

### Transaction History
- All activities logged in `transactions` table
- Types: mining, claim, buy, sell, bonus
- Status tracking: pending, completed, failed
- Related IDs link to trades, listings, etc.

## Row Level Security (RLS)

All tables have RLS enabled with policies:

- **profiles**: Users can only view/edit their own profile
- **coins**: Users can only view/edit their own coins
- **listings**: Anyone can view active listings, sellers can manage their own
- **trades**: Users can only view/edit their own trades
- **ratings**: Anyone can view ratings, users can only create their own
- **transactions**: Users can only view their own transactions

## Environment Variables

Required environment variables (automatically set by Supabase integration):

\`\`\`
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
\`\`\`

Optional for development:
\`\`\`
NEXT_PUBLIC_DEV_SUPABASE_REDIRECT_URL=http://localhost:3000
\`\`\`

## Database Utilities

Helper functions in `/lib/db/`:

- `coins.ts` - Coin operations (claim, unclaim, get total)
- `listings.ts` - Listing management (create, get, update)
- `trades.ts` - Trade operations (create, get, update status)
- `ratings.ts` - Rating operations (create, get average)
- `transactions.ts` - Transaction tracking (create, get history)

## Testing

1. Sign up with a test email
2. Confirm email in Supabase Auth dashboard
3. Sign in and access dashboard
4. Test mining, claiming, and trading features
5. Check Supabase dashboard to verify data is saved

## Troubleshooting

### Email Confirmation Issues
- Check Supabase email settings
- Verify redirect URL is correct
- Check spam folder for confirmation email

### RLS Policy Errors
- Ensure user is authenticated
- Check that user_id matches auth.uid()
- Verify RLS policies are enabled on tables

### Data Not Saving
- Check browser console for errors
- Verify Supabase credentials are correct
- Check RLS policies allow the operation
- Ensure user is authenticated

## Next Steps

1. Run all SQL migration scripts
2. Test authentication flow
3. Test mining and claiming features
4. Test P2P trading functionality
5. Deploy to production with Vercel
