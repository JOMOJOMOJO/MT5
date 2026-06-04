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
OUT_PREFIX = f"{OUT_BASE}_wave_audit"

SERIES = [
    {
        "period": "2025-02",
        "series_name": "2025_02_thirdwave_wave_audit",
        "from_date": "2025-02-01",
        "to_date": "2025-02-28",
        "context": "2025 losing-period sample",
    },
    {
        "period": "2025-08",
        "series_name": "2025_08_thirdwave_wave_audit",
        "from_date": "2025-08-01",
        "to_date": "2025-08-31",
        "context": "2025 comparison sample",
    },
    {
        "period": "2025-10",
        "series_name": "2025_10_thirdwave_wave_audit",
        "from_date": "2025-10-01",
        "to_date": "2025-10-31",
        "context": "2025 comparison sample",
    },
    {
        "period": "2026-Q1",
        "series_name": "2026_q1_thirdwave_wave_audit",
        "from_date": "2026-01-01",
        "to_date": "2026-03-31",
        "context": "2026YTD positive-period sample",
    },
]

RUN = {
    "run": "A",
    "scenario": "ThirdWave_regime_BOTH_all_5m_wave_audit",
    "suffix": "A_regime_all_5m_wave_audit",
}

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
    "wave_audit_label",
    "wave_audit_reason",
    "strategy_name",
]


def series_prefix(series_name: str) -> str:
    return f"{OUT_BASE}_{series_name}"


def run_prefix(series_name: str) -> str:
    return f"{series_prefix(series_name)}_{RUN['suffix']}"


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


def read_elapsed(series_name: str) -> float:
    path = BACKTEST / f"{series_prefix(series_name)}_elapsed.csv"
    if not path.exists():
        return 0.0
    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            if row.get("run") == RUN["run"]:
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


def reclaim_bars_band(value: int) -> str:
    if value <= 1:
        return "1"
    if value == 2:
        return "2"
    if value <= 4:
        return "3-4"
    return "5+"


def sl_atr_band(value: float) -> str:
    return band(value, [0.75, 1.00, 1.25, 1.50, 2.00], ["<0.75", "0.75-1.00", "1.00-1.25", "1.25-1.50", "1.50-2.00", "2.00+"])


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
        row["reclaim_bars_band"] = reclaim_bars_band(as_int(audit.get("bars_since_reclaim_or_breakdown")))
        row["sl_atr_band"] = sl_atr_band(as_float(audit.get("sl_atr")))
        enriched.append(row)
        if audit_idx >= 0:
            matched_by_audit_index[audit_idx] = row
    return enriched, matched_by_audit_index


def build_consolidated_audit_rows(
    raw_rows: list[dict[str, str]],
    matched_by_audit_index: dict[int, dict[str, object]],
    context: dict[str, object],
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for idx, raw in enumerate(raw_rows):
        row: dict[str, object] = dict(context)
        for field in AUDIT_FIELDS:
            row[field] = raw.get(field, "")
        match = matched_by_audit_index.get(idx)
        if match:
            row["result_R"] = match["result_R"]
            row["profit"] = match["profit"]
            row["close_time"] = match["close_time"].strftime("%Y.%m.%d %H:%M:%S")
            row["close_comment"] = match["close_comment"]
        else:
            row["close_time"] = ""
            row["close_comment"] = ""
        rows.append(row)
    return rows


def trade_row_for_csv(row: dict[str, object]) -> dict[str, object]:
    out = dict(row)
    for key in ("open_time", "close_time", "open_bar_m5", "close_bar_m5"):
        value = out.get(key)
        if isinstance(value, datetime):
            out[key] = value.strftime("%Y.%m.%d %H:%M:%S")
    return out


def group_rows(
    trades: list[dict[str, object]],
    key_name: str,
    key_fn,
) -> list[dict[str, object]]:
    buckets: dict[str, list[dict[str, object]]] = defaultdict(list)
    for trade in trades:
        buckets[str(key_fn(trade))].append(trade)
    rows: list[dict[str, object]] = []
    for key, bucket in sorted(buckets.items()):
        stats = calc_stats(bucket)
        avg_r = sum(float(t.get("result_R", 0.0)) for t in bucket) / len(bucket) if bucket else 0.0
        rows.append(
            {
                key_name: key,
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
            }
        )
    return rows


def prefixed_group_rows(trades: list[dict[str, object]], group_name: str, key_fn) -> list[dict[str, object]]:
    buckets: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for trade in trades:
        buckets[(str(trade["period"]), str(key_fn(trade)))].append(trade)
    rows: list[dict[str, object]] = []
    for (period, key), bucket in sorted(buckets.items()):
        for row in group_rows(bucket, group_name, lambda _: key):
            row = {"period": period, **row}
            rows.append(row)
            break
    return rows


def run_stats_row(period: str, context: str, trades: list[dict[str, object]], elapsed: float, raw_audit_rows: int) -> dict[str, object]:
    stats = calc_stats(trades)
    labels = defaultdict(int)
    for trade in trades:
        labels[str(trade.get("wave_audit_label", "unmatched"))] += 1
    return {
        "period": period,
        "context": context,
        "scenario": RUN["scenario"],
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
        "third_wave_initial_trades": labels["third_wave_initial"],
        "third_wave_middle_trades": labels["third_wave_middle"],
        "late_entry_trades": labels["late_entry"],
        "chasing_entry_trades": labels["chasing_entry"],
        "invalid_structure_trades": labels["invalid_structure"],
        "range_noise_trades": labels["range_noise"],
        "unclear_trades": labels["unclear"],
    }


def sample_rows(trades: list[dict[str, object]]) -> list[dict[str, object]]:
    selected: list[dict[str, object]] = []
    groups = [
        ("winning_trade", [t for t in trades if float(t["net_profit"]) > 0]),
        ("losing_trade", [t for t in trades if float(t["net_profit"]) < 0]),
        ("late_entry", [t for t in trades if t.get("wave_audit_label") == "late_entry"]),
        ("invalid_structure", [t for t in trades if t.get("wave_audit_label") == "invalid_structure"]),
    ]
    seen: set[tuple[str, str, str, str]] = set()
    for sample_type, bucket in groups:
        for trade in bucket[:20]:
            key = (str(trade["period"]), str(trade["open_time"]), str(trade["symbol"]), str(trade["direction"]))
            if key in seen:
                continue
            seen.add(key)
            row = trade_row_for_csv(trade)
            row["sample_type"] = sample_type
            selected.append(row)
    return selected


def write_summary(run_rows: list[dict[str, object]], all_trades: list[dict[str, object]]) -> None:
    label_rows = group_rows(all_trades, "wave_audit_label", lambda t: t.get("wave_audit_label", "unmatched"))
    direction_label = group_rows(all_trades, "direction_label", lambda t: f"{t['direction']}:{t.get('wave_audit_label', 'unmatched')}")

    lines = [
        "# ThirdWave Wave Audit Summary",
        "",
        "## Scope",
        "",
        "- Strategy: `ThirdWave_regime_BOTH_all_5m_wave_audit`.",
        "- Periods: 2025-02, 2025-08, 2025-10, and 2026-Q1.",
        "- No parameter optimization was performed.",
        "- Entry logic, SL/TP logic, reward R, spread guard, and Phase 2 scanner logic were not changed.",
        "- Wave Audit is diagnostic-only and logs final entry candidates, execution-blocked candidates, and order events.",
        "",
        "## Code Review Findings",
        "",
        "- Higher timeframe trend uses confirmed fractal pivots on `InpContextTF`; Long requires HH/HL and Short requires LL/LH.",
        "- Mid timeframe pullback uses confirmed fractal lows/highs on `InpPatternTF`; this makes the structure stable but can delay recognition by the fractal span.",
        "- Lower reversal uses the last closed execution bar: Long requires close above the latest minor high and bullish body; Short requires close below the latest minor low and bearish body.",
        "- Entry price is current Ask/Bid after the reclaim/breakdown is detected, not the reclaim/breakdown close itself.",
        "- SL is structure-based from the mid-timeframe pullback extreme plus spread/ATR buffer; TP remains fixed `InpRewardR`.",
        "- The audit therefore focuses on distance from pullback extreme and reclaim/breakdown to entry, because that is where late or chasing entries should show up.",
        "",
        "## Short-Period Results",
        "",
        "| Period | Trades | PF | Expected Payoff | Net | Avg R | Max DD % | third_wave_initial | late_entry | chasing_entry | invalid_structure |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in run_rows:
        lines.append(
            f"| {row['period']} | {row['trades']} | {row['profit_factor']} | {row['expected_payoff']} | {row['net_profit']} | {row['avg_R']} | {row['max_drawdown_pct']} | {row['third_wave_initial_trades']} | {row['late_entry_trades']} | {row['chasing_entry_trades']} | {row['invalid_structure_trades']} |"
        )

    lines.extend(
        [
            "",
            "## Label Results",
            "",
            "| Label | Trades | PF | Expected Payoff | Net | Avg R | Max DD % |",
            "|---|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for row in label_rows:
        lines.append(
            f"| {row['wave_audit_label']} | {row['trades']} | {row['profit_factor']} | {row['expected_payoff']} | {row['net_profit']} | {row['avg_R']} | {row['max_drawdown_pct']} |"
        )

    lines.extend(
        [
            "",
            "## Direction x Label",
            "",
            "| Direction:Label | Trades | PF | Net | Avg R |",
            "|---|---:|---:|---:|---:|",
        ]
    )
    for row in direction_label:
        lines.append(
            f"| {row['direction_label']} | {row['trades']} | {row['profit_factor']} | {row['net_profit']} | {row['avg_R']} |"
        )

    total_trades = len(all_trades)
    label_counts = defaultdict(int)
    label_net = defaultdict(float)
    for trade in all_trades:
        label = str(trade.get("wave_audit_label", "unmatched"))
        label_counts[label] += 1
        label_net[label] += float(trade.get("net_profit", 0.0))
    initial_share = (label_counts["third_wave_initial"] / total_trades * 100.0) if total_trades else 0.0
    chasing_share = (label_counts["chasing_entry"] / total_trades * 100.0) if total_trades else 0.0

    lines.extend(
        [
            "",
            "## Judgement",
            "",
            f"- `third_wave_initial` was only `{label_counts['third_wave_initial']}` of `{total_trades}` trades (`{initial_share:.1f}%`). By this audit definition, the current ThirdWave is not primarily entering at the initial part of wave 3.",
            f"- `chasing_entry` dominated with `{label_counts['chasing_entry']}` trades (`{chasing_share:.1f}%`) and still produced `{label_net['chasing_entry']:.2f}` net. This means the branch is behaving more like trend-continuation momentum after structure confirmation than an early wave-3 entry model.",
            "- The lower reversal check itself is not waiting multiple closed bars; `bars_since_reclaim_or_breakdown` is usually 1. The late/chasing classification is coming mostly from distance from pullback extreme, broad structure SL, and entry position after the move has already expanded.",
            "- Confirmed fractal pivots stabilize the structure but introduce recognition delay. That delay is likely acceptable for trend-following continuation, but it is too slow for a strict third-wave-initial thesis.",
            "- Long and Short are logically symmetric in the code: HH/HL plus minor-high reclaim for Long, LL/LH plus minor-low breakdown for Short. The quality gap should therefore be studied through market regime and distance metrics rather than an obvious directional coding asymmetry.",
            "- XAUUSD is still the dominant source of samples and profit; FX sample size in this short audit is small and should not be treated as a validated common-symbol edge.",
            "",
            "## Next Logic Candidates",
            "",
            "- First candidate: add a pre-entry audit gate around `distance_from_pullback_extreme_to_entry_atr` or `% of impulse consumed`, then test without changing reward/SL parameters.",
            "- Second candidate: improve the lower reversal model to detect an earlier minor HL/LH after reclaim/breakdown instead of using only a confirmed fractal reclaim.",
            "- Third candidate: distinguish continuation-following ThirdWave from strict wave-3-initial ThirdWave as separate strategy modes, because current evidence says the existing branch is the former.",
            "- Avoid optimizing `InpRewardR`, spread guard, or timeframe settings before deciding which of those two entry theses is actually intended.",
        ]
    )

    lines.extend(
        [
            "",
            "## Artifacts",
            "",
            f"- Consolidated audit events: `reports/backtest/{OUT_BASE}_thirdwave_wave_audit.csv`",
            f"- Actual trade audit join: `reports/backtest/{OUT_PREFIX}_trades.csv`",
            f"- Label aggregate: `reports/backtest/{OUT_PREFIX}_by_label.csv`",
            f"- Samples for manual chart review: `reports/backtest/{OUT_PREFIX}_sample_trades.csv`",
        ]
    )
    (BACKTEST / f"{OUT_PREFIX}_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_devlog(run_rows: list[dict[str, object]]) -> None:
    devlog = Path("docs/devlog/2026-06-04-thirdwave-wave-audit.md")
    lines = [
        "# 2026-06-04 - ThirdWave Wave Audit Diagnostics",
        "",
        "## Summary",
        "",
        "- Added diagnostic-only Wave Audit CSV output for ThirdWave final candidates, execution blocks, and order events.",
        "- Reviewed current ThirdWave entry mechanics against the intended third-wave-initial thesis.",
        "- Ran short-period checks instead of full-year optimization runs.",
        "",
        "## Verification",
        "",
        "- Compile evidence: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_compile.txt`.",
        "- Short-period result summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_summary.md`.",
        "- Consolidated audit CSV: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_wave_audit.csv`.",
        "",
        "## Short-Period Runs",
        "",
        "| Period | Trades | PF | Net | Avg R | Max DD % |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for row in run_rows:
        lines.append(
            f"| {row['period']} | {row['trades']} | {row['profit_factor']} | {row['net_profit']} | {row['avg_R']} | {row['max_drawdown_pct']} |"
        )
    lines.extend(
        [
            "",
            "## Decision Note",
            "",
            "- This cycle did not change ThirdWave entry logic or optimize parameters.",
            "- The audit labels are evidence for deciding whether the next logic change should target reclaim timing, pullback validation, or structure invalidation.",
        ]
    )
    devlog.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    all_audit_events: list[dict[str, object]] = []
    all_trade_rows: list[dict[str, object]] = []
    run_rows: list[dict[str, object]] = []
    metrics: dict[str, object] = {"runs": {}}

    for series in SERIES:
        prefix = run_prefix(series["series_name"])
        report_path = BACKTEST / f"{prefix}_report.html"
        trades = parse_mt5_deals(report_path)
        write_trades(BACKTEST / f"{prefix}_trades.csv", trades)

        audit_rows = read_csv_rows(BACKTEST / f"{prefix}_thirdwave_wave_audit.csv")
        context = {
            "period": series["period"],
            "from_date": series["from_date"],
            "to_date": series["to_date"],
            "context": series["context"],
            "scenario": RUN["scenario"],
            "series_name": series["series_name"],
            "run": RUN["run"],
            "prefix": prefix,
        }
        enriched, matched = enrich_trades(trades, audit_rows, context)
        consolidated = build_consolidated_audit_rows(audit_rows, matched, context)
        all_trade_rows.extend(enriched)
        all_audit_events.extend(consolidated)

        elapsed = read_elapsed(series["series_name"])
        run_row = run_stats_row(series["period"], series["context"], enriched, elapsed, len(audit_rows))
        run_rows.append(run_row)
        metrics["runs"][series["period"]] = {
            "stats": serialize_stats(calc_stats(enriched)),
            "elapsed_seconds": elapsed,
            "raw_wave_audit_rows": len(audit_rows),
        }

    write_rows(BACKTEST / f"{OUT_BASE}_thirdwave_wave_audit.csv", all_audit_events)
    write_rows(BACKTEST / f"{OUT_PREFIX}_trades.csv", [trade_row_for_csv(row) for row in all_trade_rows])
    write_rows(BACKTEST / f"{OUT_PREFIX}_run_comparison.csv", run_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_label.csv", group_rows(all_trade_rows, "wave_audit_label", lambda t: t.get("wave_audit_label", "unmatched")))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_direction.csv", group_rows(all_trade_rows, "direction", lambda t: t["direction"]))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_direction_label.csv", group_rows(all_trade_rows, "direction_label", lambda t: f"{t['direction']}:{t.get('wave_audit_label', 'unmatched')}"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_symbol.csv", group_rows(all_trade_rows, "symbol", lambda t: t["symbol"]))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_symbol_label.csv", group_rows(all_trade_rows, "symbol_label", lambda t: f"{t['symbol']}:{t.get('wave_audit_label', 'unmatched')}"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_regime.csv", group_rows(all_trade_rows, "regime", lambda t: t.get("regime", "unmatched")))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_regime_label.csv", group_rows(all_trade_rows, "regime_label", lambda t: f"{t.get('regime', 'unmatched')}:{t.get('wave_audit_label', 'unmatched')}"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_session.csv", group_rows(all_trade_rows, "session", lambda t: t.get("session", "")))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_month.csv", group_rows(all_trade_rows, "month", lambda t: t.get("month", "")))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_pullback_depth.csv", group_rows(all_trade_rows, "pullback_depth_band", lambda t: t.get("pullback_depth_band", "")))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_entry_distance.csv", group_rows(all_trade_rows, "entry_distance_band", lambda t: t.get("entry_distance_band", "")))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_reclaim_bars.csv", group_rows(all_trade_rows, "reclaim_bars_band", lambda t: t.get("reclaim_bars_band", "")))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_sl_atr.csv", group_rows(all_trade_rows, "sl_atr_band", lambda t: t.get("sl_atr_band", "")))
    write_rows(BACKTEST / f"{OUT_PREFIX}_sample_trades.csv", sample_rows(all_trade_rows))
    with (BACKTEST / f"{OUT_PREFIX}_metrics.json").open("w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=2)

    write_summary(run_rows, all_trade_rows)
    write_devlog(run_rows)
    print(json.dumps(run_rows, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
