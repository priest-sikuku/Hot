-- Add mining-related fields to profiles table
alter table public.profiles
add column if not exists last_mine timestamp with time zone,
add column if not exists next_mine timestamp with time zone;

-- Create index for faster queries
create index if not exists idx_profiles_next_mine on public.profiles(next_mine);

-- Update existing users to allow immediate mining
update public.profiles
set next_mine = now()
where next_mine is null;
