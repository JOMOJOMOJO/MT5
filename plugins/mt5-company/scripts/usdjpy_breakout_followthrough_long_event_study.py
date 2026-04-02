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
TIMEFRAME_MAP = {"M15": mt5.TIMEFRAME_M15}
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
    min_zone_range_pips: float
    max_prior_touches: int
    min_breakout_body_pips: float
    min_breakout_close_location: float
    min_body_to_range: float
    min_body_vs_avg: float
    max_breakout_to_ema13_pips: float
    max_retest_delay_bars: int
    min_retest_close_location: float
    max_retest_depth_pips: float
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
    parser = argparse.ArgumentParser(description="Run a USDJPY M15 breakout-followthrough long event study.")
    parser.add_argument("--symbol", default="USDJPY")
    parser.add_argument("--timeframe", default="M15", choices=sorted(TIMEFRAME_MAP))
    parser.add_argument("--analysis-days", type=int, default=365)
    parser.add_argument("--oos-days", type=int, default=90)
    parser.add_argument("--bars-fallback", type=int, default=140000)
    parser.add_argument("--output-dir")
    parser.add_argument("--terminal-path")
    parser.add_argument("--stop-loss-pips", type=float, default=20.0)
    parser.add_argument("--target-r", type=float, default=1.2)
    parser.add_argument("--max-hold-bars", type=int, default=18)
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

    frame = pd.DataFrame(rates)
    if frame.empty:
        raise RuntimeError("No rates returned from MT5.")

    frame["time"] = pd.to_datetime(frame["time"], unit="s")
    frame["point"] = float(info.point if info and info.point else 0.001)
    frame["digits"] = int(info.digits if info else 3)
    return frame.drop_duplicates(subset=["time"]).sort_values("time").reset_index(drop=True)


def ema(series: pd.Series, span: int) -> pd.Series:
    return series.ewm(span=span, adjust=False).mean()


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


def average_body_pips(df: pd.DataFrame, index: int, lookback: int, pip: float) -> float:
    start = max(0, index - lookback + 1)
    sample = df.iloc[start : index + 1]
    if sample.empty:
        return 0.0
    return float((sample["close"] - sample["open"]).abs().mean() / pip)


def recent_high_break_pips(df: pd.DataFrame, index: int, lookback: int, pip: float) -> float:
    start = max(0, index - lookback)
    prior_high = float(df.iloc[start:index]["high"].max())
    return float((float(df.at[index, "close"]) - prior_high) / pip)


def find_breakout_level(row: pd.Series, step_price: float) -> float | None:
    start_index = int(np.floor(float(row["low"]) / step_price)) - 1
    end_index = int(np.ceil(float(row["high"]) / step_price)) + 1
    for level_index in range(start_index, end_index + 1):
        candidate = level_index * step_price
        if float(row["open"]) < candidate and float(row["close"]) > candidate:
            return float(candidate)
    return None


def count_round_touches(df: pd.DataFrame, current_index: int, round_level: float, tolerance: float, lookback: int) -> int:
    start = max(0, current_index - lookback)
    sample = df.iloc[start:current_index]
    if sample.empty:
        return 0
    touches = (sample["high"] >= round_level - tolerance) & (sample["low"] <= round_level + tolerance)
    return int(touches.sum())


def simulate_trade(
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
    step_price = 50.0 * pip
    midpoint_distance = 25.0 * pip
    touch_tolerance = 0.5 * pip
    retest_buffer = 2.0 * pip
    expiry_bars = 12
    touch_lookback = 48

    data = df.copy()
    data["ema13"] = ema(data["close"], 13)
    data["ema100"] = ema(data["close"], 100)
    data["ema100_slope"] = data["ema100"] - data["ema100"].shift(5)
    data["window_range_24"] = (data["high"].rolling(24).max() - data["low"].rolling(24).min()) / pip
    data["hour"] = data["time"].dt.hour
    data["dayofweek"] = data["time"].dt.dayofweek

    events: list[dict[str, Any]] = []
    for breakout_index in range(140, len(data) - max_hold_bars - 2):
        if int(data.at[breakout_index, "dayofweek"]) > 4:
            continue

        row = data.iloc[breakout_index]
        level = find_breakout_level(row, step_price)
        if level is None:
            continue

        breakout_close_loc = close_location(row)
        body_pips = float(abs(float(row["close"]) - float(row["open"])) / pip)
        range_pips = float((float(row["high"]) - float(row["low"])) / pip)
        if body_pips <= 0.0 or range_pips <= 0.0:
            continue

        avg_body = average_body_pips(data, breakout_index - 1, 20, pip)
        body_vs_avg = (body_pips / avg_body) if avg_body > 0.0 else np.nan
        body_to_range = body_pips / range_pips
        slow_slope_pips = float(data.at[breakout_index, "ema100_slope"] / pip)
        breakout_to_ema13_pips = float((float(row["close"]) - float(data.at[breakout_index, "ema13"])) / pip)
        high_break_12 = recent_high_break_pips(data, breakout_index, 12, pip)
        prior_touches = count_round_touches(data, breakout_index, level, touch_tolerance, touch_lookback)
        zone_range_24 = float(data.at[breakout_index, "window_range_24"])

        if not (
            slow_slope_pips > 0.0
            and float(data.at[breakout_index, "ema13"]) > float(data.at[breakout_index, "ema100"])
            and float(row["close"]) > float(data.at[breakout_index, "ema100"])
            and breakout_close_loc >= 0.55
            and high_break_12 > 0.0
        ):
            continue

        midpoint = level + midpoint_distance
        failed = False
        for signal_index in range(breakout_index + 1, min(len(data) - max_hold_bars - 1, breakout_index + expiry_bars + 1)):
            signal_bar = data.iloc[signal_index]
            if float(signal_bar["high"]) >= midpoint:
                failed = True
                break
            if float(signal_bar["close"]) < level:
                failed = True
                break

            touched_ema = float(signal_bar["low"]) <= float(data.at[signal_index, "ema13"]) + touch_tolerance
            touched_level = float(signal_bar["low"]) <= level + retest_buffer
            if not (touched_ema or touched_level):
                continue
            if float(signal_bar["close"]) <= float(data.at[signal_index, "ema13"]):
                continue
            if float(signal_bar["close"]) <= level:
                continue

            retest_depth_pips = max(0.0, (level - float(signal_bar["low"])) / pip)
            retest_close_loc = close_location(signal_bar)
            expectancy_r, hold_bars = simulate_trade(data, signal_index, pip, stop_loss_pips, target_r, max_hold_bars)
            events.append(
                {
                    "breakout_time": data.at[breakout_index, "time"],
                    "signal_time": data.at[signal_index, "time"],
                    "breakout_hour": int(data.at[breakout_index, "hour"]),
                    "signal_hour": int(data.at[signal_index, "hour"]),
                    "level_price": level,
                    "prior_touches": prior_touches,
                    "body_pips": body_pips,
                    "range_pips": range_pips,
                    "body_to_range": body_to_range,
                    "body_vs_avg": body_vs_avg,
                    "breakout_close_location": breakout_close_loc,
                    "breakout_to_ema13_pips": breakout_to_ema13_pips,
                    "zone_range_24": zone_range_24,
                    "high_break_12": high_break_12,
                    "retest_delay_bars": signal_index - breakout_index,
                    "retest_close_location": retest_close_loc,
                    "retest_depth_pips": retest_depth_pips,
                    "expectancy_r": expectancy_r,
                    "win": float(expectancy_r > 0.0),
                    "hold_bars": hold_bars,
                }
            )
            failed = True
            break

        if not failed:
            continue

    return pd.DataFrame(events)


def trade_stats(events: pd.DataFrame) -> dict[str, float]:
    if events.empty:
        return {"trades": 0, "tpd": 0.0, "expectancy_r": 0.0, "win_rate": 0.0}
    elapsed_days = max(1.0, (events["signal_time"].iloc[-1] - events["signal_time"].iloc[0]).total_seconds() / 86400.0)
    return {
        "trades": int(len(events)),
        "tpd": float(len(events) / elapsed_days),
        "expectancy_r": float(events["expectancy_r"].mean()),
        "win_rate": float(events["win"].mean()),
    }


def tpd_fit_score(train_tpd: float, test_tpd: float, target_tpd: float) -> float:
    if target_tpd <= 0.0:
        return 0.0
    reference = min(train_tpd, test_tpd)
    deviation = abs(reference - target_tpd) / max(0.5, target_tpd)
    return max(0.0, 1.0 - deviation)


def search_candidates(events: pd.DataFrame, split_time: pd.Timestamp, target_tpd: float) -> pd.DataFrame:
    if events.empty:
        return pd.DataFrame()

    train = events.loc[events["signal_time"] < split_time].copy()
    test = events.loc[events["signal_time"] >= split_time].copy()
    rows: list[CandidateRule] = []

    for session in ("all", "london_ny", "ny"):
        for min_zone_range in (25.0, 35.0, 45.0):
            for max_prior_touches in (1, 2):
                for min_breakout_body_pips in (6.0, 8.0, 10.0):
                    for min_breakout_close_location in (0.65, 0.75):
                        for min_body_to_range in (0.60, 0.75):
                            for min_body_vs_avg in (1.0, 1.4):
                                for max_breakout_to_ema13 in (8.0, 12.0):
                                    for max_retest_delay_bars in (3, 6, 12):
                                        for min_retest_close_location in (0.55, 0.65):
                                            for max_retest_depth_pips in (3.0, 6.0, 10.0):
                                                mask = (
                                                    events["signal_hour"].map(lambda hour: in_session(int(hour), session))
                                                    & (events["zone_range_24"] >= min_zone_range)
                                                    & (events["prior_touches"] <= max_prior_touches)
                                                    & (events["body_pips"] >= min_breakout_body_pips)
                                                    & (events["breakout_close_location"] >= min_breakout_close_location)
                                                    & (events["body_to_range"] >= min_body_to_range)
                                                    & (events["body_vs_avg"] >= min_body_vs_avg)
                                                    & (events["breakout_to_ema13_pips"] <= max_breakout_to_ema13)
                                                    & (events["retest_delay_bars"] <= max_retest_delay_bars)
                                                    & (events["retest_close_location"] >= min_retest_close_location)
                                                    & (events["retest_depth_pips"] <= max_retest_depth_pips)
                                                )
                                                train_stats = trade_stats(train[mask.loc[train.index]])
                                                test_stats = trade_stats(test[mask.loc[test.index]])
                                                if train_stats["trades"] < 12 or test_stats["trades"] < 4:
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
                                                        session=session,
                                                        min_zone_range_pips=min_zone_range,
                                                        max_prior_touches=max_prior_touches,
                                                        min_breakout_body_pips=min_breakout_body_pips,
                                                        min_breakout_close_location=min_breakout_close_location,
                                                        min_body_to_range=min_body_to_range,
                                                        min_body_vs_avg=min_body_vs_avg,
                                                        max_breakout_to_ema13_pips=max_breakout_to_ema13,
                                                        max_retest_delay_bars=max_retest_delay_bars,
                                                        min_retest_close_location=min_retest_close_location,
                                                        max_retest_depth_pips=max_retest_depth_pips,
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

    return pd.DataFrame([asdict(row) for row in rows]).sort_values(
        ["score", "test_expectancy_r", "train_expectancy_r"],
        ascending=[False, False, False],
    ).reset_index(drop=True)


def default_output_dir(symbol: str, timeframe: str) -> Path:
    timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    return DEFAULT_OUTPUT_ROOT / f"{timestamp}-{slugify(symbol)}-{timeframe.lower()}-breakout-followthrough-long-study"


def write_csv_gz(frame: pd.DataFrame, path: Path) -> None:
    with gzip.open(path, "wt", encoding="utf-8", newline="") as handle:
        frame.to_csv(handle, index=False)


def write_outputs(output_dir: Path, events: pd.DataFrame, candidates: pd.DataFrame, metadata: dict[str, object]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    events.to_csv(output_dir / "events.csv", index=False)
    write_csv_gz(events, output_dir / "events.csv.gz")
    candidates.to_csv(output_dir / "candidates.csv", index=False)
    write_csv_gz(candidates, output_dir / "candidates.csv.gz")

    payload = {
        "metadata": metadata,
        "event_count": int(len(events)),
        "top_candidates": candidates.head(20).to_dict(orient="records"),
    }
    (output_dir / "summary.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# USDJPY Breakout Followthrough Long Study",
        "",
        f"- Symbol: `{metadata['symbol']}`",
        f"- Timeframe: `{metadata['timeframe']}`",
        f"- History window: `{metadata['history_start']}` -> `{metadata['history_end']}`",
        f"- Train / OOS split: `{metadata['train_start']}` -> `{metadata['train_end']}` / `{metadata['test_start']}` -> `{metadata['test_end']}`",
        f"- Event count: `{len(events)}`",
        f"- Candidate count: `{len(candidates)}`",
        f"- Stop / target / hold: `{metadata['stop_loss_pips']:.1f} pips / {metadata['target_r']:.2f}R / {metadata['max_hold_bars']} bars`",
        "",
        "## Top Candidates",
        "",
    ]
    if candidates.empty:
        lines.append("- No candidate passed the minimum sample filter.")
    else:
        for _, row in candidates.head(12).iterrows():
            lines.append(
                f"- `{row['session']}` / zone>={row['min_zone_range_pips']:.1f} / touches<={row['max_prior_touches']}` / "
                f"body>={row['min_breakout_body_pips']:.1f} / breakout_close>={row['min_breakout_close_location']:.2f} / "
                f"body_range>={row['min_body_to_range']:.2f} / body_vs_avg>={row['min_body_vs_avg']:.2f} / "
                f"breakout_ema13<={row['max_breakout_to_ema13_pips']:.1f} / delay<={row['max_retest_delay_bars']} / "
                f"retest_close>={row['min_retest_close_location']:.2f} / retest_depth<={row['max_retest_depth_pips']:.1f}: "
                f"train `{row['train_trades']} trades, {row['train_tpd']:.2f}/day, exp {row['train_expectancy_r']:.3f}R`, "
                f"test `{row['test_trades']} trades, {row['test_tpd']:.2f}/day, exp {row['test_expectancy_r']:.3f}R`"
            )
    (output_dir / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    terminal_path = load_terminal_path(args.terminal_path)
    initialize_mt5(terminal_path)
    try:
        frame = load_rates_by_range(args.symbol, args.timeframe, args.analysis_days, args.bars_fallback)
    finally:
        mt5.shutdown()

    split_date = frame["time"].max() - pd.Timedelta(days=args.oos_days)
    events = build_event_frame(frame, args.stop_loss_pips, args.target_r, args.max_hold_bars)
    candidates = search_candidates(events, split_date, args.target_trades_per_day)

    metadata = {
        "symbol": args.symbol,
        "timeframe": args.timeframe,
        "history_start": frame["time"].min().isoformat(),
        "history_end": frame["time"].max().isoformat(),
        "train_start": frame["time"].min().isoformat(),
        "train_end": (split_date - pd.Timedelta(minutes=15)).isoformat(),
        "test_start": split_date.isoformat(),
        "test_end": frame["time"].max().isoformat(),
        "stop_loss_pips": args.stop_loss_pips,
        "target_r": args.target_r,
        "max_hold_bars": args.max_hold_bars,
        "target_trades_per_day": args.target_trades_per_day,
    }
    output_dir = Path(args.output_dir) if args.output_dir else default_output_dir(args.symbol, args.timeframe)
    write_outputs(output_dir, events, candidates, metadata)
    print(json.dumps({"output_dir": str(output_dir), "events": len(events), "candidates": len(candidates)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
