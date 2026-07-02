import csv
import math
import shutil
from collections import defaultdict
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
COMMON_FILES = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"
OUT = REPO / "reports" / "backtest" / "runs" / "20260702_session_reversal_nested_thirdwave_launch"
MATRIX = OUT / "run_matrix.csv"
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
        for row in rows:
            writer.writerow(row)


def stats(rows):
    rows = list(rows)
    profits = [fnum(r.get("net_profit")) for r in rows]
    rvals = [fnum(r.get("result_r")) for r in rows]
    count = len(rows)
    wins = sum(1 for v in profits if v > 0)
    gross_profit = sum(v for v in profits if v > 0)
    gross_loss = sum(v for v in profits if v < 0)
    net = sum(profits)
    win_r = sum(v for v in rvals if v > 0)
    loss_r = sum(v for v in rvals if v < 0)
    equity = 0.0
    peak = 0.0
    max_dd = 0.0
    for value in profits:
        equity += value
        peak = max(peak, equity)
        max_dd = min(max_dd, equity - peak)
    full_sl = sum(1 for r in rows if bval(r.get("full_sl_exit")))
    tp_exit = sum(1 for r in rows if bval(r.get("tp_exit")))
    time_exit = sum(1 for r in rows if bval(r.get("time_exit")))
    mfes = [fnum(r.get("max_favorable_r_before_exit")) for r in rows]
    maes = [fnum(r.get("max_adverse_r_before_exit")) for r in rows]
    failure_exit = sum(1 for r in rows if "primary_failure_exit" in str(r.get("exit_reason", "")))
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
        "full_sl_exits": full_sl,
        "full_sl_rate": full_sl / count if count else 0.0,
        "tp_exits": tp_exit,
        "tp_exit_rate": tp_exit / count if count else 0.0,
        "time_exits": time_exit,
        "time_exit_rate": time_exit / count if count else 0.0,
        "failure_exits": failure_exit,
        "failure_exit_rate": failure_exit / count if count else 0.0,
        "avg_mfe_r": sum(mfes) / count if count else 0.0,
        "avg_mae_r": sum(maes) / count if count else 0.0,
    }


def group_stats(rows, keys):
    grouped = defaultdict(list)
    for row in rows:
        grouped[tuple(row.get(k, "") for k in keys)].append(row)
    out = []
    for key_values, values in sorted(grouped.items()):
        row = {key: value for key, value in zip(keys, key_values)}
        row.update(stats(values))
        out.append(row)
    return out


def month_key(value):
    text = str(value)
    if len(text) >= 7:
        return text[:7].replace(".", "-")
    return ""


def year_key(value):
    text = str(value)
    return text[:4] if len(text) >= 4 else ""


def concentration_ok(rows, key):
    positives = defaultdict(float)
    total = 0.0
    for row in rows:
        value = max(0.0, fnum(row.get("net_profit")))
        if value <= 0.0:
            continue
        positives[row.get(key, "")] += value
        total += value
    if total <= 0.0 or not positives:
        return False
    return max(positives.values()) / total <= 0.70


def directional_ok(rows):
    long_rows = [r for r in rows if r.get("direction") == "LONG"]
    short_rows = [r for r in rows if r.get("direction") == "SHORT"]
    if not long_rows or not short_rows:
        return False
    return stats(long_rows)["avg_r"] >= -0.20 and stats(short_rows)["avg_r"] >= -0.20


def copy_artifacts(run):
    run_id = run["run_id"]
    run_dir = OUT / run_id
    run_dir.mkdir(parents=True, exist_ok=True)
    for source in [REPO / run["tester_ini"], REPO / run["preset"]]:
        if source.exists():
            shutil.copy2(source, run_dir / ("tester.ini" if source.suffix == ".ini" else "preset.set"))
    for report in (REPO / "reports" / "backtest").glob(f"{EA_NAME}_{run_id}_report*"):
        short_name = report.name.replace(f"{EA_NAME}_{run_id}_", "")
        shutil.copy2(report, run_dir / short_name)


def csv_paths(run):
    folder = COMMON_FILES / run["log_folder"]
    scenario = run["scenario_name"]
    return {
        "signals": folder / f"fxsessionrev_{scenario}_signals.csv",
        "trades": folder / f"fxsessionrev_{scenario}_trades.csv",
        "summary": folder / f"fxsessionrev_{scenario}_summary.csv",
    }


def pass_gate(rows, run_stats, stopped):
    return (
        run_stats["trades"] >= 200
        and run_stats["profit_factor"] >= 1.05
        and run_stats["avg_r"] > 0.0
        and run_stats["net_profit"] > 0.0
        and not stopped
        and directional_ok(rows)
        and concentration_ok(rows, "symbol")
        and concentration_ok(rows, "session_label")
    )


def best_full(rows):
    candidates = [r for r in rows if r.get("period_id") == "full2025_validation" and fnum(r.get("trades")) > 0]
    if not candidates:
        return None
    return max(candidates, key=lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor")), fnum(r.get("trades"))))


def write_breakdowns(all_trades):
    write_csv(OUT / "nested_thirdwave_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "nested_thirdwave_mode", "nested_thirdwave_enabled"]))
    write_csv(OUT / "m15_wave_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "m15_wave1_candidate", "m15_wave2_candidate"]))
    write_csv(OUT / "m5_corrective_invalidation_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "m5_corrective_wave_detected", "m5_corrective_123_detected", "m5_corrective_invalidation"]))
    write_csv(OUT / "post_break_acceptance_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "post_break_acceptance_pass"]))
    write_csv(OUT / "context_fib_room_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "h1_context_fib_room_bucket"]))
    write_csv(OUT / "m15_wave2_fib_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "m15_wave2_fib_zone"]))
    write_csv(OUT / "sma75_granville_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "sma75_reclaim", "sma75_state"]))
    write_csv(OUT / "entry_pattern_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "entry_pattern", "entry_trigger"]))
    write_csv(OUT / "entry_timeframe_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "selected_candidate_timeframe"]))
    write_csv(OUT / "session_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "scenario_key", "session_label"]))
    write_csv(OUT / "symbol_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "symbol"]))
    write_csv(OUT / "direction_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "direction"]))
    write_csv(OUT / "exit_type_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "exit_type"]))
    write_csv(OUT / "mfe_mae_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "exit_type", "tp_exit", "time_exit", "full_sl_exit"]))
    write_csv(OUT / "monthly_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "month"]))
    write_csv(OUT / "yearly_breakdown.csv", group_stats(all_trades, ["period_id", "variant", "year"]))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    matrix = read_csv(MATRIX)
    all_trades = []
    comparison = []

    for run in matrix:
        paths = csv_paths(run)
        copy_artifacts(run)
        run_dir = OUT / run["run_id"]
        for label, path in paths.items():
            if label == "signals":
                continue
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
        stopped = False
        if summary:
            stopped = bval(summary[-1].get("daily_stopped")) or bval(summary[-1].get("drawdown_stopped"))
        comparison.append({
            **run,
            **run_stats,
            "daily_or_dd_stopped": stopped,
            "passed_2025_gate": pass_gate(trades, run_stats, stopped) if run["period_id"] == "full2025_validation" else False,
        })

    write_csv(OUT / "comparison.csv", comparison)
    write_csv(OUT / "full2025_comparison.csv", [r for r in comparison if r["period_id"] == "full2025_validation"])
    write_csv(OUT / "q1_comparison.csv", [r for r in comparison if r["period_id"] == "q1_quick"])
    write_csv(OUT / "trades_all_scenarios.csv", all_trades)
    write_breakdowns(all_trades)

    best = best_full(comparison)
    baseline = [r for r in comparison if r.get("period_id") == "full2025_validation" and r.get("variant") == "base" and r.get("scenario_key") == "all"]
    baseline_row = baseline[0] if baseline else None
    passed = [r for r in comparison if bval(r.get("passed_2025_gate"))]

    lines = [
        "# Nested Third-Wave Launch Validation",
        "",
        "## Scope",
        "- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`",
        "- Concept: H1 context, M15 wave1/wave2 diagnostics, M5 corrective 123 invalidation, post-break first retest, M5 failure exit.",
        "- Timeframes: tester period M15; EA inputs use `InpTopContextTF=PERIOD_H1(16385)`, `InpStructureTF=PERIOD_M15(15)`, `InpPrimaryEntryTF=PERIOD_M5(5)`.",
        "",
        "## Baseline",
    ]
    if baseline_row:
        lines.append(
            f"- baseline_c10 all_symbols_first120: trades={baseline_row['trades']}, PF={baseline_row['profit_factor']:.2f}, "
            f"avg_R={baseline_row['avg_r']:.4f}, net={baseline_row['net_profit']:.2f}, "
            f"time_exit={baseline_row['time_exit_rate']:.1%}, fullSL={baseline_row['full_sl_rate']:.1%}, avg_MFE={baseline_row['avg_mfe_r']:.3f}R."
        )
    else:
        lines.append("- baseline_c10 all_symbols_first120 was not available in copied results.")

    lines.extend(["", "## Best 2025 Row"])
    if best:
        lines.append(
            f"- `{best['run_id']}`: trades={best['trades']}, PF={best['profit_factor']:.2f}, "
            f"avg_R={best['avg_r']:.4f}, net={best['net_profit']:.2f}, MaxDD={best['max_dd_profit']:.2f}, "
            f"time_exit={best['time_exit_rate']:.1%}, fullSL={best['full_sl_rate']:.1%}, avg_MFE={best['avg_mfe_r']:.3f}R."
        )
    else:
        lines.append("- No full-year row produced trades.")

    lines.extend([
        "",
        "## Required Findings",
        f"1. c10 baseline improvement: {'robust improvement confirmed' if best and baseline_row and fnum(best['trades']) >= 200 and fnum(best['avg_r']) > fnum(baseline_row['avg_r']) and fnum(best['profit_factor']) >= 1.05 else 'no robust improvement confirmed; positive low-count session rows are research fragments only'}.",
        "2. nested third-wave diagnostic separation: see `nested_thirdwave_breakdown.csv`, `m15_wave_breakdown.csv`, and `m5_corrective_invalidation_breakdown.csv`.",
        "3. M5 corrective invalidation: compare true/false buckets in `m5_corrective_invalidation_breakdown.csv`.",
        "4. M15 wave2 detection: compare `m15_wave_breakdown.csv`; low trade count means it is too strict.",
        "5. post-break acceptance: compare `post_break_acceptance_breakdown.csv`.",
        "6. H1 context fib room: compare `context_fib_room_breakdown.csv`.",
        "7. M15 wave2 fib zone: compare `m15_wave2_fib_breakdown.csv`.",
        "8. 75SMA / Granville: compare `sma75_granville_breakdown.csv`.",
        "9. M5 failure exit remains enabled in baseline/nested rows unless explicitly changed; exit effects are in `exit_type_breakdown.csv`.",
        "10. time exit problem: inspect `time_exit_rate` in `comparison.csv` and `mfe_mae_breakdown.csv`.",
        "11. MFE: use `avg_mfe_r` in comparison and `mfe_mae_breakdown.csv`.",
        "12. TP distance vs entry quality: if avg_MFE is below target R and time exits dominate, entry quality is still weak.",
        "13. London dependency: `session_breakdown.csv` and scenario rows prevent promotion from London-only evidence.",
        f"14. 2025 gate pass candidates: {', '.join(r['run_id'] for r in passed) if passed else 'none'}.",
        "15. 3-year/OOS: only consider if a 2025 gate pass exists.",
        "",
        "## Artifacts",
        "- `comparison.csv`",
        "- `full2025_comparison.csv`",
        "- `nested_thirdwave_breakdown.csv`",
        "- `m15_wave_breakdown.csv`",
        "- `m5_corrective_invalidation_breakdown.csv`",
        "- `post_break_acceptance_breakdown.csv`",
        "- `context_fib_room_breakdown.csv`",
        "- `m15_wave2_fib_breakdown.csv`",
        "- `sma75_granville_breakdown.csv`",
    ])
    (OUT / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
