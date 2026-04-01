from __future__ import annotations

import argparse
import bisect
import gzip
import json
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

import MetaTrader5 as mt5
import numpy as np
import pandas as pd


REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_OUTPUT_ROOT = REPO_ROOT / "reports" / "research"
ORIGIN_PATH = REPO_ROOT.parents[2] / "origin.txt"
TIMEFRAME_MAP = {
    "M5": mt5.TIMEFRAME_M5,
    "M15": mt5.TIMEFRAME_M15,
}
SESSION_WINDOWS = {
    "all": (0, 24),
    "london": (7, 16),
    "ny": (13, 22),
    "london_ny": (7, 22),
    "london_open": (7, 12),
    "ny_open": (13, 18),
}


@dataclass
class CandidateRule:
    direction: str
    session: str
    max_prior_touches: int
    min_breakout_body_pips: float
    min_breakout_close_location: float
    min_body_to_range: float
    min_body_vs_avg: float
    max_retest_delay_bars: int
    min_retest_close_location: float
    train_trades: int
    train_tpd: float
    train_expectancy_r: float
    train_win_rate: float
    test_trades: int
    test_tpd: float
    test_expectancy_r: float
    test_win_rate: float
    score: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a doctrine-aligned S2 round-number breakout event study for USDJPY.")
    parser.add_argument("--symbol", default="USDJPY")
    parser.add_argument("--timeframe", default="M5", choices=sorted(TIMEFRAME_MAP))
    parser.add_argument("--analysis-days", type=int, default=365)
    parser.add_argument("--oos-days", type=int, default=91)
    parser.add_argument("--bars-fallback", type=int, default=140000)
    parser.add_argument("--output-dir")
    parser.add_argument("--terminal-path")
    parser.add_argument("--stop-loss-pips", type=float, default=10.0)
    parser.add_argument("--target-r", type=float, default=1.2)
    parser.add_argument("--max-hold-bars", type=int, default=96)
    return parser.parse_args()


def slugify(value: str) -> str:
    return "".join(ch.lower() if ch.isalnum() else "-" for ch in value).strip("-")


def load_terminal_path(explicit: str | None) -> str:
    if explicit:
        return explicit
    origin = ORIGIN_PATH.read_text(encoding="utf-16").strip()
    return str(Path(origin) / "terminal64.exe")


def initialize_mt5(terminal_path: str) -> None:
    if not mt5.initialize(path=terminal_path):
        raise RuntimeError(f"MT5 initialize failed: {mt5.last_error()}")


def pip_size(symbol: str) -> float:
    info = mt5.symbol_info(symbol)
    if info is None or not info.point:
        return 0.01
    point = float(info.point)
    if info.digits in (3, 5):
        return point * 10.0
    return point


def load_rates_by_range(symbol: str, timeframe_label: str, lookback_days: int, bars_fallback: int) -> pd.DataFrame:
    timeframe = TIMEFRAME_MAP[timeframe_label]
    info = mt5.symbol_info(symbol)
    if not mt5.symbol_select(symbol, True):
        raise RuntimeError(f"Failed to select symbol {symbol}: {mt5.last_error()}")

    tick = mt5.symbol_info_tick(symbol)
    rates = None
    if tick is not None:
        end = datetime.fromtimestamp(tick.time)
        start = end - timedelta(days=lookback_days)
        try:
            rates = mt5.copy_rates_range(symbol, timeframe, start, end)
        except Exception:
            rates = None

    if rates is None:
        chunks: list[pd.DataFrame] = []
        position = 0
        chunk_size = 5000
        while position < bars_fallback:
            request = min(chunk_size, bars_fallback - position)
            chunk = mt5.copy_rates_from_pos(symbol, timeframe, position, request)
            if chunk is None:
                if chunks:
                    break
                raise RuntimeError(f"Failed to load rates for {symbol}: {mt5.last_error()}")
            frame_chunk = pd.DataFrame(chunk)
            if frame_chunk.empty:
                break
            chunks.append(frame_chunk)
            position += len(frame_chunk)
            if len(frame_chunk) < request:
                break
        if not chunks:
            raise RuntimeError(f"Failed to load rates for {symbol}: {mt5.last_error()}")
        rates = pd.concat(chunks, ignore_index=True).to_records(index=False)

    frame = pd.DataFrame(rates)
    if frame.empty:
        raise RuntimeError("No rates returned from MT5.")

    frame["time"] = pd.to_datetime(frame["time"], unit="s")
    frame["point"] = float(info.point if info and info.point else 0.001)
    frame["digits"] = int(info.digits if info else 3)
    return frame.drop_duplicates(subset=["time"]).sort_values("time").reset_index(drop=True)


def ema(series: pd.Series, span: int) -> pd.Series:
    return series.ewm(span=span, adjust=False).mean()


def average_body_pips(df: pd.DataFrame, index: int, lookback: int, pip: float) -> float:
    start = max(0, index - lookback + 1)
    sample = df.iloc[start : index + 1]
    if sample.empty:
        return 0.0
    return float((sample["close"] - sample["open"]).abs().mean() / pip)


def close_location(row: pd.Series) -> float:
    bar_range = float(row["high"] - row["low"])
    if bar_range <= 0.0:
        return 0.5
    return float((row["close"] - row["low"]) / bar_range)


def in_session(hour: int, session_name: str) -> bool:
    start, end = SESSION_WINDOWS[session_name]
    if start < end:
        return start <= hour < end
    return hour >= start or hour < end


def simulate_trade(
    df: pd.DataFrame,
    signal_index: int,
    direction: int,
    pip: float,
    stop_loss_pips: float,
    target_r: float,
    max_hold_bars: int,
) -> tuple[float, int]:
    entry_index = signal_index + 1
    if entry_index >= len(df):
        return np.nan, 0

    entry = float(df.at[entry_index, "open"])
    spread_cost = float(df.at[entry_index, "spread"] * df.at[entry_index, "point"] / pip)
    stop_distance = stop_loss_pips * pip
    target_distance = stop_loss_pips * target_r * pip
    if direction > 0:
        stop_price = entry - stop_distance
        target_price = entry + target_distance
    else:
        stop_price = entry + stop_distance
        target_price = entry - target_distance

    last_index = min(len(df) - 1, entry_index + max_hold_bars)
    for idx in range(entry_index, last_index + 1):
        high = float(df.at[idx, "high"])
        low = float(df.at[idx, "low"])
        if direction > 0:
            if low <= stop_price:
                return (-1.0) - (spread_cost / stop_loss_pips), idx - entry_index + 1
            if high >= target_price:
                return target_r - (spread_cost / stop_loss_pips), idx - entry_index + 1
        else:
            if high >= stop_price:
                return (-1.0) - (spread_cost / stop_loss_pips), idx - entry_index + 1
            if low <= target_price:
                return target_r - (spread_cost / stop_loss_pips), idx - entry_index + 1

    exit_price = float(df.at[last_index, "close"])
    realized_pips = ((exit_price - entry) / pip) if direction > 0 else ((entry - exit_price) / pip)
    realized_pips -= spread_cost
    return realized_pips / stop_loss_pips, last_index - entry_index + 1


def find_breakout_level(row: pd.Series, direction: int, step_price: float) -> float | None:
    start_index = int(np.floor(float(row["low"]) / step_price)) - 1
    end_index = int(np.ceil(float(row["high"]) / step_price)) + 1
    for level_index in range(start_index, end_index + 1):
        candidate = level_index * step_price
        if direction > 0 and float(row["open"]) < candidate and float(row["close"]) > candidate:
            return float(candidate)
        if direction < 0 and float(row["open"]) > candidate and float(row["close"]) < candidate:
            return float(candidate)
    return None


def count_round_touches(df: pd.DataFrame, current_index: int, round_level: float, tolerance: float, lookback: int) -> int:
    start = max(0, current_index - lookback)
    sample = df.iloc[start:current_index]
    if sample.empty:
        return 0
    touches = (sample["high"] >= round_level - tolerance) & (sample["low"] <= round_level + tolerance)
    return int(touches.sum())


def build_event_frame(df: pd.DataFrame, stop_loss_pips: float, target_r: float, max_hold_bars: int) -> pd.DataFrame:
    pip = float(df["point"].iloc[0] * 10.0) if int(df["digits"].iloc[0]) in (3, 5) else float(df["point"].iloc[0])
    step_price = 50.0 * pip
    touch_tolerance = 0.6 * pip
    retest_buffer = 1.5 * pip
    midpoint_buffer = 1.0 * pip
    touch_lookback = 144
    expiry_bars = 144

    df = df.copy()
    df["ema13"] = ema(df["close"], 13)
    df["ema100"] = ema(df["close"], 100)
    df["hour"] = df["time"].dt.hour
    df["dayofweek"] = df["time"].dt.dayofweek

    events: list[dict[str, Any]] = []
    for breakout_index in range(120, len(df) - max_hold_bars - 2):
        if int(df.at[breakout_index, "dayofweek"]) > 4:
            continue

        bar = df.iloc[breakout_index]
        avg_body = average_body_pips(df, breakout_index - 1, 20, pip)
        body_pips = float(abs(float(bar["close"]) - float(bar["open"])) / pip)
        range_pips = float((float(bar["high"]) - float(bar["low"])) / pip)
        if body_pips <= 0.0 or range_pips <= 0.0:
            continue

        breakout_close_loc = close_location(bar)
        body_to_range = body_pips / range_pips
        body_vs_avg = (body_pips / avg_body) if avg_body > 0.0 else np.nan
        slow_slope_pips = float((df.at[breakout_index, "ema100"] - df.at[breakout_index - 5, "ema100"]) / pip)

        for direction, label in ((1, "buy"), (-1, "sell")):
            level = find_breakout_level(bar, direction, step_price)
            if level is None:
                continue

            if direction > 0:
                if slow_slope_pips <= 0.0 or float(bar["close"]) <= float(df.at[breakout_index, "ema100"]):
                    continue
                if breakout_close_loc < 0.55:
                    continue
            else:
                if slow_slope_pips >= 0.0 or float(bar["close"]) >= float(df.at[breakout_index, "ema100"]):
                    continue
                if breakout_close_loc > 0.45:
                    continue

            prior_touches = count_round_touches(df, breakout_index, level, touch_tolerance, touch_lookback)

            midpoint = level + direction * (step_price * 0.5)
            found_signal = False
            midpoint_hit = False
            for signal_index in range(breakout_index + 1, min(len(df) - max_hold_bars - 1, breakout_index + expiry_bars + 1)):
                signal_bar = df.iloc[signal_index]
                if direction > 0:
                    if float(signal_bar["high"]) >= midpoint - midpoint_buffer:
                        midpoint_hit = True
                        break
                else:
                    if float(signal_bar["low"]) <= midpoint + midpoint_buffer:
                        midpoint_hit = True
                        break

                if not (float(signal_bar["low"]) <= float(df.at[signal_index, "ema13"]) + touch_tolerance and float(signal_bar["high"]) >= float(df.at[signal_index, "ema13"]) - touch_tolerance):
                    continue

                retest_close_loc = close_location(signal_bar)
                if direction > 0:
                    if float(signal_bar["low"]) < level - retest_buffer:
                        continue
                    if float(signal_bar["close"]) < level:
                        continue
                else:
                    if float(signal_bar["high"]) > level + retest_buffer:
                        continue
                    if float(signal_bar["close"]) > level:
                        continue

                expectancy_r, hold_bars = simulate_trade(df, signal_index, direction, pip, stop_loss_pips, target_r, max_hold_bars)
                events.append(
                    {
                        "breakout_time": df.at[breakout_index, "time"],
                        "signal_time": df.at[signal_index, "time"],
                        "direction": label,
                        "breakout_hour": int(df.at[breakout_index, "hour"]),
                        "signal_hour": int(df.at[signal_index, "hour"]),
                        "body_pips": body_pips,
                        "range_pips": range_pips,
                        "body_to_range": body_to_range,
                        "breakout_close_location": breakout_close_loc if direction > 0 else (1.0 - breakout_close_loc),
                        "body_vs_avg": body_vs_avg,
                        "slow_slope_pips": abs(slow_slope_pips),
                        "prior_touches": prior_touches,
                        "retest_delay_bars": signal_index - breakout_index,
                        "retest_close_location": retest_close_loc if direction > 0 else (1.0 - retest_close_loc),
                        "expectancy_r": expectancy_r,
                        "win": float(expectancy_r > 0.0),
                        "hold_bars": hold_bars,
                    }
                )
                found_signal = True
                break

            if not found_signal and midpoint_hit:
                continue

    return pd.DataFrame(events)


def candidate_grids() -> dict[str, list[Any]]:
    return {
        "direction": ["buy", "sell"],
        "session": list(SESSION_WINDOWS.keys()),
        "max_prior_touches": [0, 1, 2, 3],
        "min_breakout_body_pips": [4.0, 5.0, 6.0, 8.0],
        "min_breakout_close_location": [0.60, 0.70, 0.80],
        "min_body_to_range": [0.60, 0.70, 0.80],
        "min_body_vs_avg": [1.0, 1.3, 1.6],
        "max_retest_delay_bars": [6, 12, 24, 48],
        "min_retest_close_location": [0.60, 0.70, 0.80],
    }


def evaluate_candidates(events: pd.DataFrame, split_time: pd.Timestamp) -> list[CandidateRule]:
    rules: list[CandidateRule] = []
    if events.empty:
        return rules

    train_days = max((split_time - events["signal_time"].min()).days, 1)
    test_days = max((events["signal_time"].max() - split_time).days, 1)

    grids = candidate_grids()
    for direction in grids["direction"]:
        direction_events = events.loc[events["direction"] == direction]
        if direction_events.empty:
            continue
        for session in grids["session"]:
            session_events = direction_events.loc[direction_events["signal_hour"].map(lambda hour: in_session(int(hour), session))]
            if session_events.empty:
                continue
            for max_prior_touches in grids["max_prior_touches"]:
                touch_events = session_events.loc[session_events["prior_touches"] <= max_prior_touches]
                if touch_events.empty:
                    continue
                for min_breakout_body_pips in grids["min_breakout_body_pips"]:
                    body_events = touch_events.loc[touch_events["body_pips"] >= min_breakout_body_pips]
                    if body_events.empty:
                        continue
                    for min_breakout_close_location in grids["min_breakout_close_location"]:
                        close_events = body_events.loc[body_events["breakout_close_location"] >= min_breakout_close_location]
                        if close_events.empty:
                            continue
                        for min_body_to_range in grids["min_body_to_range"]:
                            range_events = close_events.loc[close_events["body_to_range"] >= min_body_to_range]
                            if range_events.empty:
                                continue
                            for min_body_vs_avg in grids["min_body_vs_avg"]:
                                avg_events = range_events.loc[range_events["body_vs_avg"] >= min_body_vs_avg]
                                if avg_events.empty:
                                    continue
                                for max_retest_delay_bars in grids["max_retest_delay_bars"]:
                                    delay_events = avg_events.loc[avg_events["retest_delay_bars"] <= max_retest_delay_bars]
                                    if delay_events.empty:
                                        continue
                                    for min_retest_close_location in grids["min_retest_close_location"]:
                                        filtered = delay_events.loc[delay_events["retest_close_location"] >= min_retest_close_location]
                                        if filtered.empty:
                                            continue

                                        train = filtered.loc[filtered["signal_time"] < split_time]
                                        test = filtered.loc[filtered["signal_time"] >= split_time]
                                        if train.empty or test.empty:
                                            continue
                                        if len(train) < 6 or len(test) < 3:
                                            continue

                                        train_expectancy = float(train["expectancy_r"].mean())
                                        test_expectancy = float(test["expectancy_r"].mean())
                                        train_tpd = len(train) / train_days
                                        test_tpd = len(test) / test_days
                                        score = (test_expectancy * 5.0) + (train_expectancy * 2.0) + min(test_tpd, 1.0)

                                        rules.append(
                                            CandidateRule(
                                                direction=direction,
                                                session=session,
                                                max_prior_touches=max_prior_touches,
                                                min_breakout_body_pips=min_breakout_body_pips,
                                                min_breakout_close_location=min_breakout_close_location,
                                                min_body_to_range=min_body_to_range,
                                                min_body_vs_avg=min_body_vs_avg,
                                                max_retest_delay_bars=max_retest_delay_bars,
                                                min_retest_close_location=min_retest_close_location,
                                                train_trades=int(len(train)),
                                                train_tpd=float(train_tpd),
                                                train_expectancy_r=train_expectancy,
                                                train_win_rate=float(train["win"].mean()),
                                                test_trades=int(len(test)),
                                                test_tpd=float(test_tpd),
                                                test_expectancy_r=test_expectancy,
                                                test_win_rate=float(test["win"].mean()),
                                                score=float(score),
                                            )
                                        )
    return sorted(rules, key=lambda item: item.score, reverse=True)


def build_summary(
    symbol: str,
    timeframe_label: str,
    df: pd.DataFrame,
    split_time: pd.Timestamp,
    events: pd.DataFrame,
    candidates: list[CandidateRule],
) -> dict[str, Any]:
    top_rules = [asdict(rule) for rule in candidates[:12]]
    return {
        "symbol": symbol,
        "timeframe": timeframe_label,
        "history_start": df["time"].min().isoformat(),
        "history_end": df["time"].max().isoformat(),
        "split_train_end": (split_time - pd.Timedelta(minutes=5)).isoformat(),
        "split_test_start": split_time.isoformat(),
        "event_count": int(len(events)),
        "candidate_count": int(len(candidates)),
        "top_candidates": top_rules,
    }


def write_outputs(
    output_dir: Path,
    events: pd.DataFrame,
    candidates: list[CandidateRule],
    summary: dict[str, Any],
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    events_path = output_dir / "events.csv"
    candidates_path = output_dir / "candidates.csv"
    summary_json_path = output_dir / "summary.json"
    summary_md_path = output_dir / "summary.md"

    events.to_csv(events_path, index=False)
    pd.DataFrame([asdict(rule) for rule in candidates]).to_csv(candidates_path, index=False)
    summary_json_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    lines = [
        "# USDJPY Golden S2 Round Breakout Event Study",
        "",
        f"- Symbol: `{summary['symbol']}`",
        f"- Timeframe: `{summary['timeframe']}`",
        f"- History window: `{summary['history_start']}` -> `{summary['history_end']}`",
        f"- Train / OOS split: `{summary['split_train_end']}` / `{summary['split_test_start']}`",
        f"- Event count: `{summary['event_count']}`",
        f"- Candidate count: `{summary['candidate_count']}`",
        "",
        "## Top Candidates",
        "",
    ]
    for candidate in summary["top_candidates"]:
        lines.append(
            "- "
            f"`{candidate['direction']}` / `{candidate['session']}` / touches<={candidate['max_prior_touches']} / "
            f"body>={candidate['min_breakout_body_pips']} / breakout_close>={candidate['min_breakout_close_location']:.2f} / "
            f"body_range>={candidate['min_body_to_range']:.2f} / body_vs_avg>={candidate['min_body_vs_avg']:.2f} / "
            f"delay<={candidate['max_retest_delay_bars']} / retest_close>={candidate['min_retest_close_location']:.2f}: "
            f"train `{candidate['train_trades']} trades, {candidate['train_tpd']:.2f}/day, exp {candidate['train_expectancy_r']:.3f}R`, "
            f"test `{candidate['test_trades']} trades, {candidate['test_tpd']:.2f}/day, exp {candidate['test_expectancy_r']:.3f}R`"
        )
    summary_md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    for path in (events_path, candidates_path):
        with path.open("rb") as src, gzip.open(path.with_suffix(path.suffix + ".gz"), "wb") as dst:
            dst.write(src.read())


def main() -> int:
    args = parse_args()
    output_dir = Path(args.output_dir) if args.output_dir else (
        DEFAULT_OUTPUT_ROOT / f"{datetime.now().strftime('%Y-%m-%d-%H%M%S')}-{slugify(args.symbol)}-{args.timeframe.lower()}-golden-s2-event-study"
    )

    terminal_path = load_terminal_path(args.terminal_path)
    initialize_mt5(terminal_path)
    try:
        df = load_rates_by_range(args.symbol, args.timeframe, args.analysis_days, args.bars_fallback)
        split_time = df["time"].max() - pd.Timedelta(days=args.oos_days)
        events = build_event_frame(df, args.stop_loss_pips, args.target_r, args.max_hold_bars)
        candidates = evaluate_candidates(events, split_time)
        summary = build_summary(args.symbol, args.timeframe, df, split_time, events, candidates)
        write_outputs(output_dir, events, candidates, summary)
        print(json.dumps({"output_dir": str(output_dir), "events": len(events), "candidates": len(candidates)}))
        return 0
    finally:
        mt5.shutdown()


if __name__ == "__main__":
    raise SystemExit(main())
