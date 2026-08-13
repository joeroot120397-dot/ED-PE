# Dalal Desk — an agent panel for Indian stocks

A local, one-click dashboard that runs a panel of named agents over NSE-listed
stocks, has an LLM argue each pick out loud, and pushes the BUY signals to your
Telegram.

Everything runs on your machine. There is no cloud backend, no account, and no
build step — one Flask process and one self-contained HTML file.

**No orders are ever placed. This is analysis only, not investment advice.**

---

## Run it

```bash
pip install -r requirements.txt
python app.py
```

Open <http://127.0.0.1:5000>, leave the dropdown on **Demo**, and press
**Start agents**. The panel wakes up in pipeline order and the verdict feed
fills in as the Judge rules on each stock.

Use **Live** during market hours — NSE trades Mon–Fri, 09:15–15:30 IST.

### Give it a brain (optional)

The debate engine auto-detects a provider, in this order:

| Priority | Provider | What it needs |
|---|---|---|
| 1 | `claude_code` | the `claude` CLI on your PATH — **no API key, no per-call billing** |
| 2 | `anthropic` | `ANTHROPIC_API_KEY` in `.env` |
| 3 | `openai` | `OPENAI_API_KEY` in `.env` |
| — | `deterministic` | nothing at all; this is the fallback |

The cheapest route by far is the first one: install Claude Code, run `claude`,
and `/login` with your Claude Pro or Max plan. The app shells out to the CLI and
the debates run against your existing subscription.

Set `LLM_PROVIDER=claude_code|anthropic|openai|deterministic` to force one.

**Nothing here is required.** With no key, no login and no network, the
deterministic engine takes over and the run completes exactly the same way —
you just get rule-based scores instead of an argued debate.

### Wire up Telegram

1. Message [@BotFather](https://t.me/BotFather) → `/newbot` → copy the token.
2. Message [@userinfobot](https://t.me/userinfobot) → copy your numeric chat id.
3. `cp .env.example .env` and paste both in.
4. Send your bot any message once, so it is allowed to message you back.

When a run finishes, the app posts one message per fired BUY plus a daily
summary. Without Telegram configured the run still completes — the Messenger
agent simply reports that delivery was skipped.

---

## What the agents do

| Agent | Role | Stat 1 | Stat 2 |
|---|---|---|---|
| 🔭 Scout | screens the stock universe for movers | Scanned | Shortlisted |
| 📈 Technician | reads price action, RVOL & trend | Analyzed | Avg RVOL |
| 🏛️ Fundamentalist | weighs valuation & analyst targets | Covered | Avg upside |
| 📰 Newsdesk | pulls live news & scores sentiment | Headlines | Net tone |
| 🐂 Bull | argues the case to buy | Cases | Avg score |
| 🐻 Bear | argues the case against | Cases | Avg score |
| ⚖️ Judge | weighs the debate, issues verdict + confidence | Verdicts | Buy |
| ✈️ Messenger | sends signals to Telegram | Sent | Engine |

A stock fires a signal when the verdict is **BUY** *and* confidence is at or
above `CONFIDENCE_THRESHOLD` (default 7).

---

## The two data modes

**demo** loads pre-built evidence bundles from `demo_data/*.json`, so the whole
thing runs offline. One bundle (`KIRLOSENG`) deliberately has no analyst
coverage and no headlines — it exercises the missing-data path end to end.

**live** pulls each ticker in `universe.json` through yfinance (the `.NS`
suffix is added for you): about a month of daily OHLC, the `.info` block, and
the news feed. Each cap bucket is screened by day-change and the top
`SHORTLIST_PER_BUCKET` (default 4) go through to the debate.

`universe.json` is yours to edit — three buckets, plain NSE symbols:

```json
{ "large": ["RELIANCE", "..."], "mid": ["PERSISTENT", "..."], "small": ["..."] }
```

### One evidence bundle per stock

Both modes emit the **same** normalized dict, which is the only thing the
scoring engines ever see:

```
symbol, name, cap_segment, sector
price       { live, day_open, day_high, day_low, prev_close, day_change_pct, volume }
range_52w   { high, low, pct_from_high, position_pct }
technicals  { rvol, price_vs_sma_pct, sma_window, sma_slope_pct, window_return_pct,
              swing_high, swing_low, day_range_position_pct, trend }
analyst     { consensus, num_analysts, buy_pct, hold_pct, sell_pct,
              target_mean, target_low, target_high, upside_pct }
news        { total, positive, negative, neutral, net_tone, recent[] }
data_gaps[] coverage_note
```

Two rules hold everywhere: **a value that can't be computed is `null`, never
guessed**, and every `null` is also named in `data_gaps`.

This feed carries no raw fundamental ratios — no P/E, ROE, margins or debt.
That absence is stated in `coverage_note` and passed to the model, so the
panel says "data unavailable" instead of inventing a multiple.

---

## The two engines

Both satisfy one interface:

```python
evaluate(evidence) -> {"scores": {agent: {"score", "reasons"}},
                       "verdict": {"winner", "verdict", "confidence", "rationale",
                                   "key_catalyst", "bull_score", "bear_score", "net"}}
```

**LLM debate** (`llm.py`, preferred) makes one combined call per stock: a
six-seat panel returns each seat's 0–100 conviction plus a ≤25-word point, and
the Judge returns the verdict, confidence and catalyst.

**Deterministic rules** (`scoring.py`) always work — no LLM, no key, no
network. The Bull scores volume expansion, breakouts, trend, strong closes,
analyst headroom and positive news; the Bear scores thin volume, proximity to
52-week lows, downtrend, absent headroom, weak conviction and negative news.
The Judge takes `net = bull − bear`:

* **BUY** when `net ≥ 25` *and* there is leadership (52w position ≥ 60 or RVOL ≥ 3)
* **AVOID** when `net ≤ −15`
* **WATCH** otherwise

Confidence is `clamp(round(4 + net/15), 1, 10)`, forced to ≥ 7 for a BUY and
≤ 6 for anything else.

**The two engines mean different things by "confidence."** The deterministic
Judge derives it from the net score, so it is pinned to the verdict by that
forcing rule. The LLM panel states its own conviction and it passes through
untouched — which is why you will see a WATCH at 8/10 (the panel is *sure* it
is a WATCH) sitting next to one at 6. Pinning the model's number the same way
collapsed almost every non-BUY row to exactly 6 and threw the information
away. Firing is unaffected either way: a signal needs verdict BUY **and**
confidence at or above `CONFIDENCE_THRESHOLD`.

### The grounding rule

Every figure an agent cites must exist in the evidence bundle. `llm.py` ships a
verifier that re-reads the model's prose, pulls out every number, and flags any
that can't be traced back to the bundle. Flagged verdicts still appear — with a
warning on the row and the flags stored in SQLite — so a hallucinated number is
visible rather than silent.

The verifier is tuned to avoid crying wolf. It allows honest rounding (a
bundle's `-42.12` may be cited as "42%"), reads `380-700` as a range rather
than as `-700`, and ignores three things that aren't claims about the stock:
the phrase "52-week", the `X/10` confidence, and the panel's own conviction
scores (a Judge writing "Bull case leads 78-68" is quoting the debate).

It earns its keep. On a real run it caught the model citing an `11.2%`
downside for RELIANCE — a figure that appears nowhere in that stock's bundle,
though it is PERSISTENT's window return.

**It is deliberately literal, and that has a cost.** A figure the model
*derived* correctly from two evidence numbers — "15.3% downside to the
52-week low", say — is also flagged, because 15.3 is not itself in the
bundle. Widening the check to accept derived ratios would mean admitting
every pairwise combination of ~40 numbers, which would make almost any
two-digit figure "traceable" and would have let the RELIANCE hallucination
through. A flag is a prompt to look, not a verdict: hover the row to see
exactly which figures tripped it.

---

## Configuration

All optional except the Telegram pair. See `.env.example`.

| Variable | Default | Meaning |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | — | from @BotFather |
| `TELEGRAM_CHAT_ID` | — | from @userinfobot |
| `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` | — | only if you aren't using the CLI |
| `LLM_PROVIDER` | auto-detect | force one provider |
| `CLAUDE_CLI_MODEL` | `haiku` | `haiku` or `sonnet` |
| `ANTHROPIC_MODEL` | `claude-opus-5` | Messages API model |
| `OPENAI_MODEL` | `gpt-4o-mini` | Chat Completions model |
| `BRAND` | `Dalal Desk` | header name |
| `CONFIDENCE_THRESHOLD` | `7` | minimum confidence to fire a signal |
| `AGENT_DELAY` | `0.7` | seconds between pipeline steps (visual pacing) |
| `SHORTLIST_PER_BUCKET` | `4` | stocks per cap bucket sent to debate |
| `PORT` | `5000` | server port |

The bot token is scrubbed from every log line, every UI string and every
database row — including the Telegram API's own error bodies, which echo the
URL back at you.

---

## Files

```
app.py            server, state machine, Telegram sender, SQLite audit
scoring.py        deterministic agents + Judge
llm.py            LLM debate, provider detection, grounding verifier, fallback
data_sources.py   demo loader, yfinance adapter, evidence builder
dashboard.html    the whole UI, inline CSS/JS, no libraries
universe.json     editable tickers per cap bucket
demo_data/*.json  evidence bundles for the offline demo
requirements.txt  flask, requests, yfinance
audit.db          created on first run (gitignored)
```

### Routes

| Route | Purpose |
|---|---|
| `GET /` | the dashboard |
| `POST /start` | `{"mode": "demo"\|"live"}` — starts a run, 409 if one is going |
| `GET /status` | the entire state as JSON (the page polls this ~2×/sec) |
| `GET /config` | resolved config and which providers were detected |

### Audit trail

Every run and every verdict lands in `audit.db`:

```bash
sqlite3 audit.db "SELECT symbol, verdict, confidence, fired FROM verdicts ORDER BY id DESC LIMIT 10;"
```

The `verdicts` table also stores the bull/bear scores, the rationale, the
engine that produced it, the grounding flags and the data gaps.

---

## Swapping the data feed

`data_sources.py` is the only file that knows where numbers come from.
yfinance is there for portability, not fidelity — if you have a broker API, a
paid feed or an MCP connector, replace that module and keep the evidence-bundle
shape identical. Neither scoring engine changes.

---

## Notes and limits

* yfinance is unofficial, rate-limited and occasionally wrong. It is fine for
  a dashboard and unfit for anything with money behind it.
* News sentiment is a transparent keyword lexicon, not a trained classifier.
* The demo bundles are frozen snapshots shaped like real NSE sessions — they
  are there to exercise the pipeline offline, not to describe today's market.
* This tool analyses. It never places an order, and nothing it prints is
  investment advice.
