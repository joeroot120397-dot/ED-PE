"""
scoring.py
----------
The deterministic engine. No LLM, no API key, no network - this must always
work, and it is what the app falls back to when the debate engine is
unavailable or errors out.

Contract (shared with llm.py):

    evaluate(evidence) -> {
        "scores": {agent_id: {"score": 0-100, "reasons": [str, ...]}},
        "verdict": {
            "winner": "Bull" | "Bear",
            "verdict": "BUY" | "WATCH" | "AVOID",
            "confidence": 1-10,
            "rationale": str,
            "key_catalyst": str,
            "bull_score": int, "bear_score": int, "net": int,
        },
        "engine": "deterministic",
    }

Every reason string cites only figures that exist in the evidence bundle. A
missing value produces no reason at all (and is already named in data_gaps),
so the engine never invents a number.
"""

from __future__ import annotations

BUY_NET = 25          # net score needed for a BUY
AVOID_NET = -15       # net score at or below which we AVOID
LEADER_POSITION = 60  # 52w position that counts as leadership
LEADER_RVOL = 3.0     # or this much relative volume


def _get(evidence, section, key):
    block = evidence.get(section) or {}
    return block.get(key)


def _clamp(value, low, high):
    return max(low, min(high, value))


# --------------------------------------------------------------------------- #
# the bull seat
# --------------------------------------------------------------------------- #
def score_bull(evidence):
    score, reasons = 0, []

    rvol = _get(evidence, "technicals", "rvol")
    if rvol is not None and rvol > 1:
        points = int(_clamp((rvol - 1) * 12, 0, 20))  # capped contribution
        if points:
            score += points
            reasons.append(f"RVOL {rvol} - volume running above its own average")

    position = _get(evidence, "range_52w", "position_pct")
    if position is not None:
        if position >= 85:
            score += 20
            reasons.append(f"Breakout zone: {position}% of the 52-week range")
        elif position >= 60:
            score += 10
            reasons.append(f"Upper half of the 52-week range at {position}%")

    vs_sma = _get(evidence, "technicals", "price_vs_sma_pct")
    slope = _get(evidence, "technicals", "sma_slope_pct")
    if vs_sma is not None and vs_sma > 0:
        score += 12 if (slope is None or slope > 0) else 6
        window = _get(evidence, "technicals", "sma_window") or 20
        reasons.append(f"Trading {vs_sma}% above the {window}-day SMA")

    close_pos = _get(evidence, "technicals", "day_range_position_pct")
    if close_pos is not None and close_pos >= 70:
        score += 8
        reasons.append(f"Closing strong - {close_pos}% up the day's range")

    upside = _get(evidence, "analyst", "upside_pct")
    if upside is not None and upside >= 10:
        score += 15
        reasons.append(f"Analyst mean target implies {upside}% upside")

    buy_pct = _get(evidence, "analyst", "buy_pct")
    if buy_pct is not None and buy_pct >= 80:
        score += 12
        num = _get(evidence, "analyst", "num_analysts")
        tail = f" across {num} analysts" if num else ""
        reasons.append(f"{buy_pct}% of coverage is a buy{tail}")

    net_tone = _get(evidence, "news", "net_tone")
    if net_tone is not None and net_tone > 0:
        score += int(_clamp(net_tone * 4, 0, 10))
        reasons.append(f"Headline tone net +{net_tone} over the recent feed")

    window_return = _get(evidence, "technicals", "window_return_pct")
    if window_return is not None and window_return > 0:
        score += int(_clamp(window_return, 0, 10))
        reasons.append(f"Up {window_return}% over the lookback window")

    if not reasons:
        reasons.append("No constructive signal in the available evidence")
    return {"score": int(_clamp(score, 0, 100)), "reasons": reasons}


# --------------------------------------------------------------------------- #
# the bear seat
# --------------------------------------------------------------------------- #
def score_bear(evidence):
    score, reasons = 0, []

    rvol = _get(evidence, "technicals", "rvol")
    if rvol is not None and rvol < 1:
        score += 12
        reasons.append(f"RVOL {rvol} - move is running on thin participation")

    position = _get(evidence, "range_52w", "position_pct")
    if position is not None and position < 30:
        score += 18
        reasons.append(f"Only {position}% up the 52-week range - near the lows")

    vs_sma = _get(evidence, "technicals", "price_vs_sma_pct")
    trend = _get(evidence, "technicals", "trend")
    if vs_sma is not None and vs_sma < 0:
        score += 14
        window = _get(evidence, "technicals", "sma_window") or 20
        reasons.append(f"{abs(vs_sma)}% below the {window}-day SMA")
    if trend == "down":
        score += 8
        reasons.append("Trend reads down on the daily series")

    upside = _get(evidence, "analyst", "upside_pct")
    if upside is not None and upside <= 0:
        score += 15
        reasons.append(f"Price is at or through the analyst mean target ({upside}%)")

    buy_pct = _get(evidence, "analyst", "buy_pct")
    if buy_pct is not None and buy_pct < 55:
        score += 10
        reasons.append(f"Weak conviction on the street - {buy_pct}% buy")

    pct_from_high = _get(evidence, "range_52w", "pct_from_high")
    if pct_from_high is not None and pct_from_high <= -20:
        score += 12
        reasons.append(f"{abs(pct_from_high)}% below the 52-week high")

    sell_pct = _get(evidence, "analyst", "sell_pct")
    if sell_pct is not None and sell_pct >= 15:
        score += 8
        reasons.append(f"{sell_pct}% of coverage is an outright sell")

    net_tone = _get(evidence, "news", "net_tone")
    if net_tone is not None and net_tone < 0:
        score += int(_clamp(abs(net_tone) * 5, 0, 12))
        reasons.append(f"Headline tone net {net_tone} over the recent feed")

    close_pos = _get(evidence, "technicals", "day_range_position_pct")
    if close_pos is not None and close_pos <= 30:
        score += 8
        reasons.append(f"Weak close - only {close_pos}% up the day's range")

    if not reasons:
        reasons.append("No material red flag in the available evidence")
    return {"score": int(_clamp(score, 0, 100)), "reasons": reasons}


# --------------------------------------------------------------------------- #
# supporting seats - technician / fundamentalist / newsdesk
# --------------------------------------------------------------------------- #
def score_technician(evidence):
    score, reasons = 50, []

    rvol = _get(evidence, "technicals", "rvol")
    if rvol is None:
        reasons.append("Relative volume: data unavailable")
    else:
        score += int(_clamp((rvol - 1) * 15, -15, 20))
        reasons.append(f"RVOL {rvol}")

    vs_sma = _get(evidence, "technicals", "price_vs_sma_pct")
    if vs_sma is None:
        reasons.append("Price vs SMA: data unavailable")
    else:
        score += int(_clamp(vs_sma * 1.5, -20, 20))
        reasons.append(f"{vs_sma}% vs SMA")

    trend = _get(evidence, "technicals", "trend")
    if trend:
        score += {"up": 10, "sideways": 0, "down": -12}.get(trend, 0)
        reasons.append(f"Trend {trend}")

    position = _get(evidence, "range_52w", "position_pct")
    if position is not None:
        score += int(_clamp((position - 50) / 5, -10, 10))
        reasons.append(f"52w position {position}%")

    return {"score": int(_clamp(score, 0, 100)), "reasons": reasons}


def score_fundamentalist(evidence):
    score, reasons = 50, []

    upside = _get(evidence, "analyst", "upside_pct")
    if upside is None:
        score -= 5
        reasons.append("Analyst target: data unavailable")
    else:
        score += int(_clamp(upside, -25, 25))
        reasons.append(f"{upside}% to mean target")

    buy_pct = _get(evidence, "analyst", "buy_pct")
    if buy_pct is None:
        reasons.append("Coverage split: data unavailable")
    else:
        score += int(_clamp((buy_pct - 55) / 3, -15, 15))
        reasons.append(f"{buy_pct}% buy")

    consensus = _get(evidence, "analyst", "consensus")
    if consensus:
        score += {"strong_buy": 10, "buy": 6, "hold": -4, "underperform": -10, "sell": -15}.get(
            str(consensus).lower(), 0
        )
        reasons.append(f"Consensus {consensus}")

    reasons.append("No P/E, ROE or margin data in this feed")
    return {"score": int(_clamp(score, 0, 100)), "reasons": reasons}


def score_newsdesk(evidence):
    total = _get(evidence, "news", "total")
    if not total:
        return {"score": 50, "reasons": ["No headlines in the feed - neutral by default"]}

    net_tone = _get(evidence, "news", "net_tone") or 0
    score = int(_clamp(50 + (net_tone / max(total, 1)) * 50, 0, 100))
    positive = _get(evidence, "news", "positive") or 0
    negative = _get(evidence, "news", "negative") or 0
    return {
        "score": score,
        "reasons": [f"{total} headlines: {positive} positive, {negative} negative, net {net_tone}"],
    }


# --------------------------------------------------------------------------- #
# the judge
# --------------------------------------------------------------------------- #
def judge(evidence, bull, bear):
    net = bull["score"] - bear["score"]
    position = _get(evidence, "range_52w", "position_pct")
    rvol = _get(evidence, "technicals", "rvol")
    leadership = (position is not None and position >= LEADER_POSITION) or (
        rvol is not None and rvol >= LEADER_RVOL
    )

    if net >= BUY_NET and leadership:
        verdict = "BUY"
    elif net <= AVOID_NET:
        verdict = "AVOID"
    else:
        verdict = "WATCH"

    confidence = int(_clamp(round(4 + net / 15), 1, 10))
    confidence = max(confidence, 7) if verdict == "BUY" else min(confidence, 6)

    winner = "Bull" if net >= 0 else "Bear"
    lead = (bull if winner == "Bull" else bear)["reasons"][0]

    if verdict == "BUY":
        rationale = (
            f"Bull case leads {bull['score']}-{bear['score']} with confirmation in place. {lead}."
        )
    elif verdict == "AVOID":
        rationale = f"Bear case leads {bear['score']}-{bull['score']}. {lead}."
    elif net >= BUY_NET:
        rationale = (
            f"Bull case leads {bull['score']}-{bear['score']} but leadership is unconfirmed - "
            "not in the upper 52-week range and volume is not decisive."
        )
    else:
        rationale = f"Neither side is decisive ({bull['score']} vs {bear['score']}). {lead}."

    return {
        "winner": winner,
        "verdict": verdict,
        "confidence": confidence,
        "rationale": rationale,
        "key_catalyst": lead,
        "bull_score": bull["score"],
        "bear_score": bear["score"],
        "net": net,
    }


# --------------------------------------------------------------------------- #
# public entry point
# --------------------------------------------------------------------------- #
def evaluate(evidence):
    bull = score_bull(evidence)
    bear = score_bear(evidence)
    scores = {
        "bull": bull,
        "bear": bear,
        "technician": score_technician(evidence),
        "fundamentalist": score_fundamentalist(evidence),
        "newsdesk": score_newsdesk(evidence),
    }
    return {"scores": scores, "verdict": judge(evidence, bull, bear), "engine": "deterministic"}
