#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import defaultdict
from datetime import datetime
from pathlib import Path

from analyze_multicurrency_score_scanner_2025 import (
    BACKTEST,
    calc_stats,
    group_stats,
    parse_mt5_deals,
    serialize_stats,
    write_rows,
    write_trades,
)


OUT_PREFIX = "ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_neckline_break"

PERIODS = [
    {
        "period": "2025-02",
        "series": "2025_02_nested_nwave",
    },
    {
        "period": "2025-08",
        "series": "2025_08_nested_nwave",
    },
    {
        "period": "2025-10",
        "series": "2025_10_nested_nwave",
    },
    {
        "period": "2026-Q1",
        "series": "2026_q1_nested_nwave",
    },
]

RUNS = [
    {
        "run": "A",
        "name": "A_current_thirdwave",
        "fallback_name": "A_current_regime_all_5m",
        "fallback_series_suffix": "thirdwave_v4",
        "fallback_run": "A",
        "scenario": "current_ThirdWave_regime_BOTH_all_5m",
        "strategy_family": "thirdwave_current",
        "entry_selection_mode": "ALL_SCORE_PASSING",
    },
    {
        "run": "B",
        "name": "B_v4_early_reversal",
        "fallback_name": "D_v4_early_reversal_all_5m",
        "fallback_series_suffix": "thirdwave_v4",
        "fallback_run": "D",
        "scenario": "v4_early_reversal_BOTH_all_5m",
        "strategy_family": "thirdwave_v4",
        "entry_selection_mode": "ALL_SCORE_PASSING",
    },
    {
        "run": "C",
        "name": "C_nested_best",
        "fallback_name": "",
        "fallback_series_suffix": "",
        "fallback_run": "",
        "scenario": "Nested_NWave_NecklineBreak_BOTH_best_H4_H1_M15_2R",
        "strategy_family": "nested_nwave",
        "entry_selection_mode": "BEST_ONLY",
    },
    {
        "run": "D",
        "name": "D_nested_all",
        "fallback_name": "",
        "fallback_series_suffix": "",
        "fallback_run": "",
        "scenario": "Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R",
        "strategy_family": "nested_nwave",
        "entry_selection_mode": "ALL_SCORE_PASSING",
    },
]


def prefix(series: str, run: dict[str, str]) -> str:
    return f"ExpectedValue_MultiCurrency_ScoreScanner_{series}_{run['name']}"


def fallback_prefix(series: str, run: dict[str, str]) -> str:
    suffix = run.get("fallback_series_suffix", "")
    name = run.get("fallback_name", "")
    if not suffix or not name:
        return ""
    parts = series.split("_")
    period_prefix = "_".join(parts[:2]) if len(parts) >= 2 and parts[0] == "2025" else "_".join(parts[:2])
    if series.startswith("2026_q1"):
        period_prefix = "2026_q1"
    return f"ExpectedValue_MultiCurrency_ScoreScanner_{period_prefix}_{suffix}_{name}"


def resolve_prefix(series: str, run: dict[str, str]) -> str:
    primary = prefix(series, run)
    if (BACKTEST / f"{primary}_report.html").exists():
        return primary
    fallback = fallback_prefix(series, run)
    if fallback and (BACKTEST / f"{fallback}_report.html").exists():
        return fallback
    return primary


def pf_value(stats: dict[str, object]) -> object:
    return round(float(stats["profit_factor"]), 3) if stats["profit_factor"] is not None else ""


def parse_time(value: str) -> datetime | None:
    value = value.strip()
    if not value:
        return None
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            pass
    return None


def read_elapsed(series: str) -> dict[str, float]:
    path = BACKTEST / f"ExpectedValue_MultiCurrency_ScoreScanner_{series}_elapsed.csv"
    if not path.exists():
        return {}
    values: dict[str, float] = {}
    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            if row.get("run") and row.get("elapsed_seconds"):
                values[row["run"]] = float(row["elapsed_seconds"])
    return values


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return list(csv.DictReader(fh))


def write_union_rows(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        return
    fields: list[str] = []
    for row in rows:
        for key in row.keys():
            if key not in fields:
                fields.append(key)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def read_nested_summary(path: Path) -> dict[str, object]:
    rows = read_csv_rows(path)
    if not rows:
        return {}
    latest = rows[-1]

    def as_int(key: str) -> int:
        value = latest.get(key, "")
        return int(float(value)) if value not in {"", None} else 0

    return {
        "evaluations": as_int("evaluations"),
        "h4_impulse_pass": as_int("h4_impulse_pass"),
        "pullback_zone_pass": as_int("pullback_zone_pass"),
        "h1_counter_trend_pass": as_int("h1_counter_trend_pass"),
        "neckline_pass": as_int("neckline_pass"),
        "final_entry_pass": as_int("final_entry_pass"),
        "orders_sent": as_int("orders_sent"),
        "orders_failed": as_int("orders_failed"),
        "top_fail_reason": latest.get("top_fail_reason", ""),
        "top_fail_reason_rows": as_int("top_fail_reason_rows"),
    }


def read_thirdwave_summary(path: Path) -> dict[str, object]:
    rows = read_csv_rows(path)
    if not rows:
        return {}
    latest = rows[-1]

    def as_int(key: str) -> int:
        value = latest.get(key, "")
        return int(float(value)) if value not in {"", None} else 0

    return {
        "evaluations": as_int("evaluations"),
        "final_entry_pass": as_int("final_entry_pass"),
        "orders_sent": as_int("orders_sent"),
        "orders_failed": as_int("orders_failed"),
        "top_fail_reason": latest.get("top_skip_reason", ""),
        "top_fail_reason_rows": as_int("top_skip_reason_rows"),
    }


def diagnostics_for_run(prefix_value: str, family: str) -> list[dict[str, object]]:
    if family == "nested_nwave":
        rows = read_csv_rows(BACKTEST / f"{prefix_value}_nested_nwave_trade_diagnostics.csv")
        event_rows = [row for row in rows if row.get("event") == "order_sent"]
        result = []
        for row in event_rows:
            result.append(
                {
                    "time": parse_time(row.get("time", "")),
                    "symbol": row.get("symbol", ""),
                    "direction": row.get("direction", ""),
                    "session": row.get("session", ""),
                    "label": row.get("label", "") or "unknown",
                    "fib_zone": row.get("fib_zone", "") or "unknown",
                    "neckline_break_label": row.get("neckline_break_label", "") or "unknown",
                }
            )
        return result

    rows = read_csv_rows(BACKTEST / f"{prefix_value}_thirdwave_trade_diagnostics.csv")
    event_rows = [row for row in rows if row.get("event") == "order_sent"]
    result = []
    for row in event_rows:
        result.append(
            {
                "time": parse_time(row.get("time", "")),
                "symbol": row.get("symbol", ""),
                "direction": row.get("direction", ""),
                "session": "unknown",
                "label": row.get("reversal_signal_type", "") or "thirdwave",
                "fib_zone": "n/a",
                "neckline_break_label": "n/a",
            }
        )
    return result


def attach_diagnostics(trades: list[dict[str, object]], diagnostics: list[dict[str, object]]) -> list[dict[str, object]]:
    used: set[int] = set()
    enriched: list[dict[str, object]] = []
    for trade in trades:
        best_idx = -1
        best_delta = 10**9
        for idx, diag in enumerate(diagnostics):
            if idx in used:
                continue
            if diag.get("symbol") != trade["symbol"] or diag.get("direction") != trade["direction"]:
                continue
            diag_time = diag.get("time")
            if not isinstance(diag_time, datetime):
                continue
            delta = abs((trade["open_time"] - diag_time).total_seconds())
            if delta <= 1800 and delta < best_delta:
                best_delta = delta
                best_idx = idx
        row = dict(trade)
        if best_idx >= 0:
            used.add(best_idx)
            diag = diagnostics[best_idx]
            row["session"] = diag.get("session", "unknown")
            row["label"] = diag.get("label", "unknown")
            row["fib_zone"] = diag.get("fib_zone", "unknown")
            row["neckline_break_label"] = diag.get("neckline_break_label", "unknown")
        else:
            row["session"] = "unknown"
            row["label"] = "unmatched"
            row["fib_zone"] = "unknown"
            row["neckline_break_label"] = "unknown"
        return_row = row
        enriched.append(return_row)
    return enriched


def major_groups(trades: list[dict[str, object]], key: str) -> tuple[str, str]:
    by_key: dict[str, float] = defaultdict(float)
    for trade in trades:
        by_key[str(trade.get(key, ""))] += float(trade["net_profit"])
    winners = sorted([(k, v) for k, v in by_key.items() if v > 0], key=lambda item: item[1], reverse=True)
    losers = sorted([(k, v) for k, v in by_key.items() if v < 0], key=lambda item: item[1])
    return (
        "; ".join(f"{k}:{v:.2f}" for k, v in winners[:3]),
        "; ".join(f"{k}:{v:.2f}" for k, v in losers[:3]),
    )


def group_rows(enriched: list[dict[str, object]], key_fn) -> list[dict[str, object]]:
    buckets: dict[str, list[dict[str, object]]] = defaultdict(list)
    for trade in enriched:
        buckets[str(key_fn(trade))].append(trade)
    rows = []
    for key, bucket in sorted(buckets.items()):
        stats = calc_stats(bucket)
        rows.append(
            {
                "group": key,
                "trades": stats["trades"],
                "wins": stats["wins"],
                "losses": stats["losses"],
                "win_rate": round(float(stats["win_rate"]), 2),
                "net_profit": round(float(stats["net_profit"]), 2),
                "profit_factor": pf_value(stats),
                "expected_payoff": round(float(stats["expected_payoff"]), 2),
                "avg_R": "",
                "max_balance_dd": round(float(stats["max_balance_dd"]), 2),
                "max_balance_dd_pct": round(float(stats["max_balance_dd_pct"]), 2),
            }
        )
    return rows


def write_group_csv(path: Path, all_trades: list[dict[str, object]], key_fn) -> None:
    rows = []
    buckets: dict[tuple[str, str, str, str], list[dict[str, object]]] = defaultdict(list)
    for trade in all_trades:
        buckets[
            (
                str(trade["period"]),
                str(trade["run"]),
                str(trade["scenario"]),
                str(trade["strategy_family"]),
            )
        ].append(trade)
    for (period, run, scenario, family), trades in sorted(buckets.items()):
        for row in group_rows(trades, key_fn):
            rows.append(
                {
                    "period": period,
                    "run": run,
                    "scenario": scenario,
                    "strategy_family": family,
                    **row,
                }
            )
    write_rows(path, rows)


def md_table(rows: list[dict[str, object]], columns: list[str]) -> str:
    lines = ["| " + " | ".join(columns) + " |", "| " + " | ".join(["---"] * len(columns)) + " |"]
    for row in rows:
        lines.append("| " + " | ".join(str(row.get(col, "")) for col in columns) + " |")
    return "\n".join(lines)


def main() -> None:
    comparison_rows: list[dict[str, object]] = []
    filter_rows: list[dict[str, object]] = []
    all_enriched: list[dict[str, object]] = []

    for period in PERIODS:
        elapsed = read_elapsed(period["series"])
        for run in RUNS:
            prefix_value = resolve_prefix(period["series"], run)
            report_path = BACKTEST / f"{prefix_value}_report.html"
            if not report_path.exists():
                raise FileNotFoundError(report_path)

            trades = parse_mt5_deals(report_path)
            write_trades(BACKTEST / f"{prefix_value}_trades.csv", trades)
            diagnostics = diagnostics_for_run(prefix_value, run["strategy_family"])
            enriched = attach_diagnostics(trades, diagnostics)
            for trade in enriched:
                trade["period"] = period["period"]
                trade["run"] = run["run"]
                trade["scenario"] = run["scenario"]
                trade["strategy_family"] = run["strategy_family"]
                trade["entry_selection_mode"] = run["entry_selection_mode"]
            all_enriched.extend(enriched)

            stats = calc_stats(enriched)
            long_trades = [t for t in enriched if t["direction"] == "LONG"]
            short_trades = [t for t in enriched if t["direction"] == "SHORT"]
            xau_trades = [t for t in enriched if t["symbol"] == "XAUUSD"]
            fx_trades = [t for t in enriched if t["symbol"] != "XAUUSD"]
            best_symbols, worst_symbols = major_groups(enriched, "symbol")
            best_labels, worst_labels = major_groups(enriched, "label")
            comparison_rows.append(
                {
                    "period": period["period"],
                    "run": run["run"],
                    "scenario": run["scenario"],
                    "strategy_family": run["strategy_family"],
                    "entry_selection_mode": run["entry_selection_mode"],
                    "scan_interval": "5m_timer_new_execution_bar",
                    "elapsed_seconds": elapsed.get(run["run"], ""),
                    "trades": stats["trades"],
                    "wins": stats["wins"],
                    "losses": stats["losses"],
                    "win_rate": round(float(stats["win_rate"]), 2),
                    "net_profit": round(float(stats["net_profit"]), 2),
                    "profit_factor": pf_value(stats),
                    "expected_payoff": round(float(stats["expected_payoff"]), 2),
                    "avg_R": "",
                    "max_balance_dd": round(float(stats["max_balance_dd"]), 2),
                    "max_balance_dd_pct": round(float(stats["max_balance_dd_pct"]), 2),
                    "long_net": round(sum(float(t["net_profit"]) for t in long_trades), 2),
                    "short_net": round(sum(float(t["net_profit"]) for t in short_trades), 2),
                    "fx_net": round(sum(float(t["net_profit"]) for t in fx_trades), 2),
                    "xauusd_net": round(sum(float(t["net_profit"]) for t in xau_trades), 2),
                    "xauusd_trade_share_pct": round(len(xau_trades) / len(enriched) * 100.0, 2) if enriched else 0.0,
                    "best_symbol": best_symbols,
                    "worst_symbol": worst_symbols,
                    "best_label": best_labels,
                    "worst_label": worst_labels,
                }
            )

            if run["strategy_family"] == "nested_nwave":
                summary = read_nested_summary(BACKTEST / f"{prefix_value}_nested_nwave_summary.csv")
            else:
                summary = read_thirdwave_summary(BACKTEST / f"{prefix_value}_thirdwave_summary.csv")
            filter_rows.append(
                {
                    "period": period["period"],
                    "run": run["run"],
                    "scenario": run["scenario"],
                    "strategy_family": run["strategy_family"],
                    **summary,
                }
            )

    write_rows(BACKTEST / f"{OUT_PREFIX}_comparison.csv", comparison_rows)
    write_union_rows(BACKTEST / f"{OUT_PREFIX}_filter_summary.csv", filter_rows)
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_symbol.csv", all_enriched, lambda t: t["symbol"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_direction.csv", all_enriched, lambda t: t["direction"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_session.csv", all_enriched, lambda t: t.get("session", "unknown"))
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_month.csv", all_enriched, lambda t: t["open_time"].strftime("%Y-%m"))
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_label.csv", all_enriched, lambda t: t.get("label", "unknown"))
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_fib_zone.csv", all_enriched, lambda t: t.get("fib_zone", "unknown"))
    write_group_csv(
        BACKTEST / f"{OUT_PREFIX}_fx_vs_xauusd.csv",
        all_enriched,
        lambda t: "XAUUSD" if t["symbol"] == "XAUUSD" else "FX",
    )

    metrics = {
        "comparison_rows": comparison_rows,
        "filter_rows": filter_rows,
        "runs": {},
    }
    for row in comparison_rows:
        key = f"{row['period']}|{row['run']}"
        metrics["runs"][key] = row
    with (BACKTEST / f"{OUT_PREFIX}_metrics.json").open("w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=2)

    nested_rows = [row for row in comparison_rows if row["strategy_family"] == "nested_nwave"]
    baseline_rows = [row for row in comparison_rows if row["strategy_family"] == "thirdwave_current"]
    gate_pass = False
    gate_details = []
    for run_id in ("C", "D"):
        rows = [row for row in nested_rows if row["run"] == run_id]
        period_passes = 0
        severe_fails = 0
        for row in rows:
            period_rows = [base for base in baseline_rows if base["period"] == row["period"]]
            if not period_rows:
                continue
            baseline = period_rows[0]
            row_pf = float(row["profit_factor"] or 0)
            baseline_pf = float(baseline["profit_factor"] or 0)
            row_expected = float(row["expected_payoff"] or 0)
            baseline_expected = float(baseline["expected_payoff"] or 0)
            trade_count_ok = int(row["trades"]) >= max(5, int(float(baseline["trades"])) * 0.30)
            quality_ok = row_pf > baseline_pf or row_expected > baseline_expected
            concentration_ok = float(row["xauusd_trade_share_pct"]) < 80.0
            fx_ok = float(row["fx_net"]) >= float(baseline["fx_net"]) * 0.75
            if trade_count_ok and quality_ok and concentration_ok and fx_ok:
                period_passes += 1
            if row_pf < 0.80 or row_expected < -20.0:
                severe_fails += 1
        gate_details.append(f"{run_id}: period_passes={period_passes}/4 severe_fails={severe_fails}")
        if period_passes >= 3 and severe_fails == 0:
            gate_pass = True

    gate_reason = (
        "Nested short-period gate passed by multi-period consistency."
        if gate_pass
        else "Nested short-period gate failed: performance was period-specific and broke badly in at least one validation window."
    )

    summary_lines = [
        "# Nested N-Wave Neckline Break Short-Period Validation",
        "",
        "## Scope",
        "",
        "- Added `RESEARCH_STRATEGY_NESTED_NWAVE_NECKLINE_BREAK` as a separate research mode.",
        "- Existing score scanner, Phase2, ThirdWave, v2, v3, and v4 branches were left intact.",
        "- Nested branch uses H4/H1/M15 via presets, fixed `InpRewardR=2.0`, no optimization.",
        "- Short-period windows only: 2025-02, 2025-08, 2025-10, 2026-Q1.",
        "",
        "## Comparison",
        "",
        md_table(
            comparison_rows,
            [
                "period",
                "scenario",
                "trades",
                "profit_factor",
                "expected_payoff",
                "net_profit",
                "max_balance_dd_pct",
                "fx_net",
                "xauusd_net",
                "long_net",
                "short_net",
                "best_label",
                "worst_label",
            ],
        ),
        "",
        "## Short-Period Gate",
        "",
        f"- gate_pass: `{str(gate_pass).lower()}`",
        f"- reason: {gate_reason}",
        f"- details: {'; '.join(gate_details)}",
        "",
        "Annual BT was not run unless this gate passed.",
        "",
        "## Artifacts",
        "",
        f"- Comparison: `reports/backtest/{OUT_PREFIX}_comparison.csv`",
        f"- By symbol: `reports/backtest/{OUT_PREFIX}_by_symbol.csv`",
        f"- By direction: `reports/backtest/{OUT_PREFIX}_by_direction.csv`",
        f"- By label: `reports/backtest/{OUT_PREFIX}_by_label.csv`",
        f"- By fib zone: `reports/backtest/{OUT_PREFIX}_by_fib_zone.csv`",
        f"- FX vs XAUUSD: `reports/backtest/{OUT_PREFIX}_fx_vs_xauusd.csv`",
        "- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_compile.log`",
    ]
    (BACKTEST / f"{OUT_PREFIX}_short_period_summary.md").write_text("\n".join(summary_lines) + "\n", encoding="utf-8")

    devlog = BACKTEST.parents[1] / "docs" / "devlog" / "2026-06-07-nested-nwave-neckline-break.md"
    devlog_lines = [
        "# 2026-06-07 - Nested N-Wave Neckline Break",
        "",
        "## Summary",
        "",
        "- Added a separate `RESEARCH_STRATEGY_NESTED_NWAVE_NECKLINE_BREAK` branch.",
        "- Implemented H4 impulse/pullback zone, H1 counter-trend N-wave, and M15 neckline break detection.",
        "- Kept existing ThirdWave and score scanner modes intact.",
        "- Ran short-period validation only; annual validation is gated by short-period evidence.",
        "",
        "## Evidence",
        "",
        f"- Short summary: `reports/backtest/{OUT_PREFIX}_short_period_summary.md`",
        f"- Comparison: `reports/backtest/{OUT_PREFIX}_comparison.csv`",
        "- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_compile.log`",
    ]
    devlog.write_text("\n".join(devlog_lines) + "\n", encoding="utf-8")

    print(json.dumps(comparison_rows, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
