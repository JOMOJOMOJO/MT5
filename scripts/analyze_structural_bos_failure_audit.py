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
except ImportError:  # pragma: no cover - analyzer can still use stored MFE rows.
    mt5 = None

from analyze_multicurrency_score_scanner_2025 import BACKTEST, calc_stats


ROOT = Path(__file__).resolve().parents[1]
OUT_BASE = "ExpectedValue_MultiCurrency_ScoreScanner"
OUT_PREFIX = f"{OUT_BASE}_structural_bos_failure_audit"
STRUCTURAL_SCENARIO = "Nested_NWave_StructuralBOS_BOTH_all_H4_H1_M15_2R"
MT5_RATE_TIME_OFFSET = timedelta(hours=9)

PERIODS = [
    ("2025-02", "2025_02_structural_bos"),
    ("2025-08", "2025_08_structural_bos"),
    ("2025-10", "2025_10_structural_bos"),
    ("2026-Q1", "2026_q1_structural_bos"),
]

RUN_NAME = "E_structural_bos_all"

OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_summary.md",
    "by_reason": BACKTEST / f"{OUT_PREFIX}_by_reason.csv",
    "by_label": BACKTEST / f"{OUT_PREFIX}_by_label.csv",
    "h1_bos": BACKTEST / f"{OUT_BASE}_structural_bos_h1_bos_level_audit.csv",
    "pivot": BACKTEST / f"{OUT_BASE}_structural_bos_pivot_sequence_audit.csv",
    "timing": BACKTEST / f"{OUT_BASE}_structural_bos_entry_timing_audit.csv",
    "rejection": BACKTEST / f"{OUT_BASE}_structural_bos_rejection_counter.csv",
    "clean_losers": BACKTEST / f"{OUT_BASE}_structural_bos_clean_losers_sample.csv",
    "chasing_near": BACKTEST / f"{OUT_BASE}_structural_bos_chasing_entry_winners_or_near_winners_sample.csv",
    "no_trade_2025_10": BACKTEST / f"{OUT_BASE}_structural_bos_2025_10_no_trade_sample.csv",
    "losers_2026_q1": BACKTEST / f"{OUT_BASE}_structural_bos_2026_q1_losers_sample.csv",
    "metrics": BACKTEST / f"{OUT_PREFIX}_metrics.json",
}


def prefix(series: str) -> str:
    return f"{OUT_BASE}_{series}_{RUN_NAME}"


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return list(csv.DictReader(fh))


def write_rows(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fields: list[str] = []
    seen = set()
    for row in rows:
        for key in row.keys():
            if key not in seen:
                seen.add(key)
                fields.append(key)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def md_link(label: str, target: Path, base: Path) -> str:
    rel = os.path.relpath(target.resolve(), base.resolve())
    return f"[{label}]({Path(rel).as_posix()})"


def parse_time(value: str | None) -> datetime | None:
    if not value:
        return None
    value = value.strip()
    if not value:
        return None
    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")


def as_float(value: Any, default: float = 0.0) -> float:
    try:
        text = str(value).replace("\xa0", "").replace(" ", "").replace(",", "").strip()
        return float(text) if text else default
    except (TypeError, ValueError):
        return default


def as_int(value: Any, default: int = 0) -> int:
    try:
        text = str(value).strip()
        return int(float(text)) if text else default
    except (TypeError, ValueError):
        return default


def as_bool(value: Any) -> bool:
    return str(value).strip().lower() in {"true", "1", "yes"}


def session_from_time(open_time: str) -> str:
    dt = parse_time(open_time)
    if dt is None:
        return ""
    return f"server_{(dt.hour // 8) * 8:02d}_{(dt.hour // 8) * 8 + 7:02d}"


def fx_bucket(symbol: str) -> str:
    return "XAUUSD" if symbol.upper().startswith("XAU") else "FX"


def summary_paths() -> dict[str, Path]:
    return {
        period: BACKTEST / f"{prefix(series)}_nested_nwave_summary.csv"
        for period, series in PERIODS
    }


def signal_paths() -> dict[str, Path]:
    return {
        period: BACKTEST / f"{prefix(series)}_nested_nwave_signal_diagnostics.csv"
        for period, series in PERIODS
    }


def trade_diag_paths() -> dict[str, Path]:
    return {
        period: BACKTEST / f"{prefix(series)}_nested_nwave_trade_diagnostics.csv"
        for period, series in PERIODS
    }


def scan_driver_symbol(period: str, series: str) -> str:
    path = BACKTEST / f"{prefix(series)}_scan_diagnostics.csv"
    rows = read_csv(path)
    for row in rows:
        value = row.get("scan_driver_symbol", "")
        if value:
            return value
    return ""


def load_structural_trade_rows() -> list[dict[str, str]]:
    path = BACKTEST / f"{OUT_BASE}_nested_structural_bos_trade_rows.csv"
    rows = [
        row for row in read_csv(path)
        if row.get("scenario") == STRUCTURAL_SCENARIO
    ]
    return rows


def load_order_sent_diagnostics() -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for period, _series in PERIODS:
        for row in read_csv(trade_diag_paths()[period]):
            if row.get("event") == "order_sent":
                enriched = dict(row)
                enriched["period"] = period
                rows.append(enriched)
    return rows


def load_blocked_candidates() -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for period, _series in PERIODS:
        for row in read_csv(signal_paths()[period]):
            if row.get("event") in {"blocked_candidate", "final_candidate"}:
                enriched = dict(row)
                enriched["period"] = period
                rows.append(enriched)
        for row in read_csv(trade_diag_paths()[period]):
            if row.get("event") == "order_blocked":
                enriched = dict(row)
                enriched["period"] = period
                rows.append(enriched)
    return rows


def match_order_diag(trade: dict[str, str], order_rows: list[dict[str, str]], used: set[int]) -> dict[str, str]:
    open_time = parse_time(trade.get("open_time"))
    best_idx = -1
    best_delta = 999999.0
    for idx, row in enumerate(order_rows):
        if idx in used:
            continue
        if row.get("period") != trade.get("period"):
            continue
        if row.get("symbol") != trade.get("symbol"):
            continue
        if row.get("direction") != trade.get("direction"):
            continue
        row_time = parse_time(row.get("time"))
        if open_time is None or row_time is None:
            continue
        delta = abs((open_time - row_time).total_seconds())
        if delta <= 180 and delta < best_delta:
            best_delta = delta
            best_idx = idx
    if best_idx >= 0:
        used.add(best_idx)
        return order_rows[best_idx]
    return {}


def classify_h1_bos_level(row: dict[str, Any]) -> str:
    state = str(row.get("structural_bos_state", ""))
    counter_state = str(row.get("h1_counter_trend_state", ""))
    bos = as_float(row.get("h1_bos_level"))
    dist_atr = as_float(row.get("distance_bos_to_entry_atr"))
    bars = as_int(row.get("bars_since_bos"))
    sl_atr = as_float(row.get("sl_atr"))
    if bos <= 0:
        return "h1_bos_level_unclear"
    if "counter" not in counter_state:
        return "h1_bos_level_not_counter_nwave_structure"
    if bars > 8:
        return "h1_bos_level_too_old"
    if dist_atr > 1.8:
        return "h1_bos_level_too_old"
    if dist_atr < 0.12 and sl_atr > 1.6:
        return "h1_bos_level_too_minor"
    if state in {"h1_bos_confirmed", "m15_countertrend_bos_confirmed"}:
        return "h1_bos_level_valid"
    return "h1_bos_level_unclear"


def classify_pivots(row: dict[str, Any]) -> tuple[str, str, str]:
    h4_state = str(row.get("h4_trend_state", ""))
    fib = as_float(row.get("h4_fib_retracement_pct", 0.0))
    fib_zone = str(row.get("fib_zone", ""))
    h1_state = str(row.get("h1_counter_trend_state", ""))
    h1_high = as_float(row.get("h1_counter_nwave_high", 0.0))
    h1_low = as_float(row.get("h1_counter_nwave_low", 0.0))
    dist_atr = as_float(row.get("distance_bos_to_entry_atr", 0.0))

    if h4_state not in {"bullish_nwave", "bearish_nwave"}:
        h4_impulse = "h4_impulse_unclear"
    elif fib_zone == "valid_h4_pullback_zone" and fib > 0:
        h4_impulse = "h4_impulse_valid"
    else:
        h4_impulse = "h4_impulse_too_small" if fib <= 0 else "h4_impulse_unclear"

    if fib_zone != "valid_h4_pullback_zone":
        h4_correction = "h4_correction_range_noise"
    elif 47.0 <= fib <= 53.0:
        h4_correction = "h4_correction_range_noise"
    else:
        h4_correction = "h4_correction_valid"

    if "counter" not in h1_state or h1_high <= 0 or h1_low <= 0:
        h1_counter = "h1_counter_nwave_range_noise"
    elif dist_atr < 0.15:
        h1_counter = "h1_counter_nwave_too_shallow"
    elif dist_atr > 1.8:
        h1_counter = "h1_counter_nwave_overextended"
    else:
        h1_counter = "h1_counter_nwave_valid"
    return h4_impulse, h4_correction, h1_counter


def classify_failure_type(row: dict[str, Any]) -> str:
    result_r = as_float(row.get("result_R"))
    mfe = as_float(row.get("max_favorable_r"))
    mae = as_float(row.get("max_adverse_r"))
    label = str(row.get("label", ""))
    bos_label = classify_h1_bos_level(row)
    breakout = str(row.get("breakout_quality_label", ""))
    sl_atr = as_float(row.get("sl_atr"))
    bars = as_int(row.get("bars_since_bos"))
    dist_atr = as_float(row.get("distance_bos_to_entry_atr"))
    h4_impulse, h4_correction, h1_counter = classify_pivots(row)

    if result_r >= 0:
        return ""
    if sl_atr > 2.2:
        return "sl_too_wide"
    if sl_atr < 0.35:
        return "sl_too_tight"
    if label == "chasing_entry" or dist_atr > 1.8:
        return "chasing_entry"
    if label == "late_entry" or bars > 8:
        return "late_entry"
    if bos_label != "h1_bos_level_valid":
        return "h1_bos_level_wrong"
    if h4_impulse != "h4_impulse_valid" or h4_correction != "h4_correction_valid":
        return "h4_context_wrong"
    if h1_counter != "h1_counter_nwave_valid":
        return "h1_counter_nwave_not_real"
    if breakout == "dirty_breakout":
        return "m15_confirmation_too_weak"
    if mfe < 0.5 and mae >= 0.8:
        return "no_follow_through"
    if mfe >= 1.0 and result_r < 0:
        return "target_too_far"
    return "unclear"


def classify_entry_timing(row: dict[str, Any]) -> str:
    result_r = as_float(row.get("result_R"))
    mfe = as_float(row.get("max_favorable_r"))
    label = str(row.get("label", ""))
    breakout = str(row.get("breakout_quality_label", ""))
    dist_atr = as_float(row.get("distance_bos_to_entry_atr"))
    bars = as_int(row.get("bars_since_bos"))
    if label == "chasing_entry" or dist_atr > 1.8:
        return "chasing_entry"
    if label == "late_entry" or bars > 8:
        return "late_entry"
    if breakout == "dirty_breakout" and result_r < 0:
        return "false_bos_entry"
    if mfe < 0.5 and result_r < 0:
        return "no_follow_through"
    if result_r > 0 and dist_atr <= 1.2 and bars <= 4:
        return "good_timing"
    if result_r > 0:
        return "early_but_valid"
    return "bad_context_entry"


def r_reach_with_time(row: dict[str, Any]) -> dict[str, Any]:
    result = {
        "time_to_0_5R": "",
        "time_to_1R": "",
        "time_to_SL": "",
        "entry_after_wave_consumed_pct": "",
        "entry_to_next_h1_obstacle_R": "",
        "entry_to_next_h4_obstacle_R": "",
    }
    if mt5 is None:
        return result
    open_time = parse_time(str(row.get("open_time", "")))
    close_time = parse_time(str(row.get("close_time", "")))
    if open_time is None or close_time is None:
        return result
    direction = 1 if row.get("direction") == "LONG" else -1
    entry = as_float(row.get("entry_price"))
    sl = as_float(row.get("sl"))
    if entry <= 0 or sl <= 0:
        return result
    risk = abs(entry - sl)
    if risk <= 0:
        return result

    rates = mt5.copy_rates_range(
        str(row.get("symbol")),
        mt5.TIMEFRAME_M15,
        open_time - MT5_RATE_TIME_OFFSET,
        close_time - MT5_RATE_TIME_OFFSET + timedelta(hours=2),
    )
    if rates is None or len(rates) == 0:
        return result

    hit_05 = None
    hit_1 = None
    hit_sl = None
    for rate in rates:
        bar_time = datetime.fromtimestamp(int(rate["time"])) + MT5_RATE_TIME_OFFSET
        high = float(rate["high"])
        low = float(rate["low"])
        favorable = ((high - entry) / risk) if direction > 0 else ((entry - low) / risk)
        adverse = ((entry - low) / risk) if direction > 0 else ((high - entry) / risk)
        if hit_05 is None and favorable >= 0.5:
            hit_05 = bar_time
        if hit_1 is None and favorable >= 1.0:
            hit_1 = bar_time
        if hit_sl is None and adverse >= 1.0:
            hit_sl = bar_time
        if hit_05 and hit_1 and hit_sl:
            break

    def minutes(hit: datetime | None) -> str:
        if hit is None:
            return ""
        return str(round((hit - open_time).total_seconds() / 60.0, 2))

    result["time_to_0_5R"] = minutes(hit_05)
    result["time_to_1R"] = minutes(hit_1)
    result["time_to_SL"] = minutes(hit_sl)

    right_side_dist = as_float(row.get("distance_right_side_to_entry_atr", 0.0))
    bos_dist = as_float(row.get("distance_bos_to_entry_atr", 0.0))
    if right_side_dist > 0:
        result["entry_after_wave_consumed_pct"] = round(min(999.0, bos_dist / right_side_dist * 100.0), 2)

    h1_high = as_float(row.get("h1_counter_nwave_high"))
    h1_low = as_float(row.get("h1_counter_nwave_low"))
    if direction > 0 and h1_high > entry:
        result["entry_to_next_h1_obstacle_R"] = round((h1_high - entry) / risk, 3)
    if direction < 0 and h1_low > 0 and h1_low < entry:
        result["entry_to_next_h1_obstacle_R"] = round((entry - h1_low) / risk, 3)

    h4_high = as_float(row.get("h4_impulse_high"))
    h4_low = as_float(row.get("h4_impulse_low"))
    if direction > 0 and h4_high > entry:
        result["entry_to_next_h4_obstacle_R"] = round((h4_high - entry) / risk, 3)
    if direction < 0 and h4_low > 0 and h4_low < entry:
        result["entry_to_next_h4_obstacle_R"] = round((entry - h4_low) / risk, 3)

    return result


def build_enriched_trades() -> list[dict[str, Any]]:
    trades = load_structural_trade_rows()
    order_rows = load_order_sent_diagnostics()
    used: set[int] = set()
    enriched: list[dict[str, Any]] = []
    for trade in trades:
        diag = match_order_diag(trade, order_rows, used)
        row: dict[str, Any] = {**diag, **trade}
        row["entry_time"] = trade.get("open_time", "")
        row["entry_price"] = diag.get("entry_price", "")
        row["sl"] = diag.get("sl", "")
        row["tp"] = diag.get("tp", "")
        row["h4_impulse_start"] = diag.get("h4_impulse_low", "")
        row["h4_impulse_end"] = diag.get("h4_impulse_high", "")
        if row.get("direction") == "SHORT":
            row["h4_impulse_start"] = diag.get("h4_impulse_high", "")
            row["h4_impulse_end"] = diag.get("h4_impulse_low", "")
        row["h4_correction_depth"] = diag.get("h4_fib_retracement_pct", "")
        row["h1_counter_nwave_sequence"] = f"high={diag.get('h1_counter_nwave_high', '')};low={diag.get('h1_counter_nwave_low', '')}"
        row["m15_bos_close"] = diag.get("neckline_break_close_price", "")
        row["h1_bos_level_label"] = classify_h1_bos_level(row)
        h4_impulse, h4_correction, h1_counter = classify_pivots(row)
        row["h4_impulse_audit_label"] = h4_impulse
        row["h4_correction_audit_label"] = h4_correction
        row["h1_counter_nwave_audit_label"] = h1_counter
        row["failure_type"] = classify_failure_type(row)
        row["entry_timing_label"] = classify_entry_timing(row)
        row.update(r_reach_with_time(row))
        enriched.append(row)
    return enriched


def summary_counter_rows() -> list[dict[str, Any]]:
    categories = {
        "no_h4_impulse": ["no_h4_nwave"],
        "no_h4_correction": ["too_shallow_pullback", "too_deep_pullback"],
        "h4_range_middle_noise": [],
        "no_h1_counter_nwave": ["no_h1_counter_trend_nwave"],
        "h1_counter_nwave_weak": [],
        "no_h1_bos": [],
        "no_m15_bos": ["no_neckline_break"],
        "m15_bos_late": [],
        "sl_too_wide": ["sl_too_wide"],
        "sl_too_tight": ["sl_too_tight"],
        "spread_guard": ["spread_guard"],
        "existing_position": ["existing_position"],
        "insufficient_data": ["data_unavailable", "atr_unavailable"],
        "symbol_disabled_by_research_mode": ["research_excluded"],
        "direction_disabled_by_research_mode": [],
    }
    rows: list[dict[str, Any]] = []
    for period, path in summary_paths().items():
        summary = read_csv(path)
        if not summary:
            continue
        row = summary[-1]
        known_sum = 0
        for category, fields in categories.items():
            count = sum(as_int(row.get(field)) for field in fields)
            known_sum += count
            rows.append({
                "period": period,
                "reason": category,
                "rows": count,
                "source": "+".join(fields) if fields else "not_separately_logged",
                "note": "summary counter; h1 weak/no_h1_bos are not fully separable in current EA logs" if not fields else "",
            })
        total_evals = as_int(row.get("evaluations"))
        rows.append({
            "period": period,
            "reason": "other",
            "rows": max(0, total_evals - known_sum),
            "source": "evaluations-minus-known-counters",
            "note": "includes pass-through evaluations and reasons not represented by dedicated summary counters",
        })
    return rows


def blocked_sample_rows() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for row in load_blocked_candidates():
        out = dict(row)
        out["fx_vs_xauusd"] = fx_bucket(row.get("symbol", ""))
        out["h1_bos_level_label"] = classify_h1_bos_level(out)
        h4_impulse, h4_correction, h1_counter = classify_pivots(out)
        out["h4_impulse_audit_label"] = h4_impulse
        out["h4_correction_audit_label"] = h4_correction
        out["h1_counter_nwave_audit_label"] = h1_counter
        out["entry_timing_label"] = classify_entry_timing(out)
        rows.append(out)
    return rows


def group_stats(rows: list[dict[str, Any]], keys: list[str]) -> list[dict[str, Any]]:
    buckets: dict[tuple[str, ...], list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        buckets[tuple(str(row.get(key, "")) for key in keys)].append(row)
    output: list[dict[str, Any]] = []
    for key, bucket in sorted(buckets.items()):
        synthetic = []
        for item in bucket:
            synthetic.append({
                "net_profit": as_float(item.get("net_profit")),
                "open_time": item.get("open_time", ""),
                "close_time": item.get("close_time", ""),
            })
        stats = calc_stats(synthetic)
        out = {keys[idx]: key[idx] for idx in range(len(keys))}
        out.update({
            "trades": stats["trades"],
            "wins": stats["wins"],
            "losses": stats["losses"],
            "win_rate": round(float(stats["win_rate"]), 2),
            "net_profit": round(float(stats["net_profit"]), 2),
            "profit_factor": round(float(stats["profit_factor"]), 3) if stats["profit_factor"] is not None else "",
            "expected_payoff": round(float(stats["expected_payoff"]), 2),
            "avg_R": round(sum(as_float(item.get("result_R")) for item in bucket) / len(bucket), 3) if bucket else 0.0,
            "avg_MFE_R": round(sum(as_float(item.get("max_favorable_r")) for item in bucket) / len(bucket), 3) if bucket else 0.0,
            "avg_MAE_R": round(sum(as_float(item.get("max_adverse_r")) for item in bucket) / len(bucket), 3) if bucket else 0.0,
        })
        output.append(out)
    return output


def main() -> None:
    mt5_ready = False
    if mt5 is not None:
        mt5_ready = bool(mt5.initialize())

    trades = build_enriched_trades()
    if mt5_ready and mt5 is not None:
        mt5.shutdown()

    blocked = blocked_sample_rows()
    counters = summary_counter_rows()

    for row in trades:
        row["scan_driver_symbol"] = row.get("scan_driver_symbol", "USDJPY")
        row["fx_vs_xauusd"] = fx_bucket(str(row.get("symbol", "")))
        row["period_label"] = row.get("period", "")

    by_reason = group_stats([row for row in trades if row.get("failure_type")], ["period", "failure_type"])
    by_label = group_stats(trades, ["period", "label"])

    h1_rows = []
    pivot_rows = []
    timing_rows = []
    for row in trades:
        base = {
            "period": row.get("period"),
            "symbol": row.get("symbol"),
            "direction": row.get("direction"),
            "entry_time": row.get("entry_time"),
            "label": row.get("label"),
            "result_R": row.get("result_R"),
            "net_profit": row.get("net_profit"),
            "scan_driver_symbol": row.get("scan_driver_symbol"),
        }
        h1_rows.append({
            **base,
            "h1_bos_level": row.get("h1_bos_level"),
            "h1_counter_nwave_high": row.get("h1_counter_nwave_high"),
            "h1_counter_nwave_low": row.get("h1_counter_nwave_low"),
            "h1_counter_trend_state": row.get("h1_counter_trend_state"),
            "structural_bos_state": row.get("structural_bos_state"),
            "m15_confirmation_type": row.get("m15_confirmation_type"),
            "distance_bos_to_entry_atr": row.get("distance_bos_to_entry_atr"),
            "bars_since_bos": row.get("bars_since_bos"),
            "h1_bos_level_label": row.get("h1_bos_level_label"),
        })
        pivot_rows.append({
            **base,
            "h4_impulse_start": row.get("h4_impulse_start"),
            "h4_impulse_end": row.get("h4_impulse_end"),
            "h4_correction_depth": row.get("h4_correction_depth"),
            "h4_trend_state": row.get("h4_trend_state"),
            "fib_zone": row.get("fib_zone"),
            "h1_counter_nwave_sequence": row.get("h1_counter_nwave_sequence"),
            "h4_impulse_audit_label": row.get("h4_impulse_audit_label"),
            "h4_correction_audit_label": row.get("h4_correction_audit_label"),
            "h1_counter_nwave_audit_label": row.get("h1_counter_nwave_audit_label"),
        })
        timing_rows.append({
            **base,
            "entry_timing_label": row.get("entry_timing_label"),
            "failure_type": row.get("failure_type"),
            "max_favorable_r": row.get("max_favorable_r"),
            "max_adverse_r": row.get("max_adverse_r"),
            "reached_0_5R": row.get("reached_0_5R"),
            "reached_1R": row.get("reached_1R"),
            "reached_2R": row.get("reached_2R"),
            "time_to_0_5R": row.get("time_to_0_5R"),
            "time_to_1R": row.get("time_to_1R"),
            "time_to_SL": row.get("time_to_SL"),
            "bos_to_entry_atr": row.get("distance_bos_to_entry_atr"),
            "bos_to_entry_bars": row.get("bars_since_bos"),
            "entry_after_wave_consumed_pct": row.get("entry_after_wave_consumed_pct"),
            "entry_to_next_h1_obstacle_R": row.get("entry_to_next_h1_obstacle_R"),
            "entry_to_next_h4_obstacle_R": row.get("entry_to_next_h4_obstacle_R"),
        })

    clean_losers = [
        row for row in trades
        if row.get("label") == "clean_structural_bos" and as_float(row.get("result_R")) < 0
    ][:50]
    chasing_near = [
        row for row in trades
        if row.get("label") == "chasing_entry" and (as_float(row.get("result_R")) > 0 or as_float(row.get("max_favorable_r")) >= 0.5)
    ][:50]
    no_trade_2025_10 = [
        row for row in blocked
        if row.get("period") == "2025-10"
    ][:50]
    losers_2026_q1 = [
        row for row in trades
        if row.get("period") == "2026-Q1" and as_float(row.get("result_R")) < 0
    ][:50]

    write_rows(OUTPUTS["by_reason"], by_reason)
    write_rows(OUTPUTS["by_label"], by_label)
    write_rows(OUTPUTS["h1_bos"], h1_rows)
    write_rows(OUTPUTS["pivot"], pivot_rows)
    write_rows(OUTPUTS["timing"], timing_rows)
    write_rows(OUTPUTS["rejection"], counters)
    write_rows(OUTPUTS["clean_losers"], clean_losers)
    write_rows(OUTPUTS["chasing_near"], chasing_near)
    write_rows(OUTPUTS["no_trade_2025_10"], no_trade_2025_10)
    write_rows(OUTPUTS["losers_2026_q1"], losers_2026_q1)

    h1_label_counts = Counter(row["h1_bos_level_label"] for row in h1_rows)
    pivot_counts = Counter(row["h1_counter_nwave_audit_label"] for row in pivot_rows)
    timing_counts = Counter(row["entry_timing_label"] for row in timing_rows)
    counter_by_period_reason = defaultdict(int)
    for row in counters:
        counter_by_period_reason[(row["period"], row["reason"])] += as_int(row["rows"])

    aggregate_stats = calc_stats([
        {"net_profit": as_float(row.get("net_profit")), "open_time": row.get("open_time", ""), "close_time": row.get("close_time", "")}
        for row in trades
    ])
    clean_stats = calc_stats([
        {"net_profit": as_float(row.get("net_profit")), "open_time": row.get("open_time", ""), "close_time": row.get("close_time", "")}
        for row in trades if row.get("label") == "clean_structural_bos"
    ])
    chasing_stats = calc_stats([
        {"net_profit": as_float(row.get("net_profit")), "open_time": row.get("open_time", ""), "close_time": row.get("close_time", "")}
        for row in trades if row.get("label") == "chasing_entry"
    ])

    lines = [
        "# Structural BOS Failure Audit",
        "",
        "This audit uses existing short-period Structural BOS artifacts only. It does not change EA order logic, SL/TP, RewardR, risk, CTrade, spread guard, timeframe, symbol filters, direction filters, or run annual BT.",
        "",
        "## Scope",
        "",
        "- Strategy: `RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS`",
        "- Periods: `2025-02`, `2025-08`, `2025-10`, `2026-Q1`",
        "- Data source: existing nested signal/trade diagnostics and Structural BOS short comparison outputs",
        f"- MT5 M15 rate lookup for time-to-R fields: `{mt5_ready}`",
        "",
        "## Aggregate Result",
        "",
        f"- Trades: `{aggregate_stats['trades']}`",
        f"- PF: `{round(float(aggregate_stats['profit_factor']), 3) if aggregate_stats['profit_factor'] is not None else ''}`",
        f"- Expected payoff: `{round(float(aggregate_stats['expected_payoff']), 2)}`",
        f"- Net: `{round(float(aggregate_stats['net_profit']), 2)}`",
        f"- clean_structural_bos: `{clean_stats['trades']}` trades, PF `{round(float(clean_stats['profit_factor']), 3) if clean_stats['profit_factor'] is not None else ''}`, net `{round(float(clean_stats['net_profit']), 2)}`",
        f"- chasing_entry: `{chasing_stats['trades']}` trades, PF `{round(float(chasing_stats['profit_factor']), 3) if chasing_stats['profit_factor'] is not None else ''}`, net `{round(float(chasing_stats['net_profit']), 2)}`",
        "",
        "## Why 2025-08 / 2025-10 Had No Orders",
        "",
        "- The summary counters show most evaluations died before a usable H4/H1 setup: `no_h4_nwave` was the dominant counter in both windows.",
        f"- 2025-08 `no_h4_impulse`: `{counter_by_period_reason[('2025-08', 'no_h4_impulse')]}`",
        f"- 2025-08 `no_h1_counter_nwave`: `{counter_by_period_reason[('2025-08', 'no_h1_counter_nwave')]}`",
        f"- 2025-08 `no_m15_bos`: `{counter_by_period_reason[('2025-08', 'no_m15_bos')]}`",
        f"- 2025-10 `no_h4_impulse`: `{counter_by_period_reason[('2025-10', 'no_h4_impulse')]}`",
        f"- 2025-10 `no_h1_counter_nwave`: `{counter_by_period_reason[('2025-10', 'no_h1_counter_nwave')]}`",
        f"- 2025-10 `no_m15_bos`: `{counter_by_period_reason[('2025-10', 'no_m15_bos')]}`",
        "- For 2025-10, only a few final candidates reached logged blocked-candidate status, and all were blocked by spread guard after the H1/M15 structural checks. This means the zero-order outcome is mostly setup scarcity plus execution blocking, not simply a lack of price movement.",
        "",
        "## Clean Structural BOS Failure",
        "",
        "- `clean_structural_bos` was not clean in performance terms. It mostly avoided the explicit chasing labels but still failed after entry.",
        "- The losing clean samples show valid-looking H1/M15 BOS labels, but MFE was generally too weak or the stop was reached before enough follow-through.",
        "- This points to H4/H1 structure definition weakness rather than an M15 confirmation-only problem.",
        "",
        "## H1 BOS Level Audit",
        "",
        *[f"- `{key}`: `{value}`" for key, value in sorted(h1_label_counts.items())],
        "",
        "Interpretation: the current BOS level is often mechanically valid according to the latest pivot comparison, but the diagnostics cannot prove it is a meaningful countertrend N-wave invalidation line. The EA currently logs only compressed H1 high/low values, not the full pivot sequence.",
        "",
        "## Pivot Sequence Audit",
        "",
        *[f"- `{key}`: `{value}`" for key, value in sorted(pivot_counts.items())],
        "",
        "The current logic is still too close to latest-pivot comparison. It can label an H1 counter N-wave as valid without proving a full three-point N-wave or trader stop cluster.",
        "",
        "## Entry Timing Audit",
        "",
        *[f"- `{key}`: `{value}`" for key, value in sorted(timing_counts.items())],
        "",
        "## Judgement",
        "",
        "1. Structural BOS v0 failed because the H4/H1 setup definition is too sparse and the H1 BOS level is only mechanically derived from recent pivots.",
        "2. 2025-08 / 2025-10 had zero orders mainly because the setup filter generated almost no tradable candidates; 2025-10 also had spread-guard blocks on the few candidates that reached final diagnostics.",
        "3. `clean_structural_bos` underperformed `chasing_entry` because clean only meant close to the BOS level, not that the H4/H1 N-wave structure was meaningful.",
        "4. The H1 BOS level is not proven to be a true structural invalidation line from current diagnostics.",
        "5. H4/H1 pivot sequence validation is the next weak point. M15 confirmation is secondary.",
        "6. Structural BOS v2 is worth considering only if it first upgrades H4/H1 structure logging and validation: full pivot sequence, minimum wave size, countertrend N-wave depth, and next obstacle/room-to-target.",
        "",
        "## Artifacts",
        "",
        f"- By reason: {md_link('by reason', OUTPUTS['by_reason'], OUTPUTS['summary'].parent)}",
        f"- By label: {md_link('by label', OUTPUTS['by_label'], OUTPUTS['summary'].parent)}",
        f"- H1 BOS level audit: {md_link('H1 BOS level audit', OUTPUTS['h1_bos'], OUTPUTS['summary'].parent)}",
        f"- Pivot sequence audit: {md_link('pivot sequence audit', OUTPUTS['pivot'], OUTPUTS['summary'].parent)}",
        f"- Entry timing audit: {md_link('entry timing audit', OUTPUTS['timing'], OUTPUTS['summary'].parent)}",
        f"- Rejection counter: {md_link('rejection counter', OUTPUTS['rejection'], OUTPUTS['summary'].parent)}",
        f"- Clean losers sample: {md_link('clean losers sample', OUTPUTS['clean_losers'], OUTPUTS['summary'].parent)}",
        f"- 2025-10 no trade sample: {md_link('2025-10 no trade sample', OUTPUTS['no_trade_2025_10'], OUTPUTS['summary'].parent)}",
    ]
    OUTPUTS["summary"].write_text("\n".join(lines) + "\n", encoding="utf-8")

    metrics = {
        "aggregate": aggregate_stats,
        "clean": clean_stats,
        "chasing": chasing_stats,
        "h1_label_counts": dict(h1_label_counts),
        "pivot_counts": dict(pivot_counts),
        "timing_counts": dict(timing_counts),
        "mt5_rates_available": mt5_ready,
    }
    OUTPUTS["metrics"].write_text(json.dumps(metrics, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    print(json.dumps({
        "summary": str(OUTPUTS["summary"]),
        "trades": len(trades),
        "blocked_candidates": len(blocked),
        "mt5_rates_available": mt5_ready,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
