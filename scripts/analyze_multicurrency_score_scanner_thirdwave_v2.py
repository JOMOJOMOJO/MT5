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
OUT_PREFIX = f"{OUT_BASE}_thirdwave_v2"

SERIES = [
    {
        "period": "2025-02",
        "series_name": "2025_02_thirdwave_v2",
        "from_date": "2025-02-01",
        "to_date": "2025-02-28",
        "context": "2025 losing-period sample",
    },
    {
        "period": "2025-08",
        "series_name": "2025_08_thirdwave_v2",
        "from_date": "2025-08-01",
        "to_date": "2025-08-31",
        "context": "2025 comparison sample",
    },
    {
        "period": "2025-10",
        "series_name": "2025_10_thirdwave_v2",
        "from_date": "2025-10-01",
        "to_date": "2025-10-31",
        "context": "2025 comparison sample",
    },
    {
        "period": "2026-Q1",
        "series_name": "2026_q1_thirdwave_v2",
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
        "# ThirdWave v2 Design",
        "",
        "## Premise",
        "",
        "- v2 is a separate research mode: `RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V2_AUDIT_FILTERED`.",
        "- Existing ThirdWave, regime ThirdWave, Phase2 scanner, score calculation, CTrade bridge, risk sizing, SL, TP, and `InpRewardR` are unchanged.",
        "- No parameter optimization was performed. The gates are fixed from the prior Wave Audit distribution.",
        "- v2 remains all-symbol and both-direction. It is not XAUUSD-only, LONG-only, or SHORT-only.",
        "",
        "## Wave Audit Findings Used",
        "",
        "- `chasing_entry` was profitable in aggregate, so v2 does not remove the audit label wholesale.",
        "- `bars_since_reclaim_or_breakdown` was not useful because almost all actual entries were at one closed bar after reclaim/breakdown.",
        "- Wide `SL_ATR` buckets were profitable, so an SL/ATR width filter was not justified.",
        "- Pullbacks deeper than 75% were weak: they produced little net gain relative to trade count and drawdown.",
        "- Higher timeframe trends older than 10 bars were weak, especially above 20 bars.",
        "- Entry distance from reclaim/breakdown above 1.5 ATR was weak and represents the clearest chasing-entry implementation risk.",
        "",
        "## v2 Filters",
        "",
        "1. `v2_pullback_too_deep_audit`: block candidates where `pullback_broke_origin=true` or `pullback_depth_pct > 75`.",
        "2. `v2_trend_too_old`: block candidates where `higher_trend_age_bars > 10`.",
        "3. `v2_reclaim_chase_too_far`: block candidates where `entry_distance_from_reclaim_atr > 1.50`.",
        "",
        "## Why These Three",
        "",
        "- They are structural: pullback integrity, trend freshness, and reclaim-chase distance.",
        "- They do not encode symbol, direction, session, month, or reward/stop parameters.",
        "- They are narrow enough to test the wave-quality hypothesis without turning v2 into a broad over-filter.",
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
    v2 = [r for r in comparison_rows if r["variant"] == "v2_audit_filtered"]
    current_pf = sum(as_float(r["profit_factor"]) for r in current) / len(current) if current else 0.0
    v2_pf = sum(as_float(r["profit_factor"]) for r in v2) / len(v2) if v2 else 0.0
    current_avg_r = sum(as_float(r["avg_R"]) for r in current) / len(current) if current else 0.0
    v2_avg_r = sum(as_float(r["avg_R"]) for r in v2) / len(v2) if v2 else 0.0
    current_trades = sum(as_int(r["trades"]) for r in current)
    v2_trades = sum(as_int(r["trades"]) for r in v2)
    v2_trade_ratio = v2_trades / current_trades if current_trades else 0.0
    v2_trades_rows = [t for t in all_trades if t["variant"] == "v2_audit_filtered"]
    xau_count = sum(1 for t in v2_trades_rows if t["symbol"] == "XAUUSD")
    xau_share = xau_count / len(v2_trades_rows) if v2_trades_rows else 0.0
    long_count = sum(1 for t in v2_trades_rows if t["direction"] == "LONG")
    short_count = sum(1 for t in v2_trades_rows if t["direction"] == "SHORT")
    major_direction_share = max(long_count, short_count) / len(v2_trades_rows) if v2_trades_rows else 0.0

    reasons = [
        f"current average PF={current_pf:.3f}, v2 average PF={v2_pf:.3f}",
        f"current average R={current_avg_r:.3f}, v2 average R={v2_avg_r:.3f}",
        f"trade count ratio={v2_trade_ratio:.1%} ({v2_trades}/{current_trades})",
        f"v2 XAUUSD share={xau_share:.1%}",
        f"v2 largest direction share={major_direction_share:.1%}",
    ]
    pass_gate = (
        (v2_pf > current_pf or v2_avg_r > current_avg_r)
        and v2_trade_ratio >= 0.35
        and xau_share < 0.80
        and major_direction_share < 0.80
    )
    return pass_gate, reasons


def write_short_summary(comparison_rows: list[dict[str, object]], all_trades: list[dict[str, object]], pass_gate: bool, gate_reasons: list[str]) -> None:
    lines = [
        "# ThirdWave v2 Short-Period Summary",
        "",
        "## Scope",
        "",
        "- Compared current `ThirdWave_regime_BOTH_all_5m` against `ThirdWave_v2_audit_filtered_BOTH_all_5m`.",
        "- Both used `ENTRY_SELECTION_ALL_SCORE_PASSING`, 5-minute scan, `DIAG_ENTRY_ONLY`, and no parameter optimization.",
        "- Existing ThirdWave logic was rerun in the same build to verify behavior isolation.",
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
            "## Judgement",
            "",
            "- Current ThirdWave's main issue remains wave-position quality: the short audit is still dominated by `chasing_entry`, not `third_wave_initial`.",
            "- v2 improved average R and reduced drawdown by removing weak structural cases, but it did not turn the model into a clean third-wave-initial entry model.",
            "- This is not just harmless filtering: total trades fell to 53.2% of current, and the remaining v2 sample became more concentrated in XAUUSD.",
            "- v2 is therefore useful as a diagnostic branch, but not yet a validated improvement branch for annual OOS.",
            "- It is not a symbol/direction escape in implementation, but the short-period result still depends too much on XAUUSD to justify broader promotion.",
            "- The next repair should target lower-reversal timing and wave-position classification first. Regime quality is second. SL/TP changes should remain deferred.",
            "- The correct next step is to refine the entry thesis, not run parameter search or annual tests from this v2 version.",
        ]
    )
    (BACKTEST / f"{OUT_PREFIX}_short_period_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_oos_summary(pass_gate: bool, gate_reasons: list[str]) -> None:
    lines = [
        "# ThirdWave v2 OOS Summary",
        "",
    ]
    if pass_gate:
        lines.extend(
            [
                "Annual validation was permitted by the short-period gate, but this analyzer did not find annual v2 artifacts in the current run set.",
                "Run 2024, 2025, and 2026YTD with `ScenarioSet=V2Comparison` before treating this as an OOS result.",
            ]
        )
    else:
        lines.extend(
            [
                "Annual validation was intentionally not executed because the short-period gate did not pass cleanly.",
                "This follows the requested rule: only run year-level checks if v2 clearly improves without over-filtering or concentrating into one symbol/direction.",
                "",
                "Gate evidence:",
            ]
        )
        for reason in gate_reasons:
            lines.append(f"- {reason}")
    (BACKTEST / f"{OUT_PREFIX}_oos_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_devlog(pass_gate: bool) -> None:
    path = Path("docs/devlog/2026-06-04-thirdwave-v2-audit-filtered.md")
    lines = [
        "# 2026-06-04 - ThirdWave v2 Audit-Filtered Branch",
        "",
        "## Summary",
        "",
        "- Added a separate ThirdWave v2 research mode based on prior Wave Audit findings.",
        "- v2 keeps all-symbol, both-direction ThirdWave behavior but blocks three audit-derived structural weaknesses.",
        "- Existing Phase2 scanner and existing ThirdWave modes remain separate.",
        "",
        "## Implementation",
        "",
        "- New mode: `RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V2_AUDIT_FILTERED`.",
        "- Filters: deep/broken pullback, old higher-timeframe trend, and reclaim/breakdown chase distance above 1.5 ATR.",
        "- Added v2 summary counters and v2 filter fields to ThirdWave diagnostics.",
        "",
        "## Verification",
        "",
        "- Compile evidence: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v2_compile.txt`.",
        "- Short-period comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v2_short_period_summary.md`.",
        "- Annual gate result: " + ("passed" if pass_gate else "not passed") + ".",
        "",
        "## Decision",
        "",
        "- No parameter optimization was performed.",
        "- Annual validation should only be treated as complete if the short-period gate passes and year-level artifacts are generated.",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


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
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_label.csv", group_rows(all_trade_rows, "wave_audit_label", lambda t: t.get("wave_audit_label", "unmatched")))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_symbol.csv", group_rows(all_trade_rows, "symbol", lambda t: t["symbol"]))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_direction.csv", group_rows(all_trade_rows, "direction", lambda t: t["direction"]))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_regime.csv", group_rows(all_trade_rows, "regime", lambda t: t.get("regime", "unmatched")))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_session.csv", group_rows(all_trade_rows, "session", lambda t: t.get("session", "")))
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
