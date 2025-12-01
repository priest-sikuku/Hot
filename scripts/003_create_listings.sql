-- Create P2P listings table
create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references auth.users(id) on delete cascade,
  coin_amount numeric not null,
  price_per_coin numeric not null,
  currency text default 'KES',
  payment_methods text[] default array['M-Pesa', 'Bank Transfer'],
  status text default 'active', -- active, sold, cancelled
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

alter table public.listings enable row level security;

create policy "listings_select_all"
  on public.listings for select
  using (status = 'active' or auth.uid() = seller_id);

create policy "listings_insert_own"
  on public.listings for insert
  with check (auth.uid() = seller_id);

create policy "listings_update_own"
  on public.listings for update
  using (auth.uid() = seller_id);

create policy "listings_delete_own"
  on public.listings for delete
  using (auth.uid() = seller_id);
