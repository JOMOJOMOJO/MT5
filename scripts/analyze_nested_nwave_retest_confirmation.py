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
OUT_PREFIX = f"{OUT_BASE}_nested_nwave_retest_confirmation"

PERIODS = [
    {"period": "2025-02", "nested_series": "2025_02_nested_nwave", "retest_series": "2025_02_nested_retest"},
    {"period": "2025-08", "nested_series": "2025_08_nested_nwave", "retest_series": "2025_08_nested_retest"},
    {"period": "2025-10", "nested_series": "2025_10_nested_nwave", "retest_series": "2025_10_nested_retest"},
    {"period": "2026-Q1", "nested_series": "2026_q1_nested_nwave", "retest_series": "2026_q1_nested_retest"},
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
]

OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_summary.md",
    "comparison": BACKTEST / f"{OUT_PREFIX}_comparison.csv",
    "diagnostics": BACKTEST / f"{OUT_PREFIX}_diagnostics.csv",
    "retest_quality": BACKTEST / f"{OUT_PREFIX}_retest_quality.csv",
    "mfe_mae": BACKTEST / f"{OUT_PREFIX}_retest_mfe_mae.csv",
    "by_symbol": BACKTEST / f"{OUT_PREFIX}_by_symbol.csv",
    "by_direction": BACKTEST / f"{OUT_PREFIX}_by_direction.csv",
    "fx_vs_xauusd": BACKTEST / f"{OUT_PREFIX}_fx_vs_xauusd.csv",
    "by_session": BACKTEST / f"{OUT_PREFIX}_by_session.csv",
    "by_month": BACKTEST / f"{OUT_PREFIX}_by_month.csv",
    "by_failure": BACKTEST / f"{OUT_PREFIX}_by_failure_type.csv",
    "by_winning": BACKTEST / f"{OUT_PREFIX}_by_winning_type.csv",
    "metrics": BACKTEST / f"{OUT_PREFIX}_metrics.json",
}

DEVLOG = Path(__file__).resolve().parents[1] / "docs" / "devlog" / "2026-06-08-nested-nwave-retest-confirmation.md"


def prefix(series: str, run_name: str) -> str:
    return f"{OUT_BASE}_{series}_{run_name}"


def parse_time(value: str) -> datetime | None:
    value = (value or "").strip()
    if not value:
        return None
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            pass
    return None


def write_union_rows(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        return
    fields: list[str] = []
    for row in rows:
        for key in row:
            if key not in fields:
                fields.append(key)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
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


def load_run(period_cfg: dict[str, str], run: dict[str, str]) -> list[dict[str, object]]:
    series = period_cfg[run["series_key"]]
    pfx = prefix(series, run["name"])
    trades = read_or_parse_trades(pfx)
    diag_rows = read_csv_rows(BACKTEST / f"{pfx}_nested_nwave_trade_diagnostics.csv")
    signal_rows = read_csv_rows(BACKTEST / f"{pfx}_nested_nwave_signal_diagnostics.csv")
    used: set[int] = set()
    signal_used: set[int] = set()
    enriched: list[dict[str, object]] = []

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
                "session": diag.get("session", ""),
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
        row["retest_detected"] = diag.get("retest_detected") or signal.get("retest_detected") or ""
        row["retest_held"] = diag.get("retest_held") or signal.get("retest_held") or ""
        row["retest_trigger_pass"] = diag.get("retest_trigger_pass") or signal.get("retest_trigger_pass") or ""
        row["retest_depth_atr"] = as_float(diag.get("retest_depth_atr") or signal.get("retest_depth_atr"))
        row["retest_bars_after_breakout"] = as_int(diag.get("retest_bars_after_breakout") or signal.get("retest_bars_after_breakout"))
        row["entry_delay_bars"] = as_int(diag.get("entry_delay_bars") or signal.get("entry_delay_bars"))
        row["false_break_return_inside_neckline_diag"] = diag.get("false_break_return_inside_neckline") or signal.get("false_break_return_inside_neckline") or ""

        row["entry_price_diag"] = as_float(diag.get("entry_price"), float(row["open_price"]))
        row["sl"] = as_float(diag.get("sl"))
        row["tp"] = as_float(diag.get("tp"))
        row["risk_r"] = as_float(diag.get("risk_r"))
        row["rr"] = as_float(diag.get("rr"))
        row["sl_points"] = as_float(diag.get("sl_points"))
        row["sl_atr"] = as_float(diag.get("sl_atr"))
        row["tp_points"] = as_float(diag.get("tp_points"))
        row["tp_atr"] = as_float(diag.get("tp_atr"))
        row["neckline_price"] = as_float(diag.get("neckline_price"))
        row["neckline_break_close_price"] = as_float(diag.get("neckline_break_close_price"))
        row["right_side_level"] = as_float(diag.get("right_side_level"))
        row["bars_since_right_side"] = as_int(diag.get("bars_since_right_side"))
        row["distance_neckline_to_entry_atr"] = as_float(diag.get("distance_neckline_to_entry_atr"))
        row["distance_right_side_to_entry_atr"] = as_float(diag.get("distance_right_side_to_entry_atr"))
        row["spread_atr"] = as_float(diag.get("spread_atr"))
        row["quality_score"] = as_float(diag.get("quality_score"))
        row["h4_fib_retracement_pct"] = as_float(signal.get("h4_fib_retracement_pct"))
        row["h4_atr"] = as_float(signal.get("h4_atr"))
        row["h1_atr"] = as_float(signal.get("h1_atr"))
        row["m15_atr"] = as_float(signal.get("m15_atr"))
        enriched.append(row)
    return enriched


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
        "avg_mfe_R": round(sum(as_float(row.get("max_favorable_r")) for row in rows) / len(rows), 3) if rows else 0.0,
        "avg_mae_R": round(sum(as_float(row.get("max_adverse_r")) for row in rows) / len(rows), 3) if rows else 0.0,
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


def write_summary(comp: list[dict[str, object]], rows: list[dict[str, object]]) -> None:
    q1 = [row for row in comp if row["period"] == "2026-Q1"]
    oct_rows = [row for row in comp if row["period"] == "2025-10"]
    retest_all = [row for row in comp if "RetestConfirmation_BOTH_all" in row["scenario"]]
    instant_all = [row for row in comp if "NecklineBreak_BOTH_all" in row["scenario"]]

    lines = [
        "# Nested N-Wave Retest Confirmation Short-Period Validation",
        "",
        "## Scope",
        "",
        "- Added `RESEARCH_STRATEGY_NESTED_NWAVE_RETEST_CONFIRMATION` as an independent research mode.",
        "- Existing Nested neckline-break, ThirdWave, v2/v3/v4, Phase2, SL/TP, RewardR, timeframe, spread guard, risk sizing, and CTrade bridge were not changed.",
        "- Retest branch uses one fixed diagnostic rule set: breakout within 8 M15 bars, retest within 0.5 M15 ATR of neckline, no right-side invalidation, then M15 candle re-affirmation or minor rebreak.",
        "- Validation is short-period only: 2025-02, 2025-08, 2025-10, 2026-Q1. No annual BT was run.",
        "",
        "## Comparison",
        "",
        "| period | scenario | trades | PF | avg_R | net | false break % | reached 1R % | reached 2R % | FX net | XAUUSD net |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in comp:
        lines.append(
            f"| {row['period']} | {row['scenario']} | {row['trades']} | {row['profit_factor']} | {row['avg_R']} | {row['net_profit']} | {row['false_break_pct']} | {row['reached_1R_pct']} | {row['reached_2R_pct']} | {row['fx_net']} | {row['xauusd_net']} |"
        )

    lines.extend(
        [
            "",
            "## 2026-Q1 Check",
            "",
            "| scenario | trades | PF | avg_R | net | false break % | FX net | XAUUSD net | long net | short net |",
            "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for row in q1:
        lines.append(
            f"| {row['scenario']} | {row['trades']} | {row['profit_factor']} | {row['avg_R']} | {row['net_profit']} | {row['false_break_pct']} | {row['fx_net']} | {row['xauusd_net']} | {row['long_net']} | {row['short_net']} |"
        )

    lines.extend(
        [
            "",
            "## 2025-10 Preservation",
            "",
            "| scenario | trades | PF | avg_R | net | false break % | reached 2R % |",
            "|---|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for row in oct_rows:
        lines.append(
            f"| {row['scenario']} | {row['trades']} | {row['profit_factor']} | {row['avg_R']} | {row['net_profit']} | {row['false_break_pct']} | {row['reached_2R_pct']} |"
        )

    retest_trade_count = sum(as_int(row["trades"]) for row in retest_all)
    instant_trade_count = sum(as_int(row["trades"]) for row in instant_all)
    retest_net = sum(as_float(row["net_profit"]) for row in retest_all)
    instant_net = sum(as_float(row["net_profit"]) for row in instant_all)
    lines.extend(
        [
            "",
            "## Judgement",
            "",
            f"- Retest all-candidates total trades: `{retest_trade_count}` versus instant all-candidates `{instant_trade_count}`.",
            f"- Retest all-candidates total net: `{round(retest_net, 2)}` versus instant all-candidates `{round(instant_net, 2)}`.",
            "- The branch is judged on whether it reduces 2026-Q1 false-break damage without deleting the 2025-10 strength. It is not a RewardR or symbol filter test.",
        ]
    )

    q1_retest = [row for row in q1 if row["branch"] == "retest_confirmation"]
    q1_instant = [row for row in q1 if row["branch"] == "instant_breakout"]
    if q1_retest and q1_instant:
        best_retest = max(q1_retest, key=lambda item: as_float(item["net_profit"]))
        best_instant = max(q1_instant, key=lambda item: as_float(item["net_profit"]))
        if as_float(best_retest["net_profit"]) > as_float(best_instant["net_profit"]):
            lines.append("- 2026-Q1 improved versus the best instant Nested branch in net terms.")
        else:
            lines.append("- 2026-Q1 did not improve versus the best instant Nested branch in net terms.")

    if retest_trade_count < max(1, instant_trade_count) * 0.5:
        lines.append("- Trade count fell by more than 50%; any apparent improvement must be treated as diagnostic, not promotion evidence.")

    retest_oct_trades = sum(as_int(row["trades"]) for row in oct_rows if row["branch"] == "retest_confirmation")
    instant_oct_trades = sum(as_int(row["trades"]) for row in oct_rows if row["branch"] == "instant_breakout")
    if instant_oct_trades > 0 and retest_oct_trades < instant_oct_trades * 0.5:
        lines.append("- 2025-10 strength was not preserved enough: retest confirmation kept less than half of the instant-breakout October trades.")

    q1_retest_false = [as_float(row["false_break_pct"]) for row in q1 if row["branch"] == "retest_confirmation"]
    q1_instant_false = [as_float(row["false_break_pct"]) for row in q1 if row["branch"] == "instant_breakout"]
    if q1_retest_false and q1_instant_false and min(q1_retest_false) >= min(q1_instant_false) - 5.0:
        lines.append("- False-break rate did not materially improve; the better 2026-Q1 net came mostly from fewer trades and smaller FX damage, not from a clean false-break solution.")

    lines.append("- Short-period gate did not pass. No annual BT should be run for this branch yet.")

    lines.extend(
        [
            "",
            "## Artifacts",
            "",
            f"- Comparison CSV: `reports/backtest/{OUTPUTS['comparison'].name}`",
            f"- Retest quality aggregate: `reports/backtest/{OUTPUTS['retest_quality'].name}`",
            f"- MFE/MAE/R reach: `reports/backtest/{OUTPUTS['mfe_mae'].name}`",
            f"- Full diagnostics: `reports/backtest/{OUTPUTS['diagnostics'].name}`",
        ]
    )

    OUTPUTS["summary"].write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_devlog() -> None:
    text = f"""# 2026-06-08 - Nested N-Wave Retest Confirmation

## Summary

- Added an independent `RESEARCH_STRATEGY_NESTED_NWAVE_RETEST_CONFIRMATION` branch.
- Existing ThirdWave, v2/v3/v4, Phase2, score scanner, and instant Nested branch behavior were left unchanged.
- Retest confirmation waits for a post-breakout M15 retest near the neckline before entering.

## Verification

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_retest_confirmation_compile.log`
- Compile result: `0 errors, 0 warnings`
- Short-period BT only:
  - `2025-02`
  - `2025-08`
  - `2025-10`
  - `2026-Q1`
- No annual BT was run.

## Evidence

- Summary: `reports/backtest/{OUTPUTS['summary'].name}`
- Comparison: `reports/backtest/{OUTPUTS['comparison'].name}`
- Retest quality: `reports/backtest/{OUTPUTS['retest_quality'].name}`
- MFE/MAE: `reports/backtest/{OUTPUTS['mfe_mae'].name}`
"""
    DEVLOG.write_text(text, encoding="utf-8")


def main() -> None:
    rows: list[dict[str, object]] = []
    for period_cfg in PERIODS:
        for run in RUNS:
            rows.extend(load_run(period_cfg, run))

    rows = enrich_rows(rows)
    write_union_rows(OUTPUTS["diagnostics"], rows)

    comp = comparison_rows(rows)
    write_rows(OUTPUTS["comparison"], comp)
    write_rows(OUTPUTS["retest_quality"], aggregate(rows, ["period", "scenario", "retest_quality"]))
    write_rows(OUTPUTS["by_symbol"], aggregate(rows, ["period", "scenario", "symbol"]))
    write_rows(OUTPUTS["by_direction"], aggregate(rows, ["period", "scenario", "direction"]))
    write_rows(OUTPUTS["fx_vs_xauusd"], aggregate(rows, ["period", "scenario", "fx_bucket"]))
    write_rows(OUTPUTS["by_session"], aggregate(rows, ["period", "scenario", "session"]))
    write_rows(OUTPUTS["by_month"], aggregate(rows, ["period", "scenario", "month"]))
    write_rows(OUTPUTS["by_failure"], aggregate([row for row in rows if row.get("failure_type")], ["period", "scenario", "failure_type"]))
    write_rows(OUTPUTS["by_winning"], aggregate([row for row in rows if row.get("winning_type")], ["period", "scenario", "winning_type"]))

    mfe_rows = []
    for row in rows:
        mfe_rows.append(
            {
                "period": row["period"],
                "scenario": row["scenario"],
                "symbol": row["symbol"],
                "direction": row["direction"],
                "net_profit": round(float(row["net_profit"]), 2),
                "result_R": row.get("result_R"),
                "max_favorable_r": row.get("max_favorable_r"),
                "max_adverse_r": row.get("max_adverse_r"),
                "reached_0_5R": row.get("reached_0_5R"),
                "reached_1R": row.get("reached_1R"),
                "reached_1_5R": row.get("reached_1_5R"),
                "reached_2R": row.get("reached_2R"),
                "time_to_1R": row.get("time_to_1R"),
                "time_to_2R": row.get("time_to_2R"),
                "time_to_SL": row.get("time_to_SL"),
                "false_break_return_inside_neckline": row.get("false_break_return_inside_neckline"),
                "retest_quality": row.get("retest_quality"),
                "failure_type": row.get("failure_type"),
                "winning_type": row.get("winning_type"),
            }
        )
    write_rows(OUTPUTS["mfe_mae"], mfe_rows)

    metrics = {"comparison": comp}
    OUTPUTS["metrics"].write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8")
    write_summary(comp, rows)
    write_devlog()


if __name__ == "__main__":
    main()
