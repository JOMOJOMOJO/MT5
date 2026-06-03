#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import Counter, defaultdict
from pathlib import Path

from analyze_multicurrency_score_scanner_2025 import (
    BACKTEST,
    calc_stats,
    group_stats,
    parse_mt5_deals,
    read_trades,
    serialize_stats,
    write_rows,
    write_trades,
)


OUT_PREFIX = "ExpectedValue_MultiCurrency_ScoreScanner_2025_thirdwave"

RUNS = [
    {
        "run": "A",
        "scenario": "ThirdWave_BOTH",
        "prefix": "ExpectedValue_MultiCurrency_ScoreScanner_2025_thirdwave_A_both",
    },
    {
        "run": "B",
        "scenario": "ThirdWave_LONG_ONLY",
        "prefix": "ExpectedValue_MultiCurrency_ScoreScanner_2025_thirdwave_B_long_only",
    },
    {
        "run": "C",
        "scenario": "ThirdWave_SHORT_ONLY",
        "prefix": "ExpectedValue_MultiCurrency_ScoreScanner_2025_thirdwave_C_short_only",
    },
]


def pf_value(stats: dict[str, object]) -> object:
    return round(float(stats["profit_factor"]), 3) if stats["profit_factor"] is not None else ""


def read_elapsed() -> dict[str, float]:
    path = BACKTEST / f"{OUT_PREFIX}_elapsed.csv"
    if not path.exists():
        return {}
    values: dict[str, float] = {}
    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            if row.get("run") and row.get("elapsed_seconds"):
                values[row["run"]] = float(row["elapsed_seconds"])
    return values


def read_thirdwave_summary(path: Path) -> dict[str, object]:
    latest: dict[str, str] | None = None
    if path.exists():
        with path.open(newline="", encoding="utf-8-sig") as fh:
            for row in csv.DictReader(fh):
                if row.get("evaluations"):
                    latest = row
    if latest is None:
        return {}

    def as_int(key: str) -> int:
        value = latest.get(key, "")
        return int(float(value)) if value != "" else 0

    return {
        "evaluations": as_int("evaluations"),
        "long_evaluations": as_int("long_evaluations"),
        "short_evaluations": as_int("short_evaluations"),
        "setup_pass": as_int("setup_pass"),
        "entry_pass": as_int("entry_pass"),
        "orders_sent": as_int("orders_sent"),
        "orders_failed": as_int("orders_failed"),
        "no_higher_tf_trend": as_int("no_higher_tf_trend"),
        "trend_broken": as_int("trend_broken"),
        "no_mid_pullback": as_int("no_mid_pullback"),
        "pullback_too_shallow": as_int("pullback_too_shallow"),
        "pullback_too_deep": as_int("pullback_too_deep"),
        "no_lower_reversal": as_int("no_lower_reversal"),
        "sl_too_close": as_int("sl_too_close"),
        "sl_too_wide": as_int("sl_too_wide"),
        "rr_too_low": as_int("rr_too_low"),
        "existing_position": as_int("existing_position"),
        "market_closed": as_int("market_closed"),
        "spread_guard": as_int("spread_guard"),
        "data_unavailable": as_int("data_unavailable"),
        "atr_unavailable": as_int("atr_unavailable"),
        "research_excluded": as_int("research_excluded"),
        "unknown": as_int("unknown"),
        "top_skip_reason": latest.get("top_skip_reason", ""),
        "top_skip_reason_rows": as_int("top_skip_reason_rows"),
    }


def group_csv(path: Path, run_trades: dict[str, list[dict[str, object]]], key_fn) -> None:
    rows: list[dict[str, object]] = []
    for run in RUNS:
        for row in group_stats(run_trades[run["run"]], key_fn):
            rows.append({"run": run["run"], "scenario": run["scenario"], **row})
    write_rows(path, rows)


def read_trade_diagnostics(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return list(csv.DictReader(fh))


def build_skip_rows(summaries: dict[str, dict[str, object]]) -> list[dict[str, object]]:
    skip_keys = [
        "no_higher_tf_trend",
        "trend_broken",
        "no_mid_pullback",
        "pullback_too_shallow",
        "pullback_too_deep",
        "no_lower_reversal",
        "sl_too_close",
        "sl_too_wide",
        "rr_too_low",
        "existing_position",
        "market_closed",
        "spread_guard",
        "data_unavailable",
        "atr_unavailable",
        "research_excluded",
        "unknown",
    ]
    rows = []
    for run in RUNS:
        summary = summaries.get(run["run"], {})
        for key in skip_keys:
            value = int(summary.get(key, 0) or 0)
            if value > 0:
                rows.append({"run": run["run"], "scenario": run["scenario"], "skip_reason": key, "rows": value})
    return rows


def build_rr_rows(trade_logs: dict[str, list[dict[str, str]]]) -> list[dict[str, object]]:
    rows = []
    for run in RUNS:
        counts = Counter()
        sent = Counter()
        failed = Counter()
        for row in trade_logs.get(run["run"], []):
            rr = row.get("rr", "")
            if rr == "":
                rr = "unknown"
            counts[rr] += 1
            if row.get("event") == "order_sent":
                sent[rr] += 1
            if row.get("event") == "order_failed":
                failed[rr] += 1
        for rr, count in sorted(counts.items()):
            rows.append(
                {
                    "run": run["run"],
                    "scenario": run["scenario"],
                    "rr": rr,
                    "trade_log_rows": count,
                    "orders_sent": sent[rr],
                    "orders_failed": failed[rr],
                }
            )
    return rows


def major_symbols(trades: list[dict[str, object]]) -> tuple[str, str]:
    by_symbol: dict[str, float] = defaultdict(float)
    for trade in trades:
        by_symbol[str(trade["symbol"])] += float(trade["net_profit"])

    winners = [(symbol, pnl) for symbol, pnl in by_symbol.items() if pnl > 0]
    losers = [(symbol, pnl) for symbol, pnl in by_symbol.items() if pnl < 0]
    winners.sort(key=lambda item: item[1], reverse=True)
    losers.sort(key=lambda item: item[1])
    return (
        "; ".join(f"{symbol}:{pnl:.2f}" for symbol, pnl in winners[:3]),
        "; ".join(f"{symbol}:{pnl:.2f}" for symbol, pnl in losers[:3]),
    )


def md_table(rows: list[dict[str, object]], columns: list[str]) -> str:
    lines = []
    lines.append("| " + " | ".join(columns) + " |")
    lines.append("| " + " | ".join(["---"] * len(columns)) + " |")
    for row in rows:
        lines.append("| " + " | ".join(str(row.get(col, "")) for col in columns) + " |")
    return "\n".join(lines)


def read_phase2_baseline() -> list[dict[str, str]]:
    path = BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_run_comparison.csv"
    if not path.exists():
        return []
    rows = []
    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            if row.get("run") in {"A", "B", "C", "D"}:
                rows.append(row)
    return rows


def write_summary(comparison_rows: list[dict[str, object]], summaries: dict[str, dict[str, object]]) -> None:
    phase2 = read_phase2_baseline()
    phase2_rows = [
        {
            "scenario": row["scenario"],
            "trades": row["trades"],
            "net_profit": row["net_profit"],
            "profit_factor": row["profit_factor"],
            "expected_payoff": row["expected_payoff"],
            "max_balance_dd_pct": row["max_balance_dd_pct"],
        }
        for row in phase2
    ]
    thirdwave_rows = [
        {
            "scenario": row["scenario"],
            "trades": row["trades"],
            "net_profit": row["net_profit"],
            "profit_factor": row["profit_factor"],
            "expected_payoff": row["expected_payoff"],
            "max_balance_dd_pct": row["max_balance_dd_pct"],
            "long_net_profit": row["long_net_profit"],
            "short_net_profit": row["short_net_profit"],
            "usdjpy_short_net_profit": row["usdjpy_short_net_profit"],
        }
        for row in comparison_rows
    ]
    summary_rows = []
    for run in RUNS:
        summary = summaries.get(run["run"], {})
        summary_rows.append(
            {
                "scenario": run["scenario"],
                "evaluations": summary.get("evaluations", 0),
                "setup_pass": summary.get("setup_pass", 0),
                "entry_pass": summary.get("entry_pass", 0),
                "orders_sent": summary.get("orders_sent", 0),
                "top_skip_reason": summary.get("top_skip_reason", ""),
                "top_skip_reason_rows": summary.get("top_skip_reason_rows", 0),
            }
        )

    lines = [
        "# DowFractal ThirdWave Initial Backtest",
        "",
        "## Scope",
        "",
        "- Added as a separate research strategy branch via `InpResearchStrategyMode`.",
        "- Existing score scanner and existing Dow/FractalStructureFilter logic are unchanged.",
        "- Initial validation uses 2025 full-year runs: BOTH, LONG_ONLY, SHORT_ONLY.",
        "- Hard-loss stops remain disabled with the same research thresholds used in Phase 2.",
        "- No parameter optimization was performed.",
        "",
        "## Logic",
        "",
        "- Mode switch: `InpResearchStrategyMode=RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE`.",
        "- Long setup: higher-timeframe HH/HL trend, mid-timeframe pullback that does not break the structural low, then closed-bar lower-timeframe minor-high reclaim.",
        "- Short setup: higher-timeframe LL/LH trend, mid-timeframe pullback that does not break the structural high, then closed-bar lower-timeframe minor-low breakdown.",
        "- SL: structure based, below the mid-timeframe pullback fractal low for longs and above the pullback fractal high for shorts, with spread/ATR buffer.",
        "- TP: fixed `InpRewardR` multiple from the structure stop distance.",
        "- Logs: `thirdwave_signal_diagnostics.csv`, `thirdwave_trade_diagnostics.csv`, and `thirdwave_summary.csv`; full non-candidate rows are summarized by counters.",
        "",
        "## ThirdWave Results",
        "",
        md_table(
            thirdwave_rows,
            [
                "scenario",
                "trades",
                "net_profit",
                "profit_factor",
                "expected_payoff",
                "max_balance_dd_pct",
                "long_net_profit",
                "short_net_profit",
                "usdjpy_short_net_profit",
            ],
        ),
        "",
        "## Signal Diagnostics",
        "",
        md_table(
            summary_rows,
            [
                "scenario",
                "evaluations",
                "setup_pass",
                "entry_pass",
                "orders_sent",
                "top_skip_reason",
                "top_skip_reason_rows",
            ],
        ),
        "",
        "## Phase 2 Reference",
        "",
        md_table(
            phase2_rows,
            [
                "scenario",
                "trades",
                "net_profit",
                "profit_factor",
                "expected_payoff",
                "max_balance_dd_pct",
            ],
        ),
        "",
        "## Artifacts",
        "",
        f"- Run comparison: `reports/backtest/{OUT_PREFIX}_run_comparison.csv`",
        f"- By direction: `reports/backtest/{OUT_PREFIX}_by_direction.csv`",
        f"- By symbol: `reports/backtest/{OUT_PREFIX}_by_symbol.csv`",
        f"- By skip reason: `reports/backtest/{OUT_PREFIX}_by_skip_reason.csv`",
        f"- Signal diagnostics: `reports/backtest/*_thirdwave_signal_diagnostics.csv`",
        f"- Trade diagnostics: `reports/backtest/*_thirdwave_trade_diagnostics.csv`",
        "- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_compile.txt`",
    ]

    (BACKTEST / f"{OUT_PREFIX}_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_devlog(comparison_rows: list[dict[str, object]]) -> None:
    devlog = BACKTEST.parents[1] / "docs" / "devlog" / "2026-06-03-dow-fractal-thirdwave.md"
    lines = [
        "# 2026-06-03 - DowFractal ThirdWave Branch",
        "",
        "## Summary",
        "",
        "- Added `RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE` as a separate branch inside `ExpectedValue_MultiCurrency_ScoreScanner.mq5`.",
        "- Kept the Phase 2 score scanner and Dow/fractal structure filter intact.",
        "- Ran 2025 initial checks for BOTH, LONG_ONLY, and SHORT_ONLY.",
        "- Compile result: 0 errors / 0 warnings.",
        "",
        "## Results",
        "",
        md_table(
            comparison_rows,
            [
                "scenario",
                "trades",
                "net_profit",
                "profit_factor",
                "expected_payoff",
                "max_balance_dd_pct",
                "long_net_profit",
                "short_net_profit",
            ],
        ),
        "",
        "## Evidence",
        "",
        f"- Summary: `reports/backtest/{OUT_PREFIX}_summary.md`",
        f"- Run comparison: `reports/backtest/{OUT_PREFIX}_run_comparison.csv`",
        "- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_compile.txt`",
    ]
    devlog.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    elapsed = read_elapsed()
    run_trades: dict[str, list[dict[str, object]]] = {}
    summaries: dict[str, dict[str, object]] = {}
    trade_logs: dict[str, list[dict[str, str]]] = {}

    for run in RUNS:
        prefix = run["prefix"]
        trades = parse_mt5_deals(BACKTEST / f"{prefix}_report.html")
        write_trades(BACKTEST / f"{prefix}_trades.csv", trades)
        run_trades[run["run"]] = read_trades(BACKTEST / f"{prefix}_trades.csv")
        summaries[run["run"]] = read_thirdwave_summary(BACKTEST / f"{prefix}_thirdwave_summary.csv")
        trade_logs[run["run"]] = read_trade_diagnostics(BACKTEST / f"{prefix}_thirdwave_trade_diagnostics.csv")

    comparison_rows = []
    for run in RUNS:
        trades = run_trades[run["run"]]
        stats = calc_stats(trades)
        long_trades = [t for t in trades if t["direction"] == "LONG"]
        short_trades = [t for t in trades if t["direction"] == "SHORT"]
        xau_trades = [t for t in trades if t["symbol"] == "XAUUSD"]
        usd_short = [t for t in trades if t["symbol"] == "USDJPY" and t["direction"] == "SHORT"]
        winners, losers = major_symbols(trades)
        summary = summaries[run["run"]]
        comparison_rows.append(
            {
                "run": run["run"],
                "scenario": run["scenario"],
                "elapsed_seconds": elapsed.get(run["run"], ""),
                "trades": stats["trades"],
                "wins": stats["wins"],
                "losses": stats["losses"],
                "win_rate": round(float(stats["win_rate"]), 2),
                "net_profit": round(float(stats["net_profit"]), 2),
                "profit_factor": pf_value(stats),
                "expected_payoff": round(float(stats["expected_payoff"]), 2),
                "gross_profit": round(float(stats["gross_profit"]), 2),
                "gross_loss": round(float(stats["gross_loss"]), 2),
                "avg_win": round(float(stats["avg_win"]), 2),
                "avg_loss": round(float(stats["avg_loss"]), 2),
                "max_balance_dd": round(float(stats["max_balance_dd"]), 2),
                "max_balance_dd_pct": round(float(stats["max_balance_dd_pct"]), 2),
                "max_balance_dd_time": stats["max_balance_dd_time"].strftime("%Y.%m.%d %H:%M:%S")
                if stats["max_balance_dd_time"]
                else "",
                "max_consecutive_losses": stats["max_consecutive_losses"]["count"],
                "max_consecutive_losses_amount": round(float(stats["max_consecutive_losses"]["amount"]), 2),
                "long_trades": len(long_trades),
                "long_net_profit": round(sum(float(t["net_profit"]) for t in long_trades), 2),
                "short_trades": len(short_trades),
                "short_net_profit": round(sum(float(t["net_profit"]) for t in short_trades), 2),
                "xauusd_trades": len(xau_trades),
                "xauusd_trade_share_pct": round(len(xau_trades) / len(trades) * 100.0, 2) if trades else 0.0,
                "xauusd_net_profit": round(sum(float(t["net_profit"]) for t in xau_trades), 2),
                "usdjpy_short_trades": len(usd_short),
                "usdjpy_short_net_profit": round(sum(float(t["net_profit"]) for t in usd_short), 2),
                "major_winning_symbols": winners,
                "major_losing_symbols": losers,
                "thirdwave_evaluations": summary.get("evaluations", 0),
                "thirdwave_setup_pass": summary.get("setup_pass", 0),
                "thirdwave_entry_pass": summary.get("entry_pass", 0),
                "thirdwave_orders_sent": summary.get("orders_sent", 0),
                "thirdwave_top_skip_reason": summary.get("top_skip_reason", ""),
            }
        )

    write_rows(BACKTEST / f"{OUT_PREFIX}_run_comparison.csv", comparison_rows)
    group_csv(BACKTEST / f"{OUT_PREFIX}_by_year.csv", run_trades, lambda t: t["open_time"].strftime("%Y"))
    group_csv(BACKTEST / f"{OUT_PREFIX}_by_month.csv", run_trades, lambda t: t["open_time"].strftime("%Y-%m"))
    group_csv(BACKTEST / f"{OUT_PREFIX}_by_symbol.csv", run_trades, lambda t: t["symbol"])
    group_csv(BACKTEST / f"{OUT_PREFIX}_by_direction.csv", run_trades, lambda t: t["direction"])
    group_csv(BACKTEST / f"{OUT_PREFIX}_by_direction_symbol.csv", run_trades, lambda t: f"{t['direction']}:{t['symbol']}")
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_skip_reason.csv", build_skip_rows(summaries))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_rr.csv", build_rr_rows(trade_logs))

    summary_rows = [{"run": run["run"], "scenario": run["scenario"], **summaries[run["run"]]} for run in RUNS]
    write_rows(BACKTEST / f"{OUT_PREFIX}_signal_summary.csv", summary_rows)

    metrics = {
        "runs": {run_name: serialize_stats(calc_stats(trades)) for run_name, trades in run_trades.items()},
        "comparison_rows": comparison_rows,
        "thirdwave_summaries": summaries,
    }
    with (BACKTEST / f"{OUT_PREFIX}_metrics.json").open("w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=2)

    write_summary(comparison_rows, summaries)
    write_devlog(comparison_rows)
    print(json.dumps(comparison_rows, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
