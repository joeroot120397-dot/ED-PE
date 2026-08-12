"""
app.py
------
The server, the state machine, the Telegram sender and the SQLite audit.

    python app.py  ->  http://127.0.0.1:5000  ->  press "Start agents"

A background thread walks the agent pipeline. The page polls /status roughly
twice a second and re-renders from whatever it finds. Nothing is streamed and
nothing is stateful on the client - if you reload mid-run the dashboard picks
the run back up exactly where it is.

No orders are ever placed. This is analysis only.
"""

from __future__ import annotations

import html
import json
import os
import sqlite3
import threading
import time
from datetime import datetime, timedelta, timezone

import requests
from flask import Flask, jsonify, request, send_from_directory

import data_sources
import llm
import scoring

HERE = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(HERE, "audit.db")
IST = timezone(timedelta(hours=5, minutes=30))


# --------------------------------------------------------------------------- #
# .env - a tiny loader, no hard dependency on python-dotenv
# --------------------------------------------------------------------------- #
def load_env(path=os.path.join(HERE, ".env")):
    if not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key, value = key.strip(), value.strip().strip('"').strip("'")
            if key and key not in os.environ:
                os.environ[key] = value


load_env()

BRAND = os.environ.get("BRAND", "Dalal Desk")
CONFIDENCE_THRESHOLD = int(os.environ.get("CONFIDENCE_THRESHOLD", "7"))
AGENT_DELAY = float(os.environ.get("AGENT_DELAY", "0.7"))
SHORTLIST_PER_BUCKET = int(os.environ.get("SHORTLIST_PER_BUCKET", "4"))
PORT = int(os.environ.get("PORT", "5000"))
TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "").strip()

DISCLAIMER = "— Analysis only. No trade was placed. Not investment advice."


def scrub(text) -> str:
    """The bot token must never reach a log, the UI or the database."""
    text = str(text)
    if TELEGRAM_BOT_TOKEN:
        text = text.replace(TELEGRAM_BOT_TOKEN, "***")
        head = TELEGRAM_BOT_TOKEN.split(":")[0]
        if head and len(head) > 3:
            text = text.replace(head, "***")
    return text


# --------------------------------------------------------------------------- #
# the panel
# --------------------------------------------------------------------------- #
AGENTS = [
    {
        "id": "scout",
        "name": "Scout",
        "icon": "🔭",
        "role": "screens the stock universe for movers",
        "stat1_label": "Scanned",
        "stat2_label": "Shortlisted",
    },
    {
        "id": "technician",
        "name": "Technician",
        "icon": "📈",
        "role": "reads price action, RVOL & trend",
        "stat1_label": "Analyzed",
        "stat2_label": "Avg RVOL",
    },
    {
        "id": "fundamentalist",
        "name": "Fundamentalist",
        "icon": "🏛️",
        "role": "weighs valuation & analyst targets",
        "stat1_label": "Covered",
        "stat2_label": "Avg upside",
    },
    {
        "id": "newsdesk",
        "name": "Newsdesk",
        "icon": "📰",
        "role": "pulls live news & scores sentiment",
        "stat1_label": "Headlines",
        "stat2_label": "Net tone",
    },
    {
        "id": "bull",
        "name": "Bull",
        "icon": "🐂",
        "role": "argues the case to buy",
        "stat1_label": "Cases",
        "stat2_label": "Avg score",
    },
    {
        "id": "bear",
        "name": "Bear",
        "icon": "🐻",
        "role": "argues the case against",
        "stat1_label": "Cases",
        "stat2_label": "Avg score",
    },
    {
        "id": "judge",
        "name": "Judge",
        "icon": "⚖️",
        "role": "weighs the debate, issues verdict + confidence",
        "stat1_label": "Verdicts",
        "stat2_label": "Buy",
    },
    {
        "id": "messenger",
        "name": "Messenger",
        "icon": "✈️",
        "role": "sends signals to Telegram",
        "stat1_label": "Sent",
        "stat2_label": "Engine",
    },
]


def blank_state():
    return {
        "brand": BRAND,
        "running": False,
        "mode": "demo",
        "engine": llm.engine_label(llm.detect_provider()),
        "provider": llm.detect_provider(),
        "phase": "idle",
        "started_at": None,
        "finished_at": None,
        "data_timestamp": None,
        "confidence_threshold": CONFIDENCE_THRESHOLD,
        "kpis": {
            "universe": 0,
            "in_debate": 0,
            "buy_signals": 0,
            "top_pick": {"symbol": "—", "confidence": None},
        },
        "agents": [
            dict(agent, status="offline", stat1_value="—", stat2_value="—")
            for agent in AGENTS
        ],
        "verdicts": [],
        "log": [],
        "telegram": {"configured": bool(TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID), "sent": 0, "error": None},
        "run_id": None,
    }


STATE = blank_state()
LOCK = threading.Lock()


def set_agent(agent_id, **fields):
    with LOCK:
        for agent in STATE["agents"]:
            if agent["id"] == agent_id:
                agent.update(fields)
                return


def log(message):
    stamp = datetime.now(IST).strftime("%H:%M:%S")
    with LOCK:
        STATE["log"].insert(0, f"[{stamp}] {scrub(message)}")
        del STATE["log"][60:]


def pace():
    if AGENT_DELAY > 0:
        time.sleep(AGENT_DELAY)


# --------------------------------------------------------------------------- #
# SQLite audit
# --------------------------------------------------------------------------- #
def db():
    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    return connection


def init_db():
    with db() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS runs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                started_at TEXT, finished_at TEXT,
                mode TEXT, engine TEXT,
                universe INTEGER, shortlisted INTEGER,
                buy_signals INTEGER, messages_sent INTEGER,
                top_symbol TEXT, top_confidence INTEGER
            );
            CREATE TABLE IF NOT EXISTS verdicts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                run_id INTEGER, created_at TEXT,
                symbol TEXT, name TEXT, cap_segment TEXT,
                verdict TEXT, confidence INTEGER, winner TEXT,
                bull_score INTEGER, bear_score INTEGER, net INTEGER,
                rationale TEXT, key_catalyst TEXT,
                price REAL, day_change_pct REAL,
                fired INTEGER, engine TEXT,
                grounding_flags TEXT, data_gaps TEXT,
                FOREIGN KEY (run_id) REFERENCES runs (id)
            );
            """
        )


def open_run(mode, engine):
    with db() as connection:
        cursor = connection.execute(
            "INSERT INTO runs (started_at, mode, engine) VALUES (?, ?, ?)",
            (datetime.now(IST).isoformat(timespec="seconds"), mode, engine),
        )
        return cursor.lastrowid


def close_run(run_id, **fields):
    if run_id is None:
        return
    columns = ", ".join(f"{key} = ?" for key in fields)
    with db() as connection:
        connection.execute(
            f"UPDATE runs SET finished_at = ?, {columns} WHERE id = ?",
            (datetime.now(IST).isoformat(timespec="seconds"), *fields.values(), run_id),
        )


def save_verdict(run_id, row):
    with db() as connection:
        connection.execute(
            """INSERT INTO verdicts (
                run_id, created_at, symbol, name, cap_segment, verdict, confidence,
                winner, bull_score, bear_score, net, rationale, key_catalyst,
                price, day_change_pct, fired, engine, grounding_flags, data_gaps
            ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                run_id,
                datetime.now(IST).isoformat(timespec="seconds"),
                row["symbol"], row["name"], row["cap_segment"], row["verdict"],
                row["confidence"], row["winner"], row["bull_score"], row["bear_score"],
                row["net"], scrub(row["rationale"]), scrub(row["key_catalyst"]),
                row["price"], row["day_change_pct"], int(row["fired"]), row["engine"],
                json.dumps(row["grounding_flags"]), json.dumps(row["data_gaps"]),
            ),
        )


# --------------------------------------------------------------------------- #
# Telegram
# --------------------------------------------------------------------------- #
def telegram_send(message_html: str) -> bool:
    if not (TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID):
        return False
    try:
        response = requests.post(
            f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage",
            json={
                "chat_id": TELEGRAM_CHAT_ID,
                "text": message_html,
                "parse_mode": "HTML",
                "disable_web_page_preview": True,
            },
            timeout=20,
        )
        if response.status_code != 200:
            # response bodies echo the URL, so scrub before it goes anywhere
            raise RuntimeError(scrub(response.text)[:160])
        return True
    except Exception as exc:  # noqa: BLE001
        error = scrub(f"{type(exc).__name__}: {exc}")[:160]
        with LOCK:
            STATE["telegram"]["error"] = error
        log(f"Telegram send failed - {error}")
        return False


def buy_message(row) -> str:
    esc = html.escape
    price = "data unavailable" if row["price"] is None else f"₹{row['price']:,.2f}"
    change = (
        "data unavailable"
        if row["day_change_pct"] is None
        else f"{row['day_change_pct']:+.2f}%"
    )
    return "\n".join(
        [
            f"🟢 <b>BUY SIGNAL — {esc(row['symbol'])}</b> ({esc(row['cap_segment'].title())} cap)",
            f"Verdict: BUY | Confidence: {row['confidence']}/10",
            f"Winner: {esc(row['winner'])}",
            f"Why: {esc(row['rationale'])}",
            f"Key catalyst: {esc(row['key_catalyst'])}",
            f"Live price: {price} | Day change: {change}",
            "",
            f"<i>{esc(DISCLAIMER)}</i>",
        ]
    )


def summary_message(mode, engine, universe, shortlisted, fired) -> str:
    esc = html.escape
    lines = [
        f"📋 <b>{esc(BRAND)} — daily summary</b>",
        f"{datetime.now(IST).strftime('%d %b %Y, %H:%M')} IST",
        "",
        f"Scanned {universe} stocks · {shortlisted} went to debate · mode: {esc(mode)}",
        f"Engine: {esc(engine)}",
        "",
    ]
    if fired:
        lines.append(f"<b>{len(fired)} BUY signal(s) fired</b>")
        for row in fired:
            price = "data unavailable" if row["price"] is None else f"₹{row['price']:,.2f}"
            lines.append(
                f"• <b>{esc(row['symbol'])}</b> — {row['confidence']}/10 · {price}"
            )
    else:
        lines.append("<b>No BUY signals fired today.</b>")
    lines += ["", f"<i>{esc(DISCLAIMER)}</i>"]
    return "\n".join(lines)


# --------------------------------------------------------------------------- #
# the cycle
# --------------------------------------------------------------------------- #
def _mean(values):
    values = [v for v in values if v is not None]
    return sum(values) / len(values) if values else None


def run_cycle(mode):
    provider = llm.detect_provider()
    engine = llm.engine_label(provider)
    run_id = open_run(mode, engine)

    with LOCK:
        STATE.update(
            {
                "running": True,
                "mode": mode,
                "engine": engine,
                "provider": provider,
                "phase": "scanning",
                "started_at": datetime.now(IST).isoformat(timespec="seconds"),
                "finished_at": None,
                "verdicts": [],
                "run_id": run_id,
                "kpis": {
                    "universe": 0,
                    "in_debate": 0,
                    "buy_signals": 0,
                    "top_pick": {"symbol": "—", "confidence": None},
                },
                "telegram": {
                    "configured": bool(TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID),
                    "sent": 0,
                    "error": None,
                },
            }
        )
        for agent in STATE["agents"]:
            agent.update(status="offline", stat1_value="—", stat2_value="—")

    log(f"Run started in {mode} mode · engine: {engine}")

    try:
        # ---- Scout ------------------------------------------------------- #
        set_agent("scout", status="working", stat1_value=0, stat2_value=0)

        def on_progress(done, total, symbol):
            set_agent("scout", stat1_value=done)
            with LOCK:
                STATE["kpis"]["universe"] = done
            if done == 1 or done % 5 == 0 or done == total:
                log(f"Scout screened {symbol} ({done}/{total})")

        universe, bundles = data_sources.scan(
            mode, SHORTLIST_PER_BUCKET, on_progress, on_warn=log
        )
        with LOCK:
            STATE["kpis"]["universe"] = universe
            STATE["kpis"]["in_debate"] = len(bundles)
            STATE["data_timestamp"] = data_sources.now_ist_str()
        set_agent("scout", status="done", stat1_value=universe, stat2_value=len(bundles))
        log(f"Scout shortlisted {len(bundles)} of {universe}")
        pace()

        if not bundles:
            log("Nothing made the shortlist - stopping here")
            raise RuntimeError("empty shortlist")

        # ---- Technician -------------------------------------------------- #
        set_agent("technician", status="working", stat1_value=0, stat2_value="—")
        rvols = []
        for index, bundle in enumerate(bundles, start=1):
            rvols.append((bundle.get("technicals") or {}).get("rvol"))
            set_agent("technician", stat1_value=index)
        average = _mean(rvols)
        set_agent(
            "technician",
            status="done",
            stat1_value=len(bundles),
            stat2_value=f"{average:.2f}x" if average is not None else "n/a",
        )
        log(f"Technician read price action on {len(bundles)} names")
        pace()

        # ---- Fundamentalist ---------------------------------------------- #
        set_agent("fundamentalist", status="working", stat1_value=0, stat2_value="—")
        upsides, covered = [], 0
        for bundle in bundles:
            analyst = bundle.get("analyst") or {}
            if analyst.get("num_analysts") or analyst.get("target_mean") is not None:
                covered += 1
            upsides.append(analyst.get("upside_pct"))
            set_agent("fundamentalist", stat1_value=covered)
        average = _mean(upsides)
        set_agent(
            "fundamentalist",
            status="done",
            stat1_value=covered,
            stat2_value=f"{average:+.1f}%" if average is not None else "n/a",
        )
        log(f"Fundamentalist found analyst coverage on {covered} of {len(bundles)}")
        pace()

        # ---- Newsdesk ----------------------------------------------------- #
        set_agent("newsdesk", status="working", stat1_value=0, stat2_value="—")
        headlines = tone = 0
        for bundle in bundles:
            news = bundle.get("news") or {}
            headlines += news.get("total") or 0
            tone += news.get("net_tone") or 0
            set_agent("newsdesk", stat1_value=headlines)
        set_agent("newsdesk", status="done", stat1_value=headlines, stat2_value=f"{tone:+d}")
        log(f"Newsdesk scored {headlines} headlines · net tone {tone:+d}")
        pace()

        # ---- Bull / Bear / Judge ------------------------------------------ #
        with LOCK:
            STATE["phase"] = "debating"
        for agent_id in ("bull", "bear", "judge"):
            set_agent(agent_id, status="working", stat1_value=0, stat2_value="—")

        bull_scores, bear_scores, verdict_rows, fired = [], [], [], []
        for index, bundle in enumerate(bundles, start=1):
            result = (
                llm.evaluate(bundle, provider)
                if provider != "deterministic"
                else scoring.evaluate(bundle)
            )
            reason = result.get("fallback_reason")
            if reason:
                log(f"{bundle['symbol']}: debate engine fell back ({reason})")

            verdict = result["verdict"]
            scores = result["scores"]
            bull_scores.append(scores["bull"]["score"])
            bear_scores.append(scores["bear"]["score"])

            price_block = bundle.get("price") or {}
            row = {
                "symbol": bundle["symbol"],
                "name": bundle.get("name") or bundle["symbol"],
                "cap_segment": bundle.get("cap_segment") or "unknown",
                "verdict": verdict["verdict"],
                "confidence": verdict["confidence"],
                "winner": verdict["winner"],
                "bull_score": verdict["bull_score"],
                "bear_score": verdict["bear_score"],
                "net": verdict["net"],
                "rationale": verdict["rationale"],
                "key_catalyst": verdict["key_catalyst"],
                "price": price_block.get("live"),
                "day_change_pct": price_block.get("day_change_pct"),
                "engine": result.get("engine", "deterministic"),
                "grounding_flags": result.get("grounding_flags") or [],
                "data_gaps": bundle.get("data_gaps") or [],
            }
            row["fired"] = (
                row["verdict"] == "BUY" and row["confidence"] >= CONFIDENCE_THRESHOLD
            )
            verdict_rows.append(row)
            if row["fired"]:
                fired.append(row)
            save_verdict(run_id, row)

            if row["grounding_flags"]:
                log(f"{row['symbol']}: verifier flagged {len(row['grounding_flags'])} untraceable figure(s)")

            with LOCK:
                STATE["verdicts"] = list(verdict_rows)
                STATE["kpis"]["buy_signals"] = len(fired)
                best = max(verdict_rows, key=lambda r: (r["verdict"] == "BUY", r["confidence"]))
                STATE["kpis"]["top_pick"] = {
                    "symbol": best["symbol"],
                    "confidence": best["confidence"],
                }

            set_agent("bull", stat1_value=index, stat2_value=f"{_mean(bull_scores):.0f}")
            set_agent("bear", stat1_value=index, stat2_value=f"{_mean(bear_scores):.0f}")
            set_agent("judge", stat1_value=index, stat2_value=len(fired))
            log(f"Judge: {row['symbol']} → {row['verdict']} ({row['confidence']}/10)")
            pace()

        for agent_id in ("bull", "bear", "judge"):
            set_agent(agent_id, status="done")

        # ---- Messenger ----------------------------------------------------- #
        with LOCK:
            STATE["phase"] = "signalling"
        set_agent("messenger", status="working", stat1_value=0, stat2_value=engine)

        sent = 0
        if not (TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID):
            log("Telegram is not configured - skipping delivery (set it in .env)")
        else:
            for row in fired:
                if telegram_send(buy_message(row)):
                    sent += 1
                    set_agent("messenger", stat1_value=sent)
                    log(f"Sent BUY signal for {row['symbol']} to Telegram")
            if telegram_send(
                summary_message(mode, engine, universe, len(bundles), fired)
            ):
                sent += 1
                log("Sent the daily summary to Telegram")
        with LOCK:
            STATE["telegram"]["sent"] = sent
        set_agent("messenger", status="done", stat1_value=sent, stat2_value=engine)

        top = STATE["kpis"]["top_pick"]
        close_run(
            run_id,
            universe=universe,
            shortlisted=len(bundles),
            buy_signals=len(fired),
            messages_sent=sent,
            top_symbol=top["symbol"],
            top_confidence=top["confidence"],
        )
        log(f"Run complete · {len(fired)} BUY signal(s) · {sent} Telegram message(s)")

    except Exception as exc:  # noqa: BLE001 - the dashboard must never hang
        log(f"Run stopped: {type(exc).__name__}: {scrub(exc)}"[:200])
        close_run(run_id, universe=STATE["kpis"]["universe"], shortlisted=STATE["kpis"]["in_debate"],
                  buy_signals=STATE["kpis"]["buy_signals"], messages_sent=STATE["telegram"]["sent"],
                  top_symbol=STATE["kpis"]["top_pick"]["symbol"],
                  top_confidence=STATE["kpis"]["top_pick"]["confidence"])
    finally:
        with LOCK:
            STATE["running"] = False
            STATE["phase"] = "done"
            STATE["finished_at"] = datetime.now(IST).isoformat(timespec="seconds")
            for agent in STATE["agents"]:
                if agent["status"] == "working":
                    agent["status"] = "done"


# --------------------------------------------------------------------------- #
# routes
# --------------------------------------------------------------------------- #
app = Flask(__name__, static_folder=None)


@app.get("/")
def dashboard():
    return send_from_directory(HERE, "dashboard.html")


@app.post("/start")
def start():
    with LOCK:
        if STATE["running"]:
            return jsonify({"ok": False, "error": "a run is already in progress"}), 409

    payload = request.get_json(silent=True) or {}
    mode = payload.get("mode") or "demo"
    if mode not in ("demo", "live"):
        return jsonify({"ok": False, "error": "mode must be demo or live"}), 400

    threading.Thread(target=run_cycle, args=(mode,), daemon=True).start()
    return jsonify({"ok": True, "mode": mode})


@app.get("/status")
def status():
    with LOCK:
        return jsonify(json.loads(json.dumps(STATE)))


@app.get("/config")
def config():
    provider = llm.detect_provider()
    return jsonify(
        {
            "brand": BRAND,
            "engine": llm.engine_label(provider),
            "provider": provider,
            "claude_cli_detected": bool(llm.claude_cli_path()),
            "anthropic_key_present": bool(os.environ.get("ANTHROPIC_API_KEY")),
            "openai_key_present": bool(os.environ.get("OPENAI_API_KEY")),
            "telegram_configured": bool(TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID),
            "confidence_threshold": CONFIDENCE_THRESHOLD,
            "shortlist_per_bucket": SHORTLIST_PER_BUCKET,
            "agent_delay": AGENT_DELAY,
            "agents": len(AGENTS),
            "port": PORT,
        }
    )


if __name__ == "__main__":
    init_db()
    provider = llm.detect_provider()
    print(f"\n  {BRAND} · Indian stock analysis · {len(AGENTS)} agents on duty")
    print(f"  engine   : {llm.engine_label(provider)}")
    print(f"  telegram : {'configured' if TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID else 'not configured (see .env.example)'}")
    print(f"  dashboard: http://127.0.0.1:{PORT}\n")
    app.run(host="127.0.0.1", port=PORT, debug=False, threaded=True)
