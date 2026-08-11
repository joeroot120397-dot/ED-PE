-- =====================================================================
-- VitalRise core schema
--
-- Design notes that matter at scale:
--  * Health data is stored per-user with the user id as the leading column
--    of every primary key and index, so every query is a single-user range
--    scan no matter how large the table grows.
--  * Daily and weekly records use natural composite keys
--    (user_id, day) / (user_id, week_start) rather than surrogate ids, so
--    the client can upsert idempotently and a retried write can never
--    create a duplicate row.
--  * Answers and scores are JSONB rather than 30 columns. The question bank
--    is versioned content that changes without a migration; the shape is
--    enforced in the app, and `content_version` records which bank produced
--    a given row.
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  display_name    text,
  locale          text        not null default 'en',
  push_token      text,
  reminder_hour   smallint    check (reminder_hour between 0 and 23),
  reminders_on    boolean     not null default false,
  analytics_opt_in boolean    not null default true,
  onboarding_done boolean     not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.profiles is
  'One row per authenticated user. Deliberately holds no health data - only
   account preferences - so it can be read for routine operations without
   touching anything sensitive.';

-- ---------------------------------------------------------------------
-- Assessments
-- ---------------------------------------------------------------------
create table if not exists public.assessments (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid        not null references auth.users (id) on delete cascade,
  responses       jsonb       not null,
  result          jsonb       not null,
  content_version text        not null default 'v1',
  completed_at    timestamptz not null default now()
);

comment on column public.assessments.responses is
  'Question id -> answer. Append-only history: retaking the assessment
   inserts a new row rather than updating, so progress over time is visible.';

create index if not exists assessments_user_completed_idx
  on public.assessments (user_id, completed_at desc);

-- ---------------------------------------------------------------------
-- Daily habit logs
-- ---------------------------------------------------------------------
create table if not exists public.habit_logs (
  user_id          uuid        not null references auth.users (id) on delete cascade,
  day              date        not null,
  kegel_sessions   smallint    not null default 0 check (kegel_sessions between 0 and 50),
  water_ml         integer     not null default 0 check (water_ml between 0 and 20000),
  sleep_hours      numeric(4, 2) check (sleep_hours between 0 and 24),
  exercise_minutes smallint    not null default 0 check (exercise_minutes between 0 and 1440),
  weight_kg        numeric(5, 2) check (weight_kg between 20 and 400),
  waist_cm         numeric(5, 2) check (waist_cm between 30 and 250),
  note             text        check (char_length(note) <= 2000),
  updated_at       timestamptz not null default now(),
  primary key (user_id, day)
);

comment on table public.habit_logs is
  'The check constraints are not paranoia: a slider bug or a unit mix-up
   that writes 8000 kg would silently poison the progress charts forever.';

-- The dashboard only ever reads the recent past, so the index is ordered to
-- make "last N days for this user" the cheapest possible query.
create index if not exists habit_logs_user_day_idx
  on public.habit_logs (user_id, day desc);

-- ---------------------------------------------------------------------
-- Weekly progress check-ins
-- ---------------------------------------------------------------------
create table if not exists public.progress_entries (
  user_id    uuid          not null references auth.users (id) on delete cascade,
  week_start date          not null,
  ratings    jsonb         not null default '{}'::jsonb,
  weight_kg  numeric(5, 2) check (weight_kg between 20 and 400),
  waist_cm   numeric(5, 2) check (waist_cm between 30 and 250),
  note       text          check (char_length(note) <= 2000),
  updated_at timestamptz   not null default now(),
  primary key (user_id, week_start),
  -- week_start is always a Monday; enforcing it here keeps the weekly
  -- series aligned even if a client miscalculates the boundary.
  constraint progress_week_start_is_monday
    check (extract(isodow from week_start) = 1)
);

create index if not exists progress_entries_user_week_idx
  on public.progress_entries (user_id, week_start desc);

-- ---------------------------------------------------------------------
-- Coach usage
--
-- Records that a message was handled and how it was classified - never the
-- message itself. This is what lets us monitor whether safety triage is
-- firing correctly without building a database of men's sexual health
-- questions, which is exactly the database we do not want to exist.
-- ---------------------------------------------------------------------
create table if not exists public.coach_events (
  id          bigserial primary key,
  user_id     uuid        references auth.users (id) on delete set null,
  verdict     text        not null check (verdict in ('allow', 'refer', 'refuse', 'emergency')),
  reason      text,
  answered_by text        not null check (answered_by in ('model', 'offline', 'blocked')),
  latency_ms  integer,
  created_at  timestamptz not null default now()
);

create index if not exists coach_events_created_idx
  on public.coach_events (created_at desc);

-- ---------------------------------------------------------------------
-- Server-published content
--
-- The app ships with the full exercise, article and food databases bundled,
-- so it works offline and on first launch. These tables let us publish copy
-- corrections and new content without an app store release: the client
-- fetches anything with a content_version newer than the one it was built
-- with and overlays it.
-- ---------------------------------------------------------------------
create table if not exists public.content_items (
  id           text        primary key,
  kind         text        not null check (kind in ('exercise', 'article', 'food', 'anatomy')),
  payload      jsonb       not null,
  version      integer     not null default 1,
  published    boolean     not null default false,
  updated_at   timestamptz not null default now()
);

create index if not exists content_items_kind_idx
  on public.content_items (kind, published) where published;

-- ---------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

drop trigger if exists habit_logs_touch on public.habit_logs;
create trigger habit_logs_touch before update on public.habit_logs
  for each row execute function public.touch_updated_at();

drop trigger if exists progress_entries_touch on public.progress_entries;
create trigger progress_entries_touch before update on public.progress_entries
  for each row execute function public.touch_updated_at();

drop trigger if exists content_items_touch on public.content_items;
create trigger content_items_touch before update on public.content_items
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------
-- Profile bootstrap
--
-- Creating the profile row from a trigger rather than from the client means
-- it always exists by the time the app makes its first query, and cannot be
-- skipped by a client that crashes mid-signup.
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
