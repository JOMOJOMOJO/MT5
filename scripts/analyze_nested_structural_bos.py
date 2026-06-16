#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import os
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

import MetaTrader5 as mt5

from analyze_multicurrency_score_scanner_2025 import (
    BACKTEST,
    calc_stats,
    parse_mt5_deals,
    serialize_stats,
    write_rows,
    write_trades,
)


ROOT = Path(__file__).resolve().parents[1]
OUT_BASE = "ExpectedValue_MultiCurrency_ScoreScanner"
OUT_PREFIX = f"{OUT_BASE}_nested_structural_bos"
MT5_RATE_TIME_OFFSET = timedelta(hours=9)

PERIODS = [
    ("2025-02", "2025_02_structural_bos"),
    ("2025-08", "2025_08_structural_bos"),
    ("2025-10", "2025_10_structural_bos"),
    ("2026-Q1", "2026_q1_structural_bos"),
]

RUNS = [
    ("A", "A_nested_all", "Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R"),
    ("B", "B_retest_all", "Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R"),
    ("C", "C_breakout_router_all", "Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R"),
    ("D", "D_context_router_v2_all", "Nested_NWave_ContextQualityRouterV2_BOTH_all_H4_H1_M15_2R"),
    ("E", "E_structural_bos_all", "Nested_NWave_StructuralBOS_BOTH_all_H4_H1_M15_2R"),
]

OUTPUTS = {
    "summary": BACKTEST / f"{OUT_PREFIX}_short_summary.md",
    "comparison": BACKTEST / f"{OUT_PREFIX}_short_comparison.csv",
    "trade_rows": BACKTEST / f"{OUT_PREFIX}_trade_rows.csv",
    "by_symbol": BACKTEST / f"{OUT_PREFIX}_by_symbol.csv",
    "by_direction": BACKTEST / f"{OUT_PREFIX}_by_direction.csv",
    "by_session": BACKTEST / f"{OUT_PREFIX}_by_session.csv",
    "by_month": BACKTEST / f"{OUT_PREFIX}_by_month.csv",
    "by_label": BACKTEST / f"{OUT_PREFIX}_by_label.csv",
    "fx_vs_xauusd": BACKTEST / f"{OUT_PREFIX}_fx_vs_xauusd.csv",
    "mfe_mae": BACKTEST / f"{OUT_PREFIX}_mfe_mae_r_reach.csv",
    "block_summary": BACKTEST / f"{OUT_PREFIX}_block_summary.csv",
    "metrics": BACKTEST / f"{OUT_PREFIX}_metrics.json",
}


def prefix(series: str, run_name: str) -> str:
    return f"{OUT_BASE}_{series}_{run_name}"


def md_link(label: str, target: Path, base: Path) -> str:
    rel = os.path.relpath(target.resolve(), base.resolve())
    return f"[{label}]({Path(rel).as_posix()})"


def as_float(value: Any, default: float = 0.0) -> float:
    if value is None:
        return default
    try:
        text = str(value).replace("\xa0", "").replace(" ", "").replace(",", "").strip()
        return float(text) if text else default
    except ValueError:
        return default


def parse_time(value: str) -> datetime | None:
    value = (value or "").strip()
    if not value:
        return None
    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")


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
        run_id = row.get("run_id") or row.get("run") or ""
        if run_id:
            result[run_id] = as_float(row.get("elapsed_seconds"))
    return result


def read_scan_driver_symbols(pfx: str) -> str:
    rows = read_csv_rows(BACKTEST / f"{pfx}_scan_diagnostics.csv")
    symbols = sorted({row.get("scan_driver_symbol", "") for row in rows if row.get("scan_driver_symbol")})
    return ";".join(symbols)


def read_or_parse_trades(pfx: str) -> list[dict[str, object]]:
    report_path = BACKTEST / f"{pfx}_report.html"
    if not report_path.exists():
        return []
    trades = parse_mt5_deals(report_path)
    write_trades(BACKTEST / f"{pfx}_trades.csv", trades)
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
            "risk_r",
            "rr",
            "sl_atr",
            "tp_atr",
            "volume",
            "h1_bos_level",
            "distance_bos_to_entry_atr",
            "distance_neckline_to_entry_atr",
            "distance_right_side_to_entry_atr",
            "breakout_close_distance_from_neckline_atr",
            "breakout_body_ratio",
            "breakout_body_atr",
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
        if delta > 1800:
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
    if trade.get("direction") == "LONG":
        risk = entry - sl
        return (close - entry) / risk if risk > 0.0 else 0.0
    risk = sl - entry
    return (entry - close) / risk if risk > 0.0 else 0.0


class RateCache:
    def __init__(self) -> None:
        self.cache: dict[tuple[str, datetime, datetime], list[dict[str, Any]]] = {}

    @staticmethod
    def floor_m15(value: datetime) -> datetime:
        return value.replace(minute=value.minute - value.minute % 15, second=0, microsecond=0)

    def get(self, symbol: str, start: datetime, end: datetime) -> list[dict[str, Any]]:
        start = self.floor_m15(start)
        end = self.floor_m15(end) + timedelta(minutes=15)
        key = (symbol, start, end)
        if key in self.cache:
            return self.cache[key]
        data = mt5.copy_rates_range(symbol, mt5.TIMEFRAME_M15, start + MT5_RATE_TIME_OFFSET, end + MT5_RATE_TIME_OFFSET)
        rows: list[dict[str, Any]] = []
        if data is not None:
            for item in data:
                rows.append(
                    {
                        "time": datetime.fromtimestamp(int(item["time"])) - MT5_RATE_TIME_OFFSET,
                        "high": float(item["high"]),
                        "low": float(item["low"]),
                    }
                )
        self.cache[key] = rows
        return rows


def r_reach_metrics(trade: dict[str, object], diag: dict[str, object] | None, cache: RateCache | None) -> dict[str, object]:
    result = {
        "max_favorable_r": "",
        "max_adverse_r": "",
        "reached_0_5R": "",
        "reached_1R": "",
        "reached_1_5R": "",
        "reached_2R": "",
    }
    if diag is None or cache is None:
        return result
    entry = as_float(diag.get("entry_price"))
    sl = as_float(diag.get("sl"))
    if entry <= 0.0 or sl <= 0.0:
        return result
    risk = entry - sl if trade.get("direction") == "LONG" else sl - entry
    if risk <= 0.0:
        return result
    rates = cache.get(str(trade["symbol"]), trade["open_time"], trade["close_time"])
    if not rates:
        return result
    max_fav = 0.0
    max_adv = 0.0
    for bar in rates:
        if trade.get("direction") == "LONG":
            max_fav = max(max_fav, (bar["high"] - entry) / risk)
            max_adv = max(max_adv, (entry - bar["low"]) / risk)
        else:
            max_fav = max(max_fav, (entry - bar["low"]) / risk)
            max_adv = max(max_adv, (bar["high"] - entry) / risk)
    result["max_favorable_r"] = round(max_fav, 3)
    result["max_adverse_r"] = round(max_adv, 3)
    result["reached_0_5R"] = max_fav >= 0.5
    result["reached_1R"] = max_fav >= 1.0
    result["reached_1_5R"] = max_fav >= 1.5
    result["reached_2R"] = max_fav >= 2.0
    return result


def fx_bucket(symbol: object) -> str:
    return "XAUUSD" if str(symbol) == "XAUUSD" else "FX"


def summarize(rows: list[dict[str, object]]) -> dict[str, object]:
    synthetic = [
        {"net_profit": as_float(row["net_profit"]), "open_time": row["open_time"], "close_time": row["close_time"]}
        for row in rows
    ]
    stats = calc_stats(synthetic)
    result_rs = [as_float(row.get("result_R")) for row in rows]
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
        record.update(summarize(bucket))
        output.append(record)
    return output


def block_summary(period: str, series: str, run_id: str, run_name: str, scenario: str) -> list[dict[str, object]]:
    rows = read_csv_rows(BACKTEST / f"{prefix(series, run_name)}_nested_nwave_signal_diagnostics.csv")
    counts: Counter[tuple[str, str, str]] = Counter()
    for row in rows:
        if row.get("event") != "blocked_candidate":
            continue
        counts[(row.get("fail_reason", "") or "none", row.get("label", "") or "none", row.get("structural_bos_state", "") or "none")] += 1
    return [
        {
            "period": period,
            "run": run_id,
            "scenario": scenario,
            "fail_reason": key[0],
            "label": key[1],
            "structural_bos_state": key[2],
            "rows": value,
        }
        for key, value in counts.most_common()
    ]


def main() -> None:
    mt5_ready = mt5.initialize()
    cache = RateCache() if mt5_ready else None
    all_rows: list[dict[str, object]] = []
    comparison: list[dict[str, object]] = []
    blocks: list[dict[str, object]] = []

    for period, series in PERIODS:
        elapsed = read_elapsed(series)
        for run_id, run_name, scenario in RUNS:
            pfx = prefix(series, run_name)
            trades = read_or_parse_trades(pfx)
            sent_rows = load_order_sent_rows(pfx)
            used: set[int] = set()
            enriched: list[dict[str, object]] = []
            for idx, trade in enumerate(trades, start=1):
                diag = match_diag(trade, sent_rows, used)
                result_r = price_result_r(trade, diag)
                mfe = r_reach_metrics(trade, diag, cache)
                row = {
                    "period": period,
                    "month": trade["open_time"].strftime("%Y-%m"),
                    "run": run_id,
                    "scenario": scenario,
                    "trade_index": idx,
                    "open_time": trade["open_time"].strftime("%Y.%m.%d %H:%M:%S"),
                    "close_time": trade["close_time"].strftime("%Y.%m.%d %H:%M:%S"),
                    "symbol": trade["symbol"],
                    "fx_vs_xauusd": fx_bucket(trade["symbol"]),
                    "direction": trade["direction"],
                    "net_profit": round(as_float(trade["net_profit"]), 2),
                    "result_R": round(result_r, 3),
                    "session": diag.get("session", "") if diag else "",
                    "label": diag.get("label", "unmatched") if diag else "unmatched",
                    "fib_zone": diag.get("fib_zone", "") if diag else "",
                    "h4_trend_state": diag.get("h4_trend_state", "") if diag else "",
                    "h1_counter_trend_state": diag.get("h1_counter_trend_state", "") if diag else "",
                    "neckline_break_label": diag.get("neckline_break_label", "") if diag else "",
                    "structural_bos_state": diag.get("structural_bos_state", "") if diag else "",
                    "m15_confirmation_type": diag.get("m15_confirmation_type", "") if diag else "",
                    "h1_bos_level": round(as_float(diag.get("h1_bos_level")), 5) if diag else 0.0,
                    "distance_bos_to_entry_atr": round(as_float(diag.get("distance_bos_to_entry_atr")), 3) if diag else 0.0,
                    "bars_since_bos": int(as_float(diag.get("bars_since_bos"))) if diag else 0,
                    "sl_atr": round(as_float(diag.get("sl_atr")), 3) if diag else 0.0,
                    "breakout_quality_label": diag.get("breakout_quality_label", "") if diag else "",
                    "context_quality_label": diag.get("context_quality_label", "") if diag else "",
                    "scan_driver_symbol": read_scan_driver_symbols(pfx),
                    **mfe,
                }
                enriched.append(row)
                all_rows.append(row)
            comp = {"period": period, "run": run_id, "scenario": scenario, "elapsed_seconds": round(elapsed.get(run_id, 0.0), 1)}
            comp.update(summarize(enriched))
            comp["fx_net"] = round(sum(as_float(row["net_profit"]) for row in enriched if row["fx_vs_xauusd"] == "FX"), 2)
            comp["xauusd_net"] = round(sum(as_float(row["net_profit"]) for row in enriched if row["fx_vs_xauusd"] == "XAUUSD"), 2)
            comp["long_net"] = round(sum(as_float(row["net_profit"]) for row in enriched if row["direction"] == "LONG"), 2)
            comp["short_net"] = round(sum(as_float(row["net_profit"]) for row in enriched if row["direction"] == "SHORT"), 2)
            comp["scan_driver_symbol"] = read_scan_driver_symbols(pfx)
            comparison.append(comp)
            blocks.extend(block_summary(period, series, run_id, run_name, scenario))

    if mt5_ready:
        mt5.shutdown()

    write_union_rows(OUTPUTS["trade_rows"], all_rows)
    write_union_rows(OUTPUTS["comparison"], comparison)
    write_union_rows(OUTPUTS["by_symbol"], group_rows(all_rows, ["period", "scenario", "symbol"]))
    write_union_rows(OUTPUTS["by_direction"], group_rows(all_rows, ["period", "scenario", "direction"]))
    write_union_rows(OUTPUTS["by_session"], group_rows(all_rows, ["period", "scenario", "session"]))
    write_union_rows(OUTPUTS["by_month"], group_rows(all_rows, ["scenario", "month"]))
    write_union_rows(OUTPUTS["by_label"], group_rows(all_rows, ["period", "scenario", "label"]))
    write_union_rows(OUTPUTS["fx_vs_xauusd"], group_rows(all_rows, ["period", "scenario", "fx_vs_xauusd"]))
    write_union_rows(OUTPUTS["mfe_mae"], all_rows)
    write_union_rows(OUTPUTS["block_summary"], blocks)

    aggregate = group_rows(all_rows, ["scenario"])
    structural = next((row for row in aggregate if row["scenario"].startswith("Nested_NWave_StructuralBOS")), None)
    best_baseline = max((row for row in aggregate if not row["scenario"].startswith("Nested_NWave_StructuralBOS")), key=lambda row: as_float(row["avg_R"]), default=None)
    clean_rows = [row for row in all_rows if row["scenario"].startswith("Nested_NWave_StructuralBOS") and row["label"] == "clean_structural_bos"]
    chasing_rows = [row for row in all_rows if row["scenario"].startswith("Nested_NWave_StructuralBOS") and row["label"] == "chasing_entry"]

    proceed_annual = False
    gate_reasons: list[str] = []
    if structural and best_baseline:
        if structural["trades"] < 10:
            gate_reasons.append("trade count too low")
        if as_float(structural["avg_R"]) <= as_float(best_baseline["avg_R"]) and as_float(structural["profit_factor"]) <= as_float(best_baseline["profit_factor"]):
            gate_reasons.append("PF/avg_R did not beat the best baseline")
        fx_net = sum(as_float(row["net_profit"]) for row in all_rows if row["scenario"].startswith("Nested_NWave_StructuralBOS") and row["fx_vs_xauusd"] == "FX")
        xau_net = sum(as_float(row["net_profit"]) for row in all_rows if row["scenario"].startswith("Nested_NWave_StructuralBOS") and row["fx_vs_xauusd"] == "XAUUSD")
        long_net = sum(as_float(row["net_profit"]) for row in all_rows if row["scenario"].startswith("Nested_NWave_StructuralBOS") and row["direction"] == "LONG")
        short_net = sum(as_float(row["net_profit"]) for row in all_rows if row["scenario"].startswith("Nested_NWave_StructuralBOS") and row["direction"] == "SHORT")
        if fx_net < -1e-6:
            gate_reasons.append("FX net is negative")
        if xau_net > 0 and fx_net <= 0:
            gate_reasons.append("improvement depends on XAUUSD")
        if min(long_net, short_net) < -abs(max(long_net, short_net)) * 0.5:
            gate_reasons.append("direction balance is weak")
        if clean_rows and chasing_rows:
            if as_float(summarize(clean_rows)["avg_R"]) <= as_float(summarize(chasing_rows)["avg_R"]):
                gate_reasons.append("clean_structural_bos did not beat chasing_entry")
        if not gate_reasons:
            proceed_annual = True
    else:
        gate_reasons.append("missing structural or baseline aggregate")

    lines = [
        "# Nested N-Wave Structural BOS Short Summary",
        "",
        "This is a fixed-rule diagnostic run. It does not use Friday stops, symbol exclusions, direction-only promotion, or parameter optimization.",
        "",
        "## Aggregate",
        "",
        "| scenario | trades | PF | avg_R | net | maxDD% | FX net | XAUUSD net | LONG net | SHORT net |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    by_scenario = {row["scenario"]: row for row in aggregate}
    for scenario, row in sorted(by_scenario.items()):
        fx_net = sum(as_float(item["net_profit"]) for item in all_rows if item["scenario"] == scenario and item["fx_vs_xauusd"] == "FX")
        xau_net = sum(as_float(item["net_profit"]) for item in all_rows if item["scenario"] == scenario and item["fx_vs_xauusd"] == "XAUUSD")
        long_net = sum(as_float(item["net_profit"]) for item in all_rows if item["scenario"] == scenario and item["direction"] == "LONG")
        short_net = sum(as_float(item["net_profit"]) for item in all_rows if item["scenario"] == scenario and item["direction"] == "SHORT")
        lines.append(f"| {scenario} | {row['trades']} | {row['profit_factor']} | {row['avg_R']} | {row['net_profit']} | {row['max_dd_pct']} | {fx_net:.2f} | {xau_net:.2f} | {long_net:.2f} | {short_net:.2f} |")

    lines.extend([
        "",
        "## Structural BOS Labels",
        "",
        "| label | trades | PF | avg_R | net |",
        "|---|---:|---:|---:|---:|",
    ])
    for row in group_rows([item for item in all_rows if item["scenario"].startswith("Nested_NWave_StructuralBOS")], ["label"]):
        lines.append(f"| {row['label']} | {row['trades']} | {row['profit_factor']} | {row['avg_R']} | {row['net_profit']} |")

    lines.extend([
        "",
        "## Gate Decision",
        "",
        f"- Annual BT: {'proceed' if proceed_annual else 'do not proceed'}",
    ])
    for reason in gate_reasons:
        lines.append(f"- Gate reason: {reason}")

    lines.extend([
        "",
        "## Artifacts",
        "",
        f"- Comparison CSV: {md_link('short comparison', OUTPUTS['comparison'], OUTPUTS['summary'].parent)}",
        f"- Trade rows: {md_link('trade rows', OUTPUTS['trade_rows'], OUTPUTS['summary'].parent)}",
        f"- MFE/MAE/R reach: {md_link('MFE/MAE/R reach', OUTPUTS['mfe_mae'], OUTPUTS['summary'].parent)}",
        f"- By label: {md_link('by label', OUTPUTS['by_label'], OUTPUTS['summary'].parent)}",
        f"- FX vs XAUUSD: {md_link('FX vs XAUUSD', OUTPUTS['fx_vs_xauusd'], OUTPUTS['summary'].parent)}",
        f"- Compile log: {md_link('compile log', ROOT / 'reports' / 'compile' / 'ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_compile.log', OUTPUTS['summary'].parent)}",
    ])
    OUTPUTS["summary"].write_text("\n".join(lines) + "\n", encoding="utf-8")

    metrics = {
        "aggregate": aggregate,
        "comparison": comparison,
        "proceed_annual": proceed_annual,
        "gate_reasons": gate_reasons,
        "mt5_rates_available": mt5_ready,
    }
    OUTPUTS["metrics"].write_text(json.dumps(metrics, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    print(json.dumps({"proceed_annual": proceed_annual, "gate_reasons": gate_reasons, "summary": str(OUTPUTS["summary"])}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
