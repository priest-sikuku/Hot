# P2P Trading Flow with Escrow

## Complete Trading Process

### 1. **Initiate Trade** (Buyer)
- Buyer clicks on a listing in the marketplace
- Enters amount and selects payment method
- Clicks "Buy GX" or "Sell GX"
- **System Action**: 
  - Creates trade record in database
  - Moves seller's coins to escrow (locks them)
  - Updates listing amount
  - Redirects to trade status page

### 2. **Payment Pending** (Status: `escrow`)
- **Buyer sees**: Payment account number to send money to
- **Seller sees**: Waiting message for buyer to send payment
- Coins are locked in escrow (seller can't access them)

### 3. **Mark as Paid** (Buyer)
- Buyer sends payment via M-Pesa/Bank Transfer
- Buyer clicks "I Have Sent Payment" button
- **System Action**:
  - Updates trade status to `payment_confirmed`
  - Records payment confirmation timestamp
  - Sets `buyer_confirmed = true`

### 4. **Payment Confirmed** (Status: `payment_confirmed`)
- **Seller sees**: "Release Coins to Buyer" button
- **Buyer sees**: Waiting message for seller to release coins
- Seller verifies payment received in their account

### 5. **Release Coins** (Seller)
- Seller confirms payment received
- Seller clicks "Release Coins to Buyer" button
- **System Action**:
  - Calls `release_coins_from_escrow()` database function
  - Transfers coins from escrow to buyer's balance
  - Updates trade status to `completed`
  - Records coins release timestamp
  - Creates transaction record

### 6. **Trade Completed** (Status: `completed`)
- Both parties can rate each other
- Coins are now in buyer's balance
- Trade is marked as complete in history

## Database Functions

### `move_coins_to_escrow()`
\`\`\`sql
- Deducts coins from seller's balance
- Locks coins in trade escrow
- Updates trade status to 'escrow'
\`\`\`

### `release_coins_from_escrow()`
\`\`\`sql
- Transfers coins from escrow to buyer
- Updates trade status to 'completed'
- Records transaction
- Updates both users' trade counts
\`\`\`

## Security Features

1. **Row Level Security (RLS)**: Only trade participants can view/update trades
2. **Escrow Protection**: Coins locked until both parties confirm
3. **Real-time Updates**: WebSocket subscriptions for instant status changes
4. **Rating System**: Builds trust through user ratings

## SQL Scripts to Run

Run these scripts in order in your Supabase SQL Editor:

1. `scripts/020_fix_listings_table.sql` - Fix listings schema
2. `scripts/021_add_escrow_to_trades.sql` - Add escrow functions

After running scripts, the P2P trading system will be fully functional with escrow protection.
