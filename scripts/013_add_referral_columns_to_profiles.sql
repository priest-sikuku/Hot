-- Add referral system columns to profiles table
alter table public.profiles
add column if not exists referral_code text unique,
add column if not exists referred_by uuid references public.profiles(id),
add column if not exists total_referrals integer default 0,
add column if not exists total_commission numeric(10, 2) default 0.00,
add column if not exists rating numeric(3, 2) default 0.00,
add column if not exists total_trades integer default 0;

-- Create index for faster referral code lookups
create index if not exists idx_profiles_referral_code on public.profiles(referral_code);

-- Update RLS policies to allow reading referral codes
create policy "profiles_select_referral_code"
  on public.profiles for select
  using (true);

comment on column public.profiles.referral_code is 'Unique referral code for the user';
comment on column public.profiles.referred_by is 'User ID of the referrer';
comment on column public.profiles.total_referrals is 'Total number of users referred';
comment on column public.profiles.total_commission is 'Total commission earned from referrals';
comment on column public.profiles.rating is 'User rating from 0.00 to 5.00';
comment on column public.profiles.total_trades is 'Total number of completed trades';
