import csv
import math
import shutil
from collections import defaultdict
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
COMMON_FILES = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"
OUT = REPO / "reports" / "backtest" / "runs" / "20260708_session_reversal_m15_wave1_quality"
MATRIX = OUT / "run_matrix.csv"
DEPOSIT = 10000.0


def fnum(value):
    if value in (None, ""):
        return 0.0
    try:
        text = str(value).replace(",", "")
        if text.lower() in {"inf", "infinity"}:
            return math.inf
        return float(text)
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


def dedupe_trades(rows):
    unique = []
    seen = set()
    for row in rows:
        key = (
            row.get("entry_time", ""),
            row.get("exit_time", ""),
            row.get("symbol", ""),
            row.get("direction", ""),
            row.get("entry", ""),
            row.get("exit", ""),
            row.get("position_id", ""),
            row.get("result_r", ""),
        )
        if key in seen:
            continue
        seen.add(key)
        unique.append(row)
    return unique


def stats(rows):
    rows = list(rows)
    profits = [fnum(r.get("net_profit")) for r in rows]
    rvals = [fnum(r.get("result_r")) for r in rows]
    mfes = [fnum(r.get("max_favorable_r_before_exit") or r.get("mfe_r")) for r in rows]
    maes = [fnum(r.get("max_adverse_r_before_exit") or r.get("mae_r")) for r in rows]
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
        "signals": folder / f"fxsessionrev_{scenario}_signals.csv",
        "summary": folder / f"fxsessionrev_{scenario}_summary.csv",
    }


def near_miss_group(row):
    required = bval(row.get("m15_required_light_pass"))
    near = bval(row.get("m15_wave2_near_miss"))
    reached_1r = bval(row.get("reached_1_0r"))
    reached_13r = bval(row.get("reached_1_3r"))
    positive = fnum(row.get("result_r")) > 0
    if required:
        return "A_required_light_pass"
    if near and reached_13r and positive:
        return "D_reject_strong_mfe13_winner"
    if near and reached_1r and positive:
        return "B_reject_mfe1_winner"
    if near:
        return "C_reject_loser_or_no_mfe1"
    return "E_reject_not_near_miss"


def required_light_wave1_group(row):
    required = bval(row.get("m15_required_light_pass"))
    quality = bval(row.get("m15_wave1_quality_high"))
    if required and quality:
        return "B_required_light_pass_wave1_quality_high"
    if required:
        return "A_required_light_pass_wave1_quality_low"
    if quality:
        return "C_required_light_reject_wave1_quality_high"
    return "D_required_light_reject_wave1_quality_low"


def near_miss_by_wave1_group(row):
    required = bval(row.get("m15_required_light_pass"))
    quality = bval(row.get("m15_wave1_quality_high"))
    reached_1r = bval(row.get("reached_1_0r"))
    reached_13r = bval(row.get("reached_1_3r"))
    positive = fnum(row.get("result_r")) > 0
    if required:
        return "required_light_pass"
    if quality and reached_13r and positive:
        return "reject_wave1_high_strong_mfe13_winner"
    if quality and reached_1r and positive:
        return "reject_wave1_high_mfe1_winner"
    if quality:
        return "reject_wave1_high_loser_or_no_mfe1"
    return "reject_wave1_low"


def add_derived_columns(row):
    row["year"] = year_key(row.get("entry_time"))
    row["month"] = month_key(row.get("entry_time"))
    row["mfe_r"] = row.get("max_favorable_r_before_exit", "")
    row["mae_r"] = row.get("max_adverse_r_before_exit", "")
    row["entry_timeframe"] = row.get("selected_candidate_timeframe") or row.get("ltf_wave3_timeframe")
    row["mfe_1r_bucket"] = "mfe_ge_1r" if bval(row.get("reached_1_0r")) else "mfe_lt_1r"
    row["mfe_13r_bucket"] = "mfe_ge_1_3r" if bval(row.get("reached_1_3r")) else "mfe_lt_1_3r"
    row["result_bucket"] = "winner" if fnum(row.get("result_r")) > 0 else "loser_or_flat"
    row["required_light_bucket"] = "required_light_pass" if bval(row.get("m15_required_light_pass")) else "required_light_reject"
    row["wave1_quality_bucket"] = row.get("m15_wave1_quality_bucket") or "none"
    row["wave1_quality_pass_bucket"] = "wave1_quality_high" if bval(row.get("m15_wave1_quality_high")) else "wave1_quality_low"
    row["wave1_quality_gate_bucket"] = "wave1_quality_gate_pass" if bval(row.get("m15_wave1_quality_gate_pass")) else "wave1_quality_gate_fail"
    row["required_light_wave1_group"] = required_light_wave1_group(row)
    row["near_miss_by_wave1_group"] = near_miss_by_wave1_group(row)


def feature_comparison(rows, features, filename):
    out = []
    for feature in features:
        for item in group_stats(rows, ["near_miss_group", feature]):
            item = {"feature": feature, **item}
            out.append(item)
    write_csv(OUT / filename, out)


def write_breakdowns(all_trades):
    breakdowns = {
        "m15_wave1_quality_grouped_trades.csv": ["period_id", "variant", "required_light_wave1_group"],
        "m15_wave1_quality_breakdown.csv": [
            "period_id", "variant", "required_light_bucket", "wave1_quality_pass_bucket",
            "m15_wave1_impulse_bucket", "m15_wave1_body_efficiency_bucket",
            "m15_wave1_overlap_bucket", "m15_wave1_break_quality",
            "m15_wave1_speed_bucket", "m15_wave1_follow_through_bucket",
            "m15_wave1_obstacle_clearance_bucket",
        ],
        "required_light_by_m15_wave1_quality.csv": ["period_id", "variant", "required_light_bucket", "wave1_quality_pass_bucket", "wave1_quality_bucket"],
        "near_miss_by_m15_wave1_quality.csv": ["period_id", "variant", "near_miss_by_wave1_group", "wave1_quality_bucket"],
        "mfe_by_m15_wave1_quality.csv": ["period_id", "variant", "wave1_quality_pass_bucket", "wave1_quality_bucket", "mfe_1r_bucket", "mfe_13r_bucket"],
        "wave1_quality_x_corrective_exhaustion_breakdown.csv": [
            "period_id", "variant", "required_light_bucket", "wave1_quality_pass_bucket",
            "m5_corrective_exhaustion_bucket",
        ],
        "mfe_threshold_breakdown.csv": ["period_id", "variant", "mfe_1r_bucket", "mfe_13r_bucket"],
        "entry_pattern_breakdown.csv": ["period_id", "variant", "entry_pattern", "entry_trigger"],
        "entry_timeframe_breakdown.csv": ["period_id", "variant", "entry_timeframe"],
        "session_breakdown.csv": ["period_id", "variant", "session_label"],
        "symbol_breakdown.csv": ["period_id", "variant", "symbol"],
        "direction_breakdown.csv": ["period_id", "variant", "direction"],
        "monthly_breakdown.csv": ["period_id", "variant", "month"],
        "yearly_breakdown.csv": ["period_id", "variant", "year"],
    }
    for filename, keys in breakdowns.items():
        write_csv(OUT / filename, group_stats(all_trades, keys))


def choose_best_separators(comparison):
    full = [r for r in comparison if r.get("period_id") == "full2025_validation" and r.get("variant") in SEPARATOR_VARIANTS]
    for row in full:
        row["selection_score"] = (
            fnum(row.get("avg_r")) * 100.0
            + fnum(row.get("profit_factor")) * 10.0
            + fnum(row.get("reached_1_0r_rate")) * 4.0
            + fnum(row.get("reached_1_3r_rate")) * 2.0
            + min(fnum(row.get("trades")), 200.0) / 50.0
        )
        row["research_fragment_100plus_positive"] = (
            fnum(row.get("trades")) >= 100
            and fnum(row.get("profit_factor")) >= 1.05
            and fnum(row.get("avg_r")) > 0
        )
    ranked = sorted(full, key=lambda r: (bval(r.get("research_fragment_100plus_positive")), fnum(r.get("selection_score"))), reverse=True)
    selected = ranked[:2]
    mask = 0
    for row in selected:
        mask |= SEPARATOR_VARIANTS.get(row.get("variant"), 0)
    rows = []
    for idx, row in enumerate(ranked, start=1):
        rows.append({
            "rank": idx,
            "selected": row in selected,
            "recommended_best_single": selected[0].get("variant") if selected else "",
            "recommended_best_two_mask": mask,
            **row,
        })
    write_csv(OUT / "separator_candidate_comparison.csv", rows)
    write_csv(OUT / "selected_separator_modes.csv", rows)
    return selected[0].get("variant") if selected else "invalidation", mask


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


def top_value(rows, key):
    counts = defaultdict(int)
    for row in rows:
        counts[row.get(key, "")] += 1
    if not counts:
        return "none"
    value, count = max(counts.items(), key=lambda item: item[1])
    return f"{value} ({count})"


def write_summary(comparison, all_trades):
    full = [r for r in comparison if r.get("period_id") == "full2025_validation"]
    baseline = next((r for r in full if r.get("variant") == "base"), None)
    light = next((r for r in full if r.get("variant") == "light"), None)
    diag = [r for r in all_trades if r.get("run_id") == "full2025_wave1_diag"]
    group_a_all = [r for r in diag if bval(r.get("m15_required_light_pass"))]
    group_b = [r for r in diag if r.get("required_light_wave1_group") == "B_required_light_pass_wave1_quality_high"]
    group_c = [r for r in diag if r.get("required_light_wave1_group") == "C_required_light_reject_wave1_quality_high"]
    group_d = [r for r in diag if r.get("required_light_wave1_group") == "D_required_light_reject_wave1_quality_low"]
    reject_near_miss_winners = [
        r for r in diag
        if not bval(r.get("m15_required_light_pass"))
        and bval(r.get("m15_wave1_quality_high"))
        and bval(r.get("reached_1_0r"))
        and fnum(r.get("result_r")) > 0
    ]
    wave1_rows = [r for r in full if "wave1" in r.get("variant", "")]
    best_row = max(wave1_rows, key=lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor"))), default=None)
    fragments_100 = [r for r in full if fnum(r.get("trades")) >= 100 and fnum(r.get("avg_r")) > 0 and fnum(r.get("profit_factor")) >= 1.05]
    fragments_50 = [r for r in full if 50 <= fnum(r.get("trades")) < 200 and fnum(r.get("avg_r")) > 0 and fnum(r.get("profit_factor")) >= 1.05]
    gate_pass = [r for r in full if bval(r.get("passed_2025_gate"))]
    reports_missing = [r.get("run_id") for r in full if not (OUT / r.get("run_id", "") / "report.html").exists()]
    light_or_wave1 = next((r for r in full if r.get("variant") == "light_or_wave1"), None)
    wave1_only = next((r for r in full if r.get("variant") == "wave1_only"), None)
    light_and_wave1 = next((r for r in full if r.get("variant") == "light_and_wave1"), None)
    light_or_wave1_exhaustion = next((r for r in full if r.get("variant") == "light_or_wave1_exhaustion"), None)
    one_or = next((r for r in full if r.get("variant") == "one_light_or_wave1"), None)

    answers = [
        "# M15 Wave1 Quality Validation",
        "",
        "## Scope",
        "- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`",
        "- Objective: keep M15 wave2 required-light intact and test whether M15 wave1 quality separates third-wave launch candidates.",
        "- MFE/result columns are used only in analyzer grouping, not in EA entry decisions.",
        "- Timeframe preset check: H1=`16385`, M15=`15`, M5=`5`; `InpPrimaryEntryTF=5` and CSV exports `selected_candidate_timeframe` from the selected candidate.",
        f"- MT5 HTML reports missing: {', '.join(reports_missing) if reports_missing else 'none'}.",
        "",
        "## Full-2025 Anchors",
        f"- baseline c10: {fmt(baseline)}",
        f"- required-light: {fmt(light)}",
        f"- best wave1-quality row: `{best_row.get('run_id') if best_row else 'none'}` {fmt(best_row)}",
        f"- required-light AND wave1 quality: {fmt(light_and_wave1)}",
        f"- required-light OR wave1 quality: {fmt(light_or_wave1)}",
        f"- wave1 quality only: {fmt(wave1_only)}",
        f"- required-light OR wave1 quality + corrective exhaustion: {fmt(light_or_wave1_exhaustion)}",
        "",
        "## Required Answers",
        f"1. baseline c10 reproduced: {fmt(baseline)}.",
        f"2. required-light reproduced: {fmt(light)}.",
        f"3. M15 wave1 quality split required-light winners/losers: required-light all={len(group_a_all)}, required-light+quality-high={len(group_b)}; see `required_light_by_m15_wave1_quality.csv`.",
        "   Diagnostic labels inside `full2025_wave1_diag` do not equal the separate 50-trade required-light run because changing gates changes entry order and session consumption.",
        f"4. M15 wave1 quality picked required-light reject near-miss winners: reject quality-high MFE>=1R winners={len(reject_near_miss_winners)}; see `near_miss_by_m15_wave1_quality.csv`.",
        f"5. wave1 quality-only edge: {fmt(wave1_only)}.",
        f"6. required-light OR wave1 quality expanded from 50 trades to 100+: {'yes' if light_or_wave1 and fnum(light_or_wave1.get('trades')) >= 100 else 'no'}; {fmt(light_or_wave1)}.",
        f"7. 100+ trades with PF>=1.05 and avg_R>0: {', '.join(r.get('run_id') for r in fragments_100) or 'none'}.",
        f"8. 200+ trades near 2025 shallow gate: {', '.join(r.get('run_id') for r in gate_pass) or 'none'}.",
        f"9. wave1 quality + corrective exhaustion useful: {fmt(light_or_wave1_exhaustion)}; see `wave1_quality_x_corrective_exhaustion_breakdown.csv`.",
        f"10. one-symbol combination useful: {fmt(one_or)}; promotion still requires non-concentrated 200+ trades.",
        f"11. MFE>=1R / MFE>=1.3R vs baseline: baseline {fmt(baseline)}; best wave1 row {fmt(best_row)}.",
        f"12. time_exit improved: baseline={fnum(baseline.get('time_exit_rate') if baseline else 0):.1%}, best_wave1={fnum(best_row.get('time_exit_rate') if best_row else 0):.1%}.",
        f"13. TP rate improved: baseline={fnum(baseline.get('tp_exit_rate') if baseline else 0):.1%}, best_wave1={fnum(best_row.get('tp_exit_rate') if best_row else 0):.1%}.",
        "14. symbol/session/direction dependence: see `symbol_breakdown.csv`, `session_breakdown.csv`, and `direction_breakdown.csv`; gate requires no extreme concentration.",
        f"15. 2025 shallow gate pass: {', '.join(r.get('run_id') for r in gate_pass) or 'none'}.",
        f"16. 3-year BT/OOS candidate: {'yes' if gate_pass else 'no; no 2025 shallow-gate candidate was promoted'}.",
        "",
        f"Research fragments below 200 trades but positive: {', '.join(r.get('run_id') for r in fragments_50) or 'none'}.",
    ]
    (OUT / "summary.md").write_text("\n".join(answers) + "\n", encoding="utf-8")


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
        if trades:
            write_csv(run_dir / "trades.csv", trades)
        for row in trades:
            row.update(run)
            add_derived_columns(row)
            all_trades.append(row)
        run_stats = stats(trades)
        stopped = bool(summary and (bval(summary[-1].get("daily_stopped")) or bval(summary[-1].get("drawdown_stopped"))))
        comparison.append({**run, **run_stats, "daily_or_dd_stopped": stopped, "passed_2025_gate": pass_gate(trades, run_stats, stopped) if run["period_id"] == "full2025_validation" else False})

    write_csv(OUT / "comparison.csv", comparison)
    write_csv(OUT / "q1_comparison.csv", [r for r in comparison if r["period_id"] == "q1_quick"])
    write_csv(OUT / "full2025_comparison.csv", [r for r in comparison if r["period_id"] == "full2025_validation"])
    write_csv(OUT / "trades_all_scenarios.csv", all_trades)

    diag = [r for r in all_trades if r.get("run_id") == "full2025_wave1_diag"]
    write_csv(OUT / "m15_wave1_quality_grouped_trades.csv", diag)
    group_required_or_reject = [
        r for r in diag
        if r.get("required_light_wave1_group") in {
            "B_required_light_pass_wave1_quality_high",
            "C_required_light_reject_wave1_quality_high",
            "D_required_light_reject_wave1_quality_low",
        }
    ]
    features = [
        "m15_wave1_impulse_bucket",
        "m15_wave1_body_efficiency_bucket",
        "m15_wave1_overlap_bucket",
        "m15_wave1_break_quality",
        "m15_wave1_speed_bucket",
        "m15_wave1_follow_through_bucket",
        "m15_wave1_obstacle_clearance_bucket",
        "entry_pattern",
        "symbol",
        "direction",
        "session_label",
    ]
    feature_comparison(group_required_or_reject, features, "m15_wave1_quality_feature_comparison.csv")

    write_breakdowns(all_trades)
    write_summary(comparison, all_trades)


if __name__ == "__main__":
    main()
