create extension if not exists pgcrypto;

-- 사용자
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  nickname text,
  age int,
  gender text check (gender in ('남', '여')),
  tags text[] default '{}',
  avatar_url text,
  university text,
  department text,
  student_id text,
  school_email text,
  student_verified boolean not null default false,
  student_verified_at timestamptz,
  manner_score numeric default 36.5,
  created_at timestamp default now(),
  updated_at timestamp default now()
);

-- 기존 users 테이블이 이미 있을 때 누락 컬럼 보강
alter table public.users add column if not exists nickname text;
alter table public.users add column if not exists gender text;
alter table public.users add column if not exists avatar_url text;
alter table public.users add column if not exists university text;
alter table public.users add column if not exists department text;
alter table public.users add column if not exists student_id text;
alter table public.users add column if not exists school_email text;
alter table public.users add column if not exists student_verified boolean not null default false;
alter table public.users add column if not exists student_verified_at timestamptz;
alter table public.users add column if not exists manner_score numeric default 36.5;
alter table public.users add column if not exists updated_at timestamp default now();

-- 학교 이메일 인증 코드 저장소
create table if not exists public.student_email_verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  email text not null,
  code_hash text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

-- 식당/혼밥 추천
create table if not exists public.restaurants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text,
  address text,
  latitude double precision,
  longitude double precision,
  image_url text,
  tags text[] default '{}',
  description text,
  is_solo_friendly boolean default false,
  created_at timestamp default now()
);

-- 모임
create table if not exists public.meetings (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  type text check (type in ('restaurant', 'delivery')),
  category text,
  tags text[] default '{}',
  max_members int not null default 2,
  current_members int default 1,
  location text,
  address text,
  latitude double precision,
  longitude double precision,
  image_url text,
  restaurant_id uuid references public.restaurants(id) on delete set null,
  has_dutch_pay boolean default false,
  delivery_app text,
  min_order_amount int,
  delivery_fee int,
  split_location text,
  host_id uuid references public.users(id) on delete set null,
  host_name text,
  scheduled_at timestamp,
  created_at timestamp default now(),
  updated_at timestamp default now()
);

-- 모임 멤버
create table if not exists public.meeting_members (
  meeting_id uuid references public.meetings(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  role text default 'member' check (role in ('host', 'member')),
  joined_at timestamp default now(),
  primary key (meeting_id, user_id)
);

-- 채팅 메시지
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid references public.meetings(id) on delete cascade,
  sender_id uuid references public.users(id) on delete cascade,
  sender_name text,
  text text not null,
  type text default 'text',
  created_at timestamp default now()
);

-- 다시 안 만나기
create table if not exists public.blocked_matches (
  blocker_id uuid references public.users(id) on delete cascade,
  blocked_user_id uuid references public.users(id) on delete cascade,
  created_at timestamp default now(),
  primary key (blocker_id, blocked_user_id),
  constraint blocked_matches_not_self check (blocker_id <> blocked_user_id)
);

-- 저장한 모임
create table if not exists public.saved_meetings (
  user_id uuid references public.users(id) on delete cascade,
  meeting_id uuid references public.meetings(id) on delete cascade,
  created_at timestamp default now(),
  primary key (user_id, meeting_id)
);

-- 저장한 식당
create table if not exists public.saved_restaurants (
  user_id uuid references public.users(id) on delete cascade,
  restaurant_id uuid references public.restaurants(id) on delete cascade,
  created_at timestamp default now(),
  primary key (user_id, restaurant_id)
);

-- 정산 요청
create table if not exists public.settlements (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid references public.meetings(id) on delete cascade,
  requester_id uuid references public.users(id) on delete set null,
  total_amount int not null default 0,
  per_person_amount int not null default 0,
  bank_info text,
  memo text,
  status text default 'requested'
    check (status in ('requested', 'completed', 'cancelled')),
  created_at timestamp default now(),
  completed_at timestamp
);

-- 정산 멤버별 상태
create table if not exists public.settlement_members (
  settlement_id uuid references public.settlements(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  user_name text,
  amount int not null default 0,
  status text default 'requested'
    check (status in ('requested', 'paid', 'confirmed')),
  paid_at timestamp,
  confirmed_at timestamp,
  primary key (settlement_id, user_id)
);

-- 모임 평가
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid references public.meetings(id) on delete cascade,
  reviewer_id uuid references public.users(id) on delete cascade,
  reviewee_id uuid references public.users(id) on delete cascade,
  rating int check (rating between 1 and 5),
  comment text,
  created_at timestamp default now(),
  unique (meeting_id, reviewer_id, reviewee_id),
  constraint reviews_not_self check (reviewer_id <> reviewee_id)
);

-- 신뢰점수 리뷰
create table if not exists public.trust_reviews (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  reviewer_id uuid not null references public.users(id) on delete cascade,
  reviewed_user_id uuid not null references public.users(id) on delete cascade,
  score numeric(2,1) not null check (score >= 0 and score <= 5),
  comment text,
  created_at timestamptz not null default now(),
  unique (meeting_id, reviewer_id, reviewed_user_id),
  constraint trust_reviews_not_self check (reviewer_id <> reviewed_user_id)
);

-- 식사 기록
create table if not exists public.meal_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  meeting_id uuid references public.meetings(id) on delete set null,
  restaurant_id uuid references public.restaurants(id) on delete set null,
  title text,
  category text,
  location text,
  eaten_at timestamp default now(),
  created_at timestamp default now()
);

-- 알림 저장
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  title text not null,
  body text,
  type text,
  meeting_id uuid references public.meetings(id) on delete cascade,
  is_read boolean default false,
  created_at timestamp default now()
);

-- 인덱스
create index if not exists users_school_email_idx
on public.users (school_email);

create index if not exists student_email_verifications_lookup_idx
on public.student_email_verifications (user_id, email, created_at desc);

create index if not exists meetings_type_idx on public.meetings(type);
create index if not exists meetings_category_idx on public.meetings(category);
create index if not exists meetings_scheduled_at_idx on public.meetings(scheduled_at);
create index if not exists meetings_host_id_idx on public.meetings(host_id);
create index if not exists meeting_members_user_id_idx on public.meeting_members(user_id);
create index if not exists messages_meeting_id_created_at_idx on public.messages(meeting_id, created_at);
create index if not exists blocked_matches_blocker_id_idx on public.blocked_matches(blocker_id);
create index if not exists blocked_matches_blocked_user_id_idx on public.blocked_matches(blocked_user_id);
create index if not exists settlements_meeting_id_idx on public.settlements(meeting_id);
create index if not exists reviews_meeting_id_idx on public.reviews(meeting_id);
create index if not exists meal_history_user_id_idx on public.meal_history(user_id);
create index if not exists notifications_user_id_idx on public.notifications(user_id);
create index if not exists trust_reviews_reviewed_user_id_idx
on public.trust_reviews(reviewed_user_id);

-- 실시간 활성화
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
    and schemaname = 'public'
    and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
    and schemaname = 'public'
    and tablename = 'meeting_members'
  ) then
    alter publication supabase_realtime add table public.meeting_members;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
    and schemaname = 'public'
    and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

-- 프로토타입용 RLS 비활성화
alter table public.users disable row level security;
alter table public.restaurants disable row level security;
alter table public.meetings disable row level security;
alter table public.meeting_members disable row level security;
alter table public.messages disable row level security;
alter table public.blocked_matches disable row level security;
alter table public.saved_meetings disable row level security;
alter table public.saved_restaurants disable row level security;
alter table public.settlements disable row level security;
alter table public.settlement_members disable row level security;
alter table public.reviews disable row level security;
alter table public.meal_history disable row level security;
alter table public.notifications disable row level security;
alter table public.trust_reviews disable row level security;

-- 인증 코드는 앱에서 직접 조회하지 못하게 RLS 유지
alter table public.student_email_verifications enable row level security;
