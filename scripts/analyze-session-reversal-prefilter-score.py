import csv
import math
import shutil
from collections import defaultdict
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
COMMON_FILES = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"
OUT = REPO / "reports" / "backtest" / "runs" / "20260627_session_reversal_pullback_prefilter_score_diagnostics"
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
MATRIX = REPO / "reports" / "backtest" / f"{EA_NAME}_prefilter_score_run_matrix_2025.csv"
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


def month_key(value):
    text = str(value)
    if len(text) >= 7:
        return text[:7].replace(".", "-")
    return ""


def year_key(value):
    text = str(value)
    if len(text) >= 4:
        return text[:4]
    return ""


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


def obstacle_distance_bucket(row):
    value = fnum(row.get("nearest_obstacle_distance_r"))
    if value <= 0.0:
        return "none"
    if value < 0.8:
        return "lt_0_8r"
    if value < 1.0:
        return "0_8_to_1_0r"
    if value < 1.5:
        return "1_0_to_1_5r"
    return "gte_1_5r"


def retest_score_bucket(row):
    value = fnum(row.get("retest_score"))
    if value <= 0.0:
        return "none"
    if value < 0.15:
        return "low"
    if value < 0.20:
        return "medium"
    return "high"


def final_score_bucket(row):
    value = fnum(row.get("final_score") or row.get("score"))
    if value < 0.5:
        return "lt_0_5"
    if value < 0.8:
        return "0_5_to_0_8"
    if value < 1.1:
        return "0_8_to_1_1"
    return "gte_1_1"


def stats(rows):
    rows = list(rows)
    profits = [fnum(r.get("net_profit")) for r in rows]
    rvals = [fnum(r.get("result_r")) for r in rows]
    mfes = [fnum(r.get("max_favorable_r_before_exit")) for r in rows]
    maes = [fnum(r.get("max_adverse_r_before_exit")) for r in rows]
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
        "avg_mfe_r": sum(mfes) / count if count else 0.0,
        "avg_mae_r": sum(maes) / count if count else 0.0,
        "avg_final_score": sum(fnum(r.get("final_score") or r.get("score")) for r in rows) / count if count else 0.0,
        "avg_target_room_score": sum(fnum(r.get("target_room_score")) for r in rows) / count if count else 0.0,
        "avg_retest_score": sum(fnum(r.get("retest_score")) for r in rows) / count if count else 0.0,
        "avg_m15_best_score": sum(fnum(r.get("m15_best_score")) for r in rows) / count if count else 0.0,
        "avg_m5_best_score": sum(fnum(r.get("m5_best_score")) for r in rows) / count if count else 0.0,
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


def group_counts(rows, keys):
    groups = defaultdict(int)
    for row in rows:
        groups[tuple(row.get(key, "") for key in keys)] += 1
    out = []
    for key_values, count in sorted(groups.items()):
        row = {key: value for key, value in zip(keys, key_values)}
        row["rows"] = count
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
    return COMMON_FILES / f"fx_session_reversal_prefilter_{run['run_id']}_2025"


def output_run_dir(run):
    if run["run_id"] == "london_first120__london_focused_diagnostic__be_1_1r":
        return OUT / "london_focus_diag__be_1_1r"
    return OUT / run["run_id"]


def csv_names(run):
    scenario_name = run["scenario_name"]
    folder = run_folder(run)
    return {
        "signals": folder / f"fxsessionrev_{scenario_name}_signals.csv",
        "trades": folder / f"fxsessionrev_{scenario_name}_trades.csv",
        "summary": folder / f"fxsessionrev_{scenario_name}_summary.csv",
    }


def copy_artifacts(run):
    run_id = run["run_id"]
    run_dir = output_run_dir(run)
    run_dir.mkdir(parents=True, exist_ok=True)
    for source in [
        REPO / "reports" / "backtest" / f"{EA_NAME}_{run_id}_2025.ini",
        REPO / "reports" / "presets" / f"{EA_NAME}_{run_id}_2025.set",
    ]:
        if source.exists():
            shutil.copy2(source, run_dir / ("tester.ini" if source.suffix == ".ini" else "preset.set"))
    for report in (REPO / "reports" / "backtest").glob(f"{EA_NAME}_{run_id}_2025_report*"):
        short_name = report.name.replace(f"{EA_NAME}_{run_id}_2025_", "")
        shutil.copy2(report, run_dir / short_name)


def best_row(rows, where=lambda r: True, key=lambda r: fnum(r.get("avg_r"))):
    candidates = [row for row in rows if where(row)]
    if not candidates:
        return None
    return max(candidates, key=key)


def row_desc(row):
    if not row:
        return "none"
    return (
        f"`{row['run_id']}` trades={int(fnum(row.get('trades')))} "
        f"PF={fnum(row.get('profit_factor')):.2f} avg_R={fnum(row.get('avg_r')):.4f} "
        f"net={fnum(row.get('net_profit')):.2f} MaxDD={fnum(row.get('max_dd_profit')):.2f}"
    )


def signal_count(rows, **where):
    count = 0
    for row in rows:
        ok = True
        for key, value in where.items():
            if row.get(key) != value:
                ok = False
                break
        if ok:
            count += 1
    return count


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    matrix = read_csv(MATRIX)
    write_csv(OUT / "run_matrix.csv", matrix)

    all_trades = []
    all_signals = []
    comparison = []

    for run in matrix:
        paths = csv_names(run)
        copy_artifacts(run)
        run_dir = output_run_dir(run)
        for label, path in paths.items():
            if label == "signals":
                continue
            if path.exists():
                shutil.copy2(path, run_dir / f"{label}.csv")

        signals = read_csv(paths["signals"], encoding="mbcs")
        trades = read_csv(paths["trades"], encoding="mbcs")
        summary_rows = read_csv(paths["summary"], encoding="mbcs")

        for row in signals:
            row.update(run)
            row["target_room_bucket"] = target_room_bucket(row)
            row["retest_score_bucket"] = retest_score_bucket(row)
            row["obstacle_distance_bucket"] = obstacle_distance_bucket(row)
            row["final_score_bucket"] = final_score_bucket(row)
            all_signals.append(row)

        for row in trades:
            row.update(run)
            row["year"] = year_key(row.get("entry_time"))
            row["month"] = month_key(row.get("entry_time"))
            row["target_room_bucket"] = target_room_bucket(row)
            row["retest_score_bucket"] = retest_score_bucket(row)
            row["obstacle_distance_bucket"] = obstacle_distance_bucket(row)
            row["final_score_bucket"] = final_score_bucket(row)
            all_trades.append(row)

        s = stats(trades)
        dd_stopped = False
        summary_last = summary_rows[-1] if summary_rows else {}
        if summary_rows:
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
            "signals": len(signals),
            "htf_permission_rejections": int(fnum(summary_last.get("htf_permission_rejections"))) if summary_last else signal_count(signals, event="htf_permission_rejected"),
            "preselection_rejections": int(fnum(summary_last.get("preselection_rejections"))) if summary_last else signal_count(signals, event="preselection_rejected"),
            "daily_or_dd_stopped": dd_stopped,
            "gate_scope": gate_scope(run),
            "passed_2025_shallow_gate": passed,
        })

    write_csv(OUT / "comparison.csv", comparison)
    write_csv(OUT / "trades_all_scenarios.csv", all_trades)

    write_csv(OUT / "htf_permission_mode_breakdown.csv", group_stats(all_trades, ["scenario_id", "experiment_id", "htf_permission_mode", "break_even_mode"]))
    write_csv(OUT / "score_component_breakdown.csv", group_stats(all_trades, ["scenario_id", "experiment_id", "final_score_bucket", "target_room_bucket", "retest_score_bucket"]))
    write_csv(OUT / "retest_reference_breakdown.csv", group_stats(all_trades, ["scenario_id", "experiment_id", "retest_reference_type", "retest_score_bucket"]))
    write_csv(OUT / "target_room_breakdown.csv", group_stats(all_trades, ["scenario_id", "experiment_id", "target_room_bucket", "nearest_obstacle_type", "obstacle_distance_bucket"]))
    write_csv(OUT / "timeframe_breakdown.csv", group_stats(all_trades, ["scenario_id", "experiment_id", "selected_candidate_timeframe"]))
    write_csv(OUT / "session_breakdown.csv", group_stats(all_trades, ["scenario_id", "experiment_id", "session_label"]))
    write_csv(OUT / "symbol_breakdown.csv", group_stats(all_trades, ["scenario_id", "experiment_id", "symbol"]))
    write_csv(OUT / "direction_breakdown.csv", group_stats(all_trades, ["scenario_id", "experiment_id", "direction"]))
    write_csv(OUT / "entry_pattern_breakdown.csv", group_stats(all_trades, ["scenario_id", "experiment_id", "entry_pattern"]))
    write_csv(OUT / "yearly_breakdown.csv", group_stats(all_trades, ["run_id", "year"]))
    write_csv(OUT / "monthly_breakdown.csv", group_stats(all_trades, ["run_id", "month"]))
    write_csv(OUT / "signal_event_breakdown.csv", group_counts(all_signals, ["run_id", "event", "htf_permission_mode", "rejected_before_selection_reason"]))
    write_csv(OUT / "preselection_rejection_breakdown.csv", group_counts(
        [row for row in all_signals if row.get("event") == "preselection_rejected"],
        ["run_id", "rejected_before_selection_reason", "session_label", "symbol"],
    ))

    r_rows = []
    grouped = defaultdict(list)
    for row in all_trades:
        grouped[row["run_id"]].append(row)
    for run_id, rows in sorted(grouped.items()):
        rvals = sorted(fnum(row.get("result_r")) for row in rows)
        s = stats(rows)
        median = rvals[len(rvals) // 2] if rvals else 0.0
        p10 = rvals[int(len(rvals) * 0.10)] if rvals else 0.0
        p90 = rvals[int(len(rvals) * 0.90)] if rvals else 0.0
        meta = next((row for row in matrix if row["run_id"] == run_id), {})
        r_rows.append({**meta, "median_r": median, "p10_r": p10, "p90_r": p90, **s})
    write_csv(OUT / "r_metrics.csv", r_rows)

    compile_log = REPO / "reports" / "compile" / f"{EA_NAME}_prefilter_score_compile.log"
    if compile_log.exists():
        shutil.copy2(compile_log, OUT / "compile.log")

    baseline_all = next((row for row in comparison if row["scenario_id"] == "all_symbols_first120" and row["experiment_id"] == "baseline_current" and row["break_even_id"] == "no_be"), None)
    prefilter_all = [
        row for row in comparison
        if row["scenario_id"] == "all_symbols_first120"
        and row["experiment_id"] in {"prefilter_h1_h4_notopp", "prefilter_h4_bias_h1_reversal", "prefilter_soft"}
        and row["break_even_id"] == "no_be"
    ]
    best_prefilter_all = best_row(prefilter_all, key=lambda r: (fnum(r.get("trades")), fnum(r.get("avg_r"))))
    best_gate = best_row(
        comparison,
        lambda r: bval(r.get("gate_scope")),
        lambda r: (bval(r.get("passed_2025_shallow_gate")), fnum(r.get("avg_r")), fnum(r.get("profit_factor")), fnum(r.get("trades"))),
    )
    passed = [row for row in comparison if bval(row.get("passed_2025_shallow_gate"))]
    best_london = best_row(
        comparison,
        lambda r: r["scenario_id"] == "london_first120",
        lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor"))),
    )
    best_newyork = best_row(
        comparison,
        lambda r: r["scenario_id"] == "newyork_first120",
        lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor"))),
    )
    baseline_rejects = int(fnum(baseline_all.get("htf_permission_rejections"))) if baseline_all else 0
    best_orderable = best_row(
        comparison,
        lambda r: r["scenario_id"] == "one_symbol_first120" and r["experiment_id"].startswith("prefilter"),
        lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor")), -fnum(r.get("preselection_rejections"))),
    )
    m5_rows = [row for row in all_trades if row.get("selected_candidate_timeframe") == "PERIOD_M5"]
    m15_rows = [row for row in all_trades if row.get("selected_candidate_timeframe") == "PERIOD_M15"]
    retest_high = [row for row in all_trades if row.get("retest_score_bucket") == "high"]
    target_high = [row for row in all_trades if row.get("target_room_bucket") == "high"]
    target_neg = [row for row in all_trades if row.get("target_room_bucket") == "negative"]

    lines = [
        "# Session Reversal Pullback HTF Pre-Filter and Score Component Diagnostics",
        "",
        "## Implementation",
        "- `baseline_current` keeps the existing LTF-candidate then HTF post-filter order and existing time/clean-path score.",
        "- Prefilter modes compute HTF permission first, then search M15 and M5 LTF candidates only in allowed directions.",
        "- Prefilter modes remove the first-60 time score and add `retest_score` plus `target_room_score` as diagnostics/scoring components.",
        "- One-symbol selection can reject non-orderable candidates before consuming the session when `InpFilterOrderableBeforeSessionSelection=true`.",
        "- Break-even comparison is limited to `no_break_even` and `break_even_at_1_1r`.",
        "",
        "## Required Answers",
        f"1. Trade count: baseline all_symbols no_BE was {row_desc(baseline_all)}. Best all_symbols prefilter no_BE by count was {row_desc(best_prefilter_all)}.",
        f"2. PF / avg_R: best gate-scope row was {row_desc(best_gate)}.",
        f"3. Old order issue: baseline all_symbols no_BE produced {baseline_rejects} `htf_permission_rejected` rows after LTF detection; prefilter modes reject HTF first and therefore do not select an opposite LTF candidate before permission.",
        f"4. M15/M5 both: PERIOD_M15 trades={len(m15_rows)} avg_R={stats(m15_rows)['avg_r']:.4f}; PERIOD_M5 trades={len(m5_rows)} avg_R={stats(m5_rows)['avg_r']:.4f}.",
        f"5. Time score removal: baseline rows retain the time score; prefilter rows set `time_score_removed_flag=true`. Compare `baseline_current` against prefilter rows in `score_component_breakdown.csv`; no fine time-bucket repair was used.",
        f"6. Retest score: high retest-score bucket trades={len(retest_high)} avg_R={stats(retest_high)['avg_r']:.4f}; see `retest_reference_breakdown.csv` for type-level evidence.",
        f"7. Target room score: high target-room bucket trades={len(target_high)} avg_R={stats(target_high)['avg_r']:.4f}; negative bucket trades={len(target_neg)} avg_R={stats(target_neg)['avg_r']:.4f}.",
        f"8. One-symbol orderable filtering: best one-symbol prefilter row was {row_desc(best_orderable)} with {int(fnum(best_orderable.get('preselection_rejections'))) if best_orderable else 0} preselection rejections; reasons are in `preselection_rejection_breakdown.csv`.",
        f"9. London edge: best London row was {row_desc(best_london)}. It remains diagnostic only if trade count is low.",
        f"10. NewYork weakness: best NewYork row was {row_desc(best_newyork)}.",
        f"11. 2025 shallow gate: {', '.join(row['run_id'] for row in passed) if passed else 'no candidate passed'} (`200 trades`, PF>=1.05, avg_R>0, net>0, no stop, no symbol/direction/session dependence).",
        "12. 3-year fixed BT / OOS: advance only 2025 gate-pass candidates; no 3-year/OOS run is created when the 2025 gate has no pass.",
        "",
        "## Evidence",
        "- `comparison.csv`",
        "- `htf_permission_mode_breakdown.csv`",
        "- `score_component_breakdown.csv`",
        "- `retest_reference_breakdown.csv`",
        "- `target_room_breakdown.csv`",
        "- `timeframe_breakdown.csv`",
        "- `session_breakdown.csv`",
        "- `symbol_breakdown.csv`",
        "- `direction_breakdown.csv`",
        "- `entry_pattern_breakdown.csv`",
        "- `yearly_breakdown.csv`",
        "- `monthly_breakdown.csv`",
        "- `signal_event_breakdown.csv`",
        "- `preselection_rejection_breakdown.csv`",
        "- `r_metrics.csv`",
    ]
    (OUT / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
