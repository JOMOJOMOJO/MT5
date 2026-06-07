#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import Counter, defaultdict
from datetime import datetime, timedelta
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


OUT_BASE = "ExpectedValue_MultiCurrency_ScoreScanner"
OUT_PREFIX = f"{OUT_BASE}_nested_nwave"
SOURCE_PREFIX = f"{OUT_BASE}_nested_nwave_neckline_break"
INITIAL_BALANCE = 10000.0
MT5_RATE_TIME_OFFSET = timedelta(hours=9)

PERIODS = [
    {"period": "2025-02", "series": "2025_02_nested_nwave"},
    {"period": "2025-08", "series": "2025_08_nested_nwave"},
    {"period": "2025-10", "series": "2025_10_nested_nwave"},
    {"period": "2026-Q1", "series": "2026_q1_nested_nwave"},
]

NESTED_RUNS = [
    {
        "run": "C",
        "name": "C_nested_best",
        "scenario": "Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R",
        "entry_selection_mode": "BEST_ONLY",
    },
    {
        "run": "D",
        "name": "D_nested_all",
        "scenario": "Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R",
        "entry_selection_mode": "ALL_SCORE_PASSING",
    },
]

REQUIRED_OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_failure_decomposition_summary.md",
    "decomposition": BACKTEST / f"{OUT_PREFIX}_failure_decomposition.csv",
    "neckline_quality": BACKTEST / f"{OUT_PREFIX}_neckline_quality.csv",
    "by_failure_type": BACKTEST / f"{OUT_PREFIX}_by_failure_type.csv",
    "by_winning_type": BACKTEST / f"{OUT_PREFIX}_by_winning_type.csv",
    "by_label_recheck": BACKTEST / f"{OUT_PREFIX}_by_label_recheck.csv",
    "mfe_mae": BACKTEST / f"{OUT_PREFIX}_mfe_mae_r_reach.csv",
    "by_setup_layer": BACKTEST / f"{OUT_PREFIX}_by_setup_layer.csv",
    "gate_candidates": BACKTEST / f"{OUT_PREFIX}_v2_gate_candidates.md",
}


def prefix(series: str, run_name: str) -> str:
    return f"{OUT_BASE}_{series}_{run_name}"


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return list(csv.DictReader(fh))


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


def parse_log_time(value: str) -> datetime | None:
    value = (value or "").strip()
    if not value:
        return None
    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")


def as_float(value: Any, default: float = 0.0) -> float:
    if value is None:
        return default
    text = str(value).strip().replace(" ", "").replace(",", "")
    if not text:
        return default
    try:
        return float(text)
    except ValueError:
        return default


def as_int(value: Any, default: int = 0) -> int:
    return int(round(as_float(value, float(default))))


def pf_value(stats: dict[str, object]) -> object:
    return round(float(stats["profit_factor"]), 3) if stats["profit_factor"] is not None else ""


def session_for_hour(hour: int) -> str:
    if 0 <= hour < 8:
        return "server_00_07"
    if 8 <= hour < 16:
        return "server_08_15"
    return "server_16_23"


def fx_bucket(symbol: str) -> str:
    return "XAUUSD" if symbol == "XAUUSD" else "FX"


def point_size(symbol: str) -> float:
    if symbol == "XAUUSD":
        return 0.01
    if symbol.endswith("JPY"):
        return 0.001
    return 0.00001


def price_to_points(symbol: str, value: float) -> float:
    point = point_size(symbol)
    return value / point if point > 0 else value


def floor_m5(value: datetime) -> datetime:
    return value.replace(minute=value.minute - value.minute % 5, second=0, microsecond=0)


def read_elapsed(series: str, run: str) -> float:
    path = BACKTEST / f"{OUT_BASE}_{series}_elapsed.csv"
    if not path.exists():
        return 0.0
    for row in read_csv_rows(path):
        if row.get("run") == run:
            return as_float(row.get("elapsed_seconds"))
    return 0.0


class RateCache:
    def __init__(self) -> None:
        self.cache: dict[tuple[str, datetime, datetime, int], list[dict[str, Any]]] = {}

    def get(self, symbol: str, start: datetime, end: datetime, timeframe: int = mt5.TIMEFRAME_M5) -> list[dict[str, Any]]:
        start = floor_m5(start)
        end = floor_m5(end) + timedelta(minutes=5)
        key = (symbol, start, end, timeframe)
        if key in self.cache:
            return self.cache[key]
        data = mt5.copy_rates_range(symbol, timeframe, start + MT5_RATE_TIME_OFFSET, end + MT5_RATE_TIME_OFFSET)
        if data is None:
            self.cache[key] = []
            return []
        rows: list[dict[str, Any]] = []
        for item in data:
            rows.append(
                {
                    "time": datetime.fromtimestamp(int(item["time"])) - MT5_RATE_TIME_OFFSET,
                    "open": float(item["open"]),
                    "high": float(item["high"]),
                    "low": float(item["low"]),
                    "close": float(item["close"]),
                    "tick_volume": int(item["tick_volume"]),
                }
            )
        self.cache[key] = rows
        return rows


def match_order_sent(
    trade: dict[str, object],
    rows: list[dict[str, str]],
    used: set[int],
) -> dict[str, str]:
    best_idx = -1
    best_delta = 10**9
    for idx, row in enumerate(rows):
        if idx in used:
            continue
        if row.get("event") != "order_sent":
            continue
        if row.get("symbol") != trade["symbol"] or row.get("direction") != trade["direction"]:
            continue
        log_time = parse_log_time(row.get("time", ""))
        if log_time is None:
            continue
        delta = abs((trade["open_time"] - log_time).total_seconds())
        if delta <= 1800 and delta < best_delta:
            best_idx = idx
            best_delta = int(delta)
    if best_idx >= 0:
        used.add(best_idx)
        return rows[best_idx]
    return {}


def match_signal_candidate(
    trade: dict[str, object],
    rows: list[dict[str, str]],
    used: set[int],
) -> dict[str, str]:
    best_idx = -1
    best_delta = 10**9
    for idx, row in enumerate(rows):
        if idx in used:
            continue
        if row.get("event") != "final_entry_candidate":
            continue
        if row.get("symbol") != trade["symbol"] or row.get("direction") != trade["direction"]:
            continue
        log_time = parse_log_time(row.get("time", ""))
        if log_time is None:
            continue
        delta = abs((trade["open_time"] - log_time).total_seconds())
        if delta <= 1800 and delta < best_delta:
            best_idx = idx
            best_delta = int(delta)
    if best_idx >= 0:
        used.add(best_idx)
        return rows[best_idx]
    return {}


def enrich_trades_for_run(period: str, run: dict[str, str]) -> list[dict[str, object]]:
    pfx = prefix(period.replace("-", "_").lower(), run["name"])
    # Prefixes use hand-authored series names, so resolve directly from PERIODS instead of lower-case period labels.
    pfx = prefix(next(item["series"] for item in PERIODS if item["period"] == period), run["name"])
    report_path = BACKTEST / f"{pfx}_report.html"
    if not report_path.exists():
        return []

    trades_csv = BACKTEST / f"{pfx}_trades.csv"
    if trades_csv.exists():
        trades = []
        with trades_csv.open(newline="", encoding="utf-8") as fh:
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
    else:
        trades = parse_mt5_deals(report_path)
        write_trades(trades_csv, trades)

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
                "period": period,
                "run": run["run"],
                "scenario": run["scenario"],
                "entry_selection_mode": run["entry_selection_mode"],
                "trade_index": idx,
                "month": row["open_time"].strftime("%Y-%m"),
                "hour": f"{row['open_time'].hour:02d}",
                "session": diag.get("session") or session_for_hour(row["open_time"].hour),
                "fx_bucket": fx_bucket(str(row["symbol"])),
                "elapsed_seconds": read_elapsed(next(item["series"] for item in PERIODS if item["period"] == period), run["run"]),
            }
        )
        for key, value in diag.items():
            row[f"diag_{key}"] = value
        for key, value in signal.items():
            row[f"signal_{key}"] = value
        row["label"] = diag.get("label", "unmatched")
        row["fib_zone"] = diag.get("fib_zone", "unknown")
        row["neckline_break_label"] = diag.get("neckline_break_label", "unknown")
        row["h4_trend_state"] = diag.get("h4_trend_state", "unknown")
        row["h1_counter_trend_state"] = diag.get("h1_counter_trend_state", "unknown")
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
        row["spread_points"] = as_float(diag.get("spread_points"))
        row["quality_score"] = as_float(diag.get("quality_score"))
        row["h4_impulse_high"] = as_float(signal.get("h4_impulse_high"))
        row["h4_impulse_low"] = as_float(signal.get("h4_impulse_low"))
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


def compute_price_path_metrics(row: dict[str, object], cache: RateCache) -> dict[str, object]:
    symbol = str(row["symbol"])
    direction = str(row["direction"])
    entry = as_float(row.get("entry_price_diag"), float(row["open_price"]))
    risk = as_float(row.get("risk_r"))
    neckline = as_float(row.get("neckline_price"))
    sign = 1.0 if direction == "LONG" else -1.0
    rates = cache.get(symbol, row["open_time"] - timedelta(hours=12), row["close_time"] + timedelta(minutes=15))
    trade_rates = [bar for bar in rates if floor_m5(row["open_time"]) <= bar["time"] <= row["close_time"] + timedelta(minutes=5)]
    pre_rates = [bar for bar in rates if row["open_time"] - timedelta(hours=12) <= bar["time"] < row["open_time"]]

    max_fav = 0.0
    max_adv = 0.0
    time_to: dict[float, object] = {0.5: "", 1.0: "", 1.5: "", 2.0: "", 3.0: ""}
    reached: dict[float, int] = {0.5: 0, 1.0: 0, 1.5: 0, 2.0: 0, 3.0: 0}
    returned_inside = 0
    return_bars = ""
    immediate_retest = 0
    time_to_sl = ""

    for idx, bar in enumerate(trade_rates):
        if direction == "LONG":
            fav = max(0.0, bar["high"] - entry)
            adv = max(0.0, entry - bar["low"])
            inside = neckline > 0 and bar["close"] <= neckline
            retest = neckline > 0 and bar["low"] <= neckline <= bar["high"]
            sl_hit = as_float(row.get("sl")) > 0 and bar["low"] <= as_float(row.get("sl"))
        else:
            fav = max(0.0, entry - bar["low"])
            adv = max(0.0, bar["high"] - entry)
            inside = neckline > 0 and bar["close"] >= neckline
            retest = neckline > 0 and bar["low"] <= neckline <= bar["high"]
            sl_hit = as_float(row.get("sl")) > 0 and bar["high"] >= as_float(row.get("sl"))
        max_fav = max(max_fav, fav)
        max_adv = max(max_adv, adv)
        if idx <= 4 and retest:
            immediate_retest = 1
        if returned_inside == 0 and idx <= 8 and inside:
            returned_inside = 1
            return_bars = idx
        if sl_hit and time_to_sl == "":
            time_to_sl = round((bar["time"] - row["open_time"]).total_seconds() / 60.0, 1)
        if risk > 0:
            fav_r = fav / risk
            for threshold in reached:
                if reached[threshold] == 0 and fav_r >= threshold:
                    reached[threshold] = 1
                    time_to[threshold] = round((bar["time"] - row["open_time"]).total_seconds() / 60.0, 1)

    breakout_bar = pre_rates[-1] if pre_rates else {}
    body = abs(as_float(breakout_bar.get("close")) - as_float(breakout_bar.get("open")))
    bar_range = as_float(breakout_bar.get("high")) - as_float(breakout_bar.get("low"))
    close = as_float(breakout_bar.get("close"))
    low = as_float(breakout_bar.get("low"))
    high = as_float(breakout_bar.get("high"))
    if bar_range > 0:
        body_ratio = body / bar_range
        if direction == "LONG":
            close_position = (close - low) / bar_range
        else:
            close_position = (high - close) / bar_range
        wick_ratio = 1.0 - body_ratio
    else:
        body_ratio = 0.0
        close_position = 0.0
        wick_ratio = 0.0

    m15_atr = as_float(row.get("m15_atr"))
    if m15_atr <= 0:
        m15_atr = as_float(row.get("risk_r")) / max(as_float(row.get("sl_atr")), 1e-9)
    m15_atr = max(m15_atr, 1e-9)
    mfe_r = max_fav / risk if risk > 0 else 0.0
    mae_r = max_adv / risk if risk > 0 else 0.0
    return {
        "max_favorable_r": round(mfe_r, 3),
        "max_adverse_r": round(mae_r, 3),
        "reached_0_5R": reached[0.5],
        "reached_1R": reached[1.0],
        "reached_1_5R": reached[1.5],
        "reached_2R": reached[2.0],
        "reached_3R": reached[3.0],
        "time_to_0_5R": time_to[0.5],
        "time_to_1R": time_to[1.0],
        "time_to_1_5R": time_to[1.5],
        "time_to_2R": time_to[2.0],
        "time_to_3R": time_to[3.0],
        "time_to_SL": time_to_sl,
        "did_price_reverse_after_1R": int(reached[1.0] == 1 and reached[2.0] == 0 and float(row["net_profit"]) < 0),
        "did_price_reverse_after_1_5R": int(reached[1.5] == 1 and reached[2.0] == 0 and float(row["net_profit"]) < 0),
        "would_1R_take_profit_help": int(reached[1.0] == 1 and float(row["net_profit"]) < 0),
        "would_1_5R_take_profit_help": int(reached[1.5] == 1 and float(row["net_profit"]) < 0),
        "would_2R_take_profit_work": int(reached[2.0] == 1),
        "false_break_return_inside_neckline": returned_inside,
        "false_break_return_bars": return_bars,
        "immediate_retest_within_4_bars": immediate_retest,
        "breakout_body_points": round(price_to_points(symbol, body), 1),
        "breakout_body_atr": round(body / m15_atr, 3),
        "breakout_body_ratio": round(body_ratio, 3),
        "breakout_wick_ratio": round(wick_ratio, 3),
        "breakout_close_strength": round(close_position, 3),
        "close_position_in_bar": round(close_position, 3),
        "breakout_volume_proxy": as_int(breakout_bar.get("tick_volume")),
        "m15_atr_proxy": round(m15_atr, 8),
    }


def compute_neckline_quality(row: dict[str, object], cache: RateCache) -> dict[str, object]:
    symbol = str(row["symbol"])
    neckline = as_float(row.get("neckline_price"))
    right_side = as_float(row.get("right_side_level"))
    entry = as_float(row.get("entry_price_diag"), float(row["open_price"]))
    m15_atr = as_float(row.get("m15_atr"))
    if m15_atr <= 0:
        m15_atr = as_float(row.get("risk_r")) / max(as_float(row.get("sl_atr")), 1e-9)
    m15_atr = max(m15_atr, 1e-9)
    tolerance = max(m15_atr * 0.15, point_size(symbol) * max(as_float(row.get("spread_points")), 5.0))
    rates = cache.get(symbol, row["open_time"] - timedelta(hours=12), row["open_time"])
    touch_count = 0
    for bar in rates:
        if neckline <= 0:
            continue
        if abs(bar["high"] - neckline) <= tolerance or abs(bar["low"] - neckline) <= tolerance or abs(bar["close"] - neckline) <= tolerance:
            touch_count += 1
    neckline_range = abs(neckline - right_side) if neckline > 0 and right_side > 0 else 0.0
    entry_distance = abs(entry - neckline) if neckline > 0 else 0.0
    source_type = "double_bottom" if row["direction"] == "LONG" else "double_top"
    if row.get("label") == "chasing_after_break":
        source_type = "simplified_pattern"
    return {
        "neckline_price": round(neckline, 6),
        "neckline_source_type": source_type,
        "neckline_touch_count": touch_count,
        "neckline_age_bars": as_int(row.get("bars_since_right_side")),
        "neckline_range_points": round(price_to_points(symbol, neckline_range), 1),
        "neckline_range_atr": round(neckline_range / m15_atr, 3),
        "right_shoulder_or_right_bottom_distance_points": round(price_to_points(symbol, neckline_range), 1),
        "right_shoulder_or_right_bottom_distance_atr": round(neckline_range / m15_atr, 3),
        "entry_close_distance_from_neckline_points": round(price_to_points(symbol, entry_distance), 1),
        "entry_close_distance_from_neckline_atr": round(entry_distance / m15_atr, 3),
        "bars_since_pattern_completed": as_int(row.get("bars_since_right_side")),
        "bars_since_neckline_defined": as_int(row.get("bars_since_right_side")),
        "bars_since_counter_trend_nwave_completed": as_int(row.get("bars_since_right_side")),
    }


def bucket_h4_pullback(row: dict[str, object]) -> str:
    value = as_float(row.get("h4_fib_retracement_pct"))
    if value <= 0:
        return "unknown"
    if value < 42:
        return "38-42_shallow_zone"
    if value < 50:
        return "42-50"
    if value < 58:
        return "50-58"
    return "58-62_deep_zone"


def bucket_sl_atr(value: float) -> str:
    if value <= 0:
        return "unknown"
    if value < 1.0:
        return "<1.0"
    if value < 1.5:
        return "1.0-1.5"
    if value < 2.0:
        return "1.5-2.0"
    return "2.0+"


def bucket_spread(value: float) -> str:
    if value <= 0:
        return "unknown"
    if value < 0.1:
        return "<0.10"
    if value < 0.2:
        return "0.10-0.20"
    return "0.20+"


def bucket_mfe(value: float) -> str:
    if value < 0.5:
        return "<0.5R"
    if value < 1.0:
        return "0.5-1R"
    if value < 1.5:
        return "1-1.5R"
    if value < 2.0:
        return "1.5-2R"
    return "2R+"


def classify_failure(row: dict[str, object]) -> str:
    if float(row["net_profit"]) >= 0:
        return ""
    if as_float(row.get("spread_atr")) >= 0.2:
        return "spread_or_execution_issue"
    if as_int(row.get("false_break_return_inside_neckline")) == 1:
        return "false_breakout"
    if as_float(row.get("max_favorable_r")) < 0.5:
        return "no_follow_through"
    if as_int(row.get("reached_1R")) == 1 and as_int(row.get("reached_2R")) == 0:
        return "target_too_far"
    if str(row.get("label")) in {"neckline_break_late", "chasing_after_break"} or as_float(row.get("entry_close_distance_from_neckline_atr")) > 0.75:
        return "late_breakout"
    if as_float(row.get("sl_atr")) < 1.0:
        return "sl_too_tight"
    if as_float(row.get("sl_atr")) >= 2.0:
        return "sl_too_wide"
    if bucket_h4_pullback(row) in {"38-42_shallow_zone", "58-62_deep_zone"}:
        return "weak_h4_context"
    if as_float(row.get("quality_score")) < 70 or as_int(row.get("bars_since_right_side")) > 8:
        return "weak_h1_counter_nwave"
    if as_float(row.get("breakout_body_atr")) > 1.0:
        return "high_volatility_noise"
    return "unclear"


def classify_winner(row: dict[str, object]) -> str:
    if float(row["net_profit"]) <= 0:
        return ""
    if as_int(row.get("immediate_retest_within_4_bars")) == 1 and as_int(row.get("reached_2R")) == 1:
        return "retest_then_go"
    if as_float(row.get("breakout_body_ratio")) >= 0.6 and as_float(row.get("breakout_close_strength")) >= 0.7:
        return "strong_body_breakout"
    if as_float(row.get("time_to_1R") or 999999) <= 180:
        return "fast_follow_through"
    if str(row.get("label")) in {"clean_nested_nwave_entry", "neckline_break_initial"} and bucket_h4_pullback(row) in {"42-50", "50-58"}:
        return "h4_context_aligned"
    if as_float(row.get("quality_score")) >= 100:
        return "h1_counter_trend_exhausted"
    if as_int(row.get("reached_2R")) == 1:
        return "clean_break_and_go"
    return "slow_grind_follow_through"


def classify_setup_layer(row: dict[str, object]) -> str:
    if float(row["net_profit"]) >= 0:
        return "n/a_win"
    failure = str(row.get("failure_type"))
    if failure == "weak_h4_context":
        return "H4_context_problem"
    if failure == "weak_h1_counter_nwave":
        return "H1_counter_nwave_problem"
    if failure in {"false_breakout", "no_follow_through", "high_volatility_noise"}:
        return "M15_neckline_quality_problem"
    if failure == "late_breakout":
        return "entry_timing_problem"
    if failure in {"target_too_far", "sl_too_tight", "sl_too_wide"}:
        return "SL_TP_design_problem"
    if failure == "spread_or_execution_issue":
        return "execution_problem"
    return "mixed"


def true_clean_candidate(row: dict[str, object]) -> int:
    return int(
        str(row.get("label")) in {"clean_nested_nwave_entry", "neckline_break_initial"}
        and as_float(row.get("entry_close_distance_from_neckline_atr")) <= 0.4
        and as_float(row.get("breakout_close_strength")) >= 0.6
        and as_int(row.get("false_break_return_inside_neckline")) == 0
        and bucket_h4_pullback(row) in {"42-50", "50-58"}
        and as_float(row.get("sl_atr")) < 2.0
    )


def build_analysis_rows() -> list[dict[str, object]]:
    if not mt5.initialize():
        raise RuntimeError(f"MetaTrader5 initialize failed: {mt5.last_error()}")
    cache = RateCache()
    rows: list[dict[str, object]] = []
    try:
        for period in PERIODS:
            for run in NESTED_RUNS:
                for row in enrich_trades_for_run(period["period"], run):
                    price_metrics = compute_price_path_metrics(row, cache)
                    quality = compute_neckline_quality(row, cache)
                    row.update(quality)
                    row.update(price_metrics)
                    row["final_result_R"] = round(result_r(row), 3)
                    row["h4_pullback_depth_bucket"] = bucket_h4_pullback(row)
                    row["sl_atr_bucket"] = bucket_sl_atr(as_float(row.get("sl_atr")))
                    row["spread_atr_bucket"] = bucket_spread(as_float(row.get("spread_atr")))
                    row["mfe_bucket"] = bucket_mfe(as_float(row.get("max_favorable_r")))
                    row["failure_type"] = classify_failure(row)
                    row["winning_type"] = classify_winner(row)
                    row["setup_failure_layer"] = classify_setup_layer(row)
                    row["true_clean_candidate"] = true_clean_candidate(row)
                    rows.append(row)
    finally:
        mt5.shutdown()
    return rows


def stats_from_rows(rows: list[dict[str, object]]) -> dict[str, object]:
    synthetic = []
    base_time = datetime(2000, 1, 1)
    for index, row in enumerate(rows):
        synthetic.append(
            {
                "net_profit": float(row.get("net_profit", 0.0)),
                "open_time": base_time + timedelta(minutes=index),
                "close_time": base_time + timedelta(minutes=index + 1),
            }
        )
    return calc_stats(synthetic)


def aggregate(rows: list[dict[str, object]], group_fields: list[str]) -> list[dict[str, object]]:
    buckets: dict[tuple[str, ...], list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        buckets[tuple(str(row.get(field, "")) for field in group_fields)].append(row)
    output: list[dict[str, object]] = []
    for key, bucket in sorted(buckets.items()):
        stats = stats_from_rows(bucket)
        result = {field: value for field, value in zip(group_fields, key)}
        result.update(
            {
                "trades": len(bucket),
                "wins": stats["wins"],
                "losses": stats["losses"],
                "win_rate": round(float(stats["win_rate"]), 2),
                "net_profit": round(float(stats["net_profit"]), 2),
                "profit_factor": pf_value(stats),
                "expected_payoff": round(float(stats["expected_payoff"]), 2),
                "avg_R": round(sum(as_float(row.get("final_result_R")) for row in bucket) / len(bucket), 3) if bucket else 0.0,
                "max_drawdown": round(float(stats["max_balance_dd"]), 2),
                "max_drawdown_pct": round(float(stats["max_balance_dd_pct"]), 2),
                "fx_net": round(sum(float(row["net_profit"]) for row in bucket if row["symbol"] != "XAUUSD"), 2),
                "xauusd_net": round(sum(float(row["net_profit"]) for row in bucket if row["symbol"] == "XAUUSD"), 2),
                "long_net": round(sum(float(row["net_profit"]) for row in bucket if row["direction"] == "LONG"), 2),
                "short_net": round(sum(float(row["net_profit"]) for row in bucket if row["direction"] == "SHORT"), 2),
                "avg_mfe_R": round(sum(as_float(row.get("max_favorable_r")) for row in bucket) / len(bucket), 3) if bucket else 0.0,
                "avg_mae_R": round(sum(as_float(row.get("max_adverse_r")) for row in bucket) / len(bucket), 3) if bucket else 0.0,
                "reached_0_5R_pct": round(sum(as_int(row.get("reached_0_5R")) for row in bucket) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "reached_1R_pct": round(sum(as_int(row.get("reached_1R")) for row in bucket) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "reached_2R_pct": round(sum(as_int(row.get("reached_2R")) for row in bucket) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "false_break_return_pct": round(sum(as_int(row.get("false_break_return_inside_neckline")) for row in bucket) / len(bucket) * 100.0, 2) if bucket else 0.0,
            }
        )
        output.append(result)
    return output


def compact_trade_row(row: dict[str, object]) -> dict[str, object]:
    keys = [
        "period",
        "run",
        "scenario",
        "entry_selection_mode",
        "trade_index",
        "open_time",
        "close_time",
        "symbol",
        "direction",
        "session",
        "month",
        "fx_bucket",
        "net_profit",
        "final_result_R",
        "label",
        "neckline_break_label",
        "fib_zone",
        "h4_trend_state",
        "h1_counter_trend_state",
        "h4_pullback_depth_bucket",
        "neckline_source_type",
        "neckline_touch_count",
        "neckline_age_bars",
        "neckline_range_atr",
        "entry_close_distance_from_neckline_atr",
        "breakout_body_atr",
        "breakout_body_ratio",
        "breakout_wick_ratio",
        "breakout_close_strength",
        "immediate_retest_within_4_bars",
        "false_break_return_inside_neckline",
        "false_break_return_bars",
        "max_favorable_r",
        "max_adverse_r",
        "reached_0_5R",
        "reached_1R",
        "reached_1_5R",
        "reached_2R",
        "reached_3R",
        "mfe_bucket",
        "time_to_0_5R",
        "time_to_1R",
        "time_to_2R",
        "time_to_SL",
        "did_price_reverse_after_1R",
        "did_price_reverse_after_1_5R",
        "sl_atr",
        "sl_atr_bucket",
        "spread_atr",
        "spread_atr_bucket",
        "quality_score",
        "failure_type",
        "winning_type",
        "setup_failure_layer",
        "true_clean_candidate",
    ]
    result = {}
    for key in keys:
        value = row.get(key, "")
        if isinstance(value, datetime):
            value = value.strftime("%Y.%m.%d %H:%M:%S")
        result[key] = value
    return result


def neckline_quality_row(row: dict[str, object]) -> dict[str, object]:
    keys = [
        "period",
        "run",
        "scenario",
        "trade_index",
        "open_time",
        "symbol",
        "direction",
        "net_profit",
        "final_result_R",
        "label",
        "winning_type",
        "failure_type",
        "neckline_price",
        "neckline_source_type",
        "neckline_touch_count",
        "neckline_age_bars",
        "neckline_range_points",
        "neckline_range_atr",
        "right_shoulder_or_right_bottom_distance_points",
        "right_shoulder_or_right_bottom_distance_atr",
        "entry_close_distance_from_neckline_points",
        "entry_close_distance_from_neckline_atr",
        "breakout_body_points",
        "breakout_body_atr",
        "breakout_body_ratio",
        "breakout_wick_ratio",
        "breakout_close_strength",
        "close_position_in_bar",
        "breakout_volume_proxy",
        "bars_since_pattern_completed",
        "bars_since_neckline_defined",
        "bars_since_counter_trend_nwave_completed",
        "immediate_retest_within_4_bars",
        "false_break_return_inside_neckline",
        "false_break_return_bars",
        "max_favorable_r",
        "max_adverse_r",
        "reached_0_5R",
        "reached_1R",
        "reached_1_5R",
        "reached_2R",
        "time_to_0_5R",
        "time_to_1R",
        "time_to_2R",
        "time_to_SL",
    ]
    result = {}
    for key in keys:
        value = row.get(key, "")
        if isinstance(value, datetime):
            value = value.strftime("%Y.%m.%d %H:%M:%S")
        result[key] = value
    return result


def mfe_row(row: dict[str, object]) -> dict[str, object]:
    keys = [
        "period",
        "run",
        "scenario",
        "trade_index",
        "open_time",
        "close_time",
        "symbol",
        "direction",
        "net_profit",
        "final_result_R",
        "max_favorable_r",
        "max_adverse_r",
        "reached_0_5R",
        "reached_1R",
        "reached_1_5R",
        "reached_2R",
        "reached_3R",
        "time_to_0_5R",
        "time_to_1R",
        "time_to_1_5R",
        "time_to_2R",
        "time_to_3R",
        "time_to_SL",
        "would_1R_take_profit_help",
        "would_1_5R_take_profit_help",
        "would_2R_take_profit_work",
        "did_price_reverse_after_1R",
        "did_price_reverse_after_1_5R",
        "mfe_bucket",
        "failure_type",
        "winning_type",
    ]
    result = {}
    for key in keys:
        value = row.get(key, "")
        if isinstance(value, datetime):
            value = value.strftime("%Y.%m.%d %H:%M:%S")
        result[key] = value
    return result


def q1_rows(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    return [row for row in rows if row["period"] == "2026-Q1"]


def scenario_rows(rows: list[dict[str, object]], scenario: str) -> list[dict[str, object]]:
    return [row for row in rows if row["scenario"] == scenario]


def find_aggregate(aggregates: list[dict[str, object]], **filters: str) -> dict[str, object]:
    for row in aggregates:
        if all(str(row.get(key)) == str(value) for key, value in filters.items()):
            return row
    return {}


def write_summary(rows: list[dict[str, object]]) -> None:
    comparison_path = BACKTEST / f"{SOURCE_PREFIX}_comparison.csv"
    existing_comparison = read_csv_rows(comparison_path)
    nested_comparison = [row for row in existing_comparison if "Nested_NWave" in row.get("scenario", "")]

    all_nested = aggregate(rows, ["period", "scenario"])
    q1 = q1_rows(rows)
    q1_agg = aggregate(q1, ["scenario"])
    q1_symbol = aggregate(q1, ["scenario", "symbol"])
    q1_direction = aggregate(q1, ["scenario", "direction"])
    q1_h4_zone = aggregate(q1, ["scenario", "h4_pullback_depth_bucket"])
    q1_failure = aggregate([row for row in q1 if float(row["net_profit"]) < 0], ["scenario", "failure_type"])
    q1_layer = aggregate([row for row in q1 if float(row["net_profit"]) < 0], ["scenario", "setup_failure_layer"])
    label_recheck = aggregate(rows, ["period", "scenario", "label"])
    true_clean = aggregate(rows, ["period", "scenario", "true_clean_candidate"])

    lines = [
        "# Nested N-Wave Neckline Break Failure Decomposition",
        "",
        "## Scope",
        "",
        "- Diagnostic-only pass for the existing `RESEARCH_STRATEGY_NESTED_NWAVE_NECKLINE_BREAK` short-period runs.",
        "- No EA entry logic, order bridge, SL/TP, RewardR, timeframe, spread guard, risk sizing, or parameters were changed.",
        "- No annual backtests were run.",
        "- MFE/MAE and R-reach diagnostics use MT5 M5 OHLC after the existing entries. Same-bar ambiguity is not promoted to a win.",
        "",
        "## Short-Period Context",
        "",
        "| period | scenario | trades | PF | expected | net | max DD % | FX net | XAU net |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in nested_comparison:
        lines.append(
            f"| {row['period']} | {row['scenario']} | {row['trades']} | {row['profit_factor']} | {row['expected_payoff']} | {row['net_profit']} | {row['max_balance_dd_pct']} | {row['fx_net']} | {row['xauusd_net']} |"
        )

    lines += [
        "",
        "## 2026-Q1 Failure Summary",
        "",
        "| scenario | trades | PF | expected | net | avg MFE R | avg MAE R | false break % | reached 1R % | reached 2R % |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in q1_agg:
        lines.append(
            f"| {row['scenario']} | {row['trades']} | {row['profit_factor']} | {row['expected_payoff']} | {row['net_profit']} | {row['avg_mfe_R']} | {row['avg_mae_R']} | {row['false_break_return_pct']} | {row['reached_1R_pct']} | {row['reached_2R_pct']} |"
        )

    lines += [
        "",
        "Key read:",
        "",
        "- 2026-Q1 did not fail because XAUUSD alone broke. FX was also materially negative, especially GBPUSD/USDJPY.",
        "- The main defect is not simply that 2R was too far. Many losers failed before reaching even 0.5R or returned inside the neckline soon after entry.",
        "- `clean_nested_nwave_entry` is not a true clean label yet. It means the coded stages passed, not that the breakout had enough follow-through quality.",
        "",
        "## 2026-Q1 Exposure Breakdown",
        "",
        "| scenario | group | trades | net | PF | avg MFE R | false break % |",
        "|---|---|---:|---:|---:|---:|---:|",
    ]
    for row in sorted(q1_symbol, key=lambda item: float(item["net_profit"]))[:12]:
        lines.append(
            f"| {row['scenario']} | symbol={row['symbol']} | {row['trades']} | {row['net_profit']} | {row['profit_factor']} | {row['avg_mfe_R']} | {row['false_break_return_pct']} |"
        )
    for row in q1_direction:
        lines.append(
            f"| {row['scenario']} | direction={row['direction']} | {row['trades']} | {row['net_profit']} | {row['profit_factor']} | {row['avg_mfe_R']} | {row['false_break_return_pct']} |"
        )
    for row in q1_h4_zone:
        lines.append(
            f"| {row['scenario']} | h4_pullback={row['h4_pullback_depth_bucket']} | {row['trades']} | {row['net_profit']} | {row['profit_factor']} | {row['avg_mfe_R']} | {row['false_break_return_pct']} |"
        )

    lines += [
        "",
        "## 2026-Q1 Failure Types",
        "",
        "| scenario | failure_type | trades | net | avg MFE R | reached 1R % | false break % |",
        "|---|---|---:|---:|---:|---:|---:|",
    ]
    for row in q1_failure:
        lines.append(
            f"| {row['scenario']} | {row['failure_type']} | {row['trades']} | {row['net_profit']} | {row['avg_mfe_R']} | {row['reached_1R_pct']} | {row['false_break_return_pct']} |"
        )

    lines += [
        "",
        "## Failure Layer",
        "",
        "| scenario | setup_failure_layer | trades | net | avg MFE R | false break % |",
        "|---|---|---:|---:|---:|---:|",
    ]
    for row in q1_layer:
        lines.append(
            f"| {row['scenario']} | {row['setup_failure_layer']} | {row['trades']} | {row['net_profit']} | {row['avg_mfe_R']} | {row['false_break_return_pct']} |"
        )

    lines += [
        "",
        "## Clean Label Recheck",
        "",
        "| period | scenario | label | trades | PF | net | avg MFE R | false break % |",
        "|---|---|---|---:|---:|---:|---:|---:|",
    ]
    for row in label_recheck:
        lines.append(
            f"| {row['period']} | {row['scenario']} | {row['label']} | {row['trades']} | {row['profit_factor']} | {row['net_profit']} | {row['avg_mfe_R']} | {row['false_break_return_pct']} |"
        )

    lines += [
        "",
        "## Diagnostic True-Clean Proxy",
        "",
        "A temporary `true_clean_candidate` proxy was added only in analysis, not in EA logic. It requires: original clean/initial label, entry close within 0.4 ATR of neckline, close strength >= 0.6, no immediate close back inside neckline, mid-zone H4 pullback, and SL ATR < 2.0.",
        "",
        "| period | scenario | true_clean_candidate | trades | PF | net | avg MFE R | false break % |",
        "|---|---|---:|---:|---:|---:|---:|---:|",
    ]
    for row in true_clean:
        lines.append(
            f"| {row['period']} | {row['scenario']} | {row['true_clean_candidate']} | {row['trades']} | {row['profit_factor']} | {row['net_profit']} | {row['avg_mfe_R']} | {row['false_break_return_pct']} |"
        )

    lines += [
        "",
        "## Judgement",
        "",
        "1. 2026-Q1 collapse is primarily a neckline-quality and follow-through problem, with secondary H1/H4 context weakness. It is not solved by symbol or direction narrowing.",
        "2. The current neckline break check confirms a close beyond a level, but does not sufficiently grade breakout body strength, close location, retest behavior, or room to follow through.",
        "3. 2R is sometimes too far, but the more important issue is that a large portion of losers do not develop enough MFE to justify any simple RewardR retune.",
        "4. `clean_nested_nwave_entry` is currently a structural pass label, not a human-grade clean breakout label.",
        "5. The next v2, if attempted, should add fixed quality gates around breakout strength and false-break behavior before touching RewardR or SL.",
        "",
        "## Outputs",
        "",
        f"- Failure decomposition: `reports/backtest/{REQUIRED_OUTPUTS['decomposition'].name}`",
        f"- Neckline quality: `reports/backtest/{REQUIRED_OUTPUTS['neckline_quality'].name}`",
        f"- MFE/MAE/R reach: `reports/backtest/{REQUIRED_OUTPUTS['mfe_mae'].name}`",
        f"- v2 gate candidates: `reports/backtest/{REQUIRED_OUTPUTS['gate_candidates'].name}`",
    ]
    REQUIRED_OUTPUTS["summary"].write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_gate_candidates(rows: list[dict[str, object]]) -> None:
    q1 = q1_rows(rows)
    failure_counts = Counter(str(row.get("failure_type")) for row in q1 if float(row["net_profit"]) < 0)
    layer_counts = Counter(str(row.get("setup_failure_layer")) for row in q1 if float(row["net_profit"]) < 0)
    lines = [
        "# Nested N-Wave v2 Gate Candidates",
        "",
        "These are fixed diagnostic candidates, not optimized parameters. They are derived from the four short-period Nested runs and especially the 2026-Q1 failure sample.",
        "",
        "## 2026-Q1 Failure Evidence",
        "",
        "Failure types:",
    ]
    for key, count in failure_counts.most_common():
        lines.append(f"- `{key}`: {count}")
    lines += ["", "Failure layers:"]
    for key, count in layer_counts.most_common():
        lines.append(f"- `{key}`: {count}")

    lines += [
        "",
        "## Candidate Gates",
        "",
        "1. **Breakout Close Strength Gate**",
        "   - Minimum close-position strength on the breakout proxy bar.",
        "   - Rationale: the current neckline check accepts weak closes that often return inside the neckline.",
        "   - Minimal test: require `breakout_close_strength >= 0.60` as a single fixed rule.",
        "",
        "2. **False-Break Guard**",
        "   - Reject candidates where the next few M5 bars close back inside the neckline in diagnostic replay.",
        "   - This cannot be known at entry without waiting, so the live version would need a retest-confirmation variant rather than a hindsight filter.",
        "   - Minimal test: build a delayed-entry retest-confirmation branch, not a direct hindsight gate.",
        "",
        "3. **Entry Distance From Neckline Cap**",
        "   - Avoid entries already too far from the neckline.",
        "   - Rationale: late breakouts have poor reward path and often fail before meaningful MFE.",
        "   - Minimal test: fixed cap around `entry_close_distance_from_neckline_atr <= 0.40`.",
        "",
        "4. **H4 Pullback Mid-Zone Preference**",
        "   - Prefer mid-zone H4 pullbacks over edge-of-zone 38-42 or 58-62 cases.",
        "   - Rationale: edge-zone samples were more often context-problem or poor follow-through candidates.",
        "   - Minimal test: compare `42-58` zone against the full `38.2-61.8` zone without changing other logic.",
        "",
        "5. **Max SL ATR Gate**",
        "   - Block candidates with wide structure risk.",
        "   - Rationale: wide SL cases require too much follow-through for the fixed 2R target.",
        "   - Minimal test: fixed `sl_atr < 2.0` diagnostic branch.",
        "",
        "## Recommendation",
        "",
        "A v2 is worth a small diagnostic branch only if it starts with breakout-quality gates, not RewardR/SL tuning. The first implementation should combine no more than two rules: close strength and entry distance from neckline. If that only reduces trades without improving 2025-02 and 2026-Q1, park Nested and move to another pattern definition.",
    ]
    REQUIRED_OUTPUTS["gate_candidates"].write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    rows = build_analysis_rows()
    write_union_rows(REQUIRED_OUTPUTS["decomposition"], [compact_trade_row(row) for row in rows])
    write_union_rows(REQUIRED_OUTPUTS["neckline_quality"], [neckline_quality_row(row) for row in rows])
    write_union_rows(REQUIRED_OUTPUTS["mfe_mae"], [mfe_row(row) for row in rows])
    write_rows(REQUIRED_OUTPUTS["by_failure_type"], aggregate([row for row in rows if row.get("failure_type")], ["period", "scenario", "failure_type"]))
    write_rows(REQUIRED_OUTPUTS["by_winning_type"], aggregate([row for row in rows if row.get("winning_type")], ["period", "scenario", "winning_type"]))
    write_rows(REQUIRED_OUTPUTS["by_label_recheck"], aggregate(rows, ["period", "scenario", "label", "true_clean_candidate"]))
    write_rows(REQUIRED_OUTPUTS["by_setup_layer"], aggregate(rows, ["period", "scenario", "setup_failure_layer"]))
    write_summary(rows)
    write_gate_candidates(rows)

    metrics = {
        "rows": len(rows),
        "outputs": {key: str(path) for key, path in REQUIRED_OUTPUTS.items()},
        "q1_failure_types": Counter(str(row.get("failure_type")) for row in q1_rows(rows) if row.get("failure_type")),
    }
    (BACKTEST / f"{OUT_PREFIX}_failure_decomposition_metrics.json").write_text(
        json.dumps(metrics, ensure_ascii=False, indent=2, default=str) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"rows": len(rows), "summary": str(REQUIRED_OUTPUTS["summary"])}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
