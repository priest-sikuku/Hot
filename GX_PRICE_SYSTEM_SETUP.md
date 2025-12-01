# GX Price System Setup Guide

## Overview
The GX price system implements a dynamic cryptocurrency-like pricing model with:
- Base price: 16 KES
- Guaranteed 3% daily increase at 3pm
- Real-time price fluctuations (±20% max)
- Activity-based volatility
- Auto-refresh every 2 seconds

## Database Setup

### Step 1: Run SQL Scripts
Execute these scripts in your Supabase SQL Editor in order:

1. **scripts/023_create_gx_price_system.sql** - Creates price tables and functions
2. **scripts/024_create_price_update_cron.sql** - Creates daily update function

### Step 2: Set Up Daily Price Update (Optional)
To automatically update the reference price at 3pm daily, you have two options:

#### Option A: Supabase Cron (Recommended)
If your Supabase plan supports cron jobs:
\`\`\`sql
SELECT cron.schedule(
  'update-gx-reference-price',
  '0 15 * * *', -- Run at 3pm daily
  $$SELECT check_and_update_reference_price()$$
);
\`\`\`

#### Option B: Manual Update
Run this SQL command daily at 3pm or later:
\`\`\`sql
SELECT check_and_update_reference_price();
\`\`\`

#### Option C: External Cron Job
Set up a cron job on your server to call:
\`\`\`bash
curl -X POST https://your-app.vercel.app/api/update-price-reference
\`\`\`

## How It Works

### Price Calculation Logic
1. **Base Price**: 16 KES (starting point)
2. **Daily Reference**: At 3pm each day, price increases by 3%
   - Day 1 (3pm): 16.00 KES
   - Day 2 (3pm): 16.48 KES (16 × 1.03)
   - Day 3 (3pm): 16.97 KES (16.48 × 1.03)
   - And so on...

3. **Intraday Fluctuations**:
   - Price trends towards next day's 3pm target
   - Random volatility based on trading activity
   - More trades = higher volatility (up to ±20%)
   - Price bounded between 80% and 120% of current reference

4. **Color Coding**:
   - Green: Price increasing
   - Red: Price decreasing
   - Updates every 2 seconds

### Trading Activity Impact
- Base volatility: 2%
- Each trade in the last hour adds 1% volatility
- Maximum volatility: 20%
- More active trading = more price swings

## API Endpoint

### GET /api/gx-price
Returns current GX price with metadata:
\`\`\`json
{
  "price": 16.45,
  "previousPrice": 16.32,
  "changePercent": 0.80,
  "volatility": 5.2,
  "referencePrice": 16.00,
  "targetPrice": 16.48
}
\`\`\`

## Component Usage

The `GXPriceDisplay` component is automatically included in the dashboard stats.
It fetches the price every 2 seconds and displays it with color-coded changes.

## Monitoring

### Check Current Price
\`\`\`sql
SELECT * FROM gx_current_price;
\`\`\`

### View Price History
\`\`\`sql
SELECT * FROM gx_price_history
ORDER BY timestamp DESC
LIMIT 100;
\`\`\`

### View Reference Prices
\`\`\`sql
SELECT * FROM gx_price_references
ORDER BY reference_date DESC;
\`\`\`

## Troubleshooting

### Price Not Updating
1. Check if API route is accessible: `/api/gx-price`
2. Verify database tables exist
3. Check browser console for errors

### Reference Price Not Updating at 3pm
1. Manually run: `SELECT check_and_update_reference_price();`
2. Verify cron job is set up correctly
3. Check Supabase logs for errors

### Price Stuck or Not Fluctuating
1. Check if trades table has recent data
2. Verify volatility calculation function
3. Clear browser cache and refresh

## Future Enhancements
- Price charts and historical data visualization
- Price alerts and notifications
- Market depth and order book
- Price prediction based on trading patterns
