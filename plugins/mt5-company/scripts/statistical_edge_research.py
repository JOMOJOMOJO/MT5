from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

import MetaTrader5 as mt5
import numpy as np
import pandas as pd


REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_OUTPUT_ROOT = REPO_ROOT / "reports" / "research"
ORIGIN_PATH = REPO_ROOT.parents[2] / "origin.txt"
TIMEFRAME_MAP = {
    "M1": mt5.TIMEFRAME_M1,
    "M5": mt5.TIMEFRAME_M5,
    "M15": mt5.TIMEFRAME_M15,
    "M30": mt5.TIMEFRAME_M30,
    "H1": mt5.TIMEFRAME_H1,
}
SESSION_WINDOWS = {
    "asia": (0, 8),
    "london": (7, 16),
    "ny": (13, 22),
    "late": (20, 24),
}


@dataclass
class Candidate:
    family: str
    side: str
    trend: str
    hours: str
    hold: int
    dist: float
    rsi: float
    train_pf: float
    train_tpd: float
    train_exp: float
    test_pf: float
    test_tpd: float
    test_exp: float
    test_trades: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Mine MT5 bar data for statistical edge candidates.")
    parser.add_argument("--symbol", default="BTCUSD")
    parser.add_argument("--timeframe", default="M5", choices=sorted(TIMEFRAME_MAP))
    parser.add_argument("--bars", type=int, default=50000)
    parser.add_argument("--split-date", default="2026-01-01")
    parser.add_argument("--min-trades", type=int, default=250)
    parser.add_argument("--min-trades-per-day", type=float, default=5.0)
    parser.add_argument("--output-dir")
    parser.add_argument("--terminal-path")
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


def load_rates(symbol: str, timeframe_label: str, bars: int) -> pd.DataFrame:
    timeframe = TIMEFRAME_MAP[timeframe_label]
    if not mt5.symbol_select(symbol, True):
        raise RuntimeError(f"Failed to select symbol {symbol}: {mt5.last_error()}")
    rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, bars)
    if rates is None:
        raise RuntimeError(f"Failed to copy rates: {mt5.last_error()}")
    frame = pd.DataFrame(rates)
    if frame.empty:
        raise RuntimeError("No rates were returned from MT5.")
    frame["time"] = pd.to_datetime(frame["time"], unit="s")
    frame = frame.drop_duplicates(subset=["time"]).sort_values("time").reset_index(drop=True)
    return frame


def enrich_features(frame: pd.DataFrame) -> pd.DataFrame:
    df = frame.copy()
    df["ema20"] = df["close"].ewm(span=20, adjust=False).mean()
    df["ema50"] = df["close"].ewm(span=50, adjust=False).mean()

    true_range = pd.concat(
        [
            df["high"] - df["low"],
            (df["high"] - df["close"].shift(1)).abs(),
            (df["low"] - df["close"].shift(1)).abs(),
        ],
        axis=1,
    ).max(axis=1)
    df["atr14"] = true_range.rolling(14).mean()

    delta = df["close"].diff()
    gain = delta.clip(lower=0).rolling(14).mean()
    loss = (-delta.clip(upper=0)).rolling(14).mean().replace(0, np.nan)
    rs = gain / loss
    df["rsi14"] = 100 - (100 / (1 + rs))

    df["hour"] = df["time"].dt.hour
    df["dist20"] = (df["close"] - df["ema20"]) / df["atr14"]
    df["point_cost"] = df["spread"].fillna(0) * 0.01
    return df


def session_mask(df: pd.DataFrame, session_name: str) -> pd.Series:
    start, end = SESSION_WINDOWS[session_name]
    return df["hour"].between(start, end - 1)


def trend_mask(df: pd.DataFrame, trend_name: str) -> pd.Series:
    if trend_name == "none":
        return pd.Series(True, index=df.index)
    if trend_name == "bull":
        return df["ema20"] > df["ema50"]
    if trend_name == "bear":
        return df["ema20"] < df["ema50"]
    raise ValueError(f"Unknown trend mode: {trend_name}")


def trade_stats(df: pd.DataFrame, signal: pd.Series, side: str, hold: int, min_trades: int) -> dict[str, Any] | None:
    future_close = df["close"].shift(-hold)
    sign = 1.0 if side == "long" else -1.0
    ret = sign * (future_close - df["close"]) - df["point_cost"]
    trade_returns = ret[signal].dropna()
    if len(trade_returns) < min_trades:
        return None

    trade_times = df.loc[signal & ret.notna(), "time"]
    elapsed_days = max(1.0, (trade_times.iloc[-1] - trade_times.iloc[0]).total_seconds() / 86400.0)
    gross_profit = trade_returns[trade_returns > 0].sum()
    gross_loss = abs(trade_returns[trade_returns < 0].sum())
    profit_factor = gross_profit / gross_loss if gross_loss > 0 else np.nan
    return {
        "trades": int(len(trade_returns)),
        "trades_per_day": len(trade_returns) / elapsed_days,
        "profit_factor": float(profit_factor) if pd.notna(profit_factor) else None,
        "expectancy": float(trade_returns.mean()),
    }


def search_session_mean_reversion(
    df: pd.DataFrame,
    split_date: pd.Timestamp,
    min_trades: int,
) -> pd.DataFrame:
    train_mask = df["time"] < split_date
    test_mask = ~train_mask
    rows: list[Candidate] = []

    for side in ("long", "short"):
        for trend_name in ("none", "bull", "bear"):
            trend = trend_mask(df, trend_name)
            for hours_name in SESSION_WINDOWS:
                hours = session_mask(df, hours_name)
                base = trend & hours
                for hold in (4, 6, 8, 12):
                    for dist in (0.6, 0.8, 1.0, 1.2, 1.5):
                        for rsi in (25, 30, 35, 40, 45):
                            if side == "long":
                                signal = base & (df["dist20"] <= -dist) & (df["rsi14"] <= rsi)
                            else:
                                signal = base & (df["dist20"] >= dist) & (df["rsi14"] >= 100 - rsi)

                            train_stats = trade_stats(df, signal & train_mask, side, hold, min_trades)
                            test_stats = trade_stats(df, signal & test_mask, side, hold, min_trades)
                            if not train_stats or not test_stats:
                                continue

                            rows.append(
                                Candidate(
                                    family="session-mean-reversion",
                                    side=side,
                                    trend=trend_name,
                                    hours=hours_name,
                                    hold=hold,
                                    dist=dist,
                                    rsi=float(rsi),
                                    train_pf=float(train_stats["profit_factor"] or 0.0),
                                    train_tpd=float(train_stats["trades_per_day"]),
                                    train_exp=float(train_stats["expectancy"]),
                                    test_pf=float(test_stats["profit_factor"] or 0.0),
                                    test_tpd=float(test_stats["trades_per_day"]),
                                    test_exp=float(test_stats["expectancy"]),
                                    test_trades=int(test_stats["trades"]),
                                )
                            )

    return pd.DataFrame([asdict(row) for row in rows])


def filter_candidates(df: pd.DataFrame, min_trades_per_day: float) -> pd.DataFrame:
    if df.empty:
        return df
    return df[
        (df["train_pf"] > 1.0)
        & (df["test_pf"] > 1.0)
        & (df["train_exp"] > 0)
        & (df["test_exp"] > 0)
        & (df["train_tpd"] >= min_trades_per_day)
        & (df["test_tpd"] >= min_trades_per_day)
    ].copy()


def best_candidate(df: pd.DataFrame, side: str) -> dict[str, Any] | None:
    side_df = df[df["side"] == side].copy()
    if side_df.empty:
        return None
    side_df["score"] = (
        side_df["test_pf"] * 0.55
        + side_df["train_pf"] * 0.30
        + np.minimum(side_df["train_tpd"], side_df["test_tpd"]) * 0.03
    )
    row = side_df.sort_values(["score", "test_pf", "train_pf"], ascending=[False, False, False]).iloc[0]
    return row.to_dict()


def combined_pair_summary(df: pd.DataFrame, long_row: dict[str, Any] | None, short_row: dict[str, Any] | None) -> dict[str, Any]:
    if not long_row or not short_row:
        return {}

    summary = {
        "long_candidate": {
            key: long_row[key]
            for key in ("trend", "hours", "hold", "dist", "rsi", "train_pf", "train_tpd", "test_pf", "test_tpd")
        },
        "short_candidate": {
            key: short_row[key]
            for key in ("trend", "hours", "hold", "dist", "rsi", "train_pf", "train_tpd", "test_pf", "test_tpd")
        },
        "approx_combined_trades_per_day": {
            "train": float(long_row["train_tpd"] + short_row["train_tpd"]),
            "test": float(long_row["test_tpd"] + short_row["test_tpd"]),
        },
    }
    return summary


def default_output_dir(symbol: str, timeframe: str) -> Path:
    timestamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    return DEFAULT_OUTPUT_ROOT / f"{timestamp}-{slugify(symbol)}-{timeframe.lower()}-session-meanrev"


def write_outputs(
    output_dir: Path,
    full_results: pd.DataFrame,
    filtered_results: pd.DataFrame,
    summary: dict[str, Any],
    metadata: dict[str, Any],
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    full_csv = output_dir / "session_meanrev_full.csv"
    filtered_csv = output_dir / "session_meanrev_filtered.csv"
    summary_json = output_dir / "summary.json"
    summary_md = output_dir / "summary.md"

    full_results.to_csv(full_csv, index=False)
    filtered_results.to_csv(filtered_csv, index=False)
    summary_payload = {
        "metadata": metadata,
        "summary": summary,
        "top_rows": filtered_results.sort_values(["test_pf", "train_pf"], ascending=[False, False]).head(20).to_dict(orient="records"),
    }
    summary_json.write_text(json.dumps(summary_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Statistical Edge Research",
        "",
        f"- Symbol: {metadata['symbol']}",
        f"- Timeframe: {metadata['timeframe']}",
        f"- Bars: {metadata['bars']}",
        f"- Split date: {metadata['split_date']}",
        f"- History window: {metadata['history_start']} -> {metadata['history_end']}",
        f"- Full candidate count: {metadata['full_count']}",
        f"- Filtered candidate count: {metadata['filtered_count']}",
        "",
        "## Recommended Pair",
        "",
    ]

    if summary:
        long_info = summary["long_candidate"]
        short_info = summary["short_candidate"]
        combined = summary["approx_combined_trades_per_day"]
        lines.extend(
            [
                f"- Long: {long_info}",
                f"- Short: {short_info}",
                f"- Approx combined trades/day train: {combined['train']:.2f}",
                f"- Approx combined trades/day test: {combined['test']:.2f}",
            ]
        )
    else:
        lines.append("- No pair survived the filter.")

    lines.extend(["", "## Next Step", ""])
    lines.append("- Convert the recommended pair into a session-based prototype EA and validate it in MT5.")
    summary_md.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    terminal_path = load_terminal_path(args.terminal_path)
    split_date = pd.Timestamp(args.split_date)
    output_dir = Path(args.output_dir) if args.output_dir else default_output_dir(args.symbol, args.timeframe)

    initialize_mt5(terminal_path)
    try:
        rates = load_rates(args.symbol, args.timeframe, args.bars)
    finally:
        mt5.shutdown()

    df = enrich_features(rates)
    full_results = search_session_mean_reversion(df, split_date, args.min_trades)
    filtered_results = filter_candidates(full_results, args.min_trades_per_day)
    long_row = best_candidate(filtered_results, "long")
    short_row = best_candidate(filtered_results, "short")
    summary = combined_pair_summary(df, long_row, short_row)

    metadata = {
        "symbol": args.symbol,
        "timeframe": args.timeframe,
        "bars": args.bars,
        "split_date": args.split_date,
        "history_start": df["time"].iloc[0].isoformat(),
        "history_end": df["time"].iloc[-1].isoformat(),
        "full_count": int(len(full_results)),
        "filtered_count": int(len(filtered_results)),
    }
    write_outputs(output_dir, full_results, filtered_results, summary, metadata)

    print(f"Output dir: {output_dir}")
    print(f"Filtered candidates: {len(filtered_results)}")
    if summary:
        print(f"Recommended long: {summary['long_candidate']}")
        print(f"Recommended short: {summary['short_candidate']}")
        print(f"Approx combined trades/day test: {summary['approx_combined_trades_per_day']['test']:.2f}")
    else:
        print("No candidate pair passed the filter.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
