#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from pathlib import Path

from analyze_multicurrency_score_scanner_2025 import BACKTEST, parse_mt5_deals, write_trades
from analyze_fixed_condition_bt import OUT_BASE, ROOT, as_float, bool_text, bool_value, match_diag, read_order_sent_rows, write_rows
from analyze_fx_only_2025_condition_factorial import (
    ALL_CONDITIONS,
    FX_SYMBOLS,
    RateCache,
    distribution,
    long_failure_type,
    md_link,
    r_reach_metrics,
    session_from_hour,
    stats_for,
)
from analyze_relaxed_fx_only_2025_condition_factorial import add_buckets, condition_subset, load_broad_rows


RUN_PREFIX = f"{OUT_BASE}_fxbroad2025_A_broad_fx_entry_candidates"
OUT_PREFIX = f"{OUT_BASE}_broad_fx_only_2025_entry_candidates"

NEW_CONDITIONS = [
    "cond_m15_micro_break",
    "cond_m15_short_ma_reversal",
    "cond_m15_candle_reversal",
]
ALL_OUTPUT_CONDITIONS = ALL_CONDITIONS + [item for item in NEW_CONDITIONS if item not in ALL_CONDITIONS]

OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_summary.md",
    "comparison": BACKTEST / f"{OUT_PREFIX}_comparison.csv",
    "trades": BACKTEST / f"{OUT_PREFIX}_trades.csv",
    "by_symbol": BACKTEST / f"{OUT_PREFIX}_by_symbol.csv",
    "by_month": BACKTEST / f"{OUT_PREFIX}_by_month.csv",
    "by_direction": BACKTEST / f"{OUT_PREFIX}_by_direction.csv",
    "by_m15_trigger": BACKTEST / f"{OUT_PREFIX}_by_m15_trigger.csv",
    "long_failure_summary": BACKTEST / f"{OUT_PREFIX}_long_failure_summary.md",
    "metrics": BACKTEST / f"{OUT_PREFIX}_metrics.json",
}


def load_new_rows() -> list[dict[str, object]]:
    report = BACKTEST / f"{RUN_PREFIX}_report.html"
    if not report.exists():
        raise FileNotFoundError(report)
    trades = parse_mt5_deals(report)
    write_trades(BACKTEST / f"{RUN_PREFIX}_trades.csv", trades)
    sent = read_order_sent_rows(RUN_PREFIX)
    cache = RateCache()

    mt5_ready = False
    try:
        import MetaTrader5 as mt5

        mt5_ready = bool(mt5.initialize())
        if mt5_ready:
            for symbol in FX_SYMBOLS:
                mt5.symbol_select(symbol, True)
    except ImportError:
        mt5 = None

    used: set[int] = set()
    rows: list[dict[str, object]] = []
    for idx, trade in enumerate(trades, start=1):
        symbol = str(trade["symbol"]).upper()
        if symbol not in FX_SYMBOLS:
            continue
        diag = match_diag(trade, sent, used)
        open_time = trade["open_time"]
        row: dict[str, object] = {
            "trade_index": idx,
            "time": open_time.strftime("%Y.%m.%d %H:%M:%S"),
            "close_time": trade["close_time"].strftime("%Y.%m.%d %H:%M:%S"),
            "symbol": symbol,
            "direction": trade["direction"],
            "month": open_time.strftime("%Y-%m"),
            "session": diag.get("session", "") if diag and diag.get("session") else session_from_hour(open_time.hour),
            "entry_price": diag.get("entry_price", "") if diag else trade.get("open_price", ""),
            "close_price": trade.get("close_price", ""),
            "sl": diag.get("sl", "") if diag else "",
            "tp": diag.get("tp", "") if diag else "",
            "net_profit": round(as_float(trade.get("net_profit")), 2),
            "source_scenario": "B_broad_hard_gate_reduced",
        }

        from analyze_fx_only_2025_condition_factorial import price_result_r

        row["result_R"] = round(price_result_r(trade, diag), 3)
        row.update(r_reach_metrics(trade, diag, cache if mt5_ready else None))
        if diag:
            for key in (
                "h4_bias_state",
                "h4_ma_state",
                "h4_dow_state",
                "h4_fib_zone",
                "h4_fib_retracement_pct",
                "h1_pullback_type",
                "h1_prev_extreme_break_state",
                "h1_counter_nwave_state",
                "h1_counter_wave_atr",
                "bos_level_type",
                "true_bos_level",
                "m15_trigger_type",
                "room_to_1r",
                "room_to_2r",
                "nearest_obstacle_type",
                "nearest_obstacle_price",
                "sl_atr",
                "distance_bos_to_entry_atr",
                "distance_neckline_to_entry_atr",
                "label",
            ):
                row[key] = diag.get(key, "")
            for key in ALL_OUTPUT_CONDITIONS:
                row[key] = bool_text(bool_value(diag.get(key)))
        for key in ALL_OUTPUT_CONDITIONS:
            row.setdefault(key, "false")
        add_buckets(row)
        rows.append(row)

    if mt5_ready and mt5 is not None:
        mt5.shutdown()
    return rows


def both_conditions(rows: list[dict[str, object]], *conditions: str) -> list[dict[str, object]]:
    return [row for row in rows if all(bool_value(row.get(condition)) for condition in conditions)]


def scenario_rows(broad: list[dict[str, object]], new_rows: list[dict[str, object]]) -> dict[str, list[dict[str, object]]]:
    return {
        "A_current_broad_fx_only": broad,
        "B_broad_hard_gate_reduced": new_rows,
        "C_broad_reduced_room_to_2r": condition_subset(new_rows, "cond_room_to_2r"),
        "D_broad_reduced_h4_ma_bias": condition_subset(new_rows, "cond_h4_bias_ma"),
        "E_broad_reduced_m15_close_bos": condition_subset(new_rows, "cond_m15_close_bos"),
        "F_broad_reduced_room_to_2r_h4_ma": both_conditions(new_rows, "cond_room_to_2r", "cond_h4_bias_ma"),
    }


def comparison_rows(scenarios: dict[str, list[dict[str, object]]]) -> list[dict[str, object]]:
    return [{"scenario": scenario, **stats_for(items)} for scenario, items in scenarios.items()]


def group_outputs(scenarios: dict[str, list[dict[str, object]]], key: str) -> list[dict[str, object]]:
    output = []
    for scenario, items in scenarios.items():
        groups: dict[str, list[dict[str, object]]] = {}
        for row in items:
            groups.setdefault(str(row.get(key, "")), []).append(row)
        for group, bucket in sorted(groups.items()):
            output.append({"scenario": scenario, "group": group, **stats_for(bucket)})
    return output


def long_failure_rows(scenarios: dict[str, list[dict[str, object]]]) -> list[dict[str, object]]:
    output = []
    for scenario, items in scenarios.items():
        losses = []
        for row in items:
            failure = long_failure_type(row)
            if failure:
                clone = dict(row)
                clone["failure_type"] = failure
                losses.append(clone)
        groups: dict[str, list[dict[str, object]]] = {}
        for row in losses:
            groups.setdefault(str(row["failure_type"]), []).append(row)
        for failure, bucket in sorted(groups.items(), key=lambda item: (-len(item[1]), item[0])):
            st = stats_for(bucket)
            output.append(
                {
                    "scenario": scenario,
                    "failure_type": failure,
                    "trades": st["trades"],
                    "net": st["net"],
                    "avg_R": st["avg_R"],
                    "avg_MFE_R": st["avg_MFE_R"],
                    "avg_MAE_R": st["avg_MAE_R"],
                    "reached_1R_pct": st["reached_1R_pct"],
                    "symbol_distribution": distribution(bucket, "symbol"),
                    "month_distribution": distribution(bucket, "month"),
                    "m15_trigger_distribution": distribution(bucket, "m15_trigger_type"),
                }
            )
    return output


def write_long_failure_summary(rows: list[dict[str, object]]) -> None:
    lines = [
        "# Broad FX-only 2025 LONG Failure Summary",
        "",
        "| scenario | failure_type | trades | net | avg_R | avg_MFE_R | avg_MAE_R | reached_1R_pct |",
        "|---|---|---:|---:|---:|---:|---:|---:|",
    ]
    for row in rows:
        lines.append(
            f"| {row['scenario']} | {row['failure_type']} | {row['trades']} | {row['net']} | {row['avg_R']} | {row['avg_MFE_R']} | {row['avg_MAE_R']} | {row['reached_1R_pct']} |"
        )
    lines += [
        "",
        "This is diagnostic only. It does not change RewardR, SL/TP, risk, spread guard, CTrade, symbols, or direction mode.",
        "",
    ]
    OUTPUTS["long_failure_summary"].write_text("\n".join(lines), encoding="utf-8")


def write_summary(comparison: list[dict[str, object]], failures: list[dict[str, object]]) -> None:
    base = OUTPUTS["summary"].parent
    by_name = {str(row["scenario"]): row for row in comparison}
    a = by_name["A_current_broad_fx_only"]
    b = by_name["B_broad_hard_gate_reduced"]
    c = by_name["C_broad_reduced_room_to_2r"]
    d = by_name["D_broad_reduced_h4_ma_bias"]
    e = by_name["E_broad_reduced_m15_close_bos"]
    f = by_name["F_broad_reduced_room_to_2r_h4_ma"]
    best = max(comparison, key=lambda row: (as_float(row["avg_R"]), as_float(row["PF"]), as_float(row["net"])))
    b_failures = [row for row in failures if row["scenario"] == "B_broad_hard_gate_reduced"]
    top_b_failure = b_failures[0]["failure_type"] if b_failures else ""

    lines = [
        "# Broad FX-only 2025 Entry Candidates Summary",
        "",
        "Scope: 2025 full-year FX-only nested entry candidates. XAUUSD is excluded. No Friday stop, direction limit, pair exclusion, RewardR/SL/TP/risk/spread guard change, or parameter optimization was used.",
        "",
        "## Scenario Comparison",
        "",
        f"- A current Broad: `{a['trades']}` trades, PF `{a['PF']}`, avg_R `{a['avg_R']}`, net `{a['net']}`.",
        f"- B hard-gate reduced: `{b['trades']}` trades, PF `{b['PF']}`, avg_R `{b['avg_R']}`, net `{b['net']}`.",
        f"- C B + room_to_2r: `{c['trades']}` trades, PF `{c['PF']}`, avg_R `{c['avg_R']}`, net `{c['net']}`.",
        f"- D B + H4 MA bias: `{d['trades']}` trades, PF `{d['PF']}`, avg_R `{d['avg_R']}`, net `{d['net']}`.",
        f"- E B + M15 close BOS: `{e['trades']}` trades, PF `{e['PF']}`, avg_R `{e['avg_R']}`, net `{e['net']}`.",
        f"- F B + room_to_2r + H4 MA bias: `{f['trades']}` trades, PF `{f['PF']}`, avg_R `{f['avg_R']}`, net `{f['net']}`.",
        "",
        "## Required Checks",
        "",
        f"1. Trade count versus current Broad: `{b['trades']}` vs `{a['trades']}`.",
        f"2. `room_to_2r` effect in the wider pool: B avg_R `{b['avg_R']}` to C avg_R `{c['avg_R']}`.",
        f"3. H4 MA bias post-filter effect: B avg_R `{b['avg_R']}` to D avg_R `{d['avg_R']}`.",
        f"4. M15 close BOS post-filter effect: B avg_R `{b['avg_R']}` to E avg_R `{e['avg_R']}`.",
        f"5. LONG top failure in B: `{top_b_failure}`.",
        f"6. Best scenario by avg_R: `{best['scenario']}` with `{best['trades']}` trades.",
        "",
        "## Judgment",
        "",
    ]
    if int(best["trades"]) >= 60 and as_float(best["avg_R"]) > 0.0 and as_float(best["PF"]) > 1.1:
        lines.append(f"- Candidate for next fixed BT exists: `{best['scenario']}`.")
    else:
        lines.append("- No hard-gate-reduced condition set is ready for fixed BT promotion under the requested balance criteria.")
    lines += [
        "- The hard-gate-reduced branch is intended to widen the candidate pool and relabel H4/fib/H1 N-wave/BOS/room conditions for post-processing.",
        "- `E_broad_reduced_m15_close_bos` improves average price-R, but it is still negative on PF and net profit, so it is not a fixed-BT candidate.",
        "",
        "## Artifacts",
        "",
        f"- Comparison: {md_link('comparison CSV', OUTPUTS['comparison'], base)}",
        f"- Trades: {md_link('trades CSV', OUTPUTS['trades'], base)}",
        f"- By symbol: {md_link('by symbol CSV', OUTPUTS['by_symbol'], base)}",
        f"- By month: {md_link('by month CSV', OUTPUTS['by_month'], base)}",
        f"- By direction: {md_link('by direction CSV', OUTPUTS['by_direction'], base)}",
        f"- By M15 trigger: {md_link('by M15 trigger CSV', OUTPUTS['by_m15_trigger'], base)}",
        f"- LONG failure summary: {md_link('LONG failure summary', OUTPUTS['long_failure_summary'], base)}",
        f"- MT5 report: {md_link('MT5 report', BACKTEST / f'{RUN_PREFIX}_report.html', base)}",
        f"- Compile log: {md_link('compile log', ROOT / 'reports' / 'compile' / 'ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_compile.log', base)}",
        "",
    ]
    OUTPUTS["summary"].write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    broad = load_broad_rows()
    new_rows = load_new_rows()
    scenarios = scenario_rows(broad, new_rows)
    all_trades = []
    for scenario, items in scenarios.items():
        for row in items:
            clone = dict(row)
            clone["scenario"] = scenario
            all_trades.append(clone)
    comparison = comparison_rows(scenarios)
    failures = long_failure_rows(scenarios)

    write_rows(OUTPUTS["comparison"], comparison)
    write_rows(OUTPUTS["trades"], all_trades)
    write_rows(OUTPUTS["by_symbol"], group_outputs(scenarios, "symbol"))
    write_rows(OUTPUTS["by_month"], group_outputs(scenarios, "month"))
    write_rows(OUTPUTS["by_direction"], group_outputs(scenarios, "direction"))
    write_rows(OUTPUTS["by_m15_trigger"], group_outputs(scenarios, "m15_trigger_type"))
    write_long_failure_summary(failures)
    write_summary(comparison, failures)
    OUTPUTS["metrics"].write_text(
        json.dumps({"comparison": comparison, "failures": failures}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(json.dumps({"comparison": comparison}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
