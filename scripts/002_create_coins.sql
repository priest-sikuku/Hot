-- Create coins/claims table for tracking claimed coins
create table if not exists public.coins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount numeric not null,
  claim_type text not null default 'mining', -- mining, trading, bonus
  locked_until timestamp with time zone,
  lock_period_days integer default 7,
  bonus_percentage numeric default 0,
  status text default 'active', -- active, locked, claimed
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

alter table public.coins enable row level security;

create policy "coins_select_own"
  on public.coins for select
  using (auth.uid() = user_id);

create policy "coins_insert_own"
  on public.coins for insert
  with check (auth.uid() = user_id);

create policy "coins_update_own"
  on public.coins for update
  using (auth.uid() = user_id);

create policy "coins_delete_own"
  on public.coins for delete
  using (auth.uid() = user_id);
