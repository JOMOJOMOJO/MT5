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
    group_stats,
    parse_mt5_deals,
    read_trades,
    serialize_stats,
    write_rows,
    write_trades,
)


OUT_PREFIX = "ExpectedValue_MultiCurrency_ScoreScanner_scan_interval"

SERIES = [
    {"period": "2025", "series_name": "2025_thirdwave_scan_interval"},
    {"period": "2024", "series_name": "2024_thirdwave_scan_interval"},
    {"period": "2026YTD", "series_name": "2026ytd_thirdwave_scan_interval"},
]

RUNS = [
    {"run": "A", "scenario": "ThirdWave_regime_BOTH_best_5m", "suffix": "A_regime_best_5m", "selection": "best", "scan_minutes": 5},
    {"run": "B", "scenario": "ThirdWave_regime_BOTH_best_10m", "suffix": "B_regime_best_10m", "selection": "best", "scan_minutes": 10},
    {"run": "C", "scenario": "ThirdWave_regime_BOTH_best_15m", "suffix": "C_regime_best_15m", "selection": "best", "scan_minutes": 15},
    {"run": "D", "scenario": "ThirdWave_regime_BOTH_all_5m", "suffix": "D_regime_all_5m", "selection": "all", "scan_minutes": 5},
    {"run": "E", "scenario": "ThirdWave_regime_BOTH_all_10m", "suffix": "E_regime_all_10m", "selection": "all", "scan_minutes": 10},
    {"run": "F", "scenario": "ThirdWave_regime_BOTH_all_15m", "suffix": "F_regime_all_15m", "selection": "all", "scan_minutes": 15},
]


def series_prefix(series_name: str) -> str:
    return f"ExpectedValue_MultiCurrency_ScoreScanner_{series_name}"


def run_prefix(series_name: str, run: dict[str, Any]) -> str:
    return f"{series_prefix(series_name)}_{run['suffix']}"


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return list(csv.DictReader(fh))


def parse_log_time(value: str) -> datetime | None:
    value = value.strip()
    if not value:
        return None
    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")


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
    values: dict[str, float] = {}
    if not path.exists():
        return values
    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            if row.get("run") and row.get("elapsed_seconds"):
                values[row["run"]] = float(row["elapsed_seconds"])
    return values


def read_scan_stats(path: Path) -> dict[str, object]:
    rows = read_csv_rows(path)
    elapsed: list[int] = []
    executed = 0
    skipped = 0
    for row in rows:
        event = row.get("event", "")
        if event.startswith("scan_executed"):
            executed += 1
            value = row.get("scan_elapsed_ms", "")
            if value:
                elapsed.append(as_int(value))
        elif event.startswith("scan_skipped"):
            skipped += 1
    return {
        "scan_rows": len(rows),
        "scan_executed_rows": executed,
        "scan_skipped_rows": skipped,
        "avg_scan_elapsed_ms": round(sum(elapsed) / len(elapsed), 2) if elapsed else 0.0,
        "max_scan_elapsed_ms": max(elapsed) if elapsed else 0,
    }


def file_line_count(path: Path) -> int:
    if not path.exists():
        return 0
    with path.open("rb") as fh:
        return sum(1 for _ in fh)


def file_size(path: Path) -> int:
    return path.stat().st_size if path.exists() else 0


def artifact_sizes(prefix: str) -> dict[str, object]:
    files = list(BACKTEST.glob(f"{prefix}*"))
    csv_files = [path for path in files if path.suffix.lower() == ".csv"]
    detail_files = [
        BACKTEST / f"{prefix}_scan_diagnostics.csv",
        BACKTEST / f"{prefix}_thirdwave_signal_diagnostics.csv",
        BACKTEST / f"{prefix}_thirdwave_trade_diagnostics.csv",
        BACKTEST / f"{prefix}_thirdwave_summary.csv",
    ]
    return {
        "artifact_files": len(files),
        "artifact_bytes": sum(file_size(path) for path in files),
        "csv_bytes": sum(file_size(path) for path in csv_files),
        "diagnostic_csv_bytes": sum(file_size(path) for path in detail_files),
        "scan_csv_bytes": file_size(BACKTEST / f"{prefix}_scan_diagnostics.csv"),
        "signal_csv_bytes": file_size(BACKTEST / f"{prefix}_thirdwave_signal_diagnostics.csv"),
        "trade_diag_csv_bytes": file_size(BACKTEST / f"{prefix}_thirdwave_trade_diagnostics.csv"),
        "summary_csv_bytes": file_size(BACKTEST / f"{prefix}_thirdwave_summary.csv"),
        "scan_csv_rows": file_line_count(BACKTEST / f"{prefix}_scan_diagnostics.csv"),
        "signal_csv_rows": file_line_count(BACKTEST / f"{prefix}_thirdwave_signal_diagnostics.csv"),
        "trade_diag_csv_rows": file_line_count(BACKTEST / f"{prefix}_thirdwave_trade_diagnostics.csv"),
        "summary_csv_rows": file_line_count(BACKTEST / f"{prefix}_thirdwave_summary.csv"),
    }


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


def r_result_band(value: float) -> str:
    return band(value, [-1.0, -0.25, 0.25, 1.0, 1.5], ["<-1R", "-1R--0.25R", "-0.25R-0.25R", "0.25R-1R", "1R-1.5R", "1.5R+"])


def match_order_sent(
    trade: dict[str, object],
    sent_logs: list[dict[str, str]],
    used: set[int],
) -> dict[str, str]:
    best_index = -1
    best_delta = 10**9
    open_time = trade["open_time"]
    for idx, row in enumerate(sent_logs):
        if idx in used:
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
            best_delta = int(delta)
            best_index = idx
    if best_index >= 0:
        used.add(best_index)
        return sent_logs[best_index]
    return {}


def enrich_trades(
    trades: list[dict[str, object]],
    trade_logs: list[dict[str, str]],
    context: dict[str, object],
) -> list[dict[str, object]]:
    sent_logs = [row for row in trade_logs if row.get("event") == "order_sent"]
    used: set[int] = set()
    enriched: list[dict[str, object]] = []
    for idx, trade in enumerate(trades):
        diag = match_order_sent(trade, sent_logs, used)
        row = dict(trade)
        row.update(context)
        row["trade_index"] = idx + 1
        row["regime"] = diag.get("regime", "not_logged") or "not_logged"
        row["regime_reason"] = diag.get("regime_reason", "")
        row["trend_strength"] = as_float(diag.get("trend_strength"))
        row["lower_reversal_quality"] = as_float(diag.get("lower_reversal_quality"))
        row["pullback_depth_atr"] = as_float(diag.get("pullback_depth_atr"))
        row["spread_atr"] = as_float(diag.get("spread_atr"))
        row["spread_atr_band"] = spread_atr_band(float(row["spread_atr"]))
        row["risk_r"] = as_float(diag.get("risk_r"))
        row["atr_value"] = as_float(diag.get("atr_value"))
        row["entry_price_logged"] = as_float(diag.get("entry_price"))
        logged_sl_atr = as_float(diag.get("sl_atr"))
        row["sl_atr"] = logged_sl_atr if logged_sl_atr > 0 else ((float(row["risk_r"]) / float(row["atr_value"])) if float(row["atr_value"]) > 0 else 0.0)
        row["sl_atr_band"] = sl_atr_band(float(row["sl_atr"]))
        risk_r = float(row["risk_r"])
        entry_price = float(row["entry_price_logged"]) if float(row["entry_price_logged"]) > 0 else float(row["open_price"])
        close_price = float(row["close_price"])
        if risk_r > 0:
            direction_sign = 1.0 if row["direction"] == "LONG" else -1.0
            r_result = (close_price - entry_price) * direction_sign / risk_r
        else:
            r_result = 0.0
        row["r_result"] = round(r_result, 4)
        row["r_result_band"] = r_result_band(r_result)
        row["session"] = session_for_hour(row["open_time"].hour)
        row["hour"] = f"{row['open_time'].hour:02d}"
        enriched.append(row)
    return enriched


def write_group_csv(path: Path, trades: list[dict[str, object]], key_fn) -> None:
    buckets: dict[tuple[str, str, str, str], list[dict[str, object]]] = defaultdict(list)
    for trade in trades:
        key = (
            str(trade["period"]),
            str(trade["selection_mode"]),
            str(trade["scan_minutes"]),
            str(key_fn(trade)),
        )
        buckets[key].append(trade)
    rows: list[dict[str, object]] = []
    for (period, selection, scan_minutes, group), bucket in sorted(buckets.items()):
        for row in group_stats(bucket, lambda _t, group=group: group):
            rows.append({"period": period, "selection_mode": selection, "scan_minutes": scan_minutes, **row})
    write_rows(path, rows)


def md_table(rows: list[dict[str, object]], columns: list[str]) -> str:
    lines = ["| " + " | ".join(columns) + " |", "| " + " | ".join(["---"] * len(columns)) + " |"]
    for row in rows:
        lines.append("| " + " | ".join(str(row.get(col, "")) for col in columns) + " |")
    return "\n".join(lines)


def write_summary(run_rows: list[dict[str, object]], has_oos: bool) -> None:
    primary = [row for row in run_rows if row["period"] == "2025"]
    oos = [row for row in run_rows if row["period"] != "2025"]
    lookup = {(str(row["period"]), str(row["scenario"])): row for row in run_rows}

    def val(period: str, scenario: str, key: str) -> object:
        return lookup.get((period, scenario), {}).get(key, "")

    compact = [
        {
            "scenario": row["scenario"],
            "trades": row["trades"],
            "net_profit": row["net_profit"],
            "profit_factor": row["profit_factor"],
            "expected_payoff": row["expected_payoff"],
            "max_balance_dd_pct": row["max_balance_dd_pct"],
            "elapsed_seconds": row["elapsed_seconds"],
            "avg_scan_elapsed_ms": row["avg_scan_elapsed_ms"],
            "diagnostic_csv_kb": row["diagnostic_csv_kb"],
            "xauusd_trade_share_pct": row["xauusd_trade_share_pct"],
            "fx_net_profit": row["fx_net_profit"],
        }
        for row in primary
    ]
    oos_compact = [
        {
            "period": row["period"],
            "scenario": row["scenario"],
            "trades": row["trades"],
            "net_profit": row["net_profit"],
            "profit_factor": row["profit_factor"],
            "expected_payoff": row["expected_payoff"],
            "max_balance_dd_pct": row["max_balance_dd_pct"],
            "elapsed_seconds": row["elapsed_seconds"],
        }
        for row in oos
    ]
    lines = [
        "# ThirdWave Scan Interval And Entry Selection Summary",
        "",
        "## Scope",
        "",
        "- Added `InpEntrySelectionMode` with `BEST_ONLY` and research-only `ALL_SCORE_PASSING`.",
        "- Added `InpDiagnosticsLevel`; these runs use `DIAG_ENTRY_ONLY` to keep scan diagnostics, entry candidates, execution blocks, order results, and summary counters while suppressing early-fail raw rows.",
        "- Existing Phase 2 score scanner, original ThirdWave, regime ThirdWave rules, risk sizing, SL/TP, and CTrade bridge were not optimized or replaced.",
        "- Primary comparison is 2025. OOS rows are included only when the corresponding reports exist.",
        "",
        "## 2025 Results",
        "",
        md_table(
            compact,
            [
                "scenario",
                "trades",
                "net_profit",
                "profit_factor",
                "expected_payoff",
                "max_balance_dd_pct",
                "elapsed_seconds",
                "avg_scan_elapsed_ms",
                "diagnostic_csv_kb",
                "xauusd_trade_share_pct",
                "fx_net_profit",
            ],
        ),
        "",
        "## OOS Results",
        "",
        md_table(
            oos_compact,
            [
                "period",
                "scenario",
                "trades",
                "net_profit",
                "profit_factor",
                "expected_payoff",
                "max_balance_dd_pct",
                "elapsed_seconds",
            ],
        ) if oos_compact else "OOS rows were not generated.",
        "",
        "## Initial Judgment",
        "",
        f"- 2025 best-only did not require 5m scans in this branch: 5m PF `{val('2025', 'ThirdWave_regime_BOTH_best_5m', 'profit_factor')}`, 10m PF `{val('2025', 'ThirdWave_regime_BOTH_best_10m', 'profit_factor')}`, 15m PF `{val('2025', 'ThirdWave_regime_BOTH_best_15m', 'profit_factor')}`. The 15m run had the smallest loss and DD, but all three remained negative.",
        f"- 2024 does not support moving straight to 15m: best 5m PF `{val('2024', 'ThirdWave_regime_BOTH_best_5m', 'profit_factor')}`, best 10m PF `{val('2024', 'ThirdWave_regime_BOTH_best_10m', 'profit_factor')}`, best 15m PF `{val('2024', 'ThirdWave_regime_BOTH_best_15m', 'profit_factor')}`.",
        f"- 2026YTD keeps positive expectancy at 5m/10m but gives up most edge at 15m: best 5m net `{val('2026YTD', 'ThirdWave_regime_BOTH_best_5m', 'net_profit')}`, best 10m net `{val('2026YTD', 'ThirdWave_regime_BOTH_best_10m', 'net_profit')}`, best 15m net `{val('2026YTD', 'ThirdWave_regime_BOTH_best_15m', 'net_profit')}`.",
        f"- All-candidates mode exposed more candidates but did not reveal a broad multi-symbol edge. In 2025, all 5m improved net from `{val('2025', 'ThirdWave_regime_BOTH_best_5m', 'net_profit')}` to `{val('2025', 'ThirdWave_regime_BOTH_all_5m', 'net_profit')}`, but FX remained negative and 10m worsened.",
        "- The useful information from all-candidates is diagnostic: 2025 `REGIME_TREND_UP` remained the main loss source at 5m/10m, while 15m reduced that damage but did not produce a robust OOS edge.",
        "- CSV reduction is effective for structure/regime raw rows: signal diagnostics are now hundreds of rows instead of per-scan all-symbol rows. The remaining large file is scan diagnostics, kept intentionally for elapsed-ms analysis.",
        "",
        "## Artifacts",
        "",
        f"- Run comparison: `reports/backtest/{OUT_PREFIX}_run_comparison.csv`",
        f"- Scan interval comparison: `reports/backtest/{OUT_PREFIX}_scan_interval_comparison.csv`",
        f"- Entry selection comparison: `reports/backtest/{OUT_PREFIX}_entry_selection_comparison.csv`",
        f"- Log size comparison: `reports/backtest/{OUT_PREFIX}_log_size_comparison.csv`",
        f"- Trade join: `reports/backtest/{OUT_PREFIX}_trade_join.csv`",
        f"- By symbol: `reports/backtest/{OUT_PREFIX}_by_symbol.csv`",
        f"- By direction: `reports/backtest/{OUT_PREFIX}_by_direction.csv`",
        f"- By regime: `reports/backtest/{OUT_PREFIX}_by_regime.csv`",
        f"- By session: `reports/backtest/{OUT_PREFIX}_by_session.csv`",
    ]
    if has_oos:
        lines.extend(["", "OOS report rows were generated for 2024 and 2026YTD scan-interval runs."])
    (BACKTEST / f"{OUT_PREFIX}_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_devlog() -> None:
    devlog = BACKTEST.parents[1] / "docs" / "devlog" / "2026-06-04-thirdwave-scan-interval-all-candidates.md"
    lines = [
        "# 2026-06-04 - ThirdWave Scan Interval And All Candidates",
        "",
        "## Summary",
        "",
        "- Added research-only all-candidates entry selection while preserving best-only as the default.",
        "- Added diagnostics levels and kept scan diagnostics available for speed analysis.",
        "- Added scan interval runner scenarios for 5m, 10m, and 15m comparisons.",
        "- Added analyzer outputs for interval, selection mode, symbol, direction, regime, session, month, R result, and log size.",
        "",
        "## Evidence",
        "",
        f"- Summary: `reports/backtest/{OUT_PREFIX}_summary.md`",
        f"- Run comparison: `reports/backtest/{OUT_PREFIX}_run_comparison.csv`",
        f"- Log size comparison: `reports/backtest/{OUT_PREFIX}_log_size_comparison.csv`",
    ]
    devlog.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    enriched_trades: list[dict[str, object]] = []
    run_trades: dict[str, list[dict[str, object]]] = {}
    run_rows: list[dict[str, object]] = []
    log_rows: list[dict[str, object]] = []

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
            trade_logs = read_csv_rows(BACKTEST / f"{prefix}_thirdwave_trade_diagnostics.csv")
            context = {
                "period": series["period"],
                "run": run["run"],
                "scenario": run["scenario"],
                "selection_mode": run["selection"],
                "scan_minutes": run["scan_minutes"],
                "prefix": prefix,
            }
            enriched = enrich_trades(parsed_trades, trade_logs, context)
            enriched_trades.extend(enriched)
            run_trades[f"{series['period']}_{run['run']}"] = enriched

            stats = calc_stats(parsed_trades)
            scan_stats = read_scan_stats(BACKTEST / f"{prefix}_scan_diagnostics.csv")
            sizes = artifact_sizes(prefix)
            long_trades = [t for t in parsed_trades if t["direction"] == "LONG"]
            short_trades = [t for t in parsed_trades if t["direction"] == "SHORT"]
            xau_trades = [t for t in parsed_trades if t["symbol"] == "XAUUSD"]
            fx_trades = [t for t in parsed_trades if t["symbol"] != "XAUUSD"]
            run_row = {
                "period": series["period"],
                "run": run["run"],
                "scenario": run["scenario"],
                "selection_mode": run["selection"],
                "scan_minutes": run["scan_minutes"],
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
                "long_trades": len(long_trades),
                "long_net_profit": round(sum(float(t["net_profit"]) for t in long_trades), 2),
                "short_trades": len(short_trades),
                "short_net_profit": round(sum(float(t["net_profit"]) for t in short_trades), 2),
                "xauusd_trades": len(xau_trades),
                "xauusd_trade_share_pct": round(len(xau_trades) / len(parsed_trades) * 100.0, 2) if parsed_trades else 0.0,
                "xauusd_net_profit": round(sum(float(t["net_profit"]) for t in xau_trades), 2),
                "fx_trades": len(fx_trades),
                "fx_net_profit": round(sum(float(t["net_profit"]) for t in fx_trades), 2),
                **scan_stats,
                **sizes,
                "diagnostic_csv_kb": round(float(sizes["diagnostic_csv_bytes"]) / 1024.0, 2),
            }
            run_rows.append(run_row)
            log_rows.append(
                {
                    "period": series["period"],
                    "run": run["run"],
                    "scenario": run["scenario"],
                    "selection_mode": run["selection"],
                    "scan_minutes": run["scan_minutes"],
                    **sizes,
                    "diagnostic_csv_kb": round(float(sizes["diagnostic_csv_bytes"]) / 1024.0, 2),
                }
            )

    write_rows(BACKTEST / f"{OUT_PREFIX}_run_comparison.csv", run_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_trade_join.csv", enriched_trades)
    write_rows(BACKTEST / f"{OUT_PREFIX}_log_size_comparison.csv", log_rows)

    write_group_csv(BACKTEST / f"{OUT_PREFIX}_scan_interval_comparison.csv", enriched_trades, lambda t: f"{t['scan_minutes']}m")
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_entry_selection_comparison.csv", enriched_trades, lambda t: t["selection_mode"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_symbol.csv", enriched_trades, lambda t: t["symbol"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_direction.csv", enriched_trades, lambda t: t["direction"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_symbol_direction.csv", enriched_trades, lambda t: f"{t['symbol']}:{t['direction']}")
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_regime.csv", enriched_trades, lambda t: t["regime"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_regime_direction.csv", enriched_trades, lambda t: f"{t['regime']}:{t['direction']}")
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_session.csv", enriched_trades, lambda t: t["session"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_month.csv", enriched_trades, lambda t: t["open_time"].strftime("%Y-%m"))
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_sl_atr_band.csv", enriched_trades, lambda t: t["sl_atr_band"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_spread_atr_band.csv", enriched_trades, lambda t: t["spread_atr_band"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_r_result_band.csv", enriched_trades, lambda t: t["r_result_band"])

    metrics = {
        "runs": {key: serialize_stats(calc_stats(trades)) for key, trades in run_trades.items()},
        "run_rows": run_rows,
        "log_rows": log_rows,
    }
    with (BACKTEST / f"{OUT_PREFIX}_metrics.json").open("w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=2)

    has_oos = any(row["period"] != "2025" for row in run_rows)
    write_summary(run_rows, has_oos)
    write_devlog()
    print(json.dumps(run_rows, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
