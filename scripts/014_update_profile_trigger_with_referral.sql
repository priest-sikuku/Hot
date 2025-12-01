-- Update trigger to auto-generate referral code on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  username_value text;
  referral_code_value text;
begin
  -- Get username from metadata or email
  username_value := coalesce(
    new.raw_user_meta_data ->> 'username',
    split_part(new.email, '@', 1)
  );
  
  -- Generate referral code
  referral_code_value := coalesce(
    new.raw_user_meta_data ->> 'referral_code',
    'GX_' || upper(username_value) || '_' || upper(substring(md5(random()::text) from 1 for 6))
  );
  
  -- Insert profile with referral code
  insert into public.profiles (
    id,
    email,
    username,
    referral_code,
    rating,
    total_trades,
    total_referrals,
    total_commission
  )
  values (
    new.id,
    new.email,
    username_value,
    referral_code_value,
    0.00,
    0,
    0,
    0.00
  )
  on conflict (id) do update
  set
    referral_code = coalesce(profiles.referral_code, referral_code_value),
    rating = coalesce(profiles.rating, 0.00),
    total_trades = coalesce(profiles.total_trades, 0),
    total_referrals = coalesce(profiles.total_referrals, 0),
    total_commission = coalesce(profiles.total_commission, 0.00);

  return new;
end;
$$;

-- Recreate trigger
drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();
