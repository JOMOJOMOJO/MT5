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
    join_trades_to_scores,
    parse_mt5_deals,
    parse_time,
    read_trades,
    scan_scores,
    serialize_stats,
    write_rows,
    write_trades,
)


OUT_PREFIX = "ExpectedValue_MultiCurrency_ScoreScanner_oos"

RUNS = [
    {
        "run": "2024D",
        "year": "2024",
        "scenario": "LONG_ONLY_DowFractal_5m_new_bar",
        "prefix": "ExpectedValue_MultiCurrency_ScoreScanner_2024_oos_D_long_structure",
        "from": "2024.01.01",
        "to": "2024.12.31",
    },
    {
        "run": "2024E",
        "year": "2024",
        "scenario": "XAUUSD_ONLY_LONG_ONLY_DowFractal_5m_new_bar",
        "prefix": "ExpectedValue_MultiCurrency_ScoreScanner_2024_oos_E_xau_long_structure",
        "from": "2024.01.01",
        "to": "2024.12.31",
    },
    {
        "run": "2026D",
        "year": "2026YTD",
        "scenario": "LONG_ONLY_DowFractal_5m_new_bar",
        "prefix": "ExpectedValue_MultiCurrency_ScoreScanner_2026YTD_oos_D_long_structure",
        "from": "2026.01.01",
        "to": "2026.06.02",
    },
    {
        "run": "2026E",
        "year": "2026YTD",
        "scenario": "XAUUSD_ONLY_LONG_ONLY_DowFractal_5m_new_bar",
        "prefix": "ExpectedValue_MultiCurrency_ScoreScanner_2026YTD_oos_E_xau_long_structure",
        "from": "2026.01.01",
        "to": "2026.06.02",
    },
]

BASELINE_PREFIX = "ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2"


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


def read_scan_diagnostics(path: Path) -> dict[str, object]:
    events = Counter()
    elapsed: list[int] = []
    if not path.exists():
        return {
            "events": {},
            "new_bar_scans": 0,
            "same_bar_skips": 0,
            "avg_scan_elapsed_ms": 0.0,
            "max_scan_elapsed_ms": 0,
        }
    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            event = row.get("event", "")
            if not event:
                continue
            events[event] += 1
            if event == "scan_executed_new_execution_bar":
                value = row.get("scan_elapsed_ms", "")
                if value:
                    elapsed.append(int(value))
    return {
        "events": dict(events),
        "new_bar_scans": events.get("scan_executed_new_execution_bar", 0),
        "same_bar_skips": events.get("scan_skipped_same_execution_bar", 0),
        "avg_scan_elapsed_ms": round(sum(elapsed) / len(elapsed), 2) if elapsed else 0.0,
        "max_scan_elapsed_ms": max(elapsed) if elapsed else 0,
    }


def read_structure_summary(path: Path) -> tuple[dict[str, object], list[dict[str, object]]]:
    latest: dict[str, str] | None = None
    if path.exists():
        with path.open(newline="", encoding="utf-8-sig") as fh:
            for row in csv.DictReader(fh):
                if row.get("structure_evaluations"):
                    latest = row

    if latest is None:
        return {
            "evaluations": 0,
            "detail_rows": 0,
            "pass": 0,
            "fail": 0,
            "pass_rate": 0.0,
            "top_fail_reason": "",
            "top_fail_reason_rows": 0,
        }, []

    def as_int(key: str) -> int:
        value = latest.get(key, "")
        return int(float(value)) if value != "" else 0

    summary = {
        "evaluations": as_int("structure_evaluations"),
        "detail_rows": as_int("structure_detail_rows"),
        "pass": as_int("structure_pass"),
        "fail": as_int("structure_fail"),
        "pass_rate": float(latest.get("structure_pass_rate", "") or 0.0),
        "top_fail_reason": latest.get("structure_top_fail_reason", ""),
        "top_fail_reason_rows": as_int("structure_top_fail_reason_rows"),
    }

    reason_keys = [
        "no_context_swings",
        "no_trend_up",
        "no_trend_down",
        "pullback_too_deep",
        "pullback_not_valid",
        "no_fractal_low",
        "no_fractal_high",
        "not_enough_fractals",
        "no_reclaim",
        "unknown",
    ]
    reason_rows = [{"reason": key, "rows": as_int(key)} for key in reason_keys if as_int(key) > 0]
    return summary, reason_rows


def group_csv(path: Path, run_trades: dict[str, list[dict[str, object]]], key_fn) -> None:
    rows: list[dict[str, object]] = []
    for run in RUNS:
        for row in group_stats(run_trades[run["run"]], key_fn):
            rows.append({"run": run["run"], "year": run["year"], "scenario": run["scenario"], **row})
    write_rows(path, rows)


def major_symbols(trades: list[dict[str, object]]) -> tuple[str, str]:
    by_symbol: dict[str, float] = defaultdict(float)
    for trade in trades:
        by_symbol[str(trade["symbol"])] += float(trade["net_profit"])

    winners = [(symbol, pnl) for symbol, pnl in by_symbol.items() if pnl > 0]
    losers = [(symbol, pnl) for symbol, pnl in by_symbol.items() if pnl < 0]
    winners.sort(key=lambda item: item[1], reverse=True)
    losers.sort(key=lambda item: item[1])
    winner_text = "; ".join(f"{symbol}:{pnl:.2f}" for symbol, pnl in winners[:3])
    loser_text = "; ".join(f"{symbol}:{pnl:.2f}" for symbol, pnl in losers[:3])
    return winner_text, loser_text


def build_score_band_rows(joined: list[dict[str, object]]) -> list[dict[str, object]]:
    score_band_trades: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in joined:
        synthetic = {
            "net_profit": float(row["net_profit"]),
            "open_time": parse_time(str(row["open_time"])),
            "close_time": parse_time(str(row["close_time"])),
        }
        score_band_trades[f"{row['run']}|{row['score_band']}"].append(synthetic)

    rows = []
    for key, trades in sorted(score_band_trades.items()):
        run_name, band = key.split("|", 1)
        run = next(item for item in RUNS if item["run"] == run_name)
        stats = calc_stats(trades)
        rows.append(
            {
                "run": run_name,
                "year": run["year"],
                "scenario": run["scenario"],
                "group": band,
                "trades": stats["trades"],
                "wins": stats["wins"],
                "losses": stats["losses"],
                "win_rate": round(float(stats["win_rate"]), 2),
                "net_profit": round(float(stats["net_profit"]), 2),
                "profit_factor": pf_value(stats),
                "expected_payoff": round(float(stats["expected_payoff"]), 2),
                "avg_win": round(float(stats["avg_win"]), 2),
                "avg_loss": round(float(stats["avg_loss"]), 2),
            }
        )
    return rows


def read_2025_baseline() -> list[dict[str, str]]:
    path = BACKTEST / f"{BASELINE_PREFIX}_run_comparison.csv"
    if not path.exists():
        return []
    rows = []
    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            if row.get("run") in {"D", "E"}:
                rows.append(row)
    return rows


def md_table(rows: list[dict[str, object]], columns: list[str]) -> str:
    lines = []
    lines.append("| " + " | ".join(columns) + " |")
    lines.append("| " + " | ".join(["---"] * len(columns)) + " |")
    for row in rows:
        lines.append("| " + " | ".join(str(row.get(col, "")) for col in columns) + " |")
    return "\n".join(lines)


def write_summary(comparison_rows: list[dict[str, object]], baseline_rows: list[dict[str, str]]) -> None:
    baseline_compact = []
    for row in baseline_rows:
        scenario = row["scenario"]
        baseline_compact.append(
            {
                "year": "2025",
                "scenario": scenario,
                "trades": row["trades"],
                "win_rate": row["win_rate"],
                "net_profit": row["net_profit"],
                "profit_factor": row["profit_factor"],
                "expected_payoff": row["expected_payoff"],
                "max_balance_dd_pct": row["max_balance_dd_pct"],
                "xauusd_trade_share_pct": row["xauusd_trade_share_pct"],
                "xauusd_net_profit": row["xauusd_net_profit"],
            }
        )

    oos_compact = [
        {
            "year": row["year"],
            "scenario": row["scenario"],
            "trades": row["trades"],
            "win_rate": row["win_rate"],
            "net_profit": row["net_profit"],
            "profit_factor": row["profit_factor"],
            "expected_payoff": row["expected_payoff"],
            "max_balance_dd_pct": row["max_balance_dd_pct"],
            "xauusd_trade_share_pct": row["xauusd_trade_share_pct"],
            "xauusd_net_profit": row["xauusd_net_profit"],
        }
        for row in comparison_rows
    ]

    all_long_oos = [row for row in comparison_rows if row["scenario"] == "LONG_ONLY_DowFractal_5m_new_bar"]
    all_xau_oos = [row for row in comparison_rows if row["scenario"] == "XAUUSD_ONLY_LONG_ONLY_DowFractal_5m_new_bar"]
    long_positive = all(float(row["profit_factor"]) > 1.0 for row in all_long_oos if row["trades"])
    xau_positive = all(float(row["profit_factor"]) > 1.0 for row in all_xau_oos if row["trades"])

    lines = [
        "# Multi-Currency Score Scanner OOS Check",
        "",
        "## Scope",
        "",
        "- Existing Phase 2 D/E settings were reused without optimization.",
        "- Hard-loss stops remain disabled with the same large research thresholds used in Phase 2.",
        "- OOS windows: 2024-01-01 to 2024-12-31, and 2026-01-01 to 2026-06-02.",
        "- No trade logic, score logic, Dow/fractal structure filter, TP/SL, CTrade bridge, or risk sizing was changed.",
        "",
        "## 2025 Baseline",
        "",
        md_table(
            baseline_compact,
            [
                "year",
                "scenario",
                "trades",
                "win_rate",
                "net_profit",
                "profit_factor",
                "expected_payoff",
                "max_balance_dd_pct",
                "xauusd_trade_share_pct",
                "xauusd_net_profit",
            ],
        ),
        "",
        "## OOS Results",
        "",
        md_table(
            oos_compact,
            [
                "year",
                "scenario",
                "trades",
                "win_rate",
                "net_profit",
                "profit_factor",
                "expected_payoff",
                "max_balance_dd_pct",
                "xauusd_trade_share_pct",
                "xauusd_net_profit",
            ],
        ),
        "",
        "## Judgment",
        "",
        f"- LONG_ONLY + DowFractalStructureFilter OOS PF>1 across tested windows: {'yes' if long_positive else 'no'}.",
        f"- XAUUSD_ONLY + LONG_ONLY + DowFractalStructureFilter OOS PF>1 across tested windows: {'yes' if xau_positive else 'no'}.",
        "- Treat this as validation evidence only. No improvement or parameter search was performed.",
        "",
        "## Artifacts",
        "",
        f"- Run comparison: `reports/backtest/{OUT_PREFIX}_run_comparison.csv`",
        f"- By symbol: `reports/backtest/{OUT_PREFIX}_by_symbol.csv`",
        f"- By direction: `reports/backtest/{OUT_PREFIX}_by_direction.csv`",
        f"- By month: `reports/backtest/{OUT_PREFIX}_by_month.csv`",
        f"- By score band: `reports/backtest/{OUT_PREFIX}_by_score_band.csv`",
    ]

    (BACKTEST / f"{OUT_PREFIX}_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_devlog(comparison_rows: list[dict[str, object]]) -> None:
    devlog = BACKTEST.parents[1] / "docs" / "devlog" / "2026-06-03-multicurrency-score-scanner-oos.md"
    lines = [
        "# 2026-06-03 - Multi-Currency Score Scanner OOS Check",
        "",
        "## Summary",
        "",
        "- Checked Phase 2 D/E branches out of sample without optimization.",
        "- Windows: 2024 full year and 2026 YTD through 2026-06-02.",
        "- Conditions match Phase 2 research runs: M5 new-bar scan, CTrade bridge, existing TP/SL, existing risk sizing, hard stops disabled.",
        "",
        "## Results",
        "",
        md_table(
            comparison_rows,
            [
                "year",
                "scenario",
                "trades",
                "net_profit",
                "profit_factor",
                "expected_payoff",
                "max_balance_dd_pct",
                "major_winning_symbols",
                "major_losing_symbols",
            ],
        ),
        "",
        "## Evidence",
        "",
        f"- Summary: `reports/backtest/{OUT_PREFIX}_summary.md`",
        f"- Run comparison: `reports/backtest/{OUT_PREFIX}_run_comparison.csv`",
    ]
    devlog.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    elapsed = read_elapsed()
    run_trades: dict[str, list[dict[str, object]]] = {}
    score_summaries: dict[str, dict[str, object]] = {}
    score_entries: dict[str, list[dict[str, object]]] = {}
    scan_summaries: dict[str, dict[str, object]] = {}
    structure_summaries: dict[str, dict[str, object]] = {}
    structure_reason_rows: list[dict[str, object]] = []

    for run in RUNS:
        prefix = run["prefix"]
        report_path = BACKTEST / f"{prefix}_report.html"
        trades = parse_mt5_deals(report_path)
        write_trades(BACKTEST / f"{prefix}_trades.csv", trades)
        run_trades[run["run"]] = read_trades(BACKTEST / f"{prefix}_trades.csv")

        score_summary, entries = scan_scores(BACKTEST / f"{prefix}_scores.csv")
        score_summaries[run["run"]] = score_summary
        score_entries[run["run"]] = entries
        scan_summaries[run["run"]] = read_scan_diagnostics(BACKTEST / f"{prefix}_scan_diagnostics.csv")
        structure_summary, reasons = read_structure_summary(BACKTEST / f"{prefix}_structure_summary.csv")
        structure_summaries[run["run"]] = structure_summary
        for row in reasons:
            structure_reason_rows.append({"run": run["run"], "year": run["year"], "scenario": run["scenario"], **row})

    joined: list[dict[str, object]] = []
    for run in RUNS:
        rows = join_trades_to_scores(run["run"], run_trades[run["run"]], score_entries[run["run"]])
        for row in rows:
            row["year"] = run["year"]
            row["scenario"] = run["scenario"]
        joined.extend(rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_trade_join.csv", joined)

    comparison_rows = []
    for run in RUNS:
        trades = run_trades[run["run"]]
        stats = calc_stats(trades)
        xau_trades = [t for t in trades if t["symbol"] == "XAUUSD"]
        winners, losers = major_symbols(trades)
        scan = scan_summaries[run["run"]]
        structure = structure_summaries[run["run"]]
        comparison_rows.append(
            {
                "run": run["run"],
                "year": run["year"],
                "scenario": run["scenario"],
                "from": run["from"],
                "to": run["to"],
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
                "xauusd_trades": len(xau_trades),
                "xauusd_trade_share_pct": round(len(xau_trades) / len(trades) * 100.0, 2) if trades else 0.0,
                "xauusd_net_profit": round(sum(float(t["net_profit"]) for t in xau_trades), 2),
                "major_winning_symbols": winners,
                "major_losing_symbols": losers,
                "score_detail_rows": score_summaries[run["run"]]["rows"],
                "entry_score_ok_rows": score_summaries[run["run"]]["flags"].get("entry_score_ok", 0),
                "best_candidate_rows": score_summaries[run["run"]]["flags"].get("best_candidate", 0),
                "new_bar_scans": scan["new_bar_scans"],
                "same_bar_skips": scan["same_bar_skips"],
                "avg_scan_elapsed_ms": scan["avg_scan_elapsed_ms"],
                "max_scan_elapsed_ms": scan["max_scan_elapsed_ms"],
                "structure_evaluations": structure["evaluations"],
                "structure_detail_rows": structure["detail_rows"],
                "structure_pass_rate": structure["pass_rate"],
                "structure_top_fail_reason": structure["top_fail_reason"],
            }
        )

    write_rows(BACKTEST / f"{OUT_PREFIX}_run_comparison.csv", comparison_rows)
    group_csv(BACKTEST / f"{OUT_PREFIX}_by_symbol.csv", run_trades, lambda t: t["symbol"])
    group_csv(BACKTEST / f"{OUT_PREFIX}_by_direction.csv", run_trades, lambda t: t["direction"])
    group_csv(BACKTEST / f"{OUT_PREFIX}_by_symbol_direction.csv", run_trades, lambda t: f"{t['symbol']}:{t['direction']}")
    group_csv(BACKTEST / f"{OUT_PREFIX}_by_month.csv", run_trades, lambda t: t["open_time"].strftime("%Y-%m"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_score_band.csv", build_score_band_rows(joined))

    scan_rows = [{"run": run["run"], "year": run["year"], "scenario": run["scenario"], **scan_summaries[run["run"]]} for run in RUNS]
    structure_rows = [{"run": run["run"], "year": run["year"], "scenario": run["scenario"], **structure_summaries[run["run"]]} for run in RUNS]
    write_rows(BACKTEST / f"{OUT_PREFIX}_scan_diagnostics_summary.csv", scan_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_structure_filter_summary.csv", structure_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_structure_filter_by_reason.csv", structure_reason_rows)

    baseline_rows = read_2025_baseline()
    write_summary(comparison_rows, baseline_rows)
    write_devlog(comparison_rows)

    metrics = {
        "runs": {run_name: serialize_stats(calc_stats(trades)) for run_name, trades in run_trades.items()},
        "comparison_rows": comparison_rows,
        "scan_summaries": scan_summaries,
        "structure_summaries": structure_summaries,
        "score_summaries": score_summaries,
        "baseline_2025": baseline_rows,
    }
    with (BACKTEST / f"{OUT_PREFIX}_metrics.json").open("w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=2)

    print(json.dumps(comparison_rows, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
