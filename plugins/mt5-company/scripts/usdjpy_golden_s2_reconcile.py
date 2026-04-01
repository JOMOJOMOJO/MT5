from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

import pandas as pd

from usdjpy_golden_s2_event_study import (
    DEFAULT_OUTPUT_ROOT,
    initialize_mt5,
    load_rates_by_range,
    load_terminal_path,
    ema,
    find_breakout_level,
    count_round_touches,
)


REPO_ROOT = Path(__file__).resolve().parents[3]


@dataclass
class BreakoutState:
    active: bool = False
    direction: int = 0
    round_level: float = 0.0
    midpoint: float = 0.0
    bars_remaining: int = 0
    breakout_index: int = -1
    breakout_time: str = ""
    breakout_body_pips: float = 0.0
    breakout_close_location: float = 0.0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Reconcile USDJPY Golden Method S2 study events with current EA-side breakout detection.")
    parser.add_argument(
        "--preset-path",
        default=str(REPO_ROOT / "reports" / "presets" / "usdjpy_20260402_golden_method-s2-sell-breakout-active.set"),
    )
    parser.add_argument(
        "--events-path",
        default=str(REPO_ROOT / "reports" / "research" / "2026-04-02-020757-usdjpy-m5-golden-s2-event-study" / "events.csv"),
    )
    parser.add_argument("--symbol", default="USDJPY")
    parser.add_argument("--timeframe", default="M5")
    parser.add_argument("--analysis-days", type=int, default=365)
    parser.add_argument("--oos-start", default="2025-12-31T20:05:00")
    parser.add_argument("--terminal-path")
    parser.add_argument("--output-dir")
    return parser.parse_args()


def slugify(value: str) -> str:
    return "".join(ch.lower() if ch.isalnum() else "-" for ch in value).strip("-")


def parse_set_value(raw: str) -> Any:
    value = raw.split("||", 1)[0].strip()
    lowered = value.lower()
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    try:
        if "." in value:
            return float(value)
        return int(value)
    except ValueError:
        return value


def load_preset(path: Path) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        result[key.strip()] = parse_set_value(value)
    return result


def allowed_weekdays(raw: str) -> set[int]:
    return {int(item.strip()) for item in str(raw).split(",") if item.strip()}


def average_body_pips(df: pd.DataFrame, index: int, lookback: int, pip: float) -> float:
    start = max(0, index - lookback)
    sample = df.iloc[start:index]
    if sample.empty:
        return 0.0
    return float((sample["close"] - sample["open"]).abs().mean() / pip)


def close_location(row: pd.Series) -> float:
    bar_range = float(row["high"] - row["low"])
    if bar_range <= 0.0:
        return 0.5
    return float((row["close"] - row["low"]) / bar_range)


def bar_touches_price(row: pd.Series, level: float, tolerance_price: float) -> bool:
    return float(row["low"]) <= level + tolerance_price and float(row["high"]) >= level - tolerance_price


def window_range_pips(df: pd.DataFrame, index: int, lookback: int, pip: float) -> float:
    start = max(0, index - lookback + 1)
    sample = df.iloc[start : index + 1]
    if sample.empty:
        return 0.0
    return float((sample["high"].max() - sample["low"].min()) / pip)


def is_low_volatility_same_zone(df: pd.DataFrame, index: int, lookback: int, round_step_price: float) -> bool:
    start = max(0, index - lookback + 1)
    sample = df.iloc[start : index + 1]
    if sample.empty:
        return False
    highest = float(sample["high"].max())
    lowest = float(sample["low"].min())
    return int(highest // round_step_price) == int(lowest // round_step_price)


def passes_volatility_state(df: pd.DataFrame, index: int, preset: dict[str, Any], round_step_price: float, pip: float) -> tuple[bool, list[str]]:
    reasons: list[str] = []
    lookback = int(preset["InpVolatilityLookbackBars"])
    if is_low_volatility_same_zone(df, index, lookback, round_step_price):
        reasons.append("same_50pip_zone")
    if window_range_pips(df, index, lookback, pip) < float(preset["InpMinWindowRangePips"]):
        reasons.append("window_range_too_small")
    return (len(reasons) == 0, reasons)


def rejection_bar_is_strong(row: pd.Series, direction: int, avg_body_pips: float, preset: dict[str, Any], pip: float) -> tuple[bool, list[str]]:
    reasons: list[str] = []
    body = abs(float(row["close"]) - float(row["open"])) / pip
    if body < float(preset["InpMinRejectionBodyPips"]):
        reasons.append("rejection_body_too_small")
    if avg_body_pips > 0.0 and body < avg_body_pips * 0.9:
        reasons.append("rejection_body_below_avg")
    loc = close_location(row)
    min_loc = float(preset["InpMinRejectionCloseLocation"])
    if direction > 0:
        if float(row["close"]) <= float(row["open"]):
            reasons.append("rejection_not_bullish")
        if loc < min_loc:
            reasons.append("rejection_close_location_weak")
    else:
        if float(row["close"]) >= float(row["open"]):
            reasons.append("rejection_not_bearish")
        if loc > (1.0 - min_loc):
            reasons.append("rejection_close_location_weak")
    return (len(reasons) == 0, reasons)


def breakout_candle_is_large(df: pd.DataFrame, index: int, preset: dict[str, Any], pip: float) -> tuple[bool, list[str]]:
    row = df.iloc[index]
    reasons: list[str] = []
    body = abs(float(row["close"]) - float(row["open"])) / pip
    bar_range = (float(row["high"]) - float(row["low"])) / pip
    if body < float(preset["InpBreakoutMinBodyPips"]):
        reasons.append("breakout_body_too_small")
    if bar_range <= 0.0:
        reasons.append("breakout_zero_range")
    else:
        if (body / bar_range) < float(preset["InpBreakoutBodyToRangeMin"]):
            reasons.append("breakout_body_to_range_too_small")
    upper_wick = (float(row["high"]) - max(float(row["open"]), float(row["close"]))) / pip
    lower_wick = (min(float(row["open"]), float(row["close"])) - float(row["low"])) / pip
    if max(upper_wick, lower_wick) > body * 0.35:
        reasons.append("breakout_wick_too_large")
    avg_body = average_body_pips(df, index, 20, pip)
    if avg_body > 0.0 and body < avg_body * float(preset["InpBreakoutVsAverageBodyMin"]):
        reasons.append("breakout_vs_avg_too_small")
    return (len(reasons) == 0, reasons)


def detect_breakout(df: pd.DataFrame, index: int, preset: dict[str, Any], pip: float, point: float) -> tuple[BreakoutState | None, list[str]]:
    row = df.iloc[index]
    round_step_price = pip * int(preset["InpRoundStepPips"])
    tolerance_price = float(preset["InpTouchTolerancePips"]) * pip
    slow_slope = float(df.at[index, "ema100"] - df.at[max(0, index - int(preset["InpSlowSlopeLookback"])), "ema100"])
    reasons: list[str] = []
    passed_vol, vol_reasons = passes_volatility_state(df, index, preset, round_step_price, pip)
    if not passed_vol:
        reasons.extend(vol_reasons)
    if abs(slow_slope) / pip < float(preset["InpMinSlowSlopePips"]):
        reasons.append("slow_slope_too_small")

    direction = None
    level = None
    if bool(preset["InpAllowLongs"]):
        maybe = find_breakout_level(row, 1, round_step_price)
        if maybe is not None:
            direction = 1
            level = maybe
    if direction is None and bool(preset["InpAllowShorts"]):
        maybe = find_breakout_level(row, -1, round_step_price)
        if maybe is not None:
            direction = -1
            level = maybe
    if direction is None or level is None:
        reasons.append("no_breakout_level")
        return None, reasons

    candle_ok, candle_reasons = breakout_candle_is_large(df, index, preset, pip)
    if not candle_ok:
        reasons.extend(candle_reasons)

    avg_body = average_body_pips(df, index, 5, pip)
    rejection_ok, rejection_reasons = rejection_bar_is_strong(row, direction, avg_body, preset, pip)
    if not rejection_ok:
        reasons.extend(rejection_reasons)

    if direction > 0:
        if slow_slope <= 0.0 or float(row["close"]) <= float(df.at[index, "ema100"]):
            reasons.append("breakout_trend_alignment_fail")
    else:
        if slow_slope >= 0.0 or float(row["close"]) >= float(df.at[index, "ema100"]):
            reasons.append("breakout_trend_alignment_fail")

    touches = count_round_touches(df, index, level, tolerance_price, int(preset["InpRoundTouchLookbackBars"]))
    if touches > int(preset["InpMaxRoundTouchesBeforeBreak"]):
        reasons.append("too_many_prior_round_touches")

    if reasons:
        return None, reasons

    state = BreakoutState(
        active=True,
        direction=direction,
        round_level=float(level),
        midpoint=float(level + direction * (round_step_price * 0.5)),
        bars_remaining=int(preset["InpBreakoutExpiryBars"]),
        breakout_index=index,
        breakout_time=pd.Timestamp(row["time"]).isoformat(),
        breakout_body_pips=abs(float(row["close"]) - float(row["open"])) / pip,
        breakout_close_location=close_location(row) if direction > 0 else (1.0 - close_location(row)),
    )
    return state, []


def can_open_gate(df: pd.DataFrame, eval_index: int, preset: dict[str, Any], pip: float, point: float, weekday_set: set[int]) -> list[str]:
    next_index = eval_index + 1
    reasons: list[str] = []
    if next_index >= len(df):
        return ["no_next_bar"]
    next_time = pd.Timestamp(df.at[next_index, "time"])
    mql_day = (next_time.dayofweek + 1) % 7
    if mql_day not in weekday_set:
        reasons.append("weekday_blocked")

    start_hour = int(preset["InpActiveSessionStartHour"])
    end_hour = int(preset["InpActiveSessionEndHour"])
    hour = next_time.hour
    if start_hour < end_hour:
        session_ok = start_hour <= hour < end_hour
    else:
        session_ok = hour >= start_hour or hour < end_hour
    if not session_ok:
        reasons.append("session_blocked")

    spread_pips = float(df.at[next_index, "spread"] * point / pip)
    if spread_pips > float(preset["InpMaxSpreadPips"]):
        reasons.append("spread_blocked")
    return reasons


def evaluate_strategy2(df: pd.DataFrame, index: int, state: BreakoutState, preset: dict[str, Any], pip: float) -> list[str]:
    reasons: list[str] = []
    row = df.iloc[index]
    tolerance_price = float(preset["InpTouchTolerancePips"]) * pip
    if not bar_touches_price(row, float(df.at[index, "ema13"]), tolerance_price):
        reasons.append("ema13_touch_missing")

    avg_body = average_body_pips(df, index, 5, pip)
    rejection_ok, rejection_reasons = rejection_bar_is_strong(row, state.direction, avg_body, preset, pip)
    if not rejection_ok:
        reasons.extend(rejection_reasons)

    buffer = float(preset["InpRetestRoundBufferPips"]) * pip
    loc = close_location(row)
    breakout_loc_min = float(preset["InpBreakoutCloseLocationMin"])
    if state.direction > 0:
        if loc < breakout_loc_min:
            reasons.append("retest_close_location_weak")
        if float(row["low"]) < state.round_level - buffer:
            reasons.append("retest_below_round_buffer")
        if float(row["close"]) < state.round_level:
            reasons.append("retest_close_below_round")
        if float(df.at[index, "ema100"] - df.at[max(0, index - int(preset["InpSlowSlopeLookback"])), "ema100"]) <= 0.0:
            reasons.append("slow_slope_not_up")
        if float(row["close"]) < float(df.at[index, "ema13"]):
            reasons.append("close_below_fast")
        if float(row["close"]) < float(df.at[index, "ema100"]):
            reasons.append("close_below_slow")
    else:
        if loc > (1.0 - breakout_loc_min):
            reasons.append("retest_close_location_weak")
        if float(row["high"]) > state.round_level + buffer:
            reasons.append("retest_above_round_buffer")
        if float(row["close"]) > state.round_level:
            reasons.append("retest_close_above_round")
        if float(df.at[index, "ema100"] - df.at[max(0, index - int(preset["InpSlowSlopeLookback"])), "ema100"]) >= 0.0:
            reasons.append("slow_slope_not_down")
        if float(row["close"]) > float(df.at[index, "ema13"]):
            reasons.append("close_above_fast")
        if float(row["close"]) > float(df.at[index, "ema100"]):
            reasons.append("close_above_slow")
    return reasons


def find_state_before_signal(
    df: pd.DataFrame,
    breakout_index: int,
    signal_index: int,
    preset: dict[str, Any],
    pip: float,
) -> tuple[BreakoutState | None, str, dict[str, Any]]:
    round_step_price = pip * int(preset["InpRoundStepPips"])
    midpoint_buffer = float(preset["InpRoundMidpointBufferPips"]) * pip
    history: dict[str, Any] = {"refresh_attempts": []}
    state, detect_reasons = detect_breakout(df, breakout_index, preset, pip, float(df["point"].iloc[0]))
    if state is None:
        history["breakout_reasons"] = detect_reasons
        return None, "breakout_rejected", history

    for index in range(breakout_index + 1, signal_index + 1):
        # Existing EA behavior: active state blocks a fresh breakout arm while still active.
        state.bars_remaining -= 1
        row = df.iloc[index]
        if state.direction > 0 and float(row["high"]) >= state.midpoint - midpoint_buffer:
            return None, "midpoint_invalidated", history
        if state.direction < 0 and float(row["low"]) <= state.midpoint + midpoint_buffer:
            return None, "midpoint_invalidated", history
        if state.bars_remaining <= 0:
            return None, "expiry_invalidated", history

        if index < signal_index:
            refresh, _ = detect_breakout(df, index, preset, pip, float(df["point"].iloc[0]))
            if refresh is not None:
                history["refresh_attempts"].append(
                    {
                        "time": pd.Timestamp(df.at[index, "time"]).isoformat(),
                        "direction": refresh.direction,
                        "round_level": refresh.round_level,
                        "body_pips": refresh.breakout_body_pips,
                    }
                )
    return state, "armed", history


def summarize_filtered_events(events: pd.DataFrame, preset: dict[str, Any], oos_start: pd.Timestamp) -> pd.DataFrame:
    filtered = events.copy()
    direction = "sell" if bool(preset["InpAllowShorts"]) and not bool(preset["InpAllowLongs"]) else "buy"
    filtered = filtered.loc[filtered["direction"] == direction]
    filtered = filtered.loc[filtered["signal_time"] >= oos_start]
    filtered = filtered.loc[filtered["prior_touches"] <= int(preset["InpMaxRoundTouchesBeforeBreak"])]
    filtered = filtered.loc[filtered["body_pips"] >= float(preset["InpBreakoutMinBodyPips"])]
    filtered = filtered.loc[filtered["breakout_close_location"] >= float(preset["InpBreakoutCloseLocationMin"])]
    filtered = filtered.loc[filtered["body_to_range"] >= float(preset["InpBreakoutBodyToRangeMin"])]
    filtered = filtered.loc[filtered["body_vs_avg"] >= float(preset["InpBreakoutVsAverageBodyMin"])]
    filtered = filtered.loc[filtered["retest_delay_bars"] <= int(preset["InpBreakoutExpiryBars"])]
    filtered = filtered.loc[filtered["retest_close_location"] >= float(preset["InpBreakoutCloseLocationMin"])]
    return filtered.reset_index(drop=True)


def reconcile(
    df: pd.DataFrame,
    events: pd.DataFrame,
    preset: dict[str, Any],
    oos_start: pd.Timestamp,
) -> dict[str, Any]:
    point = float(df["point"].iloc[0])
    digits = int(df["digits"].iloc[0])
    pip = point * 10.0 if digits in (3, 5) else point
    weekday_set = allowed_weekdays(preset["InpAllowedWeekdays"])
    filtered_events = summarize_filtered_events(events, preset, oos_start)

    index_map = {pd.Timestamp(ts): idx for idx, ts in enumerate(df["time"])}
    rows: list[dict[str, Any]] = []
    actual_signals: list[dict[str, Any]] = []
    breakout_refresh_candidates = 0

    # Full replay to capture actual EA-side OOS S2 signals and active-state refresh opportunities.
    state = BreakoutState()
    for index in range(120, len(df) - 1):
        bar_time = pd.Timestamp(df.at[index, "time"])
        if bar_time < oos_start:
            continue

        if state.active:
            state.bars_remaining -= 1
            midpoint_buffer = float(preset["InpRoundMidpointBufferPips"]) * pip
            row = df.iloc[index]
            if state.direction > 0 and float(row["high"]) >= state.midpoint - midpoint_buffer:
                state = BreakoutState()
            elif state.direction < 0 and float(row["low"]) <= state.midpoint + midpoint_buffer:
                state = BreakoutState()
            elif state.bars_remaining <= 0:
                state = BreakoutState()

        if state.active:
            refresh, _ = detect_breakout(df, index, preset, pip, point)
            if refresh is not None:
                breakout_refresh_candidates += 1

        just_armed = False
        if not state.active:
            detected, _ = detect_breakout(df, index, preset, pip, point)
            if detected is not None:
                state = detected
                just_armed = True

        if state.active and not just_armed:
            gate_reasons = can_open_gate(df, index, preset, pip, point, weekday_set)
            eval_reasons = evaluate_strategy2(df, index, state, preset, pip)
            if not gate_reasons and not eval_reasons:
                actual_signals.append(
                    {
                        "signal_time": bar_time.isoformat(),
                        "breakout_time": state.breakout_time,
                        "direction": state.direction,
                    }
                )
                state = BreakoutState()

    for _, event in filtered_events.iterrows():
        breakout_time = pd.Timestamp(event["breakout_time"])
        signal_time = pd.Timestamp(event["signal_time"])
        breakout_index = index_map.get(breakout_time)
        signal_index = index_map.get(signal_time)
        if breakout_index is None or signal_index is None:
            rows.append(
                {
                    "breakout_time": breakout_time.isoformat(),
                    "signal_time": signal_time.isoformat(),
                    "status": "missing_bar",
                    "detail": "breakout_or_signal_bar_missing_from_loaded_history",
                }
            )
            continue

        state_before_signal, status, history = find_state_before_signal(df, breakout_index, signal_index, preset, pip)
        if status != "armed" or state_before_signal is None:
            rows.append(
                {
                    "breakout_time": breakout_time.isoformat(),
                    "signal_time": signal_time.isoformat(),
                    "status": status,
                    "detail": json.dumps(history, ensure_ascii=False),
                }
            )
            continue

        gate_reasons = can_open_gate(df, signal_index, preset, pip, point, weekday_set)
        eval_reasons = evaluate_strategy2(df, signal_index, state_before_signal, preset, pip)
        if gate_reasons or eval_reasons:
            rows.append(
                {
                    "breakout_time": breakout_time.isoformat(),
                    "signal_time": signal_time.isoformat(),
                    "status": "signal_rejected",
                    "detail": json.dumps(
                        {
                            "gate_reasons": gate_reasons,
                            "eval_reasons": eval_reasons,
                            "history": history,
                        },
                        ensure_ascii=False,
                    ),
                }
            )
        else:
            rows.append(
                {
                    "breakout_time": breakout_time.isoformat(),
                    "signal_time": signal_time.isoformat(),
                    "status": "signal_passes_current_logic",
                    "detail": json.dumps(history, ensure_ascii=False),
                }
            )

    return {
        "preset": str(args.preset_path) if False else "",
        "oos_event_count": int(len(filtered_events)),
        "actual_oos_signal_count": int(len(actual_signals)),
        "breakout_refresh_candidates": int(breakout_refresh_candidates),
        "event_rows": rows,
        "actual_signals": actual_signals,
    }


def write_outputs(output_dir: Path, preset_path: Path, result: dict[str, Any]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    summary_json_path = output_dir / "summary.json"
    summary_md_path = output_dir / "summary.md"
    rows_csv_path = output_dir / "events.csv"

    summary_json_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    pd.DataFrame(result["event_rows"]).to_csv(rows_csv_path, index=False)

    lines = [
        "# USDJPY Golden S2 Reconciliation",
        "",
        f"- Preset: `{preset_path.name}`",
        f"- OOS study events matching preset: `{result['oos_event_count']}`",
        f"- Actual EA-side OOS signals: `{result['actual_oos_signal_count']}`",
        f"- Fresh-breakout opportunities while state already active: `{result['breakout_refresh_candidates']}`",
        "",
        "## Event Reconciliation",
        "",
    ]
    for row in result["event_rows"]:
        lines.append(
            f"- `{row['breakout_time']}` -> `{row['signal_time']}`: `{row['status']}`"
        )
        lines.append(f"  - {row['detail']}")
    summary_md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    output_dir = Path(args.output_dir) if args.output_dir else (
        DEFAULT_OUTPUT_ROOT / f"{datetime.now().strftime('%Y-%m-%d-%H%M%S')}-usdjpy-golden-s2-reconcile"
    )

    preset_path = Path(args.preset_path)
    events_path = Path(args.events_path)
    preset = load_preset(preset_path)
    events = pd.read_csv(events_path, parse_dates=["breakout_time", "signal_time"])

    terminal_path = load_terminal_path(args.terminal_path)
    initialize_mt5(terminal_path)
    try:
        df = load_rates_by_range(args.symbol, args.timeframe, args.analysis_days, 140000)
    finally:
        import MetaTrader5 as mt5

        mt5.shutdown()

    df["ema13"] = ema(df["close"], int(preset["InpFastEMAPeriod"]))
    df["ema100"] = ema(df["close"], int(preset["InpSlowEMAPeriod"]))
    oos_start = pd.Timestamp(args.oos_start)
    result = reconcile(df, events, preset, oos_start)
    result["preset"] = str(preset_path)
    write_outputs(output_dir, preset_path, result)
    print(json.dumps({"output_dir": str(output_dir), "oos_events": result["oos_event_count"], "actual_signals": result["actual_oos_signal_count"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
