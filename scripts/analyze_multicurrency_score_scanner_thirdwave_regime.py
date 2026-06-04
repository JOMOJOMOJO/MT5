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


OUT_PREFIX = "ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime"

SERIES = [
    {"period": "2024", "year": "2024", "series_name": "2024_thirdwave_regime"},
    {"period": "2025", "year": "2025", "series_name": "2025_thirdwave_regime"},
    {"period": "2026YTD", "year": "2026YTD", "series_name": "2026ytd_thirdwave_regime"},
]

RUNS = [
    {"run": "A", "scenario": "ThirdWave_original_BOTH", "suffix": "A_original_both"},
    {"run": "B", "scenario": "ThirdWave_regime_BOTH", "suffix": "B_regime_both"},
    {"run": "C", "scenario": "ThirdWave_regime_LONG_ONLY", "suffix": "C_regime_long_only"},
    {"run": "D", "scenario": "ThirdWave_regime_SHORT_ONLY", "suffix": "D_regime_short_only"},
]

STRUCTURE_REASON_KEYS = [
    "no_higher_tf_trend",
    "trend_broken",
    "no_mid_pullback",
    "pullback_too_shallow",
    "pullback_too_deep",
    "no_lower_reversal",
    "lower_reversal_quality_low",
    "sl_too_close",
    "sl_too_wide",
    "rr_too_low",
    "data_unavailable",
    "atr_unavailable",
    "research_excluded",
    "regime_requires_trend_up",
    "regime_requires_trend_down",
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


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return list(csv.DictReader(fh))


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


def read_summary(path: Path) -> dict[str, object]:
    latest: dict[str, str] | None = None
    for row in read_csv_rows(path):
        if row.get("evaluations"):
            latest = row
    if latest is None:
        return {}

    strings = {
        "time",
        "strategy_name",
        "top_structure_stage_fail_reason",
        "top_execution_block_reason",
        "top_skip_reason",
    }
    parsed: dict[str, object] = {}
    for key, value in latest.items():
        parsed[key] = value if key in strings else as_int(value)
    return parsed


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


def enrich_trades(
    trades: list[dict[str, object]],
    trade_logs: list[dict[str, str]],
    context: dict[str, str],
) -> list[dict[str, object]]:
    sent_logs = [row for row in trade_logs if row.get("event") == "order_sent"]
    enriched: list[dict[str, object]] = []
    for idx, trade in enumerate(trades):
        diag = sent_logs[idx] if idx < len(sent_logs) else {}
        row = dict(trade)
        row.update(context)
        row["trade_index"] = idx + 1
        row["regime"] = diag.get("regime", "not_logged") or "not_logged"
        row["regime_reason"] = diag.get("regime_reason", "")
        row["higher_tf_swing_state"] = diag.get("higher_tf_swing_state", "")
        row["trend_strength"] = as_float(diag.get("trend_strength"))
        row["volatility_state"] = diag.get("volatility_state", "")
        row["lower_reversal_quality"] = as_float(diag.get("lower_reversal_quality"))
        row["pullback_depth_atr"] = as_float(diag.get("pullback_depth_atr"))
        row["spread_atr"] = as_float(diag.get("spread_atr"))
        row["spread_atr_band"] = spread_atr_band(float(row["spread_atr"]))
        row["risk_r"] = as_float(diag.get("risk_r"))
        row["atr_value"] = as_float(diag.get("atr_value"))
        logged_sl_atr = as_float(diag.get("sl_atr"))
        row["sl_atr"] = logged_sl_atr if logged_sl_atr > 0 else ((float(row["risk_r"]) / float(row["atr_value"])) if float(row["atr_value"]) > 0 else 0.0)
        row["sl_atr_band"] = sl_atr_band(float(row["sl_atr"]))
        row["session"] = session_for_hour(row["open_time"].hour)
        row["hour"] = f"{row['open_time'].hour:02d}"
        enriched.append(row)
    return enriched


def write_group_csv(path: Path, trades: list[dict[str, object]], key_fn) -> None:
    buckets: dict[tuple[str, str, str], list[dict[str, object]]] = defaultdict(list)
    for trade in trades:
        key = (str(trade["period"]), str(trade["scenario"]), str(key_fn(trade)))
        buckets[key].append(trade)
    rows: list[dict[str, object]] = []
    for (period, scenario, group), bucket in sorted(buckets.items()):
        for row in group_stats(bucket, lambda _t, group=group: group):
            rows.append({"period": period, "scenario": scenario, **row})
    write_rows(path, rows)


def build_block_reason_rows(summaries: dict[tuple[str, str], dict[str, object]]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for series in SERIES:
        for run in RUNS:
            summary = summaries.get((series["period"], run["run"]), {})
            if not summary:
                continue
            for key in STRUCTURE_REASON_KEYS:
                count = as_int(summary.get(key))
                if count:
                    rows.append(
                        {
                            "period": series["period"],
                            "run": run["run"],
                            "scenario": run["scenario"],
                            "block_category": "structure_stage",
                            "block_reason": key,
                            "rows": count,
                        }
                    )
            for key in EXECUTION_REASON_KEYS:
                count = as_int(summary.get(key))
                if count:
                    rows.append(
                        {
                            "period": series["period"],
                            "run": run["run"],
                            "scenario": run["scenario"],
                            "block_category": "execution",
                            "block_reason": key.replace("execution_", ""),
                            "rows": count,
                        }
                    )
    return rows


def build_regime_summary_rows(summaries: dict[tuple[str, str], dict[str, object]]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    keys = [
        ("REGIME_TREND_UP", "regime_trend_up"),
        ("REGIME_TREND_DOWN", "regime_trend_down"),
        ("REGIME_RANGE", "regime_range"),
        ("REGIME_TRANSITION", "regime_transition"),
        ("REGIME_EXHAUSTION", "regime_exhaustion"),
        ("REGIME_UNKNOWN", "regime_unknown"),
    ]
    for series in SERIES:
        for run in RUNS:
            summary = summaries.get((series["period"], run["run"]), {})
            if not summary:
                continue
            evaluations = as_int(summary.get("evaluations"))
            for regime, key in keys:
                count = as_int(summary.get(key))
                if count:
                    rows.append(
                        {
                            "period": series["period"],
                            "run": run["run"],
                            "scenario": run["scenario"],
                            "regime": regime,
                            "evaluations": evaluations,
                            "rows": count,
                            "share_pct": round(count / evaluations * 100.0, 2) if evaluations else 0.0,
                        }
                    )
    return rows


def md_table(rows: list[dict[str, object]], columns: list[str]) -> str:
    lines = ["| " + " | ".join(columns) + " |", "| " + " | ".join(["---"] * len(columns)) + " |"]
    for row in rows:
        lines.append("| " + " | ".join(str(row.get(col, "")) for col in columns) + " |")
    return "\n".join(lines)


def write_summary(run_rows: list[dict[str, object]], regime_rows: list[dict[str, object]]) -> None:
    lookup = {(str(row["period"]), str(row["scenario"])): row for row in run_rows}

    def pf(period: str, scenario: str) -> object:
        return lookup.get((period, scenario), {}).get("profit_factor", "")

    def dd(period: str, scenario: str) -> object:
        return lookup.get((period, scenario), {}).get("max_balance_dd_pct", "")

    def net(period: str, scenario: str) -> object:
        return lookup.get((period, scenario), {}).get("net_profit", "")

    compact_rows = [
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
            "xauusd_net_profit": row["xauusd_net_profit"],
            "fx_net_profit": row["fx_net_profit"],
            "top_structure_stage_fail_reason": row["top_structure_stage_fail_reason"],
        }
        for row in run_rows
    ]
    regime_2025 = [row for row in regime_rows if row["period"] == "2025"]
    lines = [
        "# Regime-Aware ThirdWave Summary",
        "",
        "## Scope",
        "",
        "- Added a separate `DowFractal_ThirdWave_Regime` branch.",
        "- Existing Phase 2 score scanner and original ThirdWave branch are preserved.",
        "- No `InpRewardR`, timeframe, spread, risk, SL, TP, or parameter optimization changes were made.",
        "- Regime mode allows long entries only in `REGIME_TREND_UP` and short entries only in `REGIME_TREND_DOWN`.",
        "- RANGE / TRANSITION / EXHAUSTION / UNKNOWN are blocked by regime summary counters rather than full per-scan detail rows.",
        "",
        "## Run Results",
        "",
        md_table(
            compact_rows,
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
                "xauusd_net_profit",
                "fx_net_profit",
                "top_structure_stage_fail_reason",
            ],
        ),
        "",
        "## 2025 Regime Evaluation Mix",
        "",
        md_table(regime_2025, ["scenario", "regime", "rows", "share_pct"]),
        "",
        "## Initial Judgment",
        "",
        f"- 2024 improved from original BOTH PF `{pf('2024', 'ThirdWave_original_BOTH')}` / DD `{dd('2024', 'ThirdWave_original_BOTH')}%` to regime BOTH PF `{pf('2024', 'ThirdWave_regime_BOTH')}` / DD `{dd('2024', 'ThirdWave_regime_BOTH')}%`.",
        f"- 2025 did not improve expectancy: original BOTH net `{net('2025', 'ThirdWave_original_BOTH')}` / PF `{pf('2025', 'ThirdWave_original_BOTH')}` versus regime BOTH net `{net('2025', 'ThirdWave_regime_BOTH')}` / PF `{pf('2025', 'ThirdWave_regime_BOTH')}`. DD improved, but edge did not.",
        f"- 2026YTD improved from original BOTH PF `{pf('2026YTD', 'ThirdWave_original_BOTH')}` / DD `{dd('2026YTD', 'ThirdWave_original_BOTH')}%` to regime BOTH PF `{pf('2026YTD', 'ThirdWave_regime_BOTH')}` / DD `{dd('2026YTD', 'ThirdWave_regime_BOTH')}%`.",
        "- LONG/SHORT asymmetry is not solved in 2025: regime LONG_ONLY remains negative, while regime SHORT_ONLY is close to flat but still negative.",
        "- XAUUSD dependency remains high because regime BOTH still takes roughly 75%-91% of trades in XAUUSD across the tested periods.",
        "- FX expectancy is not stable: regime BOTH FX net is positive in 2024, negative in 2025, and near flat-negative in 2026YTD.",
        "- The next fix should prioritize regime precision and lower-reversal quality before changing reward, spread, timeframe, or SL/TP parameters.",
        "",
        "## Artifacts",
        "",
        f"- Run comparison: `reports/backtest/{OUT_PREFIX}_run_comparison.csv`",
        f"- Trade join: `reports/backtest/{OUT_PREFIX}_trade_join.csv`",
        f"- By regime: `reports/backtest/{OUT_PREFIX}_by_regime.csv`",
        f"- By block reason: `reports/backtest/{OUT_PREFIX}_by_block_reason.csv`",
        f"- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_compile.txt`",
    ]
    (BACKTEST / f"{OUT_PREFIX}_summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_devlog(run_rows: list[dict[str, object]]) -> None:
    devlog = BACKTEST.parents[1] / "docs" / "devlog" / "2026-06-04-thirdwave-regime-aware.md"
    lines = [
        "# 2026-06-04 - Regime-Aware ThirdWave",
        "",
        "## Summary",
        "",
        "- Added `RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_REGIME` as a separate ThirdWave branch.",
        "- Added a simple higher-timeframe regime classifier using HH/HL or LL/LH, EMA slope, trend strength, ATR ratio, and range width.",
        "- Regime branch permits long entries only in trend-up regimes and short entries only in trend-down regimes.",
        "- Strengthened lower-timeframe reversal confirmation only for the regime branch.",
        "- Preserved the existing Phase 2 score scanner and original ThirdWave branch.",
        "- Ran original/regime comparisons for 2024, 2025, and 2026YTD.",
        "",
        "## Evidence",
        "",
        f"- Summary: `reports/backtest/{OUT_PREFIX}_summary.md`",
        f"- Run comparison: `reports/backtest/{OUT_PREFIX}_run_comparison.csv`",
        f"- By regime: `reports/backtest/{OUT_PREFIX}_by_regime.csv`",
        "- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_compile.txt`",
    ]
    devlog.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    enriched_trades: list[dict[str, object]] = []
    run_trades: dict[tuple[str, str], list[dict[str, object]]] = {}
    summaries: dict[tuple[str, str], dict[str, object]] = {}
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
            enriched = enrich_trades(parsed_trades, trade_logs, context)
            enriched_trades.extend(enriched)
            run_trades[(series["period"], run["run"])] = enriched
            summary = read_summary(BACKTEST / f"{prefix}_thirdwave_summary.csv")
            summaries[(series["period"], run["run"])] = summary

            stats = calc_stats(parsed_trades)
            long_trades = [t for t in parsed_trades if t["direction"] == "LONG"]
            short_trades = [t for t in parsed_trades if t["direction"] == "SHORT"]
            xau_trades = [t for t in parsed_trades if t["symbol"] == "XAUUSD"]
            fx_trades = [t for t in parsed_trades if t["symbol"] != "XAUUSD"]
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
                    "long_trades": len(long_trades),
                    "long_net_profit": round(sum(float(t["net_profit"]) for t in long_trades), 2),
                    "short_trades": len(short_trades),
                    "short_net_profit": round(sum(float(t["net_profit"]) for t in short_trades), 2),
                    "xauusd_trades": len(xau_trades),
                    "xauusd_trade_share_pct": round(len(xau_trades) / len(parsed_trades) * 100.0, 2) if parsed_trades else 0.0,
                    "xauusd_net_profit": round(sum(float(t["net_profit"]) for t in xau_trades), 2),
                    "fx_trades": len(fx_trades),
                    "fx_net_profit": round(sum(float(t["net_profit"]) for t in fx_trades), 2),
                    "usdjpy_short_trades": len(usd_short),
                    "usdjpy_short_net_profit": round(sum(float(t["net_profit"]) for t in usd_short), 2),
                    "major_winning_symbols": winners,
                    "major_losing_symbols": losers,
                    "evaluations": summary.get("evaluations", 0),
                    "regime_allowed": summary.get("regime_allowed", 0),
                    "regime_blocked": summary.get("regime_blocked", 0),
                    "regime_trend_up": summary.get("regime_trend_up", 0),
                    "regime_trend_down": summary.get("regime_trend_down", 0),
                    "regime_range": summary.get("regime_range", 0),
                    "regime_transition": summary.get("regime_transition", 0),
                    "regime_exhaustion": summary.get("regime_exhaustion", 0),
                    "regime_unknown": summary.get("regime_unknown", 0),
                    "top_structure_stage_fail_reason": summary.get("top_structure_stage_fail_reason", summary.get("top_skip_reason", "")),
                    "top_structure_stage_fail_reason_rows": summary.get("top_structure_stage_fail_reason_rows", summary.get("top_skip_reason_rows", 0)),
                    "top_execution_block_reason": summary.get("top_execution_block_reason", ""),
                    "top_execution_block_reason_rows": summary.get("top_execution_block_reason_rows", 0),
                }
            )

    regime_rows = build_regime_summary_rows(summaries)
    block_rows = build_block_reason_rows(summaries)
    write_rows(BACKTEST / f"{OUT_PREFIX}_run_comparison.csv", run_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_trade_join.csv", enriched_trades)
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_regime_evaluations.csv", regime_rows)
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_block_reason.csv", block_rows)
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_year.csv", enriched_trades, lambda t: t["period"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_regime.csv", enriched_trades, lambda t: t["regime"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_symbol.csv", enriched_trades, lambda t: t["symbol"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_direction.csv", enriched_trades, lambda t: t["direction"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_symbol_direction.csv", enriched_trades, lambda t: f"{t['symbol']}:{t['direction']}")
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_regime_direction.csv", enriched_trades, lambda t: f"{t['regime']}:{t['direction']}")
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_session.csv", enriched_trades, lambda t: t["session"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_month.csv", enriched_trades, lambda t: t["open_time"].strftime("%Y-%m"))
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_sl_atr_band.csv", enriched_trades, lambda t: t["sl_atr_band"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_spread_atr_band.csv", enriched_trades, lambda t: t["spread_atr_band"])

    metrics = {
        "runs": {f"{period}_{run}": serialize_stats(calc_stats(trades)) for (period, run), trades in run_trades.items()},
        "run_rows": run_rows,
        "regime_rows": regime_rows,
        "block_rows": block_rows,
        "summaries": {f"{period}_{run}": summary for (period, run), summary in summaries.items()},
    }
    with (BACKTEST / f"{OUT_PREFIX}_metrics.json").open("w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=2)

    write_summary(run_rows, regime_rows)
    write_devlog(run_rows)
    print(json.dumps(run_rows, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
