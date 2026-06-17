#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any

from analyze_multicurrency_score_scanner_2025 import BACKTEST, calc_stats, parse_mt5_deals, write_trades


ROOT = Path(__file__).resolve().parents[1]
OUT_BASE = "ExpectedValue_MultiCurrency_ScoreScanner"
OUT_PREFIX = f"{OUT_BASE}_nested_context_router_r12"
DEVLOG = ROOT / "docs" / "devlog" / "2026-06-15-nested-context-quality-router-r12.md"

PERIODS = [
    ("2025-02", "2025_02_nested_context_r12"),
    ("2025-08", "2025_08_nested_context_r12"),
    ("2025-10", "2025_10_nested_context_r12"),
    ("2026-Q1", "2026_q1_nested_context_r12"),
]

RUNS = [
    ("A", "A_nested_all_r12", "instant_all_r12"),
    ("B", "B_retest_all_r12", "retest_all_r12"),
    ("C", "C_breakout_router_all_r12", "breakout_router_all_r12"),
    ("D", "D_context_router_all_r12", "context_router_all_r12"),
    ("E", "E_context_router_v2_all_r12", "context_router_v2_all_r12"),
]

OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_summary.md",
    "comparison": BACKTEST / f"{OUT_PREFIX}_comparison.csv",
    "trade_rows": BACKTEST / f"{OUT_PREFIX}_trade_rows.csv",
    "by_symbol": BACKTEST / f"{OUT_PREFIX}_by_symbol.csv",
    "by_direction": BACKTEST / f"{OUT_PREFIX}_by_direction.csv",
    "fx_vs_xauusd": BACKTEST / f"{OUT_PREFIX}_fx_vs_xauusd.csv",
    "by_label": BACKTEST / f"{OUT_PREFIX}_by_label.csv",
    "by_context_quality": BACKTEST / f"{OUT_PREFIX}_by_context_quality.csv",
    "by_breakout_quality": BACKTEST / f"{OUT_PREFIX}_by_breakout_quality.csv",
    "block_summary": BACKTEST / f"{OUT_PREFIX}_block_summary.csv",
    "metrics": BACKTEST / f"{OUT_PREFIX}_metrics.json",
}


def prefix(series: str, run_name: str) -> str:
    return f"{OUT_BASE}_{series}_{run_name}"


def parse_time(value: str) -> datetime | None:
    value = (value or "").strip()
    if not value:
        return None
    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")


def as_float(value: Any, default: float = 0.0) -> float:
    try:
        text = str(value).replace("\xa0", "").replace(" ", "").replace(",", "").strip()
        return float(text) if text else default
    except Exception:
        return default


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return list(csv.DictReader(fh))


def write_rows(path: Path, rows: list[dict[str, object]]) -> None:
    fields: list[str] = []
    for row in rows:
        for key in row:
            if key not in fields:
                fields.append(key)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def read_elapsed(series: str) -> dict[str, float]:
    rows = read_csv_rows(BACKTEST / f"{OUT_BASE}_{series}_elapsed.csv")
    result: dict[str, float] = {}
    for row in rows:
        run_id = row.get("run_id", "") or row.get("run", "")
        elapsed = as_float(row.get("elapsed_seconds"))
        if run_id:
            result[run_id] = elapsed
    return result


def read_or_parse_trades(pfx: str) -> list[dict[str, object]]:
    report_path = BACKTEST / f"{pfx}_report.html"
    trades_path = BACKTEST / f"{pfx}_trades.csv"
    if not report_path.exists():
        return []
    trades = parse_mt5_deals(report_path)
    write_trades(trades_path, trades)
    return trades


def load_order_sent_rows(pfx: str) -> list[dict[str, object]]:
    rows = read_csv_rows(BACKTEST / f"{pfx}_nested_nwave_trade_diagnostics.csv")
    sent: list[dict[str, object]] = []
    for row in rows:
        if row.get("event") != "order_sent":
            continue
        parsed: dict[str, object] = dict(row)
        parsed["time_dt"] = parse_time(row.get("time", ""))
        for key in (
            "entry_price",
            "sl",
            "tp",
            "rr",
            "sl_atr",
            "tp_atr",
            "volume",
            "breakout_close_distance_from_neckline_atr",
            "breakout_body_ratio",
            "breakout_body_atr",
            "breakout_range_atr",
            "breakout_directional_wick_ratio",
            "breakout_close_position_directional",
            "context_quality_score",
        ):
            parsed[key] = as_float(row.get(key))
        sent.append(parsed)
    return sent


def match_diag(trade: dict[str, object], sent_rows: list[dict[str, object]], used: set[int]) -> dict[str, object] | None:
    best_idx = None
    best_delta = None
    open_time = trade["open_time"]
    for idx, row in enumerate(sent_rows):
        if idx in used:
            continue
        if row.get("symbol") != trade.get("symbol") or row.get("direction") != trade.get("direction"):
            continue
        row_time = row.get("time_dt")
        if not isinstance(row_time, datetime):
            continue
        delta = abs((open_time - row_time).total_seconds())
        if delta > 300:
            continue
        if best_delta is None or delta < best_delta:
            best_delta = delta
            best_idx = idx
    if best_idx is None:
        return None
    used.add(best_idx)
    return sent_rows[best_idx]


def price_result_r(trade: dict[str, object], diag: dict[str, object] | None) -> float:
    if diag is None:
        return 0.0
    entry = as_float(diag.get("entry_price"))
    sl = as_float(diag.get("sl"))
    close = as_float(trade.get("close_price"))
    if entry <= 0.0 or sl <= 0.0 or close <= 0.0:
        return 0.0
    direction = str(trade.get("direction"))
    if direction == "LONG":
        risk = entry - sl
        return (close - entry) / risk if risk > 0.0 else 0.0
    risk = sl - entry
    return (entry - close) / risk if risk > 0.0 else 0.0


def fx_bucket(symbol: object) -> str:
    return "XAUUSD" if str(symbol) == "XAUUSD" else "FX"


def period_month(period: str, open_time: datetime) -> str:
    if period == "2026-Q1":
        return open_time.strftime("%Y-%m")
    return period


def summarize_trades(rows: list[dict[str, object]]) -> dict[str, object]:
    trades = [{"net_profit": as_float(r["net_profit"]), "open_time": r["open_time"], "close_time": r["close_time"]} for r in rows]
    stats = calc_stats(trades)
    result_rs = [as_float(r.get("result_R")) for r in rows]
    return {
        "trades": stats["trades"],
        "wins": stats["wins"],
        "losses": stats["losses"],
        "win_rate": round(float(stats["win_rate"]), 2),
        "net_profit": round(float(stats["net_profit"]), 2),
        "profit_factor": round(float(stats["profit_factor"]), 3) if stats["profit_factor"] is not None else "",
        "expected_payoff": round(float(stats["expected_payoff"]), 2),
        "avg_R": round(sum(result_rs) / len(result_rs), 3) if result_rs else 0.0,
        "max_dd": round(float(stats["max_balance_dd"]), 2),
        "max_dd_pct": round(float(stats["max_balance_dd_pct"]), 2),
        "max_consecutive_losses": stats["max_consecutive_losses"]["count"],
    }


def group_rows(rows: list[dict[str, object]], keys: list[str]) -> list[dict[str, object]]:
    buckets: dict[tuple[object, ...], list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        buckets[tuple(row.get(key, "") for key in keys)].append(row)
    output: list[dict[str, object]] = []
    for key_values, bucket in sorted(buckets.items(), key=lambda item: tuple(str(v) for v in item[0])):
        record = {key: value for key, value in zip(keys, key_values)}
        record.update(summarize_trades(bucket))
        output.append(record)
    return output


def load_block_summary(period: str, series: str, run_id: str, run_name: str, scenario: str) -> list[dict[str, object]]:
    pfx = prefix(series, run_name)
    rows = read_csv_rows(BACKTEST / f"{pfx}_nested_nwave_signal_diagnostics.csv")
    counts: Counter[tuple[str, str, str, str]] = Counter()
    for row in rows:
        if row.get("event") != "blocked_candidate":
            continue
        counts[
            (
                row.get("fail_reason", "") or "none",
                row.get("label", "") or "none",
                row.get("breakout_quality_label", "") or "none",
                row.get("context_quality_label", "") or "none",
            )
        ] += 1
    return [
        {
            "period": period,
            "run": run_id,
            "scenario": scenario,
            "fail_reason": key[0],
            "label": key[1],
            "breakout_quality_label": key[2],
            "context_quality_label": key[3],
            "rows": value,
        }
        for key, value in counts.most_common()
    ]


def main() -> None:
    all_trade_rows: list[dict[str, object]] = []
    comparison: list[dict[str, object]] = []
    block_summary: list[dict[str, object]] = []

    for period, series in PERIODS:
        elapsed_by_run = read_elapsed(series)
        for run_id, run_name, scenario in RUNS:
            pfx = prefix(series, run_name)
            trades = read_or_parse_trades(pfx)
            sent_rows = load_order_sent_rows(pfx)
            used: set[int] = set()
            enriched: list[dict[str, object]] = []
            for index, trade in enumerate(trades, start=1):
                diag = match_diag(trade, sent_rows, used)
                result_r = price_result_r(trade, diag)
                row = {
                    "period": period,
                    "month": period_month(period, trade["open_time"]),
                    "run": run_id,
                    "scenario": scenario,
                    "trade_index": index,
                    "open_time": trade["open_time"],
                    "close_time": trade["close_time"],
                    "symbol": trade["symbol"],
                    "fx_vs_xauusd": fx_bucket(trade["symbol"]),
                    "direction": trade["direction"],
                    "net_profit": round(as_float(trade["net_profit"]), 2),
                    "result_R": round(result_r, 3),
                    "close_comment": trade.get("close_comment", ""),
                    "session": diag.get("session", "") if diag else "",
                    "label": diag.get("label", "unmatched") if diag else "unmatched",
                    "neckline_break_label": diag.get("neckline_break_label", "") if diag else "",
                    "breakout_quality_label": diag.get("breakout_quality_label", "unmatched") if diag else "unmatched",
                    "context_quality_label": diag.get("context_quality_label", "unmatched") if diag else "unmatched",
                    "context_quality_score": round(as_float(diag.get("context_quality_score")), 2) if diag else 0.0,
                    "context_quality_reason": diag.get("context_quality_reason", "") if diag else "",
                    "sl_atr": round(as_float(diag.get("sl_atr")), 2) if diag else 0.0,
                    "tp_atr": round(as_float(diag.get("tp_atr")), 2) if diag else 0.0,
                    "breakout_close_distance_from_neckline_atr": round(as_float(diag.get("breakout_close_distance_from_neckline_atr")), 2) if diag else 0.0,
                    "breakout_body_ratio": round(as_float(diag.get("breakout_body_ratio")), 2) if diag else 0.0,
                    "breakout_body_atr": round(as_float(diag.get("breakout_body_atr")), 2) if diag else 0.0,
                    "breakout_close_position_directional": round(as_float(diag.get("breakout_close_position_directional")), 2) if diag else 0.0,
                    "breakout_directional_wick_ratio": round(as_float(diag.get("breakout_directional_wick_ratio")), 2) if diag else 0.0,
                }
                enriched.append(row)
                all_trade_rows.append(row)
            comp = {
                "period": period,
                "run": run_id,
                "scenario": scenario,
                "elapsed_seconds": round(elapsed_by_run.get(run_id, 0.0), 1),
            }
            comp.update(summarize_trades(enriched))
            comp["fx_net"] = round(sum(as_float(r["net_profit"]) for r in enriched if r["fx_vs_xauusd"] == "FX"), 2)
            comp["xauusd_net"] = round(sum(as_float(r["net_profit"]) for r in enriched if r["fx_vs_xauusd"] == "XAUUSD"), 2)
            comp["long_net"] = round(sum(as_float(r["net_profit"]) for r in enriched if r["direction"] == "LONG"), 2)
            comp["short_net"] = round(sum(as_float(r["net_profit"]) for r in enriched if r["direction"] == "SHORT"), 2)
            comparison.append(comp)
            block_summary.extend(load_block_summary(period, series, run_id, run_name, scenario))

    write_rows(OUTPUTS["trade_rows"], all_trade_rows)
    write_rows(OUTPUTS["comparison"], comparison)
    write_rows(OUTPUTS["by_symbol"], group_rows(all_trade_rows, ["period", "scenario", "symbol"]))
    write_rows(OUTPUTS["by_direction"], group_rows(all_trade_rows, ["period", "scenario", "direction"]))
    write_rows(OUTPUTS["fx_vs_xauusd"], group_rows(all_trade_rows, ["period", "scenario", "fx_vs_xauusd"]))
    write_rows(OUTPUTS["by_label"], group_rows(all_trade_rows, ["period", "scenario", "label"]))
    write_rows(OUTPUTS["by_context_quality"], group_rows(all_trade_rows, ["period", "scenario", "context_quality_label"]))
    write_rows(OUTPUTS["by_breakout_quality"], group_rows(all_trade_rows, ["period", "scenario", "breakout_quality_label"]))
    write_rows(OUTPUTS["block_summary"], block_summary)

    totals = group_rows(all_trade_rows, ["scenario"])
    period_best = []
    for period, _series in PERIODS:
        candidates = [row for row in comparison if row["period"] == period]
        if candidates:
            best = sorted(candidates, key=lambda row: (as_float(row["avg_R"]), as_float(row["net_profit"])), reverse=True)[0]
            period_best.append(best)

    summary_lines = [
        "# Nested Context Quality Router RR 1.2 Short Test",
        "",
        "This is a bounded diagnostic cycle, not parameter optimization. All runs use H4/H1/M15 Nested N-Wave settings, all-candidates entry, and `InpRewardR=1.20`.",
        "",
        "## Aggregate By Scenario",
        "",
        "| scenario | trades | PF | avg_R | net | maxDD% | FX net | XAUUSD net |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    aggregate_fx = defaultdict(float)
    aggregate_xau = defaultdict(float)
    for row in all_trade_rows:
        if row["fx_vs_xauusd"] == "FX":
            aggregate_fx[row["scenario"]] += as_float(row["net_profit"])
        else:
            aggregate_xau[row["scenario"]] += as_float(row["net_profit"])
    for row in totals:
        summary_lines.append(
            f"| {row['scenario']} | {row['trades']} | {row['profit_factor']} | {row['avg_R']} | {row['net_profit']} | {row['max_dd_pct']} | {aggregate_fx[row['scenario']]:.2f} | {aggregate_xau[row['scenario']]:.2f} |"
        )

    summary_lines.extend([
        "",
        "## Best Scenario By Period",
        "",
        "| period | scenario | trades | PF | avg_R | net | FX net | XAUUSD net |",
        "|---|---|---:|---:|---:|---:|---:|---:|",
    ])
    for row in period_best:
        summary_lines.append(
            f"| {row['period']} | {row['scenario']} | {row['trades']} | {row['profit_factor']} | {row['avg_R']} | {row['net_profit']} | {row['fx_net']} | {row['xauusd_net']} |"
        )

    context_rows = [row for row in all_trade_rows if row["scenario"] == "context_router_all_r12"]
    summary_lines.extend([
        "",
        "## Context Router Label Breakdown",
        "",
        "| context_quality_label | trades | PF | avg_R | net |",
        "|---|---:|---:|---:|---:|",
    ])
    for row in group_rows(context_rows, ["context_quality_label"]):
        summary_lines.append(
            f"| {row['context_quality_label']} | {row['trades']} | {row['profit_factor']} | {row['avg_R']} | {row['net_profit']} |"
        )

    summary_lines.extend([
        "",
        "## Initial Judgement",
        "",
    ])
    context_total = next((row for row in totals if row["scenario"] == "context_router_all_r12"), None)
    instant_total = next((row for row in totals if row["scenario"] == "instant_all_r12"), None)
    router_total = next((row for row in totals if row["scenario"] == "breakout_router_all_r12"), None)
    if context_total and instant_total and router_total:
        if as_float(context_total["avg_R"]) > as_float(instant_total["avg_R"]) and as_float(context_total["avg_R"]) > as_float(router_total["avg_R"]):
            summary_lines.append("- Context Router improved aggregate avg_R versus both instant and breakout-router baselines.")
        else:
            summary_lines.append("- Context Router did not clearly improve aggregate avg_R versus the existing instant/router baselines.")
        if as_float(context_total["trades"]) < as_float(instant_total["trades"]) * 0.5:
            summary_lines.append("- Trade count fell by more than 50% versus instant entry, so any improvement must be treated as filter-driven until OOS supports it.")
    summary_lines.append("- Next action should be based on the losing-period/block-summary rows, not another threshold sweep.")
    summary_lines.append("")
    OUTPUTS["summary"].write_text("\n".join(summary_lines), encoding="utf-8")

    DEVLOG.write_text(
        "\n".join(
            [
                "# 2026-06-15 - Nested Context Quality Router RR 1.2 Cycle",
                "",
                "## Summary",
                "",
                "- Added independent `RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER` diagnostics branch.",
                "- Tested short windows only: 2025-02, 2025-08, 2025-10, 2026-Q1.",
                "- All comparison runs used `InpRewardR=1.20`; this was a fixed diagnostic value, not an optimization sweep.",
                "",
                "## Evidence",
                "",
                f"- Summary: `reports/backtest/{OUTPUTS['summary'].name}`",
                f"- Comparison: `reports/backtest/{OUTPUTS['comparison'].name}`",
                f"- Trade rows: `reports/backtest/{OUTPUTS['trade_rows'].name}`",
                f"- Block summary: `reports/backtest/{OUTPUTS['block_summary'].name}`",
                "",
                "## Guardrails",
                "",
                "- Existing ThirdWave, v2, v3, v4, Phase2, score scanner, CTrade bridge, spread guard, risk sizing, and SL/TP mechanics were not intentionally changed.",
            ]
        ),
        encoding="utf-8",
    )

    metrics = {"comparison": comparison, "totals": totals}
    OUTPUTS["metrics"].write_text(json.dumps(metrics, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    print(json.dumps({"comparison": comparison, "totals": totals}, ensure_ascii=False, indent=2, default=str))


if __name__ == "__main__":
    main()
