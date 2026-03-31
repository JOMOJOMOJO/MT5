from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import MetaTrader5 as mt5
import pandas as pd

from session_meanrev_validate import enrich_features, initialize_mt5, load_rates, load_terminal_path, simulate, split_stats


REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_OUTPUT_ROOT = REPO_ROOT / "reports" / "research"


@dataclass(frozen=True)
class Bucket:
    name: str
    params: dict[str, Any]


LONG_BUCKETS: tuple[Bucket, ...] = (
    Bucket("off", {"allow_buy": False}),
    Bucket(
        "bull_late_15_37_h12",
        {
            "allow_buy": True,
            "long_start_hour": 20,
            "long_end_hour": 24,
            "long_dist": 1.5,
            "long_rsi_max": 37.0,
            "buy_trend_filter": "bull",
            "long_hold_bars": 12,
            "long_exit_buffer_atr": 0.30,
        },
    ),
    Bucket(
        "bull_late_15_35_h12",
        {
            "allow_buy": True,
            "long_start_hour": 20,
            "long_end_hour": 24,
            "long_dist": 1.5,
            "long_rsi_max": 35.0,
            "buy_trend_filter": "bull",
            "long_hold_bars": 12,
            "long_exit_buffer_atr": 0.30,
        },
    ),
    Bucket(
        "late_none_12_35_h12",
        {
            "allow_buy": True,
            "long_start_hour": 20,
            "long_end_hour": 24,
            "long_dist": 1.2,
            "long_rsi_max": 35.0,
            "buy_trend_filter": "none",
            "long_hold_bars": 12,
            "long_exit_buffer_atr": 0.30,
        },
    ),
    Bucket(
        "late_none_12_40_h12",
        {
            "allow_buy": True,
            "long_start_hour": 20,
            "long_end_hour": 24,
            "long_dist": 1.2,
            "long_rsi_max": 40.0,
            "buy_trend_filter": "none",
            "long_hold_bars": 12,
            "long_exit_buffer_atr": 0.30,
        },
    ),
)

SHORT_BUCKETS: tuple[Bucket, ...] = (
    Bucket("off", {"allow_sell": False}),
    Bucket(
        "asia_087_64_82_h14",
        {
            "allow_sell": True,
            "short_start_hour": 0,
            "short_end_hour": 8,
            "short_dist": 0.87,
            "short_max_dist": 3.0,
            "short_min_atr_pct": 0.0003,
            "short_rsi_min": 64.0,
            "short_rsi_max": 82.0,
            "sell_trend_filter": "none",
            "short_hold_bars": 14,
            "short_exit_buffer_atr": 0.30,
        },
    ),
    Bucket(
        "asia_100_66_85_h12",
        {
            "allow_sell": True,
            "short_start_hour": 0,
            "short_end_hour": 8,
            "short_dist": 1.0,
            "short_max_dist": 3.0,
            "short_min_atr_pct": 0.0004,
            "short_rsi_min": 66.0,
            "short_rsi_max": 85.0,
            "sell_trend_filter": "none",
            "short_hold_bars": 12,
            "short_exit_buffer_atr": 0.30,
        },
    ),
    Bucket(
        "ny_bear_08_55_h12",
        {
            "allow_sell": True,
            "short_start_hour": 13,
            "short_end_hour": 22,
            "short_dist": 0.8,
            "short_rsi_min": 55.0,
            "short_rsi_max": 100.0,
            "sell_trend_filter": "bear",
            "short_hold_bars": 12,
            "short_exit_buffer_atr": 0.30,
        },
    ),
    Bucket(
        "ny_bear_08_60_h12",
        {
            "allow_sell": True,
            "short_start_hour": 13,
            "short_end_hour": 22,
            "short_dist": 0.8,
            "short_rsi_min": 60.0,
            "short_rsi_max": 100.0,
            "sell_trend_filter": "bear",
            "short_hold_bars": 12,
            "short_exit_buffer_atr": 0.30,
        },
    ),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Sweep a small set of session mean-reversion bucket combinations.")
    parser.add_argument("--symbol", default="BTCUSD")
    parser.add_argument("--timeframe", default="M5", choices=["M1", "M5", "M15", "M30", "H1"])
    parser.add_argument("--bars", type=int, default=80000)
    parser.add_argument("--split-dates", default="2025-10-01,2026-01-01")
    parser.add_argument("--output-dir")
    parser.add_argument("--terminal-path")
    parser.add_argument("--min-all-trades-per-day", type=float, default=3.0)
    parser.add_argument("--min-test-profit-factor", type=float, default=1.0)
    return parser.parse_args()


def default_output_dir(symbol: str, timeframe: str) -> Path:
    stamp = datetime.now().strftime("%Y-%m-%d-%H%M%S")
    return DEFAULT_OUTPUT_ROOT / f"{stamp}-{symbol.lower()}-{timeframe.lower()}-session-sweep"


def base_params(symbol: str, timeframe: str, bars: int) -> dict[str, Any]:
    return {
        "symbol": symbol,
        "timeframe": timeframe,
        "bars": bars,
        "split_date": "2026-01-01",
        "terminal_path": None,
        "trend_stack_ema_period": 100,
        "allow_buy": False,
        "allow_sell": False,
        "long_start_hour": 20,
        "long_end_hour": 24,
        "long_dist": 0.6,
        "long_max_dist": 0.0,
        "long_min_atr_pct": 0.0,
        "long_max_atr_pct": 0.0,
        "long_rsi_max": 40.0,
        "buy_trend_filter": "none",
        "short_start_hour": 0,
        "short_end_hour": 8,
        "short_dist": 0.8,
        "short_max_dist": 0.0,
        "short_min_atr_pct": 0.0,
        "short_max_atr_pct": 0.0,
        "short_rsi_min": 45.0,
        "short_rsi_max": 100.0,
        "short_require_stacked_bear": False,
        "enable_second_short": False,
        "second_short_start_hour": 13,
        "second_short_end_hour": 22,
        "second_short_dist": 0.8,
        "second_short_max_dist": 0.0,
        "second_short_min_atr_pct": 0.0,
        "second_short_max_atr_pct": 0.0,
        "second_short_rsi_min": 55.0,
        "second_short_rsi_max": 100.0,
        "second_short_trend_filter": "bear",
        "adaptive_short_by_atr_regime": False,
        "short_atr_pivot": 0.0012,
        "short_dist_calm": 1.0,
        "short_max_dist_calm": 3.0,
        "short_rsi_min_calm": 66.0,
        "short_rsi_max_calm": 85.0,
        "short_dist_active": 0.9,
        "short_max_dist_active": 0.0,
        "short_rsi_min_active": 64.0,
        "short_rsi_max_active": 95.0,
        "sell_trend_filter": "none",
        "sell_require_above_slow_ema": False,
        "hold_bars": 12,
        "long_hold_bars": 0,
        "short_hold_bars": 0,
        "exit_buffer_atr": 0.30,
        "long_exit_buffer_atr": 0.0,
        "short_exit_buffer_atr": 0.0,
        "stop_atr": 4.0,
        "allowed_weekdays": "0,1,2,3,4,6",
        "blocked_entry_hours": "3",
        "entry_slip_pips": 250.0,
        "exit_slip_pips": 250.0,
        "stop_slip_pips": 400.0,
        "max_open_trades": 8,
        "max_open_per_side": 4,
        "starting_balance": 100000.0,
        "daily_loss_cap_pct": 3.0,
        "max_trades_per_day": 20,
        "max_consecutive_losses": 5,
        "consecutive_loss_cooldown_bars": 24,
        "equity_drawdown_cap_pct": 0.0,
        "max_spread_pips": 2500.0,
        "output": None,
    }


def candidate_namespace(base: dict[str, Any], long_bucket: Bucket, short_bucket: Bucket) -> SimpleNamespace:
    merged = dict(base)
    merged.update(long_bucket.params)
    merged.update(short_bucket.params)
    if not merged["allow_buy"] and not merged["allow_sell"]:
        raise ValueError("Both buckets are disabled.")
    return SimpleNamespace(**merged)


def score_row(row: dict[str, Any]) -> float:
    dd_pct = row["max_drawdown"] / row["starting_balance"] * 100.0
    return (
        row["min_test_pf"] * 0.45
        + row["min_train_pf"] * 0.20
        + row["all_pf"] * 0.20
        + min(row["all_tpd"], 8.0) * 0.04
        + min(row["min_test_tpd"], 8.0) * 0.03
        - dd_pct * 0.02
    )


def main() -> int:
    args = parse_args()
    output_dir = Path(args.output_dir) if args.output_dir else default_output_dir(args.symbol, args.timeframe)
    output_dir.mkdir(parents=True, exist_ok=True)

    split_dates = [pd.Timestamp(item.strip()) for item in args.split_dates.split(",") if item.strip()]
    terminal_path = load_terminal_path(args.terminal_path)
    initialize_mt5(terminal_path)
    try:
        frame = load_rates(args.symbol, args.timeframe, args.bars)
    finally:
        mt5.shutdown()

    df = enrich_features(frame, 100)
    base = base_params(args.symbol, args.timeframe, args.bars)
    rows: list[dict[str, Any]] = []

    for long_bucket in LONG_BUCKETS:
        for short_bucket in SHORT_BUCKETS:
            if long_bucket.name == "off" and short_bucket.name == "off":
                continue

            candidate = candidate_namespace(base, long_bucket, short_bucket)
            trades = simulate(df, candidate)
            if trades.empty:
                continue

            split_metrics: dict[str, Any] = {}
            min_test_pf = float("inf")
            min_train_pf = float("inf")
            min_test_tpd = float("inf")
            max_test_dd = 0.0
            for split_date in split_dates:
                stats = split_stats(trades, split_date)
                split_metrics[split_date.date().isoformat()] = stats
                min_test_pf = min(min_test_pf, stats["test"]["profit_factor"])
                min_train_pf = min(min_train_pf, stats["train"]["profit_factor"])
                min_test_tpd = min(min_test_tpd, stats["test"]["trades_per_day"])
                max_test_dd = max(max_test_dd, stats["test"]["max_drawdown"])

            all_stats = split_stats(trades, split_dates[-1])["all"]
            row = {
                "long_bucket": long_bucket.name,
                "short_bucket": short_bucket.name,
                "all_trades": all_stats["trades"],
                "all_tpd": all_stats["trades_per_day"],
                "all_pf": all_stats["profit_factor"],
                "all_net": all_stats["net"],
                "all_win_rate": all_stats["win_rate"],
                "max_drawdown": all_stats["max_drawdown"],
                "starting_balance": candidate.starting_balance,
                "min_train_pf": min_train_pf,
                "min_test_pf": min_test_pf,
                "min_test_tpd": min_test_tpd,
                "max_test_dd": max_test_dd,
                "splits": split_metrics,
            }
            row["score"] = score_row(row)
            rows.append(row)

    results = pd.DataFrame(rows).sort_values(["score", "min_test_pf", "all_pf"], ascending=[False, False, False])
    if results.empty:
        raise RuntimeError("No sweep results were produced.")

    filtered = results[
        (results["all_tpd"] >= args.min_all_trades_per_day)
        & (results["min_test_pf"] >= args.min_test_profit_factor)
    ].copy()

    payload = {
        "metadata": {
            "symbol": args.symbol,
            "timeframe": args.timeframe,
            "bars": args.bars,
            "history_start": df["time"].iloc[0].isoformat(),
            "history_end": df["time"].iloc[-1].isoformat(),
            "split_dates": [item.isoformat() for item in split_dates],
            "candidate_count": int(len(results)),
            "filtered_count": int(len(filtered)),
        },
        "top_results": results.head(20).to_dict(orient="records"),
        "filtered_results": filtered.head(20).to_dict(orient="records"),
    }

    (output_dir / "results.csv").write_text(results.to_csv(index=False), encoding="utf-8")
    (output_dir / "results.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Session Mean-Reversion Candidate Sweep",
        "",
        f"- Symbol: {args.symbol}",
        f"- Timeframe: {args.timeframe}",
        f"- Bars: {args.bars}",
        f"- Split dates: {', '.join(item.date().isoformat() for item in split_dates)}",
        f"- Candidate count: {len(results)}",
        f"- Filtered count: {len(filtered)}",
        "",
        "## Top Results",
        "",
    ]
    for _, row in results.head(10).iterrows():
        lines.extend(
            [
                f"- `{row['long_bucket']} + {row['short_bucket']}`",
                f"  - score: `{row['score']:.3f}`",
                f"  - all: `PF {row['all_pf']:.2f}`, `{row['all_tpd']:.2f} trades/day`, `net {row['all_net']:.2f}`",
                f"  - min split test PF: `{row['min_test_pf']:.2f}`",
                f"  - min split test trades/day: `{row['min_test_tpd']:.2f}`",
            ]
        )
    (output_dir / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"Output dir: {output_dir}")
    print(f"Candidate count: {len(results)}")
    if not filtered.empty:
        best = filtered.iloc[0]
        print(f"Best filtered candidate: {best['long_bucket']} + {best['short_bucket']}")
        print(
            f"All PF={best['all_pf']:.2f}, All TPD={best['all_tpd']:.2f}, "
            f"Min test PF={best['min_test_pf']:.2f}, Min test TPD={best['min_test_tpd']:.2f}"
        )
    else:
        best = results.iloc[0]
        print("No candidate passed filters.")
        print(
            f"Best overall candidate: {best['long_bucket']} + {best['short_bucket']} | "
            f"All PF={best['all_pf']:.2f}, Min test PF={best['min_test_pf']:.2f}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
