-- Add seller_id and buyer_id to profiles table
-- These will be identical to the user's id for all users

-- Add seller_id and buyer_id columns that default to the user's id
alter table public.profiles
add column if not exists seller_id uuid,
add column if not exists buyer_id uuid;

-- Set existing users' seller_id and buyer_id to their id
update public.profiles
set seller_id = id, buyer_id = id
where seller_id is null or buyer_id is null;

-- Make seller_id and buyer_id not null and default to id
alter table public.profiles
alter column seller_id set default gen_random_uuid(),
alter column buyer_id set default gen_random_uuid(),
alter column seller_id set not null,
alter column buyer_id set not null;

-- Update the trigger to set seller_id and buyer_id on user creation
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, username, seller_id, buyer_id)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1)),
    new.id,  -- seller_id = user id
    new.id   -- buyer_id = user id
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

-- Add indexes for better query performance
create index if not exists idx_profiles_seller_id on public.profiles(seller_id);
create index if not exists idx_profiles_buyer_id on public.profiles(buyer_id);
