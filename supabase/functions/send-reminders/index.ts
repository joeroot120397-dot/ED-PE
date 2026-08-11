// =====================================================================
// Training reminders
//
// Scheduled hourly by pg_cron (see 0003_scheduling.sql). Each run picks the
// users whose chosen reminder hour matches the current hour in their locale
// and who have not logged a session today, then sends one push.
//
// Reminders are sent server-side rather than scheduled on device because a
// 100k-user product cannot rely on every phone's alarm surviving battery
// optimisation - and because it lets us skip the notification entirely for
// people who have already trained, which is the difference between a useful
// nudge and an app people mute.
//
// The notification body deliberately never mentions erections, ejaculation
// or sexual health. It appears on a lock screen that other people can see.
// =====================================================================

import { createClient } from "npm:@supabase/supabase-js@2";

interface Candidate {
  id: string;
  push_token: string;
  display_name: string | null;
}

const MESSAGES = [
  "Two minutes of training keeps your streak going.",
  "Your session is ready when you are.",
  "A short session today beats a long one tomorrow.",
  "Still time to log today's training.",
];

Deno.serve(async (request: Request): Promise<Response> => {
  // Only the scheduler may invoke this.
  const secret = Deno.env.get("CRON_SECRET");
  if (!secret || request.headers.get("x-cron-secret") !== secret) {
    return new Response(JSON.stringify({ error: "unauthorised" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    // The service role key bypasses RLS, which is exactly why it lives only
    // in this function's environment and never in the app.
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const hour = new Date().getUTCHours();
  const today = new Date().toISOString().slice(0, 10);

  const { data: candidates, error } = await supabase
    .from("profiles")
    .select("id, push_token, display_name")
    .eq("reminders_on", true)
    .eq("reminder_hour", hour)
    .not("push_token", "is", null)
    .limit(5000);

  if (error) {
    console.error("candidate query failed", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const list = (candidates ?? []) as Candidate[];
  if (list.length === 0) {
    return new Response(JSON.stringify({ sent: 0, skipped: 0 }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  // One query for everyone who has already trained, rather than one per
  // user: at this scale the round trips matter more than the row count.
  const { data: doneRows } = await supabase
    .from("habit_logs")
    .select("user_id")
    .eq("day", today)
    .gt("kegel_sessions", 0)
    .in("user_id", list.map((c) => c.id));

  const alreadyTrained = new Set(
    (doneRows ?? []).map((r: { user_id: string }) => r.user_id),
  );

  const serverKey = Deno.env.get("FCM_SERVER_KEY");
  let sent = 0;
  let skipped = 0;

  for (const candidate of list) {
    if (alreadyTrained.has(candidate.id)) {
      skipped++;
      continue;
    }
    if (!serverKey) {
      skipped++;
      continue;
    }

    const message = MESSAGES[sent % MESSAGES.length];
    try {
      const response = await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          Authorization: `key=${serverKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          to: candidate.push_token,
          notification: {
            // Neutral title on purpose - this shows on a lock screen.
            title: "VitalRise",
            body: message,
          },
          data: { route: "/today" },
          android: { priority: "normal" },
          apns: { headers: { "apns-priority": "5" } },
        }),
      });

      if (response.ok) {
        sent++;
      } else {
        skipped++;
        // A 404 or 410 from FCM means the token is dead; clear it so we
        // stop paying to send into the void every hour.
        if (response.status === 404 || response.status === 410) {
          await supabase
            .from("profiles")
            .update({ push_token: null })
            .eq("id", candidate.id);
        }
      }
    } catch (err) {
      console.error("send failed", err);
      skipped++;
    }
  }

  return new Response(JSON.stringify({ sent, skipped, hour }), {
    headers: { "Content-Type": "application/json" },
  });
});
