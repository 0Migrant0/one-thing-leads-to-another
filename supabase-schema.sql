create extension if not exists pgcrypto;

create table public.couples (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null check (username ~ '^[A-Za-z0-9_-]{3,24}$'),
  partner1_name text not null default 'الشريك الأول',
  partner2_name text not null default 'الشريك الثاني',
  play_mode text not null default 'in' check (play_mode in ('in', 'out')),
  created_at timestamptz not null default now()
);

create unique index couples_username_lower_unique
  on public.couples (lower(username));

create table public.shared_sessions (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete cascade,
  game_session_id text not null,
  completed boolean not null default false,
  share_token uuid not null unique default gen_random_uuid(),
  created_at timestamptz not null default now(),
  unique (couple_id, game_session_id),
  unique (id, couple_id)
);

create table public.shared_answers (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null,
  couple_id uuid not null references public.couples (id) on delete cascade,
  card_key text not null,
  partner_key text not null check (partner_key in ('p1', 'p2')),
  answer text not null,
  question text not null,
  mood_title text not null,
  session_title text not null,
  saved_at text not null,
  foreign key (session_id, couple_id)
    references public.shared_sessions (id, couple_id) on delete cascade,
  unique (session_id, card_key, partner_key)
);

create index shared_answers_couple_id_idx
  on public.shared_answers (couple_id);

alter table public.couples enable row level security;
alter table public.shared_sessions enable row level security;
alter table public.shared_answers enable row level security;

create policy "Couples can read their own account"
  on public.couples for select
  using (id = (select auth.uid()));

create policy "Couples can update their own account"
  on public.couples for update
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy "Couples can read their own sessions"
  on public.shared_sessions for select
  using (couple_id = (select auth.uid()));

create policy "Couples can create their own sessions"
  on public.shared_sessions for insert
  with check (couple_id = (select auth.uid()));

create policy "Couples can update their own sessions"
  on public.shared_sessions for update
  using (couple_id = (select auth.uid()))
  with check (couple_id = (select auth.uid()));

create policy "Couples can delete their own sessions"
  on public.shared_sessions for delete
  using (couple_id = (select auth.uid()));

create policy "Couples can read their own answers"
  on public.shared_answers for select
  using (couple_id = (select auth.uid()));

create policy "Couples can create their own answers"
  on public.shared_answers for insert
  with check (couple_id = (select auth.uid()));

create policy "Couples can update their own answers"
  on public.shared_answers for update
  using (couple_id = (select auth.uid()))
  with check (couple_id = (select auth.uid()));

create policy "Couples can delete their own answers"
  on public.shared_answers for delete
  using (couple_id = (select auth.uid()));

create function public.create_couple_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.couples (id, username, partner1_name, partner2_name)
  values (
    new.id,
    new.raw_user_meta_data ->> 'username',
    coalesce(nullif(new.raw_user_meta_data ->> 'partner1_name', ''), 'الشريك الأول'),
    coalesce(nullif(new.raw_user_meta_data ->> 'partner2_name', ''), 'الشريك الثاني')
  );
  return new;
end;
$$;

create trigger create_couple_profile_after_signup
  after insert on auth.users
  for each row execute function public.create_couple_for_new_user();
