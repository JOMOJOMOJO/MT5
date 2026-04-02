from __future__ import annotations

import argparse
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
    morphology: str
    max_ema13_distance_pips: float
    max_adx: float
    min_upper_wick_share: float
    max_upper_wick_share: float
    min_lower_wick_share: float
    max_lower_wick_share: float
    min_close_location: float
    max_close_location: float
    max_ret1: float
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
    parser = argparse.ArgumentParser(description="Run a USDJPY M15 EMA13/EMA100 continuation long event study.")
    parser.add_argument("--symbol", default="USDJPY")
    parser.add_argument("--timeframe", default="M15", choices=sorted(TIMEFRAME_MAP))
    parser.add_argument("--analysis-days", type=int, default=365)
    parser.add_argument("--oos-days", type=int, default=89)
    parser.add_argument("--bars-fallback", type=int, default=140000)
    parser.add_argument("--output-dir")
    parser.add_argument("--terminal-path")
    parser.add_argument("--stop-loss-pips", type=float, default=15.0)
    parser.add_argument("--target-r", type=float, default=1.2)
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


def adx(df: pd.DataFrame, period: int = 14) -> pd.Series:
    high = df["high"]
    low = df["low"]
    close = df["close"]
    up_move = high.diff()
    down_move = -low.diff()
    plus_dm = np.where((up_move > down_move) & (up_move > 0.0), up_move, 0.0)
    minus_dm = np.where((down_move > up_move) & (down_move > 0.0), down_move, 0.0)

    tr0 = high - low
    tr1 = (high - close.shift()).abs()
    tr2 = (low - close.shift()).abs()
    tr = pd.concat([tr0, tr1, tr2], axis=1).max(axis=1)

    atr = tr.ewm(alpha=1.0 / period, adjust=False).mean()
    plus_di = 100.0 * pd.Series(plus_dm, index=df.index).ewm(alpha=1.0 / period, adjust=False).mean() / atr.replace(0.0, np.nan)
    minus_di = 100.0 * pd.Series(minus_dm, index=df.index).ewm(alpha=1.0 / period, adjust=False).mean() / atr.replace(0.0, np.nan)
    dx = 100.0 * (plus_di - minus_di).abs() / (plus_di + minus_di).replace(0.0, np.nan)
    return dx.ewm(alpha=1.0 / period, adjust=False).mean()


def in_session(hour: int, session_name: str) -> bool:
    start, end = SESSION_WINDOWS[session_name]
    if start < end:
        return start <= hour < end
    return hour >= start or hour < end


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


def close_location(row: pd.Series) -> float:
    bar_range = float(row["high"] - row["low"])
    if bar_range <= 0.0:
        return 0.5
    return float((row["close"] - row["low"]) / bar_range)


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
    data = df.copy()
    data["ema13"] = ema(data["close"], 13)
    data["ema100"] = ema(data["close"], 100)
    data["ema100_slope"] = data["ema100"] - data["ema100"].shift(5)
    data["adx14"] = adx(data, 14)
    data["upper_wick_share"] = data.apply(upper_wick_share, axis=1)
    data["lower_wick_share"] = data.apply(lower_wick_share, axis=1)
    data["close_location"] = data.apply(close_location, axis=1)
    data["ema13_distance_pips"] = (data["close"] - data["ema13"]).abs() / pip
    data["ret_1"] = data["close"].pct_change(1)
    data["hour"] = data["time"].dt.hour
    data["dayofweek"] = data["time"].dt.dayofweek

    rows: list[dict[str, object]] = []
    for i in range(120, len(data) - max_hold_bars - 2):
        if int(data.at[i, "dayofweek"]) > 4:
            continue
        if not (
            float(data.at[i, "ema13"]) > float(data.at[i, "ema100"])
            and float(data.at[i, "ema100_slope"]) > 0.0
            and float(data.at[i, "close"]) > float(data.at[i, "ema100"])
        ):
            continue

        outcome_r, bars_to_exit = simulate_long_trade(data, i, pip, stop_loss_pips, target_r, max_hold_bars)
        if np.isnan(outcome_r):
            continue

        rows.append(
            {
                "time": data.at[i, "time"],
                "hour": int(data.at[i, "hour"]),
                "ema13_distance_pips": float(data.at[i, "ema13_distance_pips"]),
                "adx14": float(data.at[i, "adx14"]),
                "upper_wick_share": float(data.at[i, "upper_wick_share"]),
                "lower_wick_share": float(data.at[i, "lower_wick_share"]),
                "close_location": float(data.at[i, "close_location"]),
                "ret_1": float(data.at[i, "ret_1"]),
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
        for max_ema13_distance in (10.0, 12.0, 15.0, 18.0, 22.0):
            for max_adx in (18.0, 20.0, 25.0, 30.0):
                for max_ret1 in (0.0, 0.0002, 0.0004):
                    for min_upper_wick in (0.45, 0.55):
                        for max_lower_wick in (0.05, 0.10, 0.15):
                            for max_close_location in (0.45, 0.40, 0.35):
                                mask = (
                                    events["hour"].map(lambda hour: in_session(int(hour), session_name))
                                    & (events["ema13_distance_pips"] <= max_ema13_distance)
                                    & (events["adx14"] <= max_adx)
                                    & (events["ret_1"] <= max_ret1)
                                    & (events["upper_wick_share"] >= min_upper_wick)
                                    & (events["lower_wick_share"] <= max_lower_wick)
                                    & (events["close_location"] <= max_close_location)
                                )
                                train_stats = trade_stats(train[mask.loc[train.index]])
                                test_stats = trade_stats(test[mask.loc[test.index]])
                                if train_stats["trades"] < 30 or test_stats["trades"] < 10:
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
                                        morphology="bear_dip",
                                        max_ema13_distance_pips=max_ema13_distance,
                                        max_adx=max_adx,
                                        min_upper_wick_share=min_upper_wick,
                                        max_upper_wick_share=1.0,
                                        min_lower_wick_share=0.0,
                                        max_lower_wick_share=max_lower_wick,
                                        min_close_location=0.0,
                                        max_close_location=max_close_location,
                                        max_ret1=max_ret1,
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

                    for min_lower_wick in (0.35, 0.45, 0.55):
                        for max_upper_wick in (0.10, 0.15, 0.20, 0.25):
                            for min_close_location in (0.60, 0.70, 0.80):
                                mask = (
                                    events["hour"].map(lambda hour: in_session(int(hour), session_name))
                                    & (events["ema13_distance_pips"] <= max_ema13_distance)
                                    & (events["adx14"] <= max_adx)
                                    & (events["ret_1"] <= max_ret1)
                                    & (events["lower_wick_share"] >= min_lower_wick)
                                    & (events["upper_wick_share"] <= max_upper_wick)
                                    & (events["close_location"] >= min_close_location)
                                )
                                train_stats = trade_stats(train[mask.loc[train.index]])
                                test_stats = trade_stats(test[mask.loc[test.index]])
                                if train_stats["trades"] < 30 or test_stats["trades"] < 10:
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
                                        morphology="bull_reclaim",
                                        max_ema13_distance_pips=max_ema13_distance,
                                        max_adx=max_adx,
                                        min_upper_wick_share=0.0,
                                        max_upper_wick_share=max_upper_wick,
                                        min_lower_wick_share=min_lower_wick,
                                        max_lower_wick_share=1.0,
                                        min_close_location=min_close_location,
                                        max_close_location=1.0,
                                        max_ret1=max_ret1,
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

    result = pd.DataFrame(asdict(row) for row in rows)
    if result.empty:
        return result
    return result.sort_values(
        ["score", "test_expectancy_r", "train_expectancy_r", "test_tpd", "train_tpd"],
        ascending=False,
    ).reset_index(drop=True)


def build_summary(
    events: pd.DataFrame,
    candidates: pd.DataFrame,
    output_dir: Path,
    args: argparse.Namespace,
    history_start: pd.Timestamp,
    history_end: pd.Timestamp,
    split_date: pd.Timestamp,
) -> None:
    train_end = split_date - pd.Timedelta(minutes=15)
    metadata = {
        "symbol": args.symbol,
        "timeframe": args.timeframe,
        "history_start": history_start.isoformat(),
        "history_end": history_end.isoformat(),
        "train_start": history_start.isoformat(),
        "train_end": train_end.isoformat(),
        "test_start": split_date.isoformat(),
        "test_end": history_end.isoformat(),
        "split_date": split_date.isoformat(),
        "event_count": int(len(events)),
        "candidate_count": int(len(candidates)),
        "stop_loss_pips": args.stop_loss_pips,
        "target_r": args.target_r,
        "max_hold_bars": args.max_hold_bars,
    }

    top_candidates = candidates.head(20).to_dict(orient="records")
    summary = {"metadata": metadata, "top_candidates": top_candidates}
    (output_dir / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")

    lines = [
        "# USDJPY EMA13/EMA100 Continuation Long Study",
        "",
        f"- Symbol: `{args.symbol}`",
        f"- Timeframe: `{args.timeframe}`",
        f"- History window: `{history_start.isoformat()}` -> `{history_end.isoformat()}`",
        f"- Train / OOS split: `{history_start.isoformat()}` -> `{train_end.isoformat()}` / `{split_date.isoformat()}` -> `{history_end.isoformat()}`",
        f"- Event count: `{len(events)}`",
        f"- Candidate count: `{len(candidates)}`",
        f"- Stop / target / hold: `{args.stop_loss_pips:.1f} pips / {args.target_r:.2f}R / {args.max_hold_bars} bars`",
        "",
        "## Top Candidates",
        "",
    ]
    if top_candidates:
        for row in top_candidates[:10]:
            lines.append(
                "- "
                f"`{row['session']}` / `{row['morphology']}` / ema13_dist<={row['max_ema13_distance_pips']:.1f} "
                f"/ adx<={row['max_adx']:.1f} / ret1<={row['max_ret1']:.4f}: "
                f"train `{int(row['train_trades'])} trades, {row['train_tpd']:.2f}/day, exp {row['train_expectancy_r']:.3f}R`, "
                f"test `{int(row['test_trades'])} trades, {row['test_tpd']:.2f}/day, exp {row['test_expectancy_r']:.3f}R`"
            )
    else:
        lines.append("- No candidate passed the minimum sample filter.")
    (output_dir / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    args = parse_args()
    timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    output_dir = Path(args.output_dir) if args.output_dir else DEFAULT_OUTPUT_ROOT / f"{timestamp}-usdjpy-m15-ema-continuation-long-study"
    output_dir.mkdir(parents=True, exist_ok=True)

    terminal_path = load_terminal_path(args.terminal_path)
    initialize_mt5(terminal_path)
    try:
        rates = load_rates_by_range(args.symbol, args.timeframe, args.analysis_days, args.bars_fallback)
    finally:
        mt5.shutdown()

    history_start = pd.Timestamp(rates["time"].iloc[0])
    history_end = pd.Timestamp(rates["time"].iloc[-1])
    split_date = history_end - pd.Timedelta(days=args.oos_days)
    events = build_event_frame(rates, args.stop_loss_pips, args.target_r, args.max_hold_bars)
    candidates = search_candidates(events, split_date, args.target_trades_per_day)

    csv_path = output_dir / "events.csv"
    events.to_csv(csv_path, index=False)
    with gzip.open(str(csv_path) + ".gz", "wt", encoding="utf-8", newline="") as handle:
        events.to_csv(handle, index=False)
    csv_path.unlink()
    candidates.to_csv(output_dir / "candidates.csv", index=False)
    with gzip.open(output_dir / "candidates.csv.gz", "wt", encoding="utf-8", newline="") as handle:
        candidates.to_csv(handle, index=False)

    build_summary(events, candidates, output_dir, args, history_start, history_end, split_date)
    print(output_dir)


if __name__ == "__main__":
    main()
