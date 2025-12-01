-- Create trades table for P2P transactions
create table if not exists public.trades (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  buyer_id uuid not null references auth.users(id) on delete cascade,
  seller_id uuid not null references auth.users(id) on delete cascade,
  coin_amount numeric not null,
  total_price numeric not null,
  payment_method text not null,
  status text default 'pending', -- pending, escrow, completed, cancelled
  buyer_confirmed boolean default false,
  seller_confirmed boolean default false,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

alter table public.trades enable row level security;

create policy "trades_select_own"
  on public.trades for select
  using (auth.uid() = buyer_id or auth.uid() = seller_id);

create policy "trades_insert_buyer"
  on public.trades for insert
  with check (auth.uid() = buyer_id);

create policy "trades_update_own"
  on public.trades for update
  using (auth.uid() = buyer_id or auth.uid() = seller_id);

create policy "trades_delete_own"
  on public.trades for delete
  using (auth.uid() = buyer_id or auth.uid() = seller_id);
