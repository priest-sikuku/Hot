-- Add listing_type column to differentiate buy and sell orders
alter table public.listings add column if not exists listing_type text default 'sell'; -- 'buy' or 'sell'

-- Add user_id column for buy orders (since buyer_id is more appropriate for buy orders)
alter table public.listings rename column seller_id to user_id;

-- Update the RLS policies to use user_id instead of seller_id
drop policy if exists "listings_select_all" on public.listings;
drop policy if exists "listings_insert_own" on public.listings;
drop policy if exists "listings_update_own" on public.listings;
drop policy if exists "listings_delete_own" on public.listings;

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
