-- Add max supply tracking to coins table
alter table public.coins add column if not exists max_supply numeric default 500000;

-- Create view for total coins in circulation
create or replace view public.total_coins_in_circulation as
select 
  coalesce(sum(amount), 0) as total_coins,
  (select max_supply from public.coins limit 1) as max_supply
from public.coins
where status = 'active';
