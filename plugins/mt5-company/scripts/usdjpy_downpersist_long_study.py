from __future__ import annotations

import argparse
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
TIMEFRAME_MAP = {"M5": mt5.TIMEFRAME_M5}
SESSION_WINDOWS = {
    "all": (0, 24),
    "london_ny": (7, 22),
    "ny": (13, 22),
}


@dataclass
class CandidateRule:
    session: str
    trend_mode: str
    min_breakout_persist: int
    min_spread_z: float
    max_spread_pips: float
    cooldown_bars: int
    stop_loss_pips: float
    target_r: float
    max_hold_bars: int
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
    parser = argparse.ArgumentParser(description="Run a USDJPY M5 downside-persist long study.")
    parser.add_argument("--symbol", default="USDJPY")
    parser.add_argument("--timeframe", default="M5", choices=sorted(TIMEFRAME_MAP))
    parser.add_argument("--analysis-days", type=int, default=365)
    parser.add_argument("--oos-days", type=int, default=90)
    parser.add_argument("--bars-fallback", type=int, default=140000)
    parser.add_argument("--output-dir")
    parser.add_argument("--terminal-path")
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


def build_feature_frame(df: pd.DataFrame) -> pd.DataFrame:
    data = df.copy()
    pip = float(data["point"].iloc[0] * 10.0) if int(data["digits"].iloc[0]) in (3, 5) else float(data["point"].iloc[0])
    data["pip"] = pip
    data["ema13"] = ema(data["close"], 13)
    data["ema100"] = ema(data["close"], 100)
    data["ema100_slope_6"] = data["ema100"] - data["ema100"].shift(6)
    prev_low_12 = data["low"].rolling(12).min().shift(1)
    data["breakout_down_12"] = (data["close"] < prev_low_12).astype(int)
    data["breakout_persist_down_6"] = data["breakout_down_12"].rolling(6).sum()
    spread_pips = data["spread"] * data["point"] / pip
    data["spread_pips"] = spread_pips
    spread_mean = spread_pips.rolling(20).mean()
    spread_std = spread_pips.rolling(20).std().replace(0.0, np.nan)
    data["spread_z"] = (spread_pips - spread_mean) / spread_std
    data["hour"] = data["time"].dt.hour
    data["dayofweek"] = data["time"].dt.dayofweek
    return data


def simulate_trade(df: pd.DataFrame, signal_index: int, stop_loss_pips: float, target_r: float, max_hold_bars: int) -> tuple[float, int]:
    pip = float(df["pip"].iloc[signal_index])
    entry_index = signal_index + 1
    if entry_index >= len(df):
        return np.nan, entry_index

    entry = float(df.at[entry_index, "open"])
    spread_cost = float(df.at[entry_index, "spread_pips"])
    stop_price = entry - stop_loss_pips * pip
    target_price = entry + stop_loss_pips * target_r * pip
    last_index = min(len(df) - 1, entry_index + max_hold_bars)

    for idx in range(entry_index, last_index + 1):
        high = float(df.at[idx, "high"])
        low = float(df.at[idx, "low"])
        if low <= stop_price:
            return (-1.0) - (spread_cost / stop_loss_pips), idx
        if high >= target_price:
            return target_r - (spread_cost / stop_loss_pips), idx

    exit_price = float(df.at[last_index, "close"])
    realized_pips = (exit_price - entry) / pip - spread_cost
    return realized_pips / stop_loss_pips, last_index


def candidate_signal_mask(df: pd.DataFrame, session: str, trend_mode: str, min_breakout_persist: int, min_spread_z: float, max_spread_pips: float) -> pd.Series:
    base = (
        (df["dayofweek"] <= 4)
        & df["hour"].map(lambda hour: in_session(int(hour), session))
        & (df["breakout_persist_down_6"] >= min_breakout_persist)
        & (df["spread_z"] >= min_spread_z)
        & (df["spread_pips"] <= max_spread_pips)
    )
    if trend_mode == "ema_up":
        base &= (df["ema13"] > df["ema100"]) & (df["ema100_slope_6"] > 0.0)
    return base.fillna(False)


def simulate_candidate(
    df: pd.DataFrame,
    split_time: pd.Timestamp,
    session: str,
    trend_mode: str,
    min_breakout_persist: int,
    min_spread_z: float,
    max_spread_pips: float,
    cooldown_bars: int,
    stop_loss_pips: float,
    target_r: float,
    max_hold_bars: int,
) -> dict[str, Any]:
    mask = candidate_signal_mask(df, session, trend_mode, min_breakout_persist, min_spread_z, max_spread_pips)
    signal_indices = np.flatnonzero(mask.to_numpy())

    records: list[dict[str, Any]] = []
    next_allowed_index = 0
    for signal_index in signal_indices:
        if signal_index < 100 or signal_index <= next_allowed_index or signal_index + 1 >= len(df):
            continue
        outcome_r, exit_index = simulate_trade(df, int(signal_index), stop_loss_pips, target_r, max_hold_bars)
        if np.isnan(outcome_r):
            continue
        records.append(
            {
                "signal_time": df.at[signal_index, "time"],
                "signal_index": int(signal_index),
                "expectancy_r": float(outcome_r),
                "win": float(outcome_r > 0.0),
            }
        )
        next_allowed_index = int(exit_index) + cooldown_bars

    trades = pd.DataFrame(records)
    if trades.empty:
        return {"trades": trades, "train": None, "test": None}

    train = trades.loc[trades["signal_time"] < split_time].copy()
    test = trades.loc[trades["signal_time"] >= split_time].copy()
    return {"trades": trades, "train": train, "test": test}


def trade_stats(events: pd.DataFrame | None) -> dict[str, float]:
    if events is None or events.empty:
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


def search_candidates(df: pd.DataFrame, split_time: pd.Timestamp, target_tpd: float) -> pd.DataFrame:
    rows: list[CandidateRule] = []

    for session in ("all", "london_ny"):
        for trend_mode in ("any", "ema_up"):
            for min_breakout_persist in (1, 2):
                for min_spread_z in (0.0,):
                    for max_spread_pips in (2.0,):
                        for cooldown_bars in (0, 3):
                            for stop_loss_pips in (10.0, 12.0, 15.0):
                                for target_r in (1.0, 1.2):
                                    for max_hold_bars in (6, 12):
                                        sim = simulate_candidate(
                                            df,
                                            split_time,
                                            session,
                                            trend_mode,
                                            min_breakout_persist,
                                            min_spread_z,
                                            max_spread_pips,
                                            cooldown_bars,
                                            stop_loss_pips,
                                            target_r,
                                            max_hold_bars,
                                        )
                                        train_stats = trade_stats(sim["train"])
                                        test_stats = trade_stats(sim["test"])
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
                                                session=session,
                                                trend_mode=trend_mode,
                                                min_breakout_persist=min_breakout_persist,
                                                min_spread_z=min_spread_z,
                                                max_spread_pips=max_spread_pips,
                                                cooldown_bars=cooldown_bars,
                                                stop_loss_pips=stop_loss_pips,
                                                target_r=target_r,
                                                max_hold_bars=max_hold_bars,
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
    return DEFAULT_OUTPUT_ROOT / f"{timestamp}-{slugify(symbol)}-{timeframe.lower()}-downpersist-long-study"


def write_csv_gz(frame: pd.DataFrame, path: Path) -> None:
    with gzip.open(path, "wt", encoding="utf-8", newline="") as handle:
        frame.to_csv(handle, index=False)


def write_outputs(output_dir: Path, features: pd.DataFrame, candidates: pd.DataFrame, metadata: dict[str, object]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    feature_dump = features.loc[:, ["time", "hour", "dayofweek", "breakout_persist_down_6", "spread_z", "spread_pips", "ema13", "ema100", "ema100_slope_6"]].copy()
    feature_dump.to_csv(output_dir / "signals.csv", index=False)
    write_csv_gz(feature_dump, output_dir / "signals.csv.gz")
    candidates.to_csv(output_dir / "candidates.csv", index=False)
    write_csv_gz(candidates, output_dir / "candidates.csv.gz")

    payload = {
        "metadata": metadata,
        "top_candidates": candidates.head(20).to_dict(orient="records"),
    }
    (output_dir / "summary.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# USDJPY M5 Downside Persist Long Study",
        "",
        f"- Symbol: `{metadata['symbol']}`",
        f"- Timeframe: `{metadata['timeframe']}`",
        f"- History window: `{metadata['history_start']}` -> `{metadata['history_end']}`",
        f"- Train / OOS split: `{metadata['train_start']}` -> `{metadata['train_end']}` / `{metadata['test_start']}` -> `{metadata['test_end']}`",
        f"- Candidate count: `{len(candidates)}`",
        "",
        "## Top Candidates",
        "",
    ]
    if candidates.empty:
        lines.append("- No candidate passed the minimum sample filter.")
    else:
        for _, row in candidates.head(12).iterrows():
            lines.append(
                f"- `{row['session']}` / `{row['trend_mode']}` / persist>={row['min_breakout_persist']} / spread_z>={row['min_spread_z']:.1f} / "
                f"spread<={row['max_spread_pips']:.1f} / cooldown={row['cooldown_bars']} / stop={row['stop_loss_pips']:.1f} / "
                f"target={row['target_r']:.2f}R / hold={row['max_hold_bars']}: "
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

    feature_frame = build_feature_frame(frame)
    split_date = frame["time"].max() - pd.Timedelta(days=args.oos_days)
    candidates = search_candidates(feature_frame, split_date, args.target_trades_per_day)
    metadata = {
        "symbol": args.symbol,
        "timeframe": args.timeframe,
        "history_start": frame["time"].min().isoformat(),
        "history_end": frame["time"].max().isoformat(),
        "train_start": frame["time"].min().isoformat(),
        "train_end": (split_date - pd.Timedelta(minutes=5)).isoformat(),
        "test_start": split_date.isoformat(),
        "test_end": frame["time"].max().isoformat(),
        "target_trades_per_day": args.target_trades_per_day,
    }
    output_dir = Path(args.output_dir) if args.output_dir else default_output_dir(args.symbol, args.timeframe)
    write_outputs(output_dir, feature_frame, candidates, metadata)
    print(json.dumps({"output_dir": str(output_dir), "candidates": len(candidates)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
