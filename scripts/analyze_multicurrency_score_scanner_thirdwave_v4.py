#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any

from analyze_multicurrency_score_scanner_2025 import (
    BACKTEST,
    calc_stats,
    parse_mt5_deals,
    serialize_stats,
    write_rows,
    write_trades,
)


OUT_BASE = "ExpectedValue_MultiCurrency_ScoreScanner"
OUT_PREFIX = f"{OUT_BASE}_thirdwave_v4"

SERIES = [
    {
        "period": "2025-02",
        "series_name": "2025_02_thirdwave_v4",
        "from_date": "2025-02-01",
        "to_date": "2025-02-28",
        "context": "2025 losing-period sample",
    },
    {
        "period": "2025-08",
        "series_name": "2025_08_thirdwave_v4",
        "from_date": "2025-08-01",
        "to_date": "2025-08-31",
        "context": "2025 comparison sample",
    },
    {
        "period": "2025-10",
        "series_name": "2025_10_thirdwave_v4",
        "from_date": "2025-10-01",
        "to_date": "2025-10-31",
        "context": "2025 comparison sample",
    },
    {
        "period": "2026-Q1",
        "series_name": "2026_q1_thirdwave_v4",
        "from_date": "2026-01-01",
        "to_date": "2026-03-31",
        "context": "2026YTD sample",
    },
]

RUNS = [
    {
        "run": "A",
        "variant": "current",
        "scenario": "ThirdWave_regime_BOTH_all_5m",
        "suffix": "A_current_regime_all_5m",
    },
    {
        "run": "B",
        "variant": "v2_audit_filtered",
        "scenario": "ThirdWave_v2_audit_filtered_BOTH_all_5m",
        "suffix": "B_v2_audit_filtered_all_5m",
    },
    {
        "run": "C",
        "variant": "v3_entry_timing",
        "scenario": "ThirdWave_v3_entry_timing_BOTH_all_5m",
        "suffix": "C_v3_entry_timing_all_5m",
    },
    {
        "run": "D",
        "variant": "v4_early_reversal",
        "scenario": "ThirdWave_v4_early_reversal_BOTH_all_5m",
        "suffix": "D_v4_early_reversal_all_5m",
    },
]

AUDIT_FIELDS = [
    "time",
    "event",
    "symbol",
    "direction",
    "entry_price",
    "sl",
    "tp",
    "result_R",
    "profit",
    "regime",
    "session",
    "scan_interval",
    "entry_selection_mode",
    "higher_tf",
    "higher_swing_low_1",
    "higher_swing_high_1",
    "higher_swing_low_2",
    "higher_swing_high_2",
    "higher_structure_state",
    "higher_trend_age_bars",
    "higher_ema_slope",
    "higher_atr",
    "mid_tf",
    "impulse_start_price",
    "impulse_end_price",
    "pullback_extreme_price",
    "pullback_depth_pct",
    "pullback_depth_atr",
    "pullback_bars",
    "pullback_broke_origin",
    "pullback_structure_low_or_high",
    "distance_from_pullback_extreme_to_entry_atr",
    "distance_from_pullback_extreme_to_entry_pct_of_impulse",
    "lower_tf",
    "minor_reversal_level",
    "reclaim_or_breakdown_price",
    "bars_since_reclaim_or_breakdown",
    "entry_distance_from_reclaim_atr",
    "entry_distance_from_reclaim_points",
    "lower_reversal_quality",
    "lower_reversal_quality_score",
    "sl_atr",
    "risk_r",
    "rr",
    "spread_atr",
    "structure_stage_fail_reason",
    "execution_block_reason",
    "v2_filter_pass",
    "v2_filter_fail_reason",
    "v3_filter_pass",
    "v3_filter_fail_reason",
    "v3_momentum_exhaustion_score",
    "v3_momentum_exhausted",
    "v3_recent_move_atr",
    "v3_consecutive_directional_bars",
    "v3_close_to_recent_extreme_atr",
    "reversal_signal_type",
    "v4_block_reason",
    "bars_since_pullback_extreme",
    "bars_since_reversal_signal",
    "distance_from_reversal_signal_to_entry_atr",
    "impulse_consumed_pct",
    "pre_entry_momentum_score",
    "reversal_strength_score",
    "wave_audit_label",
    "wave_audit_reason",
    "strategy_name",
]


def series_prefix(series_name: str) -> str:
    return f"{OUT_BASE}_{series_name}"


def run_prefix(series_name: str, run: dict[str, str]) -> str:
    return f"{series_prefix(series_name)}_{run['suffix']}"


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return list(csv.DictReader(fh))


def parse_log_time(value: str) -> datetime | None:
    value = (value or "").strip()
    if not value:
        return None
    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")


def as_float(value: Any, default: float = 0.0) -> float:
    if value is None:
        return default
    text = str(value).strip()
    if text == "":
        return default
    return float(text)


def as_int(value: Any, default: int = 0) -> int:
    if value is None:
        return default
    text = str(value).strip()
    if text == "":
        return default
    return int(float(text))


def pf_value(stats: dict[str, object]) -> object:
    return round(float(stats["profit_factor"]), 3) if stats["profit_factor"] is not None else ""


def read_elapsed(series_name: str, run_id: str) -> float:
    path = BACKTEST / f"{series_prefix(series_name)}_elapsed.csv"
    if not path.exists():
        return 0.0
    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            if row.get("run") == run_id:
                return as_float(row.get("elapsed_seconds"))
    return 0.0


def band(value: float, cuts: list[float], labels: list[str]) -> str:
    for cut, label in zip(cuts, labels):
        if value < cut:
            return label
    return labels[-1]


def pullback_depth_band(value: float) -> str:
    return band(value, [18, 25, 38.2, 50, 61.8, 75, 90], ["<18", "18-25", "25-38.2", "38.2-50", "50-61.8", "61.8-75", "75-90", "90+"])


def entry_distance_band(value: float) -> str:
    return band(value, [0.25, 0.50, 0.75, 1.00, 1.50, 2.00, 3.00], ["<0.25ATR", "0.25-0.50ATR", "0.50-0.75ATR", "0.75-1.00ATR", "1.00-1.50ATR", "1.50-2.00ATR", "2.00-3.00ATR", "3.00ATR+"])


def session_for_hour(hour: int) -> str:
    if 0 <= hour < 8:
        return "server_00_07"
    if 8 <= hour < 16:
        return "server_08_15"
    return "server_16_23"


def match_audit_row(
    trade: dict[str, object],
    audit_rows: list[dict[str, str]],
    used: set[int],
) -> tuple[int, dict[str, str]]:
    best_idx = -1
    best_delta = 10**9
    open_time = trade["open_time"]
    for idx, row in enumerate(audit_rows):
        if idx in used:
            continue
        if row.get("event") != "order_sent":
            continue
        if row.get("symbol") != trade["symbol"]:
            continue
        if row.get("direction") != trade["direction"]:
            continue
        log_time = parse_log_time(row.get("time", ""))
        if log_time is None:
            continue
        delta = abs((open_time - log_time).total_seconds())
        if delta <= 900 and delta < best_delta:
            best_delta = int(delta)
            best_idx = idx
    if best_idx >= 0:
        used.add(best_idx)
        return best_idx, audit_rows[best_idx]
    return -1, {}


def compute_result_r(trade: dict[str, object], audit: dict[str, str]) -> float:
    risk_r = as_float(audit.get("risk_r"))
    if risk_r <= 0.0:
        return 0.0
    entry_price = as_float(audit.get("entry_price")) or float(trade["open_price"])
    direction_sign = 1.0 if trade["direction"] == "LONG" else -1.0
    return (float(trade["close_price"]) - entry_price) * direction_sign / risk_r


def file_size(path: Path) -> int:
    return path.stat().st_size if path.exists() else 0


def run_csv_bytes(prefix: str) -> int:
    total = 0
    for path in BACKTEST.glob(f"{prefix}*.csv"):
        total += file_size(path)
    return total


def enrich_trades(
    trades: list[dict[str, object]],
    audit_rows: list[dict[str, str]],
    context: dict[str, object],
) -> tuple[list[dict[str, object]], dict[int, dict[str, object]]]:
    used: set[int] = set()
    enriched: list[dict[str, object]] = []
    matched_by_audit_index: dict[int, dict[str, object]] = {}
    for idx, trade in enumerate(trades, start=1):
        audit_idx, audit = match_audit_row(trade, audit_rows, used)
        row = dict(trade)
        row.update(context)
        row["trade_index"] = idx
        for field in AUDIT_FIELDS:
            row[field] = audit.get(field, "") if audit else ""
        row["result_R"] = round(compute_result_r(trade, audit), 4) if audit else 0.0
        row["profit"] = round(float(trade["net_profit"]), 2)
        row["month"] = trade["open_time"].strftime("%Y-%m")
        row["hour"] = f"{trade['open_time'].hour:02d}"
        row["session"] = audit.get("session") or session_for_hour(trade["open_time"].hour)
        row["wave_audit_label"] = audit.get("wave_audit_label") or "unmatched"
        row["regime"] = audit.get("regime") or "unmatched"
        row["pullback_depth_band"] = pullback_depth_band(as_float(audit.get("pullback_depth_pct")))
        row["entry_distance_band"] = entry_distance_band(as_float(audit.get("distance_from_pullback_extreme_to_entry_atr")))
        enriched.append(row)
        if audit_idx >= 0:
            matched_by_audit_index[audit_idx] = row
    return enriched, matched_by_audit_index


def trade_row_for_csv(row: dict[str, object]) -> dict[str, object]:
    out = dict(row)
    for key in ("open_time", "close_time", "open_bar_m5", "close_bar_m5"):
        value = out.get(key)
        if isinstance(value, datetime):
            out[key] = value.strftime("%Y.%m.%d %H:%M:%S")
    return out


def group_rows(
    trades: list[dict[str, object]],
    group_name: str,
    key_fn,
) -> list[dict[str, object]]:
    buckets: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for trade in trades:
        buckets[(str(trade["variant"]), str(key_fn(trade)))].append(trade)
    rows: list[dict[str, object]] = []
    for (variant, key), bucket in sorted(buckets.items()):
        stats = calc_stats(bucket)
        avg_r = sum(float(t.get("result_R", 0.0)) for t in bucket) / len(bucket) if bucket else 0.0
        xau = [t for t in bucket if t["symbol"] == "XAUUSD"]
        rows.append(
            {
                "variant": variant,
                group_name: key,
                "trades": stats["trades"],
                "wins": stats["wins"],
                "losses": stats["losses"],
                "win_rate": round(float(stats["win_rate"]), 2),
                "net_profit": round(float(stats["net_profit"]), 2),
                "profit_factor": pf_value(stats),
                "expected_payoff": round(float(stats["expected_payoff"]), 2),
                "avg_R": round(avg_r, 3),
                "max_drawdown": round(float(stats["max_balance_dd"]), 2),
                "max_drawdown_pct": round(float(stats["max_balance_dd_pct"]), 2),
                "xauusd_trade_share_pct": round(len(xau) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "xauusd_net_profit": round(sum(float(t["net_profit"]) for t in xau), 2),
            }
        )
    return rows


def run_stats_row(
    series: dict[str, str],
    run: dict[str, str],
    trades: list[dict[str, object]],
    elapsed: float,
    raw_audit_rows: int,
    csv_bytes: int,
) -> dict[str, object]:
    stats = calc_stats(trades)
    labels = defaultdict(int)
    xau_trades = [t for t in trades if t["symbol"] == "XAUUSD"]
    long_trades = [t for t in trades if t["direction"] == "LONG"]
    short_trades = [t for t in trades if t["direction"] == "SHORT"]
    for trade in trades:
        labels[str(trade.get("wave_audit_label", "unmatched"))] += 1
    return {
        "period": series["period"],
        "variant": run["variant"],
        "context": series["context"],
        "scenario": run["scenario"],
        "trades": stats["trades"],
        "wins": stats["wins"],
        "losses": stats["losses"],
        "win_rate": round(float(stats["win_rate"]), 2),
        "net_profit": round(float(stats["net_profit"]), 2),
        "profit_factor": pf_value(stats),
        "expected_payoff": round(float(stats["expected_payoff"]), 2),
        "max_drawdown": round(float(stats["max_balance_dd"]), 2),
        "max_drawdown_pct": round(float(stats["max_balance_dd_pct"]), 2),
        "avg_R": round(sum(float(t.get("result_R", 0.0)) for t in trades) / len(trades), 3) if trades else 0.0,
        "elapsed_seconds": round(elapsed, 1),
        "raw_wave_audit_rows": raw_audit_rows,
        "csv_bytes": csv_bytes,
        "xauusd_trade_share_pct": round(len(xau_trades) / len(trades) * 100.0, 2) if trades else 0.0,
        "xauusd_net_profit": round(sum(float(t["net_profit"]) for t in xau_trades), 2),
        "long_trades": len(long_trades),
        "long_net_profit": round(sum(float(t["net_profit"]) for t in long_trades), 2),
        "short_trades": len(short_trades),
        "short_net_profit": round(sum(float(t["net_profit"]) for t in short_trades), 2),
        "third_wave_initial_trades": labels["third_wave_initial"],
        "third_wave_middle_trades": labels["third_wave_middle"],
        "late_entry_trades": labels["late_entry"],
        "chasing_entry_trades": labels["chasing_entry"],
        "invalid_structure_trades": labels["invalid_structure"],
        "range_noise_trades": labels["range_noise"],
        "unclear_trades": labels["unclear"],
    }


def filter_summary_rows() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for series in SERIES:
        for run in RUNS:
            prefix = run_prefix(series["series_name"], run)
            summary_rows = read_csv_rows(BACKTEST / f"{prefix}_thirdwave_summary.csv")
            last = summary_rows[-1] if summary_rows else {}
            rows.append(
                {
                    "period": series["period"],
                    "variant": run["variant"],
                    "v2_filter_evaluations": as_int(last.get("v2_filter_evaluations")),
                    "v2_filter_pass": as_int(last.get("v2_filter_pass")),
                    "v2_filter_fail": as_int(last.get("v2_filter_fail")),
                    "v2_filter_deep_pullback": as_int(last.get("v2_filter_deep_pullback")),
                    "v2_filter_trend_too_old": as_int(last.get("v2_filter_trend_too_old")),
                    "v2_filter_reclaim_chase_too_far": as_int(last.get("v2_filter_reclaim_chase_too_far")),
                    "top_v2_filter_fail_reason": last.get("top_v2_filter_fail_reason", ""),
                    "top_v2_filter_fail_reason_rows": as_int(last.get("top_v2_filter_fail_reason_rows")),
                    "v3_filter_evaluations": as_int(last.get("v3_filter_evaluations")),
                    "v3_filter_pass": as_int(last.get("v3_filter_pass")),
                    "v3_filter_fail": as_int(last.get("v3_filter_fail")),
                    "v3_filter_invalid_position": as_int(last.get("v3_filter_invalid_position")),
                    "v3_filter_late_entry": as_int(last.get("v3_filter_late_entry")),
                    "v3_filter_chasing_entry": as_int(last.get("v3_filter_chasing_entry")),
                    "v3_filter_reclaim_chase": as_int(last.get("v3_filter_reclaim_chase")),
                    "v3_filter_pullback_chase": as_int(last.get("v3_filter_pullback_chase")),
                    "v3_filter_momentum_exhausted": as_int(last.get("v3_filter_momentum_exhausted")),
                    "top_v3_filter_fail_reason": last.get("top_v3_filter_fail_reason", ""),
                    "top_v3_filter_fail_reason_rows": as_int(last.get("top_v3_filter_fail_reason_rows")),
                    "v4_reversal_evaluations": as_int(last.get("v4_reversal_evaluations")),
                    "v4_reversal_pass": as_int(last.get("v4_reversal_pass")),
                    "v4_reversal_fail": as_int(last.get("v4_reversal_fail")),
                    "v4_confirmed_fractal": as_int(last.get("v4_confirmed_fractal")),
                    "v4_early_higher_low": as_int(last.get("v4_early_higher_low")),
                    "v4_early_lower_high": as_int(last.get("v4_early_lower_high")),
                    "v4_momentum_turn": as_int(last.get("v4_momentum_turn")),
                    "v4_candle_reversal": as_int(last.get("v4_candle_reversal")),
                    "v4_micro_break": as_int(last.get("v4_micro_break")),
                    "v4_unclear": as_int(last.get("v4_unclear")),
                    "v4_impulse_consumed_blocked": as_int(last.get("v4_impulse_consumed_blocked")),
                    "top_v4_reversal_signal": last.get("top_v4_reversal_signal", ""),
                    "top_v4_reversal_signal_rows": as_int(last.get("top_v4_reversal_signal_rows")),
                }
            )
    return rows


def read_prior_wave_audit_rows() -> dict[str, list[dict[str, str]]]:
    names = [
        "ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_by_label.csv",
        "ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_by_entry_distance.csv",
        "ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_by_pullback_depth.csv",
        "ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_by_sl_atr.csv",
        "ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_by_direction.csv",
        "ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_by_symbol.csv",
    ]
    return {name: read_csv_rows(BACKTEST / name) for name in names}


def write_design() -> None:
    prior = read_prior_wave_audit_rows()
    lines = [
        "# ThirdWave v4 Early Reversal Design",
        "",
        "## Premise",
        "",
        "- v4 is a separate research mode: `RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V4_EARLY_REVERSAL`.",
        "- Existing ThirdWave, v2, v3, Phase2 scanner, score calculation, CTrade bridge, risk sizing, SL, TP, spread guard, timeframes, and `InpRewardR` are unchanged.",
        "- No parameter optimization was performed. v4 uses one fixed early-reversal detector and one loose impulse-consumed guard.",
        "- v4 remains all-symbol and both-direction. It is not XAUUSD-only, LONG-only, or SHORT-only.",
        "",
        "## Wave Audit And v3 Findings Used",
        "",
        "- Prior Wave Audit showed current ThirdWave was dominated by `chasing_entry` rather than `third_wave_initial`.",
        "- v2 reduced weak structure but did not materially solve late entry location.",
        "- v3 removed chasing labels but left only 4 of 109 comparable trades and did not improve PF or average R.",
        "- v4 therefore tests whether the lower-timeframe reversal detector itself is too late, instead of tightening the final entry-position gate further.",
        "",
        "## v4 Early Reversal Detector",
        "",
        "1. Keep confirmed fractal reclaim/breakdown as a fallback reference signal.",
        "2. Add earlier long signals: `early_higher_low`, `candle_reversal`, `micro_break`, and `momentum_turn`.",
        "3. Add earlier short signals: `early_lower_high`, `candle_reversal`, `micro_break`, and `momentum_turn`.",
        "4. Record `bars_since_pullback_extreme`, `bars_since_reversal_signal`, `impulse_consumed_pct`, pre-entry momentum, and reversal strength.",
        "5. Block only clearly consumed impulses with `v4_impulse_consumed`; this is deliberately looser than v3 to avoid collapsing trade count.",
        "",
        "## Why This Branch",
        "",
        "- The requested hypothesis is that confirmed-fractal reversal waits too long.",
        "- v4 directly compares early reversal signal types against current, v2, and v3 without changing reward, stop, spread, or timeframe behavior.",
        "- The goal is diagnostic: recover enough trades versus v3 while reducing current ThirdWave's chasing-entry dominance.",
        "",
        "## Prior Evidence Snapshot",
        "",
    ]
    for name, rows in prior.items():
        lines.append(f"### {name}")
        if rows:
            cols = list(rows[0].keys())[:6]
            lines.append("")
            lines.append("| " + " | ".join(cols) + " |")
            lines.append("|" + "|".join(["---"] * len(cols)) + "|")
            for row in rows[:8]:
                lines.append("| " + " | ".join(row.get(col, "") for col in cols) + " |")
            lines.append("")
        else:
            lines.append("")
            lines.append("- Missing or empty.")
            lines.append("")
    (BACKTEST / f"{OUT_PREFIX}_design.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def summarize_short_gate(comparison_rows: list[dict[str, object]], all_trades: list[dict[str, object]]) -> tuple[bool, list[str]]:
    current = [r for r in comparison_rows if r["variant"] == "current"]
    v3 = [r for r in comparison_rows if r["variant"] == "v3_entry_timing"]
    v4 = [r for r in comparison_rows if r["variant"] == "v4_early_reversal"]
    current_pf = sum(as_float(r["profit_factor"]) for r in current) / len(current) if current else 0.0
    v3_pf = sum(as_float(r["profit_factor"]) for r in v3) / len(v3) if v3 else 0.0
    v4_pf = sum(as_float(r["profit_factor"]) for r in v4) / len(v4) if v4 else 0.0
    current_avg_r = sum(as_float(r["avg_R"]) for r in current) / len(current) if current else 0.0
    v3_avg_r = sum(as_float(r["avg_R"]) for r in v3) / len(v3) if v3 else 0.0
    v4_avg_r = sum(as_float(r["avg_R"]) for r in v4) / len(v4) if v4 else 0.0
    current_trades = sum(as_int(r["trades"]) for r in current)
    v3_trades = sum(as_int(r["trades"]) for r in v3)
    v4_trades = sum(as_int(r["trades"]) for r in v4)
    v4_trade_ratio = v4_trades / current_trades if current_trades else 0.0
    v3_trades_rows = [t for t in all_trades if t["variant"] == "v3_entry_timing"]
    v4_trades_rows = [t for t in all_trades if t["variant"] == "v4_early_reversal"]
    current_trades_rows = [t for t in all_trades if t["variant"] == "current"]
    xau_count = sum(1 for t in v4_trades_rows if t["symbol"] == "XAUUSD")
    xau_share = xau_count / len(v4_trades_rows) if v4_trades_rows else 0.0
    long_count = sum(1 for t in v4_trades_rows if t["direction"] == "LONG")
    short_count = sum(1 for t in v4_trades_rows if t["direction"] == "SHORT")
    major_direction_share = max(long_count, short_count) / len(v4_trades_rows) if v4_trades_rows else 0.0
    current_good_labels = sum(1 for t in current_trades_rows if t.get("wave_audit_label") in {"third_wave_initial", "third_wave_middle"})
    v4_good_labels = sum(1 for t in v4_trades_rows if t.get("wave_audit_label") in {"third_wave_initial", "third_wave_middle"})
    current_chasing = sum(1 for t in current_trades_rows if t.get("wave_audit_label") == "chasing_entry")
    v4_chasing = sum(1 for t in v4_trades_rows if t.get("wave_audit_label") == "chasing_entry")
    current_good_share = current_good_labels / len(current_trades_rows) if current_trades_rows else 0.0
    v4_good_share = v4_good_labels / len(v4_trades_rows) if v4_trades_rows else 0.0
    current_chasing_share = current_chasing / len(current_trades_rows) if current_trades_rows else 0.0
    v4_chasing_share = v4_chasing / len(v4_trades_rows) if v4_trades_rows else 0.0
    current_fx = sum(float(t["net_profit"]) for t in current_trades_rows if t["symbol"] != "XAUUSD")
    v4_fx = sum(float(t["net_profit"]) for t in v4_trades_rows if t["symbol"] != "XAUUSD")

    reasons = [
        f"current average PF={current_pf:.3f}, v4 average PF={v4_pf:.3f}",
        f"current average R={current_avg_r:.3f}, v4 average R={v4_avg_r:.3f}",
        f"v3 trades={v3_trades}, v4 trades={v4_trades}, current trades={current_trades}",
        f"v4/current trade count ratio={v4_trade_ratio:.1%}",
        f"current good-label share={current_good_share:.1%}, v4 good-label share={v4_good_share:.1%}",
        f"current chasing share={current_chasing_share:.1%}, v4 chasing share={v4_chasing_share:.1%}",
        f"current FX net={current_fx:.2f}, v4 FX net={v4_fx:.2f}",
        f"v4 XAUUSD share={xau_share:.1%}",
        f"v4 largest direction share={major_direction_share:.1%}",
    ]
    pass_gate = (
        v4_trades > v3_trades
        and (v4_pf > current_pf or v4_avg_r > current_avg_r)
        and v4_good_share > current_good_share
        and v4_chasing_share < current_chasing_share
        and v4_fx >= current_fx
        and xau_share < 0.80
        and major_direction_share < 0.80
    )
    return pass_gate, reasons


def write_short_summary(comparison_rows: list[dict[str, object]], all_trades: list[dict[str, object]], pass_gate: bool, gate_reasons: list[str]) -> None:
    lines = [
        "# ThirdWave v4 Early Reversal Short-Period Summary",
        "",
        "## Scope",
        "",
        "- Compared current `ThirdWave_regime_BOTH_all_5m`, v2 `ThirdWave_v2_audit_filtered_BOTH_all_5m`, v3 `ThirdWave_v3_entry_timing_BOTH_all_5m`, and v4 `ThirdWave_v4_early_reversal_BOTH_all_5m`.",
        "- All runs used `ENTRY_SELECTION_ALL_SCORE_PASSING`, 5-minute scan, `DIAG_ENTRY_ONLY`, and no parameter optimization.",
        "- Existing ThirdWave/v2/v3 logic was rerun in the same build to verify behavior isolation.",
        "- RewardR, SL/TP, spread guard, and timeframe settings were not changed.",
        "",
        "## Results",
        "",
        "| Period | Variant | Trades | PF | Expected Payoff | Net | Avg R | Max DD % | XAU Share % | LONG Net | SHORT Net |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in comparison_rows:
        lines.append(
            f"| {row['period']} | {row['variant']} | {row['trades']} | {row['profit_factor']} | {row['expected_payoff']} | {row['net_profit']} | {row['avg_R']} | {row['max_drawdown_pct']} | {row['xauusd_trade_share_pct']} | {row['long_net_profit']} | {row['short_net_profit']} |"
        )
    lines.extend(
        [
            "",
            "## Annual Test Gate",
            "",
        ]
    )
    for reason in gate_reasons:
        lines.append(f"- {reason}")
    if pass_gate:
        lines.append("- Decision: short-period gate passed. Annual validation can proceed.")
    else:
        lines.append("- Decision: short-period gate did not pass cleanly. Annual validation was not executed in this cycle.")

    label_rows = group_rows(all_trades, "wave_audit_label", lambda t: t.get("wave_audit_label", "unmatched"))
    lines.extend(
        [
            "",
            "## Label Aggregate",
            "",
            "| Variant | Label | Trades | PF | Net | Avg R |",
            "|---|---|---:|---:|---:|---:|",
        ]
    )
    for row in label_rows:
        lines.append(f"| {row['variant']} | {row['wave_audit_label']} | {row['trades']} | {row['profit_factor']} | {row['net_profit']} | {row['avg_R']} |")

    lines.extend(
        [
            "",
            "## Reversal Signal Aggregate",
            "",
            "| Variant | Signal | Trades | PF | Net | Avg R |",
            "|---|---|---:|---:|---:|---:|",
        ]
    )
    signal_rows = group_rows(all_trades, "reversal_signal_type", lambda t: t.get("reversal_signal_type", ""))
    for row in signal_rows:
        lines.append(f"| {row['variant']} | {row['reversal_signal_type']} | {row['trades']} | {row['profit_factor']} | {row['net_profit']} | {row['avg_R']} |")

    lines.extend(
        [
            "",
            "## Judgement",
            "",
            "- v4 tests the revised hypothesis: the lower-timeframe reversal detector may be late, so earlier reversal signatures are recorded and allowed before confirmed-fractal reclaim/breakdown.",
            "- Promotion depends on restoring trade count versus v3 while reducing current ThirdWave's chasing-entry share and improving PF or average R.",
            "- If the annual gate fails, v4 should be held as diagnostic evidence rather than promoted as a research branch.",
        ]
    )
    (BACKTEST / f"{OUT_PREFIX}_short_period_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_oos_summary(pass_gate: bool, gate_reasons: list[str]) -> None:
    lines = [
        "# ThirdWave v4 Annual Summary",
        "",
    ]
    if pass_gate:
        lines.extend(
            [
                "Annual validation was permitted by the short-period gate, but this analyzer did not run annual v4 artifacts automatically.",
                "Run 2024, 2025, and 2026YTD with `ScenarioSet=V4Comparison` before treating this as an annual result.",
            ]
        )
    else:
        lines.extend(
            [
                "Annual validation was intentionally not executed because the short-period gate did not pass cleanly.",
                "This follows the requested rule: only run year-level checks if v4 restores trade count versus v3, reduces chasing versus current ThirdWave, improves PF or average R, improves FX net, and avoids symbol/direction concentration.",
                "",
                "Decision: hold v4 as a diagnostic branch unless the short-period evidence supports annual validation.",
                "",
                "Gate evidence:",
            ]
        )
        for reason in gate_reasons:
            lines.append(f"- {reason}")
    (BACKTEST / f"{OUT_PREFIX}_oos_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_devlog(pass_gate: bool) -> None:
    path = Path("docs/devlog/2026-06-05-thirdwave-v4-early-reversal.md")
    lines = [
        "# 2026-06-05 - ThirdWave v4 Early Reversal Branch",
        "",
        "## Summary",
        "",
        "- Added a separate ThirdWave v4 research mode based on Wave Audit, v2, and v3 findings.",
        "- v4 keeps all-symbol, both-direction ThirdWave behavior but detects earlier lower-timeframe reversal signatures.",
        "- Existing Phase2 scanner, existing ThirdWave, v2, and v3 modes remain separate.",
        "",
        "## Implementation",
        "",
        "- New mode: `RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V4_EARLY_REVERSAL`.",
        "- Added early reversal signatures: `early_higher_low`, `early_lower_high`, `momentum_turn`, `candle_reversal`, and `micro_break`, with confirmed fractal reclaim/breakdown retained as a fallback reference.",
        "- Added v4 summary counters and v4 reversal fields to ThirdWave diagnostics.",
        "- Kept RewardR, SL/TP, spread guard, timeframe settings, risk sizing, and CTrade bridge unchanged.",
        "",
        "## Verification",
        "",
        "- Compile evidence: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v4_compile.txt`.",
        "- Short-period comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v4_short_period_summary.md`.",
        "- Annual gate result: " + ("passed" if pass_gate else "not passed") + ".",
        "",
        "## Decision",
        "",
        "- No parameter optimization was performed.",
    ]
    if pass_gate:
        lines.append("- The short-period gate passed; annual validation should be run before any further conclusion.")
    else:
        lines.extend(
            [
                "- The short-period gate did not pass, so annual validation was intentionally skipped.",
                "- v4 should remain diagnostic evidence unless it restores enough trade count, improves label distribution, and improves FX-wide expectancy.",
                "- Next work should follow the short-period evidence: continue early reversal only if it improves broad expectancy, otherwise move to Regime Quality v2 or treat ThirdWave as a continuation branch.",
            ]
        )
    content = "\n".join(lines) + "\n"
    path.write_text(content, encoding="utf-8")
    (BACKTEST / f"{OUT_PREFIX}_devlog.md").write_text(content, encoding="utf-8")


def main() -> None:
    all_trade_rows: list[dict[str, object]] = []
    comparison_rows: list[dict[str, object]] = []
    metrics: dict[str, object] = {"runs": {}}

    for series in SERIES:
        for run in RUNS:
            prefix = run_prefix(series["series_name"], run)
            report_path = BACKTEST / f"{prefix}_report.html"
            trades = parse_mt5_deals(report_path)
            write_trades(BACKTEST / f"{prefix}_trades.csv", trades)

            audit_rows = read_csv_rows(BACKTEST / f"{prefix}_thirdwave_wave_audit.csv")
            context = {
                "period": series["period"],
                "from_date": series["from_date"],
                "to_date": series["to_date"],
                "context": series["context"],
                "variant": run["variant"],
                "scenario": run["scenario"],
                "series_name": series["series_name"],
                "run": run["run"],
                "prefix": prefix,
            }
            enriched, _ = enrich_trades(trades, audit_rows, context)
            all_trade_rows.extend(enriched)

            elapsed = read_elapsed(series["series_name"], run["run"])
            row = run_stats_row(series, run, enriched, elapsed, len(audit_rows), run_csv_bytes(prefix))
            comparison_rows.append(row)
            metrics["runs"][f"{series['period']}:{run['variant']}"] = {
                "stats": serialize_stats(calc_stats(enriched)),
                "elapsed_seconds": elapsed,
                "raw_wave_audit_rows": len(audit_rows),
                "csv_bytes": row["csv_bytes"],
            }

    write_rows(BACKTEST / f"{OUT_PREFIX}_comparison.csv", comparison_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_trades.csv", [trade_row_for_csv(row) for row in all_trade_rows])
    label_rows = group_rows(all_trade_rows, "wave_audit_label", lambda t: t.get("wave_audit_label", "unmatched"))
    reversal_signal_rows = group_rows(all_trade_rows, "reversal_signal_type", lambda t: t.get("reversal_signal_type", ""))
    write_rows(BACKTEST / f"{OUT_PREFIX}_wave_label_aggregate.csv", label_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_label.csv", label_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_reversal_signal_aggregate.csv", reversal_signal_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_reversal_signal.csv", reversal_signal_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_symbol.csv", group_rows(all_trade_rows, "symbol", lambda t: t["symbol"]))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_direction.csv", group_rows(all_trade_rows, "direction", lambda t: t["direction"]))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_regime.csv", group_rows(all_trade_rows, "regime", lambda t: t.get("regime", "unmatched")))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_session.csv", group_rows(all_trade_rows, "session", lambda t: t.get("session", "")))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_month.csv", group_rows(all_trade_rows, "month", lambda t: t.get("month", "")))
    write_rows(BACKTEST / f"{OUT_PREFIX}_fx_vs_xauusd.csv", group_rows(all_trade_rows, "asset_class", lambda t: "XAUUSD" if t["symbol"] == "XAUUSD" else "FX"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_filter_summary.csv", filter_summary_rows())
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_pullback_depth.csv", group_rows(all_trade_rows, "pullback_depth_band", lambda t: t.get("pullback_depth_band", "")))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_entry_distance.csv", group_rows(all_trade_rows, "entry_distance_band", lambda t: t.get("entry_distance_band", "")))

    pass_gate, gate_reasons = summarize_short_gate(comparison_rows, all_trade_rows)
    write_design()
    write_short_summary(comparison_rows, all_trade_rows, pass_gate, gate_reasons)
    write_oos_summary(pass_gate, gate_reasons)
    write_devlog(pass_gate)

    with (BACKTEST / f"{OUT_PREFIX}_metrics.json").open("w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=2)

    print(json.dumps(comparison_rows, ensure_ascii=False, indent=2))
    print(json.dumps({"annual_gate_pass": pass_gate, "gate_reasons": gate_reasons}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
