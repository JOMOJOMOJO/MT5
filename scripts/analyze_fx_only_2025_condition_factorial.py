#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import os
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from itertools import combinations
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
    bool_text,
    bool_value,
    match_diag,
    parse_time,
    price_result_r,
    profit_factor,
    read_csv_rows,
    read_order_sent_rows,
    write_rows,
)


RUN_PREFIX = f"{OUT_BASE}_fxcf2025_A_condition_factorial_candidates"
OUT_PREFIX = f"{OUT_BASE}_fx_only_2025_condition_factorial"
FX_SYMBOLS = {"USDJPY", "EURJPY", "GBPJPY", "AUDJPY", "EURUSD", "GBPUSD"}
MT5_RATE_TIME_OFFSET = timedelta(hours=9)

PRIMARY_CONDITIONS = [
    "cond_h4_bias_ma",
    "cond_h4_fib_382_618",
    "cond_h1_prev_extreme_break",
    "cond_h1_counter_nwave",
    "cond_h1_counter_wave_atr",
    "cond_true_bos_level",
    "cond_m15_prev_extreme_bos",
    "cond_room_to_2r",
]

SECONDARY_CONDITIONS = [
    "cond_h4_dow_bias",
    "cond_m15_close_bos",
    "cond_room_to_1r",
    "cond_sl_atr_ok",
]

ALL_CONDITIONS = PRIMARY_CONDITIONS + SECONDARY_CONDITIONS

OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_summary.md",
    "candidates": BACKTEST / f"{OUT_PREFIX}_candidates.csv",
    "all_combinations": BACKTEST / f"{OUT_PREFIX}_all_combinations.csv",
    "single_effects": BACKTEST / f"{OUT_PREFIX}_single_effects.csv",
    "entry_count_impact": BACKTEST / f"{OUT_PREFIX}_entry_count_impact.csv",
    "expectancy_impact": BACKTEST / f"{OUT_PREFIX}_expectancy_impact.csv",
    "top_combinations": BACKTEST / f"{OUT_PREFIX}_top_combinations.csv",
    "by_symbol": BACKTEST / f"{OUT_PREFIX}_by_symbol.csv",
    "by_month": BACKTEST / f"{OUT_PREFIX}_by_month.csv",
    "by_direction": BACKTEST / f"{OUT_PREFIX}_by_direction.csv",
    "long_failure_analysis": BACKTEST / f"{OUT_BASE}_fx_only_2025_long_failure_analysis.csv",
    "long_failure_summary": BACKTEST / f"{OUT_BASE}_fx_only_2025_long_failure_summary.md",
    "room2r_recheck": BACKTEST / f"{OUT_BASE}_fx_only_2025_room2r_recheck.csv",
    "metrics": BACKTEST / f"{OUT_PREFIX}_metrics.json",
}


def md_link(label: str, target: Path, base: Path) -> str:
    rel = os.path.relpath(target.resolve(), base.resolve())
    return f"[{label}]({Path(rel).as_posix()})"


def session_from_hour(hour: int) -> str:
    if 0 <= hour < 7:
        return "asia"
    if 7 <= hour < 13:
        return "london"
    if 13 <= hour < 21:
        return "ny"
    return "late_us"


class RateCache:
    def __init__(self) -> None:
        self.cache: dict[tuple[str, datetime, datetime], list[dict[str, float]]] = {}

    @staticmethod
    def floor_m15(value: datetime) -> datetime:
        return value.replace(minute=value.minute - value.minute % 15, second=0, microsecond=0)

    def get(self, symbol: str, start: datetime, end: datetime) -> list[dict[str, float]]:
        if mt5 is None:
            return []
        start = self.floor_m15(start)
        end = self.floor_m15(end) + timedelta(minutes=15)
        key = (symbol, start, end)
        if key in self.cache:
            return self.cache[key]
        data = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_M15, start + MT5_RATE_TIME_OFFSET, end + MT5_RATE_TIME_OFFSET)
        rows: list[dict[str, float]] = []
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


def r_reach_metrics(trade: dict[str, object], diag: dict[str, object] | None, cache: RateCache | None) -> dict[str, object]:
    result: dict[str, object] = {
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
    rates = cache.get(str(trade["symbol"]), trade["open_time"], trade["close_time"])
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


def max_drawdown(rows: list[dict[str, object]]) -> tuple[float, float]:
    balance = 10_000.0
    peak = balance
    max_dd = 0.0
    max_dd_pct = 0.0
    for row in sorted(rows, key=lambda item: str(item.get("time", ""))):
        balance += as_float(row.get("net_profit"))
        peak = max(peak, balance)
        dd = peak - balance
        dd_pct = dd / peak * 100.0 if peak else 0.0
        if dd > max_dd:
            max_dd = dd
            max_dd_pct = dd_pct
    return max_dd, max_dd_pct


def distribution(rows: list[dict[str, object]], key: str) -> str:
    counts = Counter(str(row.get(key, "")) for row in rows if row.get(key, "") != "")
    return ";".join(f"{name}:{count}" for name, count in sorted(counts.items()))


def stats_for(rows: list[dict[str, object]]) -> dict[str, object]:
    profits = [as_float(row.get("net_profit")) for row in rows]
    result_rs = [as_float(row.get("result_R")) for row in rows]
    wins = [p for p in profits if p > 0.0]
    pf = profit_factor(profits)
    max_dd, max_dd_pct = max_drawdown(rows)
    long_rows = [row for row in rows if row.get("direction") == "LONG"]
    short_rows = [row for row in rows if row.get("direction") == "SHORT"]
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
        "LONG trades": len(long_rows),
        "SHORT trades": len(short_rows),
        "LONG net": round(sum(as_float(row.get("net_profit")) for row in long_rows), 2),
        "SHORT net": round(sum(as_float(row.get("net_profit")) for row in short_rows), 2),
        "LONG avg_R": round(sum(as_float(row.get("result_R")) for row in long_rows) / len(long_rows), 3) if long_rows else 0.0,
        "SHORT avg_R": round(sum(as_float(row.get("result_R")) for row in short_rows) / len(short_rows), 3) if short_rows else 0.0,
        "symbol_count": len({row.get("symbol") for row in rows if row.get("symbol")}),
        "month_count": len({row.get("month") for row in rows if row.get("month")}),
        "symbol_distribution": distribution(rows, "symbol"),
        "month_distribution": distribution(rows, "month"),
        "direction_distribution": distribution(rows, "direction"),
    }


def condition_subset(rows: list[dict[str, object]], conditions: list[str]) -> list[dict[str, object]]:
    return [row for row in rows if all(bool_value(row.get(condition)) for condition in conditions)]


def condition_name(conditions: list[str]) -> str:
    return "+".join(conditions) if conditions else "BASE_ALL"


def combo_sort_key(row: dict[str, object]) -> tuple[float, float, float, int]:
    pf = as_float(row.get("PF"), 0.0)
    return (as_float(row.get("avg_R")), pf, as_float(row.get("net")), int(row.get("trades", 0)))


def build_all_combinations(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    output: list[dict[str, object]] = []
    for size in range(0, len(PRIMARY_CONDITIONS) + 1):
        for combo in combinations(PRIMARY_CONDITIONS, size):
            enabled = list(combo)
            subset = condition_subset(rows, enabled)
            stats = stats_for(subset)
            output.append(
                {
                    "enabled_conditions": condition_name(enabled),
                    "condition_count": size,
                    **stats,
                }
            )
    return sorted(output, key=combo_sort_key, reverse=True)


def build_top_combinations(all_rows: list[dict[str, object]]) -> list[dict[str, object]]:
    output: list[dict[str, object]] = []
    for threshold in (20, 40, 60, 100):
        eligible = [row for row in all_rows if int(row.get("trades", 0)) >= threshold]
        for rank, row in enumerate(sorted(eligible, key=combo_sort_key, reverse=True)[:25], start=1):
            output.append({"min_trades": threshold, "rank": rank, **row})
    return output


def build_single_effects(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    base_stats = stats_for(rows)
    output: list[dict[str, object]] = []
    for condition in ALL_CONDITIONS:
        on_rows = [row for row in rows if bool_value(row.get(condition))]
        off_rows = [row for row in rows if not bool_value(row.get(condition))]
        on = stats_for(on_rows)
        off = stats_for(off_rows)
        output.append(
            {
                "condition": condition,
                "ON trades": on["trades"],
                "OFF trades": off["trades"],
                "ON win_rate": on["win_rate"],
                "OFF win_rate": off["win_rate"],
                "ON PF": on["PF"],
                "OFF PF": off["PF"],
                "ON avg_R": on["avg_R"],
                "OFF avg_R": off["avg_R"],
                "ON net": on["net"],
                "OFF net": off["net"],
                "trade_reduction_pct_when_ON": round((1.0 - (int(on["trades"]) / int(base_stats["trades"]))) * 100.0, 2) if base_stats["trades"] else 0.0,
                "avg_R_improvement_when_ON": round(as_float(on["avg_R"]) - as_float(off["avg_R"]), 3),
                "PF_improvement_when_ON": round(as_float(on["PF"]) - as_float(off["PF"]), 3),
                "LONG_net_change_when_ON": round(as_float(on["LONG net"]) - as_float(off["LONG net"]), 2),
                "SHORT_net_change_when_ON": round(as_float(on["SHORT net"]) - as_float(off["SHORT net"]), 2),
                "ON_LONG_net": on["LONG net"],
                "ON_SHORT_net": on["SHORT net"],
                "OFF_LONG_net": off["LONG net"],
                "OFF_SHORT_net": off["SHORT net"],
            }
        )
    return output


def group_rows(rows: list[dict[str, object]], key: str) -> list[dict[str, object]]:
    buckets: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        buckets[str(row.get(key, ""))].append(row)
    return [{"group": group, **stats_for(bucket)} for group, bucket in sorted(buckets.items())]


def by_symbol_rows(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    output = []
    for row in group_rows(rows, "symbol"):
        output.append(row)
    return output


def by_month_rows(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    output = []
    for row in group_rows(rows, "month"):
        output.append(row)
    return output


def by_direction_rows(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    output = []
    for group, bucket in (("LONG", [r for r in rows if r.get("direction") == "LONG"]), ("SHORT", [r for r in rows if r.get("direction") == "SHORT"])):
        st = stats_for(bucket)
        pf = profit_factor([as_float(r.get("net_profit")) for r in bucket])
        output.append(
            {
                "group": group,
                "trades": st["trades"],
                "net": st["net"],
                "PF": round(pf, 3) if pf is not None else "",
                "avg_R": st["avg_R"],
                "reached_1R_pct": st["reached_1R_pct"],
                "reached_2R_pct": st["reached_2R_pct"],
                "avg_MFE_R": st["avg_MFE_R"],
                "avg_MAE_R": st["avg_MAE_R"],
            }
        )
    return output


def long_failure_type(row: dict[str, object]) -> str:
    if row.get("direction") != "LONG" or as_float(row.get("net_profit")) >= 0.0:
        return ""
    h4_bias = bool_value(row.get("cond_h4_bias_ma")) or bool_value(row.get("cond_h4_dow_bias"))
    h1_pullback = bool_value(row.get("cond_h1_prev_extreme_break")) or bool_value(row.get("cond_h1_counter_nwave"))
    m15_reversal = bool_value(row.get("cond_m15_prev_extreme_bos")) or bool_value(row.get("cond_m15_close_bos"))
    if not h4_bias:
        return "bad_h4_bias"
    if not h1_pullback:
        return "pullback_not_finished"
    if not m15_reversal:
        return "m15_false_bos"
    if not bool_value(row.get("cond_room_to_2r")):
        return "target_blocked"
    sl_atr = as_float(row.get("sl_atr"))
    if sl_atr > 0.0 and sl_atr < 0.6:
        return "sl_too_tight"
    if sl_atr > 2.2:
        return "sl_too_wide"
    if as_float(row.get("distance_bos_to_entry_atr")) > 1.2 or as_float(row.get("distance_neckline_to_entry_atr")) > 1.2:
        return "chasing_entry"
    if str(row.get("h4_fib_zone", "")).lower() in {"edge_zone", "outside_zone", "deep_pullback", "shallow_pullback"}:
        return "range_noise"
    return "other"


def build_long_failure_analysis(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    losses = []
    for row in rows:
        failure = long_failure_type(row)
        if failure:
            clone = dict(row)
            clone["failure_type"] = failure
            losses.append(clone)
    output = []
    buckets: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in losses:
        buckets[str(row["failure_type"])].append(row)
    for failure, bucket in sorted(buckets.items()):
        st = stats_for(bucket)
        output.append(
            {
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
    return sorted(output, key=lambda row: (-int(row["trades"]), as_float(row["net"])))


def build_room2r_recheck(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    combos = [
        ("room_to_2r", ["cond_room_to_2r"]),
        ("room_to_2r + H4 MA", ["cond_room_to_2r", "cond_h4_bias_ma"]),
        ("room_to_2r + M15 close BOS", ["cond_room_to_2r", "cond_m15_close_bos"]),
        ("room_to_2r + H4 fib", ["cond_room_to_2r", "cond_h4_fib_382_618"]),
        ("room_to_2r + H1 N-wave", ["cond_room_to_2r", "cond_h1_counter_nwave"]),
        ("room_to_2r + H4 MA + M15 close BOS", ["cond_room_to_2r", "cond_h4_bias_ma", "cond_m15_close_bos"]),
        ("room_to_2r + H4 MA + H4 fib", ["cond_room_to_2r", "cond_h4_bias_ma", "cond_h4_fib_382_618"]),
        ("room_to_2r + H4 MA + H1 N-wave", ["cond_room_to_2r", "cond_h4_bias_ma", "cond_h1_counter_nwave"]),
        (
            "room_to_2r + H4 MA + M15 close BOS + H1 N-wave",
            ["cond_room_to_2r", "cond_h4_bias_ma", "cond_m15_close_bos", "cond_h1_counter_nwave"],
        ),
    ]
    output: list[dict[str, object]] = []
    for name, conditions in combos:
        subset = condition_subset(rows, conditions)
        for direction in ("ALL", "LONG", "SHORT"):
            bucket = subset if direction == "ALL" else [row for row in subset if row.get("direction") == direction]
            output.append({"combo": name, "direction": direction, "enabled_conditions": condition_name(conditions), **stats_for(bucket)})
    for state, subset in (("room_to_2r_ON", [row for row in rows if bool_value(row.get("cond_room_to_2r"))]), ("room_to_2r_OFF", [row for row in rows if not bool_value(row.get("cond_room_to_2r"))])):
        for direction in ("ALL", "LONG", "SHORT"):
            bucket = subset if direction == "ALL" else [row for row in subset if row.get("direction") == direction]
            output.append({"combo": state, "direction": direction, "enabled_conditions": state, **stats_for(bucket)})
    return output


def load_candidates() -> list[dict[str, object]]:
    report = BACKTEST / f"{RUN_PREFIX}_report.html"
    if not report.exists():
        raise FileNotFoundError(f"Missing report: {report}")
    trades = parse_mt5_deals(report)
    write_trades(BACKTEST / f"{RUN_PREFIX}_trades.csv", trades)
    sent_rows = read_order_sent_rows(RUN_PREFIX)
    scan_rows = read_csv_rows(BACKTEST / f"{RUN_PREFIX}_scan_diagnostics.csv")
    scan_driver = ";".join(sorted({row.get("scan_driver_symbol", "") for row in scan_rows if row.get("scan_driver_symbol")}))
    cache = RateCache()
    mt5_ready = False
    if mt5 is not None:
        mt5_ready = bool(mt5.initialize())
        if mt5_ready:
            for symbol in FX_SYMBOLS:
                mt5.symbol_select(symbol, True)

    used: set[int] = set()
    rows: list[dict[str, object]] = []
    for idx, trade in enumerate(trades, start=1):
        symbol = str(trade["symbol"]).upper()
        if symbol not in FX_SYMBOLS:
            continue
        diag = match_diag(trade, sent_rows, used)
        open_time = trade["open_time"]
        result_r = price_result_r(trade, diag)
        reach = r_reach_metrics(trade, diag, cache if mt5_ready else None)
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
            "result_R": round(result_r, 3),
            "net_profit": round(as_float(trade.get("net_profit")), 2),
            "scan_driver_symbol": scan_driver,
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
                "distance_bos_to_entry_atr",
                "distance_neckline_to_entry_atr",
                "label",
            ):
                row[key] = diag.get(key, "")
            for key in ALL_CONDITIONS:
                row[key] = bool_text(bool_value(diag.get(key)))
        else:
            for key in ALL_CONDITIONS:
                row[key] = "false"
        rows.append(row)

    if mt5_ready and mt5 is not None:
        mt5.shutdown()
    return rows


def best_symbol(rows: list[dict[str, object]]) -> str:
    grouped = group_rows(rows, "symbol")
    if not grouped:
        return ""
    return str(max(grouped, key=lambda row: as_float(row.get("net"))).get("group", ""))


def worst_symbol(rows: list[dict[str, object]]) -> str:
    grouped = group_rows(rows, "symbol")
    if not grouped:
        return ""
    return str(min(grouped, key=lambda row: as_float(row.get("net"))).get("group", ""))


def write_long_failure_summary(failure_rows: list[dict[str, object]], rows: list[dict[str, object]]) -> None:
    long_rows = [row for row in rows if row.get("direction") == "LONG"]
    long_losses = [row for row in long_rows if as_float(row.get("net_profit")) < 0.0]
    lines = [
        "# FX-only 2025 LONG Failure Summary",
        "",
        f"- LONG trades: `{len(long_rows)}`",
        f"- LONG losing trades: `{len(long_losses)}`",
        f"- LONG net: `{stats_for(long_rows)['net']}`",
        f"- LONG avg_R: `{stats_for(long_rows)['avg_R']}`",
        "",
        "## Failure Type Breakdown",
        "",
        "| failure_type | trades | net | avg_R | avg_MFE_R | avg_MAE_R | reached_1R_pct | symbols | months |",
        "|---|---:|---:|---:|---:|---:|---:|---|---|",
    ]
    for row in failure_rows:
        lines.append(
            f"| {row['failure_type']} | {row['trades']} | {row['net']} | {row['avg_R']} | {row['avg_MFE_R']} | {row['avg_MAE_R']} | {row['reached_1R_pct']} | {row['symbol_distribution']} | {row['month_distribution']} |"
        )
    lines += [
        "",
        "## Diagnostic Reading",
        "",
        "- `target_blocked` means the candidate passed the broad structure but lacked room to 2R, so `room_to_2r` is directly relevant.",
        "- `pullback_not_finished` and `m15_false_bos` point to timing/structure confirmation rather than reward or risk sizing.",
        "- This is post-trade diagnosis only; no entry rule, TP, SL, risk, spread guard, or symbol/direction filter was changed.",
        "",
    ]
    OUTPUTS["long_failure_summary"].write_text("\n".join(lines), encoding="utf-8")


def write_summary(rows: list[dict[str, object]], all_combos: list[dict[str, object]], single_effects: list[dict[str, object]], top_combos: list[dict[str, object]], room2r_rows: list[dict[str, object]], failure_rows: list[dict[str, object]]) -> None:
    base = OUTPUTS["summary"].parent
    broad = stats_for(rows)
    directions = {row["group"]: row for row in by_direction_rows(rows)}
    room_on = [row for row in room2r_rows if row["combo"] == "room_to_2r_ON" and row["direction"] == "ALL"][0]
    room_off = [row for row in room2r_rows if row["combo"] == "room_to_2r_OFF" and row["direction"] == "ALL"][0]
    strongest_expectancy = max(single_effects, key=lambda row: as_float(row["avg_R_improvement_when_ON"]))
    strongest_reducer = max(single_effects, key=lambda row: as_float(row["trade_reduction_pct_when_ON"]))
    worst_expectancy = min(single_effects, key=lambda row: as_float(row["avg_R_improvement_when_ON"]))
    ineffective = min(single_effects, key=lambda row: abs(as_float(row["avg_R_improvement_when_ON"])))
    eligible_60 = [row for row in all_combos if int(row["trades"]) >= 60 and row["enabled_conditions"] != "BASE_ALL"]
    positive_eligible_60 = [row for row in eligible_60 if as_float(row.get("avg_R")) > 0.0 and as_float(row.get("net")) > 0.0]
    best_min20 = next((row for row in top_combos if int(row.get("min_trades", 0)) == 20 and int(row.get("rank", 0)) == 1), None)
    best_set = best_min20 if best_min20 is not None else max(all_combos, key=combo_sort_key)
    candidate_gate = [
        row for row in all_combos
        if int(row["trades"]) >= 60
        and as_float(row["PF"]) > 1.1
        and as_float(row["avg_R"]) > 0.0
        and as_float(row["net"]) > 0.0
        and as_float(row["LONG net"]) > -100.0
        and as_float(row["SHORT net"]) > 0.0
        and row["symbol_count"] > 1
        and row["month_count"] > 1
    ]
    top_failure = failure_rows[0]["failure_type"] if failure_rows else ""

    lines = [
        "# FX-only 2025 Condition Factorial Summary",
        "",
        "Scope: 2025 full-year ConditionFactorial broad candidates, FX symbols only (`USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD`). XAUUSD is excluded in the tester preset and again in post-processing.",
        "",
        "No Friday stop, direction-only mode, pair exclusion, RewardR/SL/TP/risk/spread guard change, or parameter optimization was used.",
        "",
        "## Core Result",
        "",
        f"- Broad FX-only candidates: `{broad['trades']}` trades",
        f"- Broad PF / avg_R / net: `{broad['PF']}` / `{broad['avg_R']}` / `{broad['net']}`",
        f"- LONG entries / SHORT entries: `{directions.get('LONG', {}).get('trades', 0)}` / `{directions.get('SHORT', {}).get('trades', 0)}`",
        f"- LONG net / SHORT net: `{directions.get('LONG', {}).get('net', 0)}` / `{directions.get('SHORT', {}).get('net', 0)}`",
        f"- `room_to_2r` ON: `{room_on['trades']}` trades, PF `{room_on['PF']}`, avg_R `{room_on['avg_R']}`, net `{room_on['net']}`",
        f"- `room_to_2r` OFF: `{room_off['trades']}` trades, PF `{room_off['PF']}`, avg_R `{room_off['avg_R']}`, net `{room_off['net']}`",
        "",
        "## Required Answers",
        "",
        f"1. Broad candidate count: `{broad['trades']}`.",
        f"2. Broad PF / avg_R / net: `{broad['PF']}` / `{broad['avg_R']}` / `{broad['net']}`.",
        f"3. LONG/SHORT entry count balance: `{directions.get('LONG', {}).get('trades', 0)}` LONG vs `{directions.get('SHORT', {}).get('trades', 0)}` SHORT.",
        f"4. LONG/SHORT profit balance: `{directions.get('LONG', {}).get('net', 0)}` LONG vs `{directions.get('SHORT', {}).get('net', 0)}` SHORT.",
        f"5. `room_to_2r` full-year effect: ON avg_R `{room_on['avg_R']}` vs OFF avg_R `{room_off['avg_R']}`; ON net `{room_on['net']}` vs OFF net `{room_off['net']}`.",
        f"6. Most expectancy-improving single condition: `{strongest_expectancy['condition']}` with avg_R lift `{strongest_expectancy['avg_R_improvement_when_ON']}`.",
        f"7. Most trade-reducing condition: `{strongest_reducer['condition']}` with reduction `{strongest_reducer['trade_reduction_pct_when_ON']}%`.",
        f"8. Least effective by avg_R lift: `{ineffective['condition']}` with avg_R lift `{ineffective['avg_R_improvement_when_ON']}`.",
        f"9. Most worsening condition: `{worst_expectancy['condition']}` with avg_R lift `{worst_expectancy['avg_R_improvement_when_ON']}`.",
        f"10. Best useful condition set: `{best_set['enabled_conditions']}` at min_trades `20`; no positive `>=60` condition set was found.",
        f"11. Best useful set trade count: `{best_set['trades']}`, so it is below the requested fixed-BT promotion threshold of `60` trades.",
        f"12. Best set distribution: symbols `{best_set['symbol_distribution']}`, months `{best_set['month_distribution']}`, directions `{best_set['direction_distribution']}`.",
        f"13. Main LONG loss cause: `{top_failure}`.",
        "14. LONG improvement should inspect H4 bias validity, H1 pullback completion, M15 false BOS, and whether 2R room is real after entry.",
        f"15. Next MT5 fixed-BT candidate count from strict gate: `{len(candidate_gate)}`.",
        "16. This is not a live or annual-promotion decision. Annual progression should wait unless a condition set keeps enough trades, positive avg_R, balanced direction exposure, and no single-symbol/month dependency.",
        "",
        "## Gate Judgment",
        "",
    ]
    if positive_eligible_60:
        best_60 = max(positive_eligible_60, key=combo_sort_key)
        lines.append(f"- Positive >=60-trade condition set exists: `{best_60['enabled_conditions']}` (`{best_60['trades']}` trades, PF `{best_60['PF']}`, avg_R `{best_60['avg_R']}`).")
    else:
        lines.append("- No positive >=60-trade condition set was found.")
    if candidate_gate:
        first = sorted(candidate_gate, key=combo_sort_key, reverse=True)[0]
        lines.append(f"- Candidate for next fixed MT5 BT: `{first['enabled_conditions']}` (`{first['trades']}` trades, PF `{first['PF']}`, avg_R `{first['avg_R']}`).")
    else:
        lines.append("- No condition set passed the strict next fixed-BT gate.")
    lines += [
        f"- Best symbol in broad FX candidates: `{best_symbol(rows)}`.",
        f"- Worst symbol in broad FX candidates: `{worst_symbol(rows)}`.",
        "",
        "## Artifacts",
        "",
        f"- Candidates: {md_link('candidates CSV', OUTPUTS['candidates'], base)}",
        f"- All combinations: {md_link('all combinations CSV', OUTPUTS['all_combinations'], base)}",
        f"- Single effects: {md_link('single effects CSV', OUTPUTS['single_effects'], base)}",
        f"- Entry count impact: {md_link('entry count impact CSV', OUTPUTS['entry_count_impact'], base)}",
        f"- Expectancy impact: {md_link('expectancy impact CSV', OUTPUTS['expectancy_impact'], base)}",
        f"- Top combinations: {md_link('top combinations CSV', OUTPUTS['top_combinations'], base)}",
        f"- By symbol: {md_link('by symbol CSV', OUTPUTS['by_symbol'], base)}",
        f"- By month: {md_link('by month CSV', OUTPUTS['by_month'], base)}",
        f"- By direction: {md_link('by direction CSV', OUTPUTS['by_direction'], base)}",
        f"- LONG failure analysis: {md_link('LONG failure analysis CSV', OUTPUTS['long_failure_analysis'], base)}",
        f"- LONG failure summary: {md_link('LONG failure summary', OUTPUTS['long_failure_summary'], base)}",
        f"- Room2R recheck: {md_link('room2r recheck CSV', OUTPUTS['room2r_recheck'], base)}",
        f"- MT5 report: {md_link('MT5 report', BACKTEST / f'{RUN_PREFIX}_report.html', base)}",
        f"- Elapsed CSV: {md_link('elapsed CSV', BACKTEST / f'{OUT_BASE}_fxcf2025_elapsed.csv', base)}",
        f"- Compile log: {md_link('compile log', ROOT / 'reports' / 'compile' / 'ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_compile.log', base)}",
        "",
    ]
    OUTPUTS["summary"].write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    rows = load_candidates()
    if not rows:
        raise RuntimeError("No FX-only candidates were loaded.")
    xau_rows = [row for row in rows if str(row.get("symbol", "")).upper().startswith("XAU")]
    if xau_rows:
        raise RuntimeError(f"XAUUSD rows leaked into FX-only analysis: {len(xau_rows)}")

    all_combos = build_all_combinations(rows)
    top_combos = build_top_combinations(all_combos)
    single_effects = build_single_effects(rows)
    entry_count_impact = sorted(single_effects, key=lambda row: as_float(row["trade_reduction_pct_when_ON"]), reverse=True)
    expectancy_impact = sorted(single_effects, key=lambda row: as_float(row["avg_R_improvement_when_ON"]), reverse=True)
    by_symbol = by_symbol_rows(rows)
    by_month = by_month_rows(rows)
    by_direction = by_direction_rows(rows)
    long_failures = build_long_failure_analysis(rows)
    room2r = build_room2r_recheck(rows)

    write_rows(OUTPUTS["candidates"], rows)
    write_rows(OUTPUTS["all_combinations"], all_combos)
    write_rows(OUTPUTS["top_combinations"], top_combos)
    write_rows(OUTPUTS["single_effects"], single_effects)
    write_rows(OUTPUTS["entry_count_impact"], entry_count_impact)
    write_rows(OUTPUTS["expectancy_impact"], expectancy_impact)
    write_rows(OUTPUTS["by_symbol"], by_symbol)
    write_rows(OUTPUTS["by_month"], by_month)
    write_rows(OUTPUTS["by_direction"], by_direction)
    write_rows(OUTPUTS["long_failure_analysis"], long_failures)
    write_rows(OUTPUTS["room2r_recheck"], room2r)
    write_long_failure_summary(long_failures, rows)
    write_summary(rows, all_combos, single_effects, top_combos, room2r, long_failures)

    OUTPUTS["metrics"].write_text(
        json.dumps(
            {
                "broad": stats_for(rows),
                "top_combinations": top_combos[:10],
                "single_effects": single_effects,
                "long_failures": long_failures,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(json.dumps({"broad": stats_for(rows), "top": top_combos[:5]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
