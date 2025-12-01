# GrowX Referral System Setup Guide

## Overview
The GrowX referral system allows users to earn commissions from their referrals:
- **2% commission** on all trading volume from downline referrals
- **1% commission** on all claimed GX coins from downline referrals
- **Max supply**: 500,000 GX coins

## Database Schema

### New Tables Created

#### 1. `referrals` Table
Tracks referral relationships between users.

\`\`\`sql
- id: UUID (primary key)
- referrer_id: UUID (references auth.users)
- referred_id: UUID (references auth.users)
- referral_code: TEXT (unique)
- status: TEXT (active/inactive)
- total_trading_commission: NUMERIC
- total_claim_commission: NUMERIC
- created_at: TIMESTAMP
- updated_at: TIMESTAMP
\`\`\`

#### 2. `referral_commissions` Table
Tracks individual commission transactions.

\`\`\`sql
- id: UUID (primary key)
- referrer_id: UUID
- referred_id: UUID
- commission_type: TEXT (trading/claim)
- amount: NUMERIC
- source_id: UUID (trade_id or coin_id)
- status: TEXT (pending/completed)
- created_at: TIMESTAMP
- updated_at: TIMESTAMP
\`\`\`

### Updated Tables

#### `profiles` Table
Added referral-related fields:
- `referral_code`: TEXT (unique) - User's unique referral code
- `referred_by`: UUID - ID of the user who referred this user
- `total_referrals`: INTEGER - Count of successful referrals
- `total_commission`: NUMERIC - Total earned commissions
- `max_supply_limit`: NUMERIC - Set to 500,000

## SQL Scripts to Run

Run these scripts in order in your Supabase SQL editor:

1. `scripts/009_create_referrals.sql` - Creates referrals and referral_commissions tables
2. `scripts/010_update_profiles_for_referrals.sql` - Adds referral fields to profiles
3. `scripts/011_update_coins_for_max_supply.sql` - Adds max supply tracking

## Features Implemented

### 1. Signup with Referral Code
- Users can enter an optional referral code during signup
- Referral code auto-populates from URL parameter: `/auth/sign-up?ref=CODE`
- Each user gets a unique referral code: `GX_USERNAME_RANDOM`

### 2. Referral Dashboard (`/referrals`)
- View total referrals count
- View trading commissions earned
- View claim commissions earned
- View total commissions
- Copy referral link to clipboard
- Share referral link on WhatsApp and Twitter
- View detailed list of all referrals with their commission breakdown

### 3. Commission Tracking
- **Trading Commission (2%)**: Automatically calculated when a referral completes a trade
- **Claim Commission (1%)**: Automatically calculated when a referral claims coins
- Commissions are tracked in `referral_commissions` table
- Totals are updated in `referrals` table

### 4. Max Supply Management
- Total GX coins in circulation cannot exceed 500,000
- View current supply status via `total_coins_in_circulation` view
- Prevents over-minting of coins

## Integration Points

### In Mining Context
When a user claims coins or completes a trade:

\`\`\`typescript
// For claim commissions
await addClaimCommission(referrerId, userId, claimAmount, coinId)

// For trading commissions
await addTradingCommission(referrerId, userId, tradeAmount, tradeId)
\`\`\`

### In Signup Flow
1. User enters referral code (optional)
2. System validates referral code exists
3. Creates referral relationship
4. Updates referrer's total_referrals count

## User Experience Flow

### For New Users
1. Visit `/auth/sign-up?ref=GX_JOHN_ABC123`
2. Referral code auto-fills in the form
3. Complete signup
4. Automatically linked to referrer

### For Referrers
1. Go to `/referrals` page
2. Copy referral link or code
3. Share on WhatsApp, Twitter, or manually
4. View all referrals and commissions in real-time
5. Commissions automatically added when referrals trade or claim

## Testing the System

### Test Referral Signup
1. Create user A with referral code
2. Copy their referral code
3. Create user B using user A's referral code
4. Verify referral relationship in database

### Test Commission Calculation
1. User B claims 100 GX coins
2. User A should receive 1 GX commission (1%)
3. User B trades 1000 GX
4. User A should receive 20 GX commission (2%)

## Security Considerations

- Row Level Security (RLS) enabled on all referral tables
- Users can only see their own referrals
- Commission calculations are server-side only
- Referral codes are unique and cannot be duplicated
- Max supply is enforced at database level

## Future Enhancements

- Multi-level referral system (earn from referrals of referrals)
- Referral tier system with increasing commission rates
- Referral leaderboard
- Referral bonus rewards
- Withdrawal of earned commissions
