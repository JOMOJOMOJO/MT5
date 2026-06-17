#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import defaultdict
from pathlib import Path

from analyze_nested_context_router_r12 import (
    BACKTEST,
    OUT_BASE,
    as_float,
    fx_bucket,
    group_rows,
    load_order_sent_rows,
    match_diag,
    prefix,
    price_result_r,
    read_elapsed,
    read_or_parse_trades,
    summarize_trades,
    write_rows,
)


OUT_PREFIX = f"{OUT_BASE}_nested_context_router_r12_annual"
PERIODS = [
    ("2024", "2024_nested_context_r12_annual"),
    ("2025", "2025_nested_context_r12_annual"),
    ("2026YTD", "2026_ytd_nested_context_r12_annual"),
]
RUNS = [
    ("A", "A_nested_all_r12", "instant_all_r12"),
    ("E", "E_context_router_v2_all_r12", "context_router_v2_all_r12"),
    ("F", "F_context_router_v3_all_r12", "context_router_v3_all_r12"),
]

OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_summary.md",
    "comparison": BACKTEST / f"{OUT_PREFIX}_comparison.csv",
    "trade_rows": BACKTEST / f"{OUT_PREFIX}_trade_rows.csv",
    "by_symbol": BACKTEST / f"{OUT_PREFIX}_by_symbol.csv",
    "by_direction": BACKTEST / f"{OUT_PREFIX}_by_direction.csv",
    "fx_vs_xauusd": BACKTEST / f"{OUT_PREFIX}_fx_vs_xauusd.csv",
    "by_label": BACKTEST / f"{OUT_PREFIX}_by_label.csv",
    "metrics": BACKTEST / f"{OUT_PREFIX}_metrics.json",
}


def main() -> None:
    all_rows: list[dict[str, object]] = []
    comparison: list[dict[str, object]] = []

    for period, series in PERIODS:
        elapsed = read_elapsed(series)
        for run_id, run_name, scenario in RUNS:
            pfx = prefix(series, run_name)
            trades = read_or_parse_trades(pfx)
            sent_rows = load_order_sent_rows(pfx)
            used: set[int] = set()
            enriched: list[dict[str, object]] = []
            for index, trade in enumerate(trades, start=1):
                diag = match_diag(trade, sent_rows, used)
                row = {
                    "period": period,
                    "run": run_id,
                    "scenario": scenario,
                    "trade_index": index,
                    "open_time": trade["open_time"],
                    "close_time": trade["close_time"],
                    "symbol": trade["symbol"],
                    "fx_vs_xauusd": fx_bucket(trade["symbol"]),
                    "direction": trade["direction"],
                    "net_profit": round(as_float(trade["net_profit"]), 2),
                    "result_R": round(price_result_r(trade, diag), 3),
                    "label": diag.get("label", "unmatched") if diag else "unmatched",
                    "breakout_quality_label": diag.get("breakout_quality_label", "unmatched") if diag else "unmatched",
                    "context_quality_label": diag.get("context_quality_label", "unmatched") if diag else "unmatched",
                    "context_quality_score": round(as_float(diag.get("context_quality_score")), 2) if diag else 0.0,
                    "sl_atr": round(as_float(diag.get("sl_atr")), 2) if diag else 0.0,
                    "breakout_body_atr": round(as_float(diag.get("breakout_body_atr")), 2) if diag else 0.0,
                }
                enriched.append(row)
                all_rows.append(row)
            comp = {
                "period": period,
                "run": run_id,
                "scenario": scenario,
                "elapsed_seconds": round(elapsed.get(run_id, 0.0), 1),
            }
            comp.update(summarize_trades(enriched))
            comp["fx_net"] = round(sum(as_float(r["net_profit"]) for r in enriched if r["fx_vs_xauusd"] == "FX"), 2)
            comp["xauusd_net"] = round(sum(as_float(r["net_profit"]) for r in enriched if r["fx_vs_xauusd"] == "XAUUSD"), 2)
            comp["long_net"] = round(sum(as_float(r["net_profit"]) for r in enriched if r["direction"] == "LONG"), 2)
            comp["short_net"] = round(sum(as_float(r["net_profit"]) for r in enriched if r["direction"] == "SHORT"), 2)
            comparison.append(comp)

    write_rows(OUTPUTS["trade_rows"], all_rows)
    write_rows(OUTPUTS["comparison"], comparison)
    write_rows(OUTPUTS["by_symbol"], group_rows(all_rows, ["period", "scenario", "symbol"]))
    write_rows(OUTPUTS["by_direction"], group_rows(all_rows, ["period", "scenario", "direction"]))
    write_rows(OUTPUTS["fx_vs_xauusd"], group_rows(all_rows, ["period", "scenario", "fx_vs_xauusd"]))
    write_rows(OUTPUTS["by_label"], group_rows(all_rows, ["period", "scenario", "label"]))

    totals = group_rows(all_rows, ["scenario"])
    fx_totals = defaultdict(float)
    xau_totals = defaultdict(float)
    for row in all_rows:
        if row["fx_vs_xauusd"] == "FX":
            fx_totals[row["scenario"]] += as_float(row["net_profit"])
        else:
            xau_totals[row["scenario"]] += as_float(row["net_profit"])

    lines = [
        "# Nested Context Router RR 1.2 Annual Check",
        "",
        "Annual check compares the original instant all-candidates RR 1.2 branch against `ContextQualityRouterV2` only.",
        "",
        "| period | scenario | trades | PF | avg_R | net | maxDD% | FX net | XAUUSD net | long net | short net |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in comparison:
        lines.append(
            f"| {row['period']} | {row['scenario']} | {row['trades']} | {row['profit_factor']} | {row['avg_R']} | {row['net_profit']} | {row['max_dd_pct']} | {row['fx_net']} | {row['xauusd_net']} | {row['long_net']} | {row['short_net']} |"
        )
    lines.extend([
        "",
        "## Aggregate",
        "",
        "| scenario | trades | PF | avg_R | net | maxDD% | FX net | XAUUSD net |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
    ])
    for row in totals:
        lines.append(
            f"| {row['scenario']} | {row['trades']} | {row['profit_factor']} | {row['avg_R']} | {row['net_profit']} | {row['max_dd_pct']} | {fx_totals[row['scenario']]:.2f} | {xau_totals[row['scenario']]:.2f} |"
        )
    lines.extend([
        "",
        "## Judgement",
        "",
        "- This is a robustness check, not a promotion test.",
        "- If v2 fails in two of three annual periods, keep it as a diagnostic branch rather than promoting it.",
        "",
    ])
    OUTPUTS["summary"].write_text("\n".join(lines), encoding="utf-8")
    OUTPUTS["metrics"].write_text(json.dumps({"comparison": comparison, "totals": totals}, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    print(json.dumps({"comparison": comparison, "totals": totals}, ensure_ascii=False, indent=2, default=str))


if __name__ == "__main__":
    main()
