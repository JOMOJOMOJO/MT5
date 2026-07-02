import csv
import math
import shutil
from collections import defaultdict
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
COMMON_FILES = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"
OUT = REPO / "reports" / "backtest" / "runs" / "20260702_session_reversal_transcript_nested_thirdwave"
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
            for key in row.keys():
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
    be_exit = sum(1 for r in rows if bval(r.get("break_even_exit")))
    tp_exit = sum(1 for r in rows if bval(r.get("tp_exit")))
    time_exit = sum(1 for r in rows if bval(r.get("time_exit")))
    mfes = [fnum(r.get("max_favorable_r_before_exit")) for r in rows]
    maes = [fnum(r.get("max_adverse_r_before_exit")) for r in rows]
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
    for source in [
        REPO / run["tester_ini"],
        REPO / run["preset"],
    ]:
        if source.exists():
            shutil.copy2(source, run_dir / ("tester.ini" if source.suffix == ".ini" else "preset.set"))
    for report in (REPO / "reports" / "backtest").glob(f"{EA_NAME}_{run_id}_report*"):
        short_name = report.name.replace(f"{EA_NAME}_{run_id}_", "")
        shutil.copy2(report, run_dir / short_name)


def run_folder(run):
    return COMMON_FILES / run["log_folder"]


def csv_paths(run):
    folder = run_folder(run)
    scenario = "session_reversal_pullback_all_symbols_first120"
    return {
        "signals": folder / f"fxsessionrev_{scenario}_signals.csv",
        "trades": folder / f"fxsessionrev_{scenario}_trades.csv",
        "summary": folder / f"fxsessionrev_{scenario}_summary.csv",
    }


def best_row(rows):
    rows = [row for row in rows if fnum(row.get("trades")) > 0]
    if not rows:
        return None
    return max(rows, key=lambda r: (fnum(r.get("avg_r")), fnum(r.get("profit_factor")), fnum(r.get("trades"))))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    matrix = read_csv(MATRIX)
    all_trades = []
    all_signals = []
    comparison = []

    for run in matrix:
        paths = csv_paths(run)
        copy_artifacts(run)
        run_dir = OUT / run["run_id"]
        for label, path in paths.items():
            if path.exists():
                shutil.copy2(path, run_dir / f"{label}.csv")

        trades = read_csv(paths["trades"], encoding="mbcs")
        signals = read_csv(paths["signals"], encoding="mbcs")
        summary = read_csv(paths["summary"], encoding="mbcs")
        for row in trades:
            row.update(run)
            row["year"] = year_key(row.get("entry_time"))
            row["month"] = month_key(row.get("entry_time"))
            all_trades.append(row)
        for row in signals:
            row.update(run)
            all_signals.append(row)

        run_stats = stats(trades)
        stopped = False
        if summary:
            stopped = bval(summary[-1].get("daily_stopped")) or bval(summary[-1].get("drawdown_stopped"))
        projected_year_trades = run_stats["trades"] * 12
        passed_search = (
            run_stats["trades"] >= 15
            and run_stats["profit_factor"] >= 1.05
            and run_stats["avg_r"] > 0.0
            and run_stats["net_profit"] > 0.0
            and not stopped
            and directional_ok(trades)
            and concentration_ok(trades, "symbol")
        )
        comparison.append({
            **run,
            **run_stats,
            "projected_year_trades": projected_year_trades,
            "daily_or_dd_stopped": stopped,
            "passed_jan_search_gate": passed_search,
        })

    write_csv(OUT / "comparison.csv", comparison)
    write_csv(OUT / "trades_all_scenarios.csv", all_trades)
    write_csv(OUT / "signals_all_scenarios.csv", all_signals)
    write_csv(OUT / "symbol_breakdown.csv", group_stats(all_trades, ["run_id", "symbol"]))
    write_csv(OUT / "direction_breakdown.csv", group_stats(all_trades, ["run_id", "direction"]))
    write_csv(OUT / "session_breakdown.csv", group_stats(all_trades, ["run_id", "session_label"]))
    write_csv(OUT / "entry_pattern_breakdown.csv", group_stats(all_trades, ["run_id", "entry_pattern", "entry_trigger"]))
    write_csv(OUT / "transcript_stage_breakdown.csv", group_stats(all_trades, ["run_id", "transcript_context_mode", "transcript_stage"]))
    write_csv(OUT / "sma75_breakdown.csv", group_stats(all_trades, ["run_id", "top_sma75_state", "structure_sma75_state", "primary_sma75_state"]))
    write_csv(OUT / "exit_type_breakdown.csv", group_stats(all_trades, ["run_id", "exit_type"]))
    write_csv(OUT / "failure_type_breakdown.csv", group_stats(all_trades, ["run_id", "failure_type"]))
    write_csv(OUT / "monthly_breakdown.csv", group_stats(all_trades, ["run_id", "month"]))
    write_csv(OUT / "yearly_breakdown.csv", group_stats(all_trades, ["run_id", "year"]))

    r_rows = []
    by_run = defaultdict(list)
    for row in all_trades:
        by_run[row["run_id"]].append(row)
    for run_id, rows in sorted(by_run.items()):
        rvals = sorted(fnum(r.get("result_r")) for r in rows)
        row = {"run_id": run_id}
        if rvals:
            row.update({
                "median_r": rvals[len(rvals) // 2],
                "p10_r": rvals[int(len(rvals) * 0.10)],
                "p90_r": rvals[int(len(rvals) * 0.90)],
            })
        else:
            row.update({"median_r": 0.0, "p10_r": 0.0, "p90_r": 0.0})
        row.update(stats(rows))
        r_rows.append(row)
    write_csv(OUT / "r_metrics.csv", r_rows)

    best = best_row(comparison)
    passed = [r for r in comparison if bval(r.get("passed_jan_search_gate"))]
    lines = [
        "# Transcript Nested Third-Wave Search",
        "",
        "## Scope",
        "- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`",
        "- Concept: H1 context, M15 confirmed swing break, M5 first-pullback/retest entry, 75SMA/Granville-style diagnostics.",
        "- Search window: January 2025. Q1 c1 was attempted first but did not produce a fresh MT5 report within 15 minutes, so the five-cycle search was shortened to one month.",
        "- Tester period remains M15; EA internally scans `InpPrimaryEntryTF=PERIOD_M5` closed bars.",
        "",
        "## Comparison",
    ]
    for row in comparison:
        lines.append(
            f"- `{row['run_id']}`: trades={row['trades']} projected_year_trades={row['projected_year_trades']} "
            f"PF={row['profit_factor']:.2f} avg_R={row['avg_r']:.4f} net={row['net_profit']:.2f} "
            f"MaxDD={row['max_dd_profit']:.2f} fullSL={row['full_sl_rate']:.1%}"
        )

    lines.extend([
        "",
        "## Search Decision",
    ])
    if best:
        lines.append(
            f"- Best Jan row by avg_R/PF/trade count: `{best['run_id']}` with trades={best['trades']}, "
            f"PF={best['profit_factor']:.2f}, avg_R={best['avg_r']:.4f}, net={best['net_profit']:.2f}."
        )
    lines.append(f"- Jan search gate pass candidates: {', '.join(r['run_id'] for r in passed) if passed else 'none'}.")
    lines.append("- A January pass is not an operating pass; it only selects one candidate for 2025 fixed validation.")
    lines.extend([
        "",
        "## Artifacts",
        "- `comparison.csv`",
        "- `trades_all_scenarios.csv`",
        "- `symbol_breakdown.csv`",
        "- `direction_breakdown.csv`",
        "- `transcript_stage_breakdown.csv`",
        "- `sma75_breakdown.csv`",
        "- `failure_type_breakdown.csv`",
        "- `r_metrics.csv`",
    ])
    (OUT / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
