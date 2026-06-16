-- AI solo meal recommendation logs

create table if not exists public.ai_recommendation_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  user_message text not null,
  recommended_place_id text,
  recommended_menu text,
  reason text,
  response_json jsonb,
  created_at timestamptz not null default now()
);

create index if not exists ai_recommendation_logs_user_id_idx
on public.ai_recommendation_logs(user_id, created_at desc);

alter table public.ai_recommendation_logs enable row level security;

drop policy if exists "Users can read their own AI recommendation logs" on public.ai_recommendation_logs;
drop policy if exists "Users can create their own AI recommendation logs" on public.ai_recommendation_logs;

create policy "Users can read their own AI recommendation logs"
on public.ai_recommendation_logs
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can create their own AI recommendation logs"
on public.ai_recommendation_logs
for insert
to authenticated
with check (auth.uid() = user_id);