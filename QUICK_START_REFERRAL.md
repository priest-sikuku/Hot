# GrowX Referral System - Quick Start Guide

## 5-Minute Setup

### Step 1: Run SQL Scripts (2 minutes)
1. Open your Supabase project
2. Go to SQL Editor
3. Run these scripts in order:
   - `scripts/009_create_referrals.sql`
   - `scripts/010_update_profiles_for_referrals.sql`
   - `scripts/011_update_coins_for_max_supply.sql`

### Step 2: Deploy Code (2 minutes)
1. The code is already updated
2. Deploy to Vercel
3. Wait for deployment to complete

### Step 3: Test (1 minute)
1. Go to `/auth/sign-up`
2. Create account with username
3. Go to `/referrals` to see your referral code
4. Copy the referral link

## How It Works

### For Users
- **Sign up**: Enter email, username, password, optional referral code
- **Get referral code**: Automatically generated as `GX_USERNAME_RANDOM`
- **Share**: Copy link or share on WhatsApp/Twitter
- **Earn**: Get 2% on trades + 1% on claims from referrals

### For Referrers
- **Dashboard**: `/referrals` shows all stats
- **Commissions**: Automatically calculated and displayed
- **Sharing**: Built-in share buttons for WhatsApp and Twitter

## Key Features

✅ Email + Username + Password authentication
✅ Optional referral code on signup
✅ Auto-fill referral code from URL
✅ Unique referral code generation
✅ 2% trading commission
✅ 1% claim commission
✅ 500,000 GX max supply
✅ Referral dashboard with stats
✅ Share on WhatsApp and Twitter
✅ Real-time commission tracking

## Referral Link Format

\`\`\`
https://yoursite.com/auth/sign-up?ref=GX_USERNAME_ABC123
\`\`\`

## Commission Examples

### Claim Commission (1%)
- User claims 100 GX
- Referrer gets 1 GX

### Trading Commission (2%)
- User trades 1000 GX
- Referrer gets 20 GX

## Database Tables

- `referrals` - Tracks referral relationships
- `referral_commissions` - Tracks individual commissions
- `profiles` - Updated with referral fields

## Troubleshooting

**Referral code not auto-filling?**
- Check URL has `?ref=CODE` parameter
- Verify referral code exists in database

**Commissions not showing?**
- Ensure SQL scripts ran successfully
- Check referral relationship exists
- Verify commission calculation logic

**Max supply not working?**
- Run script 011 again
- Check `total_coins_in_circulation` view

## Next: Integration

To fully activate commissions:
1. Update mining context to call `addClaimCommission()`
2. Update trade completion to call `addTradingCommission()`
3. Test end-to-end commission flow

## Support

See detailed docs:
- `REFERRAL_SYSTEM_SETUP.md` - Full setup guide
- `RUN_REFERRAL_SQL_SCRIPTS.md` - SQL execution guide
- `REFERRAL_IMPLEMENTATION_SUMMARY.md` - Complete overview
