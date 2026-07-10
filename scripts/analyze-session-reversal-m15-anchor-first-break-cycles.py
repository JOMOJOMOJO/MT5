import csv
import math
import shutil
from collections import defaultdict
from datetime import datetime
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
COMMON_FILES = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"
OUT = REPO / "reports" / "backtest" / "runs" / "20260710_session_reversal_m15_anchor_first_break_pullback"
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


def dt(value):
    text = str(value or "").strip()
    if not text:
        return None
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
        try:
            return datetime.strptime(text, fmt)
        except ValueError:
            pass
    return None


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


def distribution(rows, key):
    counts = defaultdict(int)
    for row in rows:
        counts[row.get(key, "") or "blank"] += 1
    if not counts:
        return ""
    return "|".join(f"{k}:{v}" for k, v in sorted(counts.items(), key=lambda item: (-item[1], item[0]))[:8])


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
        "symbol_distribution": distribution(rows, "symbol"),
        "direction_distribution": distribution(rows, "direction"),
        "session_distribution": distribution(rows, "session_label"),
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
    for report in (REPO / "reports" / "backtest").glob(f"{EA_NAME}_anchor_first_{run['run_id']}_report*"):
        shutil.copy2(report, run_dir / report.name.replace(f"{EA_NAME}_anchor_first_{run['run_id']}_", ""))


def csv_paths(run):
    folder = COMMON_FILES / run["log_folder"]
    scenario = run["scenario_name"]
    return {
        "trades": folder / f"fxsessionrev_{scenario}_trades.csv",
        "summary": folder / f"fxsessionrev_{scenario}_summary.csv",
    }


def add_derived_columns(row):
    row["year"] = year_key(row.get("entry_time"))
    row["month"] = month_key(row.get("entry_time"))
    row["mfe_r"] = row.get("max_favorable_r_before_exit", "")
    row["mae_r"] = row.get("max_adverse_r_before_exit", "")
    row["entry_timeframe"] = row.get("selected_candidate_timeframe") or row.get("ltf_wave3_timeframe")
    row["mfe_1r_bucket"] = "mfe_ge_1r" if bval(row.get("reached_1_0r")) else "mfe_lt_1r"
    row["mfe_13r_bucket"] = "mfe_ge_1_3r" if bval(row.get("reached_1_3r")) else "mfe_lt_1_3r"
    row["required_light_bucket"] = "required_light_pass" if bval(row.get("m15_required_light_pass")) else "required_light_reject"
    row["anchor_aligned_bucket"] = "anchor_aligned" if bval(row.get("m15_bias_aligned_with_entry")) else "anchor_not_aligned"
    row["anchor_opposite_bucket"] = "anchor_opposite" if bval(row.get("m15_bias_opposite_to_entry")) else "anchor_not_opposite"
    flip_dir = row.get("m15_bias_flip_direction")
    direction = row.get("direction")
    flip_entry = (direction == "LONG" and flip_dir == "LONG") or (direction == "SHORT" and flip_dir == "SHORT")
    row["anchor_flip_entry_bucket"] = "anchor_flip_entry_direction" if flip_entry else "no_anchor_flip_entry"
    row["anchor_flip_pullback_bucket"] = "true_post_anchor_pullback" if flip_entry and bval(row.get("post_anchor_pullback_gate_pass")) else ("flip_without_true_pullback" if flip_entry else "no_flip")
    if not bval(row.get("post_anchor_pullback_enabled")):
        row["post_anchor_pullback_bucket"] = "post_anchor_not_enabled"
        row["post_anchor_retest_bucket"] = "post_anchor_not_enabled"
        row["post_anchor_reconfirm_bucket"] = "post_anchor_not_enabled"
    else:
        row["post_anchor_pullback_bucket"] = "post_anchor_pullback_pass" if bval(row.get("post_anchor_pullback_gate_pass")) else "post_anchor_pullback_fail"
        row["post_anchor_retest_bucket"] = "post_anchor_retest" if bval(row.get("post_anchor_retest_detected")) else "no_post_anchor_retest"
        row["post_anchor_reconfirm_bucket"] = "post_anchor_m5_reconfirm" if bval(row.get("post_anchor_m5_reconfirm_detected")) else "no_post_anchor_m5_reconfirm"
    row["m15_bias_flip_age_bucket2"] = row.get("m15_bias_flip_age_bucket") or "none"
    old_age = fnum(row.get("m15_bias_flip_age_bars_old_like"))
    first_age = fnum(row.get("m15_bias_flip_age_bars_first_break") or row.get("m15_bias_flip_age_bars"))
    if old_age >= 0 and first_age >= 0:
        diff = first_age - old_age
        row["break_time_diff_bars"] = f"{diff:.0f}"
        if diff <= 0:
            row["break_time_diff_bucket"] = "same_or_reversed"
        elif diff <= 4:
            row["break_time_diff_bucket"] = "diff_1_4"
        elif diff <= 12:
            row["break_time_diff_bucket"] = "diff_5_12"
        elif diff <= 24:
            row["break_time_diff_bucket"] = "diff_13_24"
        else:
            row["break_time_diff_bucket"] = "diff_gt24"
    else:
        row["break_time_diff_bars"] = ""
        row["break_time_diff_bucket"] = "missing"
    max_age = fnum(row.get("InpM15BiasFlipMaxAgeBars")) or 24
    old_gate = flip_entry and old_age >= 0 and old_age <= max_age
    first_gate = flip_entry and first_age >= 0 and first_age <= max_age
    row["old_gate_pass"] = "true" if old_gate else "false"
    row["first_break_gate_pass"] = "true" if first_gate else "false"
    row["trade_taken_old_only"] = "true" if old_gate and not first_gate else "false"
    row["trade_taken_new_only"] = "true" if first_gate and not old_gate else "false"
    row["trade_taken_both"] = "true" if old_gate and first_gate else "false"
    row["trade_rejected_both"] = "true" if not old_gate and not first_gate else "false"
    pattern_quality = row.get("m5_pattern_quality_group") or "unknown"
    row["m5_high_medium_pattern_bucket"] = "m5_high_medium" if pattern_quality in {"high_quality", "medium_quality"} else "m5_low_or_unknown"
    exhaustion = row.get("m5_corrective_exhaustion_bucket") or "none"
    row["corrective_exhaustion_bucket2"] = "corrective_exhaustion" if exhaustion in {"strong_exhaustion", "mild_exhaustion"} else "no_corrective_exhaustion"
    row["range_bucket"] = "range_n" if row.get("m15_n_state") == "range_n" or bval(row.get("m15_range_detected")) else "not_range_n"
    if bval(row.get("m15_required_light_pass")) and bval(row.get("m15_bias_aligned_with_entry")):
        row["required_light_anchor_group"] = "required_light_and_anchor_aligned"
    elif bval(row.get("m15_required_light_pass")):
        row["required_light_anchor_group"] = "required_light_only"
    elif flip_entry:
        row["required_light_anchor_group"] = "required_light_reject_anchor_flip"
    elif bval(row.get("m15_bias_aligned_with_entry")):
        row["required_light_anchor_group"] = "required_light_reject_anchor_aligned"
    else:
        row["required_light_anchor_group"] = "neither_required_light_nor_anchor"


def write_breakdowns(all_trades):
    breakdowns = {
        "m15_anchor_bias_breakdown.csv": ["period_id", "variant", "m15_anchor_bias_state", "anchor_aligned_bucket", "anchor_opposite_bucket"],
        "m15_anchor_flip_breakdown.csv": ["period_id", "variant", "anchor_flip_entry_bucket", "m15_bias_flip_direction", "m15_bias_flip_age_bucket2", "anchor_flip_pullback_bucket"],
        "anchor_flip_age_diff_breakdown.csv": ["period_id", "variant", "m15_bias_flip_age_bucket2", "break_time_diff_bucket"],
        "post_anchor_pullback_breakdown.csv": ["period_id", "variant", "post_anchor_pullback_bucket", "post_anchor_retest_bucket", "post_anchor_reconfirm_bucket"],
        "post_anchor_retest_quality_breakdown.csv": ["period_id", "variant", "post_anchor_pullback_quality_bucket", "post_anchor_pullback_reject_reason"],
        "m15_anchor_by_required_light.csv": ["period_id", "variant", "required_light_bucket", "anchor_aligned_bucket", "anchor_flip_entry_bucket"],
        "m15_anchor_by_m5_pattern.csv": ["period_id", "variant", "m5_pattern_quality_group", "anchor_aligned_bucket", "anchor_flip_entry_bucket"],
        "m15_anchor_by_wave1_quality.csv": ["period_id", "variant", "m15_wave1_quality_bucket", "m15_wave1_quality_high", "anchor_aligned_bucket", "anchor_flip_entry_bucket"],
        "m15_anchor_by_corrective_exhaustion.csv": ["period_id", "variant", "corrective_exhaustion_bucket2", "anchor_aligned_bucket", "anchor_flip_entry_bucket"],
        "mfe_by_m15_anchor_state.csv": ["period_id", "variant", "m15_anchor_bias_state", "mfe_1r_bucket", "mfe_13r_bucket"],
        "m15_n_state_breakdown.csv": ["period_id", "variant", "m15_n_state", "range_bucket"],
        "anchor_break_quality_breakdown.csv": ["period_id", "variant", "anchor_break_quality_bucket", "m15_anchor_break_direction"],
        "entry_pattern_breakdown.csv": ["period_id", "variant", "entry_pattern", "entry_trigger"],
        "session_breakdown.csv": ["period_id", "variant", "session_label"],
        "symbol_breakdown.csv": ["period_id", "variant", "symbol"],
        "direction_breakdown.csv": ["period_id", "variant", "direction"],
        "monthly_breakdown.csv": ["period_id", "variant", "month"],
        "yearly_breakdown.csv": ["period_id", "variant", "year"],
    }
    for filename, keys in breakdowns.items():
        write_csv(OUT / filename, group_stats(all_trades, keys))


def write_anchor_diff_files(all_trades):
    fields = [
        "run_id", "period_id", "variant", "entry_time", "symbol", "direction",
        "old_latest_break_time", "first_break_time", "break_time_diff_bars",
        "break_time_diff_bucket", "old_flip_age", "first_break_flip_age",
        "old_gate_pass", "first_break_gate_pass", "trade_taken_old_only",
        "trade_taken_new_only", "trade_taken_both", "trade_rejected_both",
        "result_r", "mfe_r",
    ]
    rows = []
    for row in all_trades:
        rows.append({
            "run_id": row.get("run_id"),
            "period_id": row.get("period_id"),
            "variant": row.get("variant"),
            "entry_time": row.get("entry_time"),
            "symbol": row.get("symbol"),
            "direction": row.get("direction"),
            "old_latest_break_time": row.get("m15_anchor_latest_break_time"),
            "first_break_time": row.get("m15_anchor_first_break_time"),
            "break_time_diff_bars": row.get("break_time_diff_bars"),
            "break_time_diff_bucket": row.get("break_time_diff_bucket"),
            "old_flip_age": row.get("m15_bias_flip_age_bars_old_like"),
            "first_break_flip_age": row.get("m15_bias_flip_age_bars_first_break") or row.get("m15_bias_flip_age_bars"),
            "old_gate_pass": row.get("old_gate_pass"),
            "first_break_gate_pass": row.get("first_break_gate_pass"),
            "trade_taken_old_only": row.get("trade_taken_old_only"),
            "trade_taken_new_only": row.get("trade_taken_new_only"),
            "trade_taken_both": row.get("trade_taken_both"),
            "trade_rejected_both": row.get("trade_rejected_both"),
            "result_r": row.get("result_r"),
            "mfe_r": row.get("mfe_r"),
        })
    write_csv(OUT / "anchor_break_detection_diff.csv", rows, fields)
    write_csv(OUT / "old_vs_first_break_candidate_diff.csv", rows, fields)


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


def row_by_variant(full_rows, variant):
    return next((r for r in full_rows if r.get("variant") == variant), None)


def diagnostic_group(diag, predicate):
    return stats([r for r in diag if predicate(r)])


def write_summary(comparison, all_trades):
    full = [r for r in comparison if r.get("period_id") == "full2025_validation"]
    baseline = row_by_variant(full, "base")
    light = row_by_variant(full, "light")
    anchor_diag = [r for r in all_trades if r.get("run_id") == "full2025_anchor_diag_first_break"]
    flip_diag = diagnostic_group(anchor_diag, lambda r: r.get("anchor_flip_entry_bucket") == "anchor_flip_entry_direction")
    old_only_diag = diagnostic_group(anchor_diag, lambda r: bval(r.get("trade_taken_old_only")))
    new_only_diag = diagnostic_group(anchor_diag, lambda r: bval(r.get("trade_taken_new_only")))
    both_diag = diagnostic_group(anchor_diag, lambda r: bval(r.get("trade_taken_both")))
    diff_values = [fnum(r.get("break_time_diff_bars")) for r in anchor_diag if r.get("break_time_diff_bars") not in (None, "")]
    avg_diff = sum(diff_values) / len(diff_values) if diff_values else 0.0
    max_diff = max(diff_values) if diff_values else 0.0

    variants = {r.get("variant"): r for r in full}
    positive_100 = [r for r in full if fnum(r.get("trades")) >= 100 and fnum(r.get("profit_factor")) >= 1.05 and fnum(r.get("avg_r")) > 0]
    positive_fragments = [r for r in full if 50 <= fnum(r.get("trades")) < 200 and fnum(r.get("profit_factor")) >= 1.05 and fnum(r.get("avg_r")) > 0]
    near_200 = [r for r in full if fnum(r.get("trades")) >= 150 and fnum(r.get("profit_factor")) >= 1.0 and fnum(r.get("avg_r")) > -0.03]
    gate_pass = [r for r in full if bval(r.get("passed_2025_gate"))]
    reports_missing = [r.get("run_id") for r in full if not (OUT / r.get("run_id", "") / "report.html").exists()]

    lines = [
        "# M15 Anchor First-Break And True Pullback Validation",
        "",
        "## Scope",
        "- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`",
        "- Objective: fix M15 oshiyasu/modoritakane anchor break search from latest-near-entry to first-after-anchor, then test true post-break pullback/retest.",
        "- Anchor state uses confirmed M15 pivots and closed M15 bars. Entry gates use first-after-anchor break; latest-near-entry is diagnostic only.",
        "- MFE/result columns are used only by this analyzer, not by EA entry conditions.",
        "- Timeframe preset check: H1=`16385`, M15=`15`, M5=`5`; tester period remains M15 while EA scans `InpPrimaryEntryTF=PERIOD_M5` closed bars.",
        "- `range_n` was kept as diagnostic only in this matrix; no range-block candidate was promoted.",
        f"- MT5 HTML reports missing: {', '.join(reports_missing) if reports_missing else 'none'}.",
        "",
        "## Full-2025 Comparison",
    ]
    for key in [
        "base", "light", "anchor_diag_first_break", "anchor_flip_first_break",
        "anchor_flip_first_break_fresh", "anchor_pullback_diag",
        "anchor_pullback_required", "anchor_pullback_m5_reconfirm",
        "light_or_anchor_pullback", "light_or_anchor_pullback_m5pattern",
        "light_or_anchor_pullback_exhaustion", "one_anchor_pullback",
        "one_light_or_anchor_pullback",
    ]:
        lines.append(f"- {key}: {fmt(variants.get(key))}")

    lines += [
        "",
        "## Required Answers",
        f"1. baseline c10 reproduced: {fmt(baseline)}.",
        f"2. required-light reproduced: {fmt(light)}.",
        "3. FindM15AnchorBreak search-order fix implemented: yes; entry-side break uses `first_after_anchor`, while `m15_anchor_latest_break_time` keeps old/latest diagnostics.",
        f"4. old/latest vs first-after-anchor difference in diagnostic trades: n={len(diff_values)}, avg_diff={avg_diff:.1f} M15 bars, max_diff={max_diff:.0f} M15 bars; old_only={fmt(old_only_diag)}, first_only={fmt(new_only_diag)}, both={fmt(both_diag)}.",
        f"5. first-break anchor flip vs previous anchor flip: first-break required={fmt(variants.get('anchor_flip_first_break'))}; diagnostic flip group={fmt(flip_diag)}.",
        f"6. first break + fresh/normal age useful: {fmt(variants.get('anchor_flip_first_break_fresh'))}.",
        f"7. true post-break pullback/retest useful: diagnostic={fmt(variants.get('anchor_pullback_diag'))}; required={fmt(variants.get('anchor_pullback_required'))}.",
        f"8. true pullback + M5 reconfirm useful: {fmt(variants.get('anchor_pullback_m5_reconfirm'))}.",
        f"9. required-light OR true anchor pullback balanced count and expectancy: {fmt(variants.get('light_or_anchor_pullback'))}.",
        f"10. one-symbol combinations useful: one_anchor_pullback={fmt(variants.get('one_anchor_pullback'))}, one_light_or_anchor_pullback={fmt(variants.get('one_light_or_anchor_pullback'))}.",
        "11. range_n hard gate used: no. It remains diagnostic only in this run matrix.",
        f"12. MFE>=1R / MFE>=1.3R vs baseline: baseline={fmt(baseline)}, best positive fragments={', '.join(r.get('run_id') for r in positive_fragments) or 'none'}.",
        f"13. time_exit improved: baseline={fnum(baseline.get('time_exit_rate') if baseline else 0):.1%}, required-light={fnum(light.get('time_exit_rate') if light else 0):.1%}, true-pullback OR={fnum(variants.get('light_or_anchor_pullback', {}).get('time_exit_rate')):.1%}.",
        f"14. TP rate improved: baseline={fnum(baseline.get('tp_exit_rate') if baseline else 0):.1%}, required-light={fnum(light.get('tp_exit_rate') if light else 0):.1%}, true-pullback OR={fnum(variants.get('light_or_anchor_pullback', {}).get('tp_exit_rate')):.1%}.",
        "15. symbol/session/direction dependence: see `symbol_breakdown.csv`, `session_breakdown.csv`, and `direction_breakdown.csv`; promotion still requires no extreme concentration.",
        f"16. 100+ trades with PF>=1.05 and avg_R>0: {', '.join(r.get('run_id') for r in positive_100) or 'none'}.",
        f"17. 200+ trades near 2025 shallow gate: {', '.join(r.get('run_id') for r in near_200) or 'none'}.",
        f"18. 2025 shallow gate pass: {', '.join(r.get('run_id') for r in gate_pass) or 'none'}.",
        f"19. 3-year BT/OOS candidate: {'yes' if gate_pass else 'no; no 2025 shallow-gate candidate was promoted'}.",
        "",
        f"Research fragments 50-199 trades with PF>=1.05 and avg_R>0: {', '.join(r.get('run_id') for r in positive_fragments) or 'none'}.",
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
    write_breakdowns(all_trades)
    write_anchor_diff_files(all_trades)
    write_summary(comparison, all_trades)


if __name__ == "__main__":
    main()
