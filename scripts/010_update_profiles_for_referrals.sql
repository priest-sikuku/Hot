-- Update profiles table to add referral fields
alter table public.profiles add column if not exists referral_code text unique;
alter table public.profiles add column if not exists referred_by uuid references auth.users(id) on delete set null;
alter table public.profiles add column if not exists total_referrals integer default 0;
alter table public.profiles add column if not exists total_commission numeric default 0;
alter table public.profiles add column if not exists max_supply_limit numeric default 500000;

-- Create index for referral code lookup
create index if not exists idx_profiles_referral_code on public.profiles(referral_code);
