#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

import MetaTrader5 as mt5

from analyze_multicurrency_score_scanner_2025 import BACKTEST, calc_stats
from analyze_nested_nwave_breakout_quality_router import PERIODS, RUNS, prefix
from analyze_nested_nwave_failure_decomposition import (
    RateCache,
    as_float,
    as_int,
    fx_bucket,
    pf_value,
    read_csv_rows,
    session_for_hour,
)


OUT_BASE = "ExpectedValue_MultiCurrency_ScoreScanner"
OUT_PREFIX = f"{OUT_BASE}_nested_nwave_router_decision_audit"

ROOT = Path(__file__).resolve().parents[1]
DEVLOG = ROOT / "docs" / "devlog" / "2026-06-15-nested-nwave-router-decision-audit.md"

PERIOD_ENDS = {
    "2025-02": datetime(2025, 2, 28, 23, 59, 59),
    "2025-08": datetime(2025, 8, 31, 23, 59, 59),
    "2025-10": datetime(2025, 10, 31, 23, 59, 59),
    "2026-Q1": datetime(2026, 3, 31, 23, 59, 59),
}

OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_summary.md",
    "audit": BACKTEST / f"{OUT_PREFIX}.csv",
    "by_decision": BACKTEST / f"{OUT_PREFIX}_by_decision.csv",
    "by_period": BACKTEST / f"{OUT_PREFIX}_by_period.csv",
    "by_quality_label": BACKTEST / f"{OUT_PREFIX}_by_quality_label.csv",
    "by_quality_reason": BACKTEST / f"{OUT_PREFIX}_by_quality_reason.csv",
    "removed_winners_2025_10": BACKTEST / f"{OUT_PREFIX}_2025_10_removed_winners.csv",
    "avoided_losers_2026_q1": BACKTEST / f"{OUT_PREFIX}_2026_q1_avoided_losers.csv",
    "context_seed": BACKTEST / f"{OUT_PREFIX}_context_quality_seed.md",
    "metrics": BACKTEST / f"{OUT_PREFIX}_metrics.json",
}


def parse_time(value: str) -> datetime:
    return datetime.strptime(value.strip(), "%Y.%m.%d %H:%M:%S")


def write_union_rows(path: Path, rows: list[dict[str, object]]) -> None:
    fields: list[str] = []
    for row in rows:
        for key in row:
            if key not in fields:
                fields.append(key)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def candidate_key(row: dict[str, str]) -> tuple[str, str, str, str, str, str]:
    return (
        row.get("time", ""),
        row.get("symbol", ""),
        row.get("direction", ""),
        row.get("entry_price", ""),
        row.get("sl", ""),
        row.get("tp", ""),
    )


def event_priority(event: str) -> int:
    return {
        "order_sent": 4,
        "order_blocked": 3,
        "blocked_candidate": 2,
        "final_entry_candidate": 1,
    }.get(event, 0)


def dedupe_router_candidates(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    selected: dict[tuple[str, str, str, str, str, str], dict[str, str]] = {}
    for row in rows:
        label = row.get("breakout_quality_label", "")
        if label not in {"strong_breakout", "weak_breakout", "dirty_breakout"}:
            continue
        event = row.get("event", "")
        if event not in {"blocked_candidate", "final_entry_candidate", "order_sent", "order_blocked"}:
            continue
        if as_float(row.get("entry_price")) <= 0 or as_float(row.get("sl")) <= 0 or as_float(row.get("tp")) <= 0:
            continue
        key = candidate_key(row)
        current = selected.get(key)
        if current is None or event_priority(event) > event_priority(current.get("event", "")):
            selected[key] = row
    return list(selected.values())


def router_decision(row: dict[str, str]) -> str:
    label = row.get("breakout_quality_label", "")
    event = row.get("event", "")
    fail = row.get("fail_reason", "")
    if label == "dirty_breakout":
        return "dirty_skipped"
    if label == "weak_breakout":
        return "weak_routed_to_retest"
    if label == "strong_breakout" and event == "order_sent":
        return "strong_ordered"
    if label == "strong_breakout":
        if fail == "spread_guard":
            return "strong_blocked_spread_guard"
        if fail == "existing_position":
            return "strong_blocked_existing_position"
        return "strong_not_ordered"
    return "other"


def order_calc_profit(symbol: str, direction: str, volume: float, entry: float, exit_price: float) -> float:
    if volume <= 0 or entry <= 0 or exit_price <= 0:
        return 0.0
    order_type = mt5.ORDER_TYPE_BUY if direction == "LONG" else mt5.ORDER_TYPE_SELL
    value = mt5.order_calc_profit(order_type, symbol, volume, entry, exit_price)
    if value is None:
        return 0.0
    return float(value)


def simulate_candidate(row: dict[str, str], cache: RateCache, period_end: datetime) -> dict[str, object]:
    symbol = row["symbol"]
    direction = row["direction"]
    open_time = parse_time(row["time"])
    entry = as_float(row.get("entry_price"))
    sl = as_float(row.get("sl"))
    tp = as_float(row.get("tp"))
    risk = abs(entry - sl)
    volume = as_float(row.get("volume"))
    sign = 1.0 if direction == "LONG" else -1.0
    rates = cache.get(symbol, open_time, period_end)
    trade_rates = [bar for bar in rates if bar["time"] >= open_time]

    max_fav = 0.0
    max_adv = 0.0
    reached = {0.5: 0, 1.0: 0, 1.5: 0, 2.0: 0, 3.0: 0}
    time_to = {0.5: "", 1.0: "", 1.5: "", 2.0: "", 3.0: ""}
    false_inside = 0
    false_inside_bars = ""
    neckline = as_float(row.get("neckline_price"))

    outcome = "open_at_period_end"
    exit_price = trade_rates[-1]["close"] if trade_rates else entry
    exit_time = period_end
    same_bar_ambiguous = 0
    bars_to_exit = ""

    for idx, bar in enumerate(trade_rates):
        if direction == "LONG":
            fav = max(0.0, bar["high"] - entry)
            adv = max(0.0, entry - bar["low"])
            tp_hit = bar["high"] >= tp
            sl_hit = bar["low"] <= sl
            inside = neckline > 0 and bar["close"] <= neckline
        else:
            fav = max(0.0, entry - bar["low"])
            adv = max(0.0, bar["high"] - entry)
            tp_hit = bar["low"] <= tp
            sl_hit = bar["high"] >= sl
            inside = neckline > 0 and bar["close"] >= neckline
        max_fav = max(max_fav, fav)
        max_adv = max(max_adv, adv)
        if risk > 0:
            fav_r = fav / risk
            for threshold in reached:
                if reached[threshold] == 0 and fav_r >= threshold:
                    reached[threshold] = 1
                    time_to[threshold] = round((bar["time"] - open_time).total_seconds() / 60.0, 1)
        if false_inside == 0 and idx <= 8 and inside:
            false_inside = 1
            false_inside_bars = idx
        if tp_hit and sl_hit:
            outcome = "same_bar_ambiguous_sl_conservative"
            exit_price = sl
            exit_time = bar["time"]
            same_bar_ambiguous = 1
            bars_to_exit = idx
            break
        if sl_hit:
            outcome = "sl_hit"
            exit_price = sl
            exit_time = bar["time"]
            bars_to_exit = idx
            break
        if tp_hit:
            outcome = "tp_hit"
            exit_price = tp
            exit_time = bar["time"]
            bars_to_exit = idx
            break

    result_r = (exit_price - entry) * sign / risk if risk > 0 else 0.0
    net_profit = order_calc_profit(symbol, direction, volume, entry, exit_price)
    return {
        "hypothetical_exit_time": exit_time.strftime("%Y.%m.%d %H:%M:%S") if isinstance(exit_time, datetime) else "",
        "hypothetical_exit_price": round(exit_price, 6),
        "hypothetical_outcome": outcome,
        "hypothetical_result_R": round(result_r, 3),
        "hypothetical_net_profit": round(net_profit, 2),
        "same_bar_ambiguous": same_bar_ambiguous,
        "bars_to_exit": bars_to_exit,
        "max_favorable_r": round(max_fav / risk, 3) if risk > 0 else 0.0,
        "max_adverse_r": round(max_adv / risk, 3) if risk > 0 else 0.0,
        "reached_0_5R": reached[0.5],
        "reached_1R": reached[1.0],
        "reached_1_5R": reached[1.5],
        "reached_2R": reached[2.0],
        "reached_3R": reached[3.0],
        "time_to_0_5R": time_to[0.5],
        "time_to_1R": time_to[1.0],
        "time_to_1_5R": time_to[1.5],
        "time_to_2R": time_to[2.0],
        "time_to_3R": time_to[3.0],
        "false_break_return_inside_neckline": false_inside,
        "false_break_return_bars": false_inside_bars,
    }


def build_audit_rows() -> list[dict[str, object]]:
    if not mt5.initialize():
        raise RuntimeError(f"MetaTrader5 initialize failed: {mt5.last_error()}")
    cache = RateCache()
    rows: list[dict[str, object]] = []
    try:
        for period in PERIODS:
            period_name = period["period"]
            period_end = PERIOD_ENDS[period_name]
            for run in [item for item in RUNS if item["branch"] == "breakout_quality_router"]:
                pfx = prefix(period[run["series_key"]], run["name"])
                signal_path = BACKTEST / f"{pfx}_nested_nwave_signal_diagnostics.csv"
                signal_rows = read_csv_rows(signal_path)
                for idx, candidate in enumerate(dedupe_router_candidates(signal_rows), start=1):
                    open_time = parse_time(candidate["time"])
                    decision = router_decision(candidate)
                    simulated = simulate_candidate(candidate, cache, period_end)
                    audit: dict[str, object] = {
                        "period": period_name,
                        "scenario": run["scenario"],
                        "run": run["run"],
                        "entry_selection_mode": run["entry_selection_mode"],
                        "candidate_index": idx,
                        "time": candidate["time"],
                        "month": open_time.strftime("%Y-%m"),
                        "hour": f"{open_time.hour:02d}",
                        "session": candidate.get("session") or session_for_hour(open_time.hour),
                        "symbol": candidate.get("symbol", ""),
                        "direction": candidate.get("direction", ""),
                        "fx_bucket": fx_bucket(candidate.get("symbol", "")),
                        "event": candidate.get("event", ""),
                        "router_decision": decision,
                        "breakout_quality_label": candidate.get("breakout_quality_label", ""),
                        "breakout_quality_reason": candidate.get("breakout_quality_reason", ""),
                        "fail_reason": candidate.get("fail_reason", ""),
                        "execution_block_reason": candidate.get("execution_block_reason", ""),
                        "label": candidate.get("label", ""),
                        "fib_zone": candidate.get("fib_zone", ""),
                        "neckline_break_label": candidate.get("neckline_break_label", ""),
                        "h4_trend_state": candidate.get("h4_trend_state", ""),
                        "h1_counter_trend_state": candidate.get("h1_counter_trend_state", ""),
                        "h4_fib_retracement_pct": as_float(candidate.get("h4_fib_retracement_pct")),
                        "entry_price": as_float(candidate.get("entry_price")),
                        "sl": as_float(candidate.get("sl")),
                        "tp": as_float(candidate.get("tp")),
                        "volume": as_float(candidate.get("volume")),
                        "risk_r": as_float(candidate.get("risk_r")),
                        "rr": as_float(candidate.get("rr")),
                        "sl_atr": as_float(candidate.get("sl_atr")),
                        "tp_atr": as_float(candidate.get("tp_atr")),
                        "neckline_price": as_float(candidate.get("neckline_price")),
                        "right_side_level": as_float(candidate.get("right_side_level")),
                        "distance_neckline_to_entry_atr": as_float(candidate.get("distance_neckline_to_entry_atr")),
                        "breakout_close_distance_from_neckline_atr": as_float(candidate.get("breakout_close_distance_from_neckline_atr")),
                        "breakout_body_ratio": as_float(candidate.get("breakout_body_ratio")),
                        "breakout_body_atr": as_float(candidate.get("breakout_body_atr")),
                        "breakout_range_atr": as_float(candidate.get("breakout_range_atr")),
                        "breakout_directional_wick_ratio": as_float(candidate.get("breakout_directional_wick_ratio")),
                        "breakout_close_position_directional": as_float(candidate.get("breakout_close_position_directional")),
                        "neckline_touch_count": as_int(candidate.get("neckline_touch_count")),
                    }
                    audit.update(simulated)
                    rows.append(audit)
    finally:
        mt5.shutdown()
    return rows


def stats_for_rows(rows: list[dict[str, object]]) -> dict[str, object]:
    synthetic = []
    base_time = datetime(2000, 1, 1)
    for idx, row in enumerate(rows):
        synthetic.append(
            {
                "net_profit": as_float(row.get("hypothetical_net_profit")),
                "open_time": base_time + timedelta(minutes=idx),
                "close_time": base_time + timedelta(minutes=idx + 1),
            }
        )
    return calc_stats(synthetic)


def aggregate(rows: list[dict[str, object]], group_fields: list[str]) -> list[dict[str, object]]:
    buckets: dict[tuple[str, ...], list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        buckets[tuple(str(row.get(field, "")) for field in group_fields)].append(row)
    output: list[dict[str, object]] = []
    for key, bucket in sorted(buckets.items()):
        stats = stats_for_rows(bucket)
        result = {field: value for field, value in zip(group_fields, key)}
        result.update(
            {
                "candidates": len(bucket),
                "hypothetical_wins": sum(1 for row in bucket if as_float(row.get("hypothetical_result_R")) > 0),
                "hypothetical_losses": sum(1 for row in bucket if as_float(row.get("hypothetical_result_R")) < 0),
                "hypothetical_win_rate": round(sum(1 for row in bucket if as_float(row.get("hypothetical_result_R")) > 0) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "hypothetical_net_profit": round(sum(as_float(row.get("hypothetical_net_profit")) for row in bucket), 2),
                "hypothetical_profit_factor": pf_value(stats),
                "hypothetical_expected_payoff": round(float(stats["expected_payoff"]), 2),
                "hypothetical_avg_R": round(sum(as_float(row.get("hypothetical_result_R")) for row in bucket) / len(bucket), 3) if bucket else 0.0,
                "avg_mfe_R": round(sum(as_float(row.get("max_favorable_r")) for row in bucket) / len(bucket), 3) if bucket else 0.0,
                "avg_mae_R": round(sum(as_float(row.get("max_adverse_r")) for row in bucket) / len(bucket), 3) if bucket else 0.0,
                "reached_0_5R_pct": round(sum(as_int(row.get("reached_0_5R")) for row in bucket) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "reached_1R_pct": round(sum(as_int(row.get("reached_1R")) for row in bucket) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "reached_2R_pct": round(sum(as_int(row.get("reached_2R")) for row in bucket) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "false_break_return_pct": round(sum(as_int(row.get("false_break_return_inside_neckline")) for row in bucket) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "same_bar_ambiguous": sum(as_int(row.get("same_bar_ambiguous")) for row in bucket),
                "fx_hypothetical_net": round(sum(as_float(row.get("hypothetical_net_profit")) for row in bucket if row.get("fx_bucket") == "FX"), 2),
                "xauusd_hypothetical_net": round(sum(as_float(row.get("hypothetical_net_profit")) for row in bucket if row.get("fx_bucket") == "XAUUSD"), 2),
                "long_hypothetical_net": round(sum(as_float(row.get("hypothetical_net_profit")) for row in bucket if row.get("direction") == "LONG"), 2),
                "short_hypothetical_net": round(sum(as_float(row.get("hypothetical_net_profit")) for row in bucket if row.get("direction") == "SHORT"), 2),
            }
        )
        output.append(result)
    return output


def top_rows(rows: list[dict[str, object]], predicate, reverse: bool, limit: int = 50) -> list[dict[str, object]]:
    selected = [row for row in rows if predicate(row)]
    selected.sort(key=lambda row: as_float(row.get("hypothetical_result_R")), reverse=reverse)
    return selected[:limit]


def row_value(rows: list[dict[str, object]], period: str, scenario_contains: str, decision: str) -> dict[str, object] | None:
    for row in rows:
        if row.get("period") == period and scenario_contains in str(row.get("scenario")) and row.get("router_decision") == decision:
            return row
    return None


def write_summary(rows: list[dict[str, object]], by_decision: list[dict[str, object]]) -> None:
    primary = [row for row in rows if row["entry_selection_mode"] == "ALL_SCORE_PASSING"]
    primary_by_decision = aggregate(primary, ["router_decision"])
    q1 = [row for row in primary if row["period"] == "2026-Q1"]
    oct_rows = [row for row in primary if row["period"] == "2025-10"]
    q1_avoided = [row for row in q1 if row["router_decision"] in {"dirty_skipped", "weak_routed_to_retest"} and as_float(row["hypothetical_result_R"]) < 0]
    oct_removed = [row for row in oct_rows if row["router_decision"] in {"dirty_skipped", "weak_routed_to_retest", "strong_blocked_existing_position", "strong_blocked_spread_guard", "strong_not_ordered"} and as_float(row["hypothetical_result_R"]) > 0]

    lines = [
        "# Nested N-Wave Router Decision Audit",
        "",
        "## Scope",
        "",
        "- This is a judgement audit of the existing Breakout Quality Router, not Router v2.",
        "- No EA logic, order bridge, SL/TP, RewardR, timeframe, spread guard, or risk calculation was changed.",
        "- The audit replays Router candidates that were skipped or blocked using the logged `entry_price`, `sl`, and `tp`.",
        "- Same-bar TP/SL ambiguity is recorded and conservatively counted as SL for aggregate PnL.",
        "- Primary interpretation uses `ALL_SCORE_PASSING`; `BEST_ONLY` is retained in CSV for traceability.",
        "",
        "## Primary All-Candidates Decision Audit",
        "",
        "| router_decision | candidates | win % | PF | avg_R | net | reached 1R % | reached 2R % | false return % | FX net | XAUUSD net |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in primary_by_decision:
        lines.append(
            f"| {row['router_decision']} | {row['candidates']} | {row['hypothetical_win_rate']} | {row['hypothetical_profit_factor']} | {row['hypothetical_avg_R']} | {row['hypothetical_net_profit']} | {row['reached_1R_pct']} | {row['reached_2R_pct']} | {row['false_break_return_pct']} | {row['fx_hypothetical_net']} | {row['xauusd_hypothetical_net']} |"
        )

    dirty = next((row for row in primary_by_decision if row["router_decision"] == "dirty_skipped"), None)
    weak = next((row for row in primary_by_decision if row["router_decision"] == "weak_routed_to_retest"), None)
    strong_blocked = [row for row in primary_by_decision if str(row["router_decision"]).startswith("strong_blocked") or row["router_decision"] == "strong_not_ordered"]
    strong_ordered = next((row for row in primary_by_decision if row["router_decision"] == "strong_ordered"), None)

    lines += [
        "",
        "## Direct Answers",
        "",
    ]
    if dirty:
        lines.append(
            f"- `dirty_breakout` skipped candidates were net `{dirty['hypothetical_net_profit']}` with PF `{dirty['hypothetical_profit_factor']}` and avg_R `{dirty['hypothetical_avg_R']}`. They were not uniformly bad, so `dirty` is too broad as a final discard bucket."
        )
    if weak:
        lines.append(
            f"- `weak_breakout` candidates entered immediately would have produced net `{weak['hypothetical_net_profit']}`, PF `{weak['hypothetical_profit_factor']}`, avg_R `{weak['hypothetical_avg_R']}`. Retest routing should be audited with context quality, not treated as automatically safer."
        )
    if strong_blocked:
        total = {
            "candidates": sum(as_int(row["candidates"]) for row in strong_blocked),
            "net": round(sum(as_float(row["hypothetical_net_profit"]) for row in strong_blocked), 2),
            "avg_r": round(sum(as_float(row["hypothetical_avg_R"]) * as_int(row["candidates"]) for row in strong_blocked) / max(1, sum(as_int(row["candidates"]) for row in strong_blocked)), 3),
        }
        lines.append(
            f"- Blocked `strong_breakout` candidates: `{total['candidates']}` candidates, net `{total['net']}`, weighted avg_R `{total['avg_r']}`. Some losses were avoided, but this bucket also contains missed winners."
        )
    if strong_ordered:
        lines.append(
            f"- Ordered `strong_breakout` candidates were sparse: `{strong_ordered['candidates']}` candidates, net `{strong_ordered['hypothetical_net_profit']}`, avg_R `{strong_ordered['hypothetical_avg_R']}`."
        )

    lines += [
        f"- 2025-10 removed hypothetical winners: `{len(oct_removed)}` candidates.",
        f"- 2026-Q1 avoided hypothetical losers from dirty/weak routing: `{len(q1_avoided)}` candidates.",
        "",
        "## Removed Winners / Avoided Losers",
        "",
        "2025-10 removed winners by Router decision:",
    ]
    oct_counts = Counter(str(row["router_decision"]) for row in oct_removed)
    oct_net = defaultdict(float)
    for row in oct_removed:
        oct_net[str(row["router_decision"])] += as_float(row["hypothetical_net_profit"])
    for decision, count in oct_counts.most_common():
        lines.append(f"- `{decision}`: {count} candidates, hypothetical net `{round(oct_net[decision], 2)}`.")

    lines += [
        "",
        "2026-Q1 avoided losers by Router decision:",
    ]
    q1_counts = Counter(str(row["router_decision"]) for row in q1_avoided)
    q1_net = defaultdict(float)
    for row in q1_avoided:
        q1_net[str(row["router_decision"])] += as_float(row["hypothetical_net_profit"])
    for decision, count in q1_counts.most_common():
        lines.append(f"- `{decision}`: {count} candidates, hypothetical net `{round(q1_net[decision], 2)}`.")
    lines += [
        "",
        "Interpretation:",
        "",
        "- `dirty_breakout` is correctly removing many 2026-Q1 losers, but it also removed seven 2025-10 winners. Treating it as a hard final skip is too blunt.",
        "- `weak_breakout` is close to breakeven overall and has positive 2025-08/2025-10 pockets, so retest routing should depend on context quality.",
        "- Blocked `strong_breakout` candidates were often positive in this hindsight audit, but spread guard and existing-position blocks are execution constraints, not Router quality labels. Do not weaken execution guards based on this alone.",
        "",
        "## Router Direction",
        "",
        "- The current Router mostly reduces trade count; it is not yet reliably selecting winners.",
        "- The next branch should not tune the current thresholds directly.",
        "- The next useful design is a two-stage router: Breakout Candle Quality first, then Context Quality.",
        "- Context Quality should decide whether a strong candle has room to run, whether a weak candle deserves retest, and whether a dirty candle is truly invalid.",
        "",
        "## Context Quality Seed",
        "",
        "- H4 pullback must look like a natural wave-2 endpoint, not range-middle noise.",
        "- H1 counter N-wave must be structurally broken, not merely touched by one M15 close.",
        "- M15 must not already be overextended before the neckline break.",
        "- There should be enough obstacle-free room from neckline to 2R.",
        "- Neckline age and touch count should penalize stale or over-tested levels.",
        "- SL width should be acceptable relative to ATR.",
        "- The path from 1R to 2R should be plausible; otherwise the router should choose retest or skip.",
        "",
        "## Artifacts",
        "",
        f"- Audit CSV: [{OUTPUTS['audit'].name}]({OUTPUTS['audit'].name})",
        f"- By decision: [{OUTPUTS['by_decision'].name}]({OUTPUTS['by_decision'].name})",
        f"- 2025-10 removed winners: [{OUTPUTS['removed_winners_2025_10'].name}]({OUTPUTS['removed_winners_2025_10'].name})",
        f"- 2026-Q1 avoided losers: [{OUTPUTS['avoided_losers_2026_q1'].name}]({OUTPUTS['avoided_losers_2026_q1'].name})",
        f"- Context quality seed: [{OUTPUTS['context_seed'].name}]({OUTPUTS['context_seed'].name})",
    ]
    OUTPUTS["summary"].write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_context_seed() -> None:
    lines = [
        "# Nested N-Wave Context Quality Seed",
        "",
        "This note preserves the next design direction after the Router decision audit. It is not an implemented rule set.",
        "",
        "## Two-Stage Router",
        "",
        "1. M15 neckline break occurs.",
        "2. Classify Breakout Candle Quality.",
        "3. Classify Context Quality.",
        "4. Route the candidate:",
        "   - Strong breakout + clean context + room to 2R: instant entry.",
        "   - Weak breakout + clean structure: retest confirmation.",
        "   - Strong candle but overextended or blocked by nearby obstacle: retest or skip.",
        "   - Dirty breakout, stale neckline, poor RR, or broken context: skip.",
        "",
        "## Context Quality Inputs",
        "",
        "- H4 wave-2 endpoint naturalness.",
        "- H4 pullback zone and distance to next H4 obstacle.",
        "- H1 counter N-wave break quality.",
        "- M15 pre-break extension and whether the entry is already late.",
        "- Neckline age and touch count.",
        "- Neckline-to-entry distance.",
        "- SL ATR width.",
        "- Room from neckline to 2R and from 1R to 2R.",
        "- False-return behavior after break, separated from healthy shallow retests.",
        "",
        "## Guardrails",
        "",
        "- Do not make this XAUUSD-only, LONG-only, or SHORT-only.",
        "- Do not use hindsight false-break labels as direct live filters.",
        "- Keep early fail rows summarized; do not return to full raw scan logging.",
        "- Test fixed gates only after the audit shows which skipped candidates were truly poor.",
    ]
    OUTPUTS["context_seed"].write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_devlog() -> None:
    text = f"""# 2026-06-15 - Nested N-Wave Router Decision Audit

## Summary

- Audited the existing Breakout Quality Router decisions without changing EA behavior.
- Replayed skipped or blocked Router candidates using logged `entry_price`, `sl`, and `tp`.
- Focused on whether `dirty_breakout`, `weak_breakout`, and blocked `strong_breakout` decisions actually removed bad trades.
- Preserved the next design direction as Breakout Quality plus Context Quality rather than Router v2 threshold tuning.

## What Did Not Change

- No EA source changes.
- No order bridge, SL/TP, RewardR, timeframe, spread guard, risk calculation, or CTrade changes.
- No new backtest run and no annual validation.

## Evidence

- Summary: [reports/backtest/{OUTPUTS['summary'].name}](../../reports/backtest/{OUTPUTS['summary'].name})
- Audit CSV: [reports/backtest/{OUTPUTS['audit'].name}](../../reports/backtest/{OUTPUTS['audit'].name})
- By decision: [reports/backtest/{OUTPUTS['by_decision'].name}](../../reports/backtest/{OUTPUTS['by_decision'].name})
- 2025-10 removed winners: [reports/backtest/{OUTPUTS['removed_winners_2025_10'].name}](../../reports/backtest/{OUTPUTS['removed_winners_2025_10'].name})
- 2026-Q1 avoided losers: [reports/backtest/{OUTPUTS['avoided_losers_2026_q1'].name}](../../reports/backtest/{OUTPUTS['avoided_losers_2026_q1'].name})
- Context quality seed: [reports/backtest/{OUTPUTS['context_seed'].name}](../../reports/backtest/{OUTPUTS['context_seed'].name})

## Decision

Do not tune Router thresholds yet. The next useful implementation should be a diagnostic Context Quality layer that separates strong-but-overextended breakouts, weak-but-structurally-clean breakouts, and genuinely dirty breakouts.
"""
    DEVLOG.write_text(text, encoding="utf-8")


def main() -> None:
    rows = build_audit_rows()
    by_decision = aggregate(rows, ["entry_selection_mode", "router_decision"])
    write_union_rows(OUTPUTS["audit"], rows)
    write_union_rows(OUTPUTS["by_decision"], by_decision)
    write_union_rows(OUTPUTS["by_period"], aggregate(rows, ["entry_selection_mode", "period", "router_decision"]))
    write_union_rows(OUTPUTS["by_quality_label"], aggregate(rows, ["entry_selection_mode", "period", "breakout_quality_label"]))
    write_union_rows(OUTPUTS["by_quality_reason"], aggregate(rows, ["entry_selection_mode", "period", "breakout_quality_reason"]))

    write_union_rows(
        OUTPUTS["removed_winners_2025_10"],
        top_rows(
            rows,
            lambda row: row["entry_selection_mode"] == "ALL_SCORE_PASSING"
            and row["period"] == "2025-10"
            and row["router_decision"] != "strong_ordered"
            and as_float(row["hypothetical_result_R"]) > 0,
            reverse=True,
            limit=100,
        ),
    )
    write_union_rows(
        OUTPUTS["avoided_losers_2026_q1"],
        top_rows(
            rows,
            lambda row: row["entry_selection_mode"] == "ALL_SCORE_PASSING"
            and row["period"] == "2026-Q1"
            and row["router_decision"] in {"dirty_skipped", "weak_routed_to_retest"}
            and as_float(row["hypothetical_result_R"]) < 0,
            reverse=False,
            limit=150,
        ),
    )
    write_context_seed()
    write_summary(rows, by_decision)
    write_devlog()

    metrics = {
        "rows": len(rows),
        "by_decision": Counter(str(row["router_decision"]) for row in rows),
        "outputs": {key: str(path) for key, path in OUTPUTS.items()},
    }
    OUTPUTS["metrics"].write_text(json.dumps(metrics, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"rows": len(rows), "summary": str(OUTPUTS["summary"])}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
