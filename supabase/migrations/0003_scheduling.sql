-- =====================================================================
-- Scheduled jobs
--
-- Requires the `pg_cron` and `pg_net` extensions, both available on
-- Supabase. Run this migration *after* deploying the edge functions, since
-- the schedule starts firing as soon as it is created.
--
-- Set the two settings below before applying, e.g. from the SQL editor:
--   alter database postgres set app.settings.project_url = 'https://xxx.supabase.co';
--   alter database postgres set app.settings.cron_secret = '<random string>';
-- =====================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- ---------------------------------------------------------------------
-- Hourly training reminders
--
-- The function itself decides who is due, so this only has to fire once an
-- hour rather than knowing anything about time zones.
-- ---------------------------------------------------------------------
select cron.unschedule('vitalrise-send-reminders')
where exists (
  select 1 from cron.job where jobname = 'vitalrise-send-reminders'
);

select cron.schedule(
  'vitalrise-send-reminders',
  '5 * * * *',
  $$
  select net.http_post(
    url := current_setting('app.settings.project_url') || '/functions/v1/send-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', current_setting('app.settings.cron_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
  $$
);

-- ---------------------------------------------------------------------
-- Coach telemetry retention
--
-- These rows carry no message text, but there is still no reason to keep
-- them forever. Ninety days is enough to spot a regression in safety
-- triage and short enough to be defensible in a privacy review.
-- ---------------------------------------------------------------------
select cron.unschedule('vitalrise-prune-coach-events')
where exists (
  select 1 from cron.job where jobname = 'vitalrise-prune-coach-events'
);

select cron.schedule(
  'vitalrise-prune-coach-events',
  '30 3 * * *',
  $$
  delete from public.coach_events
  where created_at < now() - interval '90 days';
  $$
);

-- ---------------------------------------------------------------------
-- Safety monitoring view
--
-- Aggregate only: counts per verdict per day, so an on-call engineer can
-- see that triage is firing without ever reading a user's question.
-- ---------------------------------------------------------------------
create or replace view public.coach_safety_daily
with (security_invoker = true)
as
select
  date_trunc('day', created_at)::date as day,
  verdict,
  answered_by,
  count(*)                            as events,
  percentile_cont(0.95) within group (order by latency_ms) as p95_latency_ms
from public.coach_events
group by 1, 2, 3;

comment on view public.coach_safety_daily is
  'Aggregated coach outcomes for operational monitoring. Contains no user
   identifiers and no message content.';

revoke all on public.coach_safety_daily from anon, authenticated;
