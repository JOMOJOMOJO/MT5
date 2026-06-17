#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import os
from pathlib import Path
from typing import Any

from analyze_multicurrency_score_scanner_2025 import BACKTEST, parse_mt5_deals, write_trades
from analyze_fixed_condition_bt import (
    ROOT,
    OUT_BASE,
    as_float,
    bool_text,
    bool_value,
    match_diag,
    read_order_sent_rows,
    write_rows,
)
from analyze_fx_only_2025_condition_factorial import (
    FX_SYMBOLS,
    ALL_CONDITIONS,
    RateCache,
    distribution,
    long_failure_type,
    md_link,
    r_reach_metrics,
    session_from_hour,
    stats_for,
)


BROAD_CANDIDATES = BACKTEST / f"{OUT_BASE}_fx_only_2025_condition_factorial_candidates.csv"
RELAXED_PREFIX = f"{OUT_BASE}_fxrelax2025_A_relaxed_condition_candidates"
OUT_PREFIX = f"{OUT_BASE}_relaxed_fx_only_2025_entry_conditions"

OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_summary.md",
    "comparison": BACKTEST / f"{OUT_PREFIX}_comparison.csv",
    "trades": BACKTEST / f"{OUT_PREFIX}_trades.csv",
    "by_symbol": BACKTEST / f"{OUT_PREFIX}_by_symbol.csv",
    "by_month": BACKTEST / f"{OUT_PREFIX}_by_month.csv",
    "by_direction": BACKTEST / f"{OUT_PREFIX}_by_direction.csv",
    "long_failure_summary": BACKTEST / f"{OUT_PREFIX}_long_failure_summary.md",
    "metrics": BACKTEST / f"{OUT_PREFIX}_metrics.json",
}


def read_rows(path: Path) -> list[dict[str, object]]:
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return [dict(row) for row in csv.DictReader(fh)]


def parse_time(value: str):
    from datetime import datetime

    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")


def condition_subset(rows: list[dict[str, object]], condition: str) -> list[dict[str, object]]:
    return [row for row in rows if bool_value(row.get(condition))]


def next_round_level(symbol: str, direction: str, entry: float) -> tuple[float, float]:
    unit = 1.0 if symbol.endswith("JPY") else 0.01
    if entry <= 0.0:
        return 0.0, 0.0
    import math

    if direction == "LONG":
        level = math.ceil(entry / unit) * unit
        if level <= entry:
            level += unit
    else:
        level = math.floor(entry / unit) * unit
        if level >= entry:
            level -= unit
    return level, abs(level - entry)


def enrich_round_room(row: dict[str, object]) -> None:
    symbol = str(row.get("symbol", "")).upper()
    direction = str(row.get("direction", ""))
    entry = as_float(row.get("entry_price"))
    sl = as_float(row.get("sl"))
    risk = abs(entry - sl)
    level, distance = next_round_level(symbol, direction, entry)
    row["round_number_level"] = round(level, 5) if level else ""
    row["round_number_distance"] = round(distance, 5) if distance else ""
    row["round_number_room_to_2r"] = bool_text(risk > 0.0 and distance >= risk * 2.0)
    row["cond_major_or_round_room_to_2r"] = bool_text(bool_value(row.get("cond_room_to_2r")) and bool_value(row.get("round_number_room_to_2r")))


def add_buckets(row: dict[str, object]) -> None:
    h1_atr = as_float(row.get("h1_counter_wave_atr"))
    if h1_atr <= 0.0:
        row["h1_counter_wave_atr_bucket"] = "unknown"
    elif h1_atr < 1.0:
        row["h1_counter_wave_atr_bucket"] = "small"
    elif h1_atr < 2.0:
        row["h1_counter_wave_atr_bucket"] = "normal"
    else:
        row["h1_counter_wave_atr_bucket"] = "deep"

    fib = as_float(row.get("h4_fib_retracement_pct"))
    if fib <= 0.0:
        row["h4_fib_bucket"] = "unknown"
    elif fib < 38.2:
        row["h4_fib_bucket"] = "shallow"
    elif fib <= 61.8:
        row["h4_fib_bucket"] = "standard"
    else:
        row["h4_fib_bucket"] = "deep"
    enrich_round_room(row)


def load_broad_rows() -> list[dict[str, object]]:
    rows = read_rows(BROAD_CANDIDATES)
    output = []
    for row in rows:
        if str(row.get("symbol", "")).upper() not in FX_SYMBOLS:
            continue
        row["source_scenario"] = "A_current_broad_fx_only"
        add_buckets(row)
        output.append(row)
    return output


def load_relaxed_rows() -> list[dict[str, object]]:
    report = BACKTEST / f"{RELAXED_PREFIX}_report.html"
    if not report.exists():
        raise FileNotFoundError(report)
    trades = parse_mt5_deals(report)
    write_trades(BACKTEST / f"{RELAXED_PREFIX}_trades.csv", trades)
    sent = read_order_sent_rows(RELAXED_PREFIX)
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
            "result_R": 0.0,
            "net_profit": round(as_float(trade.get("net_profit")), 2),
            "source_scenario": "B_relaxed_entry",
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
            for key in ALL_CONDITIONS:
                row[key] = bool_text(bool_value(diag.get(key)))
        for key in ALL_CONDITIONS:
            row.setdefault(key, "false")
        add_buckets(row)
        rows.append(row)

    if mt5_ready and mt5 is not None:
        mt5.shutdown()
    return rows


def scenario_rows(broad: list[dict[str, object]], relaxed: list[dict[str, object]]) -> dict[str, list[dict[str, object]]]:
    return {
        "A_current_broad_fx_only": broad,
        "B_relaxed_entry": relaxed,
        "C_relaxed_room_to_1r": condition_subset(relaxed, "cond_room_to_1r"),
        "D_relaxed_room_to_2r": condition_subset(relaxed, "cond_room_to_2r"),
        "E_relaxed_room_to_2r_no_round_or_major_obstacle": condition_subset(relaxed, "cond_major_or_round_room_to_2r"),
    }


def comparison_rows(scenarios: dict[str, list[dict[str, object]]]) -> list[dict[str, object]]:
    rows = []
    for scenario, items in scenarios.items():
        rows.append({"scenario": scenario, **stats_for(items)})
    return rows


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
                    "reached_0_5R_pct": st["reached_0_5R_pct"],
                    "reached_1R_pct": st["reached_1R_pct"],
                    "reached_2R_pct": st["reached_2R_pct"],
                    "symbol_distribution": distribution(bucket, "symbol"),
                    "month_distribution": distribution(bucket, "month"),
                    "session_distribution": distribution(bucket, "session"),
                }
            )
    return output


def write_long_failure_summary(rows: list[dict[str, object]]) -> None:
    lines = [
        "# Relaxed FX-only 2025 LONG Failure Summary",
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


def write_summary(scenarios: dict[str, list[dict[str, object]]], comparison: list[dict[str, object]], failures: list[dict[str, object]]) -> None:
    base = OUTPUTS["summary"].parent
    by_name = {str(row["scenario"]): row for row in comparison}
    broad = by_name["A_current_broad_fx_only"]
    relaxed = by_name["B_relaxed_entry"]
    room1 = by_name["C_relaxed_room_to_1r"]
    room2 = by_name["D_relaxed_room_to_2r"]
    round_clear = by_name["E_relaxed_room_to_2r_no_round_or_major_obstacle"]
    best = max(comparison, key=lambda row: (as_float(row["avg_R"]), as_float(row["PF"]), as_float(row["net"])))
    relaxed_failures = [row for row in failures if row["scenario"] == "B_relaxed_entry"]
    top_relaxed_failure = relaxed_failures[0]["failure_type"] if relaxed_failures else ""
    lines = [
        "# Relaxed FX-only 2025 Entry Conditions Summary",
        "",
        "Scope: 2025 full-year FX-only nested entry candidates. XAUUSD is excluded. No Friday stop, direction limit, pair exclusion, RewardR/SL/TP/risk/spread guard change, or parameter optimization was used.",
        "",
        "## Scenario Comparison",
        "",
        f"- A current Broad: `{broad['trades']}` trades, PF `{broad['PF']}`, avg_R `{broad['avg_R']}`, net `{broad['net']}`.",
        f"- B relaxed entry: `{relaxed['trades']}` trades, PF `{relaxed['PF']}`, avg_R `{relaxed['avg_R']}`, net `{relaxed['net']}`.",
        f"- C relaxed + room_to_1r: `{room1['trades']}` trades, PF `{room1['PF']}`, avg_R `{room1['avg_R']}`, net `{room1['net']}`.",
        f"- D relaxed + room_to_2r: `{room2['trades']}` trades, PF `{room2['PF']}`, avg_R `{room2['avg_R']}`, net `{room2['net']}`.",
        f"- E relaxed + room_to_2r + round/major obstacle clear: `{round_clear['trades']}` trades, PF `{round_clear['PF']}`, avg_R `{round_clear['avg_R']}`, net `{round_clear['net']}`.",
        "",
        "## Required Checks",
        "",
        f"1. Trade count versus current Broad: `{relaxed['trades']}` vs `{broad['trades']}`; the relaxed branch did not increase count because it keeps H4 MA bias and M15 recent-extreme BOS as hard gates.",
        f"2. PF/avg_R did not improve in relaxed base if lower than A: PF `{relaxed['PF']}`, avg_R `{relaxed['avg_R']}`.",
        f"3. `room_to_2r` remains effective: relaxed base avg_R `{relaxed['avg_R']}` to D avg_R `{room2['avg_R']}`.",
        f"4. LONG target-blocked should be judged in `{OUTPUTS['long_failure_summary'].name}`; top relaxed LONG failure is `{top_relaxed_failure}`.",
        f"5. H1 N-wave is diagnostic only in B/C/D/E. The comparison shows whether removing it as a hard gate helped.",
        f"6. Best scenario by avg_R: `{best['scenario']}` with `{best['trades']}` trades.",
        "",
        "## Judgment",
        "",
    ]
    if int(best["trades"]) >= 60 and as_float(best["avg_R"]) > 0.0 and as_float(best["PF"]) > 1.1:
        lines.append(f"- Candidate for next fixed BT exists: `{best['scenario']}`.")
    else:
        lines.append("- No relaxed condition set is ready for fixed BT promotion under the requested balance criteria.")
    lines += [
        "- If B has fewer trades than A, the relaxed branch is looser than prior fixed gates but not looser than the previous Broad candidate definition because it requires H4 MA bias and M15 recent-extreme BOS.",
        "",
        "## Artifacts",
        "",
        f"- Comparison: {md_link('comparison CSV', OUTPUTS['comparison'], base)}",
        f"- Trades: {md_link('trades CSV', OUTPUTS['trades'], base)}",
        f"- By symbol: {md_link('by symbol CSV', OUTPUTS['by_symbol'], base)}",
        f"- By month: {md_link('by month CSV', OUTPUTS['by_month'], base)}",
        f"- By direction: {md_link('by direction CSV', OUTPUTS['by_direction'], base)}",
        f"- LONG failure summary: {md_link('LONG failure summary', OUTPUTS['long_failure_summary'], base)}",
        f"- MT5 relaxed report: {md_link('MT5 relaxed report', BACKTEST / f'{RELAXED_PREFIX}_report.html', base)}",
        f"- Compile log: {md_link('compile log', ROOT / 'reports' / 'compile' / 'ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_compile.log', base)}",
        "",
    ]
    OUTPUTS["summary"].write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    broad = load_broad_rows()
    relaxed = load_relaxed_rows()
    scenarios = scenario_rows(broad, relaxed)
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
    write_long_failure_summary(failures)
    write_summary(scenarios, comparison, failures)
    OUTPUTS["metrics"].write_text(
        json.dumps({"comparison": comparison, "failures": failures}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(json.dumps({"comparison": comparison}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
