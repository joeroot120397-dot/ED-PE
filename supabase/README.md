# VitalRise backend

Supabase project: Postgres for user data, Auth for sign-in, and two Edge
Functions. The app works fully offline without any of this — the backend
exists to sync across devices, run the AI coach, and send reminders.

## Layout

```
supabase/
├── migrations/
│   ├── 0001_schema.sql       tables, indexes, triggers
│   ├── 0002_rls.sql          row level security + delete_my_data()
│   └── 0003_scheduling.sql   pg_cron jobs and the monitoring view
└── functions/
    ├── ai-coach/             grounded coach answers (holds the model key)
    └── send-reminders/       hourly push, skips people who already trained
```

## First-time setup

```bash
supabase link --project-ref <ref>
supabase db push                      # applies migrations in order

supabase secrets set \
  ANTHROPIC_API_KEY=sk-ant-... \
  COACH_MODEL=claude-sonnet-5 \
  FCM_SERVER_KEY=... \
  CRON_SECRET="$(openssl rand -hex 32)"

supabase functions deploy ai-coach
supabase functions deploy send-reminders

# Only after the functions are live - the schedule fires immediately.
psql "$DATABASE_URL" -c "alter database postgres set app.settings.project_url = 'https://<ref>.supabase.co';"
psql "$DATABASE_URL" -c "alter database postgres set app.settings.cron_secret = '<same value as CRON_SECRET>';"
supabase db push                      # now 0003 can be applied
```

## Auth configuration

In **Authentication → URL Configuration**, add the redirect URL the app
uses:

```
io.vitalrise.app://login-callback
```

Enable the providers you intend to ship: Email (magic link), Google, Apple.
Apple sign-in is **mandatory** for App Store review if Google sign-in is
offered.

## Which key goes where

| Key | Lives in | Notes |
| --- | --- | --- |
| Publishable (anon) key | The app binary | Public by design. RLS is what protects the data, not this key. |
| Service role key | `send-reminders` function env only | Bypasses RLS. Never in the app, never in CI logs. |
| `ANTHROPIC_API_KEY` | `ai-coach` function env only | Would be extractable from any binary it shipped in. |
| `CRON_SECRET` | Function env + database setting | Stops anyone POSTing the reminder endpoint. |

## Verifying RLS actually works

Do this after any policy change. It is the single most valuable five
minutes of testing in the project.

```sql
-- As user A, insert a row, then:
set local role authenticated;
set local request.jwt.claims = '{"sub":"<user-B-uuid>"}';

select count(*) from public.assessments;   -- must be 0
select count(*) from public.habit_logs;    -- must be 0

-- And a write aimed at somebody else must fail outright:
insert into public.habit_logs (user_id, day, kegel_sessions)
values ('<user-A-uuid>', current_date, 1);
-- ERROR: new row violates row-level security policy
```

## Scaling notes

The schema is built so that growth is boring:

- Every user-data index leads with `user_id`, so query cost is a function of
  one person's history, not the table size.
- `habit_logs` and `progress_entries` use natural composite keys, so client
  retries upsert idempotently instead of duplicating rows.
- `coach_events` is the only append-heavy table and is pruned to 90 days.
- When `habit_logs` outgrows a single table (roughly 100M rows, or about
  100k users after three years), partition it by `RANGE (day)` with yearly
  partitions. The primary key already leads with `user_id`, so the
  partitioning column can be added without changing any query.
