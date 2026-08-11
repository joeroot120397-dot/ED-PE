// =====================================================================
// VitalRise AI coach
//
// Why this runs on the server at all: the model API key must never be in a
// mobile binary, where anyone can extract it. The client does retrieval
// locally (the corpus is bundled) and sends the passages it found; this
// function adds the system prompt, calls the model, and returns prose.
//
// It re-applies its own safety triage rather than trusting the client's.
// The app already blocks emergencies before they get here, but a server
// that assumes its callers are honest is a server with no guardrails.
// =====================================================================

import Anthropic from "npm:@anthropic-ai/sdk@0.71.0";
import { createClient } from "npm:@supabase/supabase-js@2";

const MODEL = Deno.env.get("COACH_MODEL") ?? "claude-sonnet-5";
const MAX_TOKENS = 700;

const SYSTEM_PROMPT = `
You are the VitalRise coach, an educational assistant inside a men's sexual
wellness app. You are not a doctor and you never behave like one.

Rules, in priority order:
1. Never diagnose. Never tell the user they "have" a condition.
2. Never recommend, dose, compare or source prescription medication or
   hormones. Redirect those questions to a prescriber. If the user says a
   medication may be causing a problem, tell them to raise it with the
   prescriber rather than stop on their own.
3. Never claim the app or any exercise cures anything. Talk about what
   improves, for whom, and over what timeframe.
4. Ground every factual claim in the CONTEXT passages provided. If the
   context does not cover the question, say so plainly rather than
   inventing a mechanism or a statistic. Do not draw on outside knowledge
   for clinical claims.
5. Point to a healthcare professional whenever the question involves
   symptoms, medication, sudden changes, pain, or anything an app cannot
   assess.
6. Be direct, warm and concrete. The user is often embarrassed and has
   usually been told to "just relax" by someone unhelpful. Never moralise
   about pornography, masturbation or relationships.
7. Keep answers under 200 words unless the user asks for detail. Lead with
   the answer, then the mechanism, then the action.
8. Close with this exact line when the question touches on symptoms or a
   health decision: "This application provides educational guidance only
   and is not a substitute for medical advice. Consult a qualified
   healthcare professional for diagnosis and treatment."
`.trim();

// Server-side triage. Deliberately duplicated from the Dart implementation
// in lib/features/coach/domain/coach_safety.dart - the client copy exists
// so an emergency answer works offline, this copy exists so the model is
// never reachable by a caller that skipped it.
const EMERGENCY = [
  "kill myself", "killing myself", "end my life", "suicide", "suicidal",
  "want to die", "better off dead", "self harm", "self-harm", "hurt myself",
  "chest pain", "erection lasting", "erection for hours", "priapism",
  "blood in urine", "blood in my urine", "blood in semen", "penile fracture",
  "cant urinate", "can't urinate", "unable to urinate",
];

const MEDICATION = [
  "viagra", "sildenafil", "cialis", "tadalafil", "levitra", "vardenafil",
  "stendra", "avanafil", "dapoxetine", "priligy", "trt", "anabolic",
  "steroid cycle", "clomid", "clomiphene", "hcg", "what dose", "what dosage",
  "how many mg", "without a prescription", "buy online",
];

const EMERGENCY_REPLY =
  "What you are describing needs urgent medical attention rather than an " +
  "app.\n\nSeek urgent care for chest pain, an erection lasting more than " +
  "4 hours, blood in urine or semen, sudden loss of erections after " +
  "injury, or thoughts of self-harm. If you are in immediate danger, call " +
  "emergency services. For mental health crises: 988 in the US, 116 123 " +
  "for Samaritans in the UK, or findahelpline.com elsewhere.";

const MEDICATION_REPLY =
  "I cannot advise on prescription medication - not doses, not sourcing, " +
  "and not whether to start or stop anything. That needs a prescriber who " +
  "knows your history and your other medications.\n\nI can help with the " +
  "training, nutrition and sleep side, and help you work out what to raise " +
  "at the appointment.\n\nIf you noticed a change after starting a " +
  "medication, do not stop it on your own - tell the prescriber, there is " +
  "often an alternative.";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface Passage {
  source: string;
  title: string;
  body: string;
}

interface CoachRequest {
  question?: string;
  profile?: Record<string, unknown>;
  context?: Passage[];
  history?: { role: string; text: string }[];
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

function matches(text: string, needles: string[]): boolean {
  const lower = text.toLowerCase();
  return needles.some((n) => lower.includes(n));
}

/** Fire-and-forget telemetry. Records the verdict, never the message. */
async function record(
  authHeader: string | null,
  verdict: string,
  answeredBy: string,
  reason: string | null,
  latencyMs: number,
): Promise<void> {
  try {
    const url = Deno.env.get("SUPABASE_URL");
    const key = Deno.env.get("SUPABASE_ANON_KEY");
    if (!url || !key || !authHeader) return;

    const client = createClient(url, key, {
      global: { headers: { Authorization: authHeader } },
    });
    await client.from("coach_events").insert({
      verdict,
      answered_by: answeredBy,
      reason,
      latency_ms: latencyMs,
    });
  } catch {
    // Telemetry must never break an answer.
  }
}

function buildUserMessage(req: CoachRequest): string {
  const passages = (req.context ?? []).slice(0, 6);
  const lines: string[] = [];

  const profile = req.profile ?? {};
  const causes = profile["top_causes"];
  lines.push(
    `USER PROFILE: ${
      Array.isArray(causes) && causes.length > 0
        ? `main drivers ${causes.join(", ")}`
        : "no assessment on file"
    }${profile["program_week"] ? `, week ${profile["program_week"]}` : ""}.`,
  );
  lines.push("");
  lines.push("CONTEXT PASSAGES:");

  if (passages.length === 0) {
    lines.push("(none matched - say so rather than guessing)");
  } else {
    passages.forEach((p, i) => {
      lines.push(`[${i + 1}] ${p.source} - ${p.title}`);
      lines.push(p.body);
      lines.push("");
    });
  }

  lines.push(`QUESTION: ${req.question}`);
  lines.push("");
  lines.push("Answer using only the context above.");
  return lines.join("\n");
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }
  if (request.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  const started = Date.now();
  const authHeader = request.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "unauthorised" }, 401);
  }

  let body: CoachRequest;
  try {
    body = await request.json() as CoachRequest;
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }

  const question = (body.question ?? "").trim();
  if (!question) {
    return json({ error: "question is required" }, 400);
  }
  if (question.length > 2000) {
    return json({ error: "question is too long" }, 413);
  }

  // ---- Safety triage, before anything reaches the model ----
  if (matches(question, EMERGENCY)) {
    await record(authHeader, "emergency", "blocked", "emergency", 0);
    return json({ answer: EMERGENCY_REPLY, blocked: true });
  }
  if (matches(question, MEDICATION)) {
    await record(authHeader, "refuse", "blocked", "medication", 0);
    return json({ answer: MEDICATION_REPLY, blocked: true });
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    // Returning an error rather than a generic answer is deliberate: the
    // client falls back to its own on-device library answer, which is
    // grounded in reviewed content, instead of showing an apology.
    return json({ error: "coach is not configured" }, 503);
  }

  try {
    const client = new Anthropic({ apiKey });

    const history = (body.history ?? [])
      .slice(-6)
      .filter((m) => typeof m.text === "string" && m.text.trim().length > 0)
      .map((m) => ({
        role: m.role === "user" ? "user" as const : "assistant" as const,
        content: m.text.slice(0, 4000),
      }));

    // The last turn is the freshly grounded question; anything the client
    // sent as history is context only.
    const messages = [
      ...history.slice(0, -1),
      { role: "user" as const, content: buildUserMessage(body) },
    ];

    const response = await client.messages.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: SYSTEM_PROMPT,
      messages,
    });

    const answer = response.content
      .filter((block) => block.type === "text")
      .map((block) => (block as { text: string }).text)
      .join("\n")
      .trim();

    if (!answer) {
      return json({ error: "empty completion" }, 502);
    }

    await record(authHeader, "allow", "model", null, Date.now() - started);
    return json({ answer, model: MODEL });
  } catch (error) {
    console.error("coach failure", error);
    return json({ error: "coach unavailable" }, 502);
  }
});
