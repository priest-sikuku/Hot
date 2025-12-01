-- Add escrow fields to trades table
alter table public.trades 
  add column if not exists escrow_amount numeric default 0,
  add column if not exists payment_confirmed_at timestamp with time zone,
  add column if not exists coins_released_at timestamp with time zone;

-- Update status enum to include more states
comment on column public.trades.status is 'pending, payment_pending, payment_confirmed, escrow, completed, cancelled';

-- Create function to move coins to escrow
create or replace function move_coins_to_escrow(
  p_trade_id uuid,
  p_seller_id uuid,
  p_amount numeric
) returns void as $$
begin
  -- Update trade with escrow amount
  update public.trades
  set escrow_amount = p_amount,
      status = 'escrow'
  where id = p_trade_id;
  
  -- Deduct from seller's balance (will be tracked in profiles)
  update public.profiles
  set balance = balance - p_amount
  where user_id = p_seller_id;
end;
$$ language plpgsql security definer;

-- Create function to release coins from escrow to buyer
create or replace function release_coins_from_escrow(
  p_trade_id uuid,
  p_buyer_id uuid,
  p_amount numeric
) returns void as $$
begin
  -- Update trade status
  update public.trades
  set status = 'completed',
      coins_released_at = now()
  where id = p_trade_id;
  
  -- Add to buyer's balance
  update public.profiles
  set balance = balance + p_amount
  where user_id = p_buyer_id;
  
  -- Record transaction
  insert into public.transactions (user_id, type, amount, description)
  values (p_buyer_id, 'trade_buy', p_amount, 'P2P trade completed');
end;
$$ language plpgsql security definer;
