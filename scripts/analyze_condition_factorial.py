#!/usr/bin/env python3
from __future__ import annotations

import csv
import itertools
import json
import math
import os
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

try:
    import MetaTrader5 as mt5
except ImportError:  # pragma: no cover - local MT5 package is optional for CSV-only review
    mt5 = None

from analyze_multicurrency_score_scanner_2025 import BACKTEST, calc_stats, parse_mt5_deals, write_trades


ROOT = Path(__file__).resolve().parents[1]
OUT_BASE = "ExpectedValue_MultiCurrency_ScoreScanner"
OUT_PREFIX = f"{OUT_BASE}_condition_factorial"
MT5_RATE_TIME_OFFSET = timedelta(hours=9)

PERIODS = [
    ("2025-02", "2025_02_condition_factorial"),
    ("2025-08", "2025_08_condition_factorial"),
    ("2025-10", "2025_10_condition_factorial"),
    ("2026-Q1", "2026_q1_condition_factorial"),
]

RUN_NAME = "A_condition_factorial_candidates"
SCENARIO = "Nested_ConditionFactorial_Candidates_BOTH_all_H4_H1_M15_2R"

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

OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_summary.md",
    "candidates": BACKTEST / f"{OUT_PREFIX}_candidates.csv",
    "all_combinations": BACKTEST / f"{OUT_PREFIX}_all_combinations.csv",
    "single_effects": BACKTEST / f"{OUT_PREFIX}_single_effects.csv",
    "entry_count_impact": BACKTEST / f"{OUT_PREFIX}_entry_count_impact.csv",
    "expectancy_impact": BACKTEST / f"{OUT_PREFIX}_expectancy_impact.csv",
    "top_combinations": BACKTEST / f"{OUT_PREFIX}_top_combinations.csv",
    "by_period": BACKTEST / f"{OUT_PREFIX}_by_period.csv",
    "by_symbol": BACKTEST / f"{OUT_PREFIX}_by_symbol.csv",
    "by_direction": BACKTEST / f"{OUT_PREFIX}_by_direction.csv",
    "metrics": BACKTEST / f"{OUT_PREFIX}_metrics.json",
}


def prefix(series: str) -> str:
    return f"{OUT_BASE}_{series}_{RUN_NAME}"


def md_link(label: str, target: Path, base: Path) -> str:
    rel = os.path.relpath(target.resolve(), base.resolve())
    return f"[{label}]({Path(rel).as_posix()})"


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return list(csv.DictReader(fh))


def write_rows(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        return
    fields: list[str] = []
    for row in rows:
        for key in row:
            if key not in fields:
                fields.append(key)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def as_float(value: Any, default: float = 0.0) -> float:
    try:
        text = str(value if value is not None else "").replace("\xa0", "").replace(" ", "").replace(",", "").strip()
        return float(text) if text else default
    except ValueError:
        return default


def parse_time(value: str) -> datetime | None:
    value = (value or "").strip()
    if not value:
        return None
    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")


def bool_value(value: Any) -> bool:
    return str(value).strip().lower() in {"true", "1", "yes"}


def bool_text(value: bool) -> str:
    return "true" if value else "false"


def profit_factor(values: list[float]) -> float | None:
    gross_profit = sum(v for v in values if v > 0.0)
    gross_loss = sum(v for v in values if v < 0.0)
    if gross_loss == 0.0:
        return None
    return gross_profit / abs(gross_loss)


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


def distribution(rows: list[dict[str, object]], key: str) -> str:
    counts = Counter(str(row.get(key, "")) for row in rows if row.get(key, "") != "")
    return ";".join(f"{name}:{count}" for name, count in sorted(counts.items()))


def stats_for(rows: list[dict[str, object]]) -> dict[str, object]:
    profits = [as_float(row.get("net_profit")) for row in rows]
    result_rs = [as_float(row.get("result_R")) for row in rows]
    wins = [p for p in profits if p > 0.0]
    pf = profit_factor(profits)
    max_dd, max_dd_pct = max_drawdown(profits)
    return {
        "candidates": len(rows),
        "trades": len(rows),
        "win_rate": round(len(wins) / len(rows) * 100.0, 2) if rows else 0.0,
        "PF": round(pf, 3) if pf is not None else "",
        "avg_R": round(sum(result_rs) / len(result_rs), 3) if result_rs else 0.0,
        "net": round(sum(profits), 2),
        "maxDD": round(max_dd, 2),
        "maxDD_pct": round(max_dd_pct, 2),
        "avg_MFE_R": round(sum(as_float(row.get("max_favorable_r")) for row in rows) / len(rows), 3) if rows else 0.0,
        "avg_MAE_R": round(sum(as_float(row.get("max_adverse_r")) for row in rows) / len(rows), 3) if rows else 0.0,
        "reached_1R_pct": round(sum(1 for row in rows if bool_value(row.get("reached_1R"))) / len(rows) * 100.0, 2) if rows else 0.0,
        "reached_2R_pct": round(sum(1 for row in rows if bool_value(row.get("reached_2R"))) / len(rows) * 100.0, 2) if rows else 0.0,
        "FX net": round(sum(as_float(row.get("net_profit")) for row in rows if row.get("fx_bucket") == "FX"), 2),
        "XAUUSD net": round(sum(as_float(row.get("net_profit")) for row in rows if row.get("fx_bucket") == "XAUUSD"), 2),
        "LONG net": round(sum(as_float(row.get("net_profit")) for row in rows if row.get("direction") == "LONG"), 2),
        "SHORT net": round(sum(as_float(row.get("net_profit")) for row in rows if row.get("direction") == "SHORT"), 2),
        "symbols_count": len({row.get("symbol") for row in rows if row.get("symbol")}),
        "periods_count": len({row.get("period") for row in rows if row.get("period")}),
        "period_distribution": distribution(rows, "period"),
        "symbol_distribution": distribution(rows, "symbol"),
        "direction_distribution": distribution(rows, "direction"),
    }


def read_scan_driver_symbols(pfx: str) -> str:
    rows = read_csv_rows(BACKTEST / f"{pfx}_scan_diagnostics.csv")
    symbols = sorted({row.get("scan_driver_symbol", "") for row in rows if row.get("scan_driver_symbol")})
    return ";".join(symbols)


def read_order_sent_rows(pfx: str) -> list[dict[str, object]]:
    rows = read_csv_rows(BACKTEST / f"{pfx}_nested_nwave_trade_diagnostics.csv")
    sent: list[dict[str, object]] = []
    numeric = {
        "entry_price",
        "sl",
        "tp",
        "risk_r",
        "rr",
        "sl_atr",
        "tp_atr",
        "h4_fib_retracement_pct",
        "h1_counter_wave_atr",
        "true_bos_level",
        "room_to_1r",
        "room_to_2r",
        "nearest_obstacle_price",
        "spread_atr",
        "spread_points",
        "quality_score",
    }
    for row in rows:
        if row.get("event") != "order_sent":
            continue
        parsed: dict[str, object] = dict(row)
        parsed["time_dt"] = parse_time(row.get("time", ""))
        for key in numeric:
            parsed[key] = as_float(row.get(key))
        sent.append(parsed)
    return sent


def match_diag(trade: dict[str, object], sent_rows: list[dict[str, object]], used: set[int]) -> dict[str, object] | None:
    best_idx = None
    best_delta = None
    open_time = trade["open_time"]
    for idx, row in enumerate(sent_rows):
        if idx in used:
            continue
        if row.get("symbol") != trade.get("symbol") or row.get("direction") != trade.get("direction"):
            continue
        row_time = row.get("time_dt")
        if not isinstance(row_time, datetime):
            continue
        delta = abs((open_time - row_time).total_seconds())
        if delta > 1800:
            continue
        if best_delta is None or delta < best_delta:
            best_delta = delta
            best_idx = idx
    if best_idx is None:
        return None
    used.add(best_idx)
    return sent_rows[best_idx]


def price_result_r(trade: dict[str, object], diag: dict[str, object] | None) -> float:
    if diag is None:
        return 0.0
    entry = as_float(diag.get("entry_price"))
    sl = as_float(diag.get("sl"))
    close = as_float(trade.get("close_price"))
    if entry <= 0.0 or sl <= 0.0 or close <= 0.0:
        return 0.0
    if trade.get("direction") == "LONG":
        risk = entry - sl
        return (close - entry) / risk if risk > 0.0 else 0.0
    risk = sl - entry
    return (entry - close) / risk if risk > 0.0 else 0.0


class RateCache:
    def __init__(self) -> None:
        self.cache: dict[tuple[str, datetime, datetime], list[dict[str, Any]]] = {}

    @staticmethod
    def floor_m15(value: datetime) -> datetime:
        return value.replace(minute=value.minute - value.minute % 15, second=0, microsecond=0)

    def get(self, symbol: str, start: datetime, end: datetime) -> list[dict[str, Any]]:
        if mt5 is None:
            return []
        start = self.floor_m15(start)
        end = self.floor_m15(end) + timedelta(minutes=15)
        key = (symbol, start, end)
        if key in self.cache:
            return self.cache[key]
        data = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_M15, start + MT5_RATE_TIME_OFFSET, end + MT5_RATE_TIME_OFFSET)
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


def r_reach_metrics(trade: dict[str, object], diag: dict[str, object] | None, cache: RateCache | None) -> dict[str, object]:
    result = {
        "max_favorable_r": "",
        "max_adverse_r": "",
        "reached_0_5R": "",
        "reached_1R": "",
        "reached_2R": "",
        "time_to_1R": "",
        "time_to_SL": "",
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
    time_to_1r = None
    time_to_sl = None
    for item in rates:
        if trade.get("direction") == "LONG":
            fav = (item["high"] - entry) / risk
            adv = (entry - item["low"]) / risk
        else:
            fav = (entry - item["low"]) / risk
            adv = (item["high"] - entry) / risk
        max_fav = max(max_fav, fav)
        max_adv = max(max_adv, adv)
        if time_to_1r is None and fav >= 1.0:
            time_to_1r = item["time"]
        if time_to_sl is None and adv >= 1.0:
            time_to_sl = item["time"]
    open_time = trade["open_time"]
    result.update(
        {
            "max_favorable_r": round(max_fav, 3),
            "max_adverse_r": round(max_adv, 3),
            "reached_0_5R": bool_text(max_fav >= 0.5),
            "reached_1R": bool_text(max_fav >= 1.0),
            "reached_2R": bool_text(max_fav >= 2.0),
            "time_to_1R": round((time_to_1r - open_time).total_seconds() / 60.0, 1) if time_to_1r else "",
            "time_to_SL": round((time_to_sl - open_time).total_seconds() / 60.0, 1) if time_to_sl else "",
        }
    )
    return result


def load_candidates() -> list[dict[str, object]]:
    candidates: list[dict[str, object]] = []
    cache = RateCache()
    mt5_ready = False
    if mt5 is not None:
        mt5_ready = bool(mt5.initialize())

    for period_name, series in PERIODS:
        pfx = prefix(series)
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
            result_r = price_result_r(trade, diag)
            reach = r_reach_metrics(trade, diag, cache if mt5_ready else None)
            row: dict[str, object] = {
                "period": period_name,
                "scenario": SCENARIO,
                "symbol": trade["symbol"],
                "direction": trade["direction"],
                "time": trade["open_time"].strftime("%Y.%m.%d %H:%M:%S"),
                "close_time": trade["close_time"].strftime("%Y.%m.%d %H:%M:%S"),
                "entry_price": diag.get("entry_price", "") if diag else trade.get("open_price", ""),
                "sl": diag.get("sl", "") if diag else "",
                "tp": diag.get("tp", "") if diag else "",
                "result_R": round(result_r, 3),
                "net_profit": round(as_float(trade.get("net_profit")), 2),
                "fx_bucket": "XAUUSD" if str(trade["symbol"]).upper().startswith("XAU") else "FX",
                "session": diag.get("session", "") if diag else "",
                "month": trade["open_time"].strftime("%Y-%m"),
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
                    "label",
                    "fail_reason",
                    "h4_pivot_sequence",
                    "h1_pivot_sequence",
                    "h4_impulse_atr",
                    "room_to_target_label",
                ):
                    row[key] = diag.get(key, "")
                for key in PRIMARY_CONDITIONS + SECONDARY_CONDITIONS:
                    row[key] = bool_text(bool_value(diag.get(key)))
            else:
                for key in PRIMARY_CONDITIONS + SECONDARY_CONDITIONS:
                    row[key] = "false"
            candidates.append(row)

    if mt5_ready and mt5 is not None:
        mt5.shutdown()
    return candidates


def combination_rows(candidates: list[dict[str, object]]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for size in range(len(PRIMARY_CONDITIONS) + 1):
        for combo in itertools.combinations(PRIMARY_CONDITIONS, size):
            enabled = list(combo)
            filtered = [row for row in candidates if all(bool_value(row.get(cond)) for cond in enabled)]
            stats = stats_for(filtered)
            rows.append(
                {
                    "enabled_conditions": ";".join(enabled) if enabled else "none",
                    "condition_count": len(enabled),
                    **stats,
                }
            )
    return rows


def single_effect_rows(candidates: list[dict[str, object]]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    total = len(candidates)
    for cond in PRIMARY_CONDITIONS + SECONDARY_CONDITIONS:
        on_rows = [row for row in candidates if bool_value(row.get(cond))]
        off_rows = [row for row in candidates if not bool_value(row.get(cond))]
        on_stats = stats_for(on_rows)
        off_stats = stats_for(off_rows)
        on_pf = as_float(on_stats.get("PF"), math.nan)
        off_pf = as_float(off_stats.get("PF"), math.nan)
        rows.append(
            {
                "condition": cond,
                "on_trades": on_stats["trades"],
                "off_trades": off_stats["trades"],
                "trade_reduction_pct": round((1.0 - (len(on_rows) / total)) * 100.0, 2) if total else 0.0,
                "on_PF": on_stats["PF"],
                "off_PF": off_stats["PF"],
                "on_avg_R": on_stats["avg_R"],
                "off_avg_R": off_stats["avg_R"],
                "on_net": on_stats["net"],
                "off_net": off_stats["net"],
                "avg_R_delta_on_minus_off": round(as_float(on_stats["avg_R"]) - as_float(off_stats["avg_R"]), 3),
                "PF_delta_on_minus_off": round(on_pf - off_pf, 3) if not math.isnan(on_pf) and not math.isnan(off_pf) else "",
                "on_period_distribution": on_stats["period_distribution"],
                "on_symbol_distribution": on_stats["symbol_distribution"],
                "on_direction_distribution": on_stats["direction_distribution"],
            }
        )
    return rows


def top_combination_rows(all_rows: list[dict[str, object]]) -> list[dict[str, object]]:
    output: list[dict[str, object]] = []
    for min_trades in (5, 10, 20):
        eligible = [row for row in all_rows if int(row["trades"]) >= min_trades]
        ranked = sorted(eligible, key=lambda row: (as_float(row.get("avg_R")), as_float(row.get("PF")), as_float(row.get("net"))), reverse=True)
        for rank, row in enumerate(ranked[:20], start=1):
            output.append({"min_trades": min_trades, "rank": rank, **row})
    return output


def group_rows(candidates: list[dict[str, object]], key: str) -> list[dict[str, object]]:
    buckets: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in candidates:
        buckets[str(row.get(key, ""))].append(row)
    return [{"group": group, **stats_for(rows)} for group, rows in sorted(buckets.items())]


def write_summary(
    candidates: list[dict[str, object]],
    all_combos: list[dict[str, object]],
    single_effects: list[dict[str, object]],
    top_combos: list[dict[str, object]],
) -> None:
    base = OUTPUTS["summary"].parent
    total_stats = stats_for(candidates)
    biggest_reduction = sorted(single_effects, key=lambda row: as_float(row["trade_reduction_pct"]), reverse=True)[:5]
    best_expectancy = sorted(single_effects, key=lambda row: as_float(row["avg_R_delta_on_minus_off"]), reverse=True)[:5]
    worst_expectancy = sorted(single_effects, key=lambda row: as_float(row["avg_R_delta_on_minus_off"]))[:5]
    best_20 = [row for row in top_combos if row["min_trades"] == 20][:5]
    gate_candidates = [
        row
        for row in top_combos
        if row["min_trades"] == 20
        and as_float(row.get("avg_R")) > 0.0
        and as_float(row.get("PF")) > 1.1
        and as_float(row.get("FX net")) > 0.0
        and as_float(row.get("XAUUSD net")) > 0.0
        and as_float(row.get("LONG net")) > 0.0
        and as_float(row.get("SHORT net")) > 0.0
        and int(row.get("periods_count", 0)) >= 2
    ]

    lines = [
        "# Condition Factorial Analysis",
        "",
        "This is a short-window diagnostic analysis. It does not optimize parameters and does not promote a new hard-gated strategy.",
        "",
        "## Candidate Coverage",
        "",
        f"- Scenario: `{SCENARIO}`",
        f"- Candidates/trades: `{total_stats['trades']}`",
        f"- PF: `{total_stats['PF']}`",
        f"- Avg R: `{total_stats['avg_R']}`",
        f"- Net: `{total_stats['net']}`",
        f"- Periods: `{total_stats['period_distribution']}`",
        f"- Symbols: `{total_stats['symbol_distribution']}`",
        f"- Directions: `{total_stats['direction_distribution']}`",
        "",
        "## Biggest Entry Count Reducers",
        "",
        "| condition | reduction % | on trades | on PF | on avg_R |",
        "|---|---:|---:|---:|---:|",
    ]
    for row in biggest_reduction:
        lines.append(f"| {row['condition']} | {row['trade_reduction_pct']} | {row['on_trades']} | {row['on_PF']} | {row['on_avg_R']} |")

    lines += [
        "",
        "## Best Single-Condition Expectancy Deltas",
        "",
        "| condition | avg_R delta | PF delta | on trades | on PF | on avg_R |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for row in best_expectancy:
        lines.append(f"| {row['condition']} | {row['avg_R_delta_on_minus_off']} | {row['PF_delta_on_minus_off']} | {row['on_trades']} | {row['on_PF']} | {row['on_avg_R']} |")

    lines += [
        "",
        "## Worst Single-Condition Expectancy Deltas",
        "",
        "| condition | avg_R delta | PF delta | on trades | on PF | on avg_R |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for row in worst_expectancy:
        lines.append(f"| {row['condition']} | {row['avg_R_delta_on_minus_off']} | {row['PF_delta_on_minus_off']} | {row['on_trades']} | {row['on_PF']} | {row['on_avg_R']} |")

    lines += [
        "",
        "## Top Combinations With Min Trades 20",
        "",
        "| rank | enabled conditions | trades | PF | avg_R | net | periods | symbols | directions |",
        "|---:|---|---:|---:|---:|---:|---|---|---|",
    ]
    for row in best_20:
        lines.append(
            f"| {row['rank']} | {row['enabled_conditions']} | {row['trades']} | {row['PF']} | {row['avg_R']} | {row['net']} | "
            f"{row['period_distribution']} | {row['symbol_distribution']} | {row['direction_distribution']} |"
        )

    lines += [
        "",
        "## Gate Judgment",
        "",
        f"- Fixed-condition candidate sets meeting the short diagnostic gate: `{len(gate_candidates)}`",
    ]
    if gate_candidates:
        first = gate_candidates[0]
        lines.append(f"- Best gate candidate: `{first['enabled_conditions']}` with `{first['trades']}` trades, PF `{first['PF']}`, avg_R `{first['avg_R']}`.")
        lines.append("- Next phase may test this fixed set in MT5, but only as a validation candidate, not an optimized parameter search.")
    else:
        best = best_20[0] if best_20 else None
        if best:
            lines.append(f"- Best min-trades-20 diagnostic set was `{best['enabled_conditions']}` with `{best['trades']}` trades, PF `{best['PF']}`, avg_R `{best['avg_R']}`.")
            lines.append(f"- It is not a validation candidate because balance remains weak: FX net `{best['FX net']}`, XAUUSD net `{best['XAUUSD net']}`, LONG net `{best['LONG net']}`, SHORT net `{best['SHORT net']}`.")
        lines.append("- No combination cleanly passed the short diagnostic gate for MT5 annual validation.")
        lines.append("- Keep the strongest conditions as diagnostic labels until a balanced fixed set appears.")

    lines += [
        "",
        "## Artifacts",
        "",
        f"- Candidates: {md_link('candidates', OUTPUTS['candidates'], base)}",
        f"- All combinations: {md_link('all combinations', OUTPUTS['all_combinations'], base)}",
        f"- Single effects: {md_link('single effects', OUTPUTS['single_effects'], base)}",
        f"- Entry count impact: {md_link('entry count impact', OUTPUTS['entry_count_impact'], base)}",
        f"- Expectancy impact: {md_link('expectancy impact', OUTPUTS['expectancy_impact'], base)}",
        f"- Top combinations: {md_link('top combinations', OUTPUTS['top_combinations'], base)}",
        f"- Compile log: {md_link('compile log', ROOT / 'reports' / 'compile' / 'ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_compile.log', base)}",
        "",
    ]
    OUTPUTS["summary"].write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    candidates = load_candidates()
    write_rows(OUTPUTS["candidates"], candidates)

    all_combos = combination_rows(candidates)
    write_rows(OUTPUTS["all_combinations"], all_combos)

    single = single_effect_rows(candidates)
    write_rows(OUTPUTS["single_effects"], single)
    write_rows(OUTPUTS["entry_count_impact"], sorted(single, key=lambda row: as_float(row["trade_reduction_pct"]), reverse=True))
    write_rows(OUTPUTS["expectancy_impact"], sorted(single, key=lambda row: as_float(row["avg_R_delta_on_minus_off"]), reverse=True))

    top = top_combination_rows(all_combos)
    write_rows(OUTPUTS["top_combinations"], top)
    write_rows(OUTPUTS["by_period"], group_rows(candidates, "period"))
    write_rows(OUTPUTS["by_symbol"], group_rows(candidates, "symbol"))
    write_rows(OUTPUTS["by_direction"], group_rows(candidates, "direction"))

    metrics = {
        "candidate_stats": stats_for(candidates),
        "primary_conditions": PRIMARY_CONDITIONS,
        "secondary_conditions": SECONDARY_CONDITIONS,
        "top_min_20": [row for row in top if row["min_trades"] == 20][:10],
    }
    OUTPUTS["metrics"].write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8")
    write_summary(candidates, all_combos, single, top)
    print(json.dumps(metrics["candidate_stats"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
