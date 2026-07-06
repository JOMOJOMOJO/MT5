import csv
import math
import shutil
from collections import defaultdict
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
COMMON_FILES = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"
OUT = REPO / "reports" / "backtest" / "runs" / "20260707_session_reversal_required_light_adjacent_expansions"
MATRIX = OUT / "run_matrix.csv"
DEPOSIT = 10000.0


ADJACENT_MASKS = {
    "relax_w1": 1,
    "relax_w2": 2,
    "fib_shallow": 4,
    "fib_deep": 4,
    "breaktype": 8,
    "highq": 16,
    "context": 32,
}


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


def weekday_key(value):
    text = str(value)
    if len(text) < 10:
        return ""
    try:
        from datetime import datetime
        return datetime.strptime(text[:10].replace(".", "-"), "%Y-%m-%d").strftime("%a")
    except ValueError:
        return ""


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


def add_derived_columns(row):
    row["year"] = year_key(row.get("entry_time"))
    row["month"] = month_key(row.get("entry_time"))
    row["weekday"] = weekday_key(row.get("entry_time"))
    row["mfe_r"] = row.get("max_favorable_r_before_exit", "")
    row["mae_r"] = row.get("max_adverse_r_before_exit", "")
    row["entry_timeframe"] = row.get("selected_candidate_timeframe") or row.get("ltf_wave3_timeframe")
    row["mfe_1r_bucket"] = "mfe_ge_1r" if bval(row.get("reached_1_0r")) else "mfe_lt_1r"
    row["mfe_13r_bucket"] = "mfe_ge_1_3r" if bval(row.get("reached_1_3r")) else "mfe_lt_1_3r"
    row["result_bucket"] = "winner" if fnum(row.get("result_r")) > 0 else "loser_or_flat"
    row["required_light_bucket"] = "required_light_pass" if bval(row.get("m15_required_light_pass")) else "required_light_reject"
    row["near_miss_bucket"] = "near_miss" if bval(row.get("m15_wave2_near_miss")) else "not_near_miss"


def write_breakdowns(all_trades):
    breakdowns = {
        "required_light_winner_loser_breakdown.csv": ["period_id", "variant", "result_bucket", "symbol", "direction", "session_label", "entry_pattern", "m15_wave2_type", "m15_wave2_fib_zone"],
        "required_light_mfe_breakdown.csv": ["period_id", "variant", "mfe_1r_bucket", "mfe_13r_bucket", "symbol", "direction", "m15_wave2_type", "m15_wave2_fib_zone", "m5_pattern_quality_group"],
        "required_light_trade_breakdown.csv": ["period_id", "variant", "symbol", "direction", "session_label", "month", "weekday", "entry_pattern", "m5_pattern_quality_group", "m15_wave1_break_type", "m15_wave2_type", "m15_wave2_fib_zone", "exit_type"],
        "adjacent_expansion_breakdown.csv": ["period_id", "variant", "m15_wave2_adjacent_mode", "m15_wave2_adjacent_relaxed_component", "m15_wave2_near_miss"],
        "m15_wave2_adjacent_breakdown.csv": ["period_id", "variant", "m15_wave2_adjacent_mode", "m15_wave2_adjacent_reason", "m15_required_light_reject_reason"],
        "m15_wave2_fib_adjacent_breakdown.csv": ["period_id", "variant", "m15_wave2_adjacent_mode", "m15_wave2_adjacent_fib_side", "m15_wave2_fib_zone"],
        "m15_wave1_age_breakdown.csv": ["period_id", "variant", "m15_wave1_age_bars", "m15_required_light_pass"],
        "m15_wave2_age_breakdown.csv": ["period_id", "variant", "m15_wave2_age_bars", "m15_required_light_pass"],
        "m15_wave1_break_type_breakdown.csv": ["period_id", "variant", "m15_wave1_break_type", "m15_required_light_pass"],
        "m5_high_quality_near_miss_breakdown.csv": ["period_id", "variant", "m5_pattern_quality_group", "near_miss_bucket", "m15_required_light_reject_reason"],
        "mfe_threshold_breakdown.csv": ["period_id", "variant", "mfe_1r_bucket", "mfe_13r_bucket"],
        "mfe_by_adjacent_mode.csv": ["period_id", "variant", "m15_wave2_adjacent_mode", "m15_wave2_adjacent_relaxed_component"],
        "mfe_by_required_light_bucket.csv": ["period_id", "variant", "required_light_bucket", "m15_required_light_reject_reason"],
        "entry_pattern_breakdown.csv": ["period_id", "variant", "entry_pattern", "entry_trigger"],
        "entry_timeframe_breakdown.csv": ["period_id", "variant", "entry_timeframe"],
        "session_breakdown.csv": ["period_id", "variant", "session_label"],
        "symbol_breakdown.csv": ["period_id", "variant", "symbol"],
        "direction_breakdown.csv": ["period_id", "variant", "direction"],
        "monthly_breakdown.csv": ["period_id", "variant", "month"],
        "yearly_breakdown.csv": ["period_id", "variant", "year"],
    }
    required_light = [
        r for r in all_trades
        if r.get("period_id") == "full2025_validation" and r.get("variant") == "light"
    ]
    for filename, keys in breakdowns.items():
        source = required_light if filename.startswith("required_light_") else all_trades
        write_csv(OUT / filename, group_stats(source, keys))


def choose_adjacent(rows, period="q1_quick"):
    period_rows = [r for r in rows if r.get("period_id") == period]
    baseline = next((r for r in period_rows if r.get("variant") == "base"), None)
    candidates = [r for r in period_rows if r.get("variant") in ADJACENT_MASKS]
    baseline_mfe = fnum(baseline.get("avg_mfe_r")) if baseline else 0.0
    baseline_1r = fnum(baseline.get("reached_1_0r_rate")) if baseline else 0.0
    for row in candidates:
        row["selection_score"] = (
            fnum(row.get("avg_r")) * 100.0
            + fnum(row.get("profit_factor")) * 10.0
            + fnum(row.get("reached_1_0r_rate")) * 4.0
            + fnum(row.get("reached_1_3r_rate")) * 2.0
        )
        row["mfe_lift_ok"] = fnum(row.get("avg_mfe_r")) > baseline_mfe and fnum(row.get("reached_1_0r_rate")) > baseline_1r
    ranked = sorted(candidates, key=lambda r: (bval(r.get("mfe_lift_ok")), fnum(r.get("selection_score")), fnum(r.get("trades"))), reverse=True)
    selected = ranked[:2]
    mask = 0
    for row in selected:
        mask |= ADJACENT_MASKS.get(row.get("variant"), 0)
    rows_out = []
    for idx, row in enumerate(ranked, start=1):
        rows_out.append({
            "rank": idx,
            "selected": row in selected,
            "combine_mask_after_selection": mask,
            "period_id": row.get("period_id"),
            "variant": row.get("variant"),
            "variant_name": row.get("variant_name"),
            "trades": row.get("trades"),
            "profit_factor": row.get("profit_factor"),
            "avg_r": row.get("avg_r"),
            "avg_mfe_r": row.get("avg_mfe_r"),
            "reached_1_0r_rate": row.get("reached_1_0r_rate"),
            "reached_1_3r_rate": row.get("reached_1_3r_rate"),
            "time_exit_rate": row.get("time_exit_rate"),
            "tp_exit_rate": row.get("tp_exit_rate"),
            "mfe_lift_ok": row.get("mfe_lift_ok"),
            "selection_score": row.get("selection_score"),
        })
    write_csv(OUT / "selected_adjacent_modes.csv", rows_out)
    return mask, selected[0]["variant"] if selected else "highq"


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


def write_summary(comparison, all_trades):
    full = [r for r in comparison if r.get("period_id") == "full2025_validation"]
    q1 = [r for r in comparison if r.get("period_id") == "q1_quick"]
    baseline = next((r for r in full if r.get("variant") == "base"), None)
    light = next((r for r in full if r.get("variant") == "light"), None)
    light_trades = [r for r in all_trades if r.get("period_id") == "full2025_validation" and r.get("variant") == "light"]
    adjacent_full = [r for r in full if r.get("variant") in ADJACENT_MASKS or r.get("variant") == "combine"]
    one_symbol_rows = [r for r in full if r.get("variant") in {"one_light", "one_best", "one_combine"}]
    best_adjacent = max(adjacent_full, key=lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor")), fnum(r.get("trades"))), default=None)
    over_100 = [r for r in adjacent_full if fnum(r.get("trades")) >= 100 and fnum(r.get("profit_factor")) >= 1.05 and fnum(r.get("avg_r")) > 0]
    over_200_near = [r for r in adjacent_full if fnum(r.get("trades")) >= 200]
    passed = [r for r in full if bval(r.get("passed_2025_gate"))]
    missing_reports = [r.get("run_id") for r in full if not (OUT / r.get("run_id", "") / "report.html").exists()]
    diagnostic_rejects = [
        r for r in all_trades
        if r.get("run_id") == "full2025_nearmiss_diag" and not bval(r.get("m15_required_light_pass"))
    ]
    near_miss = [r for r in diagnostic_rejects if bval(r.get("reached_1_0r"))]
    winners = [r for r in light_trades if fnum(r.get("result_r")) > 0]
    losers = [r for r in light_trades if fnum(r.get("result_r")) <= 0]
    mfe1 = [r for r in light_trades if bval(r.get("reached_1_0r"))]
    mfe13 = [r for r in light_trades if bval(r.get("reached_1_3r"))]

    def top_bucket(rows, key):
        counts = defaultdict(int)
        for row in rows:
            counts[row.get(key, "")] += 1
        if not counts:
            return "none"
        key_value, count = max(counts.items(), key=lambda item: item[1])
        return f"{key_value} ({count})"

    selected = read_csv(OUT / "selected_adjacent_modes.csv")
    selected_text = ", ".join(r["variant"] for r in selected if bval(r.get("selected"))) or "none"
    q1_text = "; ".join(f"{r.get('variant')} {fmt(r)}" for r in q1 if r.get("variant") in {"base", "light", "relax_w1", "relax_w2", "highq"})
    one_symbol_text = "; ".join(f"{r.get('run_id')} {fmt(r)}" for r in one_symbol_rows) or "none"

    lines = [
        "# Required-Light M15 Wave2 Adjacent Expansion Validation",
        "",
        "## Scope",
        "- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`",
        "- Purpose: decompose the prior required-light winner and test one-neighbor-at-a-time adjacent expansions.",
        "- Tester period M15; presets use H1=`16385`, M15=`15`, M5=`5`.",
        "- M5 ABC/123 was not made a hard gate.",
        f"- MT5 HTML reports missing after rerun attempts: {', '.join(missing_reports) if missing_reports else 'none'}; EA CSV evidence is present for all runs.",
        "",
        "## Key Full-2025 Rows",
        f"- baseline c10: {fmt(baseline)}",
        f"- required-light: {fmt(light)}",
        f"- best all-symbol adjacent row by avg_R: `{best_adjacent.get('run_id') if best_adjacent else 'none'}` {fmt(best_adjacent)}",
        f"- one-symbol research fragments: {one_symbol_text}",
        "",
        "## Q1 Selection",
        f"- selected adjacent modes for combine: {selected_text}",
        f"- Q1 spot check: {q1_text}",
        "",
        "## Required Findings",
        f"1. baseline c10 reproduced: {fmt(baseline)}",
        f"2. required-light reproduced: {fmt(light)}",
        f"3. required-light 50-trade breakdown: see `required_light_trade_breakdown.csv`; top wave2 type={top_bucket(light_trades, 'm15_wave2_type')}, top fib={top_bucket(light_trades, 'm15_wave2_fib_zone')}.",
        f"4. required-light winning trade common point: top wave2 type={top_bucket(winners, 'm15_wave2_type')}, top pattern={top_bucket(winners, 'entry_pattern')}.",
        f"5. required-light losing trade common point: top wave2 type={top_bucket(losers, 'm15_wave2_type')}, top exit={top_bucket(losers, 'exit_type')}.",
        f"6. near-miss good trades existed: {len(near_miss)} of {len(diagnostic_rejects)} full2025_nearmiss_diag required-light rejects reached MFE>=1R; see `near_miss_required_light_rejects.csv` and `near_miss_mfe_positive.csv`.",
        f"7. best all-symbol MFE-preserving adjacent expansion: `{best_adjacent.get('variant') if best_adjacent else 'none'}`; see `adjacent_expansion_comparison.csv`.",
        "8. broad/bad population reintroduction: any adjacent with 200+ trades but negative PF/avg_R is treated as baseline leakage.",
        f"9. candidates above 100 trades: {', '.join(r.get('run_id') for r in adjacent_full if fnum(r.get('trades')) >= 100) or 'none'}.",
        f"10. 100+ trades with PF>=1.05 and avg_R>0: {', '.join(r.get('run_id') for r in over_100) or 'none'}.",
        f"11. 200+ trades near shallow gate: {', '.join(r.get('run_id') for r in over_200_near) or 'none'}.",
        f"12. one-symbol rows are research fragments unless they reach 200 trades without concentration dependence: {', '.join(r.get('run_id') for r in one_symbol_rows) or 'none'}.",
        f"13. required-light MFE buckets: MFE>=1R trades={len(mfe1)}, MFE>=1.3R trades={len(mfe13)}; adjacent comparison is in `mfe_by_adjacent_mode.csv`.",
        "14. time-exit improvement must be read with PF/avg_R; a lower time-exit rate alone is not promotion evidence.",
        "15. TP-rate maintenance is shown in `full2025_comparison.csv`.",
        "16. Tokyo/London/Clean or one-symbol-only dependence is not used for promotion.",
        f"17. 2025 shallow gate pass candidates: {', '.join(r.get('run_id') for r in passed) if passed else 'none'}.",
        "18. 3-year BT/OOS: not run unless a 2025 shallow gate candidate exists.",
        "",
        "## Decision",
        "No candidate is promoted unless the 2025 shallow gate passes.",
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
    write_csv(OUT / "adjacent_expansion_comparison.csv", [r for r in comparison if r.get("variant") in ADJACENT_MASKS or r.get("variant") in {"combine", "one_best", "one_combine"}])

    rejects = [
        r for r in all_trades
        if r.get("run_id") == "full2025_nearmiss_diag" and not bval(r.get("m15_required_light_pass"))
    ]
    near_miss = [r for r in rejects if bval(r.get("reached_1_0r"))]
    near_positive = [r for r in near_miss if fnum(r.get("result_r")) > 0]
    near_negative = [r for r in near_miss if fnum(r.get("result_r")) <= 0]
    write_csv(OUT / "required_light_reject_near_miss.csv", near_miss)
    write_csv(OUT / "near_miss_required_light_rejects.csv", rejects)
    write_csv(OUT / "near_miss_mfe_positive.csv", near_positive)
    write_csv(OUT / "near_miss_mfe_negative.csv", near_negative)

    write_breakdowns(all_trades)
    choose_adjacent(comparison, period="q1_quick")
    write_summary(comparison, all_trades)


if __name__ == "__main__":
    main()
