import csv
import math
import shutil
from collections import defaultdict
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
COMMON_FILES = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"
OUT = REPO / "reports" / "backtest" / "runs" / "20260627_session_reversal_pullback_htf_alignment_be_diagnostics"
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
MATRIX = REPO / "reports" / "backtest" / f"{EA_NAME}_alignment_be_run_matrix_2025.csv"
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
    mfes = [fnum(r.get("max_favorable_r_before_exit")) for r in rows]
    maes = [fnum(r.get("max_adverse_r_before_exit")) for r in rows]
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
    be_exit = sum(1 for r in rows if bval(r.get("break_even_exit")))
    tp_exit = sum(1 for r in rows if bval(r.get("tp_exit")))
    time_exit = sum(1 for r in rows if bval(r.get("time_exit")))
    be_triggered = sum(1 for r in rows if bval(r.get("break_even_triggered")))
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
        "break_even_triggered": be_triggered,
        "break_even_trigger_rate": be_triggered / count if count else 0.0,
        "break_even_exits": be_exit,
        "break_even_exit_rate": be_exit / count if count else 0.0,
        "tp_exits": tp_exit,
        "tp_exit_rate": tp_exit / count if count else 0.0,
        "time_exits": time_exit,
        "time_exit_rate": time_exit / count if count else 0.0,
        "avg_mfe_r": sum(mfes) / count if count else 0.0,
        "avg_mae_r": sum(maes) / count if count else 0.0,
    }


def group_stats(rows, keys):
    groups = defaultdict(list)
    for row in rows:
        groups[tuple(row.get(k, "") for k in keys)].append(row)
    out = []
    for key_values, values in sorted(groups.items()):
        row = {k: v for k, v in zip(keys, key_values)}
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
    if len(text) >= 4:
        return text[:4]
    return ""


def concentration_ok(rows, key):
    if not rows:
        return False
    total_net = sum(max(0.0, fnum(r.get("net_profit"))) for r in rows)
    if total_net <= 0:
        return False
    groups = defaultdict(float)
    for row in rows:
        groups[row.get(key, "")] += max(0.0, fnum(row.get("net_profit")))
    return max(groups.values()) / total_net <= 0.70


def directional_ok(rows):
    long_rows = [r for r in rows if r.get("direction") == "LONG"]
    short_rows = [r for r in rows if r.get("direction") == "SHORT"]
    if not long_rows or not short_rows:
        return False
    return stats(long_rows)["avg_r"] >= -0.20 and stats(short_rows)["avg_r"] >= -0.20


def gate_scope(row):
    return row["scenario_id"] in {"all_first120", "one_first120", "clean_first120"}


def copy_artifacts(run):
    run_id = run["run_id"]
    run_dir = OUT / run_id
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


def run_folder(run):
    return COMMON_FILES / f"fx_session_reversal_be_{run['run_id']}_2025"


def csv_names(run):
    scenario_name = run["scenario_name"]
    folder = run_folder(run)
    return {
        "signals": folder / f"fxsessionrev_{scenario_name}_signals.csv",
        "trades": folder / f"fxsessionrev_{scenario_name}_trades.csv",
        "summary": folder / f"fxsessionrev_{scenario_name}_summary.csv",
    }


def best_row(rows, where=lambda r: True, key=lambda r: fnum(r.get("avg_r"))):
    candidates = [r for r in rows if where(r)]
    if not candidates:
        return None
    return max(candidates, key=key)


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
        run_dir = OUT / run["run_id"]
        for label, path in paths.items():
            if path.exists():
                shutil.copy2(path, run_dir / f"{label}.csv")

        signals = read_csv(paths["signals"], encoding="mbcs")
        trades = read_csv(paths["trades"], encoding="mbcs")
        summary_rows = read_csv(paths["summary"], encoding="mbcs")

        for row in signals:
            row.update(run)
            all_signals.append(row)
        for row in trades:
            row.update(run)
            row["year"] = year_key(row.get("entry_time"))
            row["month"] = month_key(row.get("entry_time"))
            row["symbol_break_even"] = f"{row.get('symbol', '')}|{row.get('break_even_mode', run['break_even_mode'])}"
            row["session_break_even"] = f"{row.get('session_label', '')}|{row.get('break_even_mode', run['break_even_mode'])}"
            row["entry_pattern_break_even"] = f"{row.get('entry_pattern', '')}|{row.get('break_even_mode', run['break_even_mode'])}"
            all_trades.append(row)

        s = stats(trades)
        dd_stopped = False
        if summary_rows:
            dd_stopped = bval(summary_rows[-1].get("drawdown_stopped")) or bval(summary_rows[-1].get("daily_stopped"))
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
            "daily_or_dd_stopped": dd_stopped,
            "gate_scope": gate_scope(run),
            "passed_2025_shallow_gate": passed,
        })

    write_csv(OUT / "comparison.csv", comparison)
    write_csv(OUT / "trades_all_scenarios.csv", all_trades)
    write_csv(OUT / "signals_all_scenarios.csv", all_signals)

    write_csv(OUT / "htf_alignment_mode_breakdown.csv", group_stats(all_trades, ["scenario_id", "htf_alignment_mode"]))
    write_csv(OUT / "break_even_mode_breakdown.csv", group_stats(all_trades, ["scenario_id", "break_even_mode"]))
    write_csv(OUT / "exit_type_breakdown.csv", group_stats(all_trades, ["scenario_id", "htf_alignment_mode", "break_even_mode", "exit_type"]))
    write_csv(OUT / "mfe_mae_breakdown.csv", group_stats(all_trades, ["scenario_id", "htf_alignment_mode", "break_even_mode"]))
    write_csv(OUT / "session_break_even_breakdown.csv", group_stats(all_trades, ["scenario_id", "htf_alignment_mode", "session_label", "break_even_mode"]))
    write_csv(OUT / "symbol_break_even_breakdown.csv", group_stats(all_trades, ["scenario_id", "htf_alignment_mode", "symbol", "break_even_mode"]))
    write_csv(OUT / "entry_pattern_break_even_breakdown.csv", group_stats(all_trades, ["scenario_id", "htf_alignment_mode", "entry_pattern", "break_even_mode"]))
    write_csv(OUT / "yearly_breakdown.csv", group_stats(all_trades, ["run_id", "year"]))
    write_csv(OUT / "monthly_breakdown.csv", group_stats(all_trades, ["run_id", "month"]))

    r_rows = []
    grouped = defaultdict(list)
    for row in all_trades:
        grouped[row["run_id"]].append(row)
    for run_id, rows in sorted(grouped.items()):
        rvals = sorted(fnum(r.get("result_r")) for r in rows)
        s = stats(rows)
        median = rvals[len(rvals) // 2] if rvals else 0.0
        p10 = rvals[int(len(rvals) * 0.10)] if rvals else 0.0
        p90 = rvals[int(len(rvals) * 0.90)] if rvals else 0.0
        meta = next((r for r in matrix if r["run_id"] == run_id), {})
        r_rows.append({**meta, "median_r": median, "p10_r": p10, "p90_r": p90, **s})
    write_csv(OUT / "r_metrics.csv", r_rows)

    compile_log = REPO / "reports" / "compile" / f"{EA_NAME}_compile.txt"
    if compile_log.exists():
        shutil.copy2(compile_log, OUT / "compile.log")

    strict_all = next((r for r in comparison if r["scenario_id"] == "all_first120" and r["htf_alignment_id"] == "strict" and r["break_even_id"] == "no_be"), None)
    soft_all = next((r for r in comparison if r["scenario_id"] == "all_first120" and r["htf_alignment_id"] == "soft" and r["break_even_id"] == "no_be"), None)
    all_no_be_by_alignment = {
        row["htf_alignment_id"]: row
        for row in comparison
        if row["scenario_id"] == "all_first120" and row["break_even_id"] == "no_be"
    }
    alignment_order = ["strict", "h4_bias_h1_rev", "h1_conf_h4_notopp", "soft"]
    all_alignment_summary = "; ".join(
        f"{key}={all_no_be_by_alignment[key]['trades']} trades PF={all_no_be_by_alignment[key]['profit_factor']:.2f} avg_R={all_no_be_by_alignment[key]['avg_r']:.4f}"
        for key in alignment_order
        if key in all_no_be_by_alignment
    )
    all_count_recovery_rows = [
        row for row in comparison
        if row["scenario_id"] == "all_first120" and row["break_even_id"] == "no_be" and fnum(row.get("trades")) >= 200
    ]
    best_all_count_recovery = best_row(
        all_count_recovery_rows,
        key=lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor"))),
    )
    best_all_trade_count = best_row(
        comparison,
        lambda r: r["scenario_id"] == "all_first120" and fnum(r.get("trades")) >= 200,
        lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor"))),
    )
    best_nobe_integrated = best_row(
        comparison,
        lambda r: r["scenario_id"] in {"all_first120", "one_first120", "clean_first120"} and r["break_even_id"] == "no_be",
        lambda r: (fnum(r.get("avg_r")), fnum(r.get("trades"))),
    )
    best_integrated = best_row(
        comparison,
        lambda r: r["scenario_id"] in {"all_first120", "one_first120", "clean_first120"},
        lambda r: (bval(r.get("passed_2025_shallow_gate")), fnum(r.get("avg_r")), fnum(r.get("trades"))),
    )
    best_be = best_row(
        comparison,
        lambda r: r["break_even_id"] != "no_be" and r["scenario_id"] in {"all_first120", "one_first120", "clean_first120"},
        lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor"))),
    )
    london_no_be = [r for r in comparison if r["scenario_id"] == "london_first120" and r["break_even_id"] == "no_be"]
    london_best_be = best_row(
        comparison,
        lambda r: r["scenario_id"] == "london_first120" and r["break_even_id"] != "no_be",
        lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor"))),
    )
    london_best_no_be = best_row(london_no_be, key=lambda r: fnum(r.get("avg_r")))
    passed = [r for r in comparison if bval(r.get("passed_2025_shallow_gate"))]

    be_summary = group_stats(all_trades, ["break_even_mode"])
    best_be_mode = best_row(be_summary, lambda r: r["break_even_mode"] != "no_break_even", lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor"))))
    no_be_summary = next((r for r in be_summary if r["break_even_mode"] == "no_break_even"), None)
    all_be_summary = group_stats([r for r in all_trades if r.get("scenario_id") == "all_first120"], ["break_even_mode"])
    all_best_be_mode = best_row(
        all_be_summary,
        lambda r: r["break_even_mode"] != "no_break_even",
        lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor"))),
    )
    all_no_be_summary = next((r for r in all_be_summary if r["break_even_mode"] == "no_break_even"), None)

    lines = [
        "# Session Reversal Pullback HTF Alignment and Break-Even Diagnostics",
        "",
        "## Implementation",
        "- Compared four coarse HTF alignment modes without symbol, direction, weekday, or fine threshold rescue.",
        "- Compared four break-even modes: no BE, +1.0R close, +1.1R close, and 30min/+0.5R or +1.0R close.",
        "- Break-even triggers use M15 closed-bar close only; intrabar high/low is not used to trigger BE.",
        "- MFE/MAE are diagnostic values from closed bars and exit price.",
        "",
        "## Required Answers",
    ]
    if strict_all and soft_all:
        lines.append(f"1. Trade-count drop cause: yes for trade count. all_symbols no_BE was {all_alignment_summary}. Strict H4/H1 hard alignment was the main throttle, but not the reason expectancy was negative.")
        if best_all_count_recovery:
            lines.append(f"2. Relaxed alignment recovery: yes, all_symbols no_BE recovered beyond 200 trades under relaxed modes; best recovered no_BE row was `{best_all_count_recovery['run_id']}` with {best_all_count_recovery['trades']} trades, PF={best_all_count_recovery['profit_factor']:.2f}, avg_R={best_all_count_recovery['avg_r']:.4f}.")
        else:
            lines.append("2. Relaxed alignment recovery: no no_BE all_symbols relaxed mode reached 200 trades.")
    else:
        lines.append("1. Trade-count drop cause: strict/soft all_symbols comparison was unavailable.")
        lines.append("2. Relaxed alignment recovery: unavailable.")
    if best_all_trade_count:
        if fnum(best_all_trade_count.get("avg_r")) > 0 and fnum(best_all_trade_count.get("profit_factor")) >= 1.05:
            lines.append(f"3. Expectancy-preserving alignment relaxation: candidate `{best_all_trade_count['run_id']}` trades={best_all_trade_count['trades']} PF={best_all_trade_count['profit_factor']:.2f} avg_R={best_all_trade_count['avg_r']:.4f}.")
        else:
            lines.append(f"3. Expectancy-preserving alignment relaxation: none. Best all_symbols row with >=200 trades was `{best_all_trade_count['run_id']}` trades={best_all_trade_count['trades']} PF={best_all_trade_count['profit_factor']:.2f} avg_R={best_all_trade_count['avg_r']:.4f}, still negative.")
    elif best_nobe_integrated:
        lines.append(f"3. Best no_BE gate-scope row was `{best_nobe_integrated['run_id']}` trades={best_nobe_integrated['trades']} PF={best_nobe_integrated['profit_factor']:.2f} avg_R={best_nobe_integrated['avg_r']:.4f}.")
    if all_no_be_summary and all_best_be_mode:
        lines.append(f"4. Full SL reduction: all_symbols no_BE full_sl_rate={all_no_be_summary['full_sl_rate']:.2%}; best all_symbols BE mode `{all_best_be_mode['break_even_mode']}` full_sl_rate={all_best_be_mode['full_sl_rate']:.2%}. Time-based BE reduced full SL most but increased BE exits and did not improve expectancy.")
        lines.append(f"5. BE effect: best all_symbols BE by avg_R/PF was `{all_best_be_mode['break_even_mode']}` avg_R={all_best_be_mode['avg_r']:.4f}, PF={all_best_be_mode['profit_factor']:.2f}, MaxDD={all_best_be_mode['max_dd_profit']:.2f}; all_symbols no_BE avg_R={all_no_be_summary['avg_r']:.4f}, PF={all_no_be_summary['profit_factor']:.2f}, MaxDD={all_no_be_summary['max_dd_profit']:.2f}.")
        lines.append(f"6. BE exits: best all_symbols BE break_even_exit_rate={all_best_be_mode['break_even_exit_rate']:.2%}. Time-based BE had {next((r['break_even_exit_rate'] for r in all_be_summary if r['break_even_mode'] == 'time_30min_and_0_5r_break_even'), 0.0):.2%} BE exits and lower TP rate, so it likely cut winners too often.")
        lines.append(f"7. Best BE mode by all_symbols avg_R/PF: `{all_best_be_mode['break_even_mode']}`. Across all scenarios, best aggregate BE bucket was `{best_be_mode['break_even_mode'] if best_be_mode else 'none'}`.")
    if london_best_no_be and london_best_be:
        lines.append(f"8. London first120: best no_BE `{london_best_no_be['run_id']}` avg_R={london_best_no_be['avg_r']:.4f}, PF={london_best_no_be['profit_factor']:.2f}, trades={london_best_no_be['trades']}; best BE `{london_best_be['run_id']}` avg_R={london_best_be['avg_r']:.4f}, PF={london_best_be['profit_factor']:.2f}, trades={london_best_be['trades']}.")
    lines.append(f"9. 2025 shallow gate pass candidates: {', '.join(r['run_id'] for r in passed) if passed else 'none'}.")
    if passed:
        lines.append("10. 3-year fixed BT/OOS: advance only the listed gate-pass candidates.")
    else:
        lines.append("10. 3-year fixed BT/OOS: no candidate advances.")

    if best_integrated:
        lines.extend([
            "",
            "## Best Gate-Scope Row Before Trade-Count Gate",
            f"- `{best_integrated['run_id']}` trades={best_integrated['trades']} PF={best_integrated['profit_factor']:.2f} avg_R={best_integrated['avg_r']:.4f} net={best_integrated['net_profit']:.2f} MaxDD={best_integrated['max_dd_profit']:.2f}. This is not a live/fixed-BT candidate when trades are below 200.",
        ])

    lines.extend([
        "",
        "## Evidence",
        "- `comparison.csv`",
        "- `htf_alignment_mode_breakdown.csv`",
        "- `break_even_mode_breakdown.csv`",
        "- `exit_type_breakdown.csv`",
        "- `mfe_mae_breakdown.csv`",
        "- `session_break_even_breakdown.csv`",
        "- `symbol_break_even_breakdown.csv`",
        "- `entry_pattern_break_even_breakdown.csv`",
    ])
    (OUT / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
