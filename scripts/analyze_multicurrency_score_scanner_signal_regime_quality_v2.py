#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import math
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any

from analyze_multicurrency_score_scanner_2025 import BACKTEST, calc_stats, parse_mt5_deals, write_rows
from analyze_multicurrency_score_scanner_lower_tf_sl_feasibility import (
    ANNUAL_RUN_IDS,
    ANNUAL_SERIES,
    OUT_BASE,
    RUNS,
    as_float,
    as_int,
    compute_result_r,
    match_log_row,
    pf_value,
    point_for_symbol,
    read_csv_rows,
    run_prefix,
    session_for_hour,
)


OUT_PREFIX = f"{OUT_BASE}_signal_regime_quality_v2"
TARGET_RUN_IDS = {"A", "C", "D", "G"}
INITIAL_BALANCE = 10000.0


def bucket_trend_age(value: Any) -> str:
    age = as_int(value, -1)
    if age < 0:
        return "unknown"
    if age <= 5:
        return "00-05"
    if age <= 10:
        return "06-10"
    if age <= 20:
        return "11-20"
    return "21+"


def bucket_adx_proxy(value: Any) -> str:
    strength = as_float(value, math.nan)
    if math.isnan(strength):
        return "unknown"
    if strength < 0.35:
        return "weak_<0.35"
    if strength < 0.55:
        return "medium_0.35-0.55"
    if strength < 0.75:
        return "strong_0.55-0.75"
    return "very_strong_0.75+"


def bucket_atr_percentile(value: Any) -> str:
    pct = as_float(value, math.nan)
    if math.isnan(pct):
        return "unknown"
    if pct < 20:
        return "p00-20"
    if pct < 50:
        return "p20-50"
    if pct < 80:
        return "p50-80"
    return "p80-100"


def bucket_pullback_depth(value: Any) -> str:
    depth = as_float(value, math.nan)
    if math.isnan(depth):
        return "unknown"
    if depth < 20:
        return "shallow_<20"
    if depth < 38.2:
        return "normal_20-38"
    if depth < 61.8:
        return "deep_38-62"
    if depth < 100:
        return "very_deep_62-100"
    return "broken_100+"


def bucket_sl_atr(value: Any) -> str:
    sl_atr = as_float(value, math.nan)
    if math.isnan(sl_atr):
        return "unknown"
    if sl_atr < 1.5:
        return "tight_<1.5"
    if sl_atr < 2.5:
        return "normal_1.5-2.5"
    if sl_atr < 3.5:
        return "wide_2.5-3.5"
    return "very_wide_3.5+"


def bucket_entry_distance(value: Any) -> str:
    distance = as_float(value, math.nan)
    if math.isnan(distance):
        return "unknown"
    if distance < 0.75:
        return "near_<0.75"
    if distance < 1.5:
        return "mid_0.75-1.5"
    if distance < 3.0:
        return "far_1.5-3.0"
    return "very_far_3.0+"


def bucket_spread_atr(value: Any) -> str:
    spread = as_float(value, math.nan)
    if math.isnan(spread):
        return "unknown"
    if spread < 0.05:
        return "low_<0.05"
    if spread < 0.10:
        return "normal_0.05-0.10"
    if spread < 0.20:
        return "high_0.10-0.20"
    return "blocked_0.20+"


def parse_time(value: str) -> datetime | None:
    value = (value or "").strip()
    if not value:
        return None
    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")


def read_elapsed(series_name: str, run_id: str) -> float:
    path = BACKTEST / f"{OUT_BASE}_{series_name}_elapsed.csv"
    if not path.exists():
        return 0.0
    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            if row.get("run") == run_id:
                return as_float(row.get("elapsed_seconds"))
    return 0.0


def csv_bytes(prefix: str) -> int:
    return sum(path.stat().st_size for path in BACKTEST.glob(f"{prefix}*.csv") if path.exists())


def percentile_rank(values: list[float], value: float) -> float:
    if not values:
        return math.nan
    below_or_equal = sum(1 for item in values if item <= value)
    return below_or_equal / len(values) * 100.0


def collect_atr_samples(prefix: str) -> dict[str, list[float]]:
    rows = read_csv_rows(BACKTEST / f"{prefix}_thirdwave_wave_audit.csv")
    samples: dict[str, list[float]] = defaultdict(list)
    for row in rows:
        atr = as_float(row.get("higher_atr"), math.nan)
        if not math.isnan(atr) and atr > 0:
            samples[row.get("symbol", "")].append(atr)
    return samples


def load_target_trades() -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    all_trades: list[dict[str, object]] = []
    candidates: list[dict[str, object]] = []
    run_by_id = {run["run"]: run for run in RUNS if run["run"] in TARGET_RUN_IDS}

    for series in ANNUAL_SERIES:
        for run_id in sorted(TARGET_RUN_IDS):
            if run_id not in ANNUAL_RUN_IDS:
                continue
            run = run_by_id[run_id]
            prefix = run_prefix(series["series_name"], run)
            report_path = BACKTEST / f"{prefix}_report.html"
            if not report_path.exists():
                continue

            trades = parse_mt5_deals(report_path)
            audit_rows = read_csv_rows(BACKTEST / f"{prefix}_thirdwave_wave_audit.csv")
            trade_diag_rows = read_csv_rows(BACKTEST / f"{prefix}_thirdwave_trade_diagnostics.csv")
            atr_samples = collect_atr_samples(prefix)

            for candidate in audit_rows:
                event = candidate.get("event", "")
                if event not in {"final_entry_candidate", "execution_block_candidate", "order_sent", "order_failed", "order_blocked"}:
                    continue
                atr = as_float(candidate.get("higher_atr"), math.nan)
                atr_pct = percentile_rank(atr_samples.get(candidate.get("symbol", ""), []), atr) if not math.isnan(atr) else math.nan
                candidates.append(
                    {
                        "period": series["period"],
                        "variant": run["variant"],
                        "event": event,
                        "symbol": candidate.get("symbol", ""),
                        "direction": candidate.get("direction", ""),
                        "regime": candidate.get("regime", "unknown"),
                        "session": candidate.get("session", ""),
                        "reversal_signal_type": candidate.get("reversal_signal_type", "unknown"),
                        "wave_audit_label": candidate.get("wave_audit_label", "unknown"),
                        "structure_stage_fail_reason": candidate.get("structure_stage_fail_reason", ""),
                        "execution_block_reason": candidate.get("execution_block_reason", ""),
                        "trend_age_bucket": bucket_trend_age(candidate.get("higher_trend_age_bars")),
                        "atr_percentile_bucket": bucket_atr_percentile(atr_pct),
                        "pullback_depth_bucket": bucket_pullback_depth(candidate.get("pullback_depth_pct")),
                        "sl_width_atr_bucket": bucket_sl_atr(candidate.get("sl_atr")),
                        "entry_distance_bucket": bucket_entry_distance(candidate.get("distance_from_pullback_extreme_to_entry_atr")),
                        "spread_atr_bucket": bucket_spread_atr(candidate.get("spread_atr")),
                    }
                )

            used_audit: set[int] = set()
            used_trade_diag: set[int] = set()
            for trade_index, trade in enumerate(trades, start=1):
                audit = match_log_row(trade, audit_rows, used_audit, "order_sent")
                trade_diag = match_log_row(trade, trade_diag_rows, used_trade_diag, "order_sent")
                open_time: datetime = trade["open_time"]
                symbol = str(trade["symbol"])
                atr = as_float(audit.get("higher_atr"), math.nan)
                atr_pct = percentile_rank(atr_samples.get(symbol, []), atr) if not math.isnan(atr) else math.nan
                direction_sign = 1.0 if trade["direction"] == "LONG" else -1.0
                entry_price = as_float(audit.get("entry_price"), float(trade["open_price"]))
                impulse_end = as_float(audit.get("impulse_end_price"), entry_price)
                higher_atr = as_float(audit.get("higher_atr"), 0.0)
                mfe_room_atr = ((impulse_end - entry_price) * direction_sign / higher_atr) if higher_atr > 0 else 0.0
                risk_r = as_float(audit.get("risk_r"))
                point = point_for_symbol(symbol)
                result_r = round(compute_result_r(trade, audit, float(run["reward_r"])), 4)
                row = dict(trade)
                row.update(
                    {
                        "period": series["period"],
                        "run": run["run"],
                        "variant": run["variant"],
                        "scenario": run["scenario"],
                        "strategy_mode": run["strategy_mode"],
                        "signal_mode": run["signal_mode"],
                        "sl_mode": run["sl_mode"],
                        "reward_r": run["reward_r"],
                        "trade_index": trade_index,
                        "month": open_time.strftime("%Y-%m"),
                        "day_of_week": open_time.strftime("%a"),
                        "hour": f"{open_time.hour:02d}",
                        "session": audit.get("session") or session_for_hour(open_time.hour),
                        "fx_vs_xauusd": "XAUUSD" if symbol == "XAUUSD" else "FX",
                        "regime": audit.get("regime") or "unmatched",
                        "regime_reason": trade_diag.get("regime_reason", ""),
                        "trend_direction": str(audit.get("regime") or "").replace("REGIME_", ""),
                        "higher_structure_state": audit.get("higher_structure_state", ""),
                        "higher_trend_age_bars": as_int(audit.get("higher_trend_age_bars"), -1),
                        "trend_age_bucket": bucket_trend_age(audit.get("higher_trend_age_bars")),
                        "higher_ema_slope": as_float(audit.get("higher_ema_slope")),
                        "higher_atr": higher_atr,
                        "atr_percentile": round(atr_pct, 2) if not math.isnan(atr_pct) else "",
                        "atr_percentile_bucket": bucket_atr_percentile(atr_pct),
                        "trend_strength": as_float(trade_diag.get("trend_strength"), math.nan),
                        "adx_bucket": bucket_adx_proxy(trade_diag.get("trend_strength")),
                        "volatility_state": trade_diag.get("volatility_state", ""),
                        "pullback_depth_pct": as_float(audit.get("pullback_depth_pct"), math.nan),
                        "pullback_depth_atr": as_float(audit.get("pullback_depth_atr"), math.nan),
                        "pullback_depth_bucket": bucket_pullback_depth(audit.get("pullback_depth_pct")),
                        "pullback_bars": as_int(audit.get("pullback_bars"), -1),
                        "pullback_broke_origin": audit.get("pullback_broke_origin", ""),
                        "distance_from_pullback_extreme_to_entry_atr": as_float(audit.get("distance_from_pullback_extreme_to_entry_atr"), math.nan),
                        "entry_distance_bucket": bucket_entry_distance(audit.get("distance_from_pullback_extreme_to_entry_atr")),
                        "mfe_room_to_impulse_extreme_atr": round(mfe_room_atr, 3),
                        "lower_reversal_quality": audit.get("lower_reversal_quality", ""),
                        "lower_reversal_quality_score": as_float(audit.get("lower_reversal_quality_score"), math.nan),
                        "bars_since_reversal_signal": as_int(audit.get("bars_since_reversal_signal"), -1),
                        "bars_since_pullback_extreme": as_int(audit.get("bars_since_pullback_extreme"), -1),
                        "distance_from_reversal_signal_to_entry_atr": as_float(audit.get("distance_from_reversal_signal_to_entry_atr"), math.nan),
                        "impulse_consumed_pct": as_float(audit.get("impulse_consumed_pct"), math.nan),
                        "pre_entry_momentum_score": as_float(audit.get("pre_entry_momentum_score"), math.nan),
                        "reversal_strength_score": as_float(audit.get("reversal_strength_score"), math.nan),
                        "reversal_signal_type": audit.get("reversal_signal_type") or "unmatched",
                        "wave_audit_label": audit.get("wave_audit_label") or "unmatched",
                        "sl_atr": as_float(audit.get("sl_atr"), math.nan),
                        "sl_width_atr_bucket": bucket_sl_atr(audit.get("sl_atr")),
                        "risk_r": risk_r,
                        "rr": as_float(audit.get("rr"), float(run["reward_r"])),
                        "tp_atr": as_float(audit.get("rr"), float(run["reward_r"])) * as_float(audit.get("sl_atr"), 0.0),
                        "spread_atr": as_float(audit.get("spread_atr"), math.nan),
                        "spread_atr_bucket": bucket_spread_atr(audit.get("spread_atr")),
                        "entry_price": entry_price,
                        "sl": as_float(audit.get("sl")),
                        "tp": as_float(audit.get("tp")),
                        "result_R": result_r,
                        "volume": as_float(trade_diag.get("volume"), float(trade.get("volume", 0.0))),
                        "sl_points": round(risk_r / point, 1) if point > 0 and risk_r > 0 else 0.0,
                        "tp_points": round(risk_r / point * as_float(audit.get("rr"), float(run["reward_r"])), 1) if point > 0 and risk_r > 0 else 0.0,
                        "risk_amount": round(abs(float(trade["net_profit"]) / result_r), 2) if abs(result_r) > 0.05 else 0.0,
                        "structure_stage_fail_reason": audit.get("structure_stage_fail_reason", ""),
                        "execution_block_reason": audit.get("execution_block_reason", ""),
                        "csv_bytes": csv_bytes(prefix),
                        "elapsed_seconds": read_elapsed(series["series_name"], run["run"]),
                    }
                )
                all_trades.append(row)

    all_trades.sort(key=lambda item: (str(item["period"]), str(item["variant"]), item["open_time"]))
    return all_trades, candidates


def stats_from_rows(rows: list[dict[str, object]]) -> dict[str, object]:
    synthetic = []
    for row in sorted(rows, key=lambda item: item["open_time"]):
        synthetic.append(
            {
                "net_profit": float(row.get("net_profit", 0.0)),
                "open_time": row["open_time"],
                "close_time": row["close_time"],
            }
        )
    return calc_stats(synthetic)


def max_consecutive_losses(rows: list[dict[str, object]]) -> tuple[int, float]:
    max_count = 0
    max_amount = 0.0
    count = 0
    amount = 0.0
    for row in sorted(rows, key=lambda item: item["close_time"]):
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


def aggregate(rows: list[dict[str, object]], group_fields: list[str]) -> list[dict[str, object]]:
    buckets: dict[tuple[str, ...], list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        buckets[tuple(str(row.get(field, "")) for field in group_fields)].append(row)

    out = []
    for key, bucket in sorted(buckets.items()):
        stats = stats_from_rows(bucket)
        losses, loss_amount = max_consecutive_losses(bucket)
        avg_r = sum(float(row.get("result_R", 0.0)) for row in bucket) / len(bucket) if bucket else 0.0
        fx = [row for row in bucket if row.get("fx_vs_xauusd") == "FX"]
        xau = [row for row in bucket if row.get("fx_vs_xauusd") == "XAUUSD"]
        longs = [row for row in bucket if row.get("direction") == "LONG"]
        shorts = [row for row in bucket if row.get("direction") == "SHORT"]
        row_out = {field: value for field, value in zip(group_fields, key)}
        row_out.update(
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
                "long_trade_share_pct": round(len(longs) / len(bucket) * 100.0, 2) if bucket else 0.0,
                "avg_sl_atr": round(sum(as_float(row.get("sl_atr")) for row in bucket) / len(bucket), 3) if bucket else 0.0,
                "avg_tp_atr": round(sum(as_float(row.get("tp_atr")) for row in bucket) / len(bucket), 3) if bucket else 0.0,
                "avg_spread_atr": round(sum(as_float(row.get("spread_atr")) for row in bucket) / len(bucket), 4) if bucket else 0.0,
                "avg_trend_strength": round(sum(as_float(row.get("trend_strength")) for row in bucket if not math.isnan(as_float(row.get("trend_strength"), math.nan))) / max(1, sum(1 for row in bucket if not math.isnan(as_float(row.get("trend_strength"), math.nan)))), 4),
                "avg_pullback_depth_pct": round(sum(as_float(row.get("pullback_depth_pct")) for row in bucket if not math.isnan(as_float(row.get("pullback_depth_pct"), math.nan))) / max(1, sum(1 for row in bucket if not math.isnan(as_float(row.get("pullback_depth_pct"), math.nan)))), 2),
                "avg_distance_from_pullback_extreme_atr": round(sum(as_float(row.get("distance_from_pullback_extreme_to_entry_atr")) for row in bucket if not math.isnan(as_float(row.get("distance_from_pullback_extreme_to_entry_atr"), math.nan))) / max(1, sum(1 for row in bucket if not math.isnan(as_float(row.get("distance_from_pullback_extreme_to_entry_atr"), math.nan)))), 3),
                "avg_lot_size": round(sum(as_float(row.get("volume")) for row in bucket) / len(bucket), 3) if bucket else 0.0,
                "max_lot_size": round(max(as_float(row.get("volume")) for row in bucket), 3) if bucket else 0.0,
            }
        )
        out.append(row_out)
    return out


def summarize_candidates(candidates: list[dict[str, object]]) -> list[dict[str, object]]:
    buckets: dict[tuple[str, str, str], list[dict[str, object]]] = defaultdict(list)
    for row in candidates:
        reason = str(row.get("execution_block_reason") or row.get("structure_stage_fail_reason") or "candidate")
        buckets[(str(row.get("period")), str(row.get("variant")), reason)].append(row)
    rows = []
    for (period, variant, reason), bucket in sorted(buckets.items()):
        rows.append(
            {
                "period": period,
                "variant": variant,
                "reason": reason,
                "rows": len(bucket),
                "xauusd_rows": sum(1 for row in bucket if row.get("symbol") == "XAUUSD"),
                "fx_rows": sum(1 for row in bucket if row.get("symbol") != "XAUUSD"),
                "long_rows": sum(1 for row in bucket if row.get("direction") == "LONG"),
                "short_rows": sum(1 for row in bucket if row.get("direction") == "SHORT"),
            }
        )
    return rows


def rows_for_csv(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    out = []
    for row in rows:
        item = dict(row)
        for key in ("open_time", "close_time", "open_bar_m5", "close_bar_m5"):
            value = item.get(key)
            if isinstance(value, datetime):
                item[key] = value.strftime("%Y.%m.%d %H:%M:%S")
        out.append(item)
    return out


def main_loss_reason(rows: list[dict[str, object]]) -> str:
    losers = [row for row in rows if float(row.get("net_profit", 0.0)) < 0]
    if not losers:
        return "none"
    dimensions = ["symbol", "direction", "session", "month", "reversal_signal_type", "wave_audit_label", "sl_width_atr_bucket"]
    best_label = "unknown"
    best_loss = 0.0
    for dimension in dimensions:
        sums: dict[str, float] = defaultdict(float)
        for row in losers:
            sums[str(row.get(dimension, ""))] += float(row.get("net_profit", 0.0))
        key, value = min(sums.items(), key=lambda item: item[1])
        if value < best_loss:
            best_loss = value
            best_label = f"{dimension}:{key} ({round(value, 2)})"
    return best_label


def master_comparison(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    base = aggregate(rows, ["period", "variant"])
    combined = aggregate(rows, ["variant"])
    for row in combined:
        row["period"] = "ALL_ANNUAL_WINDOWS"
    out = base + combined
    for row in out:
        bucket = [
            item
            for item in rows
            if str(item.get("variant")) == str(row.get("variant"))
            and (row.get("period") == "ALL_ANNUAL_WINDOWS" or str(item.get("period")) == str(row.get("period")))
        ]
        row["main_loss_reason"] = main_loss_reason(bucket)
    return out


def variant_period(rows: list[dict[str, object]], period: str, variant: str) -> list[dict[str, object]]:
    return [row for row in rows if row.get("period") == period and row.get("variant") == variant]


def aggregate_diff(rows: list[dict[str, object]], period: str, variant: str, baseline: str, dimension: str) -> list[dict[str, object]]:
    var = {row[dimension]: row for row in aggregate(variant_period(rows, period, variant), [dimension])}
    base = {row[dimension]: row for row in aggregate(variant_period(rows, period, baseline), [dimension])}
    out = []
    for key in sorted(set(var) | set(base)):
        v = var.get(key, {})
        b = base.get(key, {})
        out.append(
            {
                "period": period,
                "dimension": dimension,
                "group": key,
                "baseline_net": b.get("net_profit", 0.0),
                "variant_net": v.get("net_profit", 0.0),
                "net_delta": round(as_float(v.get("net_profit")) - as_float(b.get("net_profit")), 2),
                "baseline_trades": b.get("trades", 0),
                "variant_trades": v.get("trades", 0),
                "baseline_pf": b.get("profit_factor", ""),
                "variant_pf": v.get("profit_factor", ""),
            }
        )
    return sorted(out, key=lambda item: as_float(item["net_delta"]))


def write_markdown_reports(rows: list[dict[str, object]], master: list[dict[str, object]], candidate_summary: list[dict[str, object]]) -> None:
    target = "v4_micro_or_candle_lower_tf_sl_1_2R"
    baseline = "current_thirdwave_current_sl_1_5R"
    summary_path = BACKTEST / f"{OUT_PREFIX}_summary.md"

    master_key = {(row["period"], row["variant"]): row for row in master}
    c2024 = master_key.get(("2024", target), {})
    c2025 = master_key.get(("2025", target), {})
    c2026 = master_key.get(("2026YTD", target), {})
    b2024 = master_key.get(("2024", baseline), {})
    combined = master_key.get(("ALL_ANNUAL_WINDOWS", target), {})

    lines = [
        "# Signal / Regime Quality v2 Diagnostic",
        "",
        "## Scope",
        "",
        "- No trading logic, RewardR, SL, timeframe, symbol, or direction optimization was performed.",
        "- The analyzer reuses existing annual LowerTF SL feasibility BT artifacts for 2024, 2025, and 2026YTD.",
        "- `trend_strength` is treated as an ADX-style proxy because the current EA logs trend strength rather than raw ADX.",
        "- ATR percentile buckets are computed from the entry/candidate sample per symbol and run, not from all historical bars.",
        "",
        "## Main Comparison",
        "",
        "| period | variant | trades | PF | avg_R | net | DD% | FX net | XAUUSD net | long net | short net | main loss reason |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|",
    ]
    for period in ("2024", "2025", "2026YTD", "ALL_ANNUAL_WINDOWS"):
        for variant in (baseline, target, "v4_micro_or_candle_lower_tf_sl_1_3R", "v4_without_weak_lower_tf_sl_1_3R"):
            row = master_key.get((period, variant))
            if not row:
                continue
            lines.append(
                f"| {period} | {variant} | {row['trades']} | {row['profit_factor']} | {row['avg_R']} | "
                f"{row['net_profit']} | {row['max_drawdown_pct']} | {row['fx_net']} | {row['xauusd_net']} | "
                f"{row['long_net']} | {row['short_net']} | {row['main_loss_reason']} |"
            )

    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            f"- 2024 failure: `{target}` produced PF `{c2024.get('profit_factor')}`, net `{c2024.get('net_profit')}`, while baseline produced PF `{b2024.get('profit_factor')}`, net `{b2024.get('net_profit')}`.",
            f"- 2025 success: `{target}` improved to PF `{c2025.get('profit_factor')}`, net `{c2025.get('net_profit')}`, but FX net remained `{c2025.get('fx_net')}`.",
            f"- 2026YTD success: `{target}` produced PF `{c2026.get('profit_factor')}`, net `{c2026.get('net_profit')}`, and FX net `{c2026.get('fx_net')}`.",
            f"- Combined annual result stayed flat: PF `{combined.get('profit_factor')}`, avg_R `{combined.get('avg_R')}`. This is not enough for promotion.",
            "",
            "## Decision",
            "",
            "- LowerTF SL remains a parked research branch, not a promotion candidate.",
            "- The 2024 break is not explained by a single broad switch such as XAUUSD only or direction only; the branch changes the loss profile by year.",
            "- The next useful filter candidate must be tested as a fixed regime-quality diagnostic, not as RewardR/SL tuning.",
        ]
    )
    summary_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    failure_lines = [
        "# 2024 Failure Breakdown",
        "",
        f"Target branch: `{target}`",
        "",
        "## Worst Deltas vs Baseline",
        "",
    ]
    for dimension in ("symbol", "direction", "session", "month", "reversal_signal_type", "wave_audit_label", "sl_width_atr_bucket", "trend_age_bucket", "atr_percentile_bucket", "adx_bucket", "pullback_depth_bucket"):
        diffs = aggregate_diff(rows, "2024", target, baseline, dimension)[:8]
        failure_lines.extend([f"### {dimension}", "", "| group | baseline net | target net | delta | baseline trades | target trades |", "|---|---:|---:|---:|---:|---:|"])
        for item in diffs:
            failure_lines.append(
                f"| {item['group']} | {item['baseline_net']} | {item['variant_net']} | {item['net_delta']} | {item['baseline_trades']} | {item['variant_trades']} |"
            )
        failure_lines.append("")
    failure_lines.extend(
        [
            "## Diagnosis",
            "",
            "- The LowerTF SL branch reduced stop distance and increased trade count, but 2024 did not pay for the added entries.",
            "- XAUUSD flipped from a baseline gain to a loss in 2024, so the branch is not merely adding FX noise.",
            "- Short-side deterioration is visible, but filtering direction alone would violate the common-branch objective and would not explain all year-to-year variation.",
        ]
    )
    (BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_2024_failure_breakdown.md").write_text("\n".join(failure_lines) + "\n", encoding="utf-8")

    success_lines = [
        "# 2025 / 2026 Success Breakdown",
        "",
        f"Target branch: `{target}`",
        "",
        "## Best Deltas vs Baseline",
        "",
    ]
    for period in ("2025", "2026YTD"):
        success_lines.extend([f"## {period}", ""])
        for dimension in ("symbol", "direction", "session", "month", "reversal_signal_type", "wave_audit_label", "sl_width_atr_bucket", "trend_age_bucket", "atr_percentile_bucket", "adx_bucket", "pullback_depth_bucket"):
            diffs = list(reversed(aggregate_diff(rows, period, target, baseline, dimension)[-8:]))
            success_lines.extend([f"### {dimension}", "", "| group | baseline net | target net | delta | baseline trades | target trades |", "|---|---:|---:|---:|---:|---:|"])
            for item in diffs:
                success_lines.append(
                    f"| {item['group']} | {item['baseline_net']} | {item['variant_net']} | {item['net_delta']} | {item['baseline_trades']} | {item['variant_trades']} |"
                )
            success_lines.append("")
    success_lines.extend(
        [
            "## Diagnosis",
            "",
            "- 2025 improvement is mostly a better long/XAUUSD profile, while FX remains weak.",
            "- 2026YTD improvement is materially different: FX and short-side results improve, so the same branch is regime-sensitive rather than universally better.",
        ]
    )
    (BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_2025_2026_success_breakdown.md").write_text("\n".join(success_lines) + "\n", encoding="utf-8")

    candidates_lines = [
        "# Next Filter Candidates",
        "",
        "## Candidate 1: Regime Quality Gate",
        "",
        "- Target: avoid years/segments where LowerTF SL increases entries without compensating expectancy.",
        "- Evidence: 2024 fails despite short-period success; 2025 and 2026YTD improve in different symbol/direction profiles.",
        "- Risk: high. A broad regime label can overfit if derived from only three annual windows.",
        "- Minimal next test: one fixed gate using trend age + trend strength + ATR percentile buckets, no RewardR/SL changes.",
        "",
        "## Candidate 2: Signal-Specific Risk Gate",
        "",
        "- Target: keep micro/candle entries only when SL ATR and entry distance buckets are in historically stable zones.",
        "- Evidence: LowerTF SL changes trade count and stop geometry; weak years may be stop-width/noise dominated.",
        "- Risk: medium-high. Needs yearly validation and FX/XAU split.",
        "",
        "## Candidate 3: 2024 Rejection Classifier",
        "",
        "- Target: identify whether 2024 failure is mostly trend-age, volatility, session, or symbol-direction exposure.",
        "- Evidence: annual PF ties baseline, so a filter must explain 2024 specifically without removing 2025/2026 winners.",
        "- Risk: medium. This should stay diagnostic until it survives 2024/2025/2026YTD.",
        "",
        "## Recommendation",
        "",
        "Do not tune RewardR or SL again. The next task should be a fixed Regime Quality Gate diagnostic based on this report. Stop if it improves only XAUUSD, only one direction, or fewer than two of 2024/2025/2026YTD.",
    ]
    (BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_next_filter_candidates.md").write_text("\n".join(candidates_lines) + "\n", encoding="utf-8")


def main() -> None:
    rows, candidates = load_target_trades()
    write_rows(BACKTEST / f"{OUT_PREFIX}_trade_quality.csv", rows_for_csv(rows))
    write_rows(BACKTEST / f"{OUT_PREFIX}_candidate_summary.csv", summarize_candidates(candidates))

    master = master_comparison(rows)
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_master_comparison.csv", master)
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_by_period.csv", aggregate(rows, ["period", "variant"]))
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_by_symbol.csv", aggregate(rows, ["period", "variant", "symbol"]))
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_by_direction.csv", aggregate(rows, ["period", "variant", "direction"]))
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_by_session.csv", aggregate(rows, ["period", "variant", "session"]))
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_by_month.csv", aggregate(rows, ["period", "variant", "month"]))
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_by_regime.csv", aggregate(rows, ["period", "variant", "regime"]))
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_by_trend_age.csv", aggregate(rows, ["period", "variant", "trend_age_bucket"]))
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_by_atr_percentile.csv", aggregate(rows, ["period", "variant", "atr_percentile_bucket"]))
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_by_adx.csv", aggregate(rows, ["period", "variant", "adx_bucket"]))
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_by_pullback_depth.csv", aggregate(rows, ["period", "variant", "pullback_depth_bucket"]))
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_by_sl_width_atr.csv", aggregate(rows, ["period", "variant", "sl_width_atr_bucket"]))
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_by_reversal_signal.csv", aggregate(rows, ["period", "variant", "reversal_signal_type"]))
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_fx_vs_xauusd.csv", aggregate(rows, ["period", "variant", "fx_vs_xauusd"]))
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_by_wave_label.csv", aggregate(rows, ["period", "variant", "wave_audit_label"]))
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_by_spread_atr.csv", aggregate(rows, ["period", "variant", "spread_atr_bucket"]))
    write_rows(BACKTEST / "ExpectedValue_MultiCurrency_ScoreScanner_regime_quality_by_entry_distance.csv", aggregate(rows, ["period", "variant", "entry_distance_bucket"]))

    write_markdown_reports(rows, master, summarize_candidates(candidates))
    metrics = {
        "rows": len(rows),
        "candidates": len(candidates),
        "master": master,
        "candidate_summary_top": summarize_candidates(candidates)[:20],
    }
    (BACKTEST / f"{OUT_PREFIX}_metrics.json").write_text(json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"rows": len(rows), "candidates": len(candidates)}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
