import csv
import math
import shutil
from collections import defaultdict
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
COMMON_FILES = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"
OUT = REPO / "reports" / "backtest" / "runs" / "20260628_session_reversal_pullback_timeframe_matrix"
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
MATRIX = REPO / "reports" / "backtest" / f"{EA_NAME}_timeframe_matrix_run_matrix_2025.csv"
DEPOSIT = 10000.0


def fnum(value):
    if value is None or value == "":
        return 0.0
    try:
        return float(str(value).replace(",", ""))
    except ValueError:
        return 0.0


def bval(value):
    return str(value).strip().lower() in {"1", "true", "yes"}


def read_csv(path, encoding="utf-8-sig"):
    if not path.exists():
        return []
    try:
        with path.open("r", encoding=encoding, newline="") as handle:
            return list(csv.DictReader(handle))
    except UnicodeDecodeError:
        with path.open("r", encoding="mbcs", newline="") as handle:
            return list(csv.DictReader(handle))


def write_csv(path, rows, fieldnames=None):
    rows = list(rows)
    if fieldnames is None:
        fieldnames = []
        for row in rows:
            for key in row:
                if key not in fieldnames:
                    fieldnames.append(key)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def month_key(value):
    text = str(value)
    return text[:7].replace(".", "-") if len(text) >= 7 else ""


def year_key(value):
    text = str(value)
    return text[:4] if len(text) >= 4 else ""


def bucket(value, cuts):
    value = fnum(value)
    for label, high in cuts:
        if value < high:
            return label
    return cuts[-1][0]


def target_room_bucket(row):
    return bucket(row.get("target_room_score"), [
        ("negative", 0.0),
        ("zero", 0.001),
        ("low", 0.20),
        ("high", 999.0),
    ])


def retest_bucket(row):
    return bucket(row.get("retest_score"), [
        ("none", 0.001),
        ("low", 0.15),
        ("medium", 0.20),
        ("high", 999.0),
    ])


def stats(rows):
    rows = list(rows)
    profits = [fnum(r.get("net_profit")) for r in rows]
    rvals = [fnum(r.get("result_r")) for r in rows]
    count = len(rows)
    wins = sum(1 for value in profits if value > 0)
    gross_profit = sum(value for value in profits if value > 0)
    gross_loss = sum(value for value in profits if value < 0)
    net = sum(profits)
    win_r = sum(value for value in rvals if value > 0)
    loss_r = sum(value for value in rvals if value < 0)
    equity = 0.0
    peak = 0.0
    max_dd = 0.0
    for value in profits:
        equity += value
        peak = max(peak, equity)
        max_dd = min(max_dd, equity - peak)
    return {
        "trades": count,
        "wins": wins,
        "win_rate": wins / count if count else 0.0,
        "net_profit": net,
        "gross_profit": gross_profit,
        "gross_loss": gross_loss,
        "profit_factor": gross_profit / abs(gross_loss) if gross_loss < 0 else (math.inf if gross_profit > 0 else 0.0),
        "sum_r": sum(rvals),
        "avg_r": sum(rvals) / count if count else 0.0,
        "r_profit_factor": win_r / abs(loss_r) if loss_r < 0 else (math.inf if win_r > 0 else 0.0),
        "max_dd_profit": abs(max_dd),
        "max_dd_pct": abs(max_dd) / DEPOSIT * 100.0,
        "recovery_factor": net / abs(max_dd) if max_dd < 0 else (math.inf if net > 0 else 0.0),
        "break_even_triggered": sum(1 for r in rows if bval(r.get("break_even_triggered"))),
        "break_even_exits": sum(1 for r in rows if bval(r.get("break_even_exit"))),
        "full_sl_exits": sum(1 for r in rows if bval(r.get("full_sl_exit"))),
        "tp_exits": sum(1 for r in rows if bval(r.get("tp_exit"))),
        "time_exits": sum(1 for r in rows if bval(r.get("time_exit"))),
        "avg_base_pattern_score": sum(fnum(r.get("base_pattern_score")) for r in rows) / count if count else 0.0,
        "avg_final_score": sum(fnum(r.get("final_score") or r.get("score")) for r in rows) / count if count else 0.0,
        "avg_target_room_score": sum(fnum(r.get("target_room_score")) for r in rows) / count if count else 0.0,
        "avg_retest_score": sum(fnum(r.get("retest_score")) for r in rows) / count if count else 0.0,
        "avg_fib_score": sum(fnum(r.get("fib_score")) for r in rows) / count if count else 0.0,
        "avg_primary_best_score": sum(fnum(r.get("primary_best_score")) for r in rows) / count if count else 0.0,
        "avg_secondary_best_score": sum(fnum(r.get("secondary_best_score")) for r in rows) / count if count else 0.0,
    }


def r_metrics(rows):
    rows = list(rows)
    rvals = sorted(fnum(r.get("result_r")) for r in rows)
    count = len(rvals)
    if not count:
        return {
            "r_count": 0,
            "r_min": 0.0,
            "r_p10": 0.0,
            "r_p25": 0.0,
            "r_median": 0.0,
            "r_p75": 0.0,
            "r_p90": 0.0,
            "r_max": 0.0,
        }

    def quantile(p):
        idx = int(round((count - 1) * p))
        return rvals[max(0, min(count - 1, idx))]

    return {
        "r_count": count,
        "r_min": rvals[0],
        "r_p10": quantile(0.10),
        "r_p25": quantile(0.25),
        "r_median": quantile(0.50),
        "r_p75": quantile(0.75),
        "r_p90": quantile(0.90),
        "r_max": rvals[-1],
    }


def group_stats(rows, keys):
    groups = defaultdict(list)
    for row in rows:
        groups[tuple(row.get(key, "") for key in keys)].append(row)
    out = []
    for key_values, values in sorted(groups.items()):
        row = {key: value for key, value in zip(keys, key_values)}
        row.update(stats(values))
        out.append(row)
    return out


def concentration_ok(rows, key):
    if not rows:
        return False
    positive_net = sum(max(0.0, fnum(row.get("net_profit"))) for row in rows)
    if positive_net <= 0:
        return False
    groups = defaultdict(float)
    for row in rows:
        groups[row.get(key, "")] += max(0.0, fnum(row.get("net_profit")))
    return max(groups.values()) / positive_net <= 0.70


def directional_ok(rows):
    long_rows = [row for row in rows if row.get("direction") == "LONG"]
    short_rows = [row for row in rows if row.get("direction") == "SHORT"]
    if not long_rows or not short_rows:
        return False
    return stats(long_rows)["avg_r"] >= -0.20 and stats(short_rows)["avg_r"] >= -0.20


def gate_scope(run):
    return run["scenario_id"] in {"all_symbols_first120", "one_symbol_first120", "clean_target_path_first120"}


def run_folder(run):
    return COMMON_FILES / f"fx_session_reversal_timeframes_{run['run_id']}_2025"


def csv_names(run):
    folder = run_folder(run)
    scenario_name = run["scenario_name"]
    return {
        "signals": folder / f"fxsessionrev_{scenario_name}_signals.csv",
        "trades": folder / f"fxsessionrev_{scenario_name}_trades.csv",
        "summary": folder / f"fxsessionrev_{scenario_name}_summary.csv",
    }


def copy_artifacts(run):
    run_dir = OUT / run["run_id"]
    run_dir.mkdir(parents=True, exist_ok=True)
    for source in [
        REPO / "reports" / "backtest" / f"{EA_NAME}_{run['run_id']}_2025.ini",
        REPO / "reports" / "presets" / f"{EA_NAME}_{run['run_id']}_2025.set",
    ]:
        if source.exists():
            shutil.copy2(source, run_dir / ("tester.ini" if source.suffix == ".ini" else "preset.set"))
    for report in (REPO / "reports" / "backtest").glob(f"{EA_NAME}_{run['run_id']}_2025_report*"):
        short_name = report.name.replace(f"{EA_NAME}_{run['run_id']}_2025_", "")
        shutil.copy2(report, run_dir / short_name)
    paths = csv_names(run)
    for label in ["trades", "summary"]:
        if paths[label].exists():
            shutil.copy2(paths[label], run_dir / f"{label}.csv")


def report_exists(run):
    return any((REPO / "reports" / "backtest").glob(f"{EA_NAME}_{run['run_id']}_2025_report.html"))


def best_row(rows, where=lambda r: True, key=lambda r: fnum(r.get("avg_r"))):
    candidates = [row for row in rows if where(row)]
    return max(candidates, key=key) if candidates else None


def row_desc(row):
    if not row:
        return "none"
    if row.get("run_status") and row.get("run_status") != "completed":
        return f"`{row['run_id']}` not completed"
    return (
        f"`{row['run_id']}` trades={int(fnum(row.get('trades')))} "
        f"PF={fnum(row.get('profit_factor')):.2f} avg_R={fnum(row.get('avg_r')):.4f} "
        f"net={fnum(row.get('net_profit')):.2f} MaxDD={fnum(row.get('max_dd_profit')):.2f}"
    )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    matrix = read_csv(MATRIX)
    write_csv(OUT / "run_matrix.csv", matrix)

    all_trades = []
    comparison = []

    for run in matrix:
        paths = csv_names(run)
        copy_artifacts(run)
        trades = read_csv(paths["trades"], encoding="mbcs")
        signals = read_csv(paths["signals"], encoding="mbcs")
        summary_rows = read_csv(paths["summary"], encoding="mbcs")
        has_report = report_exists(run)
        has_trade_file = paths["trades"].exists()
        has_summary_file = paths["summary"].exists()
        run_status = "completed" if has_report and has_summary_file else "missing_or_failed"

        for row in trades:
            row.update(run)
            row["year"] = year_key(row.get("entry_time"))
            row["month"] = month_key(row.get("entry_time"))
            row["target_room_bucket"] = target_room_bucket(row)
            row["retest_score_bucket"] = retest_bucket(row)
            all_trades.append(row)

        s = stats(trades)
        rm = r_metrics(trades)
        summary_last = summary_rows[-1] if summary_rows else {}
        dd_stopped = bval(summary_last.get("drawdown_stopped")) or bval(summary_last.get("daily_stopped"))
        passed = (
            gate_scope(run)
            and s["trades"] >= 200
            and s["profit_factor"] >= 1.05
            and s["avg_r"] > 0
            and s["net_profit"] > 0
            and not dd_stopped
            and directional_ok(trades)
            and concentration_ok(trades, "symbol")
            and concentration_ok(trades, "session_label")
        )
        comparison.append({
            **run,
            **s,
            **rm,
            "signals": len(signals),
            "run_status": run_status,
            "report_exists": has_report,
            "trades_csv_exists": has_trade_file,
            "summary_csv_exists": has_summary_file,
            "htf_permission_rejections": int(fnum(summary_last.get("htf_permission_rejections"))) if summary_last else 0,
            "preselection_rejections": int(fnum(summary_last.get("preselection_rejections"))) if summary_last else 0,
            "daily_or_dd_stopped": dd_stopped,
            "gate_scope": gate_scope(run),
            "passed_2025_shallow_gate": passed,
        })

    write_csv(OUT / "comparison.csv", comparison)
    write_csv(OUT / "trades_all_scenarios.csv", all_trades)
    write_csv(OUT / "timeframe_config_breakdown.csv", group_stats(all_trades, ["scenario_id", "timeframe_config_id", "break_even_mode"]))
    write_csv(OUT / "session_breakdown.csv", group_stats(all_trades, ["timeframe_config_id", "break_even_mode", "session_label"]))
    write_csv(OUT / "symbol_breakdown.csv", group_stats(all_trades, ["timeframe_config_id", "break_even_mode", "symbol"]))
    write_csv(OUT / "direction_breakdown.csv", group_stats(all_trades, ["timeframe_config_id", "break_even_mode", "direction"]))
    write_csv(OUT / "entry_pattern_breakdown.csv", group_stats(all_trades, ["timeframe_config_id", "break_even_mode", "entry_pattern"]))
    write_csv(OUT / "entry_timeframe_breakdown.csv", group_stats(all_trades, ["scenario_id", "timeframe_config_id", "break_even_mode", "selected_candidate_timeframe"]))
    write_csv(OUT / "fib_zone_breakdown.csv", group_stats(all_trades, ["scenario_id", "timeframe_config_id", "break_even_mode", "fib_zone"]))
    write_csv(OUT / "retest_reference_breakdown.csv", group_stats(all_trades, ["scenario_id", "timeframe_config_id", "break_even_mode", "retest_reference_type", "retest_score_bucket"]))
    write_csv(OUT / "target_room_breakdown.csv", group_stats(all_trades, ["scenario_id", "timeframe_config_id", "break_even_mode", "target_room_bucket", "nearest_obstacle_type"]))
    write_csv(OUT / "monthly_breakdown.csv", group_stats(all_trades, ["run_id", "month"]))
    write_csv(OUT / "yearly_breakdown.csv", group_stats(all_trades, ["run_id", "year"]))
    write_csv(OUT / "r_metrics.csv", [
        {**{key: row[key] for key in ["run_id", "scenario_id", "timeframe_config_id", "break_even_id"]}, **r_metrics([
            trade for trade in all_trades if trade.get("run_id") == row["run_id"]
        ])}
        for row in matrix
    ])

    compile_log = REPO / "reports" / "compile" / f"{EA_NAME}_timeframe_matrix_compile.log"
    if compile_log.exists():
        shutil.copy2(compile_log, OUT / "compile.log")

    london_current = best_row(comparison, lambda r: r["scenario_id"] == "london_first120_reference" and r["timeframe_config_id"] == "current_default" and r["break_even_id"] == "no_be")
    london_h1 = best_row(comparison, lambda r: r["scenario_id"] == "london_first120_reference" and r["timeframe_config_id"].startswith("h1_m15_m5"))
    best_current = best_row(comparison, lambda r: r["timeframe_config_id"] == "current_default", lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor"))))
    best_h1 = best_row(comparison, lambda r: r["timeframe_config_id"].startswith("h1_m15_m5"), lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor")), fnum(r.get("trades"))))
    best_m5 = best_row(comparison, lambda r: r["primary_entry_tf"] == "PERIOD_M5", lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor")), fnum(r.get("trades"))))
    dual = best_row(comparison, lambda r: r["timeframe_config_id"] == "h1_m15_m5_dual_entry", lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor"))))
    fib_score = best_row(comparison, lambda r: r["timeframe_config_id"] == "h1_m15_m5_with_fib_score", lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor")), fnum(r.get("trades"))))
    fib_required = best_row(comparison, lambda r: r["timeframe_config_id"] == "h1_m15_m5_with_fib_required", lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor")), fnum(r.get("trades"))))
    best_non_london = best_row(comparison, lambda r: r["scenario_id"] != "london_first120_reference", lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor")), fnum(r.get("trades"))))
    best_newyork = best_row(comparison, lambda r: r["scenario_id"] == "newyork_first120_reference", lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor")), fnum(r.get("trades"))))
    passed = [row for row in comparison if bval(row.get("passed_2025_shallow_gate"))]
    completed_runs = [row for row in comparison if row.get("run_status") == "completed"]
    missing_runs = [row for row in comparison if row.get("run_status") != "completed"]

    lines = [
        "# Session Reversal Pullback Fractal Timeframe Matrix",
        "",
        "## Implementation",
        "- Timeframes are input-parameterized as `InpTopContextTF`, `InpStructureTF`, `InpPrimaryEntryTF`, and `InpSecondaryEntryTF`.",
        "- The default H4/H1/M15/M5 structure is reproduced through inputs, while H1/M15/M5 variants use M5 as the main trigger.",
        "- Primary and secondary entry candidates are both scored when secondary is enabled; the highest score is selected.",
        "- First-60 time score is removed; time is retained as gate and diagnostic bucket only.",
        "- Fib pullback is coarse diagnostic/scoring only, with no fine threshold optimization.",
        "",
        "## Required Answers",
        f"0. Matrix completion: {len(completed_runs)} / {len(comparison)} runs completed. Missing rows are marked `missing_or_failed` in `comparison.csv`; the MT5 terminal stopped progressing after broker authorization/synchronization failures, so incomplete rows are not interpreted as strategy evidence.",
        f"1. London first120 count over 26: current default no_BE was {row_desc(london_current)}; best H1/M15/M5 London row was {row_desc(london_h1)}.",
        f"2. PF / avg_R with trade count increase: compare the London rows above; low-count London remains diagnostic-only below 200 trades.",
        f"3. Better than current_default: best current_default row was {row_desc(best_current)}; best H1/M15/M5 row was {row_desc(best_h1)}.",
        f"4. M5 trigger: best primary M5 row was {row_desc(best_m5)}; entry timeframe details are in `entry_timeframe_breakdown.csv`.",
        f"5. M15 as structure confirmation: best dual-entry row was {row_desc(dual)}.",
        f"6. Fib score: best fib-score row was {row_desc(fib_score)}; fib zone details are in `fib_zone_breakdown.csv`.",
        f"7. Fib required: best fib-required row was {row_desc(fib_required)}. If trades remain below 200 it is not promotable.",
        f"8. Outside London: best non-London row was {row_desc(best_non_london)}.",
        f"9. NewYork: best NewYork row was {row_desc(best_newyork)}.",
        f"10. 2025 shallow gate: {', '.join(row['run_id'] for row in passed) if passed else 'no candidate passed'}.",
        "11. 3-year fixed BT / OOS: advance only 2025 gate-pass candidates; no 3-year/OOS run is created when the 2025 gate has no pass.",
        "",
        "## Evidence",
        "- `comparison.csv`",
        "- `timeframe_config_breakdown.csv`",
        "- `session_breakdown.csv`",
        "- `symbol_breakdown.csv`",
        "- `direction_breakdown.csv`",
        "- `entry_pattern_breakdown.csv`",
        "- `entry_timeframe_breakdown.csv`",
        "- `fib_zone_breakdown.csv`",
        "- `retest_reference_breakdown.csv`",
        "- `target_room_breakdown.csv`",
        "- `monthly_breakdown.csv`",
        "- `yearly_breakdown.csv`",
        "- `r_metrics.csv`",
        "- `run_matrix.csv`",
    ]
    if missing_runs:
        lines.extend([
            "",
            "## Incomplete MT5 Runs",
            "The following run IDs did not produce a fresh MT5 report and are excluded from promotion decisions:",
            "",
            ", ".join(row["run_id"] for row in missing_runs),
        ])
    (OUT / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
