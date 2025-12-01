# How to Run SQL Migration Scripts

## Option 1: Using v0 Script Execution (Recommended)

The SQL scripts are located in the `/scripts` folder and can be executed directly through v0:

1. Go to your Code Project
2. Click on the script files in the `/scripts` folder
3. Click "Run" to execute each script in order

**Order to run:**
1. `001_create_profiles.sql`
2. `002_create_coins.sql`
3. `003_create_listings.sql`
4. `004_create_trades.sql`
5. `005_create_ratings.sql`
6. `006_create_transactions.sql`
7. `007_create_profile_trigger.sql`
8. `008_create_user_stats_view.sql`

## Option 2: Using Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Click "New Query"
4. Copy and paste the contents of each SQL file
5. Click "Run" to execute
6. Repeat for each file in order

## Option 3: Using Supabase CLI

\`\`\`bash
# Install Supabase CLI
npm install -g supabase

# Link to your project
supabase link --project-ref your_project_ref

# Run migrations
supabase db push
\`\`\`

## Verification

After running all scripts, verify the setup:

1. **Check Tables**: In Supabase dashboard, go to Table Editor
   - Should see: profiles, coins, listings, trades, ratings, transactions

2. **Check RLS**: In Supabase dashboard, go to Authentication > Policies
   - Each table should have RLS enabled with policies

3. **Check Trigger**: In Supabase dashboard, go to Database > Functions
   - Should see: handle_new_user function

4. **Check View**: In Supabase dashboard, go to Table Editor
   - Should see: user_stats view

## Troubleshooting

### Error: "relation already exists"
- The table already exists
- Drop the table first: `DROP TABLE IF EXISTS table_name CASCADE;`
- Then run the script again

### Error: "permission denied"
- Check your Supabase role permissions
- Ensure you're using a role with DDL permissions

### Error: "function does not exist"
- The trigger function wasn't created
- Run `007_create_profile_trigger.sql` again

### Tables created but no data
- This is normal - tables are empty until users sign up
- Sign up a test user to populate data

## Testing the Setup

1. **Test Authentication**
   \`\`\`
   - Go to /auth/sign-up
   - Create a test account
   - Confirm email
   - Check Supabase Auth dashboard - user should appear
   - Check profiles table - profile should be auto-created
   \`\`\`

2. **Test Mining**
   \`\`\`
   - Sign in
   - Go to dashboard
   - Click "Mine Now"
   - Check transactions table - mining transaction should appear
   - Check coins table - coins should be added
   \`\`\`

3. **Test Claiming**
   \`\`\`
   - Click "Claim Coins"
   - Check coins table - new coin entry with status 'locked'
   - Check transactions table - claim transaction should appear
   \`\`\`

4. **Test P2P Trading**
   \`\`\`
   - Go to P2P Market
   - Create a listing
   - Check listings table - listing should appear
   - Initiate a trade
   - Check trades table - trade should appear
   \`\`\`

5. **Test Ratings**
   \`\`\`
   - Complete a trade
   - Rate the seller
   - Check ratings table - rating should appear
   - Check user_stats view - average rating should update
   \`\`\`

## Common Issues and Solutions

### Issue: "Email confirmation not working"
**Solution:**
- Check Supabase email settings
- Verify SMTP configuration
- Check spam folder
- Use test email if available

### Issue: "Profile not auto-creating on signup"
**Solution:**
- Verify trigger was created: `007_create_profile_trigger.sql`
- Check trigger is enabled in Supabase dashboard
- Manually create profile if needed

### Issue: "RLS blocking operations"
**Solution:**
- Ensure user is authenticated
- Check RLS policies allow the operation
- Verify user_id matches auth.uid()
- Temporarily disable RLS for testing (not recommended for production)

### Issue: "Data not persisting"
**Solution:**
- Check browser console for errors
- Verify Supabase credentials
- Check RLS policies
- Ensure user is authenticated
- Check database connection

## Next Steps

After successful setup:

1. Test all features thoroughly
2. Set up monitoring and alerts
3. Configure backups
4. Set up staging environment
5. Deploy to production
6. Monitor performance and errors
7. Gather user feedback
8. Iterate and improve

## Support

For additional help:
- Check Supabase documentation: https://supabase.com/docs
- Review SUPABASE_SETUP.md for detailed information
- Check browser console for error messages
- Review Supabase dashboard logs
