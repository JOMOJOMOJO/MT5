#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

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


OUT_PREFIX = "ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_diag"

SERIES = [
    {
        "year": "2025",
        "period": "2025",
        "series_name": "2025_thirdwave_diag",
        "label": "2025 in-sample diagnostics",
    },
    {
        "year": "2024",
        "period": "2024",
        "series_name": "2024_thirdwave_diag",
        "label": "2024 OOS",
    },
    {
        "year": "2026YTD",
        "period": "2026YTD",
        "series_name": "2026ytd_thirdwave_diag",
        "label": "2026YTD OOS",
    },
]

RUNS = [
    {"run": "A", "scenario": "ThirdWave_BOTH", "suffix": "A_both"},
    {"run": "B", "scenario": "ThirdWave_LONG_ONLY", "suffix": "B_long_only"},
    {"run": "C", "scenario": "ThirdWave_SHORT_ONLY", "suffix": "C_short_only"},
]

STRUCTURE_REASON_KEYS = [
    "no_higher_tf_trend",
    "trend_broken",
    "no_mid_pullback",
    "pullback_too_shallow",
    "pullback_too_deep",
    "no_lower_reversal",
    "sl_too_close",
    "sl_too_wide",
    "rr_too_low",
    "data_unavailable",
    "atr_unavailable",
    "research_excluded",
    "unknown",
]

EXECUTION_REASON_KEYS = [
    "execution_spread_guard",
    "execution_trading_disabled",
    "execution_no_entry_signal",
    "execution_position_limit",
    "execution_risk_stop",
    "execution_risk_limit",
    "execution_invalid",
    "execution_order_failed",
    "execution_unknown",
]


def series_prefix(series_name: str) -> str:
    return f"ExpectedValue_MultiCurrency_ScoreScanner_{series_name}"


def run_prefix(series_name: str, run: dict[str, str]) -> str:
    return f"{series_prefix(series_name)}_{run['suffix']}"


def as_float(value: Any, default: float = 0.0) -> float:
    if value is None:
        return default
    text = str(value).strip()
    if text == "":
        return default
    return float(text)


def as_int(value: Any, default: int = 0) -> int:
    if value is None:
        return default
    text = str(value).strip()
    if text == "":
        return default
    return int(float(text))


def pf_value(stats: dict[str, object]) -> object:
    return round(float(stats["profit_factor"]), 3) if stats["profit_factor"] is not None else ""


def read_elapsed(series_name: str) -> dict[str, float]:
    path = BACKTEST / f"{series_prefix(series_name)}_elapsed.csv"
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


def read_summary(path: Path) -> dict[str, object]:
    latest: dict[str, str] | None = None
    for row in read_csv_rows(path):
        if row.get("evaluations"):
            latest = row
    if latest is None:
        return {}

    result: dict[str, object] = {}
    string_keys = {
        "time",
        "strategy_name",
        "top_structure_stage_fail_reason",
        "top_execution_block_reason",
        "top_skip_reason",
    }
    for key, value in latest.items():
        if key in string_keys:
            result[key] = value
        else:
            result[key] = as_int(value)
    return result


def major_symbols(trades: list[dict[str, object]]) -> tuple[str, str]:
    by_symbol: dict[str, float] = defaultdict(float)
    for trade in trades:
        by_symbol[str(trade["symbol"])] += float(trade["net_profit"])
    winners = sorted(((k, v) for k, v in by_symbol.items() if v > 0), key=lambda item: item[1], reverse=True)
    losers = sorted(((k, v) for k, v in by_symbol.items() if v < 0), key=lambda item: item[1])
    return (
        "; ".join(f"{symbol}:{pnl:.2f}" for symbol, pnl in winners[:3]),
        "; ".join(f"{symbol}:{pnl:.2f}" for symbol, pnl in losers[:3]),
    )


def session_for_hour(hour: int) -> str:
    if 0 <= hour < 8:
        return "server_00_07"
    if 8 <= hour < 16:
        return "server_08_15"
    return "server_16_23"


def band(value: float, cuts: list[float], labels: list[str]) -> str:
    for cut, label in zip(cuts, labels):
        if value < cut:
            return label
    return labels[-1]


def spread_atr_band(value: float) -> str:
    return band(value, [0.05, 0.10, 0.15, 0.20], ["<0.05", "0.05-0.10", "0.10-0.15", "0.15-0.20", "0.20+"])


def sl_atr_band(value: float) -> str:
    return band(value, [0.75, 1.00, 1.25, 1.50, 2.00], ["<0.75", "0.75-1.00", "1.00-1.25", "1.25-1.50", "1.50-2.00", "2.00+"])


def rr_band(value: float) -> str:
    if value <= 0:
        return "unknown"
    return f"{value:.2f}R"


def enrich_trades_with_order_logs(
    trades: list[dict[str, object]],
    trade_logs: list[dict[str, str]],
    context: dict[str, str],
) -> list[dict[str, object]]:
    sent_logs = [row for row in trade_logs if row.get("event") == "order_sent"]
    enriched: list[dict[str, object]] = []
    for idx, trade in enumerate(trades):
        row = dict(trade)
        diag = sent_logs[idx] if idx < len(sent_logs) else {}
        risk_r = as_float(diag.get("risk_r"))
        atr_value = as_float(diag.get("atr_value"))
        spread_atr = as_float(diag.get("spread_atr"))
        rr = as_float(diag.get("rr"))
        row.update(context)
        row["trade_index"] = idx + 1
        row["spread_atr"] = spread_atr
        row["spread_atr_band"] = spread_atr_band(spread_atr)
        row["atr_value"] = atr_value
        row["risk_r"] = risk_r
        row["sl_atr"] = (risk_r / atr_value) if atr_value > 0 else 0.0
        row["sl_atr_band"] = sl_atr_band(float(row["sl_atr"]))
        row["rr"] = rr
        row["rr_band"] = rr_band(rr)
        row["session"] = session_for_hour(row["open_time"].hour)
        row["hour"] = f"{row['open_time'].hour:02d}"
        enriched.append(row)
    return enriched


def write_group_csv(path: Path, trades: list[dict[str, object]], key_fn) -> None:
    buckets: dict[tuple[str, str, str], list[dict[str, object]]] = defaultdict(list)
    for trade in trades:
        key = (str(trade["period"]), str(trade["run"]), str(key_fn(trade)))
        buckets[key].append(trade)
    rows: list[dict[str, object]] = []
    for (period, run, group), bucket in sorted(buckets.items()):
        scenario = str(bucket[0]["scenario"])
        for row in group_stats(bucket, lambda _t, group=group: group):
            rows.append({"period": period, "run": run, "scenario": scenario, **row})
    write_rows(path, rows)


def build_stage_rows(summaries: dict[tuple[str, str], dict[str, object]]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for series in SERIES:
        for run in RUNS:
            summary = summaries.get((series["period"], run["run"]), {})
            if not summary:
                continue
            for direction, prefix in (("ALL", ""), ("LONG", "long_"), ("SHORT", "short_")):
                evaluations = as_int(summary.get("evaluations" if direction == "ALL" else f"{prefix}evaluations"))
                if direction == "LONG":
                    evaluations = as_int(summary.get("long_evaluations"))
                elif direction == "SHORT":
                    evaluations = as_int(summary.get("short_evaluations"))
                higher = as_int(summary.get(f"{prefix}higher_tf_trend_pass"))
                mid = as_int(summary.get(f"{prefix}mid_tf_pullback_pass"))
                lower = as_int(summary.get(f"{prefix}lower_tf_reversal_pass"))
                sl = as_int(summary.get(f"{prefix}structure_sl_pass"))
                rr = as_int(summary.get(f"{prefix}rr_pass"))
                spread_pass = as_int(summary.get(f"{prefix}spread_guard_pass"))
                spread_blocked = as_int(summary.get(f"{prefix}spread_guard_blocked"))
                final_entry = as_int(summary.get(f"{prefix}final_entry_pass"))
                rows.append(
                    {
                        "period": series["period"],
                        "run": run["run"],
                        "scenario": run["scenario"],
                        "direction": direction,
                        "evaluations": evaluations,
                        "higher_tf_trend_pass": higher,
                        "higher_tf_trend_fail": max(evaluations - higher, 0),
                        "mid_tf_pullback_pass": mid,
                        "mid_tf_pullback_fail_after_higher": max(higher - mid, 0),
                        "lower_tf_reversal_pass": lower,
                        "lower_tf_reversal_fail_after_mid": max(mid - lower, 0),
                        "structure_sl_pass": sl,
                        "structure_sl_fail_after_lower": max(lower - sl, 0),
                        "rr_pass": rr,
                        "rr_fail_after_sl": max(sl - rr, 0),
                        "spread_guard_pass": spread_pass,
                        "spread_guard_blocked": spread_blocked,
                        "final_entry_pass": final_entry,
                        "final_entry_rate_pct": round(final_entry / evaluations * 100.0, 4) if evaluations else 0.0,
                    }
                )
    return rows


def build_reason_rows(
    summaries: dict[tuple[str, str], dict[str, object]],
    keys: list[str],
    reason_column: str,
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for series in SERIES:
        for run in RUNS:
            summary = summaries.get((series["period"], run["run"]), {})
            if not summary:
                continue
            for key in keys:
                value = as_int(summary.get(key))
                if value:
                    reason = key.replace("execution_", "") if reason_column == "execution_block_reason" else key
                    rows.append(
                        {
                            "period": series["period"],
                            "run": run["run"],
                            "scenario": run["scenario"],
                            reason_column: reason,
                            "rows": value,
                        }
                    )
    return rows


def build_combined_skip_rows(summaries: dict[tuple[str, str], dict[str, object]]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for row in build_reason_rows(summaries, STRUCTURE_REASON_KEYS, "structure_stage_fail_reason"):
        rows.append(
            {
                "period": row["period"],
                "run": row["run"],
                "scenario": row["scenario"],
                "skip_category": "structure_stage",
                "skip_reason": row["structure_stage_fail_reason"],
                "rows": row["rows"],
            }
        )
    for row in build_reason_rows(summaries, EXECUTION_REASON_KEYS, "execution_block_reason"):
        rows.append(
            {
                "period": row["period"],
                "run": row["run"],
                "scenario": row["scenario"],
                "skip_category": "execution_block",
                "skip_reason": row["execution_block_reason"],
                "rows": row["rows"],
            }
        )
    return rows


def build_signal_reason_rows(signal_rows: list[dict[str, str]], field: str, out_field: str) -> list[dict[str, object]]:
    counts = Counter()
    for row in signal_rows:
        reason = row.get(field, "")
        if reason:
            counts[(row["period"], row["run"], row["scenario"], row.get("direction", ""), reason)] += 1
    return [
        {
            "period": period,
            "run": run,
            "scenario": scenario,
            "direction": direction,
            out_field: reason,
            "logged_rows": count,
        }
        for (period, run, scenario, direction, reason), count in sorted(counts.items())
    ]


def md_table(rows: list[dict[str, object]], columns: list[str]) -> str:
    lines = ["| " + " | ".join(columns) + " |", "| " + " | ".join(["---"] * len(columns)) + " |"]
    for row in rows:
        lines.append("| " + " | ".join(str(row.get(col, "")) for col in columns) + " |")
    return "\n".join(lines)


def write_summary(run_rows: list[dict[str, object]], stage_rows: list[dict[str, object]]) -> None:
    short_rows = [
        {
            "period": row["period"],
            "scenario": row["scenario"],
            "trades": row["trades"],
            "net_profit": row["net_profit"],
            "profit_factor": row["profit_factor"],
            "expected_payoff": row["expected_payoff"],
            "max_balance_dd_pct": row["max_balance_dd_pct"],
            "long_net_profit": row["long_net_profit"],
            "short_net_profit": row["short_net_profit"],
            "xauusd_trade_share_pct": row["xauusd_trade_share_pct"],
            "usdjpy_short_net_profit": row["usdjpy_short_net_profit"],
            "top_structure_stage_fail_reason": row["top_structure_stage_fail_reason"],
            "top_execution_block_reason": row["top_execution_block_reason"],
        }
        for row in run_rows
    ]
    stage_2025 = [
        row
        for row in stage_rows
        if row["period"] == "2025" and row["direction"] in {"LONG", "SHORT"} and row["scenario"] != "ThirdWave_BOTH"
    ]
    lines = [
        "# ThirdWave Diagnostics Improved Summary",
        "",
        "## Scope",
        "",
        "- Diagnostic-only change for the separate DowFractal ThirdWave branch.",
        "- No optimization was performed.",
        "- `InpRewardR`, `InpMaxSpreadATR`, timeframe inputs, SL/TP logic, CTrade bridge, and existing Phase 2 score scanner logic were not changed.",
        "- Spread guard is now recorded separately from structure-stage failures.",
        "- Signal detail rows are limited to lower-reversal-or-later candidates and execution-block candidates; earlier stage failures remain available through summary counters.",
        "",
        "## Run Results",
        "",
        md_table(
            short_rows,
            [
                "period",
                "scenario",
                "trades",
                "net_profit",
                "profit_factor",
                "expected_payoff",
                "max_balance_dd_pct",
                "long_net_profit",
                "short_net_profit",
                "xauusd_trade_share_pct",
                "usdjpy_short_net_profit",
                "top_structure_stage_fail_reason",
                "top_execution_block_reason",
            ],
        ),
        "",
        "## 2025 Stage Breakdown",
        "",
        md_table(
            stage_2025,
            [
                "scenario",
                "direction",
                "evaluations",
                "higher_tf_trend_pass",
                "mid_tf_pullback_pass",
                "lower_tf_reversal_pass",
                "structure_sl_pass",
                "rr_pass",
                "spread_guard_blocked",
                "final_entry_pass",
                "final_entry_rate_pct",
            ],
        ),
        "",
        "## Artifacts",
        "",
        f"- Run comparison: `reports/backtest/{OUT_PREFIX}_run_comparison.csv`",
        f"- 2025 stage breakdown: `reports/backtest/{OUT_PREFIX}_2025_stage_breakdown.csv`",
        f"- OOS summary: `reports/backtest/{OUT_PREFIX}_oos_summary.md`",
        f"- By spread/ATR band: `reports/backtest/{OUT_PREFIX}_2025_by_spread_atr_band.csv`",
        f"- By SL/ATR band: `reports/backtest/{OUT_PREFIX}_2025_by_sl_atr_band.csv`",
        f"- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_diagnostics_compile.txt`",
    ]
    (BACKTEST / f"{OUT_PREFIX}_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_oos_summary(run_rows: list[dict[str, object]]) -> None:
    rows = [row for row in run_rows if row["period"] in {"2024", "2026YTD"}]
    lines = [
        "# ThirdWave OOS Diagnostics Summary",
        "",
        "The OOS runs reuse the same ThirdWave diagnostics settings without parameter optimization.",
        "",
        md_table(
            rows,
            [
                "period",
                "scenario",
                "trades",
                "net_profit",
                "profit_factor",
                "expected_payoff",
                "max_balance_dd_pct",
                "long_net_profit",
                "short_net_profit",
                "xauusd_net_profit",
                "usdjpy_short_net_profit",
                "major_winning_symbols",
                "major_losing_symbols",
            ],
        ),
        "",
        f"- CSV: `reports/backtest/{OUT_PREFIX}_oos_run_comparison.csv`",
    ]
    (BACKTEST / f"{OUT_PREFIX}_oos_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    write_rows(BACKTEST / f"{OUT_PREFIX}_oos_run_comparison.csv", rows)


def write_devlog(run_rows: list[dict[str, object]]) -> None:
    devlog = BACKTEST.parents[1] / "docs" / "devlog" / "2026-06-03-thirdwave-diagnostics-improved.md"
    lines = [
        "# 2026-06-03 - ThirdWave Diagnostics Improved",
        "",
        "## Summary",
        "",
        "- Split ThirdWave structure-stage failure diagnostics from final execution-block diagnostics.",
        "- Added spread/ATR, max spread/ATR, spread pass/block flags, spread points, and ATR value to ThirdWave signal/trade diagnostics.",
        "- Added stage pass counters for higher-timeframe trend, mid-timeframe pullback, lower-timeframe reversal, structure SL, RR, spread guard, and final entry, split by direction.",
        "- Kept signal diagnostics at candidate level by logging lower-reversal-or-later rows plus execution-block rows; early-stage failures are summary counters.",
        "- Ran 2025 diagnostics plus 2024 and 2026YTD OOS checks for BOTH, LONG_ONLY, and SHORT_ONLY.",
        "- Compile result: 0 errors / 0 warnings.",
        "",
        "## Evidence",
        "",
        f"- Summary: `reports/backtest/{OUT_PREFIX}_summary.md`",
        f"- OOS summary: `reports/backtest/{OUT_PREFIX}_oos_summary.md`",
        f"- Run comparison: `reports/backtest/{OUT_PREFIX}_run_comparison.csv`",
        "- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_diagnostics_compile.txt`",
    ]
    devlog.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    run_trades: dict[tuple[str, str], list[dict[str, object]]] = {}
    enriched_trades: list[dict[str, object]] = []
    summaries: dict[tuple[str, str], dict[str, object]] = {}
    all_signal_rows: list[dict[str, str]] = []
    run_rows: list[dict[str, object]] = []

    for series in SERIES:
        elapsed = read_elapsed(series["series_name"])
        for run in RUNS:
            prefix = run_prefix(series["series_name"], run)
            report_path = BACKTEST / f"{prefix}_report.html"
            if not report_path.exists():
                continue
            trades = parse_mt5_deals(report_path)
            write_trades(BACKTEST / f"{prefix}_trades.csv", trades)
            parsed_trades = read_trades(BACKTEST / f"{prefix}_trades.csv")
            context = {
                "period": series["period"],
                "year": series["year"],
                "run": run["run"],
                "scenario": run["scenario"],
                "prefix": prefix,
            }
            trade_logs = read_csv_rows(BACKTEST / f"{prefix}_thirdwave_trade_diagnostics.csv")
            enriched = enrich_trades_with_order_logs(parsed_trades, trade_logs, context)
            enriched_trades.extend(enriched)
            run_trades[(series["period"], run["run"])] = enriched

            summary = read_summary(BACKTEST / f"{prefix}_thirdwave_summary.csv")
            summaries[(series["period"], run["run"])] = summary

            for row in read_csv_rows(BACKTEST / f"{prefix}_thirdwave_signal_diagnostics.csv"):
                row.update(context)
                all_signal_rows.append(row)

            stats = calc_stats(parsed_trades)
            long_trades = [t for t in parsed_trades if t["direction"] == "LONG"]
            short_trades = [t for t in parsed_trades if t["direction"] == "SHORT"]
            xau_trades = [t for t in parsed_trades if t["symbol"] == "XAUUSD"]
            usd_short = [t for t in parsed_trades if t["symbol"] == "USDJPY" and t["direction"] == "SHORT"]
            winners, losers = major_symbols(parsed_trades)
            run_rows.append(
                {
                    "period": series["period"],
                    "year": series["year"],
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
                    "max_balance_dd": round(float(stats["max_balance_dd"]), 2),
                    "max_balance_dd_pct": round(float(stats["max_balance_dd_pct"]), 2),
                    "max_consecutive_losses": stats["max_consecutive_losses"]["count"],
                    "max_consecutive_losses_amount": round(float(stats["max_consecutive_losses"]["amount"]), 2),
                    "long_trades": len(long_trades),
                    "long_net_profit": round(sum(float(t["net_profit"]) for t in long_trades), 2),
                    "short_trades": len(short_trades),
                    "short_net_profit": round(sum(float(t["net_profit"]) for t in short_trades), 2),
                    "xauusd_trades": len(xau_trades),
                    "xauusd_trade_share_pct": round(len(xau_trades) / len(parsed_trades) * 100.0, 2) if parsed_trades else 0.0,
                    "xauusd_net_profit": round(sum(float(t["net_profit"]) for t in xau_trades), 2),
                    "usdjpy_short_trades": len(usd_short),
                    "usdjpy_short_net_profit": round(sum(float(t["net_profit"]) for t in usd_short), 2),
                    "major_winning_symbols": winners,
                    "major_losing_symbols": losers,
                    "evaluations": summary.get("evaluations", 0),
                    "higher_tf_trend_pass": summary.get("higher_tf_trend_pass", 0),
                    "mid_tf_pullback_pass": summary.get("mid_tf_pullback_pass", 0),
                    "lower_tf_reversal_pass": summary.get("lower_tf_reversal_pass", 0),
                    "structure_sl_pass": summary.get("structure_sl_pass", 0),
                    "rr_pass": summary.get("rr_pass", 0),
                    "spread_guard_blocked": summary.get("spread_guard_blocked", 0),
                    "final_entry_pass": summary.get("final_entry_pass", 0),
                    "top_structure_stage_fail_reason": summary.get("top_structure_stage_fail_reason", summary.get("top_skip_reason", "")),
                    "top_structure_stage_fail_reason_rows": summary.get("top_structure_stage_fail_reason_rows", summary.get("top_skip_reason_rows", 0)),
                    "top_execution_block_reason": summary.get("top_execution_block_reason", ""),
                    "top_execution_block_reason_rows": summary.get("top_execution_block_reason_rows", 0),
                }
            )

    stage_rows = build_stage_rows(summaries)
    combined_skip_rows = build_combined_skip_rows(summaries)
    write_rows(BACKTEST / f"{OUT_PREFIX}_run_comparison.csv", run_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_2025_stage_breakdown.csv", [row for row in stage_rows if row["period"] == "2025"])
    write_rows(BACKTEST / f"{OUT_PREFIX}_2025_by_setup_stage.csv", [row for row in stage_rows if row["period"] == "2025"])
    write_rows(BACKTEST / f"{OUT_PREFIX}_stage_breakdown.csv", stage_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_skip_reason.csv", combined_skip_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_2025_by_skip_reason.csv", [row for row in combined_skip_rows if row["period"] == "2025"])
    write_rows(BACKTEST / f"{OUT_PREFIX}_structure_stage_fail_reason_summary.csv", build_reason_rows(summaries, STRUCTURE_REASON_KEYS, "structure_stage_fail_reason"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_execution_block_reason_summary.csv", build_reason_rows(summaries, EXECUTION_REASON_KEYS, "execution_block_reason"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_logged_structure_stage_fail_reason.csv", build_signal_reason_rows(all_signal_rows, "structure_stage_fail_reason", "structure_stage_fail_reason"))
    write_rows(BACKTEST / f"{OUT_PREFIX}_logged_execution_block_reason.csv", build_signal_reason_rows(all_signal_rows, "execution_block_reason", "execution_block_reason"))

    trades_2025 = [trade for trade in enriched_trades if trade["period"] == "2025"]
    write_rows(BACKTEST / f"{OUT_PREFIX}_2025_trade_join.csv", trades_2025)
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_2025_by_symbol.csv", trades_2025, lambda t: t["symbol"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_2025_by_direction.csv", trades_2025, lambda t: t["direction"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_2025_by_symbol_direction.csv", trades_2025, lambda t: f"{t['symbol']}:{t['direction']}")
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_2025_by_month.csv", trades_2025, lambda t: t["open_time"].strftime("%Y-%m"))
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_2025_by_hour.csv", trades_2025, lambda t: t["hour"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_2025_by_session.csv", trades_2025, lambda t: t["session"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_2025_by_spread_atr_band.csv", trades_2025, lambda t: t["spread_atr_band"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_2025_by_sl_atr_band.csv", trades_2025, lambda t: t["sl_atr_band"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_2025_by_rr_band.csv", trades_2025, lambda t: t["rr_band"])

    metrics = {
        "runs": {f"{period}_{run}": serialize_stats(calc_stats(trades)) for (period, run), trades in run_trades.items()},
        "run_rows": run_rows,
        "stage_rows": stage_rows,
        "summaries": {f"{period}_{run}": summary for (period, run), summary in summaries.items()},
    }
    with (BACKTEST / f"{OUT_PREFIX}_metrics.json").open("w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=2)

    write_summary(run_rows, stage_rows)
    write_oos_summary(run_rows)
    write_devlog(run_rows)
    print(json.dumps(run_rows, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
