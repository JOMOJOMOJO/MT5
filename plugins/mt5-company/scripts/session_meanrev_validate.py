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
ORIGIN_PATH = REPO_ROOT.parents[2] / "origin.txt"
TIMEFRAME_MAP = {
    "M1": mt5.TIMEFRAME_M1,
    "M5": mt5.TIMEFRAME_M5,
    "M15": mt5.TIMEFRAME_M15,
    "M30": mt5.TIMEFRAME_M30,
    "H1": mt5.TIMEFRAME_H1,
}


@dataclass
class Position:
    side: int
    entry_index: int
    entry_time: pd.Timestamp
    quote_price: float
    entry_price: float
    stop_price: float
    entry_atr: float
    spread_cost: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate the session mean-reversion EA logic on MT5 bars.")
    parser.add_argument("--symbol", default="BTCUSD")
    parser.add_argument("--timeframe", default="M5", choices=sorted(TIMEFRAME_MAP))
    parser.add_argument("--bars", type=int, default=50000)
    parser.add_argument("--split-date", default="2026-01-01")
    parser.add_argument("--terminal-path")
    parser.add_argument("--trend-stack-ema-period", type=int, default=100)
    parser.add_argument("--allow-buy", action="store_true", default=False)
    parser.add_argument("--allow-sell", action="store_true", default=False)
    parser.add_argument("--long-start-hour", type=int, default=20)
    parser.add_argument("--long-end-hour", type=int, default=24)
    parser.add_argument("--long-dist", type=float, default=0.6)
    parser.add_argument("--long-max-dist", type=float, default=0.0)
    parser.add_argument("--long-min-atr-pct", type=float, default=0.0)
    parser.add_argument("--long-max-atr-pct", type=float, default=0.0)
    parser.add_argument("--long-rsi-max", type=float, default=40.0)
    parser.add_argument("--buy-trend-filter", default="none", choices=["none", "bull", "bear"])
    parser.add_argument("--enable-second-long", action="store_true", default=False)
    parser.add_argument("--second-long-start-hour", type=int, default=13)
    parser.add_argument("--second-long-end-hour", type=int, default=22)
    parser.add_argument("--second-long-dist", type=float, default=1.5)
    parser.add_argument("--second-long-max-dist", type=float, default=0.0)
    parser.add_argument("--second-long-min-atr-pct", type=float, default=0.0)
    parser.add_argument("--second-long-max-atr-pct", type=float, default=0.0)
    parser.add_argument("--second-long-rsi-max", type=float, default=30.0)
    parser.add_argument("--second-long-trend-filter", default="bull", choices=["none", "bull", "bear"])
    parser.add_argument("--short-start-hour", type=int, default=0)
    parser.add_argument("--short-end-hour", type=int, default=8)
    parser.add_argument("--short-dist", type=float, default=0.8)
    parser.add_argument("--short-max-dist", type=float, default=0.0)
    parser.add_argument("--short-min-atr-pct", type=float, default=0.0)
    parser.add_argument("--short-max-atr-pct", type=float, default=0.0)
    parser.add_argument("--short-rsi-min", type=float, default=45.0)
    parser.add_argument("--short-rsi-max", type=float, default=100.0)
    parser.add_argument("--short-require-stacked-bear", action="store_true", default=False)
    parser.add_argument("--enable-second-short", action="store_true", default=False)
    parser.add_argument("--second-short-start-hour", type=int, default=13)
    parser.add_argument("--second-short-end-hour", type=int, default=22)
    parser.add_argument("--second-short-dist", type=float, default=0.8)
    parser.add_argument("--second-short-max-dist", type=float, default=0.0)
    parser.add_argument("--second-short-min-atr-pct", type=float, default=0.0)
    parser.add_argument("--second-short-max-atr-pct", type=float, default=0.0)
    parser.add_argument("--second-short-rsi-min", type=float, default=55.0)
    parser.add_argument("--second-short-rsi-max", type=float, default=100.0)
    parser.add_argument("--second-short-trend-filter", default="bear", choices=["none", "bull", "bear"])
    parser.add_argument("--adaptive-short-by-atr-regime", action="store_true", default=False)
    parser.add_argument("--short-atr-pivot", type=float, default=0.0012)
    parser.add_argument("--short-dist-calm", type=float, default=1.0)
    parser.add_argument("--short-max-dist-calm", type=float, default=3.0)
    parser.add_argument("--short-rsi-min-calm", type=float, default=66.0)
    parser.add_argument("--short-rsi-max-calm", type=float, default=85.0)
    parser.add_argument("--short-dist-active", type=float, default=0.9)
    parser.add_argument("--short-max-dist-active", type=float, default=0.0)
    parser.add_argument("--short-rsi-min-active", type=float, default=64.0)
    parser.add_argument("--short-rsi-max-active", type=float, default=95.0)
    parser.add_argument("--sell-trend-filter", default="none", choices=["none", "bull", "bear"])
    parser.add_argument("--sell-require-above-slow-ema", action="store_true", default=False)
    parser.add_argument("--hold-bars", type=int, default=12)
    parser.add_argument("--long-hold-bars", type=int, default=0)
    parser.add_argument("--short-hold-bars", type=int, default=0)
    parser.add_argument("--exit-buffer-atr", type=float, default=0.10)
    parser.add_argument("--long-exit-buffer-atr", type=float, default=0.0)
    parser.add_argument("--short-exit-buffer-atr", type=float, default=0.0)
    parser.add_argument("--stop-atr", type=float, default=2.50)
    parser.add_argument("--allowed-weekdays", default="0,1,2,3,4,5,6")
    parser.add_argument("--blocked-entry-hours", default="")
    parser.add_argument("--entry-slip-pips", type=float, default=0.0)
    parser.add_argument("--exit-slip-pips", type=float, default=0.0)
    parser.add_argument("--stop-slip-pips", type=float, default=0.0)
    parser.add_argument("--max-open-trades", type=int, default=8)
    parser.add_argument("--max-open-per-side", type=int, default=4)
    parser.add_argument("--starting-balance", type=float, default=100000.0)
    parser.add_argument("--daily-loss-cap-pct", type=float, default=3.0)
    parser.add_argument("--max-trades-per-day", type=int, default=0)
    parser.add_argument("--max-consecutive-losses", type=int, default=0)
    parser.add_argument("--consecutive-loss-cooldown-bars", type=int, default=0)
    parser.add_argument("--equity-drawdown-cap-pct", type=float, default=0.0)
    parser.add_argument("--max-spread-pips", type=float, default=3500.0)
    parser.add_argument("--output")
    return parser.parse_args()


def parse_int_csv(csv_text: str, minimum: int, maximum: int) -> set[int]:
    values: set[int] = set()
    if not csv_text.strip():
        return values

    for token in csv_text.split(","):
        part = token.strip()
        if not part:
            continue
        value = int(part)
        if value < minimum or value > maximum:
            raise ValueError(f"Value {value} out of range [{minimum}, {maximum}] in '{csv_text}'")
        values.add(value)
    return values


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
    return frame.drop_duplicates(subset=["time"]).sort_values("time").reset_index(drop=True)


def enrich_features(frame: pd.DataFrame, trend_stack_ema_period: int) -> pd.DataFrame:
    df = frame.copy()
    df["ema20"] = df["close"].ewm(span=20, adjust=False).mean()
    df["ema50"] = df["close"].ewm(span=50, adjust=False).mean()
    df["ema_stack"] = df["close"].ewm(span=trend_stack_ema_period, adjust=False).mean()
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
    loss = (-delta.clip(upper=0)).rolling(14).mean()
    rs = gain / loss.replace(0, np.nan)
    df["rsi14"] = 100 - (100 / (1 + rs))
    df["hour"] = df["time"].dt.hour
    df["point"] = 0.01
    df["spread_price"] = df["spread"].fillna(0) * df["point"]
    df["spread_pips"] = df["spread_price"] / df["point"]
    return df


def trend_pass(filter_name: str, fast_ema: float, slow_ema: float) -> bool:
    if filter_name == "none":
        return True
    if filter_name == "bull":
        return fast_ema > slow_ema
    if filter_name == "bear":
        return fast_ema < slow_ema
    raise ValueError(f"Unknown trend filter: {filter_name}")


def hour_in_range(hour: int, start_hour: int, end_hour: int) -> bool:
    start = max(0, min(23, start_hour))
    end = max(0, min(24, end_hour))
    if start == end:
        return True
    if start < end:
        return start <= hour < end
    return hour >= start or hour < end


def calculate_trade_stats(pnl: pd.Series, times: pd.Series) -> dict[str, Any]:
    if pnl.empty:
        return {
            "trades": 0,
            "trades_per_day": 0.0,
            "net": 0.0,
            "profit_factor": 0.0,
            "win_rate": 0.0,
            "max_drawdown": 0.0,
        }

    gross_profit = pnl[pnl > 0].sum()
    gross_loss = abs(pnl[pnl < 0].sum())
    elapsed_days = max(1.0, (times.iloc[-1] - times.iloc[0]).total_seconds() / 86400.0)
    equity = pnl.cumsum()
    drawdown = equity - equity.cummax()
    profit_factor = gross_profit / gross_loss if gross_loss > 0 else np.nan
    return {
        "trades": int(len(pnl)),
        "trades_per_day": float(len(pnl) / elapsed_days),
        "net": float(pnl.sum()),
        "profit_factor": float(profit_factor) if pd.notna(profit_factor) else 0.0,
        "win_rate": float((pnl > 0).mean() * 100.0),
        "max_drawdown": float(abs(drawdown.min()) if not drawdown.empty else 0.0),
    }


def effective_hold_bars(args: argparse.Namespace, side: int) -> int:
    if side > 0 and args.long_hold_bars > 0:
        return args.long_hold_bars
    if side < 0 and args.short_hold_bars > 0:
        return args.short_hold_bars
    return args.hold_bars


def effective_exit_buffer_atr(args: argparse.Namespace, side: int) -> float:
    if side > 0 and args.long_exit_buffer_atr > 0.0:
        return args.long_exit_buffer_atr
    if side < 0 and args.short_exit_buffer_atr > 0.0:
        return args.short_exit_buffer_atr
    return args.exit_buffer_atr


def adverse_fill_price(side: int, base_price: float, slip_price: float) -> float:
    if side > 0:
        return base_price + slip_price
    return base_price - slip_price


def split_stats(trades: pd.DataFrame, split_date: pd.Timestamp) -> dict[str, Any]:
    train = trades[trades["exit_time"] < split_date].copy()
    test = trades[trades["exit_time"] >= split_date].copy()
    return {
        "train": calculate_trade_stats(train["pnl"], train["exit_time"]),
        "test": calculate_trade_stats(test["pnl"], test["exit_time"]),
        "all": calculate_trade_stats(trades["pnl"], trades["exit_time"]),
    }


def simulate(df: pd.DataFrame, args: argparse.Namespace) -> pd.DataFrame:
    open_positions: list[Position] = []
    closed_rows: list[dict[str, Any]] = []
    current_day: pd.Timestamp | None = None
    current_balance = float(args.starting_balance)
    daily_start_balance = float(args.starting_balance)
    equity_peak = float(args.starting_balance)
    daily_closed_trades = 0
    consecutive_losses = 0
    loss_lock_today = False
    loss_lock_until_index = -1
    allowed_weekdays = parse_int_csv(args.allowed_weekdays, 0, 6)
    blocked_entry_hours = parse_int_csv(args.blocked_entry_hours, 0, 23)
    pip_size = float(df["point"].iloc[0])
    entry_slip = args.entry_slip_pips * pip_size
    exit_slip = args.exit_slip_pips * pip_size
    stop_slip = args.stop_slip_pips * pip_size

    for i in range(30, len(df)):
        row = df.iloc[i]
        prev = df.iloc[i - 1]

        bar_day = row["time"].floor("D")
        if current_day is None or bar_day != current_day:
            current_day = bar_day
            daily_start_balance = current_balance
            daily_closed_trades = 0
            consecutive_losses = 0
            loss_lock_today = False
            loss_lock_until_index = -1

        survivors: list[Position] = []
        for pos in open_positions:
            stop_hit = False
            exit_price = 0.0
            exit_reason = ""

            if pos.side > 0 and row["low"] <= pos.stop_price:
                stop_hit = True
                gap_base = min(pos.stop_price, float(row["open"]))
                exit_price = gap_base - stop_slip
                exit_reason = "stop"
            elif pos.side < 0 and row["high"] >= pos.stop_price:
                stop_hit = True
                gap_base = max(pos.stop_price, float(row["open"]))
                exit_price = gap_base + stop_slip
                exit_reason = "stop"

            if stop_hit:
                pnl = pos.side * (exit_price - pos.entry_price) - pos.spread_cost
                current_balance += pnl
                closed_rows.append(
                    {
                        "entry_time": pos.entry_time,
                        "exit_time": row["time"],
                        "side": "buy" if pos.side > 0 else "sell",
                        "entry_price": pos.entry_price,
                        "exit_price": exit_price,
                        "pnl": pnl,
                        "reason": exit_reason,
                    }
                )
                daily_closed_trades += 1
                if pnl < 0:
                    consecutive_losses += 1
                    if args.max_consecutive_losses > 0 and consecutive_losses >= args.max_consecutive_losses:
                        if args.consecutive_loss_cooldown_bars > 0:
                            loss_lock_until_index = max(loss_lock_until_index, i + args.consecutive_loss_cooldown_bars)
                        else:
                            loss_lock_today = True
                else:
                    consecutive_losses = 0
                continue

            held_bars = i - pos.entry_index
            hold_limit = effective_hold_bars(args, pos.side)
            exit_buffer_atr = effective_exit_buffer_atr(args, pos.side)
            mean_exit = False
            if exit_buffer_atr > 0 and prev["atr14"] > 0:
                buffer = prev["atr14"] * exit_buffer_atr
                if pos.side > 0:
                    mean_exit = prev["close"] >= prev["ema20"] - buffer
                else:
                    mean_exit = prev["close"] <= prev["ema20"] + buffer

            if held_bars >= hold_limit or mean_exit:
                exit_price = adverse_fill_price(-pos.side, float(row["open"]), exit_slip)
                pnl = pos.side * (exit_price - pos.entry_price) - pos.spread_cost
                current_balance += pnl
                closed_rows.append(
                    {
                        "entry_time": pos.entry_time,
                        "exit_time": row["time"],
                        "side": "buy" if pos.side > 0 else "sell",
                        "entry_price": pos.entry_price,
                        "exit_price": exit_price,
                        "pnl": pnl,
                        "reason": "time" if held_bars >= args.hold_bars else "mean",
                    }
                )
                daily_closed_trades += 1
                if pnl < 0:
                    consecutive_losses += 1
                    if args.max_consecutive_losses > 0 and consecutive_losses >= args.max_consecutive_losses:
                        if args.consecutive_loss_cooldown_bars > 0:
                            loss_lock_until_index = max(loss_lock_until_index, i + args.consecutive_loss_cooldown_bars)
                        else:
                            loss_lock_today = True
                else:
                    consecutive_losses = 0
                continue

            survivors.append(pos)

        open_positions = survivors
        equity_peak = max(equity_peak, current_balance)

        signal_weekday = int((prev["time"].dayofweek + 1) % 7)
        signal_hour = int(prev["hour"])
        if (
            prev["atr14"] <= 0
            or pd.isna(prev["rsi14"])
            or row["spread_pips"] > args.max_spread_pips
            or (allowed_weekdays and signal_weekday not in allowed_weekdays)
            or signal_hour in blocked_entry_hours
        ):
            continue

        if len(open_positions) >= args.max_open_trades:
            continue
        if (
            args.daily_loss_cap_pct > 0.0
            and daily_start_balance > 0.0
            and current_balance <= daily_start_balance * (1.0 - args.daily_loss_cap_pct / 100.0)
        ):
            continue
        if (
            args.equity_drawdown_cap_pct > 0.0
            and equity_peak > 0.0
            and current_balance <= equity_peak * (1.0 - args.equity_drawdown_cap_pct / 100.0)
        ):
            continue
        if args.max_trades_per_day > 0 and daily_closed_trades >= args.max_trades_per_day:
            continue
        if args.max_consecutive_losses > 0:
            if args.consecutive_loss_cooldown_bars > 0 and i < loss_lock_until_index:
                continue
            if args.consecutive_loss_cooldown_bars <= 0 and loss_lock_today:
                continue

        dist_atr = (prev["close"] - prev["ema20"]) / prev["atr14"]
        atr_pct = float(prev["atr14"] / prev["close"]) if prev["close"] > 0 else 0.0
        stacked_bear = float(prev["ema20"]) < float(prev["ema50"]) < float(prev["ema_stack"])
        short_dist = args.short_dist
        short_max_dist = args.short_max_dist
        short_rsi_min = args.short_rsi_min
        short_rsi_max = args.short_rsi_max
        if args.adaptive_short_by_atr_regime:
            is_active = atr_pct >= args.short_atr_pivot
            if is_active:
                short_dist = args.short_dist_active
                short_max_dist = args.short_max_dist_active
                short_rsi_min = args.short_rsi_min_active
                short_rsi_max = args.short_rsi_max_active
            else:
                short_dist = args.short_dist_calm
                short_max_dist = args.short_max_dist_calm
                short_rsi_min = args.short_rsi_min_calm
                short_rsi_max = args.short_rsi_max_calm
        long_signal = (
            args.allow_buy
            and hour_in_range(int(prev["hour"]), args.long_start_hour, args.long_end_hour)
            and dist_atr <= -args.long_dist
            and (args.long_max_dist <= 0.0 or dist_atr >= -args.long_max_dist)
            and (args.long_min_atr_pct <= 0.0 or atr_pct >= args.long_min_atr_pct)
            and (args.long_max_atr_pct <= 0.0 or atr_pct <= args.long_max_atr_pct)
            and prev["rsi14"] <= args.long_rsi_max
            and trend_pass(args.buy_trend_filter, float(prev["ema20"]), float(prev["ema50"]))
        )
        second_long_signal = (
            args.allow_buy
            and args.enable_second_long
            and hour_in_range(int(prev["hour"]), args.second_long_start_hour, args.second_long_end_hour)
            and dist_atr <= -args.second_long_dist
            and (args.second_long_max_dist <= 0.0 or dist_atr >= -args.second_long_max_dist)
            and (args.second_long_min_atr_pct <= 0.0 or atr_pct >= args.second_long_min_atr_pct)
            and (args.second_long_max_atr_pct <= 0.0 or atr_pct <= args.second_long_max_atr_pct)
            and prev["rsi14"] <= args.second_long_rsi_max
            and trend_pass(args.second_long_trend_filter, float(prev["ema20"]), float(prev["ema50"]))
        )
        short_signal = (
            args.allow_sell
            and hour_in_range(int(prev["hour"]), args.short_start_hour, args.short_end_hour)
            and dist_atr >= short_dist
            and (short_max_dist <= 0.0 or dist_atr <= short_max_dist)
            and (args.short_min_atr_pct <= 0.0 or atr_pct >= args.short_min_atr_pct)
            and (args.short_max_atr_pct <= 0.0 or atr_pct <= args.short_max_atr_pct)
            and prev["rsi14"] >= short_rsi_min
            and prev["rsi14"] <= short_rsi_max
            and trend_pass(args.sell_trend_filter, float(prev["ema20"]), float(prev["ema50"]))
            and (not args.short_require_stacked_bear or stacked_bear)
            and (not args.sell_require_above_slow_ema or prev["close"] > prev["ema50"])
        )
        second_short_signal = (
            args.allow_sell
            and args.enable_second_short
            and hour_in_range(int(prev["hour"]), args.second_short_start_hour, args.second_short_end_hour)
            and dist_atr >= args.second_short_dist
            and (args.second_short_max_dist <= 0.0 or dist_atr <= args.second_short_max_dist)
            and (args.second_short_min_atr_pct <= 0.0 or atr_pct >= args.second_short_min_atr_pct)
            and (args.second_short_max_atr_pct <= 0.0 or atr_pct <= args.second_short_max_atr_pct)
            and prev["rsi14"] >= args.second_short_rsi_min
            and prev["rsi14"] <= args.second_short_rsi_max
            and trend_pass(args.second_short_trend_filter, float(prev["ema20"]), float(prev["ema50"]))
        )

        if not long_signal and not second_long_signal and not short_signal and not second_short_signal:
            continue

        long_open = sum(1 for p in open_positions if p.side > 0)
        short_open = sum(1 for p in open_positions if p.side < 0)
        spread_cost = float(row["spread_price"])
        stop_distance = float(prev["atr14"] * args.stop_atr)
        quote_price = float(row["open"])

        if (long_signal or second_long_signal) and long_open < args.max_open_per_side:
            entry_price = adverse_fill_price(1, quote_price, entry_slip)
            open_positions.append(
                Position(
                    side=1,
                    entry_index=i,
                    entry_time=row["time"],
                    quote_price=quote_price,
                    entry_price=entry_price,
                    stop_price=quote_price - stop_distance,
                    entry_atr=float(prev["atr14"]),
                    spread_cost=spread_cost,
                )
            )

        if (short_signal or second_short_signal) and short_open < args.max_open_per_side and len(open_positions) < args.max_open_trades:
            entry_price = adverse_fill_price(-1, quote_price, entry_slip)
            open_positions.append(
                Position(
                    side=-1,
                    entry_index=i,
                    entry_time=row["time"],
                    quote_price=quote_price,
                    entry_price=entry_price,
                    stop_price=quote_price + stop_distance,
                    entry_atr=float(prev["atr14"]),
                    spread_cost=spread_cost,
                )
            )

    return pd.DataFrame(closed_rows)


def main() -> int:
    args = parse_args()
    if not args.allow_buy and not args.allow_sell:
        args.allow_buy = True
        args.allow_sell = True

    terminal_path = load_terminal_path(args.terminal_path)
    initialize_mt5(terminal_path)
    try:
        frame = load_rates(args.symbol, args.timeframe, args.bars)
    finally:
        mt5.shutdown()

    df = enrich_features(frame, args.trend_stack_ema_period)
    trades = simulate(df, args)
    split_date = pd.Timestamp(args.split_date)
    stats = split_stats(trades, split_date)
    payload = {
        "metadata": {
            "symbol": args.symbol,
            "timeframe": args.timeframe,
            "bars": args.bars,
            "history_start": df["time"].iloc[0].isoformat(),
            "history_end": df["time"].iloc[-1].isoformat(),
            "split_date": split_date.isoformat(),
            "parameters": vars(args),
        },
        "stats": stats,
    }

    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
