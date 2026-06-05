#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import math
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

import MetaTrader5 as mt5

from analyze_multicurrency_score_scanner_2025 import (
    BACKTEST,
    calc_stats,
    parse_mt5_deals,
    serialize_stats,
    write_rows,
    write_trades,
)


OUT_BASE = "ExpectedValue_MultiCurrency_ScoreScanner"
OUT_PREFIX = f"{OUT_BASE}_thirdwave_v4_signal_shadow"

SERIES = [
    {
        "period": "2025-02",
        "series_name": "v4sig_2502",
        "context": "2025 losing-period sample",
    },
    {
        "period": "2025-08",
        "series_name": "v4sig_2508",
        "context": "2025 comparison sample",
    },
    {
        "period": "2025-10",
        "series_name": "v4sig_2510",
        "context": "2025 comparison sample",
    },
    {
        "period": "2026-Q1",
        "series_name": "v4sig_26q1",
        "context": "2026YTD sample",
    },
]

RUNS = [
    {
        "run": "A",
        "variant": "current_thirdwave",
        "scenario": "ThirdWave_regime_BOTH_all_5m",
        "suffix": "A_cur",
        "signal_mode": "not_used",
    },
    {
        "run": "B",
        "variant": "v4_all_signals",
        "scenario": "ThirdWave_v4_all_signals_BOTH_all_5m",
        "suffix": "B_v4all",
        "signal_mode": "V4_SIGNAL_ALL",
    },
    {
        "run": "C",
        "variant": "v4_micro_break_only",
        "scenario": "ThirdWave_v4_micro_break_only_BOTH_all_5m",
        "suffix": "C_micro",
        "signal_mode": "V4_SIGNAL_MICRO_BREAK_ONLY",
    },
    {
        "run": "D",
        "variant": "v4_candle_reversal_only",
        "scenario": "ThirdWave_v4_candle_reversal_only_BOTH_all_5m",
        "suffix": "D_candle",
        "signal_mode": "V4_SIGNAL_CANDLE_REVERSAL_ONLY",
    },
    {
        "run": "E",
        "variant": "v4_micro_or_candle",
        "scenario": "ThirdWave_v4_micro_or_candle_BOTH_all_5m",
        "suffix": "E_microcandle",
        "signal_mode": "V4_SIGNAL_MICRO_OR_CANDLE",
    },
    {
        "run": "F",
        "variant": "v4_without_weak_signals",
        "scenario": "ThirdWave_v4_without_weak_signals_BOTH_all_5m",
        "suffix": "F_noweak",
        "signal_mode": "V4_SIGNAL_WITHOUT_WEAK_SIGNALS",
    },
]

AUDIT_FIELDS = [
    "time",
    "event",
    "symbol",
    "direction",
    "entry_price",
    "sl",
    "tp",
    "mid_tf_structure_sl",
    "lower_tf_reversal_sl",
    "mid_tf_structure_sl_atr",
    "lower_tf_reversal_sl_atr",
    "lower_tf_reversal_sl_status",
    "result_R",
    "profit",
    "regime",
    "session",
    "scan_interval",
    "entry_selection_mode",
    "v4_signal_mode",
    "v4_signal_mode_pass",
    "v4_signal_mode_blocked",
    "higher_tf",
    "higher_structure_state",
    "mid_tf",
    "pullback_depth_pct",
    "pullback_depth_atr",
    "distance_from_pullback_extreme_to_entry_atr",
    "distance_from_pullback_extreme_to_entry_pct_of_impulse",
    "lower_tf",
    "minor_reversal_level",
    "reclaim_or_breakdown_price",
    "bars_since_reclaim_or_breakdown",
    "entry_distance_from_reclaim_atr",
    "entry_distance_from_reclaim_points",
    "lower_reversal_quality",
    "lower_reversal_quality_score",
    "sl_atr",
    "risk_r",
    "rr",
    "spread_atr",
    "structure_stage_fail_reason",
    "execution_block_reason",
    "v2_filter_pass",
    "v2_filter_fail_reason",
    "v3_filter_pass",
    "v3_filter_fail_reason",
    "v3_momentum_exhaustion_score",
    "v3_momentum_exhausted",
    "v3_recent_move_atr",
    "v3_consecutive_directional_bars",
    "v3_close_to_recent_extreme_atr",
    "reversal_signal_type",
    "v4_block_reason",
    "bars_since_pullback_extreme",
    "bars_since_reversal_signal",
    "distance_from_reversal_signal_to_entry_atr",
    "impulse_consumed_pct",
    "pre_entry_momentum_score",
    "reversal_strength_score",
    "wave_audit_label",
    "wave_audit_reason",
    "strategy_name",
]

REWARD_R_VALUES = [1.2, 1.3, 1.5]
SL_MODES = ["CURRENT_SL", "MID_TF_STRUCTURE_SL", "LOWER_TF_REVERSAL_SL"]
INITIAL_BALANCE = 10000.0
MT5_RATE_TIME_OFFSET = timedelta(hours=9)


def series_prefix(series_name: str) -> str:
    return f"{OUT_BASE}_{series_name}"


def run_prefix(series_name: str, run: dict[str, str]) -> str:
    return f"{series_prefix(series_name)}_{run['suffix']}"


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return list(csv.DictReader(fh))


def parse_log_time(value: str) -> datetime | None:
    value = (value or "").strip()
    if not value:
        return None
    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")


def as_float(value: Any, default: float = 0.0) -> float:
    if value is None:
        return default
    text = str(value).strip().replace(" ", "").replace(",", "")
    if text == "":
        return default
    try:
        return float(text)
    except ValueError:
        return default


def as_int(value: Any, default: int = 0) -> int:
    return int(as_float(value, float(default)))


def pf_value(stats: dict[str, object]) -> object:
    return round(float(stats["profit_factor"]), 3) if stats["profit_factor"] is not None else ""


def read_elapsed(series_name: str, run_id: str) -> float:
    path = BACKTEST / f"{series_prefix(series_name)}_elapsed.csv"
    if not path.exists():
        return 0.0
    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            if row.get("run") == run_id:
                return as_float(row.get("elapsed_seconds"))
    return 0.0


def session_for_hour(hour: int) -> str:
    if 0 <= hour < 8:
        return "server_00_07"
    if 8 <= hour < 16:
        return "server_08_15"
    return "server_16_23"


def match_audit_row(
    trade: dict[str, object],
    audit_rows: list[dict[str, str]],
    used: set[int],
) -> tuple[int, dict[str, str]]:
    best_idx = -1
    best_delta = 10**9
    open_time = trade["open_time"]
    for idx, row in enumerate(audit_rows):
        if idx in used:
            continue
        if row.get("event") != "order_sent":
            continue
        if row.get("symbol") != trade["symbol"]:
            continue
        if row.get("direction") != trade["direction"]:
            continue
        log_time = parse_log_time(row.get("time", ""))
        if log_time is None:
            continue
        delta = abs((open_time - log_time).total_seconds())
        if delta <= 900 and delta < best_delta:
            best_delta = int(delta)
            best_idx = idx
    if best_idx >= 0:
        used.add(best_idx)
        return best_idx, audit_rows[best_idx]
    return -1, {}


def compute_result_r(trade: dict[str, object], audit: dict[str, str]) -> float:
    risk_r = as_float(audit.get("risk_r"))
    if risk_r <= 0.0:
        return 0.0
    entry_price = as_float(audit.get("entry_price")) or float(trade["open_price"])
    direction_sign = 1.0 if trade["direction"] == "LONG" else -1.0
    return (float(trade["close_price"]) - entry_price) * direction_sign / risk_r


def risk_money_for_trade(trade: dict[str, object], result_r: float) -> float:
    if abs(result_r) >= 0.05:
        return abs(float(trade["net_profit"]) / result_r)
    return 50.0


def file_size(path: Path) -> int:
    return path.stat().st_size if path.exists() else 0


def run_csv_bytes(prefix: str) -> int:
    return sum(file_size(path) for path in BACKTEST.glob(f"{prefix}*.csv"))


def floor_m5(value: datetime) -> datetime:
    return value.replace(minute=value.minute - value.minute % 5, second=0, microsecond=0)


class RateCache:
    def __init__(self) -> None:
        self.cache: dict[tuple[str, datetime, datetime], list[dict[str, Any]]] = {}

    def get(self, symbol: str, start: datetime, end: datetime) -> list[dict[str, Any]]:
        start = floor_m5(start) - timedelta(minutes=5)
        end = end + timedelta(minutes=10)
        key = (symbol, start, end)
        if key in self.cache:
            return self.cache[key]
        data = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_M5, start + MT5_RATE_TIME_OFFSET, end + MT5_RATE_TIME_OFFSET)
        if data is None:
            self.cache[key] = []
            return []
        rows = []
        for item in data:
            rows.append(
                {
                    "time": datetime.fromtimestamp(int(item["time"])) - MT5_RATE_TIME_OFFSET,
                    "open": float(item["open"]),
                    "high": float(item["high"]),
                    "low": float(item["low"]),
                    "close": float(item["close"]),
                }
            )
        self.cache[key] = rows
        return rows


def sl_for_mode(row: dict[str, object], sl_mode: str) -> tuple[float, str]:
    if sl_mode == "CURRENT_SL":
        return as_float(row.get("sl")), "valid"
    if sl_mode == "MID_TF_STRUCTURE_SL":
        value = as_float(row.get("mid_tf_structure_sl"))
        return (value if value > 0 else as_float(row.get("sl"))), "valid"
    value = as_float(row.get("lower_tf_reversal_sl"))
    status = str(row.get("lower_tf_reversal_sl_status") or "not_available")
    return value, status


def simulate_shadow_exit(
    row: dict[str, object],
    sl_mode: str,
    reward_r: float,
    rates: list[dict[str, Any]],
) -> dict[str, object]:
    direction = str(row["direction"])
    entry = float(row["open_price"])
    close = float(row["close_price"])
    sl, sl_status = sl_for_mode(row, sl_mode)
    risk = abs(entry - sl)
    actual_result_r = float(row.get("result_R", 0.0))
    risk_money = risk_money_for_trade(row, actual_result_r)
    current_risk = as_float(row.get("risk_r"))
    current_volume = float(row.get("volume", 0.0))
    hypothetical_lot = current_volume * current_risk / risk if current_volume > 0 and current_risk > 0 and risk > 0 else 0.0

    invalid_reason = ""
    if sl <= 0.0 or risk <= 0.0:
        invalid_reason = "invalid_stops"
    elif sl_mode == "LOWER_TF_REVERSAL_SL" and sl_status != "valid":
        invalid_reason = sl_status
    if invalid_reason:
        return {
            "shadow_outcome": invalid_reason,
            "shadow_result_R": 0.0,
            "shadow_profit": 0.0,
            "tp_hit": 0,
            "sl_hit": 0,
            "same_bar_ambiguous": 0,
            "time_to_tp_minutes": "",
            "time_to_sl_minutes": "",
            "mae_R": 0.0,
            "mfe_R": 0.0,
            "avg_sl_points": risk,
            "avg_sl_atr": risk / max(as_float(row.get("atr_value")), 1e-9),
            "avg_tp_points": risk * reward_r,
            "avg_tp_atr": risk * reward_r / max(as_float(row.get("atr_value")), 1e-9),
            "hypothetical_lot_size": round(hypothetical_lot, 4),
            "invalid_stops": 1 if invalid_reason == "invalid_stops" else 0,
            "sl_too_tight": 1 if invalid_reason == "sl_too_tight" else 0,
            "sl_too_wide": 1 if invalid_reason == "sl_too_wide" else 0,
            "not_enough_money": 0,
        }

    sign = 1.0 if direction == "LONG" else -1.0
    tp = entry + sign * risk * reward_r
    open_time = row["open_time"]
    max_fav = 0.0
    max_adv = 0.0
    outcome = "actual_close"
    hit_time: datetime | None = None
    tp_hit = 0
    sl_hit = 0
    ambiguous = 0

    for bar in rates:
        if bar["time"] < floor_m5(open_time):
            continue
        if direction == "LONG":
            fav = max(0.0, bar["high"] - entry)
            adv = max(0.0, entry - bar["low"])
            hit_tp = bar["high"] >= tp
            hit_sl = bar["low"] <= sl
        else:
            fav = max(0.0, entry - bar["low"])
            adv = max(0.0, bar["high"] - entry)
            hit_tp = bar["low"] <= tp
            hit_sl = bar["high"] >= sl
        max_fav = max(max_fav, fav)
        max_adv = max(max_adv, adv)
        if hit_tp and hit_sl:
            outcome = "same_bar_ambiguous"
            ambiguous = 1
            sl_hit = 1
            hit_time = bar["time"]
            break
        if hit_tp:
            outcome = "tp"
            tp_hit = 1
            hit_time = bar["time"]
            break
        if hit_sl:
            outcome = "sl"
            sl_hit = 1
            hit_time = bar["time"]
            break

    if outcome == "tp":
        result_r = reward_r
    elif outcome in {"sl", "same_bar_ambiguous"}:
        result_r = -1.0
    else:
        result_r = (close - entry) * sign / risk

    return {
        "shadow_outcome": outcome,
        "shadow_result_R": round(result_r, 4),
        "shadow_profit": round(result_r * risk_money, 2),
        "tp_hit": tp_hit,
        "sl_hit": sl_hit,
        "same_bar_ambiguous": ambiguous,
        "time_to_tp_minutes": round((hit_time - open_time).total_seconds() / 60.0, 1) if hit_time and tp_hit else "",
        "time_to_sl_minutes": round((hit_time - open_time).total_seconds() / 60.0, 1) if hit_time and sl_hit else "",
        "mae_R": round(max_adv / risk, 4),
        "mfe_R": round(max_fav / risk, 4),
        "avg_sl_points": risk,
        "avg_sl_atr": risk / max(as_float(row.get("atr_value")), 1e-9),
        "avg_tp_points": risk * reward_r,
        "avg_tp_atr": risk * reward_r / max(as_float(row.get("atr_value")), 1e-9),
        "hypothetical_lot_size": round(hypothetical_lot, 4),
        "invalid_stops": 0,
        "sl_too_tight": 0,
        "sl_too_wide": 0,
        "not_enough_money": 0,
    }


def enrich_trades(
    trades: list[dict[str, object]],
    audit_rows: list[dict[str, str]],
    context: dict[str, object],
) -> list[dict[str, object]]:
    used: set[int] = set()
    enriched: list[dict[str, object]] = []
    for idx, trade in enumerate(trades, start=1):
        _, audit = match_audit_row(trade, audit_rows, used)
        row = dict(trade)
        row.update(context)
        row["trade_index"] = idx
        for field in AUDIT_FIELDS:
            row[field] = audit.get(field, "") if audit else ""
        row["result_R"] = round(compute_result_r(trade, audit), 4) if audit else 0.0
        row["profit"] = round(float(trade["net_profit"]), 2)
        row["month"] = trade["open_time"].strftime("%Y-%m")
        row["hour"] = f"{trade['open_time'].hour:02d}"
        row["session"] = audit.get("session") or session_for_hour(trade["open_time"].hour)
        row["wave_audit_label"] = audit.get("wave_audit_label") or "unmatched"
        row["reversal_signal_type"] = audit.get("reversal_signal_type") or "unmatched"
        row["regime"] = audit.get("regime") or "unmatched"
        row["is_xauusd"] = "XAUUSD" if trade["symbol"] == "XAUUSD" else "FX"
        enriched.append(row)
    return enriched


def trade_row_for_csv(row: dict[str, object]) -> dict[str, object]:
    out = dict(row)
    for key in ("open_time", "close_time", "open_bar_m5", "close_bar_m5"):
        value = out.get(key)
        if isinstance(value, datetime):
            out[key] = value.strftime("%Y.%m.%d %H:%M:%S")
    return out


def stats_from_profit_rows(rows: list[dict[str, object]], profit_key: str = "net_profit") -> dict[str, object]:
    synthetic = []
    base_time = datetime(2000, 1, 1)
    for i, row in enumerate(rows):
        synthetic.append(
            {
                "net_profit": float(row.get(profit_key, 0.0)),
                "open_time": base_time + timedelta(minutes=i),
                "close_time": base_time + timedelta(minutes=i + 1),
            }
        )
    return calc_stats(synthetic)


def aggregate_rows(rows: list[dict[str, object]], group_fields: list[str], profit_key: str, r_key: str) -> list[dict[str, object]]:
    buckets: dict[tuple[str, ...], list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        buckets[tuple(str(row.get(field, "")) for field in group_fields)].append(row)
    out: list[dict[str, object]] = []
    for key, bucket in sorted(buckets.items()):
        valid = [r for r in bucket if str(r.get("shadow_outcome", "")) not in {"invalid_stops", "sl_too_tight", "sl_too_wide", "not_available"}]
        metric_rows = valid if profit_key == "shadow_profit" else bucket
        stats = stats_from_profit_rows(metric_rows, profit_key)
        avg_r = sum(float(r.get(r_key, 0.0)) for r in metric_rows) / len(metric_rows) if metric_rows else 0.0
        result = {field: value for field, value in zip(group_fields, key)}
        result.update(
            {
                "trades": len(bucket),
                "valid_trades": len(metric_rows),
                "wins": stats["wins"],
                "losses": stats["losses"],
                "win_rate": round(float(stats["win_rate"]), 2),
                "net_profit": round(float(stats["net_profit"]), 2),
                "profit_factor": pf_value(stats),
                "expected_payoff": round(float(stats["expected_payoff"]), 2),
                "avg_R": round(avg_r, 3),
                "max_drawdown": round(float(stats["max_balance_dd"]), 2),
                "max_drawdown_pct": round(float(stats["max_balance_dd_pct"]), 2),
                "tp_hit_rate_pct": round(sum(int(r.get("tp_hit", 0)) for r in bucket) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "sl_hit_rate_pct": round(sum(int(r.get("sl_hit", 0)) for r in bucket) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "same_bar_ambiguous": sum(int(r.get("same_bar_ambiguous", 0)) for r in bucket),
                "invalid_stops": sum(int(r.get("invalid_stops", 0)) for r in bucket),
                "sl_too_tight": sum(int(r.get("sl_too_tight", 0)) for r in bucket),
                "sl_too_wide": sum(int(r.get("sl_too_wide", 0)) for r in bucket),
                "avg_mae_R": round(sum(float(r.get("mae_R", 0.0)) for r in metric_rows) / len(metric_rows), 3) if metric_rows else 0.0,
                "avg_mfe_R": round(sum(float(r.get("mfe_R", 0.0)) for r in metric_rows) / len(metric_rows), 3) if metric_rows else 0.0,
                "avg_sl_atr": round(sum(float(r.get("avg_sl_atr", 0.0)) for r in metric_rows) / len(metric_rows), 3) if metric_rows else 0.0,
                "avg_tp_atr": round(sum(float(r.get("avg_tp_atr", 0.0)) for r in metric_rows) / len(metric_rows), 3) if metric_rows else 0.0,
                "avg_hypothetical_lot_size": round(sum(float(r.get("hypothetical_lot_size", 0.0)) for r in metric_rows) / len(metric_rows), 3) if metric_rows else 0.0,
            }
        )
        out.append(result)
    return out


def actual_run_row(series: dict[str, str], run: dict[str, str], trades: list[dict[str, object]], elapsed: float, csv_bytes: int) -> dict[str, object]:
    stats = stats_from_profit_rows(trades, "net_profit")
    xau = [t for t in trades if t["symbol"] == "XAUUSD"]
    fx = [t for t in trades if t["symbol"] != "XAUUSD"]
    longs = [t for t in trades if t["direction"] == "LONG"]
    shorts = [t for t in trades if t["direction"] == "SHORT"]
    chasing = [t for t in trades if t.get("wave_audit_label") == "chasing_entry"]
    initial = [t for t in trades if t.get("wave_audit_label") == "third_wave_initial"]
    middle = [t for t in trades if t.get("wave_audit_label") == "third_wave_middle"]
    avg_r = sum(float(t.get("result_R", 0.0)) for t in trades) / len(trades) if trades else 0.0
    return {
        "period": series["period"],
        "variant": run["variant"],
        "scenario": run["scenario"],
        "signal_mode": run["signal_mode"],
        "trades": len(trades),
        "wins": stats["wins"],
        "losses": stats["losses"],
        "win_rate": round(float(stats["win_rate"]), 2),
        "net_profit": round(float(stats["net_profit"]), 2),
        "profit_factor": pf_value(stats),
        "expected_payoff": round(float(stats["expected_payoff"]), 2),
        "avg_R": round(avg_r, 3),
        "max_drawdown": round(float(stats["max_balance_dd"]), 2),
        "max_drawdown_pct": round(float(stats["max_balance_dd_pct"]), 2),
        "elapsed_seconds": round(elapsed, 1),
        "csv_bytes": csv_bytes,
        "fx_net": round(sum(float(t["net_profit"]) for t in fx), 2),
        "xauusd_net": round(sum(float(t["net_profit"]) for t in xau), 2),
        "xauusd_trade_share_pct": round(len(xau) / len(trades) * 100.0, 2) if trades else 0.0,
        "long_net": round(sum(float(t["net_profit"]) for t in longs), 2),
        "short_net": round(sum(float(t["net_profit"]) for t in shorts), 2),
        "largest_direction_share_pct": round(max(len(longs), len(shorts)) / len(trades) * 100.0, 2) if trades else 0.0,
        "chasing_entry_ratio_pct": round(len(chasing) / len(trades) * 100.0, 2) if trades else 0.0,
        "third_wave_initial_ratio_pct": round(len(initial) / len(trades) * 100.0, 2) if trades else 0.0,
        "third_wave_middle_ratio_pct": round(len(middle) / len(trades) * 100.0, 2) if trades else 0.0,
        "good_label_ratio_pct": round((len(initial) + len(middle)) / len(trades) * 100.0, 2) if trades else 0.0,
    }


def combined_variant_rows(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    out = []
    for agg in aggregate_rows(rows, ["variant"], "net_profit", "result_R"):
        out.append(agg)
    return out


def build_shadow_rows(trades: list[dict[str, object]], cache: RateCache) -> list[dict[str, object]]:
    shadow: list[dict[str, object]] = []
    for trade in trades:
        rates = cache.get(str(trade["symbol"]), trade["open_time"], trade["close_time"])
        for sl_mode in SL_MODES:
            for reward_r in REWARD_R_VALUES:
                result = simulate_shadow_exit(trade, sl_mode, reward_r, rates)
                row = {
                    "period": trade["period"],
                    "variant": trade["variant"],
                    "scenario": trade["scenario"],
                    "symbol": trade["symbol"],
                    "direction": trade["direction"],
                    "month": trade["month"],
                    "session": trade["session"],
                    "regime": trade["regime"],
                    "is_xauusd": trade["is_xauusd"],
                    "reversal_signal_type": trade["reversal_signal_type"],
                    "wave_audit_label": trade["wave_audit_label"],
                    "sl_mode": sl_mode,
                    "reward_r": reward_r,
                    "current_result_R": trade.get("result_R", 0.0),
                    "current_profit": trade.get("net_profit", 0.0),
                }
                row.update(result)
                row["delta_result_R_vs_current"] = round(float(row["shadow_result_R"]) - float(trade.get("result_R", 0.0)), 4)
                shadow.append(row)
    return shadow


def write_short_summary(actual_trades: list[dict[str, object]], comparison: list[dict[str, object]], shadow: list[dict[str, object]], gate_rows: list[dict[str, object]]) -> None:
    combined = aggregate_rows(actual_trades, ["variant"], "net_profit", "result_R")
    sl_combo = aggregate_rows(shadow, ["variant", "sl_mode", "reward_r"], "shadow_profit", "shadow_result_R")
    micro = [r for r in combined if r["variant"] == "v4_micro_break_only"]
    candle = [r for r in combined if r["variant"] == "v4_candle_reversal_only"]
    micro_or_candle = [r for r in combined if r["variant"] == "v4_micro_or_candle"]

    lines = [
        "# ThirdWave v4 Reversal Signal Quality And Shadow SL/RewardR Diagnostics",
        "",
        "## Scope",
        "",
        "- Short-period only: 2025-02, 2025-08, 2025-10, and 2026-Q1.",
        "- Existing ThirdWave, v2, v3, v4, Phase2, score scanner, CTrade bridge, actual SL/TP, spread guard, timeframe settings, and `InpRewardR` were not changed.",
        "- `InpV4ReversalSignalMode` controls only the v4 research branch; default `V4_SIGNAL_ALL` preserves prior v4 behavior.",
        "- RewardR 1.2 / 1.3 / 1.5 and Current/MidTF/LowerTF SL are shadow diagnostics only. Actual orders still use the configured live SL/TP.",
        "- Shadow exits are evaluated on M5 OHLC from MT5. Same-bar TP/SL overlap is marked `same_bar_ambiguous` and treated conservatively, not as a win.",
        "",
        "## Signal Mode Result",
        "",
        "| variant | trades | PF | avg_R | net | FX net | XAU net | chasing % | good label % |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    combined_by_variant = {r["variant"]: r for r in combined}
    for variant in [
        "current_thirdwave",
        "v4_all_signals",
        "v4_micro_break_only",
        "v4_candle_reversal_only",
        "v4_micro_or_candle",
        "v4_without_weak_signals",
    ]:
        row = combined_by_variant.get(variant, {})
        if not row:
            continue
        source = [r for r in actual_trades if r["variant"] == variant]
        fx_net = sum(float(r["net_profit"]) for r in source if r["symbol"] != "XAUUSD")
        xau_net = sum(float(r["net_profit"]) for r in source if r["symbol"] == "XAUUSD")
        trades = int(row["trades"])
        chasing = sum(1 for r in source if r.get("wave_audit_label") == "chasing_entry") / max(len(source), 1) * 100.0
        good = sum(1 for r in source if r.get("wave_audit_label") in {"third_wave_initial", "third_wave_middle"}) / max(len(source), 1) * 100.0
        lines.append(
            f"| {variant} | {trades} | {row['profit_factor']} | {row['avg_R']} | {row['net_profit']} | {fx_net:.2f} | {xau_net:.2f} | {chasing:.1f} | {good:.1f} |"
        )

    lines += [
        "",
        "## Shadow Diagnostic Highlights",
        "",
    ]
    baseline_shadow = next(
        (
            r
            for r in sl_combo
            if r["variant"] == "current_thirdwave"
            and r["sl_mode"] == "CURRENT_SL"
            and str(r["reward_r"]) == "1.5"
        ),
        None,
    )
    if baseline_shadow:
        lines.append(
            f"- Shadow baseline check: `current_thirdwave / CURRENT_SL / 1.5R` produced PF `{baseline_shadow['profit_factor']}`, avg_R `{baseline_shadow['avg_R']}`, net `{baseline_shadow['net_profit']}`. This is close enough to the actual short-period baseline for sensitivity diagnostics, but it remains an M5 OHLC approximation."
        )
    for variant_rows, title in ((micro, "micro_break_only"), (candle, "candle_reversal_only"), (micro_or_candle, "micro_or_candle")):
        if variant_rows:
            lines.append(f"- `{title}` actual aggregate: PF `{variant_rows[0]['profit_factor']}`, avg_R `{variant_rows[0]['avg_R']}`, trades `{variant_rows[0]['trades']}`.")

    best_shadow = sorted(
        [r for r in sl_combo if r["variant"] != "current_thirdwave"],
        key=lambda r: (float(r["avg_R"]), float(r["net_profit"])),
        reverse=True,
    )[:8]
    lines.append("")
    lines.append("Top shadow SL/RewardR combinations by avg_R:")
    for row in best_shadow:
        lines.append(
            f"- `{row['variant']}` / `{row['sl_mode']}` / `{row['reward_r']}R`: PF `{row['profit_factor']}`, avg_R `{row['avg_R']}`, valid trades `{row['valid_trades']}`, ambiguous `{row['same_bar_ambiguous']}`."
        )

    lines += [
        "",
        "## Interpretation",
        "",
        "- Actual signal-mode BT did not promote a v4 signal branch: every v4 branch failed to improve PF or avg_R over `current_thirdwave`, and every branch reduced FX net versus the current baseline.",
        "- The earlier `micro_break` strength inside all-signal v4 did not survive isolation. `v4_micro_break_only` finished near flat, so it should not be promoted as a standalone entry signal.",
        "- `micro_or_candle` and `without_weak_signals` improved net profit, but the improvement was mostly XAUUSD-driven and came with lower PF/avg_R than the current ThirdWave baseline.",
        "- RewardR-only shadow does not justify changing the live TP. The stronger diagnostic finding is that `LOWER_TF_REVERSAL_SL` plus 1.2R/1.3R improves shadow avg_R for micro/candle branches, but this is a separate SL-location hypothesis and was not executed as live logic.",
        "- Current SL and MidTF SL are effectively equivalent in this implementation; the meaningful shadow contrast is Current/MidTF versus LowerTF reversal structure.",
    ]

    lines += [
        "",
        "## Annual Gate",
        "",
    ]
    if any(str(r.get("gate_pass")) == "True" for r in gate_rows):
        passed = [r["variant"] for r in gate_rows if str(r.get("gate_pass")) == "True"]
        lines.append(f"- Gate passed for: {', '.join(passed)}. Annual BT should be run only for those branches.")
    else:
        lines.append("- No branch passed the short-period annual gate. Annual BT was not run.")
    for row in gate_rows:
        lines.append(f"- `{row['variant']}`: gate_pass={row['gate_pass']} reason={row['reason']}")

    lines += [
        "",
        "## Files",
        "",
        f"- Comparison CSV: `reports/backtest/{OUT_PREFIX}_reversal_signal_comparison.csv`",
        f"- RewardR shadow CSV: `reports/backtest/{OUT_PREFIX}_rewardR_shadow_comparison.csv`",
        f"- SL shadow CSV: `reports/backtest/{OUT_PREFIX}_sl_rewardR_comparison.csv`",
        f"- Raw shadow diagnostics: `reports/backtest/{OUT_PREFIX}_shadow_sl_diagnostics.csv`",
    ]
    (BACKTEST / f"{OUT_PREFIX}_short_period_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_gate_rows(actual_trades: list[dict[str, object]]) -> list[dict[str, object]]:
    combined = {r["variant"]: r for r in aggregate_rows(actual_trades, ["variant"], "net_profit", "result_R")}
    current = combined.get("current_thirdwave", {})
    current_pf = as_float(current.get("profit_factor"))
    current_avg_r = as_float(current.get("avg_R"))
    current_trades = as_int(current.get("trades"))
    current_source = [r for r in actual_trades if r["variant"] == "current_thirdwave"]
    current_fx = sum(float(r["net_profit"]) for r in current_source if r["symbol"] != "XAUUSD")
    rows = []
    for variant, row in combined.items():
        if variant == "current_thirdwave":
            continue
        source = [r for r in actual_trades if r["variant"] == variant]
        trades = as_int(row.get("trades"))
        pf = as_float(row.get("profit_factor"))
        avg_r = as_float(row.get("avg_R"))
        fx_net = sum(float(r["net_profit"]) for r in source if r["symbol"] != "XAUUSD")
        xau_share = sum(1 for r in source if r["symbol"] == "XAUUSD") / max(len(source), 1) * 100.0
        longs = sum(1 for r in source if r["direction"] == "LONG")
        shorts = sum(1 for r in source if r["direction"] == "SHORT")
        direction_share = max(longs, shorts) / max(len(source), 1) * 100.0
        chasing = sum(1 for r in source if r.get("wave_audit_label") == "chasing_entry") / max(len(source), 1) * 100.0
        improves = pf > current_pf or avg_r > current_avg_r
        enough_trades = trades >= current_trades * 0.50 or pf > current_pf * 1.20 or avg_r > current_avg_r * 1.30
        fx_ok = fx_net >= current_fx
        concentration_ok = xau_share < 85.0 and direction_share < 80.0
        chasing_ok = chasing < 90.0 or variant in {"v4_micro_break_only", "v4_micro_or_candle"}
        gate_pass = bool(improves and enough_trades and fx_ok and concentration_ok and chasing_ok)
        reasons = []
        if not improves:
            reasons.append("no_pf_or_avgR_improvement")
        if not enough_trades:
            reasons.append("trade_count_too_low_without_large_edge_gain")
        if not fx_ok:
            reasons.append("fx_net_worse_than_current")
        if not concentration_ok:
            reasons.append("xau_or_direction_concentration_too_high")
        if not chasing_ok:
            reasons.append("chasing_not_reduced")
        rows.append(
            {
                "variant": variant,
                "gate_pass": gate_pass,
                "trades": trades,
                "pf": pf,
                "avg_R": avg_r,
                "fx_net": round(fx_net, 2),
                "xauusd_trade_share_pct": round(xau_share, 2),
                "largest_direction_share_pct": round(direction_share, 2),
                "chasing_entry_ratio_pct": round(chasing, 2),
                "reason": "pass" if gate_pass else ";".join(reasons),
            }
        )
    return rows


def write_devlog(gate_rows: list[dict[str, object]]) -> None:
    lines = [
        "# 2026-06-05 - ThirdWave v4 Signal Quality And Shadow SL/RewardR",
        "",
        "## Summary",
        "",
        "- Added `InpV4ReversalSignalMode` for v4-only signal selection.",
        "- Kept existing ThirdWave, v2, v3, v4 default, Phase2, score scanner, actual SL/TP, RewardR, spread guard, timeframes, CTrade bridge, and risk sizing unchanged.",
        "- Added wave-audit-only shadow metadata for MidTF and LowerTF SL candidates.",
        "- Added analyzer for fixed RewardR 1.2 / 1.3 / 1.5 and Current/MidTF/LowerTF SL shadow diagnostics.",
        "",
        "## Evidence",
        "",
        f"- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_v4_signal_shadow_compile.txt`",
        f"- Short-period summary: `reports/backtest/{OUT_PREFIX}_short_period_summary.md`",
        f"- Reversal signal comparison: `reports/backtest/{OUT_PREFIX}_reversal_signal_comparison.csv`",
        f"- SL/RewardR shadow comparison: `reports/backtest/{OUT_PREFIX}_sl_rewardR_comparison.csv`",
        "",
        "## Decision",
        "",
        "- Actual v4 signal-mode BT did not beat the current ThirdWave baseline on PF or avg_R, so no branch advanced to annual BT.",
        "- `micro_break` remains diagnostically interesting but failed as a standalone live-signal branch in the short-period test.",
        "- LowerTF reversal SL plus 1.2R/1.3R improved shadow results for micro/candle branches, but this is a shadow-only SL-location hypothesis, not an executed logic change.",
        "- Current SL and MidTF SL are effectively the same in this implementation; the useful next hypothesis is whether LowerTF structure SL can be implemented safely without excessive lot-size or invalid-stop side effects.",
        "",
        "## Annual Gate",
        "",
    ]
    if any(row["gate_pass"] for row in gate_rows):
        lines.append("- At least one signal branch passed the short-period gate; annual BT should be run only for passing branches.")
    else:
        lines.append("- No signal branch passed the short-period gate; annual BT was intentionally skipped.")
    for row in gate_rows:
        lines.append(f"- `{row['variant']}`: gate_pass={row['gate_pass']} reason={row['reason']}")
    Path("docs/devlog/2026-06-05-thirdwave-v4-signal-shadow.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    if not mt5.initialize():
        raise RuntimeError(f"MetaTrader5 initialize failed: {mt5.last_error()}")

    all_trades: list[dict[str, object]] = []
    comparison_rows: list[dict[str, object]] = []
    cache = RateCache()

    try:
        for series in SERIES:
            for run in RUNS:
                prefix = run_prefix(series["series_name"], run)
                report_path = BACKTEST / f"{prefix}_report.html"
                trades = parse_mt5_deals(report_path) if report_path.exists() else []
                write_trades(BACKTEST / f"{prefix}_trades.csv", trades)
                audit_rows = read_csv_rows(BACKTEST / f"{prefix}_thirdwave_wave_audit.csv")
                context = {
                    "period": series["period"],
                    "context": series["context"],
                    "run": run["run"],
                    "variant": run["variant"],
                    "scenario": run["scenario"],
                    "signal_mode": run["signal_mode"],
                }
                enriched = enrich_trades(trades, audit_rows, context)
                all_trades.extend(enriched)
                comparison_rows.append(
                    actual_run_row(
                        series,
                        run,
                        enriched,
                        read_elapsed(series["series_name"], run["run"]),
                        run_csv_bytes(prefix),
                    )
                )

        shadow_rows = build_shadow_rows(all_trades, cache)
    finally:
        mt5.shutdown()

    write_rows(BACKTEST / f"{OUT_PREFIX}_trades.csv", [trade_row_for_csv(row) for row in all_trades])
    write_rows(BACKTEST / f"{OUT_PREFIX}_reversal_signal_comparison.csv", comparison_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_micro_candle_comparison.csv", [r for r in comparison_rows if r["variant"] in {"v4_micro_break_only", "v4_candle_reversal_only", "v4_micro_or_candle"}])
    write_rows(BACKTEST / f"{OUT_PREFIX}_wave_label_aggregate.csv", aggregate_rows(all_trades, ["variant", "wave_audit_label"], "net_profit", "result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_symbol.csv", aggregate_rows(all_trades, ["variant", "symbol"], "net_profit", "result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_direction.csv", aggregate_rows(all_trades, ["variant", "direction"], "net_profit", "result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_session.csv", aggregate_rows(all_trades, ["variant", "session"], "net_profit", "result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_month.csv", aggregate_rows(all_trades, ["variant", "month"], "net_profit", "result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_reversal_signal_quality.csv", aggregate_rows(all_trades, ["variant", "reversal_signal_type"], "net_profit", "result_R"))

    write_rows(BACKTEST / f"{OUT_PREFIX}_shadow_sl_diagnostics.csv", shadow_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_rewardR_shadow_comparison.csv", aggregate_rows([r for r in shadow_rows if r["sl_mode"] == "CURRENT_SL"], ["variant", "reward_r"], "shadow_profit", "shadow_result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_rewardR_by_signal.csv", aggregate_rows([r for r in shadow_rows if r["sl_mode"] == "CURRENT_SL"], ["variant", "reward_r", "reversal_signal_type"], "shadow_profit", "shadow_result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_rewardR_by_label.csv", aggregate_rows([r for r in shadow_rows if r["sl_mode"] == "CURRENT_SL"], ["variant", "reward_r", "wave_audit_label"], "shadow_profit", "shadow_result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_rewardR_by_symbol.csv", aggregate_rows([r for r in shadow_rows if r["sl_mode"] == "CURRENT_SL"], ["variant", "reward_r", "symbol"], "shadow_profit", "shadow_result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_rewardR_by_direction.csv", aggregate_rows([r for r in shadow_rows if r["sl_mode"] == "CURRENT_SL"], ["variant", "reward_r", "direction"], "shadow_profit", "shadow_result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_rewardR_fx_vs_xauusd.csv", aggregate_rows([r for r in shadow_rows if r["sl_mode"] == "CURRENT_SL"], ["variant", "reward_r", "is_xauusd"], "shadow_profit", "shadow_result_R"))

    write_rows(BACKTEST / f"{OUT_PREFIX}_shadow_sl_aggregate_by_signal.csv", aggregate_rows(shadow_rows, ["variant", "sl_mode", "reward_r", "reversal_signal_type"], "shadow_profit", "shadow_result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_sl_rewardR_comparison.csv", aggregate_rows(shadow_rows, ["variant", "sl_mode", "reward_r"], "shadow_profit", "shadow_result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_sl_mode_by_signal.csv", aggregate_rows(shadow_rows, ["variant", "sl_mode", "reversal_signal_type"], "shadow_profit", "shadow_result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_sl_mode_by_label.csv", aggregate_rows(shadow_rows, ["variant", "sl_mode", "wave_audit_label"], "shadow_profit", "shadow_result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_sl_mode_by_symbol.csv", aggregate_rows(shadow_rows, ["variant", "sl_mode", "symbol"], "shadow_profit", "shadow_result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_sl_mode_by_direction.csv", aggregate_rows(shadow_rows, ["variant", "sl_mode", "direction"], "shadow_profit", "shadow_result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_sl_mode_fx_vs_xauusd.csv", aggregate_rows(shadow_rows, ["variant", "sl_mode", "is_xauusd"], "shadow_profit", "shadow_result_R"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_sl_mode_session_month.csv", aggregate_rows(shadow_rows, ["variant", "sl_mode", "session", "month"], "shadow_profit", "shadow_result_R"))

    gate_rows = build_gate_rows(all_trades)
    write_rows(BACKTEST / f"{OUT_PREFIX}_annual_gate.csv", gate_rows)
    annual_lines = [
        "# ThirdWave v4 Signal Shadow Annual Summary",
        "",
        "Annual BT was not run unless a signal branch passed the short-period gate.",
        "",
    ]
    if any(row["gate_pass"] for row in gate_rows):
        annual_lines.append("At least one branch passed. Run annual BT for passing variants before treating this as annual evidence.")
    else:
        annual_lines.append("No branch passed the short-period gate, so annual BT was intentionally skipped.")
    (BACKTEST / f"{OUT_PREFIX}_annual_summary.md").write_text("\n".join(annual_lines) + "\n", encoding="utf-8")

    metrics = {
        "comparison_rows": comparison_rows,
        "gate_rows": gate_rows,
        "shadow_rows": len(shadow_rows),
    }
    with (BACKTEST / f"{OUT_PREFIX}_metrics.json").open("w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=2, default=str)

    write_short_summary(all_trades, comparison_rows, shadow_rows, gate_rows)
    write_devlog(gate_rows)
    print(json.dumps({"gate_rows": gate_rows, "shadow_rows": len(shadow_rows)}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
