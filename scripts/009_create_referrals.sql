-- Create referrals table for tracking referral relationships
create table if not exists public.referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_id uuid not null references auth.users(id) on delete cascade,
  referred_id uuid not null references auth.users(id) on delete cascade,
  referral_code text unique not null,
  status text default 'active', -- active, inactive
  total_trading_commission numeric default 0,
  total_claim_commission numeric default 0,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  unique(referrer_id, referred_id)
);

alter table public.referrals enable row level security;

create policy "referrals_select_own"
  on public.referrals for select
  using (auth.uid() = referrer_id or auth.uid() = referred_id);

create policy "referrals_insert_own"
  on public.referrals for insert
  with check (auth.uid() = referred_id);

create policy "referrals_update_own"
  on public.referrals for update
  using (auth.uid() = referrer_id);

-- Create referral commissions table
create table if not exists public.referral_commissions (
  id uuid primary key default gen_random_uuid(),
  referrer_id uuid not null references auth.users(id) on delete cascade,
  referred_id uuid not null references auth.users(id) on delete cascade,
  commission_type text not null, -- trading, claim
  amount numeric not null,
  source_id uuid, -- trade_id or coin_id
  status text default 'pending', -- pending, completed
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

alter table public.referral_commissions enable row level security;

create policy "referral_commissions_select_own"
  on public.referral_commissions for select
  using (auth.uid() = referrer_id or auth.uid() = referred_id);

create policy "referral_commissions_insert"
  on public.referral_commissions for insert
  with check (true);

create policy "referral_commissions_update_own"
  on public.referral_commissions for update
  using (auth.uid() = referrer_id);
