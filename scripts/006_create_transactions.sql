-- Create transactions table for tracking all activities
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null, -- mining, claim, buy, sell, bonus
  amount numeric not null,
  description text,
  related_id uuid, -- reference to trade_id, listing_id, etc
  status text default 'completed', -- pending, completed, failed
  created_at timestamp with time zone default now()
);

alter table public.transactions enable row level security;

create policy "transactions_select_own"
  on public.transactions for select
  using (auth.uid() = user_id);

create policy "transactions_insert_own"
  on public.transactions for insert
  with check (auth.uid() = user_id);
