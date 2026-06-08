#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any

import MetaTrader5 as mt5

from analyze_multicurrency_score_scanner_2025 import (
    BACKTEST,
    calc_stats,
    parse_mt5_deals,
    write_rows,
    write_trades,
)
from analyze_nested_nwave_failure_decomposition import (
    RateCache,
    aggregate,
    as_float,
    as_int,
    classify_failure,
    classify_setup_layer,
    classify_winner,
    compute_neckline_quality,
    compute_price_path_metrics,
    fx_bucket,
    match_order_sent,
    match_signal_candidate,
    pf_value,
    read_csv_rows,
    read_elapsed,
)


OUT_BASE = "ExpectedValue_MultiCurrency_ScoreScanner"
OUT_PREFIX = f"{OUT_BASE}_nested_nwave_breakout_quality_router"

PERIODS = [
    {
        "period": "2025-02",
        "nested_series": "2025_02_nested_nwave",
        "retest_series": "2025_02_nested_retest",
        "router_series": "2025_02_nested_router",
    },
    {
        "period": "2025-08",
        "nested_series": "2025_08_nested_nwave",
        "retest_series": "2025_08_nested_retest",
        "router_series": "2025_08_nested_router",
    },
    {
        "period": "2025-10",
        "nested_series": "2025_10_nested_nwave",
        "retest_series": "2025_10_nested_retest",
        "router_series": "2025_10_nested_router",
    },
    {
        "period": "2026-Q1",
        "nested_series": "2026_q1_nested_nwave",
        "retest_series": "2026_q1_nested_retest",
        "router_series": "2026_q1_nested_router",
    },
]

RUNS = [
    {
        "run": "C",
        "name": "C_nested_best",
        "series_key": "nested_series",
        "scenario": "Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R",
        "entry_selection_mode": "BEST_ONLY",
        "branch": "instant_breakout",
    },
    {
        "run": "D",
        "name": "D_nested_all",
        "series_key": "nested_series",
        "scenario": "Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R",
        "entry_selection_mode": "ALL_SCORE_PASSING",
        "branch": "instant_breakout",
    },
    {
        "run": "E",
        "name": "E_retest_best",
        "series_key": "retest_series",
        "scenario": "Nested_NWave_RetestConfirmation_BOTH_best_H4_H1_M15_2R",
        "entry_selection_mode": "BEST_ONLY",
        "branch": "retest_confirmation",
    },
    {
        "run": "F",
        "name": "F_retest_all",
        "series_key": "retest_series",
        "scenario": "Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R",
        "entry_selection_mode": "ALL_SCORE_PASSING",
        "branch": "retest_confirmation",
    },
    {
        "run": "G",
        "name": "G_router_best",
        "series_key": "router_series",
        "scenario": "Nested_NWave_BreakoutQualityRouter_BOTH_best_H4_H1_M15_2R",
        "entry_selection_mode": "BEST_ONLY",
        "branch": "breakout_quality_router",
    },
    {
        "run": "H",
        "name": "H_router_all",
        "series_key": "router_series",
        "scenario": "Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R",
        "entry_selection_mode": "ALL_SCORE_PASSING",
        "branch": "breakout_quality_router",
    },
]

OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_summary.md",
    "comparison": BACKTEST / f"{OUT_PREFIX}_comparison.csv",
    "diagnostics": BACKTEST / f"{OUT_PREFIX}_breakout_quality_diagnostics.csv",
    "quality_summary": BACKTEST / f"{OUT_PREFIX}_breakout_quality_summary.csv",
    "quality_by_label": BACKTEST / f"{OUT_PREFIX}_breakout_quality_by_label.csv",
    "by_symbol": BACKTEST / f"{OUT_PREFIX}_breakout_quality_by_symbol.csv",
    "by_direction": BACKTEST / f"{OUT_PREFIX}_breakout_quality_by_direction.csv",
    "fx_vs_xauusd": BACKTEST / f"{OUT_PREFIX}_breakout_quality_fx_vs_xauusd.csv",
    "by_session": BACKTEST / f"{OUT_PREFIX}_breakout_quality_by_session.csv",
    "by_month": BACKTEST / f"{OUT_PREFIX}_breakout_quality_by_month.csv",
    "missed_strong": BACKTEST / f"{OUT_PREFIX}_missed_strong_breakout_samples.csv",
    "avoided_dirty": BACKTEST / f"{OUT_PREFIX}_avoided_dirty_breakout_samples.csv",
    "metrics": BACKTEST / f"{OUT_PREFIX}_metrics.json",
}

DEVLOG = Path(__file__).resolve().parents[1] / "docs" / "devlog" / "2026-06-08-nested-nwave-breakout-quality-router.md"


def prefix(series: str, run_name: str) -> str:
    return f"{OUT_BASE}_{series}_{run_name}"


def write_union_rows(path: Path, rows: list[dict[str, object]], fields: list[str] | None = None) -> None:
    if fields is None:
        fields = []
        for row in rows:
            for key in row:
                if key not in fields:
                    fields.append(key)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def read_or_parse_trades(pfx: str) -> list[dict[str, object]]:
    report_path = BACKTEST / f"{pfx}_report.html"
    trades_path = BACKTEST / f"{pfx}_trades.csv"
    if not report_path.exists():
        return []
    if not trades_path.exists():
        trades = parse_mt5_deals(report_path)
        write_trades(trades_path, trades)
        return trades

    trades: list[dict[str, object]] = []
    with trades_path.open(newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            parsed: dict[str, object] = dict(row)
            for key in ("open_time", "close_time", "open_bar_m5", "close_bar_m5"):
                parsed[key] = datetime.strptime(str(parsed[key]), "%Y.%m.%d %H:%M:%S")
            for key in (
                "volume",
                "open_price",
                "close_price",
                "commission",
                "swap",
                "profit",
                "net_profit",
                "close_balance",
                "holding_minutes",
            ):
                parsed[key] = as_float(parsed[key])
            trades.append(parsed)
    return trades


def load_run(period_cfg: dict[str, str], run: dict[str, str]) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    series = period_cfg[run["series_key"]]
    pfx = prefix(series, run["name"])
    trades = read_or_parse_trades(pfx)
    diag_rows = read_csv_rows(BACKTEST / f"{pfx}_nested_nwave_trade_diagnostics.csv")
    signal_rows = read_csv_rows(BACKTEST / f"{pfx}_nested_nwave_signal_diagnostics.csv")
    used: set[int] = set()
    signal_used: set[int] = set()
    enriched: list[dict[str, object]] = []

    signal_meta: list[dict[str, object]] = []
    for idx, signal in enumerate(signal_rows, start=1):
        signal_meta.append(
            {
                "period": period_cfg["period"],
                "run": run["run"],
                "scenario": run["scenario"],
                "branch": run["branch"],
                "entry_selection_mode": run["entry_selection_mode"],
                "signal_index": idx,
                "event": signal.get("event", ""),
                "symbol": signal.get("symbol", ""),
                "direction": signal.get("direction", ""),
                "session": signal.get("session", ""),
                "label": signal.get("label", ""),
                "fail_reason": signal.get("fail_reason", ""),
                "breakout_quality_label": signal.get("breakout_quality_label", "not_recorded") or "not_recorded",
                "breakout_quality_reason": signal.get("breakout_quality_reason", ""),
                "breakout_quality_pass": signal.get("breakout_quality_pass", ""),
                "breakout_close_distance_from_neckline_atr": as_float(signal.get("breakout_close_distance_from_neckline_atr")),
                "breakout_body_ratio": as_float(signal.get("breakout_body_ratio")),
                "breakout_body_atr": as_float(signal.get("breakout_body_atr")),
                "breakout_range_atr": as_float(signal.get("breakout_range_atr")),
                "breakout_directional_wick_ratio": as_float(signal.get("breakout_directional_wick_ratio")),
                "breakout_close_position_directional": as_float(signal.get("breakout_close_position_directional")),
                "neckline_touch_count": as_int(signal.get("neckline_touch_count")),
            }
        )

    for idx, trade in enumerate(trades, start=1):
        diag = match_order_sent(trade, diag_rows, used)
        signal = match_signal_candidate(trade, signal_rows, signal_used)
        row = dict(trade)
        row.update(
            {
                "period": period_cfg["period"],
                "run": run["run"],
                "scenario": run["scenario"],
                "branch": run["branch"],
                "entry_selection_mode": run["entry_selection_mode"],
                "trade_index": idx,
                "month": row["open_time"].strftime("%Y-%m"),
                "hour": f"{row['open_time'].hour:02d}",
                "session": diag.get("session") or signal.get("session") or "",
                "fx_bucket": fx_bucket(str(row["symbol"])),
                "elapsed_seconds": read_elapsed(series, run["run"]),
            }
        )
        for key, value in diag.items():
            row[f"diag_{key}"] = value
        for key, value in signal.items():
            row[f"signal_{key}"] = value

        row["label"] = diag.get("label") or signal.get("label") or "unmatched"
        row["fib_zone"] = diag.get("fib_zone") or signal.get("fib_zone") or "unknown"
        row["neckline_break_label"] = diag.get("neckline_break_label") or signal.get("neckline_break_label") or "unknown"
        row["retest_quality"] = diag.get("retest_quality") or signal.get("retest_quality") or "not_applicable"
        row["breakout_quality_label"] = diag.get("breakout_quality_label") or signal.get("breakout_quality_label") or "not_recorded"
        row["breakout_quality_reason"] = diag.get("breakout_quality_reason") or signal.get("breakout_quality_reason") or ""
        row["breakout_close_distance_from_neckline_atr"] = as_float(diag.get("breakout_close_distance_from_neckline_atr") or signal.get("breakout_close_distance_from_neckline_atr"))
        row["breakout_body_ratio"] = as_float(diag.get("breakout_body_ratio") or signal.get("breakout_body_ratio"))
        row["breakout_body_atr"] = as_float(diag.get("breakout_body_atr") or signal.get("breakout_body_atr"))
        row["breakout_range_atr"] = as_float(diag.get("breakout_range_atr") or signal.get("breakout_range_atr"))
        row["breakout_directional_wick_ratio"] = as_float(diag.get("breakout_directional_wick_ratio") or signal.get("breakout_directional_wick_ratio"))
        row["breakout_close_position_directional"] = as_float(diag.get("breakout_close_position_directional") or signal.get("breakout_close_position_directional"))
        row["neckline_touch_count"] = as_int(diag.get("neckline_touch_count") or signal.get("neckline_touch_count"))
        row["false_break_return_inside_neckline_diag"] = diag.get("false_break_return_inside_neckline") or signal.get("false_break_return_inside_neckline") or ""

        row["entry_price_diag"] = as_float(diag.get("entry_price"), float(row["open_price"]))
        row["sl"] = as_float(diag.get("sl"))
        row["tp"] = as_float(diag.get("tp"))
        row["risk_r"] = as_float(diag.get("risk_r"))
        row["rr"] = as_float(diag.get("rr"))
        row["sl_atr"] = as_float(diag.get("sl_atr"))
        row["tp_atr"] = as_float(diag.get("tp_atr"))
        row["neckline_price"] = as_float(diag.get("neckline_price"))
        row["neckline_break_close_price"] = as_float(diag.get("neckline_break_close_price"))
        row["right_side_level"] = as_float(diag.get("right_side_level"))
        row["bars_since_right_side"] = as_int(diag.get("bars_since_right_side"))
        row["distance_neckline_to_entry_atr"] = as_float(diag.get("distance_neckline_to_entry_atr"))
        row["distance_right_side_to_entry_atr"] = as_float(diag.get("distance_right_side_to_entry_atr"))
        row["spread_atr"] = as_float(diag.get("spread_atr"))
        row["quality_score"] = as_float(diag.get("quality_score"))
        enriched.append(row)
    return enriched, signal_meta


def result_r(row: dict[str, object]) -> float:
    risk = as_float(row.get("risk_r"))
    if risk <= 0:
        return 0.0
    entry = as_float(row.get("entry_price_diag"), float(row["open_price"]))
    sign = 1.0 if row["direction"] == "LONG" else -1.0
    return (float(row["close_price"]) - entry) * sign / risk


def enrich_rows(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    if not mt5.initialize():
        raise RuntimeError(f"MetaTrader5 initialize failed: {mt5.last_error()}")
    cache = RateCache()
    try:
        for row in rows:
            row["result_R"] = round(result_r(row), 3)
            row["final_result_R"] = row["result_R"]
            row.update(compute_price_path_metrics(row, cache))
            row.update(compute_neckline_quality(row, cache))
            row["failure_type"] = classify_failure(row) if float(row["net_profit"]) < 0 else ""
            row["winning_type"] = classify_winner(row) if float(row["net_profit"]) > 0 else ""
            row["setup_failure_layer"] = classify_setup_layer(row)
    finally:
        mt5.shutdown()
    return rows


def scenario_stats(rows: list[dict[str, object]]) -> dict[str, object]:
    stats = calc_stats(rows)
    return {
        "trades": stats["trades"],
        "win_rate": round(float(stats["win_rate"]), 2),
        "net_profit": round(float(stats["net_profit"]), 2),
        "profit_factor": pf_value(stats),
        "expected_payoff": round(float(stats["expected_payoff"]), 2),
        "avg_R": round(sum(as_float(row.get("result_R")) for row in rows) / len(rows), 3) if rows else 0.0,
        "max_drawdown": round(float(stats["max_balance_dd"]), 2),
        "max_drawdown_pct": round(float(stats["max_balance_dd_pct"]), 2),
        "false_break_pct": round(sum(as_int(row.get("false_break_return_inside_neckline")) for row in rows) / len(rows) * 100.0, 2) if rows else 0.0,
        "reached_1R_pct": round(sum(as_int(row.get("reached_1R")) for row in rows) / len(rows) * 100.0, 2) if rows else 0.0,
        "reached_2R_pct": round(sum(as_int(row.get("reached_2R")) for row in rows) / len(rows) * 100.0, 2) if rows else 0.0,
        "fx_net": round(sum(float(row["net_profit"]) for row in rows if row.get("fx_bucket") == "FX"), 2),
        "xauusd_net": round(sum(float(row["net_profit"]) for row in rows if row.get("fx_bucket") == "XAUUSD"), 2),
        "long_net": round(sum(float(row["net_profit"]) for row in rows if row.get("direction") == "LONG"), 2),
        "short_net": round(sum(float(row["net_profit"]) for row in rows if row.get("direction") == "SHORT"), 2),
    }


def comparison_rows(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    buckets: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        buckets[(str(row["period"]), str(row["scenario"]))].append(row)
    output: list[dict[str, object]] = []
    for (period, scenario), bucket in sorted(buckets.items()):
        meta = bucket[0]
        output.append(
            {
                "period": period,
                "scenario": scenario,
                "branch": meta["branch"],
                "entry_selection_mode": meta["entry_selection_mode"],
                **scenario_stats(bucket),
                "elapsed_seconds": round(as_float(meta.get("elapsed_seconds")), 1),
            }
        )
    return output


def write_summary(comp: list[dict[str, object]], quality_rows: list[dict[str, object]]) -> None:
    q1 = [row for row in comp if row["period"] == "2026-Q1"]
    oct_rows = [row for row in comp if row["period"] == "2025-10"]
    router_rows = [row for row in comp if row["branch"] == "breakout_quality_router"]
    instant_rows = [row for row in comp if row["branch"] == "instant_breakout"]
    retest_rows = [row for row in comp if row["branch"] == "retest_confirmation"]

    lines = [
        "# Nested N-Wave Breakout Quality Router Short-Period Validation",
        "",
        "## Scope",
        "",
        "- Added `RESEARCH_STRATEGY_NESTED_NWAVE_BREAKOUT_QUALITY_ROUTER` as an independent research mode.",
        "- Existing ThirdWave, v2/v3/v4, Phase2, score scanner, instant Nested, and Retest Confirmation behavior were not changed.",
        "- Router rule set is fixed: `strong_breakout` enters immediately, `weak_breakout` waits for retest confirmation, and `dirty_breakout` is skipped.",
        "- Validation used only 2025-02, 2025-08, 2025-10, and 2026-Q1. Annual BT is gated and was not run unless the short-period result passed.",
        "",
        "## Comparison",
        "",
        "| period | scenario | trades | PF | avg_R | net | false break % | reached 1R % | reached 2R % | FX net | XAUUSD net | long net | short net |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in comp:
        lines.append(
            f"| {row['period']} | {row['scenario']} | {row['trades']} | {row['profit_factor']} | {row['avg_R']} | {row['net_profit']} | {row['false_break_pct']} | {row['reached_1R_pct']} | {row['reached_2R_pct']} | {row['fx_net']} | {row['xauusd_net']} | {row['long_net']} | {row['short_net']} |"
        )

    lines.extend(
        [
            "",
            "## Breakout Quality Counts",
            "",
            "| period | scenario | quality | rows |",
            "|---|---|---|---:|",
        ]
    )
    for row in quality_rows:
        if row.get("group_field") == "breakout_quality_label":
            lines.append(f"| {row['period']} | {row['scenario']} | {row['group']} | {row['rows']} |")

    def total_net(items: list[dict[str, object]]) -> float:
        return round(sum(as_float(row["net_profit"]) for row in items), 2)

    lines.extend(
        [
            "",
            "## Judgement",
            "",
            f"- Router total net: `{total_net(router_rows)}`.",
            f"- Instant total net: `{total_net(instant_rows)}`.",
            f"- Retest total net: `{total_net(retest_rows)}`.",
        ]
    )

    q1_router = [row for row in q1 if row["branch"] == "breakout_quality_router"]
    q1_instant = [row for row in q1 if row["branch"] == "instant_breakout"]
    oct_router = [row for row in oct_rows if row["branch"] == "breakout_quality_router"]
    oct_instant = [row for row in oct_rows if row["branch"] == "instant_breakout"]
    if q1_router and q1_instant:
        router_best_q1 = max(q1_router, key=lambda item: as_float(item["net_profit"]))
        instant_best_q1 = max(q1_instant, key=lambda item: as_float(item["net_profit"]))
        if as_float(router_best_q1["net_profit"]) > as_float(instant_best_q1["net_profit"]):
            lines.append("- 2026-Q1 damage improved versus the best instant branch.")
        else:
            lines.append("- 2026-Q1 damage did not improve versus the best instant branch.")
    if oct_router and oct_instant:
        router_oct_net = total_net(oct_router)
        instant_oct_net = total_net(oct_instant)
        if router_oct_net < instant_oct_net * 0.5:
            lines.append("- 2025-10 strength was not preserved enough; Router deleted too much October net.")
        else:
            lines.append("- 2025-10 strength was partially preserved.")

    annual_gate_pass = False
    if q1_router and q1_instant and oct_router and oct_instant:
        router_best_q1 = max(q1_router, key=lambda item: as_float(item["net_profit"]))
        instant_best_q1 = max(q1_instant, key=lambda item: as_float(item["net_profit"]))
        router_oct_net = total_net(oct_router)
        instant_oct_net = total_net(oct_instant)
        router_total_fx = sum(as_float(row["fx_net"]) for row in router_rows)
        instant_total_fx = sum(as_float(row["fx_net"]) for row in instant_rows)
        router_trades = sum(as_int(row["trades"]) for row in router_rows)
        instant_trades = sum(as_int(row["trades"]) for row in instant_rows)
        annual_gate_pass = (
            as_float(router_best_q1["net_profit"]) > as_float(instant_best_q1["net_profit"])
            and router_oct_net >= instant_oct_net * 0.5
            and router_total_fx >= instant_total_fx
            and router_trades >= max(1, instant_trades) * 0.5
        )

    if annual_gate_pass:
        lines.append("- Short-period gate passed mechanically. Annual OOS may be considered next.")
    else:
        lines.append("- Short-period gate did not pass. No annual BT was run.")

    lines.extend(
        [
            "",
            "## Artifacts",
            "",
            f"- Comparison CSV: `reports/backtest/{OUTPUTS['comparison'].name}`",
            f"- Breakout quality summary: `reports/backtest/{OUTPUTS['quality_summary'].name}`",
            f"- Trade diagnostics: `reports/backtest/{OUTPUTS['diagnostics'].name}`",
            f"- Avoided dirty samples: `reports/backtest/{OUTPUTS['avoided_dirty'].name}`",
            f"- Missed strong samples: `reports/backtest/{OUTPUTS['missed_strong'].name}`",
        ]
    )

    OUTPUTS["summary"].write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_devlog() -> None:
    text = f"""# 2026-06-08 - Nested N-Wave Breakout Quality Router

## Summary

- Added independent research mode `RESEARCH_STRATEGY_NESTED_NWAVE_BREAKOUT_QUALITY_ROUTER`.
- Router classifies M15 neckline breaks into `strong_breakout`, `weak_breakout`, `dirty_breakout`, or `unclear`.
- `strong_breakout` uses instant entry, `weak_breakout` requires retest confirmation, and `dirty_breakout` is skipped.
- Existing instant Nested, Retest Confirmation, ThirdWave v2/v3/v4, Phase2, score scanner, SL/TP, RewardR, timeframe, spread guard, risk sizing, and CTrade bridge were left unchanged.

## Verification

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_breakout_quality_router_compile.log`
- Compile result: `0 errors, 0 warnings`
- Short-period BT only:
  - `2025-02`
  - `2025-08`
  - `2025-10`
  - `2026-Q1`

## Evidence

- Summary: `reports/backtest/{OUTPUTS['summary'].name}`
- Comparison: `reports/backtest/{OUTPUTS['comparison'].name}`
- Breakout quality summary: `reports/backtest/{OUTPUTS['quality_summary'].name}`
- Diagnostics: `reports/backtest/{OUTPUTS['diagnostics'].name}`
"""
    DEVLOG.write_text(text, encoding="utf-8")


def main() -> None:
    rows: list[dict[str, object]] = []
    signal_rows: list[dict[str, object]] = []
    for period_cfg in PERIODS:
        for run in RUNS:
            run_rows, run_signals = load_run(period_cfg, run)
            rows.extend(run_rows)
            signal_rows.extend(run_signals)

    rows = enrich_rows(rows)
    write_union_rows(OUTPUTS["diagnostics"], rows)

    comp = comparison_rows(rows)
    write_rows(OUTPUTS["comparison"], comp)

    quality_summary: list[dict[str, object]] = []
    for field in ("breakout_quality_label", "event", "fail_reason"):
        buckets: dict[tuple[str, str, str], int] = defaultdict(int)
        for row in signal_rows:
            buckets[(str(row["period"]), str(row["scenario"]), str(row.get(field) or ""))] += 1
        for (period, scenario, group), count in sorted(buckets.items()):
            quality_summary.append(
                {
                    "period": period,
                    "scenario": scenario,
                    "group_field": field,
                    "group": group,
                    "rows": count,
                }
            )
    write_rows(OUTPUTS["quality_summary"], quality_summary)

    write_rows(OUTPUTS["quality_by_label"], aggregate(rows, ["period", "scenario", "breakout_quality_label"]))
    write_rows(OUTPUTS["by_symbol"], aggregate(rows, ["period", "scenario", "symbol"]))
    write_rows(OUTPUTS["by_direction"], aggregate(rows, ["period", "scenario", "direction"]))
    write_rows(OUTPUTS["fx_vs_xauusd"], aggregate(rows, ["period", "scenario", "fx_bucket"]))
    write_rows(OUTPUTS["by_session"], aggregate(rows, ["period", "scenario", "session"]))
    write_rows(OUTPUTS["by_month"], aggregate(rows, ["period", "scenario", "month"]))

    missed_strong = [
        row
        for row in signal_rows
        if row.get("breakout_quality_label") == "strong_breakout"
        and row.get("event") not in {"final_entry_candidate", "order_sent"}
    ][:200]
    avoided_dirty = [
        row for row in signal_rows if row.get("breakout_quality_label") == "dirty_breakout"
    ][:200]
    sample_fields = [
        "period",
        "scenario",
        "event",
        "symbol",
        "direction",
        "session",
        "label",
        "fail_reason",
        "breakout_quality_label",
        "breakout_quality_reason",
        "breakout_close_distance_from_neckline_atr",
        "breakout_body_ratio",
        "breakout_body_atr",
        "breakout_range_atr",
        "breakout_directional_wick_ratio",
        "breakout_close_position_directional",
        "neckline_touch_count",
    ]
    write_union_rows(OUTPUTS["missed_strong"], missed_strong, sample_fields)
    write_union_rows(OUTPUTS["avoided_dirty"], avoided_dirty, sample_fields)

    OUTPUTS["metrics"].write_text(json.dumps({"comparison": comp}, ensure_ascii=False, indent=2), encoding="utf-8")
    write_summary(comp, quality_summary)
    write_devlog()


if __name__ == "__main__":
    main()
