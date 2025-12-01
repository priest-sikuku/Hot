-- Add listing_type, terms, and payment_account fields to listings table
alter table public.listings 
  add column if not exists listing_type text default 'sell', -- 'buy' or 'sell'
  add column if not exists terms text, -- Terms of trade
  add column if not exists payment_account text; -- M-Pesa number or bank account

-- Rename seller_id to user_id for consistency
alter table public.listings rename column seller_id to user_id;

-- Update RLS policies to use user_id instead of seller_id
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

-- Add index for better query performance
create index if not exists idx_listings_type_status on public.listings(listing_type, status);
create index if not exists idx_listings_user_id on public.listings(user_id);
