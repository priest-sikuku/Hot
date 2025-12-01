-- Create p2p_trades table
create table if not exists public.p2p_trades (
  id uuid primary key default gen_random_uuid(),
  ad_id uuid references public.p2p_ads(id) on delete cascade,
  buyer_id uuid references public.profiles(id) on delete cascade,
  seller_id uuid references public.profiles(id) on delete cascade,
  gx_amount numeric not null,
  escrow_amount numeric default 0,
  status text default 'pending' check (status in ('pending', 'escrowed', 'payment_sent', 'completed', 'cancelled', 'disputed')),
  payment_confirmed_at timestamp with time zone,
  coins_released_at timestamp with time zone,
  expires_at timestamp with time zone default (now() + interval '30 minutes'),
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Enable RLS
alter table public.p2p_trades enable row level security;

-- RLS Policies
create policy "Users can view their own trades"
  on public.p2p_trades for select
  using (auth.uid() = buyer_id or auth.uid() = seller_id);

create policy "Users can insert trades"
  on public.p2p_trades for insert
  with check (auth.uid() = buyer_id or auth.uid() = seller_id);

create policy "Users can update their own trades"
  on public.p2p_trades for update
  using (auth.uid() = buyer_id or auth.uid() = seller_id);

-- Function to initiate trade and move coins to escrow
create or replace function initiate_p2p_trade(
  p_ad_id uuid,
  p_buyer_id uuid,
  p_seller_id uuid,
  p_gx_amount numeric
) returns uuid as $$
declare
  v_trade_id uuid;
  v_seller_balance numeric;
begin
  -- Check seller has enough balance
  select total_mined into v_seller_balance
  from public.profiles
  where id = p_seller_id;

  if v_seller_balance < p_gx_amount then
    raise exception 'Seller has insufficient balance';
  end if;

  -- Create trade
  insert into public.p2p_trades (ad_id, buyer_id, seller_id, gx_amount, escrow_amount, status)
  values (p_ad_id, p_buyer_id, p_seller_id, p_gx_amount, p_gx_amount, 'escrowed')
  returning id into v_trade_id;

  -- Move coins to escrow (deduct from seller)
  update public.profiles
  set total_mined = total_mined - p_gx_amount,
      updated_at = now()
  where id = p_seller_id;

  -- Record transaction
  insert into public.transactions (user_id, type, amount, description, related_id, status)
  values (p_seller_id, 'p2p_escrow', -p_gx_amount, 'Coins moved to escrow for P2P trade', v_trade_id, 'completed');

  return v_trade_id;
end;
$$ language plpgsql security definer;

-- Function to release coins from escrow to buyer
create or replace function release_p2p_coins(
  p_trade_id uuid,
  p_seller_id uuid
) returns void as $$
declare
  v_buyer_id uuid;
  v_escrow_amount numeric;
  v_trade_status text;
begin
  -- Get trade details
  select buyer_id, escrow_amount, status
  into v_buyer_id, v_escrow_amount, v_trade_status
  from public.p2p_trades
  where id = p_trade_id and seller_id = p_seller_id;

  if not found then
    raise exception 'Trade not found or you are not the seller';
  end if;

  if v_trade_status != 'escrowed' and v_trade_status != 'payment_sent' then
    raise exception 'Trade is not in a state to release coins';
  end if;

  -- Update trade status
  update public.p2p_trades
  set status = 'completed',
      coins_released_at = now(),
      updated_at = now()
  where id = p_trade_id;

  -- Transfer coins to buyer
  update public.profiles
  set total_mined = total_mined + v_escrow_amount,
      updated_at = now()
  where id = v_buyer_id;

  -- Record transaction for buyer
  insert into public.transactions (user_id, type, amount, description, related_id, status)
  values (v_buyer_id, 'p2p_buy', v_escrow_amount, 'Received GX from P2P trade', p_trade_id, 'completed');
end;
$$ language plpgsql security definer;

-- Function to mark payment as sent (buyer action)
create or replace function mark_payment_sent(
  p_trade_id uuid,
  p_buyer_id uuid
) returns void as $$
begin
  update public.p2p_trades
  set status = 'payment_sent',
      payment_confirmed_at = now(),
      updated_at = now()
  where id = p_trade_id and buyer_id = p_buyer_id;

  if not found then
    raise exception 'Trade not found or you are not the buyer';
  end if;
end;
$$ language plpgsql security definer;

-- Function to cancel trade and return coins to seller
create or replace function cancel_p2p_trade(
  p_trade_id uuid,
  p_user_id uuid
) returns void as $$
declare
  v_seller_id uuid;
  v_escrow_amount numeric;
  v_status text;
begin
  -- Get trade details
  select seller_id, escrow_amount, status
  into v_seller_id, v_escrow_amount, v_status
  from public.p2p_trades
  where id = p_trade_id and (buyer_id = p_user_id or seller_id = p_user_id);

  if not found then
    raise exception 'Trade not found';
  end if;

  if v_status = 'completed' then
    raise exception 'Cannot cancel completed trade';
  end if;

  -- Update trade status
  update public.p2p_trades
  set status = 'cancelled',
      updated_at = now()
  where id = p_trade_id;

  -- Return coins to seller if they were in escrow
  if v_escrow_amount > 0 then
    update public.profiles
    set total_mined = total_mined + v_escrow_amount,
        updated_at = now()
    where id = v_seller_id;

    -- Record transaction
    insert into public.transactions (user_id, type, amount, description, related_id, status)
    values (v_seller_id, 'p2p_refund', v_escrow_amount, 'Coins returned from cancelled P2P trade', p_trade_id, 'completed');
  end if;
end;
$$ language plpgsql security definer;

-- Create indexes for performance
create index if not exists idx_p2p_trades_buyer on public.p2p_trades(buyer_id);
create index if not exists idx_p2p_trades_seller on public.p2p_trades(seller_id);
create index if not exists idx_p2p_trades_status on public.p2p_trades(status);
create index if not exists idx_p2p_trades_expires on public.p2p_trades(expires_at);
