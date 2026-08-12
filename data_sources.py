"""
data_sources.py
---------------
Two data modes, one output shape.

  demo : loads pre-built evidence bundles from demo_data/*.json (fully offline)
  live : pulls NSE data via yfinance (tickers get a .NS suffix)

Whichever mode runs, every stock comes out as the SAME normalized "evidence
bundle" dict. The scoring engine only ever sees that shape, so swapping this
module for a richer feed (broker API, paid data, MCP connector) needs no
changes anywhere else.

Rules that matter:
  * a value that cannot be computed is None (never guessed, never zero-filled)
  * every None is also named in bundle["data_gaps"]
  * this feed carries no raw fundamental ratios (P/E, ROE, margins...). That
    absence is declared up-front in bundle["coverage_note"] so agents do not
    pretend to have them.
"""

from __future__ import annotations

import glob
import json
import os
import statistics
from datetime import datetime, timedelta, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
DEMO_DIR = os.path.join(HERE, "demo_data")
UNIVERSE_FILE = os.path.join(HERE, "universe.json")

SMA_WINDOW = 20          # N-day SMA used for price_vs_sma_pct
SWING_WINDOW = 20        # lookback for swing high / low
IST = timezone(timedelta(hours=5, minutes=30))

COVERAGE_NOTE = (
    "Feed carries price/volume, 52-week range, analyst targets and headlines only. "
    "No raw fundamental ratios (P/E, ROE, margins, debt) are available in this "
    "evidence bundle - treat any such figure as data unavailable."
)

POSITIVE_WORDS = {
    "beat", "beats", "surge", "surges", "surged", "jump", "jumps", "jumped", "rally",
    "rallies", "gain", "gains", "gained", "record", "high", "profit", "profits",
    "growth", "grows", "upgrade", "upgraded", "outperform", "buy", "bullish", "strong",
    "wins", "win", "order", "orders", "expansion", "expands", "approval", "approved",
    "raise", "raises", "raised", "dividend", "bonus", "acquire", "acquires",
    "acquisition", "partnership", "launch", "launches", "positive", "boost", "boosts",
    "soars", "soar", "top", "tops", "rises", "rise", "recovery", "revival", "optimism",
}
NEGATIVE_WORDS = {
    "miss", "misses", "missed", "fall", "falls", "fell", "drop", "drops", "dropped",
    "plunge", "plunges", "plunged", "slump", "slumps", "loss", "losses", "decline",
    "declines", "declined", "downgrade", "downgraded", "underperform", "sell",
    "bearish", "weak", "weakness", "cut", "cuts", "probe", "fraud", "penalty", "fine",
    "lawsuit", "recall", "resign", "resigns", "resigned", "exit", "exits", "warn",
    "warns", "warning", "concern", "concerns", "risk", "risks", "delay", "delays",
    "halt", "halts", "slide", "slides", "sinks", "sink", "tumble", "tumbles",
    "crash", "default", "downside", "pressure", "layoff", "layoffs",
}


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
def now_ist_str() -> str:
    return datetime.now(IST).strftime("%d %b %Y, %H:%M")


def _num(value):
    """Coerce to float, or None. Rejects NaN/inf and non-numeric junk."""
    if value is None:
        return None
    try:
        out = float(value)
    except (TypeError, ValueError):
        return None
    if out != out or out in (float("inf"), float("-inf")):
        return None
    return out


def _pct(part, whole):
    part, whole = _num(part), _num(whole)
    if part is None or whole in (None, 0):
        return None
    return round((part / whole) * 100.0, 2)


def _round(value, digits=2):
    value = _num(value)
    return None if value is None else round(value, digits)


def load_universe() -> dict:
    """Read universe.json -> {"large": [...], "mid": [...], "small": [...]}."""
    with open(UNIVERSE_FILE, "r", encoding="utf-8") as handle:
        raw = json.load(handle)
    return {
        bucket: [str(sym).strip().upper() for sym in raw.get(bucket, []) if str(sym).strip()]
        for bucket in ("large", "mid", "small")
    }


def score_headline(title: str) -> str:
    """Crude but transparent lexicon sentiment: positive / negative / neutral."""
    words = {w.strip(".,!?:;'\"()[]").lower() for w in (title or "").split()}
    pos = len(words & POSITIVE_WORDS)
    neg = len(words & NEGATIVE_WORDS)
    if pos > neg:
        return "positive"
    if neg > pos:
        return "negative"
    return "neutral"


def _finalize(bundle: dict) -> dict:
    """Walk the bundle, record every None leaf in data_gaps, stamp the note."""
    gaps = []

    def walk(node, path):
        if isinstance(node, dict):
            for key, value in node.items():
                walk(value, f"{path}.{key}" if path else key)
        elif node is None:
            gaps.append(path)

    for section in ("price", "range_52w", "technicals", "analyst", "news"):
        walk(bundle.get(section), section)
    for key in ("name", "sector", "cap_segment"):
        if bundle.get(key) is None:
            gaps.append(key)

    bundle["data_gaps"] = sorted(set(gaps + list(bundle.get("data_gaps") or [])))
    bundle["coverage_note"] = COVERAGE_NOTE
    return bundle


# --------------------------------------------------------------------------- #
# demo mode
# --------------------------------------------------------------------------- #
def load_demo_bundles() -> list:
    bundles = []
    for path in sorted(glob.glob(os.path.join(DEMO_DIR, "*.json"))):
        try:
            with open(path, "r", encoding="utf-8") as handle:
                bundle = json.load(handle)
        except (OSError, ValueError):
            continue
        if isinstance(bundle, dict) and bundle.get("symbol"):
            bundles.append(_finalize(bundle))
    return bundles


# --------------------------------------------------------------------------- #
# live mode (yfinance)
# --------------------------------------------------------------------------- #
def _import_yfinance():
    try:
        import yfinance  # noqa: WPS433 (deliberate lazy import)
    except ImportError as exc:  # pragma: no cover - environment dependent
        raise RuntimeError(
            "live mode needs yfinance - run `pip install -r requirements.txt` "
            "or switch the dropdown back to Demo"
        ) from exc
    return yfinance


def _analyst_split(ticker):
    """buy/hold/sell % from the recommendations grid. None when unavailable."""
    try:
        grid = ticker.recommendations
    except Exception:
        return None, None, None
    if grid is None or getattr(grid, "empty", True):
        return None, None, None
    try:
        row = grid.iloc[0]
        strong_buy = _num(row.get("strongBuy")) or 0
        buy = _num(row.get("buy")) or 0
        hold = _num(row.get("hold")) or 0
        sell = (_num(row.get("sell")) or 0) + (_num(row.get("strongSell")) or 0)
        total = strong_buy + buy + hold + sell
        if total <= 0:
            return None, None, None
        return (
            round((strong_buy + buy) / total * 100, 1),
            round(hold / total * 100, 1),
            round(sell / total * 100, 1),
        )
    except Exception:
        return None, None, None


def _news_block(ticker, limit=6):
    try:
        raw = ticker.news or []
    except Exception:
        raw = []

    recent, counts = [], {"positive": 0, "negative": 0, "neutral": 0}
    for item in raw[: max(limit, 0)]:
        if not isinstance(item, dict):
            continue
        # yfinance has shipped two shapes: flat, and nested under "content".
        content = item.get("content") if isinstance(item.get("content"), dict) else item
        title = content.get("title") or item.get("title")
        if not title:
            continue
        publisher = (
            content.get("provider", {}).get("displayName")
            if isinstance(content.get("provider"), dict)
            else content.get("publisher") or item.get("publisher")
        )
        stamp = content.get("pubDate") or item.get("providerPublishTime")
        if isinstance(stamp, (int, float)):
            stamp = datetime.fromtimestamp(stamp, IST).strftime("%d %b %H:%M")
        sentiment = score_headline(title)
        counts[sentiment] += 1
        recent.append(
            {
                "title": title,
                "publisher": publisher or None,
                "published": stamp or None,
                "sentiment": sentiment,
            }
        )

    if not recent:
        return {
            "total": 0,
            "positive": 0,
            "negative": 0,
            "neutral": 0,
            "net_tone": 0,
            "recent": [],
        }
    return {
        "total": len(recent),
        "positive": counts["positive"],
        "negative": counts["negative"],
        "neutral": counts["neutral"],
        "net_tone": counts["positive"] - counts["negative"],
        "recent": recent,
    }


def _technicals(closes, volumes, highs, lows, price, day_high, day_low):
    tech = {
        "rvol": None,
        "price_vs_sma_pct": None,
        "sma_window": SMA_WINDOW,
        "window_return_pct": None,
        "swing_high": None,
        "swing_low": None,
        "day_range_position_pct": None,
        "trend": None,
    }

    if volumes and len(volumes) >= 2:
        prior = [v for v in volumes[:-1] if v is not None and v > 0]
        today = volumes[-1]
        if prior and today:
            avg = statistics.fmean(prior)
            tech["rvol"] = _round(today / avg, 2) if avg else None

    sma = None
    if closes and len(closes) >= 5:
        window = closes[-min(SMA_WINDOW, len(closes)):]
        sma = statistics.fmean(window)
        if price is not None and sma:
            tech["price_vs_sma_pct"] = _round((price - sma) / sma * 100, 2)
        first = closes[0]
        if first:
            tech["window_return_pct"] = _round((closes[-1] - first) / first * 100, 2)

    if highs:
        tech["swing_high"] = _round(max(highs[-min(SWING_WINDOW, len(highs)):]))
    if lows:
        tech["swing_low"] = _round(min(lows[-min(SWING_WINDOW, len(lows)):]))

    if None not in (price, day_high, day_low) and day_high > day_low:
        tech["day_range_position_pct"] = _round((price - day_low) / (day_high - day_low) * 100, 1)

    # slope of the SMA: compare it against the same SMA five sessions back
    slope = None
    if closes and len(closes) >= SMA_WINDOW + 5:
        past = statistics.fmean(closes[-(SMA_WINDOW + 5):-5])
        if past:
            slope = (sma - past) / past * 100 if sma else None
    tech["sma_slope_pct"] = _round(slope, 2)

    delta = tech["price_vs_sma_pct"]
    if delta is None:
        tech["trend"] = None
    elif delta > 1.5 and (slope is None or slope >= 0):
        tech["trend"] = "up"
    elif delta < -1.5 and (slope is None or slope <= 0):
        tech["trend"] = "down"
    else:
        tech["trend"] = "sideways"
    return tech


def build_live_bundle(symbol: str, cap_segment: str) -> dict:
    """One NSE symbol -> one normalized evidence bundle."""
    yfinance = _import_yfinance()
    ticker = yfinance.Ticker(f"{symbol}.NS")

    try:
        info = ticker.info or {}
    except Exception:
        info = {}

    closes = volumes = highs = lows = []
    try:
        history = ticker.history(period="1mo", interval="1d")
        if history is not None and not history.empty:
            closes = [_num(v) for v in history["Close"].tolist()]
            volumes = [_num(v) for v in history["Volume"].tolist()]
            highs = [_num(v) for v in history["High"].tolist()]
            lows = [_num(v) for v in history["Low"].tolist()]
            closes = [c for c in closes if c is not None]
            highs = [h for h in highs if h is not None]
            lows = [low for low in lows if low is not None]
    except Exception:
        pass

    price = _num(info.get("currentPrice")) or _num(info.get("regularMarketPrice"))
    if price is None and closes:
        price = closes[-1]
    prev_close = _num(info.get("previousClose")) or _num(info.get("regularMarketPreviousClose"))
    day_open = _num(info.get("open")) or _num(info.get("regularMarketOpen"))
    day_high = _num(info.get("dayHigh")) or _num(info.get("regularMarketDayHigh"))
    day_low = _num(info.get("dayLow")) or _num(info.get("regularMarketDayLow"))
    volume = _num(info.get("volume")) or _num(info.get("regularMarketVolume"))
    if volume is None and volumes:
        volume = volumes[-1]

    day_change_pct = None
    if price is not None and prev_close:
        day_change_pct = _round((price - prev_close) / prev_close * 100, 2)

    high_52 = _num(info.get("fiftyTwoWeekHigh"))
    low_52 = _num(info.get("fiftyTwoWeekLow"))
    if high_52 is None and highs:
        high_52 = max(highs)
    if low_52 is None and lows:
        low_52 = min(lows)

    pct_from_high = position_pct = None
    if price is not None and high_52:
        pct_from_high = _round((price - high_52) / high_52 * 100, 2)
    if price is not None and high_52 is not None and low_52 is not None and high_52 > low_52:
        position_pct = _round((price - low_52) / (high_52 - low_52) * 100, 1)

    if price is None:
        # No price at all means the fetch failed, not that the stock is quiet.
        # Raising here keeps an empty shell out of the evidence pool.
        raise RuntimeError(f"{symbol}: no price returned")

    target_mean = _num(info.get("targetMeanPrice"))
    upside_pct = None
    if target_mean is not None and price:
        upside_pct = _round((target_mean - price) / price * 100, 2)
    buy_pct, hold_pct, sell_pct = _analyst_split(ticker)

    bundle = {
        "symbol": symbol,
        "name": info.get("longName") or info.get("shortName") or None,
        "cap_segment": cap_segment,
        "sector": info.get("sector") or None,
        "currency": info.get("currency") or "INR",
        "as_of": now_ist_str(),
        "source": "yfinance",
        "price": {
            "live": _round(price),
            "day_open": _round(day_open),
            "day_high": _round(day_high),
            "day_low": _round(day_low),
            "prev_close": _round(prev_close),
            "day_change_pct": day_change_pct,
            "volume": int(volume) if volume is not None else None,
        },
        "range_52w": {
            "high": _round(high_52),
            "low": _round(low_52),
            "pct_from_high": pct_from_high,
            "position_pct": position_pct,
        },
        "technicals": _technicals(closes, volumes, highs, lows, price, day_high, day_low),
        "analyst": {
            "consensus": info.get("recommendationKey") or None,
            "num_analysts": int(_num(info.get("numberOfAnalystOpinions")) or 0) or None,
            "buy_pct": buy_pct,
            "hold_pct": hold_pct,
            "sell_pct": sell_pct,
            "target_mean": _round(target_mean),
            "target_low": _round(info.get("targetLowPrice")),
            "target_high": _round(info.get("targetHighPrice")),
            "upside_pct": upside_pct,
        },
        "news": _news_block(ticker),
    }
    return _finalize(bundle)


# --------------------------------------------------------------------------- #
# scan orchestration
# --------------------------------------------------------------------------- #
def _shortlist(bundles, per_bucket):
    """Top `per_bucket` movers of each cap bucket, ranked by day change."""
    picked = []
    for bucket in ("large", "mid", "small"):
        in_bucket = [b for b in bundles if b.get("cap_segment") == bucket]
        in_bucket.sort(
            key=lambda b: abs(b.get("price", {}).get("day_change_pct") or 0), reverse=True
        )
        picked.extend(in_bucket[:per_bucket])
    return picked


def scan(mode="demo", shortlist_per_bucket=4, on_progress=None, on_warn=None):
    """
    Returns (universe_count, shortlisted_bundles).

    on_progress(done, total, symbol) fires as each symbol lands, so the Scout
    card can tick upward while the scan runs. on_warn(message) reports tickers
    that failed without sinking the run.
    """
    if mode == "demo":
        bundles = load_demo_bundles()
        total = len(bundles)
        if not bundles:
            raise RuntimeError(f"no demo bundles found in {DEMO_DIR}")
        for index, bundle in enumerate(bundles, start=1):
            if on_progress:
                on_progress(index, total, bundle["symbol"])
        return total, _shortlist(bundles, shortlist_per_bucket)

    _import_yfinance()  # fail fast and legibly if the dependency is missing
    universe = load_universe()
    symbols = [(sym, bucket) for bucket, syms in universe.items() for sym in syms]
    bundles, failed, total = [], [], len(symbols)

    for index, (symbol, bucket) in enumerate(symbols, start=1):
        try:
            bundles.append(build_live_bundle(symbol, bucket))
        except Exception:
            failed.append(symbol)  # one bad ticker never sinks the run
        if on_progress:
            on_progress(index, total, symbol)

    if failed and on_warn:
        on_warn(f"{len(failed)} ticker(s) returned nothing: {', '.join(failed[:8])}")
    if not bundles:
        raise RuntimeError(
            f"live mode fetched nothing - all {total} tickers failed. The network is "
            "likely blocked or yfinance is rate-limited. Switch to Demo mode."
        )
    return total, _shortlist(bundles, shortlist_per_bucket)
