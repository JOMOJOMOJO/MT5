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
    score_band,
    serialize_stats,
    write_rows,
    write_trades,
)


OUT_PREFIX = "ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2"

RUNS = [
    {
        "run": "A",
        "scenario": "BOTH_5m_new_bar",
        "prefix": "ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_A_both_5m",
        "elapsed_seconds": 1160.2,
    },
    {
        "run": "B",
        "scenario": "LONG_ONLY_5m_new_bar",
        "prefix": "ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_B_long_only_5m",
        "elapsed_seconds": 1159.9,
    },
    {
        "run": "C",
        "scenario": "SHORT_ONLY_5m_new_bar",
        "prefix": "ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_C_short_only_5m",
        "elapsed_seconds": 3784.1,
    },
    {
        "run": "D",
        "scenario": "LONG_ONLY_DowFractal_5m_new_bar",
        "prefix": "ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_D_long_structure_5m",
        "elapsed_seconds": 1334.0,
    },
    {
        "run": "E",
        "scenario": "XAUUSD_ONLY_LONG_ONLY_DowFractal_5m_new_bar",
        "prefix": "ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_E_xau_long_structure_5m",
        "elapsed_seconds": 3777.6,
    },
    {
        "run": "F",
        "scenario": "BOTH_disable_USDJPY_SHORT_5m_new_bar",
        "prefix": "ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_F_disable_usdjpy_short_5m",
        "elapsed_seconds": 3784.2,
    },
]


def pf_value(stats: dict[str, object]) -> object:
    return round(float(stats["profit_factor"]), 3) if stats["profit_factor"] is not None else ""


def group_csv(path: Path, run_trades: dict[str, list[dict[str, object]]], key_fn) -> None:
    rows: list[dict[str, object]] = []
    for run_name, trades in run_trades.items():
        scenario = next(item["scenario"] for item in RUNS if item["run"] == run_name)
        for row in group_stats(trades, key_fn):
            rows.append({"run": run_name, "scenario": scenario, **row})
    write_rows(path, rows)


def read_scan_diagnostics(path: Path) -> dict[str, object]:
    events = Counter()
    elapsed: list[int] = []
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


def read_structure_diagnostics(path: Path) -> tuple[dict[str, object], list[dict[str, object]], list[dict[str, object]]]:
    rows = 0
    pass_count = 0
    fail_count = 0
    by_reason = Counter()
    by_direction = defaultdict(lambda: {"rows": 0, "pass": 0, "fail": 0})
    combined_rows: list[dict[str, object]] = []

    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            if not row.get("symbol"):
                continue
            rows += 1
            passed = row.get("structure_filter_pass", "").lower() == "true"
            direction = row.get("direction", "")
            by_direction[direction]["rows"] += 1
            if passed:
                pass_count += 1
                by_direction[direction]["pass"] += 1
            else:
                fail_count += 1
                by_direction[direction]["fail"] += 1
                by_reason[row.get("structure_filter_fail_reason", "") or "unknown"] += 1
            combined_rows.append(row)

    summary = {
        "rows": rows,
        "pass": pass_count,
        "fail": fail_count,
        "pass_rate": round(pass_count / rows * 100.0, 2) if rows else 0.0,
        "top_fail_reason": by_reason.most_common(1)[0][0] if by_reason else "",
        "top_fail_reason_rows": by_reason.most_common(1)[0][1] if by_reason else 0,
    }

    reason_rows = [{"reason": key, "rows": value} for key, value in sorted(by_reason.items())]
    direction_rows = []
    for direction, values in sorted(by_direction.items()):
        row_count = values["rows"]
        direction_rows.append(
            {
                "direction": direction,
                "rows": row_count,
                "pass": values["pass"],
                "fail": values["fail"],
                "pass_rate": round(values["pass"] / row_count * 100.0, 2) if row_count else 0.0,
            }
        )
    return summary, reason_rows, direction_rows, combined_rows


def read_structure_summary(path: Path) -> tuple[dict[str, object] | None, list[dict[str, object]]]:
    if not path.exists():
        return None, []

    latest: dict[str, str] | None = None
    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            if row.get("structure_evaluations"):
                latest = row

    if latest is None:
        return None, []

    def as_int(key: str) -> int:
        value = latest.get(key, "")
        return int(float(value)) if value != "" else 0

    summary = {
        "rows": as_int("structure_evaluations"),
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


def main() -> None:
    run_trades: dict[str, list[dict[str, object]]] = {}
    score_summaries: dict[str, dict[str, object]] = {}
    score_entries: dict[str, list[dict[str, object]]] = {}
    scan_summaries: dict[str, dict[str, object]] = {}
    structure_summaries: dict[str, dict[str, object]] = {}
    all_structure_reason_rows: list[dict[str, object]] = []
    all_structure_direction_rows: list[dict[str, object]] = []
    all_structure_rows: list[dict[str, object]] = []

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

        detail_structure_summary, detail_reason_rows, direction_rows, structure_rows = read_structure_diagnostics(
            BACKTEST / f"{prefix}_structure_diagnostics.csv"
        )
        structure_summary_from_file, summary_reason_rows = read_structure_summary(BACKTEST / f"{prefix}_structure_summary.csv")
        structure_summary = structure_summary_from_file if structure_summary_from_file is not None else {
            **detail_structure_summary,
            "evaluations": detail_structure_summary["rows"],
            "detail_rows": detail_structure_summary["rows"],
        }
        structure_summaries[run["run"]] = structure_summary
        reason_rows = summary_reason_rows if summary_reason_rows else detail_reason_rows
        for row in reason_rows:
            all_structure_reason_rows.append({"run": run["run"], "scenario": run["scenario"], **row})
        for row in direction_rows:
            all_structure_direction_rows.append({"run": run["run"], "scenario": run["scenario"], **row})
        for row in structure_rows:
            all_structure_rows.append({"run": run["run"], "scenario": run["scenario"], **row})

    joined: list[dict[str, object]] = []
    for run in RUNS:
        run_name = run["run"]
        rows = join_trades_to_scores(run_name, run_trades[run_name], score_entries[run_name])
        for row in rows:
            row["scenario"] = run["scenario"]
        joined.extend(rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_trade_join.csv", joined)

    comparison_rows = []
    for run in RUNS:
        run_name = run["run"]
        trades = run_trades[run_name]
        stats = calc_stats(trades)
        xau_trades = [t for t in trades if t["symbol"] == "XAUUSD"]
        usd_short = [t for t in trades if t["symbol"] == "USDJPY" and t["direction"] == "SHORT"]
        long_trades = [t for t in trades if t["direction"] == "LONG"]
        short_trades = [t for t in trades if t["direction"] == "SHORT"]
        scan = scan_summaries[run_name]
        comparison_rows.append(
            {
                "run": run_name,
                "scenario": run["scenario"],
                "elapsed_seconds": run["elapsed_seconds"],
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
                "score_detail_rows": score_summaries[run_name]["rows"],
                "score_rows": score_summaries[run_name]["rows"],
                "entry_score_ok_rows": score_summaries[run_name]["flags"].get("entry_score_ok", 0),
                "best_candidate_rows": score_summaries[run_name]["flags"].get("best_candidate", 0),
                "new_bar_scans": scan["new_bar_scans"],
                "same_bar_skips": scan["same_bar_skips"],
                "avg_scan_elapsed_ms": scan["avg_scan_elapsed_ms"],
                "max_scan_elapsed_ms": scan["max_scan_elapsed_ms"],
                "structure_evaluations": structure_summaries[run_name].get("evaluations", structure_summaries[run_name]["rows"]),
                "structure_detail_rows": structure_summaries[run_name].get("detail_rows", structure_summaries[run_name]["rows"]),
                "structure_rows": structure_summaries[run_name]["rows"],
                "structure_pass_rate": structure_summaries[run_name]["pass_rate"],
                "structure_top_fail_reason": structure_summaries[run_name]["top_fail_reason"],
            }
        )
    write_rows(BACKTEST / f"{OUT_PREFIX}_run_comparison.csv", comparison_rows)

    group_csv(BACKTEST / f"{OUT_PREFIX}_by_symbol.csv", run_trades, lambda t: t["symbol"])
    group_csv(BACKTEST / f"{OUT_PREFIX}_by_direction.csv", run_trades, lambda t: t["direction"])
    group_csv(BACKTEST / f"{OUT_PREFIX}_by_symbol_direction.csv", run_trades, lambda t: f"{t['symbol']}:{t['direction']}")
    group_csv(BACKTEST / f"{OUT_PREFIX}_by_month.csv", run_trades, lambda t: t["open_time"].strftime("%Y-%m"))
    group_csv(BACKTEST / f"{OUT_PREFIX}_by_hour.csv", run_trades, lambda t: f"{t['open_time'].hour:02d}")

    score_band_trades: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in joined:
        synthetic = {
            "net_profit": float(row["net_profit"]),
            "open_time": parse_time(str(row["open_time"])),
            "close_time": parse_time(str(row["close_time"])),
        }
        score_band_trades[f"{row['run']}|{row['score_band']}"].append(synthetic)
    score_band_rows = []
    for key, trades in sorted(score_band_trades.items()):
        run_name, band = key.split("|", 1)
        scenario = next(item["scenario"] for item in RUNS if item["run"] == run_name)
        stats = calc_stats(trades)
        score_band_rows.append(
            {
                "run": run_name,
                "scenario": scenario,
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
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_score_band.csv", score_band_rows)

    scan_summary_rows = []
    score_count_rows = []
    structure_summary_rows = []
    for run in RUNS:
        run_name = run["run"]
        scan = scan_summaries[run_name]
        scan_summary_rows.append({"run": run_name, "scenario": run["scenario"], **scan})
        for kind in ("entry_by_symbol", "entry_by_direction", "best_by_symbol", "best_by_direction"):
            for key, value in sorted(score_summaries[run_name][kind].items()):
                score_count_rows.append({"run": run_name, "scenario": run["scenario"], "kind": kind, "group": key, "rows": value})
        structure_summary_rows.append({"run": run_name, "scenario": run["scenario"], **structure_summaries[run_name]})

    write_rows(BACKTEST / f"{OUT_PREFIX}_scan_diagnostics_summary.csv", scan_summary_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_score_counts.csv", score_count_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_structure_filter_summary.csv", structure_summary_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_structure_filter_by_reason.csv", all_structure_reason_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_structure_filter_by_direction.csv", all_structure_direction_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_structure_filter_diagnostics.csv", all_structure_rows)

    metrics = {
        "runs": {run_name: serialize_stats(calc_stats(trades)) for run_name, trades in run_trades.items()},
        "comparison_rows": comparison_rows,
        "scan_summaries": scan_summaries,
        "structure_summaries": structure_summaries,
        "score_summaries": score_summaries,
    }
    with (BACKTEST / f"{OUT_PREFIX}_metrics.json").open("w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=2)

    print(json.dumps(comparison_rows, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
