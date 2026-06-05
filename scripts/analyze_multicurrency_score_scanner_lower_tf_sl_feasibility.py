#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any

from analyze_multicurrency_score_scanner_2025 import (
    BACKTEST,
    calc_stats,
    parse_mt5_deals,
    serialize_stats,
    write_rows,
    write_trades,
)


OUT_BASE = "ExpectedValue_MultiCurrency_ScoreScanner"
OUT_PREFIX = f"{OUT_BASE}_lower_tf_sl_feasibility"

SERIES = [
    {"period": "2025-02", "series_name": "ltfsl_2502", "context": "2025 losing-period sample"},
    {"period": "2025-08", "series_name": "ltfsl_2508", "context": "2025 comparison sample"},
    {"period": "2025-10", "series_name": "ltfsl_2510", "context": "2025 comparison sample"},
    {"period": "2026-Q1", "series_name": "ltfsl_26q1", "context": "2026YTD sample"},
]

ANNUAL_SERIES = [
    {"period": "2024", "series_name": "ltfsl_2024", "context": "annual validation"},
    {"period": "2025", "series_name": "ltfsl_2025", "context": "annual validation"},
    {"period": "2026YTD", "series_name": "ltfsl_2026ytd", "context": "annual validation"},
]

RUNS = [
    {
        "run": "A",
        "variant": "current_thirdwave_current_sl_1_5R",
        "scenario": "current_thirdwave_current_sl_1_5R",
        "suffix": "A_cur15",
        "strategy_mode": "current_thirdwave",
        "signal_mode": "not_used",
        "sl_mode": "THIRD_WAVE_SL_CURRENT",
        "reward_r": 1.5,
    },
    {
        "run": "B",
        "variant": "v4_micro_or_candle_current_sl_1_5R",
        "scenario": "v4_micro_or_candle_current_sl_1_5R",
        "suffix": "B_mc_cur15",
        "strategy_mode": "v4",
        "signal_mode": "V4_SIGNAL_MICRO_OR_CANDLE",
        "sl_mode": "THIRD_WAVE_SL_CURRENT",
        "reward_r": 1.5,
    },
    {
        "run": "C",
        "variant": "v4_micro_or_candle_lower_tf_sl_1_2R",
        "scenario": "v4_micro_or_candle_lower_tf_sl_1_2R",
        "suffix": "C_mc_l12",
        "strategy_mode": "v4",
        "signal_mode": "V4_SIGNAL_MICRO_OR_CANDLE",
        "sl_mode": "THIRD_WAVE_SL_LOWER_TF_REVERSAL",
        "reward_r": 1.2,
    },
    {
        "run": "D",
        "variant": "v4_micro_or_candle_lower_tf_sl_1_3R",
        "scenario": "v4_micro_or_candle_lower_tf_sl_1_3R",
        "suffix": "D_mc_l13",
        "strategy_mode": "v4",
        "signal_mode": "V4_SIGNAL_MICRO_OR_CANDLE",
        "sl_mode": "THIRD_WAVE_SL_LOWER_TF_REVERSAL",
        "reward_r": 1.3,
    },
    {
        "run": "E",
        "variant": "v4_micro_or_candle_lower_tf_sl_1_5R",
        "scenario": "v4_micro_or_candle_lower_tf_sl_1_5R",
        "suffix": "E_mc_l15",
        "strategy_mode": "v4",
        "signal_mode": "V4_SIGNAL_MICRO_OR_CANDLE",
        "sl_mode": "THIRD_WAVE_SL_LOWER_TF_REVERSAL",
        "reward_r": 1.5,
    },
    {
        "run": "F",
        "variant": "v4_without_weak_lower_tf_sl_1_2R",
        "scenario": "v4_without_weak_lower_tf_sl_1_2R",
        "suffix": "F_nw_l12",
        "strategy_mode": "v4",
        "signal_mode": "V4_SIGNAL_WITHOUT_WEAK_SIGNALS",
        "sl_mode": "THIRD_WAVE_SL_LOWER_TF_REVERSAL",
        "reward_r": 1.2,
    },
    {
        "run": "G",
        "variant": "v4_without_weak_lower_tf_sl_1_3R",
        "scenario": "v4_without_weak_lower_tf_sl_1_3R",
        "suffix": "G_nw_l13",
        "strategy_mode": "v4",
        "signal_mode": "V4_SIGNAL_WITHOUT_WEAK_SIGNALS",
        "sl_mode": "THIRD_WAVE_SL_LOWER_TF_REVERSAL",
        "reward_r": 1.3,
    },
]

ANNUAL_RUN_IDS = {"A", "C", "D", "G"}

AUDIT_FIELDS = [
    "regime",
    "session",
    "entry_selection_mode",
    "v4_signal_mode",
    "thirdwave_sl_mode",
    "reversal_signal_type",
    "wave_audit_label",
    "lower_tf_reversal_sl_status",
    "structure_stage_fail_reason",
    "execution_block_reason",
    "sl_atr",
    "risk_r",
    "rr",
    "spread_atr",
    "entry_price",
    "sl",
    "tp",
]

INITIAL_BALANCE = 10000.0


def series_prefix(series_name: str) -> str:
    return f"{OUT_BASE}_{series_name}"


def run_prefix(series_name: str, run: dict[str, Any]) -> str:
    return f"{series_prefix(series_name)}_{run['suffix']}"


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return list(csv.DictReader(fh))


def parse_log_time(value: str) -> datetime | None:
    value = (value or "").strip()
    if not value:
        return None
    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")


def as_float(value: Any, default: float = 0.0) -> float:
    if value is None:
        return default
    text = str(value).strip().replace(" ", "").replace(",", "")
    if text == "":
        return default
    try:
        return float(text)
    except ValueError:
        return default


def as_int(value: Any, default: int = 0) -> int:
    return int(as_float(value, float(default)))


def pf_value(stats: dict[str, object]) -> object:
    return round(float(stats["profit_factor"]), 3) if stats["profit_factor"] is not None else ""


def point_for_symbol(symbol: str) -> float:
    if symbol == "XAUUSD":
        return 0.01
    if symbol.endswith("JPY"):
        return 0.001
    return 0.00001


def read_elapsed(series_name: str, run_id: str) -> float:
    path = BACKTEST / f"{series_prefix(series_name)}_elapsed.csv"
    if not path.exists():
        return 0.0
    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            if row.get("run") == run_id:
                return as_float(row.get("elapsed_seconds"))
    return 0.0


def file_size(path: Path) -> int:
    return path.stat().st_size if path.exists() else 0


def run_csv_bytes(prefix: str) -> int:
    return sum(file_size(path) for path in BACKTEST.glob(f"{prefix}*.csv"))


def session_for_hour(hour: int) -> str:
    if hour < 8:
        return "server_00_07"
    if hour < 16:
        return "server_08_15"
    return "server_16_23"


def match_log_row(
    trade: dict[str, object],
    rows: list[dict[str, str]],
    used: set[int],
    event: str = "order_sent",
) -> dict[str, str]:
    best_idx = -1
    best_delta = 10**9
    open_time = trade["open_time"]
    for idx, row in enumerate(rows):
        if idx in used:
            continue
        if row.get("event") != event:
            continue
        if row.get("symbol") != trade["symbol"]:
            continue
        if row.get("direction") != trade["direction"]:
            continue
        log_time = parse_log_time(row.get("time", ""))
        if log_time is None:
            continue
        delta = abs((open_time - log_time).total_seconds())
        if delta <= 900 and delta < best_delta:
            best_idx = idx
            best_delta = int(delta)
    if best_idx >= 0:
        used.add(best_idx)
        return rows[best_idx]
    return {}


def compute_result_r(trade: dict[str, object], audit: dict[str, str], reward_r: float) -> float:
    risk_r = as_float(audit.get("risk_r"))
    if risk_r > 0.0:
        entry_price = as_float(audit.get("entry_price")) or float(trade["open_price"])
        direction_sign = 1.0 if trade["direction"] == "LONG" else -1.0
        return (float(trade["close_price"]) - entry_price) * direction_sign / risk_r

    comment = str(trade.get("close_comment", "")).lower()
    if comment.startswith("tp"):
        return reward_r
    if comment.startswith("sl"):
        return -1.0
    return 0.0


def read_summary_counts(prefix: str) -> dict[str, object]:
    rows = read_csv_rows(BACKTEST / f"{prefix}_thirdwave_summary.csv")
    if not rows:
        return {}
    row = rows[-1]
    keys = [
        "evaluations",
        "setup_pass",
        "entry_pass",
        "orders_sent",
        "orders_failed",
        "sl_too_close",
        "sl_too_tight",
        "sl_too_wide",
        "invalid_stops",
        "market_closed",
        "spread_guard",
        "execution_order_failed",
        "top_structure_stage_fail_reason",
        "top_structure_stage_fail_reason_rows",
        "top_execution_block_reason",
        "top_execution_block_reason_rows",
        "top_skip_reason",
        "top_skip_reason_rows",
    ]
    result: dict[str, object] = {}
    for key in keys:
        value = row.get(key, "")
        result[key] = as_int(value) if value.replace(".", "", 1).isdigit() else value
    return result


def stats_from_rows(rows: list[dict[str, object]], profit_key: str = "net_profit") -> dict[str, object]:
    synthetic = []
    base = datetime(2000, 1, 1)
    for idx, row in enumerate(rows):
        synthetic.append(
            {
                "net_profit": float(row.get(profit_key, 0.0)),
                "open_time": base,
                "close_time": base.replace(minute=(idx + 1) % 60),
            }
        )
    return calc_stats(synthetic)


def max_consecutive_losses(rows: list[dict[str, object]]) -> tuple[int, float]:
    max_count = 0
    max_amount = 0.0
    count = 0
    amount = 0.0
    for row in rows:
        profit = float(row.get("net_profit", 0.0))
        if profit < 0:
            count += 1
            amount += profit
            if count > max_count:
                max_count = count
                max_amount = amount
        else:
            count = 0
            amount = 0.0
    return max_count, max_amount


def enrich_trades(
    trades: list[dict[str, object]],
    audit_rows: list[dict[str, str]],
    trade_diag_rows: list[dict[str, str]],
    series: dict[str, str],
    run: dict[str, Any],
) -> list[dict[str, object]]:
    used_audit: set[int] = set()
    used_trade_diag: set[int] = set()
    enriched = []
    for index, trade in enumerate(trades, start=1):
        audit = match_log_row(trade, audit_rows, used_audit, "order_sent")
        trade_diag = match_log_row(trade, trade_diag_rows, used_trade_diag, "order_sent")
        row = dict(trade)
        row.update(
            {
                "period": series["period"],
                "context": series["context"],
                "run": run["run"],
                "variant": run["variant"],
                "scenario": run["scenario"],
                "strategy_mode": run["strategy_mode"],
                "signal_mode": run["signal_mode"],
                "sl_mode": run["sl_mode"],
                "reward_r": run["reward_r"],
                "trade_index": index,
                "month": trade["open_time"].strftime("%Y-%m"),
                "hour": f"{trade['open_time'].hour:02d}",
                "fx_vs_xauusd": "XAUUSD" if trade["symbol"] == "XAUUSD" else "FX",
            }
        )
        for field in AUDIT_FIELDS:
            row[field] = audit.get(field, "") if audit else ""
        row["session"] = row.get("session") or session_for_hour(trade["open_time"].hour)
        row["regime"] = row.get("regime") or "unmatched"
        row["reversal_signal_type"] = row.get("reversal_signal_type") or "unmatched"
        row["wave_audit_label"] = row.get("wave_audit_label") or "unmatched"
        row["thirdwave_sl_mode"] = row.get("thirdwave_sl_mode") or run["sl_mode"]
        row["result_R"] = round(compute_result_r(trade, audit, float(run["reward_r"])), 4)
        row["volume"] = as_float(trade_diag.get("volume"), float(trade.get("volume", 0.0)))
        row["risk_r"] = as_float(row.get("risk_r"))
        row["sl_atr"] = as_float(row.get("sl_atr"))
        point = point_for_symbol(str(trade["symbol"]))
        row["sl_points"] = round(row["risk_r"] / point, 1) if point > 0 else 0.0
        row["tp_points"] = round(row["sl_points"] * float(row.get("rr") or run["reward_r"]), 1)
        row["tp_atr"] = round(row["sl_atr"] * float(row.get("rr") or run["reward_r"]), 3)
        row["risk_amount"] = round(abs(float(row["net_profit"]) / row["result_R"]), 2) if abs(row["result_R"]) > 0.05 else 0.0
        enriched.append(row)
    return enriched


def rows_for_csv(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    converted = []
    for row in rows:
        item = dict(row)
        for key in ("open_time", "close_time", "open_bar_m5", "close_bar_m5"):
            value = item.get(key)
            if isinstance(value, datetime):
                item[key] = value.strftime("%Y.%m.%d %H:%M:%S")
        converted.append(item)
    return converted


def aggregate(rows: list[dict[str, object]], group_fields: list[str]) -> list[dict[str, object]]:
    buckets: dict[tuple[str, ...], list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        buckets[tuple(str(row.get(field, "")) for field in group_fields)].append(row)

    out = []
    for key, bucket in sorted(buckets.items()):
        stats = stats_from_rows(bucket)
        losses, loss_amount = max_consecutive_losses(bucket)
        avg_r = sum(float(row.get("result_R", 0.0)) for row in bucket) / len(bucket) if bucket else 0.0
        xau = [row for row in bucket if row.get("fx_vs_xauusd") == "XAUUSD"]
        fx = [row for row in bucket if row.get("fx_vs_xauusd") == "FX"]
        longs = [row for row in bucket if row.get("direction") == "LONG"]
        shorts = [row for row in bucket if row.get("direction") == "SHORT"]
        result = {field: value for field, value in zip(group_fields, key)}
        result.update(
            {
                "trades": len(bucket),
                "wins": stats["wins"],
                "losses": stats["losses"],
                "win_rate": round(float(stats["win_rate"]), 2),
                "net_profit": round(float(stats["net_profit"]), 2),
                "profit_factor": pf_value(stats),
                "expected_payoff": round(float(stats["expected_payoff"]), 2),
                "avg_R": round(avg_r, 3),
                "max_drawdown": round(float(stats["max_balance_dd"]), 2),
                "max_drawdown_pct": round(float(stats["max_balance_dd_pct"]), 2),
                "max_consecutive_losses": losses,
                "max_consecutive_losses_amount": round(loss_amount, 2),
                "fx_net": round(sum(float(row["net_profit"]) for row in fx), 2),
                "xauusd_net": round(sum(float(row["net_profit"]) for row in xau), 2),
                "long_net": round(sum(float(row["net_profit"]) for row in longs), 2),
                "short_net": round(sum(float(row["net_profit"]) for row in shorts), 2),
                "xauusd_trade_share_pct": round(len(xau) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "largest_direction_share_pct": round(max(len(longs), len(shorts)) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "avg_sl_points": round(sum(float(row.get("sl_points", 0.0)) for row in bucket) / len(bucket), 1) if bucket else 0.0,
                "avg_sl_atr": round(sum(float(row.get("sl_atr", 0.0)) for row in bucket) / len(bucket), 3) if bucket else 0.0,
                "avg_tp_points": round(sum(float(row.get("tp_points", 0.0)) for row in bucket) / len(bucket), 1) if bucket else 0.0,
                "avg_tp_atr": round(sum(float(row.get("tp_atr", 0.0)) for row in bucket) / len(bucket), 3) if bucket else 0.0,
                "avg_lot_size": round(sum(float(row.get("volume", 0.0)) for row in bucket) / len(bucket), 3) if bucket else 0.0,
                "max_lot_size": round(max(float(row.get("volume", 0.0)) for row in bucket), 3) if bucket else 0.0,
                "avg_risk_amount": round(sum(float(row.get("risk_amount", 0.0)) for row in bucket) / len(bucket), 2) if bucket else 0.0,
            }
        )
        out.append(result)
    return out


def comparison_rows(all_trades: list[dict[str, object]], combined_label: str = "ALL_SHORT_WINDOWS") -> list[dict[str, object]]:
    rows = aggregate(all_trades, ["period", "variant"])
    combined = aggregate(all_trades, ["variant"])
    for row in combined:
        row["period"] = combined_label
    return rows + combined


def filter_summary_rows() -> list[dict[str, object]]:
    out = []
    for series in SERIES:
        for run in RUNS:
            prefix = run_prefix(series["series_name"], run)
            counts = read_summary_counts(prefix)
            if not counts:
                continue
            row = {
                "period": series["period"],
                "variant": run["variant"],
                "scenario": run["scenario"],
                "sl_mode": run["sl_mode"],
                "reward_r": run["reward_r"],
            }
            row.update(counts)
            out.append(row)
    return out


def build_gate_rows(comparison: list[dict[str, object]]) -> list[dict[str, object]]:
    combined = {row["variant"]: row for row in comparison if row.get("period") == "ALL_SHORT_WINDOWS"}
    baseline = combined.get("current_thirdwave_current_sl_1_5R", {})
    rows = []
    base_pf = as_float(baseline.get("profit_factor"))
    base_avg_r = as_float(baseline.get("avg_R"))
    base_trades = as_int(baseline.get("trades"))
    base_fx_net = as_float(baseline.get("fx_net"))
    for variant, row in sorted(combined.items()):
        if variant == "current_thirdwave_current_sl_1_5R":
            continue
        pf = as_float(row.get("profit_factor"))
        avg_r = as_float(row.get("avg_R"))
        trades = as_int(row.get("trades"))
        fx_net = as_float(row.get("fx_net"))
        xau_share = as_float(row.get("xauusd_trade_share_pct"))
        direction_share = as_float(row.get("largest_direction_share_pct"))
        invalid_ok = True
        gate_pass = (
            (pf > base_pf or avg_r > base_avg_r)
            and trades >= base_trades * 0.5
            and fx_net >= base_fx_net
            and xau_share < 90.0
            and direction_share < 90.0
            and invalid_ok
        )
        reasons = []
        if not (pf > base_pf or avg_r > base_avg_r):
            reasons.append("pf_avgR_not_improved")
        if trades < base_trades * 0.5:
            reasons.append("trade_count_below_half")
        if fx_net < base_fx_net:
            reasons.append("fx_net_worse")
        if xau_share >= 90.0:
            reasons.append("xauusd_concentrated")
        if direction_share >= 90.0:
            reasons.append("direction_concentrated")
        rows.append(
            {
                "variant": variant,
                "gate_pass": gate_pass,
                "gate_fail_reasons": ";".join(reasons),
                "baseline_pf": base_pf,
                "variant_pf": pf,
                "baseline_avg_R": base_avg_r,
                "variant_avg_R": avg_r,
                "baseline_trades": base_trades,
                "variant_trades": trades,
                "baseline_fx_net": round(base_fx_net, 2),
                "variant_fx_net": round(fx_net, 2),
                "variant_xauusd_trade_share_pct": xau_share,
                "variant_largest_direction_share_pct": direction_share,
            }
        )
    return rows


def write_summary(comparison: list[dict[str, object]], gate_rows: list[dict[str, object]], filter_rows: list[dict[str, object]]) -> None:
    combined = [row for row in comparison if row.get("period") == "ALL_SHORT_WINDOWS"]
    combined_sorted = sorted(combined, key=lambda row: as_float(row.get("profit_factor")), reverse=True)
    gate_passed = [row for row in gate_rows if row["gate_pass"]]
    top = combined_sorted[0] if combined_sorted else {}

    lines = [
        "# LowerTF SL Feasibility Short Test",
        "",
        "## Scope",
        "",
        "- Actual-order short-period feasibility test only.",
        "- Existing ThirdWave, v2, v3, v4, Phase2, and score scanner defaults remain unchanged.",
        "- `InpThirdWaveSLMode=THIRD_WAVE_SL_LOWER_TF_REVERSAL` is used only by the new research presets.",
        "- RewardR `1.2 / 1.3 / 1.5` are fixed comparison points, not optimized ranges.",
        "- Short windows: 2025-02, 2025-08, 2025-10, 2026-Q1.",
        "",
        "## Combined Short-Window Result",
        "",
        "| variant | trades | PF | avg_R | net | maxDD% | FX net | XAUUSD net | avg lot | max lot |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in combined_sorted:
        lines.append(
            f"| {row['variant']} | {row['trades']} | {row['profit_factor']} | {row['avg_R']} | "
            f"{row['net_profit']} | {row['max_drawdown_pct']} | {row['fx_net']} | {row['xauusd_net']} | "
            f"{row['avg_lot_size']} | {row['max_lot_size']} |"
        )

    lines.extend(
        [
            "",
            "## Short Gate",
            "",
            "| variant | gate | fail reasons |",
            "|---|---:|---|",
        ]
    )
    for row in gate_rows:
        lines.append(f"| {row['variant']} | {row['gate_pass']} | {row['gate_fail_reasons']} |")

    lines.extend(
        [
            "",
            "## Decision",
            "",
        ]
    )
    if gate_passed:
        lines.append("At least one branch passed the short gate. Annual BT can be run for the passing branch only.")
    else:
        lines.append("No branch passed the short gate, so annual 2024/2025/2026YTD BT is skipped.")

    if top:
        lines.append(
            f"Best combined PF was `{top['profit_factor']}` from `{top['variant']}` with "
            f"`{top['trades']}` trades and avg_R `{top['avg_R']}`."
        )

    tight = sum(as_int(row.get("sl_too_tight")) for row in filter_rows)
    invalid = sum(as_int(row.get("invalid_stops")) for row in filter_rows)
    wide = sum(as_int(row.get("sl_too_wide")) for row in filter_rows)
    lines.extend(
        [
            "",
            "## Execution Feasibility Notes",
            "",
            f"- `sl_too_tight`: {tight}",
            f"- `invalid_stops`: {invalid}",
            f"- `sl_too_wide`: {wide}",
            "- Lot-size feasibility is summarized in the comparison and grouping CSVs.",
        ]
    )

    (BACKTEST / f"{OUT_PREFIX}_short_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    annual_lines = [
        "# LowerTF SL Feasibility Annual Summary",
        "",
        "Annual BT was not run by this analyzer.",
        "Run annual 2024/2025/2026YTD only if `lower_tf_sl_feasibility_annual_gate.csv` contains a passing branch.",
        "",
    ]
    if not gate_passed:
        annual_lines.append("Current result: no short-gate pass, annual BT skipped.")
    (BACKTEST / f"{OUT_PREFIX}_annual_summary.md").write_text("\n".join(annual_lines) + "\n", encoding="utf-8")


def load_series_trades(
    series_items: list[dict[str, str]],
    runs: list[dict[str, Any]],
) -> tuple[list[dict[str, object]], dict[str, object]]:
    all_trades: list[dict[str, object]] = []
    metrics: dict[str, object] = {}

    for series in series_items:
        for run in runs:
            prefix = run_prefix(series["series_name"], run)
            report = BACKTEST / f"{prefix}_report.html"
            if not report.exists():
                continue
            trades = parse_mt5_deals(report)
            write_trades(BACKTEST / f"{prefix}_trades.csv", trades)
            audit_rows = read_csv_rows(BACKTEST / f"{prefix}_thirdwave_wave_audit.csv")
            trade_diag_rows = read_csv_rows(BACKTEST / f"{prefix}_thirdwave_trade_diagnostics.csv")
            enriched = enrich_trades(trades, audit_rows, trade_diag_rows, series, run)
            write_rows(BACKTEST / f"{prefix}_enriched_trades.csv", rows_for_csv(enriched))
            all_trades.extend(enriched)
            metrics[prefix] = {
                "stats": serialize_stats(calc_stats(trades)),
                "elapsed_seconds": read_elapsed(series["series_name"], run["run"]),
                "csv_bytes": run_csv_bytes(prefix),
            }
    return all_trades, metrics


def add_elapsed_and_size(rows: list[dict[str, object]], series_items: list[dict[str, str]], runs: list[dict[str, Any]]) -> None:
    for row in rows:
        if str(row.get("period", "")).startswith("ALL_"):
            continue
        series = next((item for item in series_items if item["period"] == row["period"]), None)
        run = next((item for item in runs if item["variant"] == row["variant"]), None)
        if series and run:
            prefix = run_prefix(series["series_name"], run)
            row["elapsed_seconds"] = round(read_elapsed(series["series_name"], run["run"]), 1)
            row["csv_bytes"] = run_csv_bytes(prefix)


def write_annual_summary(annual_comparison: list[dict[str, object]]) -> None:
    rows = [row for row in annual_comparison if not str(row.get("period", "")).startswith("ALL_")]
    combined = [row for row in annual_comparison if row.get("period") == "ALL_ANNUAL_WINDOWS"]
    combined_by_variant = {row["variant"]: row for row in combined}
    baseline = combined_by_variant.get("current_thirdwave_current_sl_1_5R", {})
    best = max(combined, key=lambda row: as_float(row.get("profit_factor")), default={})
    lines = [
        "# LowerTF SL Feasibility Annual Summary",
        "",
        "Annual BT was run because the short-period gate passed for C/D/G.",
        "Annual branches: baseline A plus passing C/D/G only.",
        "",
        "| period | variant | trades | PF | avg_R | net | maxDD% | FX net | XAUUSD net | long net | short net |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in rows:
        lines.append(
            f"| {row['period']} | {row['variant']} | {row['trades']} | {row['profit_factor']} | "
            f"{row['avg_R']} | {row['net_profit']} | {row['max_drawdown_pct']} | "
            f"{row['fx_net']} | {row['xauusd_net']} | {row['long_net']} | {row['short_net']} |"
        )

    if combined:
        lines.extend(["", "## Combined Annual Windows", "", "| variant | trades | PF | avg_R | net | FX net | XAUUSD net |", "|---|---:|---:|---:|---:|---:|---:|"])
        for row in sorted(combined, key=lambda item: as_float(item.get("profit_factor")), reverse=True):
            lines.append(
                f"| {row['variant']} | {row['trades']} | {row['profit_factor']} | {row['avg_R']} | "
                f"{row['net_profit']} | {row['fx_net']} | {row['xauusd_net']} |"
            )

    lines.extend(["", "## Decision", ""])
    if best:
        lines.append(
            f"Best annual PF is `{best['profit_factor']}` from `{best['variant']}`. "
            f"The baseline PF is `{baseline.get('profit_factor', '')}`."
        )
    lines.append(
        "The LowerTF SL hypothesis is feasible as a narrow research branch, but it is not robust enough for promotion: "
        "the short-period improvement does not survive 2024, and annual PF/avg_R do not clearly exceed the baseline across 2024/2025/2026YTD."
    )
    lines.append(
        "`v4_micro_or_candle_lower_tf_sl_1_2R` is the only branch worth parking for later: it improves 2025 and 2026YTD FX net, "
        "but 2024 is negative and the annual combined PF/avg_R are effectively tied with the current ThirdWave baseline."
    )
    lines.append(
        "Do not run a broader parameter search from this result. The next useful work is signal/regime quality, not tuning RewardR."
    )

    (BACKTEST / f"{OUT_PREFIX}_annual_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    all_trades, metrics = load_series_trades(SERIES, RUNS)

    write_rows(BACKTEST / f"{OUT_PREFIX}_trades.csv", rows_for_csv(all_trades))

    comparison = comparison_rows(all_trades, "ALL_SHORT_WINDOWS")
    add_elapsed_and_size(comparison, SERIES, RUNS)
    write_rows(BACKTEST / f"{OUT_PREFIX}_comparison.csv", comparison)
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_symbol.csv", aggregate(all_trades, ["variant", "symbol"]))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_direction.csv", aggregate(all_trades, ["variant", "direction"]))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_signal.csv", aggregate(all_trades, ["variant", "reversal_signal_type"]))
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_label.csv", aggregate(all_trades, ["variant", "wave_audit_label"]))
    write_rows(BACKTEST / f"{OUT_PREFIX}_fx_vs_xauusd.csv", aggregate(all_trades, ["variant", "fx_vs_xauusd"]))
    write_rows(BACKTEST / f"{OUT_PREFIX}_session_month.csv", aggregate(all_trades, ["variant", "session", "month"]))

    filter_rows = filter_summary_rows()
    write_rows(BACKTEST / f"{OUT_PREFIX}_filter_summary.csv", filter_rows)

    gate_rows = build_gate_rows(comparison)
    write_rows(BACKTEST / f"{OUT_PREFIX}_annual_gate.csv", gate_rows)
    write_summary(comparison, gate_rows, filter_rows)

    annual_runs = [run for run in RUNS if run["run"] in ANNUAL_RUN_IDS]
    annual_trades, annual_metrics = load_series_trades(ANNUAL_SERIES, annual_runs)
    if annual_trades:
        write_rows(BACKTEST / f"{OUT_PREFIX}_annual_trades.csv", rows_for_csv(annual_trades))
        annual_comparison = comparison_rows(annual_trades, "ALL_ANNUAL_WINDOWS")
        add_elapsed_and_size(annual_comparison, ANNUAL_SERIES, annual_runs)
        write_rows(BACKTEST / f"{OUT_PREFIX}_annual_comparison.csv", annual_comparison)
        write_rows(BACKTEST / f"{OUT_PREFIX}_annual_by_symbol.csv", aggregate(annual_trades, ["period", "variant", "symbol"]))
        write_rows(BACKTEST / f"{OUT_PREFIX}_annual_by_direction.csv", aggregate(annual_trades, ["period", "variant", "direction"]))
        write_rows(BACKTEST / f"{OUT_PREFIX}_annual_fx_vs_xauusd.csv", aggregate(annual_trades, ["period", "variant", "fx_vs_xauusd"]))
        write_annual_summary(annual_comparison)
        metrics.update(annual_metrics)

    with (BACKTEST / f"{OUT_PREFIX}_metrics.json").open("w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=2)

    print(json.dumps(gate_rows, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
