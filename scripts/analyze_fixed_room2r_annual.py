#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import os
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

try:
    import MetaTrader5 as mt5
except ImportError:  # pragma: no cover
    mt5 = None

from analyze_multicurrency_score_scanner_2025 import BACKTEST, parse_mt5_deals, write_trades
from analyze_fixed_condition_bt import (
    ROOT,
    OUT_BASE,
    as_float,
    audit_labels,
    bool_text,
    bool_value,
    match_diag,
    md_link,
    parse_time,
    price_result_r,
    profit_factor,
    read_csv_rows,
    read_order_sent_rows,
    write_rows,
)


MT5_RATE_TIME_OFFSET = timedelta(hours=9)

H4_PREFIX = "fixed_room2r_annual"
LOWER_PREFIX = "fixed_room2r_lower_tf"

PERIODS = [
    ("2024", "2024", "2024_fixed_room2r_annual", "2024_fixed_room2r_lower_tf"),
    ("2025", "2025", "2025_fixed_room2r_annual", "2025_fixed_room2r_lower_tf"),
    ("2026YTD", "2026", "2026_ytd_fixed_room2r_annual", "2026_ytd_fixed_room2r_lower_tf"),
]

SCENARIOS = [
    {
        "key": "h4",
        "scenario": "Nested_Fixed_Room2R_BOTH_all_H4_H1_M15_2R",
        "run_name": "B_fixed_room2r",
        "series_index": 2,
        "execution_minutes": 15,
        "outputs_prefix": f"{OUT_BASE}_{H4_PREFIX}",
    },
    {
        "key": "lower",
        "scenario": "Nested_Fixed_Room2R_LOWER_TF_BOTH_all_H1_M15_M5_2R",
        "run_name": "L_fixed_room2r_lower_tf",
        "series_index": 3,
        "execution_minutes": 5,
        "outputs_prefix": f"{OUT_BASE}_{LOWER_PREFIX}",
    },
]


class RateCache:
    def __init__(self) -> None:
        self.cache: dict[tuple[str, datetime, datetime, int], list[dict[str, Any]]] = {}

    @staticmethod
    def floor_time(value: datetime, minutes: int) -> datetime:
        return value.replace(minute=value.minute - value.minute % minutes, second=0, microsecond=0)

    @staticmethod
    def mt5_tf(minutes: int):
        if mt5 is None:
            return None
        return mt5.TIMEFRAME_M5 if minutes == 5 else mt5.TIMEFRAME_M15

    def get(self, symbol: str, start: datetime, end: datetime, minutes: int) -> list[dict[str, Any]]:
        if mt5 is None:
            return []
        start = self.floor_time(start, minutes)
        end = self.floor_time(end, minutes) + timedelta(minutes=minutes)
        key = (symbol, start, end, minutes)
        if key in self.cache:
            return self.cache[key]
        timeframe = self.mt5_tf(minutes)
        data = mt5.copy_rates_range(symbol, timeframe, start + MT5_RATE_TIME_OFFSET, end + MT5_RATE_TIME_OFFSET)
        rows: list[dict[str, Any]] = []
        if data is not None:
            for item in data:
                rows.append(
                    {
                        "time": datetime.fromtimestamp(int(item["time"])) - MT5_RATE_TIME_OFFSET,
                        "high": float(item["high"]),
                        "low": float(item["low"]),
                    }
                )
        self.cache[key] = rows
        return rows


def r_reach_metrics(trade: dict[str, object], diag: dict[str, object] | None, cache: RateCache | None, minutes: int) -> dict[str, object]:
    result = {
        "max_favorable_r": "",
        "max_adverse_r": "",
        "reached_0_5R": "",
        "reached_1R": "",
        "reached_2R": "",
    }
    if diag is None or cache is None:
        return result
    entry = as_float(diag.get("entry_price"))
    sl = as_float(diag.get("sl"))
    if entry <= 0.0 or sl <= 0.0:
        return result
    risk = entry - sl if trade.get("direction") == "LONG" else sl - entry
    if risk <= 0.0:
        return result
    rates = cache.get(str(trade["symbol"]), trade["open_time"], trade["close_time"], minutes)
    if not rates:
        return result
    max_fav = 0.0
    max_adv = 0.0
    for item in rates:
        if trade.get("direction") == "LONG":
            fav = (item["high"] - entry) / risk
            adv = (entry - item["low"]) / risk
        else:
            fav = (entry - item["low"]) / risk
            adv = (item["high"] - entry) / risk
        max_fav = max(max_fav, fav)
        max_adv = max(max_adv, adv)
    result.update(
        {
            "max_favorable_r": round(max_fav, 3),
            "max_adverse_r": round(max_adv, 3),
            "reached_0_5R": bool_text(max_fav >= 0.5),
            "reached_1R": bool_text(max_fav >= 1.0),
            "reached_2R": bool_text(max_fav >= 2.0),
        }
    )
    return result


def read_scan_driver_symbols(pfx: str) -> str:
    rows = read_csv_rows(BACKTEST / f"{pfx}_scan_diagnostics.csv")
    symbols = sorted({row.get("scan_driver_symbol", "") for row in rows if row.get("scan_driver_symbol")})
    return ";".join(symbols)


def prefix(series: str, run_name: str) -> str:
    return f"{OUT_BASE}_{series}_{run_name}"


def session_from_hour(hour: int) -> str:
    if 0 <= hour < 7:
        return "asia"
    if 7 <= hour < 13:
        return "london"
    if 13 <= hour < 21:
        return "ny"
    return "late_us"


def load_scenario(scenario: dict[str, Any]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    cache = RateCache()
    mt5_ready = False
    if mt5 is not None:
        mt5_ready = bool(mt5.initialize())

    for period_name, year, annual_series, lower_series in PERIODS:
        series = annual_series if scenario["key"] == "h4" else lower_series
        pfx = prefix(series, str(scenario["run_name"]))
        report = BACKTEST / f"{pfx}_report.html"
        if not report.exists():
            continue
        trades = parse_mt5_deals(report)
        write_trades(BACKTEST / f"{pfx}_trades.csv", trades)
        sent_rows = read_order_sent_rows(pfx)
        used: set[int] = set()
        scan_driver = read_scan_driver_symbols(pfx)
        for trade in trades:
            diag = match_diag(trade, sent_rows, used)
            open_time = trade["open_time"]
            result_r = price_result_r(trade, diag)
            reach = r_reach_metrics(trade, diag, cache if mt5_ready else None, int(scenario["execution_minutes"]))
            row: dict[str, object] = {
                "timeframe_set": "H4-H1-M15" if scenario["key"] == "h4" else "H1-M15-M5",
                "scenario": scenario["scenario"],
                "period": period_name,
                "year": year,
                "symbol": trade["symbol"],
                "direction": trade["direction"],
                "fx_bucket": "XAUUSD" if str(trade["symbol"]).upper().startswith("XAU") else "FX",
                "fx_direction_bucket": ("XAUUSD" if str(trade["symbol"]).upper().startswith("XAU") else "FX") + " " + str(trade["direction"]),
                "time": open_time.strftime("%Y.%m.%d %H:%M:%S"),
                "close_time": trade["close_time"].strftime("%Y.%m.%d %H:%M:%S"),
                "month": open_time.strftime("%Y-%m"),
                "session": diag.get("session", "") if diag and diag.get("session") else session_from_hour(open_time.hour),
                "entry_price": diag.get("entry_price", "") if diag else trade.get("open_price", ""),
                "sl": diag.get("sl", "") if diag else "",
                "tp": diag.get("tp", "") if diag else "",
                "result_R": round(result_r, 3),
                "net_profit": round(as_float(trade.get("net_profit")), 2),
                "scan_driver_symbol": scan_driver,
                "execution_minutes": scenario["execution_minutes"],
            }
            row.update(reach)
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
                    "spread_atr",
                    "spread_points",
                    "distance_bos_to_entry_atr",
                    "distance_neckline_to_entry_atr",
                    "label",
                ):
                    row[key] = diag.get(key, "")
                for key in (
                    "cond_h4_bias_ma",
                    "cond_h4_dow_bias",
                    "cond_h4_fib_382_618",
                    "cond_h1_prev_extreme_break",
                    "cond_h1_counter_nwave",
                    "cond_h1_counter_wave_atr",
                    "cond_true_bos_level",
                    "cond_m15_prev_extreme_bos",
                    "cond_m15_close_bos",
                    "cond_room_to_1r",
                    "cond_room_to_2r",
                    "cond_sl_atr_ok",
                ):
                    row[key] = bool_text(bool_value(diag.get(key)))
            row.update(audit_labels(row))
            rows.append(row)

    if mt5_ready and mt5 is not None:
        mt5.shutdown()
    return rows


def max_drawdown(values: list[float]) -> tuple[float, float]:
    balance = 10_000.0
    peak = balance
    max_dd = 0.0
    max_dd_pct = 0.0
    for value in values:
        balance += value
        peak = max(peak, balance)
        dd = peak - balance
        dd_pct = dd / peak * 100.0 if peak else 0.0
        if dd > max_dd:
            max_dd = dd
            max_dd_pct = dd_pct
    return max_dd, max_dd_pct


def max_consecutive_losses(rows: list[dict[str, object]]) -> int:
    current = 0
    max_count = 0
    for row in sorted(rows, key=lambda item: str(item.get("time", ""))):
        if as_float(row.get("net_profit")) < 0.0:
            current += 1
            max_count = max(max_count, current)
        elif as_float(row.get("net_profit")) > 0.0:
            current = 0
    return max_count


def distribution(rows: list[dict[str, object]], key: str) -> str:
    counts = Counter(str(row.get(key, "")) for row in rows if row.get(key, "") != "")
    return ";".join(f"{name}:{count}" for name, count in sorted(counts.items()))


def stats_for(rows: list[dict[str, object]]) -> dict[str, object]:
    profits = [as_float(row.get("net_profit")) for row in rows]
    result_rs = [as_float(row.get("result_R")) for row in rows]
    wins = [p for p in profits if p > 0.0]
    pf = profit_factor(profits)
    max_dd, max_dd_pct = max_drawdown(profits)
    months = month_buckets(rows)
    return {
        "trades": len(rows),
        "win_rate": round(len(wins) / len(rows) * 100.0, 2) if rows else 0.0,
        "PF": round(pf, 3) if pf is not None else "",
        "avg_R": round(sum(result_rs) / len(result_rs), 3) if result_rs else 0.0,
        "net": round(sum(profits), 2),
        "maxDD": round(max_dd, 2),
        "maxDD_pct": round(max_dd_pct, 2),
        "avg_MFE_R": round(sum(as_float(row.get("max_favorable_r")) for row in rows) / len(rows), 3) if rows else 0.0,
        "avg_MAE_R": round(sum(as_float(row.get("max_adverse_r")) for row in rows) / len(rows), 3) if rows else 0.0,
        "reached_0_5R_pct": round(sum(1 for row in rows if bool_value(row.get("reached_0_5R"))) / len(rows) * 100.0, 2) if rows else 0.0,
        "reached_1R_pct": round(sum(1 for row in rows if bool_value(row.get("reached_1R"))) / len(rows) * 100.0, 2) if rows else 0.0,
        "reached_2R_pct": round(sum(1 for row in rows if bool_value(row.get("reached_2R"))) / len(rows) * 100.0, 2) if rows else 0.0,
        "max_consecutive_losses": max_consecutive_losses(rows),
        "monthly_net": ";".join(f"{month}:{round(sum(as_float(r.get('net_profit')) for r in bucket), 2)}" for month, bucket in months.items()),
        "monthly_trades": ";".join(f"{month}:{len(bucket)}" for month, bucket in months.items()),
        "symbol_distribution": distribution(rows, "symbol"),
        "direction_distribution": distribution(rows, "direction"),
        "FX_net": round(sum(as_float(row.get("net_profit")) for row in rows if row.get("fx_bucket") == "FX"), 2),
        "XAUUSD_net": round(sum(as_float(row.get("net_profit")) for row in rows if row.get("fx_bucket") == "XAUUSD"), 2),
        "LONG_net": round(sum(as_float(row.get("net_profit")) for row in rows if row.get("direction") == "LONG"), 2),
        "SHORT_net": round(sum(as_float(row.get("net_profit")) for row in rows if row.get("direction") == "SHORT"), 2),
        "clean_or_acceptable_pct": clean_or_acceptable_pct(rows),
    }


def clean_or_acceptable_pct(rows: list[dict[str, object]]) -> float:
    if not rows:
        return 0.0
    count = sum(1 for row in rows if row.get("audit_fractal_entry_quality") in {"clean_fractal", "acceptable_fractal"})
    return round(count / len(rows) * 100.0, 2)


def month_buckets(rows: list[dict[str, object]]) -> dict[str, list[dict[str, object]]]:
    buckets: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        buckets[str(row.get("month", ""))].append(row)
    return dict(sorted(buckets.items()))


def group_rows(rows: list[dict[str, object]], key: str) -> list[dict[str, object]]:
    buckets: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        buckets[(str(row["scenario"]), str(row.get(key, "")))].append(row)
    return [{"scenario": scenario, "group": group, **stats_for(items)} for (scenario, group), items in sorted(buckets.items())]


def comparison_rows(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    rows_out: list[dict[str, object]] = []
    for scenario in sorted({str(row["scenario"]) for row in rows}):
        subset = [row for row in rows if row["scenario"] == scenario]
        rows_out.append({"scenario": scenario, "group": "ALL", **stats_for(subset)})
        filters = [
            ("FX only", lambda r: r.get("fx_bucket") == "FX"),
            ("XAUUSD only", lambda r: r.get("fx_bucket") == "XAUUSD"),
            ("LONG", lambda r: r.get("direction") == "LONG"),
            ("SHORT", lambda r: r.get("direction") == "SHORT"),
            ("FX LONG", lambda r: r.get("fx_bucket") == "FX" and r.get("direction") == "LONG"),
            ("FX SHORT", lambda r: r.get("fx_bucket") == "FX" and r.get("direction") == "SHORT"),
            ("XAUUSD LONG", lambda r: r.get("fx_bucket") == "XAUUSD" and r.get("direction") == "LONG"),
            ("XAUUSD SHORT", lambda r: r.get("fx_bucket") == "XAUUSD" and r.get("direction") == "SHORT"),
        ]
        for name, fn in filters:
            bucket = [row for row in subset if fn(row)]
            rows_out.append({"scenario": scenario, "group": name, **stats_for(bucket)})
    return rows_out


def write_output_set(prefix_name: str, rows: list[dict[str, object]]) -> None:
    prefix_path = BACKTEST / f"{OUT_BASE}_{prefix_name}"
    write_rows(prefix_path.with_name(prefix_path.name + "_comparison.csv"), comparison_rows(rows))
    write_rows(prefix_path.with_name(prefix_path.name + "_by_year.csv"), group_rows(rows, "year"))
    write_rows(prefix_path.with_name(prefix_path.name + "_by_month.csv"), group_rows(rows, "month"))
    write_rows(prefix_path.with_name(prefix_path.name + "_by_symbol.csv"), group_rows(rows, "symbol"))
    write_rows(prefix_path.with_name(prefix_path.name + "_by_direction.csv"), group_rows(rows, "direction"))
    write_rows(prefix_path.with_name(prefix_path.name + "_by_session.csv"), group_rows(rows, "session"))
    write_rows(prefix_path.with_name(prefix_path.name + "_fx_vs_xauusd.csv"), group_rows(rows, "fx_bucket"))
    write_rows(prefix_path.with_name(prefix_path.name + "_trades.csv"), rows)
    write_rows(prefix_path.with_name(prefix_path.name + "_fractal_audit.csv"), rows)


def row_for_group(rows: list[dict[str, object]], scenario: str, group: str) -> dict[str, object]:
    for row in comparison_rows(rows):
        if row["scenario"] == scenario and row["group"] == group:
            return row
    return {"scenario": scenario, "group": group, **stats_for([])}


def write_summary(h4_rows: list[dict[str, object]], lower_rows: list[dict[str, object]]) -> None:
    base = BACKTEST
    h4_scenario = "Nested_Fixed_Room2R_BOTH_all_H4_H1_M15_2R"
    lower_scenario = "Nested_Fixed_Room2R_LOWER_TF_BOTH_all_H1_M15_M5_2R"
    h4_all = row_for_group(h4_rows, h4_scenario, "ALL")
    lower_all = row_for_group(lower_rows, lower_scenario, "ALL")
    h4_by_year = group_rows(h4_rows, "year")
    lower_by_year = group_rows(lower_rows, "year")
    h4_annual_lt_100 = any(int(row["trades"]) < 100 for row in h4_by_year)
    h4_year_counts = ";".join(f"{row['group']}:{row['trades']}" for row in h4_by_year)

    gate_h4 = (
        as_float(h4_all.get("PF")) > 1.1
        and as_float(h4_all.get("avg_R")) > 0.0
        and int(h4_all.get("trades", 0)) >= 100
        and as_float(row_for_group(h4_rows, h4_scenario, "FX only").get("net")) > -100.0
        and as_float(row_for_group(h4_rows, h4_scenario, "LONG").get("net")) > -100.0
        and as_float(h4_all.get("clean_or_acceptable_pct")) > 50.0
    )
    gate_lower = (
        as_float(lower_all.get("PF")) > 1.1
        and as_float(lower_all.get("avg_R")) > 0.0
        and int(lower_all.get("trades", 0)) >= 100
        and as_float(row_for_group(lower_rows, lower_scenario, "FX only").get("net")) > -100.0
        and as_float(row_for_group(lower_rows, lower_scenario, "LONG").get("net")) > -100.0
        and as_float(lower_all.get("clean_or_acceptable_pct")) > 50.0
    )

    lines = [
        "# Fixed Room2R Annual And Lower TF Summary",
        "",
        "This validates `RESEARCH_STRATEGY_NESTED_FIXED_ROOM2R` on annual BT and runs the lower timeframe comparison because annual H4-H1-M15 trade counts were below 100 per year.",
        "",
        "## H4-H1-M15 Annual Result",
        "",
        f"- Trades: `{h4_all['trades']}`",
        f"- PF: `{h4_all['PF']}`",
        f"- Avg R: `{h4_all['avg_R']}`",
        f"- Net: `{h4_all['net']}`",
        f"- Max DD: `{h4_all['maxDD']}` / `{h4_all['maxDD_pct']}%`",
        f"- FX net: `{h4_all['FX_net']}`",
        f"- XAUUSD net: `{h4_all['XAUUSD_net']}`",
        f"- LONG net: `{h4_all['LONG_net']}`",
        f"- SHORT net: `{h4_all['SHORT_net']}`",
        f"- Clean/acceptable fractal: `{h4_all['clean_or_acceptable_pct']}%`",
        "",
        "## H1-M15-M5 Lower TF Result",
        "",
        f"- Trades: `{lower_all['trades']}`",
        f"- PF: `{lower_all['PF']}`",
        f"- Avg R: `{lower_all['avg_R']}`",
        f"- Net: `{lower_all['net']}`",
        f"- Max DD: `{lower_all['maxDD']}` / `{lower_all['maxDD_pct']}%`",
        f"- FX net: `{lower_all['FX_net']}`",
        f"- XAUUSD net: `{lower_all['XAUUSD_net']}`",
        f"- LONG net: `{lower_all['LONG_net']}`",
        f"- SHORT net: `{lower_all['SHORT_net']}`",
        f"- Clean/acceptable fractal: `{lower_all['clean_or_acceptable_pct']}%`",
        "",
        "## Required Answers",
        "",
        f"1. Annual H4-H1-M15 effectiveness: {'pass' if gate_h4 else 'fail'} by gate criteria.",
        f"2. Stability across 2024/2025/2026: see by-year CSV; multiple-year stability is {'acceptable' if gate_h4 else 'not proven'}.",
        f"3. Annual trade count sufficiency: total `{h4_all['trades']}`, by-year counts `{h4_year_counts}`.",
        f"4. H4-H1-M15 had years below 100 trades: `{bool_text(h4_annual_lt_100)}`.",
        "5. Lower TF H1-M15-M5 was executed because at least one annual H4-H1-M15 year had fewer than 100 trades.",
        f"6. Lower TF trade count changed from `{h4_all['trades']}` to `{lower_all['trades']}`.",
        f"7. Lower TF PF/avg_R: PF `{lower_all['PF']}`, avg_R `{lower_all['avg_R']}`.",
        f"8. FX only H4 vs Lower: `{row_for_group(h4_rows, h4_scenario, 'FX only')['net']}` vs `{row_for_group(lower_rows, lower_scenario, 'FX only')['net']}`.",
        f"9. XAUUSD dependence H4 vs Lower: `{h4_all['XAUUSD_net']}` vs `{lower_all['XAUUSD_net']}`.",
        f"10. LONG/SHORT balance H4: LONG `{h4_all['LONG_net']}`, SHORT `{h4_all['SHORT_net']}`; Lower: LONG `{lower_all['LONG_net']}`, SHORT `{lower_all['SHORT_net']}`.",
        f"11. M5 spread/noise proxy: lower TF avg_MAE_R `{lower_all['avg_MAE_R']}` and reached_0_5R `{lower_all['reached_0_5R_pct']}%`; inspect lower trades for `spread_atr` and false-BOS labels.",
        f"12. FX fit: {'lower TF' if as_float(row_for_group(lower_rows, lower_scenario, 'FX only').get('net')) > as_float(row_for_group(h4_rows, h4_scenario, 'FX only').get('net')) else 'H4-H1-M15'}.",
        f"13. XAUUSD fit: {'lower TF' if as_float(lower_all.get('XAUUSD_net')) > as_float(h4_all.get('XAUUSD_net')) else 'H4-H1-M15'}.",
        f"14. Next research candidate: {'H4-H1-M15' if gate_h4 else ('H1-M15-M5' if gate_lower else 'none')} by the current gate.",
        "15. Live-candidate promotion remains too early unless the gate passes without XAUUSD/SHORT concentration.",
        "",
        "## Gate Decision",
        "",
        f"- H4-H1-M15 gate: `{'pass' if gate_h4 else 'fail'}`",
        f"- H1-M15-M5 gate: `{'pass' if gate_lower else 'fail'}`",
        "",
        "## Artifacts",
        "",
        f"- H4 summary: {md_link('annual comparison CSV', BACKTEST / f'{OUT_BASE}_{H4_PREFIX}_comparison.csv', base)}",
        f"- H4 trades: {md_link('annual trades CSV', BACKTEST / f'{OUT_BASE}_{H4_PREFIX}_trades.csv', base)}",
        f"- H4 fractal audit: {md_link('annual fractal audit CSV', BACKTEST / f'{OUT_BASE}_{H4_PREFIX}_fractal_audit.csv', base)}",
        f"- H4 by session: {md_link('annual by session CSV', BACKTEST / f'{OUT_BASE}_{H4_PREFIX}_by_session.csv', base)}",
        f"- Lower summary: {md_link('lower comparison CSV', BACKTEST / f'{OUT_BASE}_{LOWER_PREFIX}_comparison.csv', base)}",
        f"- Lower trades: {md_link('lower trades CSV', BACKTEST / f'{OUT_BASE}_{LOWER_PREFIX}_trades.csv', base)}",
        f"- Lower fractal audit: {md_link('lower fractal audit CSV', BACKTEST / f'{OUT_BASE}_{LOWER_PREFIX}_fractal_audit.csv', base)}",
        f"- Lower by session: {md_link('lower by session CSV', BACKTEST / f'{OUT_BASE}_{LOWER_PREFIX}_by_session.csv', base)}",
        f"- TF comparison: {md_link('TF comparison markdown', BACKTEST / f'{OUT_BASE}_fixed_room2r_tf_comparison.md', base)}",
        f"- Compile log: {md_link('compile log', ROOT / 'reports' / 'compile' / 'ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_annual_compile.log', base)}",
        "",
    ]
    summary_text = "\n".join(lines)
    (BACKTEST / f"{OUT_BASE}_{H4_PREFIX}_summary.md").write_text(summary_text, encoding="utf-8")
    (BACKTEST / f"{OUT_BASE}_{LOWER_PREFIX}_summary.md").write_text(summary_text, encoding="utf-8")

    tf_lines = [
        "# Fixed Room2R Timeframe Comparison",
        "",
        "| timeframe_set | trades | PF | avg_R | net | maxDD | FX net | XAUUSD net | LONG net | SHORT net | clean/acceptable % |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
        f"| H4-H1-M15 | {h4_all['trades']} | {h4_all['PF']} | {h4_all['avg_R']} | {h4_all['net']} | {h4_all['maxDD']} | {h4_all['FX_net']} | {h4_all['XAUUSD_net']} | {h4_all['LONG_net']} | {h4_all['SHORT_net']} | {h4_all['clean_or_acceptable_pct']} |",
        f"| H1-M15-M5 | {lower_all['trades']} | {lower_all['PF']} | {lower_all['avg_R']} | {lower_all['net']} | {lower_all['maxDD']} | {lower_all['FX_net']} | {lower_all['XAUUSD_net']} | {lower_all['LONG_net']} | {lower_all['SHORT_net']} | {lower_all['clean_or_acceptable_pct']} |",
        "",
        "H1-M15-M5 is a comparison branch only. It keeps the same fixed Room2R idea and changes the timeframe stack one step lower.",
        "",
    ]
    (BACKTEST / f"{OUT_BASE}_fixed_room2r_tf_comparison.md").write_text("\n".join(tf_lines), encoding="utf-8")


def main() -> None:
    h4_rows = load_scenario(SCENARIOS[0])
    lower_rows = load_scenario(SCENARIOS[1])
    write_output_set(H4_PREFIX, h4_rows)
    write_output_set(LOWER_PREFIX, lower_rows)
    write_summary(h4_rows, lower_rows)
    (BACKTEST / f"{OUT_BASE}_fixed_room2r_annual_metrics.json").write_text(
        json.dumps(
            {
                "h4": row_for_group(h4_rows, SCENARIOS[0]["scenario"], "ALL"),
                "lower": row_for_group(lower_rows, SCENARIOS[1]["scenario"], "ALL"),
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(json.dumps({"h4": row_for_group(h4_rows, SCENARIOS[0]["scenario"], "ALL"), "lower": row_for_group(lower_rows, SCENARIOS[1]["scenario"], "ALL")}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
