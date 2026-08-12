"""
llm.py
------
The debate engine. Six seats around one table - Bull, Bear, Fundamentals,
Technicals, News - and a Judge who weighs what they said and issues the
verdict.

Provider auto-detection, in priority order:

  1. claude_code : the `claude` CLI on PATH. Shelled out to with
                   `claude -p "<prompt>" --output-format json --model <model>`.
                   Uses the user's own Claude subscription - no API key, no
                   per-call billing. If the JSON envelope comes back with
                   is_error true we raise, which trips the fallback.
  2. anthropic   : ANTHROPIC_API_KEY via the Messages API.
  3. openai      : OPENAI_API_KEY via Chat Completions.

Set LLM_PROVIDER=claude_code|anthropic|openai to force one.

If the chosen provider fails for any reason - not installed, not logged in,
no network, bad JSON, timeout - we fall back to scoring.evaluate() and the
run continues. The dashboard always finishes.

Grounding rule (non-negotiable): every figure an agent cites must exist in the
evidence bundle. verify_output() below re-reads the model's prose and flags any
number that cannot be traced back to the evidence.

Note on the transport: this module speaks raw HTTPS via `requests` rather than
the official SDKs. That is deliberate - the app ships three interchangeable
providers (including a non-Anthropic one) behind one interface, and keeps its
dependency list to flask/requests/yfinance.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess

import requests

import scoring

ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_VERSION = "2023-06-01"
OPENAI_URL = "https://api.openai.com/v1/chat/completions"

# Per-provider model defaults. Override with the matching env var.
CLAUDE_CLI_MODEL = os.environ.get("CLAUDE_CLI_MODEL", "haiku")   # haiku | sonnet
ANTHROPIC_MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-opus-5")
OPENAI_MODEL = os.environ.get("OPENAI_MODEL", "gpt-4o-mini")

CLI_TIMEOUT = int(os.environ.get("LLM_TIMEOUT", "120"))
HTTP_TIMEOUT = int(os.environ.get("LLM_HTTP_TIMEOUT", "90"))

SYSTEM_PROMPT = """You are the panel of an Indian equity desk (NSE-listed stocks).
Five analysts argue one stock, then a Judge rules.

House rules:
- A BUY needs genuinely favourable risk/reward WITH confirmation - momentum and
  volume must agree. Promising but unconfirmed is a WATCH. Poor risk/reward is
  an AVOID.
- Every number you cite must appear in the evidence bundle you are given.
  Never invent, estimate or recall a figure from memory. If a value you need is
  missing, write exactly "data unavailable".
- The bundle carries no P/E, ROE, margin or debt data. Do not pretend otherwise.
- Reply with one JSON object and nothing else. No prose, no markdown fence."""

USER_TEMPLATE = """EVIDENCE BUNDLE (the only facts you may cite):
{evidence}

Return exactly this JSON shape:
{{
  "bull":           {{"score": 0-100, "point": "<=25 words"}},
  "bear":           {{"score": 0-100, "point": "<=25 words"}},
  "fundamentalist": {{"score": 0-100, "point": "<=25 words"}},
  "technician":     {{"score": 0-100, "point": "<=25 words"}},
  "newsdesk":       {{"score": 0-100, "point": "<=25 words"}},
  "judge": {{
    "winner": "Bull" or "Bear",
    "verdict": "BUY" or "WATCH" or "AVOID",
    "confidence": 1-10,
    "rationale": "<=2 lines",
    "key_catalyst": "the single strongest reason, one line"
  }}
}}

score = that seat's conviction, 0 (no case) to 100 (overwhelming case)."""


# --------------------------------------------------------------------------- #
# provider detection
# --------------------------------------------------------------------------- #
def claude_cli_path():
    return shutil.which("claude")


def detect_provider() -> str:
    """Returns 'claude_code' | 'anthropic' | 'openai' | 'deterministic'."""
    forced = (os.environ.get("LLM_PROVIDER") or "").strip().lower()
    if forced in ("claude_code", "anthropic", "openai", "deterministic"):
        return forced
    if claude_cli_path():
        return "claude_code"
    if os.environ.get("ANTHROPIC_API_KEY"):
        return "anthropic"
    if os.environ.get("OPENAI_API_KEY"):
        return "openai"
    return "deterministic"


def engine_label(provider: str) -> str:
    return {
        "claude_code": f"claude CLI ({CLAUDE_CLI_MODEL})",
        "anthropic": f"anthropic api ({ANTHROPIC_MODEL})",
        "openai": f"openai api ({OPENAI_MODEL})",
        "deterministic": "deterministic rules",
    }.get(provider, provider)


# --------------------------------------------------------------------------- #
# transports - each returns the model's raw text
# --------------------------------------------------------------------------- #
def _call_claude_cli(prompt: str) -> str:
    binary = claude_cli_path()
    if not binary:
        raise RuntimeError("claude CLI not found on PATH")

    completed = subprocess.run(
        [binary, "-p", prompt, "--output-format", "json", "--model", CLAUDE_CLI_MODEL],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        timeout=CLI_TIMEOUT,
    )
    if completed.returncode != 0:
        raise RuntimeError(f"claude CLI exited {completed.returncode}")

    envelope = json.loads(completed.stdout)
    if envelope.get("is_error"):
        raise RuntimeError("claude CLI reported is_error - falling back")
    result = envelope.get("result")
    if not result:
        raise RuntimeError("claude CLI returned an empty result")
    return result


def _call_anthropic(prompt: str) -> str:
    key = os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        raise RuntimeError("ANTHROPIC_API_KEY is not set")

    # No temperature/top_p: current Claude models reject sampling parameters.
    response = requests.post(
        ANTHROPIC_URL,
        headers={
            "x-api-key": key,
            "anthropic-version": ANTHROPIC_VERSION,
            "content-type": "application/json",
        },
        json={
            "model": ANTHROPIC_MODEL,
            "max_tokens": 8000,
            "system": SYSTEM_PROMPT,
            "messages": [{"role": "user", "content": prompt}],
        },
        timeout=HTTP_TIMEOUT,
    )
    response.raise_for_status()
    payload = response.json()
    if payload.get("stop_reason") == "refusal":
        raise RuntimeError("anthropic api declined the request")
    text = "".join(
        block.get("text", "")
        for block in payload.get("content", [])
        if block.get("type") == "text"
    )
    if not text.strip():
        raise RuntimeError("anthropic api returned no text")
    return text


def _call_openai(prompt: str) -> str:
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        raise RuntimeError("OPENAI_API_KEY is not set")

    response = requests.post(
        OPENAI_URL,
        headers={"Authorization": f"Bearer {key}", "content-type": "application/json"},
        json={
            "model": OPENAI_MODEL,
            "temperature": 0.2,
            "response_format": {"type": "json_object"},
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
        },
        timeout=HTTP_TIMEOUT,
    )
    response.raise_for_status()
    return response.json()["choices"][0]["message"]["content"]


TRANSPORTS = {
    "claude_code": _call_claude_cli,
    "anthropic": _call_anthropic,
    "openai": _call_openai,
}


# --------------------------------------------------------------------------- #
# parsing + grounding verifier
# --------------------------------------------------------------------------- #
def extract_json(text: str) -> dict:
    """Pull the first JSON object out of a reply that may be fenced or chatty."""
    text = (text or "").strip()
    fence = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", text, re.DOTALL)
    if fence:
        text = fence.group(1)

    try:
        return json.loads(text)
    except ValueError:
        pass

    start = text.find("{")
    if start == -1:
        raise ValueError("no JSON object in model reply")
    depth = 0
    for index in range(start, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return json.loads(text[start : index + 1])
    raise ValueError("unterminated JSON object in model reply")


def _evidence_numbers(evidence) -> set:
    """
    Every number the model is allowed to cite, plus harmless derivations:
    the absolute value (agents say "42% below the high", the bundle stores
    -42.12) and the 0- and 1-decimal roundings of both.
    """
    found = set()

    def walk(node):
        if isinstance(node, dict):
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)
        elif isinstance(node, bool):
            return
        elif isinstance(node, (int, float)):
            number = float(node)
            for base in (number, abs(number)):
                found.update({round(base, 2), round(base, 1), float(round(base))})

    walk(evidence)
    return found


# Pulling numbers out of prose is fiddlier than it looks:
#   - a hyphen only means "minus" when it doesn't follow a word character,
#     so "380-700" is a range and "SMA-20" is a name, not -700 and -20
#   - thousands separators are only real between digits, so a trailing
#     comma in "RVOL 3.1, up 20, strong" is punctuation, not part of 20
NUMBER_RE = re.compile(r"(?<![\w.,])-?\d+(?:,\d{3})*(?:\.\d+)?")

# "52-week high" is a phrase, not a figure the model is claiming.
PHRASE_RE = re.compile(r"\b52[\s-]*(?:week|wk|w)\b", re.IGNORECASE)
CONFIDENCE_RE = re.compile(r"\b\d+\s*/\s*10\b")


def _traceable(value: float, allowed) -> bool:
    """Allow honest rounding: within half a unit, or 1% of the figure."""
    for candidate in allowed:
        if abs(value - candidate) <= max(0.55, abs(candidate) * 0.01):
            return True
    return False


def verify_output(parsed: dict, evidence: dict) -> list:
    """
    Flag any number in the model's prose that isn't traceable to the evidence.

    Only free text is checked - the seats' own 0-100 scores and the Judge's
    1-10 confidence are outputs, not claims about the stock. Small integers are
    skipped too: they are almost always counts or ordinals rather than figures.
    """
    allowed = _evidence_numbers(evidence)
    flags = []

    texts = []
    for seat in ("bull", "bear", "fundamentalist", "technician", "newsdesk"):
        block = parsed.get(seat) or {}
        texts.append((seat, str(block.get("point") or "")))
        # A Judge writing "Bull case leads 78-68" is quoting the panel's own
        # conviction scores, not claiming a figure about the stock.
        try:
            allowed.add(float(block.get("score")))
        except (TypeError, ValueError):
            pass
    judge = parsed.get("judge") or {}
    texts.append(("judge", str(judge.get("rationale") or "")))
    texts.append(("judge", str(judge.get("key_catalyst") or "")))

    for seat, text in texts:
        cleaned = CONFIDENCE_RE.sub(" ", text)   # "8/10" is a confidence, not a claim
        cleaned = PHRASE_RE.sub(" ", cleaned)    # "52-week" is a phrase, not a claim
        for raw in NUMBER_RE.findall(cleaned):
            try:
                value = float(raw.replace(",", ""))
            except ValueError:
                continue
            if abs(value) <= 12 and value == int(value):
                continue
            if _traceable(value, allowed):
                continue
            flags.append(f"{seat}: '{raw}' is not in the evidence")
    return flags


# --------------------------------------------------------------------------- #
# normalization
# --------------------------------------------------------------------------- #
def _clamp(value, low, high, default):
    try:
        value = float(value)
    except (TypeError, ValueError):
        return default
    return int(max(low, min(high, round(value))))


def _shape(parsed: dict, evidence: dict, engine: str) -> dict:
    scores = {}
    for seat in ("bull", "bear", "fundamentalist", "technician", "newsdesk"):
        block = parsed.get(seat) or {}
        point = str(block.get("point") or "").strip() or "No comment recorded"
        scores[seat] = {"score": _clamp(block.get("score"), 0, 100, 50), "reasons": [point]}

    judge = parsed.get("judge") or {}
    verdict = str(judge.get("verdict") or "").strip().upper()
    if verdict not in ("BUY", "WATCH", "AVOID"):
        verdict = "WATCH"

    bull_score = scores["bull"]["score"]
    bear_score = scores["bear"]["score"]
    winner = str(judge.get("winner") or "").strip().title()
    if winner not in ("Bull", "Bear"):
        winner = "Bull" if bull_score >= bear_score else "Bear"

    confidence = _clamp(judge.get("confidence"), 1, 10, 5)
    confidence = max(confidence, 7) if verdict == "BUY" else min(confidence, 6)

    return {
        "scores": scores,
        "verdict": {
            "winner": winner,
            "verdict": verdict,
            "confidence": confidence,
            "rationale": str(judge.get("rationale") or "").strip() or "No rationale returned.",
            "key_catalyst": str(judge.get("key_catalyst") or "").strip()
            or scores["bull"]["reasons"][0],
            "bull_score": bull_score,
            "bear_score": bear_score,
            "net": bull_score - bear_score,
        },
        "engine": engine,
        "grounding_flags": verify_output(parsed, evidence),
    }


# --------------------------------------------------------------------------- #
# public entry point
# --------------------------------------------------------------------------- #
def evaluate(evidence: dict, provider=None):
    """
    One combined call per stock. Returns the same shape as scoring.evaluate(),
    plus "engine" and "grounding_flags". Never raises - a failed debate falls
    back to the deterministic engine and records why.
    """
    provider = provider or detect_provider()
    if provider == "deterministic":
        result = scoring.evaluate(evidence)
        result["grounding_flags"] = []
        return result

    transport = TRANSPORTS.get(provider)
    if transport is None:
        result = scoring.evaluate(evidence)
        result["grounding_flags"] = []
        result["fallback_reason"] = f"unknown provider '{provider}'"
        return result

    prompt = f"{SYSTEM_PROMPT}\n\n{USER_TEMPLATE.format(evidence=json.dumps(evidence, indent=2))}"
    try:
        raw = transport(prompt)
        parsed = extract_json(raw)
        return _shape(parsed, evidence, provider)
    except Exception as exc:  # noqa: BLE001 - any failure must fall back cleanly
        result = scoring.evaluate(evidence)
        result["grounding_flags"] = []
        result["fallback_reason"] = f"{type(exc).__name__}: {exc}"[:180]
        return result
