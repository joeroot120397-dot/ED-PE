-- =====================================================================
-- Row level security
--
-- This file is the security boundary for the entire product. The client
-- holds a *public* key, so the only thing standing between one user's
-- assessment answers and another user is these policies.
--
-- Rules followed throughout:
--  * RLS is enabled on every table holding user data, with no exceptions
--    and no "temporarily disabled" states.
--  * Every policy is written against `(select auth.uid())` rather than
--    `auth.uid()`. The subquery form is evaluated once per statement
--    instead of once per row, which is the difference between a fast index
--    scan and a per-row function call on a large table.
--  * WITH CHECK is specified on every insert and update policy, so a user
--    cannot write a row belonging to somebody else even though they can
--    only read their own.
--  * No policy grants access to `anon`. Unauthenticated clients can read
--    published content and nothing else.
-- =====================================================================

alter table public.profiles         enable row level security;
alter table public.assessments      enable row level security;
alter table public.habit_logs       enable row level security;
alter table public.progress_entries enable row level security;
alter table public.coach_events     enable row level security;
alter table public.content_items    enable row level security;

-- Belt and braces: revoke the blanket grants Supabase issues by default so
-- that a missing policy fails closed rather than open.
revoke all on public.profiles         from anon, authenticated;
revoke all on public.assessments      from anon, authenticated;
revoke all on public.habit_logs       from anon, authenticated;
revoke all on public.progress_entries from anon, authenticated;
revoke all on public.coach_events     from anon, authenticated;
revoke all on public.content_items    from anon, authenticated;

grant select, insert, update on public.profiles         to authenticated;
grant select, insert, delete on public.assessments      to authenticated;
grant select, insert, update, delete on public.habit_logs       to authenticated;
grant select, insert, update, delete on public.progress_entries to authenticated;
grant insert on public.coach_events to authenticated;
grant select on public.content_items to anon, authenticated;

-- ---------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check (id = (select auth.uid()));

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Deliberately no delete policy: account deletion goes through
-- `delete_my_data()` and Supabase auth, not a direct row delete.

-- ---------------------------------------------------------------------
-- Assessments
-- ---------------------------------------------------------------------
drop policy if exists assessments_select_own on public.assessments;
create policy assessments_select_own on public.assessments
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists assessments_insert_own on public.assessments;
create policy assessments_insert_own on public.assessments
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists assessments_delete_own on public.assessments;
create policy assessments_delete_own on public.assessments
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- No update policy. Assessments are an append-only history; editing a past
-- result would silently rewrite the baseline every trend is measured from.

-- ---------------------------------------------------------------------
-- Habit logs
-- ---------------------------------------------------------------------
drop policy if exists habit_logs_select_own on public.habit_logs;
create policy habit_logs_select_own on public.habit_logs
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists habit_logs_insert_own on public.habit_logs;
create policy habit_logs_insert_own on public.habit_logs
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists habit_logs_update_own on public.habit_logs;
create policy habit_logs_update_own on public.habit_logs
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists habit_logs_delete_own on public.habit_logs;
create policy habit_logs_delete_own on public.habit_logs
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- Progress entries
-- ---------------------------------------------------------------------
drop policy if exists progress_select_own on public.progress_entries;
create policy progress_select_own on public.progress_entries
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists progress_insert_own on public.progress_entries;
create policy progress_insert_own on public.progress_entries
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists progress_update_own on public.progress_entries;
create policy progress_update_own on public.progress_entries
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists progress_delete_own on public.progress_entries;
create policy progress_delete_own on public.progress_entries
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- Coach events
--
-- Insert-only from the client. Nobody can read this table through the API
-- at all - not even their own rows - because there is no product feature
-- that needs it and every read path is a potential leak.
-- ---------------------------------------------------------------------
drop policy if exists coach_events_insert_own on public.coach_events;
create policy coach_events_insert_own on public.coach_events
  for insert to authenticated
  with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- Content
-- ---------------------------------------------------------------------
drop policy if exists content_public_read on public.content_items;
create policy content_public_read on public.content_items
  for select to anon, authenticated
  using (published);

-- ---------------------------------------------------------------------
-- Account deletion
--
-- Runs as a single transaction under `security definer` so a dropped
-- connection cannot leave a user half-deleted. It only ever touches the
-- caller's rows: `auth.uid()` is read inside the function, so there is no
-- parameter an attacker could point at somebody else.
-- ---------------------------------------------------------------------
create or replace function public.delete_my_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := auth.uid();
begin
  if caller is null then
    raise exception 'delete_my_data() requires an authenticated caller';
  end if;

  delete from public.habit_logs       where user_id = caller;
  delete from public.progress_entries where user_id = caller;
  delete from public.assessments      where user_id = caller;
  update public.coach_events set user_id = null where user_id = caller;
  delete from public.profiles         where id = caller;
end;
$$;

revoke all on function public.delete_my_data() from public, anon;
grant execute on function public.delete_my_data() to authenticated;

comment on function public.delete_my_data is
  'Erases every health record belonging to the caller. Coach events are
   anonymised rather than deleted so aggregate safety monitoring survives,
   but they never contained message text in the first place.';
