from __future__ import annotations

import argparse
import bisect
import gzip
import json
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta
from pathlib import Path

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
}


@dataclass
class CandidateRule:
    session: str
    min_window_range_pips: float
    max_ema13_distance_pips: float
    min_upper_wick_share: float
    max_lower_wick_share: float
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
    parser = argparse.ArgumentParser(description="Run a USDJPY M15 round-continuation long event study.")
    parser.add_argument("--symbol", default="USDJPY")
    parser.add_argument("--timeframe", default="M15", choices=sorted(TIMEFRAME_MAP))
    parser.add_argument("--analysis-days", type=int, default=365)
    parser.add_argument("--oos-days", type=int, default=89)
    parser.add_argument("--bars-fallback", type=int, default=140000)
    parser.add_argument("--output-dir")
    parser.add_argument("--terminal-path")
    parser.add_argument("--stop-loss-pips", type=float, default=18.0)
    parser.add_argument("--target-r", type=float, default=1.0)
    parser.add_argument("--max-hold-bars", type=int, default=12)
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


def in_session(hour: int, session_name: str) -> bool:
    start, end = SESSION_WINDOWS[session_name]
    if start < end:
        return start <= hour < end
    return hour >= start or hour < end


def is_pivot_high(df: pd.DataFrame, idx: int, span: int) -> bool:
    if idx - span < 0 or idx + span >= len(df):
        return False
    center = float(df.at[idx, "high"])
    return bool(center > df.loc[idx - span : idx - 1, "high"].max() and center >= df.loc[idx + 1 : idx + span, "high"].max())


def is_pivot_low(df: pd.DataFrame, idx: int, span: int) -> bool:
    if idx - span < 0 or idx + span >= len(df):
        return False
    center = float(df.at[idx, "low"])
    return bool(center < df.loc[idx - span : idx - 1, "low"].min() and center <= df.loc[idx + 1 : idx + span, "low"].min())


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


def upper_wick_share(row: pd.Series) -> float:
    bar_range = float(row["high"] - row["low"])
    if bar_range <= 0.0:
        return np.nan
    return float((row["high"] - max(row["open"], row["close"])) / bar_range)


def lower_wick_share(row: pd.Series) -> float:
    bar_range = float(row["high"] - row["low"])
    if bar_range <= 0.0:
        return np.nan
    return float((min(row["open"], row["close"]) - row["low"]) / bar_range)


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
    pivot_span = 2
    trend_scan_bars = 180
    slope_lookback = 5
    vol_lookback = 24
    round_step_pips = 50.0

    data = df.copy()
    data["ema13"] = ema(data["close"], 13)
    data["ema100"] = ema(data["close"], 100)
    data["ema100_slope"] = data["ema100"] - data["ema100"].shift(slope_lookback)
    data["upper_wick_share"] = data.apply(upper_wick_share, axis=1)
    data["lower_wick_share"] = data.apply(lower_wick_share, axis=1)
    data["ema13_distance_pips"] = (data["close"] - data["ema13"]).abs() / pip
    data["hour"] = data["time"].dt.hour
    data["dayofweek"] = data["time"].dt.dayofweek
    window_high = data["high"].rolling(vol_lookback).max()
    window_low = data["low"].rolling(vol_lookback).min()
    data["window_range_pips"] = (window_high - window_low) / pip
    zone_step = round_step_pips * pip
    data["same_zone"] = [
        int(np.floor(high / zone_step)) == int(np.floor(low / zone_step)) if pd.notna(high) and pd.notna(low) else False
        for high, low in zip(window_high, window_low)
    ]

    pivot_high_indices = [idx for idx in range(len(data)) if is_pivot_high(data, idx, pivot_span)]
    pivot_low_indices = [idx for idx in range(len(data)) if is_pivot_low(data, idx, pivot_span)]

    rows: list[dict[str, object]] = []
    for i in range(max(140, slope_lookback + 10), len(data) - max_hold_bars - 2):
        if int(data.at[i, "dayofweek"]) > 4:
            continue

        latest_high, previous_high = recent_pivots(pivot_high_indices, i, pivot_span, trend_scan_bars)
        latest_low, previous_low = recent_pivots(pivot_low_indices, i, pivot_span, trend_scan_bars)
        if None in (latest_high, previous_high, latest_low, previous_low):
            continue

        if not (
            float(data.at[latest_high, "high"]) > float(data.at[previous_high, "high"])
            and float(data.at[latest_low, "low"]) > float(data.at[previous_low, "low"])
            and float(data.at[i, "ema13"]) > float(data.at[i, "ema100"])
            and float(data.at[i, "ema100_slope"]) > 0.0
            and float(data.at[i, "close"]) > float(data.at[i, "ema100"])
            and float(data.at[i, "low"]) > float(data.at[latest_low, "low"])
        ):
            continue

        outcome_r, bars_to_exit = simulate_long_trade(data, i, pip, stop_loss_pips, target_r, max_hold_bars)
        if np.isnan(outcome_r):
            continue

        rows.append(
            {
                "time": data.at[i, "time"],
                "hour": int(data.at[i, "hour"]),
                "window_range_pips": float(data.at[i, "window_range_pips"]),
                "same_zone": bool(data.at[i, "same_zone"]),
                "ema13_distance_pips": float(data.at[i, "ema13_distance_pips"]),
                "upper_wick_share": float(data.at[i, "upper_wick_share"]),
                "lower_wick_share": float(data.at[i, "lower_wick_share"]),
                "outcome_r": outcome_r,
                "bars_to_exit": bars_to_exit,
            }
        )

    return pd.DataFrame(rows).sort_values("time").reset_index(drop=True)


def trade_stats(events: pd.DataFrame) -> dict[str, float]:
    if events.empty:
        return {"trades": 0, "tpd": 0.0, "expectancy_r": 0.0, "win_rate": 0.0}
    elapsed_days = max(1.0, (events["time"].iloc[-1] - events["time"].iloc[0]).total_seconds() / 86400.0)
    return {
        "trades": int(len(events)),
        "tpd": float(len(events) / elapsed_days),
        "expectancy_r": float(events["outcome_r"].mean()),
        "win_rate": float((events["outcome_r"] > 0).mean()),
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
        for min_window_range in (15.0, 18.0, 22.0, 26.0):
            for max_ema13_distance in (8.0, 10.0, 12.0, 15.0, 18.0):
                for min_upper_wick in (0.35, 0.40, 0.45, 0.50):
                    for max_lower_wick in (0.05, 0.07, 0.10, 0.15):
                        mask = (
                            events["hour"].map(lambda hour: in_session(int(hour), session_name))
                            & (events["window_range_pips"] >= min_window_range)
                            & (~events["same_zone"])
                            & (events["ema13_distance_pips"] <= max_ema13_distance)
                            & (events["upper_wick_share"] >= min_upper_wick)
                            & (events["lower_wick_share"] <= max_lower_wick)
                        )
                        train_stats = trade_stats(train[mask.loc[train.index]])
                        test_stats = trade_stats(test[mask.loc[test.index]])
                        if train_stats["trades"] < 24 or test_stats["trades"] < 8:
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
                                min_window_range_pips=min_window_range,
                                max_ema13_distance_pips=max_ema13_distance,
                                min_upper_wick_share=min_upper_wick,
                                max_lower_wick_share=max_lower_wick,
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
    return DEFAULT_OUTPUT_ROOT / f"{timestamp}-{slugify(symbol)}-{timeframe.lower()}-round-continuation-long-study"


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
        "# USDJPY Round Continuation Long Study",
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
        for _, row in candidates.head(10).iterrows():
            lines.append(
                f"- `{row['session']}` / range>={row['min_window_range_pips']:.1f} / ema13_dist<={row['max_ema13_distance_pips']:.1f} / "
                f"upper_wick>={row['min_upper_wick_share']:.2f} / lower_wick<={row['max_lower_wick_share']:.2f}: "
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
