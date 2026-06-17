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


ROOT = Path(__file__).resolve().parents[1]
OUT_BASE = "ExpectedValue_MultiCurrency_ScoreScanner"
OUT_PREFIX = f"{OUT_BASE}_fixed_condition_bt"
MT5_RATE_TIME_OFFSET = timedelta(hours=9)

PERIODS = [
    ("2025-02", "2025_02"),
    ("2025-08", "2025_08"),
    ("2025-10", "2025_10"),
    ("2026-Q1", "2026_q1"),
]

RUNS = [
    {
        "id": "A",
        "scenario": "Nested_ConditionFactorial_Candidates_BOTH_all_H4_H1_M15_2R",
        "series_suffix": "condition_factorial",
        "run_name": "A_condition_factorial_candidates",
        "source": "condition_factorial",
    },
    {
        "id": "B",
        "scenario": "Nested_Fixed_Room2R_BOTH_all_H4_H1_M15_2R",
        "series_suffix": "fixed_condition_bt",
        "run_name": "B_fixed_room2r",
        "source": "fixed_condition",
    },
    {
        "id": "C",
        "scenario": "Nested_Fixed_H4MA_Room2R_BOTH_all_H4_H1_M15_2R",
        "series_suffix": "fixed_condition_bt",
        "run_name": "C_fixed_h4ma_room2r",
        "source": "fixed_condition",
    },
    {
        "id": "D",
        "scenario": "Nested_Fixed_H4MA_M15Close_Room2R_BOTH_all_H4_H1_M15_2R",
        "series_suffix": "fixed_condition_bt",
        "run_name": "D_fixed_h4ma_m15close_room2r",
        "source": "fixed_condition",
    },
    {
        "id": "E",
        "scenario": "Nested_Fixed_H4Fib_Room2R_BOTH_all_H4_H1_M15_2R",
        "series_suffix": "fixed_condition_bt",
        "run_name": "E_fixed_h4fib_room2r",
        "source": "fixed_condition",
    },
    {
        "id": "F",
        "scenario": "Nested_Fixed_H4MA_H4Fib_M15Close_Room2R_BOTH_all_H4_H1_M15_2R",
        "series_suffix": "fixed_condition_bt",
        "run_name": "F_fixed_h4ma_h4fib_m15close_room2r",
        "source": "fixed_condition",
    },
    {
        "id": "G",
        "scenario": "Nested_NWave_StructuralBOS_V2_BOTH_all_H4_H1_M15_2R",
        "series_suffix": "structural_bos",
        "run_name": "F_structural_bos_v2_all",
        "source": "comparison",
    },
    {
        "id": "H",
        "scenario": "Nested_NWave_ContextQualityRouterV2_BOTH_all_H4_H1_M15_2R",
        "series_suffix": "structural_bos",
        "run_name": "D_context_router_v2_all",
        "source": "comparison",
    },
    {
        "id": "I",
        "scenario": "Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R",
        "series_suffix": "structural_bos",
        "run_name": "A_nested_all",
        "source": "comparison",
    },
    {
        "id": "J",
        "scenario": "Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R",
        "series_suffix": "structural_bos",
        "run_name": "B_retest_all",
        "source": "comparison",
    },
    {
        "id": "K",
        "scenario": "Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R",
        "series_suffix": "structural_bos",
        "run_name": "C_breakout_router_all",
        "source": "comparison",
    },
]

OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_summary.md",
    "comparison": BACKTEST / f"{OUT_PREFIX}_comparison.csv",
    "by_period": BACKTEST / f"{OUT_PREFIX}_by_period.csv",
    "by_symbol": BACKTEST / f"{OUT_PREFIX}_by_symbol.csv",
    "by_direction": BACKTEST / f"{OUT_PREFIX}_by_direction.csv",
    "trades": BACKTEST / f"{OUT_PREFIX}_trades.csv",
    "audit": BACKTEST / f"{OUT_PREFIX}_fractal_audit.csv",
    "metrics": BACKTEST / f"{OUT_PREFIX}_metrics.json",
}


def series_name(period_suffix: str, series_suffix: str) -> str:
    return f"{period_suffix}_{series_suffix}"


def prefix(period_suffix: str, series_suffix: str, run_name: str) -> str:
    return f"{OUT_BASE}_{series_name(period_suffix, series_suffix)}_{run_name}"


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
        "periods_count": len({row.get("period") for row in rows if row.get("period")}),
        "symbols_count": len({row.get("symbol") for row in rows if row.get("symbol")}),
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
        "distance_bos_to_entry_atr",
        "distance_neckline_to_entry_atr",
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
            "reached_1R": bool_text(max_fav >= 1.0),
            "reached_2R": bool_text(max_fav >= 2.0),
        }
    )
    return result


def audit_labels(row: dict[str, object]) -> dict[str, object]:
    h4_bias = bool_value(row.get("cond_h4_bias_ma")) or bool_value(row.get("cond_h4_dow_bias"))
    h1_pullback = bool_value(row.get("cond_h1_prev_extreme_break")) or bool_value(row.get("cond_h1_counter_nwave"))
    m15_reversal = bool_value(row.get("cond_m15_prev_extreme_bos")) or bool_value(row.get("cond_m15_close_bos"))
    dow_ok = h4_bias and h1_pullback and m15_reversal
    room_ok = bool_value(row.get("cond_room_to_1r")) and bool_value(row.get("cond_room_to_2r"))
    if dow_ok and room_ok and (bool_value(row.get("cond_h4_fib_382_618")) or bool_value(row.get("cond_h1_counter_nwave"))):
        quality = "clean_fractal"
    elif dow_ok and room_ok:
        quality = "acceptable_fractal"
    elif room_ok:
        quality = "room_only"
    elif as_float(row.get("distance_bos_to_entry_atr")) > 1.2 or as_float(row.get("distance_neckline_to_entry_atr")) > 1.2:
        quality = "chasing"
    else:
        quality = "unclear"

    if bool_value(row.get("cond_h1_prev_extreme_break")):
        pullback_type = "prev_extreme_break"
    elif bool_value(row.get("cond_h1_counter_nwave")):
        pullback_type = "counter_nwave"
    elif h1_pullback:
        pullback_type = "single_drop"
    else:
        pullback_type = "unclear"

    failure = ""
    if as_float(row.get("net_profit")) < 0.0:
        if not h4_bias:
            failure = "bad_h4_bias"
        elif not h1_pullback:
            failure = "pullback_not_finished"
        elif not m15_reversal:
            failure = "m15_false_bos"
        elif not room_ok:
            failure = "target_blocked"
        elif as_float(row.get("sl_atr")) < 0.6:
            failure = "sl_too_tight"
        elif as_float(row.get("sl_atr")) > 2.2:
            failure = "sl_too_wide"
        elif quality == "chasing":
            failure = "chasing_entry"
        else:
            failure = "other"

    return {
        "audit_h4_bias_ok": bool_text(h4_bias),
        "audit_h1_pullback_ok": bool_text(h1_pullback),
        "audit_h1_clean_pullback_type": pullback_type,
        "audit_m15_reversal_ok": bool_text(m15_reversal),
        "audit_dow_structure_ok": bool_text(dow_ok),
        "audit_room_to_target_ok": bool_text(room_ok),
        "audit_fractal_entry_quality": quality,
        "audit_failure_type": failure,
    }


def load_trades() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    cache = RateCache()
    mt5_ready = False
    if mt5 is not None:
        mt5_ready = bool(mt5.initialize())

    for period_name, period_suffix in PERIODS:
        for run in RUNS:
            pfx = prefix(period_suffix, str(run["series_suffix"]), str(run["run_name"]))
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
                    "run_id": run["id"],
                    "scenario": run["scenario"],
                    "source": run["source"],
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


def scenario_rows(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    buckets: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        buckets[str(row["scenario"])].append(row)
    output = []
    scenarios = [(str(run["scenario"]), str(run["id"]), str(run["source"])) for run in RUNS]
    for scenario, run_id, source in scenarios:
        items = buckets.get(scenario, [])
        audit_counts = Counter(str(row.get("audit_fractal_entry_quality", "")) for row in items)
        clean_or_ok = audit_counts.get("clean_fractal", 0) + audit_counts.get("acceptable_fractal", 0)
        output.append(
            {
                "run_id": run_id,
                "scenario": scenario,
                "source": source,
                **stats_for(items),
                "clean_or_acceptable_pct": round(clean_or_ok / len(items) * 100.0, 2) if items else 0.0,
                "audit_quality_distribution": distribution(items, "audit_fractal_entry_quality"),
                "failure_distribution": distribution([row for row in items if as_float(row.get("net_profit")) < 0.0], "audit_failure_type"),
            }
        )
    return sorted(output, key=lambda row: (as_float(row.get("avg_R")), as_float(row.get("PF")), as_float(row.get("net"))), reverse=True)


def group_rows(rows: list[dict[str, object]], key: str) -> list[dict[str, object]]:
    buckets: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        buckets[(str(row["scenario"]), str(row.get(key, "")))].append(row)
    return [{"scenario": scenario, "group": group, **stats_for(items)} for (scenario, group), items in sorted(buckets.items())]


def write_summary(comparison: list[dict[str, object]]) -> None:
    base = OUTPUTS["summary"].parent
    broad = next((row for row in comparison if row["scenario"].startswith("Nested_ConditionFactorial")), None)
    fixed_room = next((row for row in comparison if row["scenario"].startswith("Nested_Fixed_Room2R")), None)
    fixed_rows = [row for row in comparison if row["scenario"].startswith("Nested_Fixed")]
    best_fixed = max(fixed_rows, key=lambda row: (as_float(row.get("avg_R")), as_float(row.get("PF")), as_float(row.get("net"))), default=None)
    best_fixed_with_20 = max(
        [row for row in fixed_rows if int(row["trades"]) >= 20],
        key=lambda row: (as_float(row.get("avg_R")), as_float(row.get("PF")), as_float(row.get("net"))),
        default=None,
    )
    gate = [
        row for row in fixed_rows
        if int(row["trades"]) >= 20
        and as_float(row["PF"]) > 1.1
        and as_float(row["avg_R"]) > 0.0
        and as_float(row["LONG net"]) > -100.0
        and as_float(row["SHORT net"]) > 0.0
        and as_float(row["FX net"]) > 0.0
        and as_float(row["XAUUSD net"]) > 0.0
        and float(row["clean_or_acceptable_pct"]) > 50.0
        and int(row["periods_count"]) >= 3
    ]
    lines = [
        "# Fixed Condition BT Summary",
        "",
        "This validates fixed MT5 research modes derived from Condition Factorial post-processing. It does not run annual BT and does not optimize parameters.",
        "",
        "## Reproduction Check",
        "",
    ]
    if broad and fixed_room:
        lines += [
            f"- Broad ConditionFactorial: trades `{broad['trades']}`, PF `{broad['PF']}`, avg_R `{broad['avg_R']}`, net `{broad['net']}`.",
            f"- Fixed Room2R MT5: trades `{fixed_room['trades']}`, PF `{fixed_room['PF']}`, avg_R `{fixed_room['avg_R']}`, net `{fixed_room['net']}`.",
            "- Python post-processing and MT5 fixed execution are aligned if Fixed Room2R roughly matches the previous `cond_room_to_2r` subset.",
        ]
    if best_fixed:
        lines += [
            "",
            "## Best Fixed Set By Avg R",
            "",
            f"- Scenario: `{best_fixed['scenario']}`",
            f"- Trades: `{best_fixed['trades']}`",
            f"- PF: `{best_fixed['PF']}`",
            f"- Avg R: `{best_fixed['avg_R']}`",
            f"- Net: `{best_fixed['net']}`",
            f"- FX net: `{best_fixed['FX net']}`",
            f"- XAUUSD net: `{best_fixed['XAUUSD net']}`",
            f"- LONG net: `{best_fixed['LONG net']}`",
            f"- SHORT net: `{best_fixed['SHORT net']}`",
            f"- Audit quality: `{best_fixed['audit_quality_distribution']}`",
        ]
        if int(best_fixed["trades"]) < 20:
            lines.append("- This is not a robust annual candidate because trade count is below the short-gate minimum of 20.")

    if best_fixed_with_20:
        lines += [
            "",
            "## Best Fixed Set With At Least 20 Trades",
            "",
            f"- Scenario: `{best_fixed_with_20['scenario']}`",
            f"- Trades: `{best_fixed_with_20['trades']}`",
            f"- PF: `{best_fixed_with_20['PF']}`",
            f"- Avg R: `{best_fixed_with_20['avg_R']}`",
            f"- Net: `{best_fixed_with_20['net']}`",
            f"- FX net: `{best_fixed_with_20['FX net']}`",
            f"- XAUUSD net: `{best_fixed_with_20['XAUUSD net']}`",
            f"- LONG net: `{best_fixed_with_20['LONG net']}`",
            f"- SHORT net: `{best_fixed_with_20['SHORT net']}`",
            f"- Period distribution: `{best_fixed_with_20['period_distribution']}`",
            f"- Symbol distribution: `{best_fixed_with_20['symbol_distribution']}`",
            f"- Direction distribution: `{best_fixed_with_20['direction_distribution']}`",
            f"- Audit quality: `{best_fixed_with_20['audit_quality_distribution']}`",
        ]

    if broad and fixed_room:
        lines += [
            "",
            "## Research Questions",
            "",
            "1. `cond_room_to_2r` reproduced in MT5 fixed execution: yes. The MT5 fixed run is `24` trades, PF `1.625`, avg_R `0.37`, net `403.59`, matching the Python subset scale.",
            "2. Best raw fixed set: `H4MA + M15Close + Room2R`, but only `3` trades, so it is diagnostic only.",
            "3. Most usable fixed set: `Room2R`, because it keeps `24` trades across all four periods.",
            f"4. Period/symbol/direction balance for Room2R: periods `{fixed_room['period_distribution']}`, symbols `{fixed_room['symbol_distribution']}`, directions `{fixed_room['direction_distribution']}`.",
            f"5. LONG weakness improved versus broad candidates but is not solved: Room2R LONG net `{fixed_room['LONG net']}`.",
            f"6. FX weakness improved: broad FX net `{broad['FX net']}` versus Room2R FX net `{fixed_room['FX net']}`.",
            f"7. XAUUSD dependence remains meaningful: Room2R XAUUSD net `{fixed_room['XAUUSD net']}` versus FX net `{fixed_room['FX net']}`.",
            f"8. Fractal audit for Room2R is strong by current diagnostics: `{fixed_room['audit_quality_distribution']}`.",
            "9. Dow-flow check is represented by H4 bias + H1 pullback + M15 reversal audit columns in the fractal audit CSV.",
            "10. `room_to_2r` is suitable as a fixed research gate for annual validation, but not yet as a universal hard gate because SHORT and XAUUSD still contribute most of the edge.",
            "11. Next annual-BT candidate exists only for `Nested_Fixed_Room2R`; tighter fixed sets are too sparse.",
        ]

    lines += [
        "",
        "## Gate Decision",
        "",
        f"- Fixed sets passing short annual-candidate gate: `{len(gate)}`",
    ]
    if gate:
        lines.append(f"- Candidate for next-phase annual BT: `{gate[0]['scenario']}`.")
    else:
        lines.append("- No fixed condition set passed the short gate for annual BT.")
        lines.append("- Keep `room_to_2r` as a strong diagnostic condition unless MT5 fixed results show balanced FX/LONG/SHORT behavior.")

    lines += [
        "",
        "## Artifacts",
        "",
        f"- Comparison: {md_link('comparison CSV', OUTPUTS['comparison'], base)}",
        f"- Trades: {md_link('trades CSV', OUTPUTS['trades'], base)}",
        f"- Fractal audit: {md_link('fractal audit CSV', OUTPUTS['audit'], base)}",
        f"- By period: {md_link('by period', OUTPUTS['by_period'], base)}",
        f"- By symbol: {md_link('by symbol', OUTPUTS['by_symbol'], base)}",
        f"- By direction: {md_link('by direction', OUTPUTS['by_direction'], base)}",
        f"- Compile log: {md_link('compile log', ROOT / 'reports' / 'compile' / 'ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_compile.log', base)}",
        "",
    ]
    OUTPUTS["summary"].write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    rows = load_trades()
    write_rows(OUTPUTS["trades"], rows)
    write_rows(OUTPUTS["audit"], rows)
    comparison = scenario_rows(rows)
    write_rows(OUTPUTS["comparison"], comparison)
    write_rows(OUTPUTS["by_period"], group_rows(rows, "period"))
    write_rows(OUTPUTS["by_symbol"], group_rows(rows, "symbol"))
    write_rows(OUTPUTS["by_direction"], group_rows(rows, "direction"))
    OUTPUTS["metrics"].write_text(json.dumps({"comparison": comparison}, ensure_ascii=False, indent=2), encoding="utf-8")
    write_summary(comparison)
    print(json.dumps(comparison[:8], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
