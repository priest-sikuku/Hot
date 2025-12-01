# Running Referral System SQL Scripts

## Prerequisites
- Supabase project connected
- Access to Supabase SQL Editor

## Steps to Run Scripts

### 1. Open Supabase SQL Editor
- Go to your Supabase project dashboard
- Click on "SQL Editor" in the left sidebar
- Click "New Query"

### 2. Run Script 009 - Create Referrals Tables
Copy the contents of `scripts/009_create_referrals.sql` and paste into the SQL editor.
Click "Run" and wait for success message.

### 3. Run Script 010 - Update Profiles Table
Copy the contents of `scripts/010_update_profiles_for_referrals.sql` and paste into the SQL editor.
Click "Run" and wait for success message.

### 4. Run Script 011 - Update Coins for Max Supply
Copy the contents of `scripts/011_update_coins_for_max_supply.sql` and paste into the SQL editor.
Click "Run" and wait for success message.

## Verification

After running all scripts, verify the setup:

### Check Referrals Table
\`\`\`sql
select * from public.referrals limit 1;
\`\`\`

### Check Referral Commissions Table
\`\`\`sql
select * from public.referral_commissions limit 1;
\`\`\`

### Check Updated Profiles
\`\`\`sql
select referral_code, referred_by, total_referrals, total_commission 
from public.profiles limit 1;
\`\`\`

### Check Total Coins View
\`\`\`sql
select * from public.total_coins_in_circulation;
\`\`\`

## Troubleshooting

### Error: "relation already exists"
- The table already exists from a previous run
- This is safe to ignore, or drop the table first:
\`\`\`sql
drop table if exists public.referrals cascade;
drop table if exists public.referral_commissions cascade;
\`\`\`

### Error: "column already exists"
- The column was already added in a previous run
- This is safe to ignore

### Referral Code Not Generating
- Ensure the profiles table has the referral_code column
- Run script 010 again

## Next Steps

1. Test the signup flow with a referral code
2. Verify referral relationships in the database
3. Test commission calculations
4. Deploy to production

## Support

If you encounter issues:
1. Check the Supabase logs for detailed error messages
2. Verify all scripts ran successfully
3. Check that Row Level Security policies are enabled
4. Ensure auth.users table exists and is properly configured
