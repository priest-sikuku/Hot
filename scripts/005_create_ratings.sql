-- Create ratings/reviews table
create table if not exists public.ratings (
  id uuid primary key default gen_random_uuid(),
  trade_id uuid not null references public.trades(id) on delete cascade,
  rater_id uuid not null references auth.users(id) on delete cascade,
  rated_user_id uuid not null references auth.users(id) on delete cascade,
  rating integer not null check (rating >= 1 and rating <= 5),
  review text,
  created_at timestamp with time zone default now()
);

alter table public.ratings enable row level security;

create policy "ratings_select_all"
  on public.ratings for select
  using (true);

create policy "ratings_insert_own"
  on public.ratings for insert
  with check (auth.uid() = rater_id);

create policy "ratings_update_own"
  on public.ratings for update
  using (auth.uid() = rater_id);

create policy "ratings_delete_own"
  on public.ratings for delete
  using (auth.uid() = rater_id);
