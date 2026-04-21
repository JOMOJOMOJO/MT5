from __future__ import annotations

import argparse
import csv
import json
import math
import os
import re
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any

import pandas as pd


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[3]
COMMON_FILES_ROOT = Path(os.environ["APPDATA"]) / "MetaQuotes" / "Terminal" / "Common" / "Files"
SWEEP_ROOT = REPO_ROOT / "reports" / "backtest" / "sweeps" / "2026-04-21-usdjpy-intraday-feature-regime-research"
RESULTS_ROOT = SWEEP_ROOT / "results"

TIMESTAMP_FORMAT = "%Y.%m.%d %H:%M:%S"
WINDOW_ORDER = ["train", "oos", "actual"]
MIN_OOS_TRADES = 5
MIN_ACTUAL_TRADES = 20

SESSION_BOX_PATTERN = re.compile(
    r"^mt5_company_session_box_(?P<window>train|oos|actual)-(?P<pair>[a-z0-9_]+)-(?P<trigger>close|retest|cont)\.csv$"
)
N_WAVE_PATTERN = re.compile(
    r"^mt5_company_phase1-(?P<window>train|oos|actual)-(?P<pair>[a-z0-9_]+)-core-(?P<trigger>close|retest|swing)\.csv$"
)
EXTERNAL_SWEEP_PATTERN = re.compile(
    r"^mt5_company_phase1-(?P<window>train|oos|actual)-(?P<pair>[a-z0-9_]+)-(?P<level>ctx|m30|pday)-(?P<trigger>reclaim|retest|swing)\.csv$"
)
LOCAL_SWEEP_PATTERN = re.compile(
    r"^mt5_company_phase1-(?P<window>train|oos|actual)-(?P<pair>[a-z0-9_]+)-(?P<trigger>reclaim_close_confirm|retest_failure|recent_swing_breakdown)\.csv$"
)
DOWN_HS_PATTERN = re.compile(
    r"^mt5_company_phase1-(?P<window>train|oos|actual)-(?P<pair>[a-z0-9_]+)-(?P<trigger>neck_close_confirm|neck_retest_failure|recent_swing_break)\.csv$"
)

FEATURE_COLUMNS = [
    "session_type",
    "entry_session_bucket",
    "london_timing_bucket",
    "weekday",
    "breakout_side",
    "prev_day_alignment_type",
    "m30_swing_alignment_type",
    "size_bucket",
    "entry_strength_bucket",
    "trigger_type",
    "subtype",
    "invalidation_line_type",
    "entry_archetype",
]

BIVARIATE_FEATURES = [
    ("breakout_side", "trigger_type"),
    ("london_timing_bucket", "breakout_side"),
    ("prev_day_alignment_type", "breakout_side"),
    ("trigger_type", "entry_strength_bucket"),
    ("subtype", "invalidation_line_type"),
    ("entry_session_bucket", "london_timing_bucket"),
]

UNIVARIATE_FEATURE_PRIORITY = [
    "breakout_side",
    "trigger_type",
    "london_timing_bucket",
    "prev_day_alignment_type",
    "m30_swing_alignment_type",
    "entry_strength_bucket",
    "subtype",
    "invalidation_line_type",
    "entry_session_bucket",
    "weekday",
    "size_bucket",
]

EXIT_CATEGORY_MAP = {
    "acceptance": "acceptance_exit",
    "time_stop": "time_stop",
    "runner_target": "runner_target",
    "target": "target",
    "breakeven": "breakeven_after_partial",
    "stop": "stop_loss",
    "partial_exit": "partial_exit",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Research cross-family intraday USDJPY feature/regime contributions.")
    parser.add_argument("--include-dow-hs", action="store_true")
    parser.add_argument("--output-root", default=str(SWEEP_ROOT))
    return parser.parse_args()


def ensure_dirs(output_root: Path) -> None:
    (output_root / "results").mkdir(parents=True, exist_ok=True)


def parse_timestamp(value: str) -> datetime | None:
    if not value:
        return None
    return datetime.strptime(value, TIMESTAMP_FORMAT)


def parse_float(value: Any) -> float:
    if value in (None, ""):
        return 0.0
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def parse_int(value: Any) -> int:
    if value in (None, ""):
        return -1
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return -1


def parse_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    text = str(value or "").strip().lower()
    return text in {"1", "true", "yes"}


def safe_div(numerator: float, denominator: float) -> float:
    if denominator == 0.0:
        return 0.0
    return numerator / denominator


def clean_label(value: Any) -> str:
    text = str(value or "").strip()
    return text if text else "na"


def normalize_trigger(raw_value: str) -> str:
    value = clean_label(raw_value)
    mapping = {
        "exec_range_close_confirm": "range_close_confirm",
        "exec_range_retest_confirm": "range_retest_confirm",
        "exec_breakout_bar_continuation": "breakout_bar_continuation",
        "exec_reclaim_close_confirm": "reclaim_close_confirm",
        "exec_retest_failure": "retest_failure",
        "exec_recent_swing_breakdown": "recent_swing_breakdown",
        "exec_invalidation_close_break": "invalidation_close_break",
        "exec_retest_reject": "retest_reject",
        "exec_recent_swing_break": "recent_swing_break",
        "exec_recent_swing_breakout": "recent_swing_breakout",
        "range_close_confirm": "range_close_confirm",
        "range_retest_confirm": "range_retest_confirm",
        "breakout_bar_continuation": "breakout_bar_continuation",
        "reclaim_close_confirm": "reclaim_close_confirm",
        "retest_failure": "retest_failure",
        "recent_swing_breakdown": "recent_swing_breakdown",
        "invalidation_close_break": "invalidation_close_break",
        "retest_reject": "retest_reject",
        "neck_close_confirm": "neck_close_confirm",
        "neck_retest_failure": "neck_retest_failure",
        "recent_swing_break": "recent_swing_break",
    }
    return mapping.get(value, value.replace("exec_", ""))


def classify_exit_reason(reason: str) -> str:
    value = clean_label(reason)
    lower = value.lower()
    if "acceptance" in lower or "back_inside_box" in lower or "back_above" in lower or "back_below" in lower:
        return EXIT_CATEGORY_MAP["acceptance"]
    if "time_stop" in lower:
        return EXIT_CATEGORY_MAP["time_stop"]
    if "runner_target" in lower:
        return EXIT_CATEGORY_MAP["runner_target"]
    if lower == "target":
        return EXIT_CATEGORY_MAP["target"]
    if "breakeven" in lower:
        return EXIT_CATEGORY_MAP["breakeven"]
    if "stop" in lower:
        return EXIT_CATEGORY_MAP["stop"]
    if "partial_exit" in lower:
        return EXIT_CATEGORY_MAP["partial_exit"]
    return "other"


def infer_entry_session_bucket(entry_time: datetime | None) -> str:
    if entry_time is None:
        return "na"
    minutes = entry_time.hour * 60 + entry_time.minute
    if 0 <= minutes < 420:
        return "tokyo"
    if 420 <= minutes < 480:
        return "tokyo_to_london"
    if 480 <= minutes < 600:
        return "london_open"
    if 600 <= minutes < 780:
        return "london_mid"
    if 780 <= minutes < 960:
        return "ny_overlap"
    if 960 <= minutes < 1320:
        return "ny_late"
    return "other"


def infer_london_timing_bucket(minutes_from_open: float) -> str:
    if math.isnan(minutes_from_open):
        return "na"
    if minutes_from_open < 0:
        return "pre_london"
    if minutes_from_open < 30:
        return "0_30m"
    if minutes_from_open < 60:
        return "30_60m"
    return "60m_plus"


def infer_weekday(entry_time: datetime | None, weekday_label: str) -> str:
    existing = clean_label(weekday_label)
    if existing != "na":
        return existing
    if entry_time is None:
        return "na"
    return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][entry_time.weekday()]


def classify_source(path: Path, include_dow_hs: bool) -> dict[str, Any] | None:
    name = path.name
    match = SESSION_BOX_PATTERN.match(name)
    if match:
        trigger_label = {
            "close": "range_close_confirm",
            "retest": "range_retest_confirm",
            "cont": "breakout_bar_continuation",
        }[match.group("trigger")]
        return {
            "family": "session_box",
            "family_label": "Tokyo-London Session Box",
            "entry_archetype": "breakout",
            "window": match.group("window"),
            "pair_key": match.group("pair"),
            "trigger_key": trigger_label,
            "level_key": "na",
            "source_slug": name.removesuffix(".csv"),
        }

    match = N_WAVE_PATTERN.match(name)
    if match:
        trigger_label = {
            "close": "invalidation_close_break",
            "retest": "retest_reject",
            "swing": "recent_swing_breakdown",
        }[match.group("trigger")]
        return {
            "family": "n_wave",
            "family_label": "N-Wave Third-Leg",
            "entry_archetype": "continuation",
            "window": match.group("window"),
            "pair_key": match.group("pair"),
            "trigger_key": trigger_label,
            "level_key": "core",
            "source_slug": name.removesuffix(".csv"),
        }

    match = EXTERNAL_SWEEP_PATTERN.match(name)
    if match:
        level_label = {
            "ctx": "context_prior_swing",
            "m30": "m30_prior_swing",
            "pday": "previous_day_extreme",
        }[match.group("level")]
        trigger_label = {
            "reclaim": "reclaim_close_confirm",
            "retest": "retest_failure",
            "swing": "recent_swing_breakdown",
        }[match.group("trigger")]
        return {
            "family": "external_sweep",
            "family_label": "External Liquidity Sweep",
            "entry_archetype": "reversal",
            "window": match.group("window"),
            "pair_key": match.group("pair"),
            "trigger_key": trigger_label,
            "level_key": level_label,
            "source_slug": name.removesuffix(".csv"),
        }

    match = LOCAL_SWEEP_PATTERN.match(name)
    if match:
        return {
            "family": "local_sweep",
            "family_label": "Local Liquidity Sweep",
            "entry_archetype": "reversal",
            "window": match.group("window"),
            "pair_key": match.group("pair"),
            "trigger_key": match.group("trigger"),
            "level_key": "local",
            "source_slug": name.removesuffix(".csv"),
        }

    if include_dow_hs:
        match = DOWN_HS_PATTERN.match(name)
        if match:
            return {
                "family": "dow_hs",
                "family_label": "Dow HS",
                "entry_archetype": "reversal",
                "window": match.group("window"),
                "pair_key": match.group("pair"),
                "trigger_key": match.group("trigger"),
                "level_key": "neckline",
                "source_slug": name.removesuffix(".csv"),
            }

    return None


def initialize_trade(meta: dict[str, Any], trade_key: str, row: dict[str, str]) -> dict[str, Any]:
    return {
        "trade_key": trade_key,
        "source_slug": meta["source_slug"],
        "family": meta["family"],
        "family_label": meta["family_label"],
        "entry_archetype": meta["entry_archetype"],
        "window": meta["window"],
        "pair_key": meta["pair_key"],
        "trigger_key_from_file": meta["trigger_key"],
        "level_key": meta["level_key"],
        "position_id": clean_label(row.get("position_id")),
        "entry_time": None,
        "exit_time": None,
        "side": clean_label(row.get("side")),
        "session_type": clean_label(row.get("session_type")),
        "breakout_side": clean_label(row.get("breakout_side")),
        "breakout_type": clean_label(row.get("breakout_type")),
        "trigger_type": normalize_trigger(row.get("trigger_type") or row.get("execution_trigger") or meta["trigger_key"]),
        "context_phase": clean_label(row.get("context_phase")),
        "subtype": "na",
        "invalidation_line_type": "na",
        "prev_day_alignment_type": clean_label(row.get("prev_day_alignment_type")),
        "m30_swing_alignment_type": clean_label(row.get("m30_swing_alignment_type")),
        "weekday": clean_label(row.get("weekday")),
        "size_pips": 0.0,
        "size_atr_ratio": 0.0,
        "entry_distance_pips": 0.0,
        "entry_distance_atr": math.nan,
        "london_minutes_from_open": math.nan,
        "london_timing_bucket": "na",
        "planned_risk_amount": 0.0,
        "net_profit": 0.0,
        "partial_profit": 0.0,
        "final_profit": 0.0,
        "trade_r": math.nan,
        "partial_hit": False,
        "be_move": False,
        "runner_target_enabled": False,
        "runner_target_hit": False,
        "runner_stop_at_breakeven": False,
        "bars_to_partial": -1,
        "bars_to_final": -1,
        "bars_to_time_stop": -1,
        "mfe_pips": 0.0,
        "mae_pips": 0.0,
        "max_unrealized_r": 0.0,
        "min_unrealized_r": 0.0,
        "accepted_outside_box_bars": -1,
        "failed_back_inside_box_bars": -1,
        "mfe_before_acceptance_exit": 0.0,
        "mae_before_acceptance_exit": 0.0,
        "did_time_stop_after_partial": False,
        "did_runner_hit_before_time_stop": False,
        "final_reason": "na",
        "final_outcome": "na",
        "final_exit_category": "na",
        "has_exit": False,
    }


def update_trade_from_row(trade: dict[str, Any], row: dict[str, str], event_type: str) -> None:
    timestamp = parse_timestamp(row.get("timestamp", ""))
    if event_type == "entry":
        trade["entry_time"] = timestamp
        trade["side"] = clean_label(row.get("side")) if clean_label(row.get("side")) != "na" else trade["side"]
        trade["session_type"] = clean_label(row.get("session_type")) if clean_label(row.get("session_type")) != "na" else trade["session_type"]
        trade["breakout_side"] = clean_label(row.get("breakout_side")) if clean_label(row.get("breakout_side")) != "na" else trade["breakout_side"]
        trade["breakout_type"] = clean_label(row.get("breakout_type")) if clean_label(row.get("breakout_type")) != "na" else trade["breakout_type"]
        trade["trigger_type"] = normalize_trigger(row.get("trigger_type") or row.get("execution_trigger") or trade["trigger_type"])
        trade["context_phase"] = clean_label(row.get("context_phase")) if clean_label(row.get("context_phase")) != "na" else trade["context_phase"]
        trade["weekday"] = clean_label(row.get("weekday")) if clean_label(row.get("weekday")) != "na" else trade["weekday"]
        trade["prev_day_alignment_type"] = clean_label(row.get("prev_day_alignment_type")) if clean_label(row.get("prev_day_alignment_type")) != "na" else trade["prev_day_alignment_type"]
        trade["m30_swing_alignment_type"] = clean_label(row.get("m30_swing_alignment_type")) if clean_label(row.get("m30_swing_alignment_type")) != "na" else trade["m30_swing_alignment_type"]
        trade["runner_target_enabled"] = parse_bool(row.get("runner_target_enabled")) or trade["runner_target_enabled"]

        if trade["family"] == "session_box":
            trade["subtype"] = clean_label(row.get("breakout_type"))
            trade["invalidation_line_type"] = "box_opposite_side"
            trade["size_pips"] = parse_float(row.get("box_width_pips"))
            trade["size_atr_ratio"] = parse_float(row.get("box_width_atr_ratio"))
            trade["entry_distance_pips"] = parse_float(row.get("breakout_close_distance_pips"))
            raw_distance_atr = row.get("breakout_close_distance_atr")
            trade["entry_distance_atr"] = parse_float(raw_distance_atr) if raw_distance_atr not in (None, "") else math.nan
            raw_minutes = row.get("london_minutes_from_open")
            if raw_minutes not in (None, ""):
                trade["london_minutes_from_open"] = parse_float(raw_minutes)
            trade["accepted_outside_box_bars"] = parse_int(row.get("accepted_outside_box_bars"))
            trade["failed_back_inside_box_bars"] = parse_int(row.get("failed_back_inside_box_bars"))
            trade["mfe_before_acceptance_exit"] = parse_float(row.get("mfe_before_acceptance_exit"))
            trade["mae_before_acceptance_exit"] = parse_float(row.get("mae_before_acceptance_exit"))
            trade["did_time_stop_after_partial"] = parse_bool(row.get("did_time_stop_after_partial"))
            trade["did_runner_hit_before_time_stop"] = parse_bool(row.get("did_runner_hit_before_time_stop"))
        elif trade["family"] == "n_wave":
            trade["subtype"] = clean_label(row.get("wave_subtype"))
            trade["invalidation_line_type"] = clean_label(row.get("invalidation_line_type"))
            trade["size_pips"] = parse_float(row.get("structure_height_pips"))
            pattern_atr_pips = parse_float(row.get("pattern_atr_pips"))
            trade["size_atr_ratio"] = safe_div(trade["size_pips"], pattern_atr_pips)
            trade["entry_distance_pips"] = abs(parse_float(row.get("setup_to_entry_pips")))
            trade["entry_distance_atr"] = safe_div(trade["entry_distance_pips"], pattern_atr_pips) if pattern_atr_pips > 0.0 else math.nan
        elif trade["family"] in {"local_sweep", "external_sweep", "dow_hs"}:
            if trade["family"] == "external_sweep":
                trade["subtype"] = clean_label(row.get("external_level_type"))
                if trade["subtype"] == "previous_day_extreme":
                    trade["prev_day_alignment_type"] = "external_previous_day_extreme"
                elif trade["subtype"] == "m30_prior_swing":
                    trade["m30_swing_alignment_type"] = "external_m30_prior_swing"
            elif trade["family"] == "local_sweep":
                trade["subtype"] = clean_label(row.get("pattern_label"))
            else:
                trade["subtype"] = clean_label(row.get("pattern_label"))
            trade["invalidation_line_type"] = "failed_sweep_anchor" if trade["family"] != "dow_hs" else "neckline_cluster"
            trade["size_pips"] = parse_float(row.get("structure_height_pips"))
            pattern_atr_pips = parse_float(row.get("pattern_atr_pips"))
            trade["size_atr_ratio"] = safe_div(trade["size_pips"], pattern_atr_pips)
            trade["entry_distance_pips"] = abs(parse_float(row.get("setup_to_entry_pips")))
            trade["entry_distance_atr"] = safe_div(trade["entry_distance_pips"], pattern_atr_pips) if pattern_atr_pips > 0.0 else math.nan

        if math.isnan(trade["london_minutes_from_open"]) and timestamp is not None:
            trade["london_minutes_from_open"] = float((timestamp.hour * 60 + timestamp.minute) - 420)
        trade["london_timing_bucket"] = infer_london_timing_bucket(trade["london_minutes_from_open"])

    planned_risk = parse_float(row.get("planned_risk_amount"))
    if planned_risk > 0.0:
        trade["planned_risk_amount"] = planned_risk
    trade["mfe_pips"] = max(trade["mfe_pips"], parse_float(row.get("mfe_pips")))
    trade["mae_pips"] = max(trade["mae_pips"], parse_float(row.get("mae_pips")))
    trade["max_unrealized_r"] = max(trade["max_unrealized_r"], parse_float(row.get("max_unrealized_r")))
    trade["min_unrealized_r"] = min(trade["min_unrealized_r"], parse_float(row.get("min_unrealized_r")))

    if event_type == "partial_exit":
        profit = parse_float(row.get("net_profit"))
        trade["net_profit"] += profit
        trade["partial_profit"] += profit
        trade["partial_hit"] = True
        trade["be_move"] = parse_bool(row.get("be_move")) or trade["be_move"]
        bars_to_partial = parse_int(row.get("bars_to_partial"))
        if bars_to_partial >= 0:
            trade["bars_to_partial"] = bars_to_partial
        return

    if event_type == "exit":
        profit = parse_float(row.get("net_profit"))
        trade["net_profit"] += profit
        trade["final_profit"] += profit
        trade["exit_time"] = timestamp
        trade["be_move"] = parse_bool(row.get("be_move")) or trade["be_move"]
        trade["partial_hit"] = trade["partial_hit"] or parse_bool(row.get("partial_hit"))
        trade["runner_target_hit"] = parse_bool(row.get("runner_target_hit"))
        trade["runner_stop_at_breakeven"] = parse_bool(row.get("runner_stop_at_breakeven"))
        trade["final_reason"] = clean_label(row.get("reason"))
        trade["final_outcome"] = clean_label(row.get("outcome"))
        trade["final_exit_category"] = classify_exit_reason(trade["final_reason"])
        bars_to_final = parse_int(row.get("bars_to_final"))
        bars_to_time_stop = parse_int(row.get("bars_to_time_stop"))
        if bars_to_final >= 0:
            trade["bars_to_final"] = bars_to_final
        if bars_to_time_stop >= 0:
            trade["bars_to_time_stop"] = bars_to_time_stop
        if trade["family"] == "session_box":
            trade["accepted_outside_box_bars"] = max(trade["accepted_outside_box_bars"], parse_int(row.get("accepted_outside_box_bars")))
            trade["failed_back_inside_box_bars"] = max(trade["failed_back_inside_box_bars"], parse_int(row.get("failed_back_inside_box_bars")))
            trade["mfe_before_acceptance_exit"] = max(trade["mfe_before_acceptance_exit"], parse_float(row.get("mfe_before_acceptance_exit")))
            trade["mae_before_acceptance_exit"] = max(trade["mae_before_acceptance_exit"], parse_float(row.get("mae_before_acceptance_exit")))
            trade["did_time_stop_after_partial"] = parse_bool(row.get("did_time_stop_after_partial")) or trade["did_time_stop_after_partial"]
            trade["did_runner_hit_before_time_stop"] = parse_bool(row.get("did_runner_hit_before_time_stop")) or trade["did_runner_hit_before_time_stop"]
        trade["has_exit"] = True


def load_trade_records(path: Path, meta: dict[str, Any]) -> list[dict[str, Any]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle, delimiter=";")
        rows = [dict(row) for row in reader]

    campaigns: dict[str, dict[str, Any]] = {}
    active_trade_key: str | None = None
    trade_sequence = 0

    for row in rows:
        event_type = clean_label(row.get("event_type"))
        position_id = clean_label(row.get("position_id"))
        if event_type == "entry":
            trade_sequence += 1
            active_trade_key = f"campaign_{trade_sequence}"
        trade_key = active_trade_key or f"orphan_{position_id}_{trade_sequence}"
        trade = campaigns.setdefault(trade_key, initialize_trade(meta, trade_key, row))
        update_trade_from_row(trade, row, event_type)
        if event_type == "exit":
            active_trade_key = None

    closed_trades: list[dict[str, Any]] = []
    for trade in campaigns.values():
        if not trade["has_exit"]:
            continue
        entry_time = trade["entry_time"]
        trade["weekday"] = infer_weekday(entry_time, trade["weekday"])
        trade["entry_session_bucket"] = infer_entry_session_bucket(entry_time)
        trade["london_timing_bucket"] = infer_london_timing_bucket(trade["london_minutes_from_open"])
        if trade["planned_risk_amount"] > 0.0:
            trade["trade_r"] = trade["net_profit"] / trade["planned_risk_amount"]
        else:
            trade["trade_r"] = math.nan
        if trade["final_exit_category"] == "time_stop" and trade["partial_hit"]:
            trade["did_time_stop_after_partial"] = True
        if trade["runner_target_hit"]:
            trade["did_runner_hit_before_time_stop"] = True
        trade["acceptance_exit"] = trade["final_exit_category"] == "acceptance_exit"
        trade["time_stop_exit"] = trade["final_exit_category"] == "time_stop"
        trade["runner_hit"] = trade["runner_target_hit"] or trade["final_exit_category"] == "runner_target"
        closed_trades.append(trade)

    return closed_trades


def build_trade_frame(include_dow_hs: bool) -> pd.DataFrame:
    trade_rows: list[dict[str, Any]] = []
    for path in sorted(COMMON_FILES_ROOT.glob("mt5_company_*.csv")):
        meta = classify_source(path, include_dow_hs=include_dow_hs)
        if meta is None:
            continue
        trade_rows.extend(load_trade_records(path, meta))

    frame = pd.DataFrame(trade_rows)
    if frame.empty:
        raise RuntimeError("No trade rows were loaded from telemetry CSVs.")

    frame["entry_time"] = pd.to_datetime(frame["entry_time"])
    frame["exit_time"] = pd.to_datetime(frame["exit_time"])
    frame["source_type"] = frame["family"]
    return frame


def apply_train_quantile_buckets(frame: pd.DataFrame) -> pd.DataFrame:
    result = frame.copy()
    result["size_bucket"] = "na"
    result["entry_strength_bucket"] = "na"

    for family, family_frame in result.groupby("family"):
        train = family_frame[(family_frame["window"] == "train") & family_frame["size_atr_ratio"].notna() & (family_frame["size_atr_ratio"] > 0.0)]
        if not train.empty:
            q25 = train["size_atr_ratio"].quantile(0.25)
            q75 = train["size_atr_ratio"].quantile(0.75)
            family_mask = result["family"] == family
            result.loc[family_mask & (result["size_atr_ratio"] <= q25), "size_bucket"] = "narrow"
            result.loc[family_mask & (result["size_atr_ratio"] > q25) & (result["size_atr_ratio"] <= q75), "size_bucket"] = "normal"
            result.loc[family_mask & (result["size_atr_ratio"] > q75), "size_bucket"] = "wide"

        train_strength = family_frame[
            (family_frame["window"] == "train")
            & family_frame["entry_distance_atr"].notna()
            & (family_frame["entry_distance_atr"] >= 0.0)
        ]
        if not train_strength.empty:
            s25 = train_strength["entry_distance_atr"].quantile(0.25)
            s75 = train_strength["entry_distance_atr"].quantile(0.75)
            family_mask = result["family"] == family
            result.loc[family_mask & (result["entry_distance_atr"] <= s25), "entry_strength_bucket"] = "weak"
            result.loc[
                family_mask & (result["entry_distance_atr"] > s25) & (result["entry_distance_atr"] <= s75),
                "entry_strength_bucket",
            ] = "medium"
            result.loc[family_mask & (result["entry_distance_atr"] > s75), "entry_strength_bucket"] = "strong"

    for column in FEATURE_COLUMNS:
        result[column] = result[column].fillna("na")
        result[column] = result[column].map(clean_label)

    return result


def summarize_subset(frame: pd.DataFrame) -> dict[str, Any]:
    trades = int(len(frame))
    if trades == 0:
        return {
            "trades": 0,
            "pf": 0.0,
            "net": 0.0,
            "expected_payoff": 0.0,
            "avg_r": 0.0,
            "win_rate": 0.0,
            "average_win": 0.0,
            "average_loss": 0.0,
            "acceptance_exit_rate": 0.0,
            "time_stop_rate": 0.0,
            "runner_hit_rate": 0.0,
            "be_rate": 0.0,
            "partial_hit_rate": 0.0,
            "time_stop_after_partial_rate": 0.0,
            "mfe_p25": 0.0,
            "mfe_p50": 0.0,
            "mfe_p75": 0.0,
            "mae_p25": 0.0,
            "mae_p50": 0.0,
            "mae_p75": 0.0,
        }

    profits = frame["net_profit"]
    gross_profit = profits[profits > 0.0].sum()
    gross_loss = abs(profits[profits < 0.0].sum())
    wins = profits[profits > 0.0]
    losses = profits[profits < 0.0]
    trade_r = frame["trade_r"].dropna()
    pf = safe_div(float(gross_profit), float(gross_loss)) if gross_loss > 0.0 else 0.0

    return {
        "trades": trades,
        "pf": round(pf, 4),
        "net": round(float(profits.sum()), 4),
        "expected_payoff": round(float(profits.mean()), 4),
        "avg_r": round(float(trade_r.mean()), 4) if not trade_r.empty else 0.0,
        "win_rate": round(float((profits > 0.0).mean()) * 100.0, 2),
        "average_win": round(float(wins.mean()), 4) if not wins.empty else 0.0,
        "average_loss": round(float(losses.mean()), 4) if not losses.empty else 0.0,
        "acceptance_exit_rate": round(float(frame["acceptance_exit"].mean()) * 100.0, 2),
        "time_stop_rate": round(float(frame["time_stop_exit"].mean()) * 100.0, 2),
        "runner_hit_rate": round(float(frame["runner_hit"].mean()) * 100.0, 2),
        "be_rate": round(float(frame["be_move"].mean()) * 100.0, 2),
        "partial_hit_rate": round(float(frame["partial_hit"].mean()) * 100.0, 2),
        "time_stop_after_partial_rate": round(float(frame["did_time_stop_after_partial"].mean()) * 100.0, 2),
        "mfe_p25": round(float(frame["mfe_pips"].quantile(0.25)), 4),
        "mfe_p50": round(float(frame["mfe_pips"].quantile(0.50)), 4),
        "mfe_p75": round(float(frame["mfe_pips"].quantile(0.75)), 4),
        "mae_p25": round(float(frame["mae_pips"].quantile(0.25)), 4),
        "mae_p50": round(float(frame["mae_pips"].quantile(0.50)), 4),
        "mae_p75": round(float(frame["mae_pips"].quantile(0.75)), 4),
    }


def aggregate_by(frame: pd.DataFrame, keys: list[str]) -> pd.DataFrame:
    rows: list[dict[str, Any]] = []
    for group_values, group_frame in frame.groupby(keys, dropna=False):
        if not isinstance(group_values, tuple):
            group_values = (group_values,)
        record = {key: value for key, value in zip(keys, group_values)}
        record.update(summarize_subset(group_frame))
        rows.append(record)
    return pd.DataFrame(rows)


def build_family_aggregates(frame: pd.DataFrame) -> pd.DataFrame:
    return aggregate_by(frame, ["family", "window"]).sort_values(["family", "window"])


def feature_is_informative(frame: pd.DataFrame, family: str, feature: str) -> bool:
    family_frame = frame[frame["family"] == family]
    values = {clean_label(value) for value in family_frame[feature].tolist() if clean_label(value) != "na"}
    return len(values) >= 2


def build_univariate_table(frame: pd.DataFrame) -> pd.DataFrame:
    rows: list[pd.DataFrame] = []
    for family in sorted(frame["family"].unique()):
        for feature in FEATURE_COLUMNS:
            if not feature_is_informative(frame, family, feature):
                continue
            subset = frame[frame["family"] == family]
            summary = aggregate_by(subset, ["family", "window", feature])
            summary["feature_name"] = feature
            summary["feature_value"] = summary[feature].map(clean_label)
            summary = summary.drop(columns=[feature])
            rows.append(summary)
    if not rows:
        return pd.DataFrame()
    result = pd.concat(rows, ignore_index=True)
    return result[
        [
            "family",
            "window",
            "feature_name",
            "feature_value",
            "trades",
            "pf",
            "net",
            "expected_payoff",
            "avg_r",
            "win_rate",
            "average_win",
            "average_loss",
            "acceptance_exit_rate",
            "time_stop_rate",
            "runner_hit_rate",
            "be_rate",
            "partial_hit_rate",
            "time_stop_after_partial_rate",
            "mfe_p25",
            "mfe_p50",
            "mfe_p75",
            "mae_p25",
            "mae_p50",
            "mae_p75",
        ]
    ]


def bivariate_is_informative(frame: pd.DataFrame, family: str, feature_pair: tuple[str, str]) -> bool:
    left, right = feature_pair
    family_frame = frame[frame["family"] == family]
    left_values = {clean_label(value) for value in family_frame[left].tolist() if clean_label(value) != "na"}
    right_values = {clean_label(value) for value in family_frame[right].tolist() if clean_label(value) != "na"}
    return len(left_values) >= 2 and len(right_values) >= 2


def build_bivariate_table(frame: pd.DataFrame) -> pd.DataFrame:
    rows: list[pd.DataFrame] = []
    for family in sorted(frame["family"].unique()):
        subset = frame[frame["family"] == family]
        for left, right in BIVARIATE_FEATURES:
            if not bivariate_is_informative(frame, family, (left, right)):
                continue
            summary = aggregate_by(subset, ["family", "window", left, right])
            summary["feature_name"] = f"{left} x {right}"
            summary["feature_value"] = summary[left].map(clean_label) + " | " + summary[right].map(clean_label)
            summary = summary.drop(columns=[left, right])
            rows.append(summary)
    if not rows:
        return pd.DataFrame()
    result = pd.concat(rows, ignore_index=True)
    return result[
        [
            "family",
            "window",
            "feature_name",
            "feature_value",
            "trades",
            "pf",
            "net",
            "expected_payoff",
            "avg_r",
            "win_rate",
            "average_win",
            "average_loss",
            "acceptance_exit_rate",
            "time_stop_rate",
            "runner_hit_rate",
            "be_rate",
            "partial_hit_rate",
            "time_stop_after_partial_rate",
            "mfe_p25",
            "mfe_p50",
            "mfe_p75",
            "mae_p25",
            "mae_p50",
            "mae_p75",
        ]
    ]


def build_repeatability_table(summary: pd.DataFrame) -> pd.DataFrame:
    if summary.empty:
        return pd.DataFrame()

    metrics = [
        "trades",
        "pf",
        "net",
        "expected_payoff",
        "avg_r",
        "win_rate",
        "average_win",
        "average_loss",
        "acceptance_exit_rate",
        "time_stop_rate",
        "runner_hit_rate",
        "be_rate",
        "partial_hit_rate",
        "time_stop_after_partial_rate",
        "mfe_p25",
        "mfe_p50",
        "mfe_p75",
        "mae_p25",
        "mae_p50",
        "mae_p75",
    ]
    pivot = summary.pivot_table(
        index=["family", "feature_name", "feature_value"],
        columns="window",
        values=metrics,
        aggfunc="first",
    )
    pivot.columns = [f"{window}_{metric}" for metric, window in pivot.columns]
    result = pivot.reset_index()
    result["oos_actual_same_direction_positive"] = (result.get("oos_net", 0.0) > 0.0) & (result.get("actual_net", 0.0) > 0.0)
    result["pf_repeat"] = (result.get("oos_pf", 0.0) >= 1.0) & (result.get("actual_pf", 0.0) >= 1.0)
    result["sparse_survivor"] = (result.get("oos_trades", 0) < MIN_OOS_TRADES) | (result.get("actual_trades", 0) < MIN_ACTUAL_TRADES)
    result["time_stop_reliant"] = (result.get("actual_time_stop_rate", 0.0) >= 35.0) & (result.get("actual_runner_hit_rate", 0.0) <= 5.0)
    result["acceptance_improved"] = result.get("actual_acceptance_exit_rate", 100.0) <= result.get("oos_acceptance_exit_rate", 100.0)
    sort_columns = ["pf_repeat", "oos_actual_same_direction_positive", "actual_pf", "oos_pf", "actual_trades"]
    ascending = [False, False, False, False, False]
    existing = [column for column in sort_columns if column in result.columns]
    ascending = ascending[: len(existing)]
    return result.sort_values(existing, ascending=ascending) if existing else result


def top_rows(frame: pd.DataFrame, limit: int) -> pd.DataFrame:
    if frame.empty:
        return frame
    return frame.head(limit).copy()


def rows_to_records(frame: pd.DataFrame, limit: int = 20) -> list[dict[str, Any]]:
    if frame.empty:
        return []
    return frame.head(limit).fillna("").to_dict(orient="records")


def markdown_cell(value: Any) -> str:
    if isinstance(value, float):
        return f"{value:.4f}"
    return str(value).replace("|", "\\|")


def append_table(lines: list[str], title: str, frame: pd.DataFrame, columns: list[str]) -> None:
    lines.append(f"## {title}")
    lines.append("")
    if frame.empty:
        lines.append("- no data")
        lines.append("")
        return

    header = "| " + " | ".join(columns) + " |"
    separator = "| " + " | ".join(["---"] * len(columns)) + " |"
    lines.append(header)
    lines.append(separator)
    for _, row in frame.iterrows():
        values = []
        for column in columns:
            values.append(markdown_cell(row.get(column, "")))
        lines.append("| " + " | ".join(values) + " |")
    lines.append("")


def build_markdown(
    trade_frame: pd.DataFrame,
    family_aggregates: pd.DataFrame,
    top_univariate: pd.DataFrame,
    top_bivariate: pd.DataFrame,
    bundle_candidates: pd.DataFrame,
    repeatable: pd.DataFrame,
    acceptance_dominant: pd.DataFrame,
    time_stop_reliant: pd.DataFrame,
    runner_friendly: pd.DataFrame,
) -> str:
    lines = [
        "# USDJPY Intraday Feature / Regime Research",
        "",
        f"- Generated: `{datetime.now().isoformat(timespec='seconds')}`",
        f"- Families: `{', '.join(sorted(trade_frame['family'].unique()))}`",
        f"- Closed trades: `{len(trade_frame)}`",
        "",
        "## Design Plan",
        "",
        "- target families:",
        "  - `session_box`",
        "  - `local_sweep`",
        "  - `external_sweep`",
        "  - `n_wave`",
        "- priority feature groups:",
        "  - time / session buckets",
        "  - previous-day / M30 alignment",
        "  - size / breakout-strength buckets",
        "  - trigger / subtype / invalidation line type",
        "  - acceptance / time-stop / runner behavior",
        "- method:",
        "  - trade-level telemetry reconstruction",
        "  - univariate feature tables",
        "  - bivariate feature tables",
        "  - OOS / actual repeatability checks",
        "  - no new EA family, no rescue filters, no ML",
        "",
    ]

    append_table(
        lines,
        "Family Aggregate",
        family_aggregates.sort_values(["family", "window"]),
        ["family", "window", "trades", "pf", "net", "expected_payoff", "avg_r", "acceptance_exit_rate", "time_stop_rate", "runner_hit_rate"],
    )
    append_table(
        lines,
        "Top Univariate Features",
        top_univariate,
        [
            "family",
            "feature_name",
            "feature_value",
            "oos_trades",
            "oos_pf",
            "oos_net",
            "actual_trades",
            "actual_pf",
            "actual_net",
            "actual_acceptance_exit_rate",
            "actual_time_stop_rate",
            "actual_runner_hit_rate",
            "sparse_survivor",
        ],
    )
    append_table(
        lines,
        "Top Bivariate Feature Bundles",
        top_bivariate,
        [
            "family",
            "feature_name",
            "feature_value",
            "oos_trades",
            "oos_pf",
            "oos_net",
            "actual_trades",
            "actual_pf",
            "actual_net",
            "actual_acceptance_exit_rate",
            "actual_time_stop_rate",
            "actual_runner_hit_rate",
            "sparse_survivor",
        ],
    )
    append_table(
        lines,
        "Repeatability Table",
        top_rows(repeatable, 20),
        [
            "family",
            "feature_name",
            "feature_value",
            "pf_repeat",
            "oos_actual_same_direction_positive",
            "oos_trades",
            "oos_pf",
            "actual_trades",
            "actual_pf",
            "actual_acceptance_exit_rate",
            "actual_time_stop_rate",
            "actual_runner_hit_rate",
            "sparse_survivor",
            "time_stop_reliant",
        ],
    )
    append_table(
        lines,
        "Feature Bundle Candidates",
        top_rows(bundle_candidates, 10),
        [
            "family",
            "feature_name",
            "feature_value",
            "oos_trades",
            "oos_pf",
            "oos_net",
            "actual_trades",
            "actual_pf",
            "actual_net",
            "actual_acceptance_exit_rate",
            "actual_time_stop_rate",
            "actual_runner_hit_rate",
        ],
    )
    append_table(
        lines,
        "Acceptance-Dominant Regimes",
        top_rows(acceptance_dominant, 20),
        [
            "family",
            "feature_name",
            "feature_value",
            "actual_trades",
            "actual_pf",
            "actual_net",
            "actual_acceptance_exit_rate",
            "actual_time_stop_rate",
            "actual_runner_hit_rate",
        ],
    )
    append_table(
        lines,
        "Time-Stop-Reliant Regimes",
        top_rows(time_stop_reliant, 20),
        [
            "family",
            "feature_name",
            "feature_value",
            "actual_trades",
            "actual_pf",
            "actual_net",
            "actual_time_stop_rate",
            "actual_time_stop_after_partial_rate",
            "actual_runner_hit_rate",
        ],
    )
    append_table(
        lines,
        "Runner-Friendly Regimes",
        top_rows(runner_friendly, 20),
        [
            "family",
            "feature_name",
            "feature_value",
            "actual_trades",
            "actual_pf",
            "actual_net",
            "actual_runner_hit_rate",
            "actual_time_stop_rate",
            "actual_acceptance_exit_rate",
        ],
    )
    return "\n".join(lines)


def build_review_text(
    trade_frame: pd.DataFrame,
    family_aggregates: pd.DataFrame,
    top_univariate: pd.DataFrame,
    top_bivariate: pd.DataFrame,
    bundle_candidates: pd.DataFrame,
    repeatable: pd.DataFrame,
    acceptance_dominant: pd.DataFrame,
    time_stop_reliant: pd.DataFrame,
    runner_friendly: pd.DataFrame,
) -> str:
    family_lines = []
    for family in sorted(trade_frame["family"].unique()):
        family_label = trade_frame.loc[trade_frame["family"] == family, "family_label"].iloc[0]
        oos_row = family_aggregates[(family_aggregates["family"] == family) & (family_aggregates["window"] == "oos")]
        actual_row = family_aggregates[(family_aggregates["family"] == family) & (family_aggregates["window"] == "actual")]
        if oos_row.empty or actual_row.empty:
            continue
        oos = oos_row.iloc[0]
        actual = actual_row.iloc[0]
        family_lines.append(
            f"- `{family_label}`: OOS `{int(oos['trades'])} trades / PF {oos['pf']:.2f} / net {oos['net']:.2f}`, "
            f"actual `{int(actual['trades'])} / PF {actual['pf']:.2f} / net {actual['net']:.2f}`"
        )

    lines = [
        "# USDJPY Intraday Feature / Regime Research Review",
        "",
        f"Date: {datetime.now().date().isoformat()}",
        "Verdict: `hard-close unless a repeatable feature bundle survives`",
        "",
        "## Scope",
        "",
        "- primary families:",
        "  - `Tokyo-London Session Box`",
        "  - `Local Liquidity Sweep / Failed Acceptance`",
        "  - `External Liquidity Sweep / Failed Acceptance`",
        "  - `N-Wave Third-Leg`",
        "- data windows:",
        "  - `train 2025-04-01 -> 2025-12-31`",
        "  - `oos 2026-01-01 -> 2026-04-01`",
        "  - `actual 2024-11-26 -> 2026-04-01`",
        "",
        "## Family Aggregate Read",
        "",
        *family_lines,
        "",
        "## Slightly Better Univariate Features",
        "",
    ]

    if top_univariate.empty:
        lines.append("- none survived even as directional positives.")
    else:
        for _, row in top_univariate.head(10).iterrows():
            lines.append(
                f"- `{row['family']} | {row['feature_name']}={row['feature_value']}`: "
                f"OOS `{int(row['oos_trades'])} / PF {row['oos_pf']:.2f} / net {row['oos_net']:.2f}`, "
                f"actual `{int(row['actual_trades'])} / PF {row['actual_pf']:.2f} / net {row['actual_net']:.2f}`, "
                f"acceptance `{row['actual_acceptance_exit_rate']:.2f}%`, "
                f"time-stop `{row['actual_time_stop_rate']:.2f}%`, "
                f"runner `{row['actual_runner_hit_rate']:.2f}%`."
            )

    lines.extend(["", "## Slightly Better Bivariate Bundles", ""])
    if top_bivariate.empty:
        lines.append("- none survived even as directional positives.")
    else:
        for _, row in top_bivariate.head(10).iterrows():
            lines.append(
                f"- `{row['family']} | {row['feature_name']}={row['feature_value']}`: "
                f"OOS `{int(row['oos_trades'])} / PF {row['oos_pf']:.2f} / net {row['oos_net']:.2f}`, "
                f"actual `{int(row['actual_trades'])} / PF {row['actual_pf']:.2f} / net {row['actual_net']:.2f}`, "
                f"acceptance `{row['actual_acceptance_exit_rate']:.2f}%`, "
                f"time-stop `{row['actual_time_stop_rate']:.2f}%`, "
                f"runner `{row['actual_runner_hit_rate']:.2f}%`."
            )

    lines.extend(["", "## Repeatability", ""])
    if bundle_candidates.empty:
        lines.append("- no bivariate feature bundle passed `PF >= 1 in OOS and actual`, minimum trade thresholds, and non-rescue dependence together.")
    else:
        for _, row in bundle_candidates.head(10).iterrows():
            lines.append(
                f"- `{row['family']} | {row['feature_name']}={row['feature_value']}` repeated with "
                f"OOS `{int(row['oos_trades'])} / PF {row['oos_pf']:.2f}` and actual `{int(row['actual_trades'])} / PF {row['actual_pf']:.2f}`."
            )

    lines.extend(["", "## Weak Positive Hints", ""])
    univariate_repeat = repeatable[
        ~repeatable["feature_name"].str.contains(r" x ", regex=True)
        & repeatable["pf_repeat"]
        & ~repeatable["sparse_survivor"]
    ]
    if univariate_repeat.empty:
        lines.append("- no univariate feature repeated cleanly enough to treat as a design lead.")
    else:
        for _, row in univariate_repeat.head(8).iterrows():
            lines.append(
                f"- `{row['family']} | {row['feature_name']}={row['feature_value']}`: "
                f"OOS `{int(row['oos_trades'])} / PF {row['oos_pf']:.2f} / net {row['oos_net']:.2f}`, "
                f"actual `{int(row['actual_trades'])} / PF {row['actual_pf']:.2f} / net {row['actual_net']:.2f}`, "
                f"acceptance `{row['actual_acceptance_exit_rate']:.2f}%`, "
                f"time-stop `{row['actual_time_stop_rate']:.2f}%`, "
                f"runner `{row['actual_runner_hit_rate']:.2f}%`."
            )

    lines.extend(["", "## Acceptance-Dominant Regimes", ""])
    for _, row in top_rows(acceptance_dominant, 8).iterrows():
        lines.append(
            f"- `{row['family']} | {row['feature_name']}={row['feature_value']}`: "
            f"actual acceptance `{row['actual_acceptance_exit_rate']:.2f}%` on `{int(row['actual_trades'])}` trades, "
            f"PF `{row['actual_pf']:.2f}`."
        )

    lines.extend(["", "## Time-Stop-Reliant Regimes", ""])
    for _, row in top_rows(time_stop_reliant, 8).iterrows():
        lines.append(
            f"- `{row['family']} | {row['feature_name']}={row['feature_value']}`: "
            f"actual time-stop `{row['actual_time_stop_rate']:.2f}%`, "
            f"time-stop-after-partial `{row['actual_time_stop_after_partial_rate']:.2f}%`, "
            f"runner `{row['actual_runner_hit_rate']:.2f}%`."
        )

    lines.extend(["", "## Runner-Friendly Regimes", ""])
    if runner_friendly.empty:
        lines.append("- no regime produced meaningful runner participation with enough actual trades.")
    else:
        for _, row in top_rows(runner_friendly, 8).iterrows():
            lines.append(
                f"- `{row['family']} | {row['feature_name']}={row['feature_value']}`: "
                f"actual runner `{row['actual_runner_hit_rate']:.2f}%`, "
                f"time-stop `{row['actual_time_stop_rate']:.2f}%`, "
                f"PF `{row['actual_pf']:.2f}`."
            )

    lines.extend(["", "## Decision", ""])
    if bundle_candidates.empty:
        lines.append("- `Hard-close` if the goal is a standalone USDJPY intraday family.")
        lines.append("- reason:")
        lines.append("  - no bivariate feature bundle repeated in OOS and actual with enough trades")
        lines.append("  - the only non-sparse repeat was a session-box univariate timing hint, not a reusable bundle")
        lines.append("  - positive-looking slices were still sparse, acceptance-heavy, or time-stop driven")
        lines.append("  - runner participation stayed weak, so the edge did not look like durable continuation")
    else:
        lines.append("- `Continue research-only` because at least one feature bundle repeated without obvious rescue dependence.")

    lines.append("")
    return "\n".join(lines)


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def main() -> None:
    args = parse_args()
    output_root = Path(args.output_root).resolve()
    ensure_dirs(output_root)

    trade_frame = build_trade_frame(include_dow_hs=args.include_dow_hs)
    trade_frame = apply_train_quantile_buckets(trade_frame)

    family_aggregates = build_family_aggregates(trade_frame)
    univariate_table = build_univariate_table(trade_frame)
    bivariate_table = build_bivariate_table(trade_frame)
    univariate_repeatability = build_repeatability_table(univariate_table)
    bivariate_repeatability = build_repeatability_table(bivariate_table)
    combined_repeatability = pd.concat([univariate_repeatability, bivariate_repeatability], ignore_index=True)
    combined_repeatability = combined_repeatability.sort_values(
        ["pf_repeat", "oos_actual_same_direction_positive", "actual_pf", "oos_pf", "actual_trades"],
        ascending=[False, False, False, False, False],
    )

    top_univariate = top_rows(
        univariate_repeatability[
            (univariate_repeatability.get("oos_trades", 0) >= MIN_OOS_TRADES)
            & (univariate_repeatability.get("actual_trades", 0) >= MIN_ACTUAL_TRADES)
        ],
        20,
    )
    top_bivariate = top_rows(
        bivariate_repeatability[
            (bivariate_repeatability.get("oos_trades", 0) >= MIN_OOS_TRADES)
            & (bivariate_repeatability.get("actual_trades", 0) >= MIN_ACTUAL_TRADES)
        ],
        20,
    )
    bundle_candidates = top_rows(
        bivariate_repeatability[
            bivariate_repeatability.get("pf_repeat", False)
            & ~bivariate_repeatability.get("sparse_survivor", True)
            & ~bivariate_repeatability.get("time_stop_reliant", True)
        ],
        10,
    )

    acceptance_dominant = combined_repeatability[
        combined_repeatability.get("actual_trades", 0) >= MIN_ACTUAL_TRADES
    ].sort_values(["actual_acceptance_exit_rate", "actual_trades"], ascending=[False, False])

    time_stop_reliant = combined_repeatability[
        (combined_repeatability.get("actual_trades", 0) >= MIN_ACTUAL_TRADES)
        & (combined_repeatability.get("actual_time_stop_rate", 0.0) >= 25.0)
    ].sort_values(["actual_time_stop_rate", "actual_trades"], ascending=[False, False])

    runner_friendly = combined_repeatability[
        (combined_repeatability.get("actual_trades", 0) >= MIN_ACTUAL_TRADES)
        & (combined_repeatability.get("actual_runner_hit_rate", 0.0) > 0.0)
    ].sort_values(["actual_runner_hit_rate", "actual_pf"], ascending=[False, False])

    results = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "families": sorted(trade_frame["family"].unique().tolist()),
        "trade_count": int(len(trade_frame)),
        "family_aggregate": family_aggregates.to_dict(orient="records"),
        "top_univariate": rows_to_records(top_univariate),
        "top_bivariate": rows_to_records(top_bivariate),
        "bundle_candidates": rows_to_records(bundle_candidates, limit=10),
        "repeatability": rows_to_records(combined_repeatability, limit=50),
        "acceptance_dominant": rows_to_records(acceptance_dominant),
        "time_stop_reliant": rows_to_records(time_stop_reliant),
        "runner_friendly": rows_to_records(runner_friendly),
    }

    markdown = build_markdown(
        trade_frame=trade_frame,
        family_aggregates=family_aggregates,
        top_univariate=top_univariate,
        top_bivariate=top_bivariate,
        bundle_candidates=bundle_candidates,
        repeatable=combined_repeatability,
        acceptance_dominant=acceptance_dominant,
        time_stop_reliant=time_stop_reliant,
        runner_friendly=runner_friendly,
    )
    review = build_review_text(
        trade_frame=trade_frame,
        family_aggregates=family_aggregates,
        top_univariate=top_univariate,
        top_bivariate=top_bivariate,
        bundle_candidates=bundle_candidates,
        repeatable=combined_repeatability,
        acceptance_dominant=acceptance_dominant,
        time_stop_reliant=time_stop_reliant,
        runner_friendly=runner_friendly,
    )

    results_path = output_root / "results" / "results.json"
    summary_path = output_root / "results" / "summary.md"
    review_path = REPO_ROOT / "knowledge" / "experiments" / "2026-04-21-usdjpy-intraday-feature-regime-research-review.md"

    write_text(results_path, json.dumps(results, indent=2, ensure_ascii=False))
    write_text(summary_path, markdown)
    write_text(review_path, review)

    print(
        json.dumps(
            {
                "families": results["families"],
                "trade_count": results["trade_count"],
                "repeatability_rows": len(results["repeatability"]),
                "summary": str(summary_path),
                "review": str(review_path),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
