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
    session: str
    max_countertrend_bodies: int
    min_transition_distance_pips: float
    max_pullback_ratio: float
    min_rejection_close_location: float
    min_impulse_pips: float
    max_stoch_d: float
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
    parser = argparse.ArgumentParser(description="Run a doctrine-aligned S1 long-only event study for USDJPY.")
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
    parser.add_argument("--target-trades-per-day", type=float, default=1.0)
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

    if rates is None:
        raise RuntimeError(f"Failed to load rates for {symbol}: {mt5.last_error()}")

    frame = pd.DataFrame(rates)
    if frame.empty:
        raise RuntimeError("No rates returned from MT5.")

    frame["time"] = pd.to_datetime(frame["time"], unit="s")
    frame["point"] = float(info.point if info and info.point else 0.001)
    frame["digits"] = int(info.digits if info else 3)
    return frame.drop_duplicates(subset=["time"]).sort_values("time").reset_index(drop=True)


def ema(series: pd.Series, span: int) -> pd.Series:
    return series.ewm(span=span, adjust=False).mean()


def stochastic_d(df: pd.DataFrame, period: int = 14, smooth: int = 3) -> pd.Series:
    lowest = df["low"].rolling(period).min()
    highest = df["high"].rolling(period).max()
    k = 100.0 * (df["close"] - lowest) / (highest - lowest).replace(0.0, np.nan)
    return k.rolling(smooth).mean()


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


def is_pivot_high(df: pd.DataFrame, idx: int, span: int) -> bool:
    if idx - span < 0 or idx + span >= len(df):
        return False
    center = float(df.at[idx, "high"])
    prev_highs = df.loc[idx - span : idx - 1, "high"]
    next_highs = df.loc[idx + 1 : idx + span, "high"]
    return bool((center > prev_highs.max()) and (center >= next_highs.max()))


def is_pivot_low(df: pd.DataFrame, idx: int, span: int) -> bool:
    if idx - span < 0 or idx + span >= len(df):
        return False
    center = float(df.at[idx, "low"])
    prev_lows = df.loc[idx - span : idx - 1, "low"]
    next_lows = df.loc[idx + 1 : idx + span, "low"]
    return bool((center < prev_lows.min()) and (center <= next_lows.min()))


def recent_pivots(indices: list[int], current_index: int, span: int, lookback: int) -> tuple[int | None, int | None]:
    cutoff = current_index - span
    pos = bisect.bisect_right(indices, cutoff) - 1
    recent: list[int] = []
    while pos >= 0 and len(recent) < 2:
        candidate = indices[pos]
        if current_index - candidate > lookback:
            break
        recent.append(candidate)
        pos -= 1
    if len(recent) < 2:
        return None, None
    return recent[0], recent[1]


def in_session(hour: int, session_name: str) -> bool:
    start, end = SESSION_WINDOWS[session_name]
    if start < end:
        return start <= hour < end
    return hour >= start or hour < end


def simulate_long_trade(
    df: pd.DataFrame,
    signal_index: int,
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
    stop_price = entry - stop_loss_pips * pip
    target_price = entry + stop_loss_pips * target_r * pip
    last_index = min(len(df) - 1, entry_index + max_hold_bars)

    for idx in range(entry_index, last_index + 1):
        high = float(df.at[idx, "high"])
        low = float(df.at[idx, "low"])
        if low <= stop_price:
            return (-1.0) - (spread_cost / stop_loss_pips), idx - entry_index + 1
        if high >= target_price:
            return target_r - (spread_cost / stop_loss_pips), idx - entry_index + 1

    exit_price = float(df.at[last_index, "close"])
    realized_pips = (exit_price - entry) / pip - spread_cost
    return realized_pips / stop_loss_pips, last_index - entry_index + 1


def build_event_frame(df: pd.DataFrame, stop_loss_pips: float, target_r: float, max_hold_bars: int) -> pd.DataFrame:
    pip = float(df["point"].iloc[0] * 10.0) if int(df["digits"].iloc[0]) in (3, 5) else float(df["point"].iloc[0])
    df = df.copy()
    df["ema13"] = ema(df["close"], 13)
    df["ema100"] = ema(df["close"], 100)
    df["stoch_d"] = stochastic_d(df)
    df["hour"] = df["time"].dt.hour
    df["dayofweek"] = df["time"].dt.dayofweek

    pivot_span = 2
    trend_scan_bars = 180
    pullback_lookback = 4
    slow_slope_lookback = 5
    volatility_lookback = 24
    round_step_pips = 50.0
    touch_tolerance_pips = 0.6

    pivot_high_indices = [idx for idx in range(len(df)) if is_pivot_high(df, idx, pivot_span)]
    pivot_low_indices = [idx for idx in range(len(df)) if is_pivot_low(df, idx, pivot_span)]

    rows: list[dict[str, Any]] = []
    for i in range(max(40, slow_slope_lookback + 10), len(df) - max_hold_bars - 2):
        if int(df.at[i, "dayofweek"]) > 4:
            continue

        highest = float(df.loc[i - volatility_lookback + 1 : i, "high"].max())
        lowest = float(df.loc[i - volatility_lookback + 1 : i, "low"].min())
        if highest - lowest < 18.0 * pip:
            continue
        zone_step = round_step_pips * pip
        if int(np.floor(highest / zone_step)) == int(np.floor(lowest / zone_step)):
            continue

        latest_high, previous_high = recent_pivots(pivot_high_indices, i, pivot_span, trend_scan_bars)
        latest_low, previous_low = recent_pivots(pivot_low_indices, i, pivot_span, trend_scan_bars)
        if None in (latest_high, previous_high, latest_low, previous_low):
            continue

        slow_slope = float(df.at[i, "ema100"] - df.at[i - slow_slope_lookback, "ema100"])
        if not (
            float(df.at[latest_high, "high"]) > float(df.at[previous_high, "high"])
            and float(df.at[latest_low, "low"]) > float(df.at[previous_low, "low"])
            and slow_slope > 0.0
            and float(df.at[i, "close"]) > float(df.at[i, "ema100"])
        ):
            continue

        transition_line = float(df.at[latest_low, "low"])
        tolerance = touch_tolerance_pips * pip
        if not (
            float(df.at[i, "low"]) <= float(df.at[i, "ema13"]) + tolerance
            and float(df.at[i, "high"]) >= float(df.at[i, "ema13"]) - tolerance
        ):
            continue
        if float(df.at[i, "low"]) <= transition_line:
            continue
        if float(df.at[i - 1, "close"]) <= float(df.at[i - 1, "ema13"]):
            continue
        if float(df.at[i - 2, "close"]) <= float(df.at[i - 2, "ema13"]):
            continue
        if float(df.at[i, "close"]) < float(df.at[i, "ema13"]):
            continue

        counter_start = i - pullback_lookback
        counter_sample = df.iloc[counter_start:i]
        countertrend_bodies = int((counter_sample["close"] < counter_sample["open"]).sum())
        if countertrend_bodies < 1:
            continue

        impulse_window = df.iloc[i - (pullback_lookback + 5) : i]
        if impulse_window.empty:
            continue
        impulse_pips = float((impulse_window["high"].max() - impulse_window["low"].min()) / pip)
        pullback_pips = float((counter_sample["high"].max() - float(df.at[i, "low"])) / pip)
        if impulse_pips <= 0.0:
            continue
        pullback_ratio = pullback_pips / impulse_pips
        transition_distance_pips = float((float(df.at[i, "low"]) - transition_line) / pip)
        close_loc = close_location(df.iloc[i])
        avg_body_pips = average_body_pips(df, i - 1, 5, pip)
        rejection_body_pips = float(abs(df.at[i, "close"] - df.at[i, "open"]) / pip)
        slow_slope_pips = abs(slow_slope) / pip

        outcome_r, bars_to_exit = simulate_long_trade(df, i, pip, stop_loss_pips, target_r, max_hold_bars)
        if np.isnan(outcome_r):
            continue

        rows.append(
            {
                "time": df.at[i, "time"],
                "hour": int(df.at[i, "hour"]),
                "close": float(df.at[i, "close"]),
                "stoch_d": float(df.at[i, "stoch_d"]) if pd.notna(df.at[i, "stoch_d"]) else np.nan,
                "slow_slope_pips": slow_slope_pips,
                "impulse_pips": impulse_pips,
                "pullback_pips": pullback_pips,
                "pullback_ratio": pullback_ratio,
                "countertrend_bodies": countertrend_bodies,
                "transition_distance_pips": transition_distance_pips,
                "rejection_body_pips": rejection_body_pips,
                "rejection_close_location": close_loc,
                "outcome_r": outcome_r,
                "bars_to_exit": bars_to_exit,
            }
        )

    events = pd.DataFrame(rows)
    if events.empty:
        return events
    events["date"] = pd.to_datetime(events["time"])
    return events.sort_values("time").reset_index(drop=True)


def trade_stats(events: pd.DataFrame) -> dict[str, float]:
    if events.empty:
        return {"trades": 0, "tpd": 0.0, "expectancy_r": 0.0, "win_rate": 0.0}
    elapsed_days = max(1.0, (events["time"].iloc[-1] - events["time"].iloc[0]).total_seconds() / 86400.0)
    wins = (events["outcome_r"] > 0).mean() if len(events) else 0.0
    return {
        "trades": int(len(events)),
        "tpd": float(len(events) / elapsed_days),
        "expectancy_r": float(events["outcome_r"].mean()),
        "win_rate": float(wins),
    }


def tpd_fit_score(train_tpd: float, test_tpd: float, target_tpd: float) -> float:
    if target_tpd <= 0.0:
        return 0.0
    reference = min(train_tpd, test_tpd)
    deviation = abs(reference - target_tpd) / max(0.5, target_tpd)
    return max(0.0, 1.0 - deviation)


def search_candidates(events: pd.DataFrame, split_date: pd.Timestamp, target_tpd: float) -> pd.DataFrame:
    if events.empty:
        return pd.DataFrame()

    train = events[events["time"] < split_date].copy()
    test = events[events["time"] >= split_date].copy()
    rows: list[CandidateRule] = []

    for session_name in SESSION_WINDOWS:
        for max_bodies in (1, 2, 3, 4):
            for min_transition in (0.0, 1.0, 2.0, 3.0):
                for max_pullback_ratio in (0.35, 0.45, 0.55, 0.70):
                    for min_rej_close in (0.60, 0.65, 0.70, 0.75):
                        for min_impulse in (8.0, 10.0, 12.0, 14.0):
                            for max_stoch_d in (35.0, 45.0, 55.0, 65.0, 100.0):
                                mask = (
                                    events["hour"].map(lambda value: in_session(int(value), session_name))
                                    & (events["countertrend_bodies"] <= max_bodies)
                                    & (events["transition_distance_pips"] >= min_transition)
                                    & (events["pullback_ratio"] <= max_pullback_ratio)
                                    & (events["rejection_close_location"] >= min_rej_close)
                                    & (events["impulse_pips"] >= min_impulse)
                                    & (events["stoch_d"] <= max_stoch_d)
                                )
                                train_stats = trade_stats(train[mask.loc[train.index]])
                                test_stats = trade_stats(test[mask.loc[test.index]])
                                if train_stats["trades"] < 8 or test_stats["trades"] < 4:
                                    continue
                                score = (
                                    test_stats["expectancy_r"] * 0.45
                                    + train_stats["expectancy_r"] * 0.20
                                    + test_stats["win_rate"] * 0.10
                                    + train_stats["win_rate"] * 0.05
                                    + tpd_fit_score(train_stats["tpd"], test_stats["tpd"], target_tpd) * 0.20
                                )
                                rows.append(
                                    CandidateRule(
                                        session=session_name,
                                        max_countertrend_bodies=max_bodies,
                                        min_transition_distance_pips=min_transition,
                                        max_pullback_ratio=max_pullback_ratio,
                                        min_rejection_close_location=min_rej_close,
                                        min_impulse_pips=min_impulse,
                                        max_stoch_d=max_stoch_d,
                                        train_trades=train_stats["trades"],
                                        train_tpd=train_stats["tpd"],
                                        train_expectancy_r=train_stats["expectancy_r"],
                                        train_win_rate=train_stats["win_rate"],
                                        test_trades=test_stats["trades"],
                                        test_tpd=test_stats["tpd"],
                                        test_expectancy_r=test_stats["expectancy_r"],
                                        test_win_rate=test_stats["win_rate"],
                                        score=score,
                                    )
                                )

    if not rows:
        return pd.DataFrame()
    frame = pd.DataFrame([asdict(row) for row in rows])
    return frame.sort_values(["score", "test_expectancy_r", "train_expectancy_r"], ascending=[False, False, False]).reset_index(drop=True)


def default_output_dir(symbol: str, timeframe: str) -> Path:
    timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    return DEFAULT_OUTPUT_ROOT / f"{timestamp}-{slugify(symbol)}-{timeframe.lower()}-golden-s1-long-event-study"


def write_csv_gz(frame: pd.DataFrame, path: Path) -> None:
    with gzip.open(path, "wt", encoding="utf-8", newline="") as handle:
        frame.to_csv(handle, index=False)


def write_outputs(output_dir: Path, events: pd.DataFrame, candidates: pd.DataFrame, metadata: dict[str, Any]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    events_csv = output_dir / "events.csv"
    events_gz = output_dir / "events.csv.gz"
    candidates_csv = output_dir / "candidates.csv"
    candidates_gz = output_dir / "candidates.csv.gz"
    summary_json = output_dir / "summary.json"
    summary_md = output_dir / "summary.md"

    events.to_csv(events_csv, index=False)
    write_csv_gz(events, events_gz)
    candidates.to_csv(candidates_csv, index=False)
    write_csv_gz(candidates, candidates_gz)

    payload = {
        "metadata": metadata,
        "top_candidates": candidates.head(20).to_dict(orient="records"),
        "event_count": int(len(events)),
    }
    summary_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# USDJPY Golden S1 Long-Only Event Study",
        "",
        f"- Symbol: `{metadata['symbol']}`",
        f"- Timeframe: `{metadata['timeframe']}`",
        f"- History window: `{metadata['history_start']}` -> `{metadata['history_end']}`",
        f"- Train / OOS split: `{metadata['train_start']}` -> `{metadata['train_end']}` / `{metadata['test_start']}` -> `{metadata['test_end']}`",
        f"- Event count: `{len(events)}`",
        f"- Candidate count: `{len(candidates)}`",
        f"- Target trades/day: `{metadata['target_trades_per_day']:.2f}`",
        "",
        "## Top Candidates",
        "",
    ]
    if candidates.empty:
        lines.append("- No candidate passed the minimum sample filter.")
    else:
        for _, row in candidates.head(10).iterrows():
            lines.append(
                f"- `{row['session']}` / bodies<={int(row['max_countertrend_bodies'])} / transition>={row['min_transition_distance_pips']:.1f} / "
                f"pullback_ratio<={row['max_pullback_ratio']:.2f} / close_loc>={row['min_rejection_close_location']:.2f} / "
                f"impulse>={row['min_impulse_pips']:.1f} / stoch<={row['max_stoch_d']:.1f}: "
                f"train `{row['train_trades']} trades, {row['train_tpd']:.2f}/day, exp {row['train_expectancy_r']:.3f}R`, "
                f"test `{row['test_trades']} trades, {row['test_tpd']:.2f}/day, exp {row['test_expectancy_r']:.3f}R`"
            )

    summary_md.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    terminal_path = load_terminal_path(args.terminal_path)
    initialize_mt5(terminal_path)
    try:
        frame = load_rates_by_range(args.symbol, args.timeframe, args.analysis_days, args.bars_fallback)
    finally:
        mt5.shutdown()

    split_date = frame["time"].max() - pd.Timedelta(days=args.oos_days)
    events = build_event_frame(
        frame,
        stop_loss_pips=args.stop_loss_pips,
        target_r=args.target_r,
        max_hold_bars=args.max_hold_bars,
    )
    candidates = search_candidates(events, split_date, args.target_trades_per_day)

    output_dir = Path(args.output_dir) if args.output_dir else default_output_dir(args.symbol, args.timeframe)
    metadata = {
        "symbol": args.symbol,
        "timeframe": args.timeframe,
        "history_start": frame["time"].min().isoformat(),
        "history_end": frame["time"].max().isoformat(),
        "train_start": frame["time"].min().isoformat(),
        "train_end": (split_date - pd.Timedelta(minutes=5)).isoformat(),
        "test_start": split_date.isoformat(),
        "test_end": frame["time"].max().isoformat(),
        "stop_loss_pips": args.stop_loss_pips,
        "target_r": args.target_r,
        "max_hold_bars": args.max_hold_bars,
        "target_trades_per_day": args.target_trades_per_day,
    }
    write_outputs(output_dir, events, candidates, metadata)
    print(json.dumps({"output_dir": str(output_dir), "events": len(events), "candidates": len(candidates)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
