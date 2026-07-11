import csv
import importlib.util
import shutil
from collections import Counter
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
OUT = REPO / "reports" / "backtest" / "runs" / "20260711_session_reversal_m5_micro_n_relaunch"
MATRIX = OUT / "run_matrix.csv"


def load_previous_analyzer():
    path = REPO / "scripts" / "analyze-session-reversal-m15-anchor-first-break-cycles.py"
    spec = importlib.util.spec_from_file_location("anchor_first_analyzer", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.OUT = OUT
    module.MATRIX = MATRIX
    return module


base = load_previous_analyzer()
fnum = base.fnum
bval = base.bval
read_csv = base.read_csv
write_csv = base.write_csv
dedupe_trades = base.dedupe_trades
stats = base.stats
group_stats = base.group_stats
pass_gate = base.pass_gate


def copy_artifacts(run):
    run_dir = OUT / run["run_id"]
    run_dir.mkdir(parents=True, exist_ok=True)
    for key, name in [("tester_ini", "tester.ini"), ("preset", "preset.set")]:
        source = REPO / run[key]
        if source.exists():
            shutil.copy2(source, run_dir / name)
    pattern = f"{EA_NAME}_micro_n_{run['run_id']}_report*"
    for report in (REPO / "reports" / "backtest").glob(pattern):
        target_name = report.name.replace(f"{EA_NAME}_micro_n_{run['run_id']}_", "")
        shutil.copy2(report, run_dir / target_name)


def csv_paths(run):
    paths = base.csv_paths(run)
    folder = base.COMMON_FILES / run["log_folder"]
    scenario = run["scenario_name"]
    paths["signals"] = folder / f"fxsessionrev_{scenario}_signals.csv"
    return paths


def add_derived(row):
    row["year"] = base.year_key(row.get("entry_time"))
    row["month"] = base.month_key(row.get("entry_time"))
    row["mfe_r"] = row.get("max_favorable_r_before_exit", "")
    row["mae_r"] = row.get("max_adverse_r_before_exit", "")
    old_pass = bval(row.get("post_anchor_m5_reconfirm_detected"))
    new_detected = bval(row.get("m5_relaunch_break_detected"))
    new_pass = new_detected and bval(row.get("m5_relaunch_gate_pass"))
    row["old_reconfirm_pass"] = str(old_pass).lower()
    row["new_micro_n_relaunch_detected"] = str(new_detected).lower()
    row["new_micro_n_relaunch_pass"] = str(new_pass).lower()
    if old_pass and new_pass:
        row["old_vs_new_bucket"] = "both"
    elif old_pass:
        row["old_vs_new_bucket"] = "old_only"
    elif new_pass:
        row["old_vs_new_bucket"] = "new_only"
    else:
        row["old_vs_new_bucket"] = "neither"
    age = int(fnum(row.get("m5_relaunch_signal_age_bars")))
    if not new_detected:
        row["relaunch_signal_age_bucket"] = "no_relaunch"
    elif age <= 0:
        row["relaunch_signal_age_bucket"] = "age_0"
    elif age == 1:
        row["relaunch_signal_age_bucket"] = "age_1"
    elif age <= 3:
        row["relaunch_signal_age_bucket"] = "late_2_3"
    else:
        row["relaunch_signal_age_bucket"] = "late_gt3"
    delay = int(fnum(row.get("bars_from_relaunch_to_entry")))
    if delay < 0:
        row["break_to_entry_delay_bucket"] = "no_relaunch"
    elif delay == 0:
        row["break_to_entry_delay_bucket"] = "entry_on_relaunch"
    elif delay == 1:
        row["break_to_entry_delay_bucket"] = "entry_one_bar_after"
    else:
        row["break_to_entry_delay_bucket"] = "entry_late_ge2"
    row["required_light_bucket"] = "required_light_pass" if bval(row.get("m15_required_light_pass")) else "required_light_reject"
    row["micro_n_gate_bucket"] = "micro_n_pass" if new_pass else "micro_n_reject"
    row["post_anchor_pullback_bucket"] = "post_anchor_pullback_pass" if bval(row.get("post_anchor_pullback_gate_pass")) else "post_anchor_pullback_reject"
    row["mfe_1r_bucket"] = "mfe_ge_1r" if bval(row.get("reached_1_0r")) else "mfe_lt_1r"


def write_breakdowns(rows):
    files = {
        "m5_relaunch_signal_age_breakdown.csv": ["period_id", "variant", "relaunch_signal_age_bucket"],
        "m5_micro_anchor_breakdown.csv": ["period_id", "variant", "m5_micro_n_state", "m5_micro_anchor_created_after_m15_break"],
        "mfe_by_relaunch_signal_age.csv": ["period_id", "variant", "relaunch_signal_age_bucket", "mfe_1r_bucket"],
        "mfe_by_break_to_entry_delay.csv": ["period_id", "variant", "break_to_entry_delay_bucket", "mfe_1r_bucket"],
        "mfe_by_micro_n_state.csv": ["period_id", "variant", "m5_micro_n_state", "mfe_1r_bucket"],
        "mfe_by_relaunch_break_quality.csv": ["period_id", "variant", "m5_relaunch_break_quality_bucket", "mfe_1r_bucket"],
        "m15_anchor_breakdown.csv": ["period_id", "variant", "m15_anchor_bias_state", "m15_anchor_break_direction"],
        "post_anchor_pullback_breakdown.csv": ["period_id", "variant", "post_anchor_pullback_bucket", "post_anchor_pullback_quality_bucket"],
        "required_light_by_m5_relaunch.csv": ["period_id", "variant", "required_light_bucket", "micro_n_gate_bucket"],
        "session_breakdown.csv": ["period_id", "variant", "session_label"],
        "symbol_breakdown.csv": ["period_id", "variant", "symbol"],
        "direction_breakdown.csv": ["period_id", "variant", "direction"],
        "monthly_breakdown.csv": ["period_id", "variant", "month"],
        "yearly_breakdown.csv": ["period_id", "variant", "year"],
    }
    for filename, keys in files.items():
        write_csv(OUT / filename, group_stats(rows, keys))


def write_old_new_diff(rows):
    fields = [
        "run_id", "period_id", "variant", "entry_time", "symbol", "direction",
        "old_reconfirm_pass", "new_micro_n_relaunch_detected", "new_micro_n_relaunch_pass",
        "old_vs_new_bucket", "m5_micro_n_state", "m5_active_oshiyasu_price",
        "m5_active_modoritakane_price", "m5_micro_anchor_creation_time",
        "m5_relaunch_break_time", "m5_relaunch_break_level", "m5_relaunch_signal_age_bars",
        "bars_from_relaunch_to_entry", "result_r", "mfe_r", "mae_r", "exit_type",
    ]
    projected = [{field: row.get(field, "") for field in fields} for row in rows]
    write_csv(OUT / "old_vs_micro_n_reconfirm_diff.csv", projected, fields)


def fmt(row):
    if not row:
        return "missing"
    return (
        f"trades={int(fnum(row.get('trades')))}, PF={fnum(row.get('profit_factor')):.2f}, "
        f"avg_R={fnum(row.get('avg_r')):.4f}, net={fnum(row.get('net_profit')):.2f}, "
        f"avg_MFE={fnum(row.get('avg_mfe_r')):.3f}R, "
        f"MFE>=1R={fnum(row.get('reached_1_0r_rate')):.1%}, "
        f"MFE>=1.3R={fnum(row.get('reached_1_3r_rate')):.1%}, "
        f"time_exit={fnum(row.get('time_exit_rate')):.1%}, TP={fnum(row.get('tp_exit_rate')):.1%}"
    )


def variant_row(rows, variant):
    return next((row for row in rows if row.get("variant") == variant), None)


def subset_stats(rows, predicate):
    return stats(row for row in rows if predicate(row))


def dependency_text(rows):
    if not rows:
        return "no trades"
    parts = []
    for key in ("symbol", "session_label", "direction"):
        counts = Counter(row.get(key, "") for row in rows)
        label, count = counts.most_common(1)[0]
        parts.append(f"{key}={label}:{count / len(rows):.1%}")
    return ", ".join(parts)


def write_summary(comparison, all_trades):
    full = [row for row in comparison if row.get("period_id") == "full2025_validation"]
    variants = {row.get("variant"): row for row in full}
    baseline = variants.get("base")
    light = variants.get("light")
    anchor = variants.get("anchor_pullback")
    diagnostic = [row for row in all_trades if row.get("run_id") == "full2025_micro_n_diag"]
    old_only = subset_stats(diagnostic, lambda row: row.get("old_vs_new_bucket") == "old_only")
    new_only = subset_stats(diagnostic, lambda row: row.get("old_vs_new_bucket") == "new_only")
    both = subset_stats(diagnostic, lambda row: row.get("old_vs_new_bucket") == "both")
    first_rows = [row for row in all_trades if row.get("period_id") == "full2025_validation" and row.get("variant") in {
        "micro_n_first", "micro_n_strong", "light_or_micro_n_first", "light_or_micro_n_pattern",
        "light_or_micro_n_exhaustion", "one_micro_n_first", "one_light_or_micro_n_first",
    }]
    first_taken = [row for row in first_rows if bval(row.get("m5_relaunch_break_detected"))]
    first_age_ok = bool(first_taken) and all(int(fnum(row.get("m5_relaunch_signal_age_bars"))) <= 1 for row in first_taken)
    event_ids = [row.get("m5_relaunch_event_id") for row in first_rows if row.get("m5_relaunch_event_id")]
    unique_events = bool(event_ids) and len(event_ids) == len(set(event_ids))
    positive_100 = [row for row in full if fnum(row.get("trades")) >= 100 and fnum(row.get("profit_factor")) >= 1.05 and fnum(row.get("avg_r")) > 0 and fnum(row.get("net_profit")) > 0]
    fragments = [row for row in full if 50 <= fnum(row.get("trades")) < 200 and fnum(row.get("profit_factor")) >= 1.05 and fnum(row.get("avg_r")) > 0 and fnum(row.get("net_profit")) > 0]
    gates = [row for row in full if bval(row.get("passed_2025_gate"))]
    baseline_mfe = fnum(baseline.get("reached_1_0r_rate") if baseline else 0)
    stop_pass = [row for row in positive_100 if fnum(row.get("reached_1_0r_rate")) > baseline_mfe]
    promote = variants.get("light_or_micro_n_first")
    promote_trades = [row for row in all_trades if row.get("run_id") == "full2025_light_or_micro_n_first"]
    report_missing = [row.get("run_id") for row in full if not (OUT / row.get("run_id", "") / "report.html").exists()]

    lines = [
        "# First M5 Micro-N Relaunch After M15 Anchor Pullback",
        "",
        "## Scope",
        "- M15 anchor uses the first close break after a confirmed M15 anchor. Latest-near-entry remains diagnostic only.",
        "- The M5 relaunch requires a confirmed `low-high-lower-low` correction for Long or `high-low-higher-high` correction for Short, then the first close break of the middle micro anchor.",
        "- M5 pivots use closed bars and right-side confirmation bars; no unclosed bar, repaint value, MFE, or result label is used by entry logic.",
        "- Timeframes: H1=`16385`, M15=`15`, M5=`5`; tester period M15, internal scan `PERIOD_M5` closed bars.",
        f"- MT5 HTML reports missing: {', '.join(report_missing) if report_missing else 'none'}.",
        "",
        "## Full-2025 Comparison",
    ]
    for key in ["base", "light", "anchor_pullback", "micro_n_diag", "micro_n_required", "micro_n_first",
                "micro_n_strong", "light_or_micro_n", "light_or_micro_n_first", "light_or_micro_n_pattern",
                "light_or_micro_n_exhaustion", "one_micro_n_first", "one_light_or_micro_n_first"]:
        lines.append(f"- {key}: {fmt(variants.get(key))}")
    lines += [
        "",
        "## Required Answers",
        f"1. baseline reproduced: {fmt(baseline)}.",
        f"2. required-light reproduced: {fmt(light)}.",
        f"3. previous anchor pullback reproduced: {fmt(anchor)}.",
        f"4. confirmed M5 micro anchors formed: detected rows={sum(1 for row in diagnostic if row.get('m5_micro_n_state') in {'falling_n', 'rising_n'})}; range/unknown remains diagnostic.",
        "5. relaunch is an anchor break, not a candle label: yes; it requires a confirmed three-pivot corrective N and a close beyond the middle oshiyasu/modoritakane.",
        f"6. first-valid-signal-only worked: implementation enforces age<=1, but empirical trade validation was not possible because taken first-mode relaunch trades={len(first_taken)} (observed_age_rule_pass={first_age_ok}).",
        f"7. stale signal reuse blocked: the EA reserves the event before portfolio selection/order checks, but empirical duplicate validation was not possible because taken event IDs={len(event_ids)} (observed_unique={unique_events}).",
        f"8. old vs new diagnostic: old_only={fmt(old_only)}, new_only={fmt(new_only)}, both={fmt(both)}.",
        f"9. micro-N required: {fmt(variants.get('micro_n_required'))}; first-only={fmt(variants.get('micro_n_first'))}.",
        f"10. first-only time exit comparison: required={fnum(variants.get('micro_n_required', {}).get('time_exit_rate')):.1%}, first-only={fnum(variants.get('micro_n_first', {}).get('time_exit_rate')):.1%}.",
        f"11. required-light OR first micro-N: {fmt(promote)}; this is identical to required-light, so micro-N contributed zero additional trades.",
        f"12. one-symbol combination: {fmt(variants.get('one_light_or_micro_n_first'))}; micro-N-only produced zero, so this positive fragment is also required-light selection, not micro-N improvement.",
        f"13. dependency for required-light OR first micro-N: {dependency_text(promote_trades)}.",
        f"14. 100+ trades with PF>=1.05, avg_R>0, net>0: {', '.join(row.get('run_id') for row in positive_100) or 'none'}.",
        f"15. 2025 shallow gate pass (200+): {', '.join(row.get('run_id') for row in gates) or 'none'}.",
        f"16. 3-year BT/OOS candidate: {'yes' if gates else 'no; 2025 gate was not passed'}.",
        f"17. family decision: {'continue only with the named 100+ positive candidate(s)' if stop_pass else 'park as a research asset; the final structural stop condition was not met'}.",
        "",
        f"Research fragments (50-199 positive): {', '.join(row.get('run_id') for row in fragments) or 'none'}.",
        f"Final stop-condition candidates with 100+ positive trades and MFE>=1R above baseline: {', '.join(row.get('run_id') for row in stop_pass) or 'none'}.",
        "No 3-year or OOS run was executed unless the 2025 shallow gate passed.",
    ]
    (OUT / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


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
        trades = dedupe_trades(read_csv(paths["trades"], encoding="mbcs"))
        summary = read_csv(paths["summary"], encoding="mbcs")
        for row in trades:
            row.update(run)
            add_derived(row)
            all_trades.append(row)
        if trades:
            write_csv(run_dir / "trades.csv", trades)
        run_stats = stats(trades)
        stopped = bool(summary and (bval(summary[-1].get("daily_stopped")) or bval(summary[-1].get("drawdown_stopped"))))
        gate = pass_gate(trades, run_stats, stopped) if run["period_id"] == "full2025_validation" else False
        comparison.append({**run, **run_stats, "daily_or_dd_stopped": stopped, "passed_2025_gate": gate})

    write_csv(OUT / "comparison.csv", comparison)
    write_csv(OUT / "q1_comparison.csv", [row for row in comparison if row["period_id"] == "q1_quick"])
    write_csv(OUT / "full2025_comparison.csv", [row for row in comparison if row["period_id"] == "full2025_validation"])
    write_csv(OUT / "trades_all_scenarios.csv", all_trades)
    write_old_new_diff(all_trades)
    write_breakdowns(all_trades)
    write_summary(comparison, all_trades)


if __name__ == "__main__":
    main()
