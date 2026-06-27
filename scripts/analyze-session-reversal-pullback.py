import csv
import math
import shutil
from collections import defaultdict
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
COMMON_FILES = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"
OUT = REPO / "reports" / "backtest" / "runs" / "20260627_session_reversal_pullback_htf_obstacle_diagnostics"
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"

SCENARIOS = [
    "session_reversal_pullback_all_symbols_first120",
    "session_reversal_pullback_one_symbol_first120",
    "session_reversal_pullback_one_symbol_first60",
    "session_reversal_pullback_clean_target_path_first120",
    "session_reversal_pullback_clean_target_path_first60",
    "tokyo_first120_reference",
    "london_first120_reference",
    "newyork_first120_reference",
    "overlap_first120_reference",
    "target_multiple_1_2_reference",
    "target_multiple_2_0_reference",
]


def fnum(value):
    if value is None or value == "":
        return 0.0
    try:
        return float(str(value).replace(",", ""))
    except ValueError:
        return 0.0


def bval(value):
    return str(value).strip().lower() in {"1", "true", "yes"}


def read_csv(path):
    if not path.exists():
        return []
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
        "recovery_factor": net / abs(max_dd) if max_dd < 0 else (math.inf if net > 0 else 0.0),
    }


def group_stats(rows, scenario, key_name):
    groups = defaultdict(list)
    for row in rows:
        groups[row.get(key_name, "")].append(row)
    out = []
    for key, values in sorted(groups.items()):
        out.append({"scenario": scenario, key_name: key, **stats(values)})
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


def htf_state(row):
    obstacle = row.get("nearest_obstacle_type", "")
    if obstacle in {"h4_confirmed_swing_high", "h4_confirmed_swing_low", "h1_confirmed_swing_high", "h1_confirmed_swing_low"}:
        return obstacle
    if obstacle.startswith("previous_day") or obstacle.startswith("previous_week"):
        return obstacle
    if fnum(row.get("htf_nearest_resistance")) > 0 and row.get("direction") == "LONG":
        return "nearest_resistance_recorded"
    if fnum(row.get("htf_nearest_support")) > 0 and row.get("direction") == "SHORT":
        return "nearest_support_recorded"
    return "none"


def scenario_gate_scope(name):
    return (
        "one_symbol" in name
        or "clean_target_path" in name
        or "target_multiple" in name
        or name.endswith("_reference")
    )


def directional_ok(rows):
    long_rows = [r for r in rows if r.get("direction") == "LONG"]
    short_rows = [r for r in rows if r.get("direction") == "SHORT"]
    if not long_rows or not short_rows:
        return False
    long_s = stats(long_rows)
    short_s = stats(short_rows)
    if long_s["avg_r"] < -0.20 or short_s["avg_r"] < -0.20:
        return False
    return True


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


def copy_artifacts(scenario, scenario_dir):
    scenario_dir.mkdir(parents=True, exist_ok=True)
    for suffix in [".ini"]:
        source = REPO / "reports" / "backtest" / f"{EA_NAME}_{scenario}_2025{suffix}"
        if source.exists():
            shutil.copy2(source, scenario_dir / "tester.ini")
    preset = REPO / "reports" / "presets" / f"{EA_NAME}_{scenario}_2025.set"
    if preset.exists():
        shutil.copy2(preset, scenario_dir / "preset.set")
    for report in (REPO / "reports" / "backtest").glob(f"{EA_NAME}_{scenario}_2025_report*"):
        short_name = report.name.replace(f"{EA_NAME}_{scenario}_2025_", "")
        shutil.copy2(report, scenario_dir / short_name)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    all_trades = []
    all_signals = []
    all_blocked = []
    comparison = []

    for scenario in SCENARIOS:
        folder = COMMON_FILES / f"fx_session_reversal_pullback_{scenario}_2025"
        signals_path = folder / f"fxsessionrev_{scenario}_signals.csv"
        trades_path = folder / f"fxsessionrev_{scenario}_trades.csv"
        summary_path = folder / f"fxsessionrev_{scenario}_summary.csv"
        scenario_dir = OUT / scenario
        copy_artifacts(scenario, scenario_dir)
        if signals_path.exists():
            shutil.copy2(signals_path, scenario_dir / "signals.csv")
        if trades_path.exists():
            shutil.copy2(trades_path, scenario_dir / "trades.csv")
        if summary_path.exists():
            shutil.copy2(summary_path, scenario_dir / "ea_summary.csv")

        signals = read_csv(signals_path)
        trades = read_csv(trades_path)
        summary_rows = read_csv(summary_path)
        for row in signals:
            row["scenario"] = scenario
            all_signals.append(row)
            if row.get("event") == "blocked":
                all_blocked.append(row)
        for row in trades:
            row["scenario"] = scenario
            row["year"] = year_key(row.get("entry_time"))
            row["month"] = month_key(row.get("entry_time"))
            row["htf_level_state"] = htf_state(row)
            row["symbol_session"] = f"{row.get('symbol', '')}_{row.get('session_label', '')}"
            all_trades.append(row)

        s = stats(trades)
        clean = [r for r in trades if bval(r.get("clean_path_to_target"))]
        dirty = [r for r in trades if not bval(r.get("clean_path_to_target"))]
        clean_s = stats(clean)
        dirty_s = stats(dirty)
        blocked_count = len([r for r in signals if r.get("event") == "blocked"])
        obstacle_blocked = len([r for r in signals if r.get("event") == "blocked" and bval(r.get("obstacle_blocked"))])
        dd_stopped = False
        if summary_rows:
            dd_stopped = bval(summary_rows[-1].get("drawdown_stopped")) or bval(summary_rows[-1].get("daily_stopped"))
        passed = (
            scenario_gate_scope(scenario)
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
            "scenario": scenario,
            **s,
            "blocked_signals": blocked_count,
            "obstacle_blocked_signals": obstacle_blocked,
            "clean_trades": clean_s["trades"],
            "clean_avg_r": clean_s["avg_r"],
            "dirty_trades": dirty_s["trades"],
            "dirty_avg_r": dirty_s["avg_r"],
            "daily_or_dd_stopped": dd_stopped,
            "gate_scope": scenario_gate_scope(scenario),
            "passed_2025_shallow_gate": passed,
        })

    write_csv(OUT / "comparison.csv", comparison)
    write_csv(OUT / "trades_all_scenarios.csv", all_trades)
    write_csv(OUT / "signals_all_scenarios.csv", all_signals)
    write_csv(OUT / "blocked_signals.csv", all_blocked)

    breakdowns = {
        "session_breakdown.csv": "session_label",
        "trade_window_breakdown.csv": "trade_window_label",
        "symbol_session_breakdown.csv": "symbol_session",
        "entry_pattern_breakdown.csv": "entry_pattern",
        "entry_trigger_breakdown.csv": "entry_trigger",
        "target_multiple_breakdown.csv": "target_reward_multiple",
        "obstacle_breakdown.csv": "nearest_obstacle_type",
        "clean_path_to_target_breakdown.csv": "clean_path_to_target",
        "htf_level_breakdown.csv": "htf_level_state",
        "failure_type_breakdown.csv": "failure_type",
        "yearly_breakdown.csv": "year",
        "monthly_breakdown.csv": "month",
    }
    for filename, key in breakdowns.items():
        rows = []
        for scenario in SCENARIOS:
            scenario_rows = [r for r in all_trades if r.get("scenario") == scenario]
            rows.extend(group_stats(scenario_rows, scenario, key))
        write_csv(OUT / filename, rows)

    r_rows = []
    for scenario in SCENARIOS:
        scenario_rows = [r for r in all_trades if r.get("scenario") == scenario]
        rvals = sorted(fnum(r.get("result_r")) for r in scenario_rows)
        s = stats(scenario_rows)
        median = rvals[len(rvals) // 2] if rvals else 0.0
        p10 = rvals[int(len(rvals) * 0.10)] if rvals else 0.0
        p90 = rvals[int(len(rvals) * 0.90)] if rvals else 0.0
        r_rows.append({"scenario": scenario, "median_r": median, "p10_r": p10, "p90_r": p90, **s})
    write_csv(OUT / "r_metrics.csv", r_rows)

    compile_log = REPO / "reports" / "compile" / "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_compile.txt"
    if compile_log.exists():
        shutil.copy2(compile_log, OUT / "compile.log")

    best = max(comparison, key=lambda r: r["avg_r"]) if comparison else None
    first60 = next((r for r in comparison if r["scenario"] == "session_reversal_pullback_one_symbol_first60"), None)
    first120 = next((r for r in comparison if r["scenario"] == "session_reversal_pullback_one_symbol_first120"), None)
    clean120 = next((r for r in comparison if r["scenario"] == "session_reversal_pullback_clean_target_path_first120"), None)
    one120 = first120
    passed = [r for r in comparison if r["passed_2025_shallow_gate"]]

    session_rows = [r for r in group_stats(all_trades, "all", "session_label") if r["trades"] > 0]
    best_session = max(session_rows, key=lambda r: r["avg_r"]) if session_rows else None
    pattern_rows = [r for r in group_stats(all_trades, "all", "entry_pattern") if r["trades"] > 0]
    best_pattern = max(pattern_rows, key=lambda r: r["avg_r"]) if pattern_rows else None

    lines = [
        "# Session Reversal Pullback HTF Obstacle Diagnostics",
        "",
        "## Implementation",
        "- The EA evaluates only the first 60 or 120 minutes after each UTC session start, not the whole session.",
        "- Broker server time is converted to UTC with `InpBrokerUtcOffsetHours`; server/UTC/JST hour and minutes_from_session_start are exported.",
        "- H4/H1 swings use only confirmed fractal-style pivots with `InpSwingDepth`; ZigZag repaint values are not used.",
        "- Target path is explicitly defined by `entry_price`, `stop_loss_price`, `initial_risk_price_distance`, `target_reward_multiple`, and `target_price`.",
        "- Hard obstacles are no-trade gates only in clean target path scenarios; soft obstacles remain diagnostic.",
        "",
        "## 2025 Shallow BT Result",
    ]
    if best:
        lines.append(f"- Best avg_R scenario: `{best['scenario']}` trades={best['trades']} PF={best['profit_factor']:.2f} avg_R={best['avg_r']:.4f} net={best['net_profit']:.2f}.")
    if first60 and first120:
        better = "first60" if first60["avg_r"] > first120["avg_r"] else "first120"
        lines.append(f"- first60 vs first120: better_by_avg_R={better}; first60 avg_R={first60['avg_r']:.4f}, trades={first60['trades']}; first120 avg_R={first120['avg_r']:.4f}, trades={first120['trades']}.")
    if best_session:
        lines.append(f"- Best session by avg_R across all trades: `{best_session['session_label']}` avg_R={best_session['avg_r']:.4f}, trades={best_session['trades']}.")
    if clean120 and one120:
        lines.append(f"- Clean target path effect first120: one_symbol avg_R={one120['avg_r']:.4f}, trades={one120['trades']}; clean_path avg_R={clean120['avg_r']:.4f}, trades={clean120['trades']}, obstacle_blocked={clean120['obstacle_blocked_signals']}.")
    if one120:
        lines.append(f"- clean_path_to_target split in one_symbol_first120: clean_avg_R={one120['clean_avg_r']:.4f}, dirty_avg_R={one120['dirty_avg_r']:.4f}.")
    if best_pattern:
        lines.append(f"- Best entry pattern by avg_R across all trades: `{best_pattern['entry_pattern']}` avg_R={best_pattern['avg_r']:.4f}, trades={best_pattern['trades']}.")
    lines.extend([
        f"- 2025 shallow gate pass candidates: {', '.join(r['scenario'] for r in passed) if passed else 'none'}.",
        "",
        "## Required Checks",
        "1. Session was restricted to first 60/120 minutes, not the whole session.",
        "2. first60/first120 comparison is in `comparison.csv` and `trade_window_breakdown.csv`.",
        "3. Tokyo/London/New York/Overlap comparison is in `session_breakdown.csv`.",
        "4. HTF resistance/support and target path obstacles were recorded in trades/signals CSV.",
        "5. Clean path did not automatically become a pass; gate result is based on PF, avg_R, net, trade count, and concentration.",
        "6. clean_path_to_target=true/false comparison is in `clean_path_to_target_breakdown.csv`.",
        "7. Pattern comparison is in `entry_pattern_breakdown.csv` and `entry_trigger_breakdown.csv`.",
        "8. one session / one symbol / one trade was tested against all-symbol mode.",
        "9. 200+ trade requirement is checked in `comparison.csv`.",
        "10. 2025 shallow gate result is recorded above; no scenario moves to 3-year BT/OOS unless it passes.",
    ])
    (OUT / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
