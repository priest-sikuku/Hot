-- Drop the old listings table and recreate with correct structure
drop table if exists public.listings cascade;

-- Create listings table with proper structure for both buy and sell ads
create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  listing_type text not null check (listing_type in ('buy', 'sell')),
  coin_amount numeric not null check (coin_amount > 0),
  price_per_coin numeric not null check (price_per_coin > 0),
  currency text default 'KES',
  payment_methods text[] not null default array[]::text[],
  payment_account text, -- Only required for sell ads
  terms text, -- Optional terms of trade
  status text default 'active' check (status in ('active', 'completed', 'cancelled')),
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Create indexes for better performance
create index idx_listings_user_id on public.listings(user_id);
create index idx_listings_type on public.listings(listing_type);
create index idx_listings_status on public.listings(status);
create index idx_listings_created_at on public.listings(created_at desc);

-- Enable RLS
alter table public.listings enable row level security;

-- RLS Policies
create policy "listings_select_all"
  on public.listings for select
  using (status = 'active' or auth.uid() = user_id);

create policy "listings_insert_own"
  on public.listings for insert
  with check (auth.uid() = user_id);

create policy "listings_update_own"
  on public.listings for update
  using (auth.uid() = user_id);

create policy "listings_delete_own"
  on public.listings for delete
  using (auth.uid() = user_id);

-- Add trigger to update updated_at
create or replace function update_listings_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger listings_updated_at
  before update on public.listings
  for each row
  execute function update_listings_updated_at();
