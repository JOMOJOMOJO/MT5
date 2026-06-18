#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import os
from pathlib import Path

from analyze_multicurrency_score_scanner_2025 import BACKTEST, parse_mt5_deals, write_trades
from analyze_fixed_condition_bt import ROOT, OUT_BASE, as_float, bool_text, bool_value, match_diag, read_order_sent_rows, write_rows
from analyze_fx_only_2025_condition_factorial import (
    ALL_CONDITIONS,
    FX_SYMBOLS,
    RateCache,
    distribution,
    md_link,
    r_reach_metrics,
    session_from_hour,
    stats_for,
)
from analyze_relaxed_fx_only_2025_condition_factorial import add_buckets, enrich_round_room


SERIES_NAME = "sweep_reclaim_retest_2025_fx_only"
OUT_PREFIX = f"{OUT_BASE}_{SERIES_NAME}"
EXISTING_BROAD_TRADES = BACKTEST / f"{OUT_BASE}_broad_fx_only_2025_entry_candidates_trades.csv"

NEW_RUNS = [
    {
        "scenario": "C_sweep_reclaim_only",
        "run_name": "C_sweep_reclaim_only",
    },
    {
        "scenario": "D_bos_retest_only",
        "run_name": "D_bos_retest_only",
    },
    {
        "scenario": "E_first_pullback_after_reclaim_only",
        "run_name": "E_first_pullback",
    },
    {
        "scenario": "F_combined_new_triggers",
        "run_name": "F_combined_new_triggers",
    },
]

EXTRA_CONDITIONS = [
    "cond_m15_micro_break",
    "cond_m15_short_ma_reversal",
    "cond_m15_candle_reversal",
    "cond_major_or_round_room_to_2r",
]
OUTPUT_CONDITIONS = ALL_CONDITIONS + [item for item in EXTRA_CONDITIONS if item not in ALL_CONDITIONS]

OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_summary.md",
    "comparison": BACKTEST / f"{OUT_PREFIX}_comparison.csv",
    "trades": BACKTEST / f"{OUT_PREFIX}_trades.csv",
    "by_trigger": BACKTEST / f"{OUT_PREFIX}_by_trigger.csv",
    "by_failure_type": BACKTEST / f"{OUT_PREFIX}_by_failure_type.csv",
    "by_direction": BACKTEST / f"{OUT_PREFIX}_by_direction.csv",
    "by_symbol": BACKTEST / f"{OUT_PREFIX}_by_symbol.csv",
    "by_month": BACKTEST / f"{OUT_PREFIX}_by_month.csv",
    "by_session": BACKTEST / f"{OUT_PREFIX}_by_session.csv",
    "room2r_interaction": BACKTEST / f"{OUT_PREFIX}_room2r_interaction.csv",
    "h4_context_interaction": BACKTEST / f"{OUT_PREFIX}_h4_context_interaction.csv",
    "metrics": BACKTEST / f"{OUT_PREFIX}_metrics.json",
}


def read_rows(path: Path) -> list[dict[str, object]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return [dict(row) for row in csv.DictReader(fh)]


def run_prefix(run_name: str) -> str:
    return f"{OUT_BASE}_{SERIES_NAME}_{run_name}"


def source_a_b_rows() -> dict[str, list[dict[str, object]]]:
    rows = read_rows(EXISTING_BROAD_TRADES)
    scenarios = {
        "A_current_broad_fx_only": [],
        "B_broad_hard_gate_reduced": [],
    }
    for row in rows:
        scenario = str(row.get("scenario", ""))
        symbol = str(row.get("symbol", "")).upper()
        if scenario not in scenarios or symbol not in FX_SYMBOLS:
            continue
        row["trigger_type"] = row.get("trigger_type") or row.get("m15_trigger_type", "")
        row["fx_bucket"] = "FX"
        for condition in OUTPUT_CONDITIONS:
            row.setdefault(condition, "false")
        add_buckets(row)
        classify_failure(row)
        scenarios[scenario].append(row)
    if not scenarios["A_current_broad_fx_only"] or not scenarios["B_broad_hard_gate_reduced"]:
        raise RuntimeError(f"Existing broad trades missing A/B scenarios: {EXISTING_BROAD_TRADES}")
    return scenarios


def set_condition_defaults(row: dict[str, object], diag: dict[str, object] | None) -> None:
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
            "trigger_type",
            "m15_sweep_level",
            "m15_reclaim_confirmed",
            "m15_bos_level",
            "m15_retest_confirmed",
            "m15_first_pullback_confirmed",
            "entry_delay_bars_from_bos",
            "entry_delay_bars_from_sweep",
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
        for key in OUTPUT_CONDITIONS:
            row[key] = bool_text(bool_value(diag.get(key)))
    for key in OUTPUT_CONDITIONS:
        row.setdefault(key, "false")

    trigger = str(row.get("trigger_type") or row.get("m15_trigger_type", ""))
    row["trigger_type"] = trigger
    row["cond_m15_micro_break"] = bool_text(trigger == "m15_micro_break" or bool_value(row.get("cond_m15_micro_break")))
    row["cond_m15_short_ma_reversal"] = bool_text(trigger == "m15_short_ma_reversal" or bool_value(row.get("cond_m15_short_ma_reversal")))
    row["cond_m15_candle_reversal"] = bool_text(trigger == "m15_reversal_candle" or bool_value(row.get("cond_m15_candle_reversal")))
    row["cond_room_to_1r"] = bool_text(as_float(row.get("room_to_1r")) >= 1.0 or bool_value(row.get("cond_room_to_1r")))
    row["cond_room_to_2r"] = bool_text(as_float(row.get("room_to_2r")) >= 1.0 or bool_value(row.get("cond_room_to_2r")))
    row["cond_h4_bias_ma"] = bool_text(str(row.get("h4_ma_state", "")) == "ma_bias_pass" or bool_value(row.get("cond_h4_bias_ma")))
    row["cond_h4_dow_bias"] = bool_text(str(row.get("h4_dow_state", "")) == "dow_bias_pass" or bool_value(row.get("cond_h4_dow_bias")))


def classify_failure(row: dict[str, object]) -> None:
    if as_float(row.get("net_profit")) >= 0.0:
        row["failure_type"] = "win"
        return
    if not (bool_value(row.get("cond_h4_bias_ma")) or bool_value(row.get("cond_h4_dow_bias"))):
        row["failure_type"] = "bad_h4_context"
    elif not bool_value(row.get("cond_room_to_1r")):
        row["failure_type"] = "target_blocked_before_1r"
    elif not bool_value(row.get("cond_room_to_2r")):
        row["failure_type"] = "target_blocked_before_2r"
    elif as_float(row.get("max_favorable_r")) < 0.5:
        trigger = str(row.get("trigger_type", ""))
        if trigger == "sweep_reclaim":
            row["failure_type"] = "sweep_reclaim_no_follow_through"
        elif trigger == "bos_retest":
            row["failure_type"] = "bos_retest_failed"
        elif trigger == "first_pullback_after_reclaim":
            row["failure_type"] = "first_pullback_failed"
        else:
            row["failure_type"] = "m15_false_reversal"
    elif as_float(row.get("max_favorable_r")) >= 1.0 and as_float(row.get("max_favorable_r")) < 2.0:
        row["failure_type"] = "target_too_far_after_1r"
    elif as_float(row.get("distance_neckline_to_entry_atr")) > 1.2 or as_float(row.get("entry_delay_bars_from_bos")) > 8:
        row["failure_type"] = "chasing_entry"
    else:
        row["failure_type"] = "other"


def load_new_run_rows(run_name: str, scenario: str) -> list[dict[str, object]]:
    pfx = run_prefix(run_name)
    report = BACKTEST / f"{pfx}_report.html"
    if not report.exists():
        raise FileNotFoundError(report)
    trades = parse_mt5_deals(report)
    write_trades(BACKTEST / f"{pfx}_trades.csv", trades)
    sent = read_order_sent_rows(pfx)
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
    missing_diag = 0
    for idx, trade in enumerate(trades, start=1):
        symbol = str(trade["symbol"]).upper()
        if symbol not in FX_SYMBOLS:
            continue
        diag = match_diag(trade, sent, used)
        if diag is None:
            missing_diag += 1
        open_time = trade["open_time"]
        row: dict[str, object] = {
            "trade_index": idx,
            "scenario": scenario,
            "source_scenario": scenario,
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
            "fx_bucket": "FX",
        }
        from analyze_fixed_condition_bt import price_result_r

        row["result_R"] = round(price_result_r(trade, diag), 3)
        row.update(r_reach_metrics(trade, diag, cache if mt5_ready else None))
        set_condition_defaults(row, diag)
        add_buckets(row)
        enrich_round_room(row)
        classify_failure(row)
        rows.append(row)

    if mt5_ready and mt5 is not None:
        mt5.shutdown()
    if missing_diag:
        raise RuntimeError(f"{scenario}: missing order_sent diagnostics for {missing_diag} trades.")
    return rows


def both_conditions(rows: list[dict[str, object]], *conditions: str) -> list[dict[str, object]]:
    return [row for row in rows if all(bool_value(row.get(condition)) for condition in conditions)]


def build_scenarios() -> dict[str, list[dict[str, object]]]:
    scenarios = source_a_b_rows()
    for run in NEW_RUNS:
        scenarios[run["scenario"]] = load_new_run_rows(str(run["run_name"]), str(run["scenario"]))
    combined = scenarios["F_combined_new_triggers"]
    scenarios["G_combined_new_triggers_room_to_2r"] = both_conditions(combined, "cond_room_to_2r")
    scenarios["H_combined_new_triggers_h4_ma_bias"] = both_conditions(combined, "cond_h4_bias_ma")
    scenarios["I_combined_new_triggers_h4_ma_room_to_2r"] = both_conditions(combined, "cond_h4_bias_ma", "cond_room_to_2r")
    return scenarios


def comparison_rows(scenarios: dict[str, list[dict[str, object]]]) -> list[dict[str, object]]:
    return [{"scenario": scenario, **stats_for(rows)} for scenario, rows in scenarios.items()]


def group_outputs(scenarios: dict[str, list[dict[str, object]]], key: str) -> list[dict[str, object]]:
    output: list[dict[str, object]] = []
    for scenario, rows in scenarios.items():
        groups: dict[str, list[dict[str, object]]] = {}
        for row in rows:
            groups.setdefault(str(row.get(key, "")), []).append(row)
        for group, bucket in sorted(groups.items()):
            output.append({"scenario": scenario, "group": group, **stats_for(bucket)})
    return output


def interaction_outputs(scenarios: dict[str, list[dict[str, object]]], condition: str) -> list[dict[str, object]]:
    output: list[dict[str, object]] = []
    for scenario, rows in scenarios.items():
        for state in ("ON", "OFF"):
            bucket = [row for row in rows if bool_value(row.get(condition)) == (state == "ON")]
            output.append({"scenario": scenario, "condition": condition, "state": state, **stats_for(bucket)})
    return output


def write_summary(comparison: list[dict[str, object]], scenarios: dict[str, list[dict[str, object]]]) -> None:
    base = OUTPUTS["summary"].parent
    by_name = {str(row["scenario"]): row for row in comparison}
    best = max(comparison, key=lambda row: (as_float(row.get("avg_R")), as_float(row.get("PF")), as_float(row.get("net"))))

    fixed_candidates = [
        row
        for row in comparison
        if int(row.get("trades", 0)) >= 100
        and int(row.get("trades", 0)) <= 700
        and as_float(row.get("PF")) > 1.05
        and as_float(row.get("avg_R")) > 0.0
        and as_float(row.get("net")) > 0.0
        and as_float(row.get("LONG net")) > -500.0
        and as_float(row.get("SHORT net")) > -500.0
    ]

    lines = [
        "# Sweep/Reclaim/Retest 2025 FX-only Summary",
        "",
        "Scope: 2025 full-year FX-only. XAUUSD is excluded via `InpSymbols`; no Friday stop, direction limit, pair exclusion, RewardR/SL/TP/risk/spread guard/CTrade change, or parameter optimization was used.",
        "",
        "## Scenario Comparison",
        "",
        "| scenario | trades | PF | avg_R | net | maxDD | LONG net | SHORT net | reached_1R_pct | reached_2R_pct |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in comparison:
        lines.append(
            f"| {row['scenario']} | {row['trades']} | {row['PF']} | {row['avg_R']} | {row['net']} | {row['maxDD']} | {row['LONG net']} | {row['SHORT net']} | {row['reached_1R_pct']} | {row['reached_2R_pct']} |"
        )

    lines += [
        "",
        "## Judgment",
        "",
        f"- Best by avg_R: `{best['scenario']}` with `{best['trades']}` trades, PF `{best['PF']}`, avg_R `{best['avg_R']}`, net `{best['net']}`.",
    ]
    if fixed_candidates:
        lines.append("- Fixed-BT candidate exists under the requested balance criteria:")
        for row in fixed_candidates:
            lines.append(f"  - `{row['scenario']}`: trades `{row['trades']}`, PF `{row['PF']}`, avg_R `{row['avg_R']}`, net `{row['net']}`.")
    else:
        lines.append("- No fixed-BT candidate exists under the requested balance criteria. High-PF low-count subsets remain reference only.")

    f_rows = scenarios.get("F_combined_new_triggers", [])
    trigger_dist = distribution(f_rows, "trigger_type")
    failure_dist = distribution([row for row in f_rows if as_float(row.get("net_profit")) < 0.0], "failure_type")
    lines += [
        f"- Combined trigger distribution: `{trigger_dist}`.",
        f"- Combined losing failure distribution: `{failure_dist}`.",
        "",
        "## Artifacts",
        "",
        f"- Comparison: {md_link('comparison CSV', OUTPUTS['comparison'], base)}",
        f"- Trades: {md_link('trades CSV', OUTPUTS['trades'], base)}",
        f"- By trigger: {md_link('by trigger CSV', OUTPUTS['by_trigger'], base)}",
        f"- By failure type: {md_link('by failure type CSV', OUTPUTS['by_failure_type'], base)}",
        f"- By direction: {md_link('by direction CSV', OUTPUTS['by_direction'], base)}",
        f"- By symbol: {md_link('by symbol CSV', OUTPUTS['by_symbol'], base)}",
        f"- By month: {md_link('by month CSV', OUTPUTS['by_month'], base)}",
        f"- By session: {md_link('by session CSV', OUTPUTS['by_session'], base)}",
        f"- Room-to-2R interaction: {md_link('room2r interaction CSV', OUTPUTS['room2r_interaction'], base)}",
        f"- H4 context interaction: {md_link('H4 context interaction CSV', OUTPUTS['h4_context_interaction'], base)}",
        "",
    ]
    OUTPUTS["summary"].write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    scenarios = build_scenarios()
    comparison = comparison_rows(scenarios)
    all_trades: list[dict[str, object]] = []
    for scenario, rows in scenarios.items():
        for row in rows:
            clone = dict(row)
            clone["scenario"] = scenario
            all_trades.append(clone)

    write_rows(OUTPUTS["comparison"], comparison)
    write_rows(OUTPUTS["trades"], all_trades)
    write_rows(OUTPUTS["by_trigger"], group_outputs(scenarios, "trigger_type"))
    write_rows(OUTPUTS["by_failure_type"], group_outputs(scenarios, "failure_type"))
    write_rows(OUTPUTS["by_direction"], group_outputs(scenarios, "direction"))
    write_rows(OUTPUTS["by_symbol"], group_outputs(scenarios, "symbol"))
    write_rows(OUTPUTS["by_month"], group_outputs(scenarios, "month"))
    write_rows(OUTPUTS["by_session"], group_outputs(scenarios, "session"))
    write_rows(OUTPUTS["room2r_interaction"], interaction_outputs(scenarios, "cond_room_to_2r"))
    write_rows(OUTPUTS["h4_context_interaction"], interaction_outputs(scenarios, "cond_h4_bias_ma"))
    write_summary(comparison, scenarios)
    OUTPUTS["metrics"].write_text(json.dumps({"comparison": comparison}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"comparison": comparison}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
