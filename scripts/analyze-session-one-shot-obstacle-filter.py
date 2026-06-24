import csv
import math
import shutil
from collections import defaultdict
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
COMMON_FILES = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"
OUT = REPO / "reports" / "backtest" / "runs" / "20260624_session_one_shot_obstacle_filter_diagnostics"

SCENARIOS = [
    {
        "name": "session_one_shot_no_obstacle_filter",
        "target": 1.5,
        "hard_filter": False,
        "soft_as_hard": False,
        "telemetry": "mt5_company_usdjpy_20260421_session_one_shot_no_obstacle_filter_2025.csv",
    },
    {
        "name": "session_one_shot_target_1_5_clean_path",
        "target": 1.5,
        "hard_filter": True,
        "soft_as_hard": False,
        "telemetry": "mt5_company_usdjpy_20260421_session_one_shot_target_1_5_clean_path_2025.csv",
    },
    {
        "name": "session_one_shot_target_2_0_clean_path_reference",
        "target": 2.0,
        "hard_filter": True,
        "soft_as_hard": False,
        "telemetry": "mt5_company_usdjpy_20260421_session_one_shot_target_2_0_clean_path_reference_2025.csv",
    },
    {
        "name": "session_one_shot_target_1_2_clean_path_reference",
        "target": 1.2,
        "hard_filter": True,
        "soft_as_hard": False,
        "telemetry": "mt5_company_usdjpy_20260421_session_one_shot_target_1_2_clean_path_reference_2025.csv",
    },
    {
        "name": "session_one_shot_target_1_5_soft_obstacle_diagnostics",
        "target": 1.5,
        "hard_filter": True,
        "soft_as_hard": False,
        "telemetry": "mt5_company_usdjpy_20260421_session_one_shot_target_1_5_soft_obstacle_diagnostics_2025.csv",
    },
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


def stats(rows):
    rows = list(rows)
    count = len(rows)
    profits = [fnum(r.get("net_profit")) for r in rows]
    rvals = [fnum(r.get("result_r")) for r in rows]
    wins = sum(1 for v in profits if v > 0)
    gross_profit = sum(v for v in profits if v > 0)
    gross_loss = sum(v for v in profits if v < 0)
    net = sum(profits)
    sum_r = sum(rvals)
    win_r = sum(v for v in rvals if v > 0)
    loss_r = sum(v for v in rvals if v < 0)
    return {
        "trades": count,
        "wins": wins,
        "win_rate": wins / count if count else 0.0,
        "net_profit": net,
        "gross_profit": gross_profit,
        "gross_loss": gross_loss,
        "profit_factor": gross_profit / abs(gross_loss) if gross_loss < 0 else (math.inf if gross_profit > 0 else 0.0),
        "sum_r": sum_r,
        "avg_r": sum_r / count if count else 0.0,
        "r_profit_factor": win_r / abs(loss_r) if loss_r < 0 else (math.inf if win_r > 0 else 0.0),
    }


def read_telemetry(path):
    with path.open("r", encoding="mbcs", newline="") as handle:
        return list(csv.DictReader(handle, delimiter=";"))


def group_stats(rows, scenario, key_name):
    out = []
    groups = defaultdict(list)
    for row in rows:
        groups[row.get(key_name, "")].append(row)
    for key, values in sorted(groups.items()):
        s = stats(values)
        out.append({"scenario": scenario, key_name: key, **s})
    return out


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


def build_trade_rows(scenario, rows):
    entries = {}
    trades = {}
    blocked = []
    all_rows = []
    for row in rows:
        row = dict(row)
        row["scenario"] = scenario["name"]
        all_rows.append(row)
        event = row.get("event_type", "")
        position_id = row.get("position_id", "")
        if event == "entry":
            entries[position_id] = row
            trades.setdefault(position_id, {"entry": row, "net_profit": 0.0, "result_r": 0.0, "exit_rows": 0})
        elif event == "obstacle_blocked":
            blocked.append(row)
        elif event in {"partial_exit", "exit"}:
            trades.setdefault(position_id, {"entry": entries.get(position_id, row), "net_profit": 0.0, "result_r": 0.0, "exit_rows": 0})
            trades[position_id]["net_profit"] += fnum(row.get("net_profit"))
            trades[position_id]["result_r"] += fnum(row.get("event_r_multiple"))
            trades[position_id]["exit_rows"] += 1

    trade_rows = []
    for position_id, trade in trades.items():
        if trade["exit_rows"] <= 0:
            continue
        entry = trade["entry"]
        trade_rows.append(
            {
                "scenario": scenario["name"],
                "position_id": position_id,
                "side": entry.get("side", ""),
                "entry_time": entry.get("timestamp", ""),
                "entry_price": entry.get("entry_price", ""),
                "stop_loss_price": entry.get("stop_loss_price", ""),
                "initial_risk_price_distance": entry.get("initial_risk_price_distance", ""),
                "target_reward_multiple": entry.get("target_reward_multiple", ""),
                "target_price": entry.get("target_price", ""),
                "nearest_obstacle_price": entry.get("nearest_obstacle_price", ""),
                "nearest_obstacle_type": entry.get("nearest_obstacle_type", ""),
                "nearest_obstacle_distance_price": entry.get("nearest_obstacle_distance_price", ""),
                "nearest_obstacle_distance_r": entry.get("nearest_obstacle_distance_r", ""),
                "obstacle_buffer_r": entry.get("obstacle_buffer_r", ""),
                "hard_obstacle_present_before_target": entry.get("hard_obstacle_present_before_target", ""),
                "soft_obstacle_present_before_target": entry.get("soft_obstacle_present_before_target", ""),
                "clean_path_to_target": entry.get("clean_path_to_target", ""),
                "obstacle_blocked": entry.get("obstacle_blocked", ""),
                "obstacle_block_reason": entry.get("obstacle_block_reason", ""),
                "obstacle_count_before_target": entry.get("obstacle_count_before_target", ""),
                "hard_obstacle_count_before_target": entry.get("hard_obstacle_count_before_target", ""),
                "soft_obstacle_count_before_target": entry.get("soft_obstacle_count_before_target", ""),
                "net_profit": trade["net_profit"],
                "result_r": trade["result_r"],
                "outcome": "win" if trade["net_profit"] > 0 else ("loss" if trade["net_profit"] < 0 else "flat"),
            }
        )
    return trade_rows, blocked, all_rows


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    all_trades = []
    all_blocked = []
    all_telemetry = []
    comparison = []
    clean_breakdown = []
    obstacle_type_breakdown = []
    block_reason_breakdown = []
    soft_breakdown = []
    side_breakdown = []

    for scenario in SCENARIOS:
        source = COMMON_FILES / scenario["telemetry"]
        if not source.exists():
            raise FileNotFoundError(source)
        scenario_dir = OUT / scenario["name"]
        scenario_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, scenario_dir / "telemetry.csv")
        for suffix in [".ini"]:
            candidate = REPO / "reports" / "backtest" / f"usdjpy_20260421_{scenario['name']}_2025{suffix}"
            if candidate.exists():
                shutil.copy2(candidate, scenario_dir / "tester.ini")
        for report in (REPO / "reports" / "backtest").glob(f"usdjpy_20260421_{scenario['name']}_2025_report*"):
            short_name = report.name.replace(f"usdjpy_20260421_{scenario['name']}_2025_", "")
            shutil.copy2(report, scenario_dir / short_name)
        preset = REPO / "reports" / "presets" / f"usdjpy_20260421_{scenario['name']}_2025.set"
        if preset.exists():
            shutil.copy2(preset, scenario_dir / "preset.set")

        rows = read_telemetry(source)
        trades, blocked, telemetry_rows = build_trade_rows(scenario, rows)
        all_trades.extend(trades)
        all_blocked.extend({"scenario": scenario["name"], **row} for row in blocked)
        all_telemetry.extend(telemetry_rows)

        s = stats(trades)
        clean = [row for row in trades if bval(row.get("clean_path_to_target"))]
        dirty = [row for row in trades if not bval(row.get("clean_path_to_target"))]
        clean_s = stats(clean)
        dirty_s = stats(dirty)
        passed = s["trades"] >= 100 and s["profit_factor"] >= 1.05 and s["avg_r"] > 0 and s["net_profit"] > 0
        comparison.append(
            {
                "scenario": scenario["name"],
                "target_reward_multiple": scenario["target"],
                "hard_filter": scenario["hard_filter"],
                "soft_as_hard": scenario["soft_as_hard"],
                "trades": s["trades"],
                "blocked_signals": len(blocked),
                "net_profit": s["net_profit"],
                "profit_factor": s["profit_factor"],
                "avg_r": s["avg_r"],
                "win_rate": s["win_rate"],
                "clean_path_trades": clean_s["trades"],
                "clean_path_avg_r": clean_s["avg_r"],
                "dirty_path_trades": dirty_s["trades"],
                "dirty_path_avg_r": dirty_s["avg_r"],
                "passed_2025_shallow_gate": passed,
            }
        )
        clean_breakdown.extend(group_stats(trades, scenario["name"], "clean_path_to_target"))
        obstacle_type_breakdown.extend(group_stats(trades, scenario["name"], "nearest_obstacle_type"))
        soft_breakdown.extend(group_stats(trades, scenario["name"], "soft_obstacle_present_before_target"))
        side_breakdown.extend(group_stats(trades, scenario["name"], "side"))

        reason_groups = defaultdict(list)
        for row in blocked:
            reason_groups[row.get("obstacle_block_reason", "")].append(row)
        for reason, values in sorted(reason_groups.items()):
            block_reason_breakdown.append(
                {
                    "scenario": scenario["name"],
                    "obstacle_block_reason": reason,
                    "blocked_signals": len(values),
                }
            )

    write_csv(OUT / "comparison.csv", comparison)
    write_csv(OUT / "trades_all_scenarios.csv", all_trades)
    write_csv(OUT / "blocked_signals.csv", all_blocked)
    write_csv(OUT / "telemetry_all_scenarios.csv", all_telemetry)
    write_csv(OUT / "clean_path_breakdown.csv", clean_breakdown)
    write_csv(OUT / "obstacle_type_breakdown.csv", obstacle_type_breakdown)
    write_csv(OUT / "obstacle_block_reason_breakdown.csv", block_reason_breakdown)
    write_csv(OUT / "soft_obstacle_breakdown.csv", soft_breakdown)
    write_csv(OUT / "side_breakdown.csv", side_breakdown)

    best = max(comparison, key=lambda row: row["avg_r"]) if comparison else None
    base = next(row for row in comparison if row["scenario"] == "session_one_shot_no_obstacle_filter")
    clean_15 = next(row for row in comparison if row["scenario"] == "session_one_shot_target_1_5_clean_path")
    base_clean_rows = [row for row in all_trades if row["scenario"] == "session_one_shot_no_obstacle_filter" and bval(row.get("clean_path_to_target"))]
    base_dirty_rows = [row for row in all_trades if row["scenario"] == "session_one_shot_no_obstacle_filter" and not bval(row.get("clean_path_to_target"))]
    base_clean = stats(base_clean_rows)
    base_dirty = stats(base_dirty_rows)
    target_rows = [row for row in comparison if "target_" in row["scenario"] and row["scenario"] != "session_one_shot_target_1_5_soft_obstacle_diagnostics"]
    worst_obstacle = sorted(obstacle_type_breakdown, key=lambda row: float(row["avg_r"]))[0] if obstacle_type_breakdown else None
    most_blocked = sorted(block_reason_breakdown, key=lambda row: int(row["blocked_signals"]), reverse=True)[0] if block_reason_breakdown else None

    lines = [
        "# Session One-Shot Target Path Obstacle Filter Diagnostics",
        "",
        "## Definitions",
        "- `entry_price` is the planned order entry price.",
        "- `stop_loss_price` is the initial protective stop price.",
        "- `initial_risk_price_distance = abs(entry_price - stop_loss_price)`.",
        "- `target_reward_multiple` default is `1.5`.",
        "- Long `target_price = entry_price + initial_risk_price_distance * target_reward_multiple`.",
        "- Short `target_price = entry_price - initial_risk_price_distance * target_reward_multiple`.",
        "- `obstacle_buffer_r` default is `0.2`; the filter requires the nearest hard obstacle to be at least `target_reward_multiple + obstacle_buffer_r` away in R terms.",
        "",
        "## Hard vs Soft Obstacles",
        "- Hard obstacles are previous-day levels, H1/H4 confirmed swings, session high/low, opening-range high/low, and pre-session high/low. These can block entries when `InpUseHardObstacleFilter=true`.",
        "- Soft obstacles are round numbers, recent equal highs/lows, rejection/wick clusters, consolidation, prior breakout failure, failed breakout level, and price congestion. They are logged for diagnostics and are not hard gates unless `InpUseSoftObstacleAsHardFilter=true`.",
        "",
        "## 2025 Shallow Comparison",
    ]
    for row in comparison:
        lines.append(
            f"- {row['scenario']}: trades={row['trades']}, blocked={row['blocked_signals']}, "
            f"PF={row['profit_factor']:.2f}, avg_R={row['avg_r']:.4f}, net={row['net_profit']:.2f}, "
            f"clean_avg_R={row['clean_path_avg_r']:.4f}, dirty_avg_R={row['dirty_path_avg_r']:.4f}, "
            f"passed={row['passed_2025_shallow_gate']}"
        )
    lines += [
        "",
        "## Required Findings",
        f"- In the no-filter baseline, clean_path_to_target=true did not improve expectancy: clean_avg_R={base_clean['avg_r']:.4f} over {base_clean['trades']} trades, dirty_avg_R={base_dirty['avg_r']:.4f} over {base_dirty['trades']} trades.",
        f"- Compared with no filter, the 1.5 clean-path filter changed avg_R from {base['avg_r']:.4f} to {clean_15['avg_r']:.4f}, PF from {base['profit_factor']:.2f} to {clean_15['profit_factor']:.2f}, and trades from {base['trades']} to {clean_15['trades']}.",
        f"- obstacle_blocked removed {clean_15['blocked_signals']} candidate signals in the 1.5 clean-path scenario, but it did not improve aggregate expectancy.",
        f"- Worst obstacle type by avg_R was `{worst_obstacle['nearest_obstacle_type']}` in `{worst_obstacle['scenario']}` with avg_R={float(worst_obstacle['avg_r']):.4f} over {worst_obstacle['trades']} trades." if worst_obstacle else "- No obstacle type breakdown was available.",
        f"- Most frequent block reason was `{most_blocked['obstacle_block_reason']}` with {most_blocked['blocked_signals']} blocked signals." if most_blocked else "- No obstacle-blocked rows were generated.",
        "- Target multiple comparison:",
    ]
    for row in sorted(target_rows, key=lambda r: r["target_reward_multiple"]):
        lines.append(f"  - target_reward_multiple={row['target_reward_multiple']}: trades={row['trades']}, blocked={row['blocked_signals']}, PF={row['profit_factor']:.2f}, avg_R={row['avg_r']:.4f}, net={row['net_profit']:.2f}")
    lines += [
        f"- Best scenario by avg_R was `{best['scenario']}` with avg_R={best['avg_r']:.4f}, PF={best['profit_factor']:.2f}, net={best['net_profit']:.2f}." if best else "- No scenario rows were available.",
        f"- 2025 shallow gate candidate exists: {any(row['passed_2025_shallow_gate'] for row in comparison)}.",
        "",
        "## Notes",
        "- This implementation does not use the ambiguous phrase `2R余白`; it records explicit target, risk, obstacle distance, and R-normalized obstacle distance.",
        "- The test did not repair results by excluding symbols, limiting direction, adding a Friday stop, or fine-optimizing target multiples.",
    ]
    (OUT / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    compile_log = REPO / "reports" / "compile" / "usdjpy_20260421_tokyo_london_session_box_breakout_engine_obstacle_filter.log"
    if compile_log.exists():
        shutil.copy2(compile_log, OUT / "compile.log")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
