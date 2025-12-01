-- Create view for user statistics
create or replace view public.user_stats as
select
  p.id,
  p.email,
  p.username,
  coalesce(sum(case when c.status = 'active' then c.amount else 0 end), 0) as total_coins,
  coalesce(sum(case when c.status = 'locked' then c.amount else 0 end), 0) as locked_coins,
  coalesce(avg(r.rating), 0) as average_rating,
  coalesce(count(distinct r.id), 0) as total_ratings,
  coalesce(count(distinct t.id), 0) as total_trades
from public.profiles p
left join public.coins c on p.id = c.user_id
left join public.ratings r on p.id = r.rated_user_id
left join public.trades t on p.id = t.buyer_id or p.id = t.seller_id
group by p.id, p.email, p.username;
