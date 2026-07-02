import csv
import math
import shutil
from collections import defaultdict
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
COMMON_FILES = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"
OUT = REPO / "reports" / "backtest" / "runs" / "20260702_session_reversal_refined_m5_abc_session_gate"
MATRIX = OUT / "run_matrix.csv"
DEPOSIT = 10000.0


def fnum(value):
    if value in (None, ""):
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


def stats(rows):
    rows = list(rows)
    profits = [fnum(r.get("net_profit")) for r in rows]
    rvals = [fnum(r.get("result_r")) for r in rows]
    mfes = [fnum(r.get("max_favorable_r_before_exit")) for r in rows]
    maes = [fnum(r.get("max_adverse_r_before_exit")) for r in rows]
    count = len(rows)
    gross_profit = sum(v for v in profits if v > 0)
    gross_loss = sum(v for v in profits if v < 0)
    win_r = sum(v for v in rvals if v > 0)
    loss_r = sum(v for v in rvals if v < 0)
    equity = peak = max_dd = 0.0
    for value in profits:
        equity += value
        peak = max(peak, equity)
        max_dd = min(max_dd, equity - peak)
    return {
        "trades": count,
        "wins": sum(1 for v in profits if v > 0),
        "win_rate": sum(1 for v in profits if v > 0) / count if count else 0.0,
        "net_profit": sum(profits),
        "gross_profit": gross_profit,
        "gross_loss": gross_loss,
        "profit_factor": gross_profit / abs(gross_loss) if gross_loss < 0 else (math.inf if gross_profit > 0 else 0.0),
        "sum_r": sum(rvals),
        "avg_r": sum(rvals) / count if count else 0.0,
        "r_profit_factor": win_r / abs(loss_r) if loss_r < 0 else (math.inf if win_r > 0 else 0.0),
        "max_dd_profit": abs(max_dd),
        "max_dd_pct": abs(max_dd) / DEPOSIT * 100.0,
        "recovery_factor": sum(profits) / abs(max_dd) if max_dd < 0 else (math.inf if sum(profits) > 0 else 0.0),
        "full_sl_exits": sum(1 for r in rows if bval(r.get("full_sl_exit"))),
        "full_sl_rate": sum(1 for r in rows if bval(r.get("full_sl_exit"))) / count if count else 0.0,
        "tp_exits": sum(1 for r in rows if bval(r.get("tp_exit"))),
        "tp_exit_rate": sum(1 for r in rows if bval(r.get("tp_exit"))) / count if count else 0.0,
        "time_exits": sum(1 for r in rows if bval(r.get("time_exit"))),
        "time_exit_rate": sum(1 for r in rows if bval(r.get("time_exit"))) / count if count else 0.0,
        "structure_target_exits": sum(1 for r in rows if bval(r.get("structure_target_exit"))),
        "avg_mfe_r": sum(mfes) / count if count else 0.0,
        "avg_mae_r": sum(maes) / count if count else 0.0,
        "reached_0_5r_rate": sum(1 for r in rows if bval(r.get("reached_0_5r"))) / count if count else 0.0,
        "reached_0_8r_rate": sum(1 for r in rows if bval(r.get("reached_0_8r"))) / count if count else 0.0,
        "reached_1_0r_rate": sum(1 for r in rows if bval(r.get("reached_1_0r"))) / count if count else 0.0,
        "reached_1_3r_rate": sum(1 for r in rows if bval(r.get("reached_1_3r"))) / count if count else 0.0,
        "reached_1_5r_rate": sum(1 for r in rows if bval(r.get("reached_1_5r"))) / count if count else 0.0,
    }


def group_stats(rows, keys):
    groups = defaultdict(list)
    for row in rows:
        groups[tuple(row.get(k, "") for k in keys)].append(row)
    out = []
    for values, subset in sorted(groups.items()):
        row = {key: value for key, value in zip(keys, values)}
        row.update(stats(subset))
        out.append(row)
    return out


def month_key(value):
    text = str(value)
    return text[:7].replace(".", "-") if len(text) >= 7 else ""


def year_key(value):
    text = str(value)
    return text[:4] if len(text) >= 4 else ""


def concentration_ok(rows, key):
    positives = defaultdict(float)
    total = 0.0
    for row in rows:
        value = max(0.0, fnum(row.get("net_profit")))
        if value <= 0:
            continue
        positives[row.get(key, "")] += value
        total += value
    return bool(total > 0 and positives and max(positives.values()) / total <= 0.70)


def directional_ok(rows):
    longs = [r for r in rows if r.get("direction") == "LONG"]
    shorts = [r for r in rows if r.get("direction") == "SHORT"]
    return bool(longs and shorts and stats(longs)["avg_r"] >= -0.20 and stats(shorts)["avg_r"] >= -0.20)


def pass_gate(rows, run_stats, stopped):
    return (
        run_stats["trades"] >= 200
        and run_stats["profit_factor"] >= 1.05
        and run_stats["avg_r"] > 0
        and run_stats["net_profit"] > 0
        and not stopped
        and directional_ok(rows)
        and concentration_ok(rows, "symbol")
        and concentration_ok(rows, "session_label")
    )


def copy_artifacts(run):
    run_dir = OUT / run["run_id"]
    run_dir.mkdir(parents=True, exist_ok=True)
    for key, name in [("tester_ini", "tester.ini"), ("preset", "preset.set")]:
        source = REPO / run[key]
        if source.exists():
            shutil.copy2(source, run_dir / name)
    for report in (REPO / "reports" / "backtest").glob(f"{EA_NAME}_{run['run_id']}_report*"):
        shutil.copy2(report, run_dir / report.name.replace(f"{EA_NAME}_{run['run_id']}_", ""))


def csv_paths(run):
    folder = COMMON_FILES / run["log_folder"]
    scenario = run["scenario_name"]
    return {
        "trades": folder / f"fxsessionrev_{scenario}_trades.csv",
        "summary": folder / f"fxsessionrev_{scenario}_summary.csv",
    }


def write_breakdowns(all_trades):
    breakdowns = {
        "session_gate_breakdown.csv": ["period_id", "scenario_key", "variant", "session_gate_mode", "entry_after_first120", "structure_started_in_first120"],
        "m15_wave_breakdown.csv": ["period_id", "scenario_key", "variant", "m15_wave_context_mode", "m15_wave1_candidate", "m15_wave2_candidate", "m15_wave2_fib_zone"],
        "m5_corrective_abc_breakdown.csv": ["period_id", "scenario_key", "variant", "m5_corrective_abc_detected", "m5_corrective_leg_count"],
        "m5_invalidation_breakdown.csv": ["period_id", "scenario_key", "variant", "m5_invalidation_detected", "m5_invalidation_close_break"],
        "post_break_acceptance_breakdown.csv": ["period_id", "scenario_key", "variant", "post_break_acceptance_pass", "first_retest_after_invalidation"],
        "mfe_threshold_breakdown.csv": ["period_id", "scenario_key", "variant", "reached_1_0r", "reached_1_3r"],
        "mfe_by_nested_state.csv": ["period_id", "scenario_key", "variant", "nested_thirdwave_mode", "nested_thirdwave_enabled"],
        "mfe_by_m5_corrective_state.csv": ["period_id", "scenario_key", "variant", "m5_corrective_abc_detected", "m5_invalidation_detected"],
        "mfe_by_post_break_acceptance.csv": ["period_id", "scenario_key", "variant", "post_break_acceptance_pass", "first_retest_after_invalidation"],
        "mfe_by_session_gate_mode.csv": ["period_id", "scenario_key", "variant", "session_gate_mode"],
        "mfe_by_entry_pattern.csv": ["period_id", "scenario_key", "variant", "entry_pattern", "entry_trigger"],
        "mfe_by_time_bucket.csv": ["period_id", "scenario_key", "variant", "time_bucket"],
        "exit_type_breakdown.csv": ["period_id", "scenario_key", "variant", "exit_type", "exit_mode"],
        "entry_pattern_breakdown.csv": ["period_id", "scenario_key", "variant", "entry_pattern", "entry_trigger"],
        "session_breakdown.csv": ["period_id", "variant", "scenario_key", "session_label"],
        "symbol_breakdown.csv": ["period_id", "variant", "symbol"],
        "direction_breakdown.csv": ["period_id", "variant", "direction"],
        "monthly_breakdown.csv": ["period_id", "variant", "month"],
        "yearly_breakdown.csv": ["period_id", "variant", "year"],
    }
    for filename, keys in breakdowns.items():
        write_csv(OUT / filename, group_stats(all_trades, keys))


def fmt(row):
    return (
        f"trades={row['trades']}, PF={row['profit_factor']:.2f}, avg_R={row['avg_r']:.4f}, "
        f"net={row['net_profit']:.2f}, time_exit={row['time_exit_rate']:.1%}, "
        f"fullSL={row['full_sl_rate']:.1%}, MFE1R={row['reached_1_0r_rate']:.1%}, "
        f"MFE1.3R={row['reached_1_3r_rate']:.1%}, avg_MFE={row['avg_mfe_r']:.3f}R"
    )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    matrix = read_csv(MATRIX)
    all_trades = []
    comparison = []
    for run in matrix:
        copy_artifacts(run)
        run_dir = OUT / run["run_id"]
        paths = csv_paths(run)
        for label, path in paths.items():
            if path.exists():
                shutil.copy2(path, run_dir / f"{label}.csv")
        trades = read_csv(paths["trades"], encoding="mbcs")
        summary = read_csv(paths["summary"], encoding="mbcs")
        for row in trades:
            row.update(run)
            row["year"] = year_key(row.get("entry_time"))
            row["month"] = month_key(row.get("entry_time"))
            all_trades.append(row)
        run_stats = stats(trades)
        stopped = bool(summary and (bval(summary[-1].get("daily_stopped")) or bval(summary[-1].get("drawdown_stopped"))))
        comparison.append({**run, **run_stats, "daily_or_dd_stopped": stopped, "passed_2025_gate": pass_gate(trades, run_stats, stopped) if run["period_id"] == "full2025_validation" else False})

    write_csv(OUT / "comparison.csv", comparison)
    write_csv(OUT / "q1_comparison.csv", [r for r in comparison if r["period_id"] == "q1_quick"])
    write_csv(OUT / "full2025_comparison.csv", [r for r in comparison if r["period_id"] == "full2025_validation"])
    write_csv(OUT / "trades_all_scenarios.csv", all_trades)
    write_breakdowns(all_trades)

    full_rows = [r for r in comparison if r["period_id"] == "full2025_validation" and r["trades"] > 0]
    baseline = next((r for r in full_rows if r["run_id"] == "full2025_all_base"), None)
    all_symbol = [r for r in full_rows if r["scenario_key"] == "all"]
    best_all = max(all_symbol, key=lambda r: (r["avg_r"], r["profit_factor"], r["trades"]), default=None)
    passed = [r for r in full_rows if bval(r.get("passed_2025_gate"))]
    lines = [
        "# Refined M5 ABC Invalidation And Session Gate Diagnostics",
        "",
        "## Scope",
        "- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`",
        "- Change: refined M15 wave2 context, M5 corrective ABC/123, close-break invalidation, acceptance/retest diagnostics, session gate modes, and MFE threshold tracking.",
        "- Timeframes: tester M15; EA inputs use H1=`16385`, M15=`15`, M5=`5`; trade rows verify `selected_candidate_timeframe=PERIOD_M5` when trades exist.",
        "",
        "## 2025 All-Symbols Baseline",
        f"- {fmt(baseline)}" if baseline else "- Baseline row missing.",
        "",
        "## 2025 Best All-Symbols Row",
        f"- `{best_all['run_id']}` {fmt(best_all)}" if best_all else "- No all-symbol full-year row produced trades.",
        "",
        "## Required Findings",
        f"1. baseline c10 improvement: {'yes' if best_all and baseline and best_all['trades'] >= 200 and best_all['profit_factor'] >= 1.05 and best_all['avg_r'] > baseline['avg_r'] else 'no robust improvement'}",
        "2. session gate effect: compare `session_gate_breakdown.csv` and no-session rows in `full2025_comparison.csv`.",
        "3. first120 timing distortion: use `entry_after_first120` and `structure_started_in_first120` in `session_gate_breakdown.csv`.",
        "4. M5 ABC/123 separation: see `m5_corrective_abc_breakdown.csv`.",
        "5. M5 invalidation close break: see `m5_invalidation_breakdown.csv`.",
        "6. post-break acceptance and first retest: see `post_break_acceptance_breakdown.csv`.",
        "7. M15 wave2 context: see `m15_wave_breakdown.csv`.",
        "8. MFE 1R/1.3R separation: see `mfe_threshold_breakdown.csv` and MFE breakdown files.",
        "9. time exit problem: compare `time_exit_rate` in `comparison.csv`.",
        "10. full SL vs TP/MFE: compare `full_sl_rate`, `tp_exit_rate`, `avg_mfe_r`, and reached-R rates.",
        "11. small session fragments: Tokyo/London/Clean remain research-only if below 200 trades.",
        f"12. 2025 gate pass candidates: {', '.join(r['run_id'] for r in passed) if passed else 'none'}.",
        "13. 3-year/OOS: not run unless a 2025 gate pass exists.",
        "",
        "## Decision",
        "No live/operating decision should be made without a 2025 gate pass.",
    ]
    (OUT / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
