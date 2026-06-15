-- Daily meal balance game votes
-- One immutable vote per user per KST game date.

create table if not exists public.balance_game_votes (
  game_date date not null,
  user_id uuid not null references public.users(id) on delete cascade,
  choice text not null check (choice in ('a', 'b')),
  created_at timestamptz not null default now(),
  primary key (game_date, user_id)
);

create index if not exists balance_game_votes_game_date_idx
on public.balance_game_votes(game_date);

alter table public.balance_game_votes enable row level security;

drop policy if exists "Balance game votes are readable" on public.balance_game_votes;
drop policy if exists "Users can create their own balance game vote" on public.balance_game_votes;

create policy "Balance game votes are readable"
on public.balance_game_votes
for select
to authenticated
using (true);

create policy "Users can create their own balance game vote"
on public.balance_game_votes
for insert
to authenticated
with check (auth.uid() = user_id);