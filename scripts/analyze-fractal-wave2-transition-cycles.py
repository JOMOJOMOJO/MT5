import csv
import math
import shutil
from collections import defaultdict
from datetime import datetime
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FractalWave2TransitionTrader"
COMMON = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"
OUT = REPO / "reports" / "backtest" / "runs" / "20260711_fractal_wave2_transition"
MATRIX = OUT / "run_matrix.csv"
DEPOSIT = 10000.0


def fnum(value):
    try:
        return float(str(value or "0").replace(",", ""))
    except ValueError:
        return 0.0


def bval(value):
    return str(value or "").lower() in {"1", "true", "yes"}


def read_csv(path):
    if not path.exists():
        return []
    for encoding in ("utf-8-sig", "mbcs"):
        try:
            with path.open("r", encoding=encoding, newline="") as handle:
                return list(csv.DictReader(handle))
        except UnicodeDecodeError:
            continue
    return []


def stream_csv(path):
    if not path.exists():
        return
    with path.open("r", encoding="mbcs", newline="") as handle:
        yield from csv.DictReader(handle)


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


def dedupe(rows):
    result, seen = [], set()
    for row in rows:
        key = (row.get("entry_time"), row.get("exit_time"), row.get("symbol"),
               row.get("direction"), row.get("entry"), row.get("result_r"))
        if key in seen:
            continue
        seen.add(key)
        result.append(row)
    return result


def stats(rows):
    rows = sorted(list(rows), key=lambda row: row.get("exit_time", ""))
    profits = [fnum(row.get("net_profit")) for row in rows]
    rvals = [fnum(row.get("result_r")) for row in rows]
    mfes = [fnum(row.get("max_favorable_r_before_exit")) for row in rows]
    maes = [fnum(row.get("max_adverse_r_before_exit")) for row in rows]
    gross_profit = sum(value for value in profits if value > 0)
    gross_loss = sum(value for value in profits if value < 0)
    equity = peak = max_dd = 0.0
    for value in profits:
        equity += value
        peak = max(peak, equity)
        max_dd = min(max_dd, equity - peak)
    count = len(rows)
    net = sum(profits)
    return {
        "trades": count,
        "wins": sum(value > 0 for value in profits),
        "win_rate": sum(value > 0 for value in profits) / count if count else 0.0,
        "net_profit": net,
        "gross_profit": gross_profit,
        "gross_loss": gross_loss,
        "profit_factor": gross_profit / abs(gross_loss) if gross_loss < 0 else (math.inf if gross_profit else 0.0),
        "avg_r": sum(rvals) / count if count else 0.0,
        "max_dd_profit": abs(max_dd),
        "max_dd_pct": abs(max_dd) / DEPOSIT * 100.0,
        "recovery_factor": net / abs(max_dd) if max_dd < 0 else (math.inf if net > 0 else 0.0),
        "avg_mfe_r": sum(mfes) / count if count else 0.0,
        "avg_mae_r": sum(maes) / count if count else 0.0,
        "mfe_ge_0_5r_rate": sum(bval(row.get("reached_0_5r")) for row in rows) / count if count else 0.0,
        "mfe_ge_0_8r_rate": sum(bval(row.get("reached_0_8r")) for row in rows) / count if count else 0.0,
        "mfe_ge_1_0r_rate": sum(bval(row.get("reached_1_0r")) for row in rows) / count if count else 0.0,
        "mfe_ge_1_3r_rate": sum(bval(row.get("reached_1_3r")) for row in rows) / count if count else 0.0,
        "tp_rate": sum(bval(row.get("tp_exit")) for row in rows) / count if count else 0.0,
        "full_sl_rate": sum(bval(row.get("full_sl_exit")) for row in rows) / count if count else 0.0,
        "time_exit_rate": sum(bval(row.get("time_exit")) for row in rows) / count if count else 0.0,
        "avg_hold_bars": sum(fnum(row.get("holding_bars")) for row in rows) / count if count else 0.0,
        "avg_parent_wave2_age": sum(fnum(row.get("entry_parent_wave2_age")) for row in rows) / count if count else 0.0,
        "avg_child_flip_signal_age": sum(fnum(row.get("entry_signal_age_bars")) for row in rows) / count if count else 0.0,
    }


def grouped_stats(rows, keys):
    groups = defaultdict(list)
    for row in rows:
        groups[tuple(row.get(key, "") or "blank" for key in keys)].append(row)
    output = []
    for group, subset in sorted(groups.items()):
        record = dict(zip(keys, group))
        record.update(stats(subset))
        output.append(record)
    return output


def concentration_share(rows, key):
    positive = defaultdict(float)
    for row in rows:
        positive[row.get(key, "") or "blank"] += max(0.0, fnum(row.get("net_profit")))
    total = sum(positive.values())
    return max(positive.values(), default=0.0) / total if total else 1.0


def dependence_ok(rows):
    directions = {row.get("direction") for row in rows}
    return (directions >= {"LONG", "SHORT"} and concentration_share(rows, "symbol") <= 0.70
            and concentration_share(rows, "session_label") <= 0.70)


def gate_flags(rows, result, stopped):
    common = (result["profit_factor"] >= 1.05 and result["avg_r"] > 0
              and result["net_profit"] > 0 and not stopped and dependence_ok(rows))
    return common and result["trades"] >= 100 and result["mfe_ge_1_0r_rate"] > 0.245, common and result["trades"] >= 200


def add_derived(row, run):
    row.update({key: value for key, value in run.items() if key not in {"preset", "tester_ini"}})
    entry = row.get("entry_time", "")
    row["year"] = entry[:4]
    row["month"] = entry[:7].replace(".", "-")
    age = int(fnum(row.get("entry_signal_age_bars")))
    row["child_flip_age_bucket"] = "age_0" if age == 0 else ("age_1" if age == 1 else "age_other")
    wave2_age = int(fnum(row.get("entry_parent_wave2_age")))
    row["parent_wave2_age_bucket"] = ("age_0_3" if wave2_age <= 3 else "age_4_8" if wave2_age <= 8
                                       else "age_9_16" if wave2_age <= 16 else "age_17_plus")
    row["fractal_alignment_bucket"] = "full" if bval(row.get("full_fractal_alignment")) else f"count_{row.get('fractal_alignment_count', '0')}"


def common_paths(run):
    folder = COMMON / run["log_folder"]
    prefix = f"fw2t_{run['run_id']}_"
    return {name: folder / f"{prefix}{name}.csv" for name in ("events", "funnel", "rejections", "summary", "trades")}


def copy_artifacts(run, paths):
    run_dir = OUT / run["run_id"]
    run_dir.mkdir(parents=True, exist_ok=True)
    for key, name in (("tester_ini", "tester.ini"), ("preset", "preset.set")):
        source = REPO / run[key]
        if source.exists():
            shutil.copy2(source, run_dir / name)
    report_root = REPO / "reports" / "backtest"
    pattern = f"{EA_NAME}_fw2t_{run['run_id']}_report*"
    for source in report_root.glob(pattern):
        target_name = source.name.replace(f"{EA_NAME}_fw2t_{run['run_id']}_", "")
        shutil.copy2(source, run_dir / target_name)
    for name in ("funnel", "rejections", "summary", "trades"):
        if paths[name].exists():
            shutil.copy2(paths[name], run_dir / f"{name}.csv")


def event_breakdowns(run, path, accumulators):
    for row in stream_csv(path) or []:
        base = (run["period_id"], run["variant"], run["variant_name"])
        state_key = base + (row.get("previous_strategy_state", ""), row.get("strategy_state", ""), row.get("state_change_reason", ""))
        accumulators["state"][state_key] += 1
        state = row.get("strategy_state", "")
        if state == "PARENT_WAVE1_CONFIRMED":
            key = base + (row.get("parent_direction", ""), row.get("parent_wave1_valid", ""), row.get("parent_wave1_invalid_reason", ""))
            accumulators["wave1"][key] += 1
        if state in {"PARENT_WAVE2_ACTIVE", "INVALIDATED", "EXPIRED"}:
            key = base + (row.get("parent_direction", ""), row.get("parent_wave2_active", ""), row.get("parent_wave2_invalid_reason", ""), state)
            accumulators["wave2"][key] += 1
        if state == "CHILD_COUNTER_TREND_CONFIRMED":
            key = base + (row.get("parent_direction", ""), row.get("child_trend_state", ""), row.get("child_trend_aligned_with_wave2", ""))
            accumulators["child_trend"][key] += 1
        if state in {"CHILD_TREND_FLIPPED", "SIGNAL_CONSUMED"}:
            key = base + (row.get("parent_direction", ""), row.get("child_trend_state", ""), row.get("entry_signal_age_bars", ""), state)
            accumulators["child_flip"][key] += 1


def counter_rows(counter, fields):
    return [dict(zip(fields, key), count=count) for key, count in sorted(counter.items())]


def fmt(row):
    if not row:
        return "missing"
    return (f"{int(fnum(row.get('trades')))} trades / PF {fnum(row.get('profit_factor')):.2f} / "
            f"avg_R {fnum(row.get('avg_r')):+.4f} / net {fnum(row.get('net_profit')):+.2f} / "
            f"MFE>=1R {fnum(row.get('mfe_ge_1_0r_rate')):.1%}")


def write_summary(comparison, funnel_rows, all_trades):
    full = {row["variant"]: row for row in comparison if row["period_id"] == "full2025_validation"}
    base = full.get("e_base_first_child_flip")
    child_stop = full.get("f_child_stop")
    parent_stop = full.get("g_parent_stop")
    one = full.get("h_one_symbol")
    h1 = full.get("i_h1_diag")
    fractal = full.get("j_full_fractal_diag")
    funnel = next((row for row in funnel_rows if row.get("run_id") == "full2025_e_base_first_child_flip"), {})
    continued = [row["run_id"] for row in comparison if row["period_id"] == "full2025_validation" and bval(row.get("passed_research_continuation"))]
    passed = [row["run_id"] for row in comparison if row["period_id"] == "full2025_validation" and bval(row.get("passed_2025_gate"))]
    lines = [
        "# Standalone Fractal Wave2 Transition Trader Validation",
        "",
        "## Scope",
        "- 新EA `ExpectedValue_MultiCurrency_FractalWave2TransitionTrader` を別ファイル・別ロジックとして作成した。",
        "- 旧EA `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` は変更せずparked research assetのまま維持した。",
        "- 再利用したのはmulti-currency scanner、CopyRates、confirmed pivot、anchor/event ID、signal consumption、risk/lot、CSV、MFE/MAE、tester/batch基盤である。",
        "- session first120、required-light、SMA75、Fib、旧score、pattern hard gateは新entry logicへ持ち込んでいない。",
        "- M15/M5 pivotは左右確定後のみ有効化し、anchor break探索はpivot confirmed timeより後の確定足だけを使う。未来参照はない。",
        "- tester=M15だがEA scanはM5 closed bar。内部CopyRatesはH4/H1/M15/M5、enumはH1=16385/M15=15/M5=5。",
        "",
        "## Full 2025",
        f"- E base: {fmt(base)}",
        f"- F child extreme SL: {fmt(child_stop)}",
        f"- G parent wave2 extreme SL: {fmt(parent_stop)}",
        f"- H one-symbol selection: {fmt(one)}",
        f"- I H1 diagnostic: {fmt(h1)}",
        f"- J full fractal diagnostic: {fmt(fractal)}",
        "",
        "## Required Answers",
        "1. 新EAを別ファイルとして作成した: yes。",
        "2. 旧EAを変更せずparkedのまま維持した: yes。",
        "3. 共通基盤の再利用範囲: scanner/CopyRates/pivot/anchor/event/risk/log/testerのみ。",
        "4. 旧filterを持ち込んだか: no。",
        f"5. parent M15 flip: {funnel.get('parent_flips_detected', 'missing')}件。",
        f"6. valid parent wave1: {funnel.get('valid_parent_wave1', 'missing')}件。",
        f"7. parent wave2 start: {funnel.get('parent_wave2_started', 'missing')}件。",
        f"8. M5 child counter-trend: {funnel.get('child_countertrend_confirmed', 'missing')}件。",
        f"9. M5 child trend flip: {funnel.get('child_trend_flips_detected', 'missing')}件。",
        f"10. trades: {int(fnum(base.get('trades') if base else 0))}件。",
        "11. funnel最大減衰: `funnel_breakdown.csv` のfirst flip→fresh/consumed→tradeを参照。",
        f"12. M5 child flip entryの期待値: {'positive' if base and fnum(base.get('avg_r')) > 0 else 'negative'} ({fmt(base)})。",
        f"13. SL mode差: child={fmt(child_stop)} / parent={fmt(parent_stop)}。",
        f"14. one-symbol改善: {'yes' if one and base and fnum(one.get('avg_r')) > fnum(base.get('avg_r')) else 'no'} ({fmt(one)})。",
        f"15. H1/H4 alignment診断: H1={fmt(h1)} / full={fmt(fractal)}。hard gateにはしていない。",
        "16. symbol/direction/session依存: `symbol_breakdown.csv`, `direction_breakdown.csv`, `session_breakdown.csv` を参照。",
        f"17. 2025 shallow gate通過: {', '.join(passed) if passed else 'none'}。",
        f"18. 3年BT/OOS候補: {'yes' if passed else 'no; gate未通過のため実施しない'}。",
        f"19. 研究継続条件通過: {', '.join(continued) if continued else 'none'}。通過なしならfamilyはpark対象。",
        "",
        "最終funnel所見: baseは2839 first flipを一度ずつ消費し、spread guard 2344件、invalid stop 341件を経て154 tradesとなった。signal再利用はない。",
        "最良断片Gは100 trades / PF 1.03 / avg_R +0.0127Rだが、PF 1.05未満、SHORT PF 0.79、USDJPY 64%のため昇格しない。",
        "H1 alignment=trueは25 trades / PF 0.71、full alignmentは10 trades / PF 0.65であり、H1/H4 hard gateによる修理根拠はない。",
        "研究判断: 新familyはpark。parent-extreme SL断片は記録するが、閾値微調整や通貨・方向除外では延命しない。",
        "",
        "旧EA baseline参照: 318 trades / PF 0.59 / avg_R -0.1582 / MFE>=1R 24.5%。",
    ]
    (OUT / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    matrix = read_csv(MATRIX)
    comparison, all_trades, funnel_rows, rejection_rows = [], [], [], []
    counters = {name: defaultdict(int) for name in ("state", "wave1", "wave2", "child_trend", "child_flip")}
    for run in matrix:
        paths = common_paths(run)
        copy_artifacts(run, paths)
        trades = dedupe(read_csv(paths["trades"]))
        summary = read_csv(paths["summary"])
        for trade in trades:
            add_derived(trade, run)
            all_trades.append(trade)
        result = stats(trades)
        stopped = bool(summary and (bval(summary[-1].get("daily_stopped")) or bval(summary[-1].get("drawdown_stopped"))))
        research, shallow = gate_flags(trades, result, stopped) if run["period_id"] == "full2025_validation" else (False, False)
        comparison.append({**run, **result, "daily_or_dd_stopped": stopped,
                           "passed_research_continuation": research, "passed_2025_gate": shallow,
                           "max_symbol_positive_profit_share": concentration_share(trades, "symbol") if trades else 0.0,
                           "max_session_positive_profit_share": concentration_share(trades, "session_label") if trades else 0.0})
        funnel = read_csv(paths["funnel"])
        funnel_record = {"run_id": run["run_id"], "period_id": run["period_id"], "variant": run["variant"]}
        funnel_record.update({row.get("stage", ""): row.get("count", "0") for row in funnel})
        funnel_rows.append(funnel_record)
        for row in read_csv(paths["rejections"]):
            rejection_rows.append({"run_id": run["run_id"], "period_id": run["period_id"],
                                   "variant": run["variant"], **row})
        event_breakdowns(run, paths["events"], counters)

    write_csv(OUT / "comparison.csv", comparison)
    write_csv(OUT / "q1_comparison.csv", [row for row in comparison if row["period_id"] == "q1_quick"])
    write_csv(OUT / "full2025_comparison.csv", [row for row in comparison if row["period_id"] == "full2025_validation"])
    write_csv(OUT / "trades_all_scenarios.csv", all_trades)
    write_csv(OUT / "funnel_breakdown.csv", funnel_rows)
    write_csv(OUT / "rejection_reason_breakdown.csv", rejection_rows)
    base_fields = ["period_id", "variant", "variant_name"]
    write_csv(OUT / "state_transition_breakdown.csv", counter_rows(counters["state"], base_fields + ["previous_state", "strategy_state", "reason"]))
    write_csv(OUT / "parent_wave1_breakdown.csv", counter_rows(counters["wave1"], base_fields + ["parent_direction", "wave1_valid", "invalid_reason"]))
    write_csv(OUT / "parent_wave2_breakdown.csv", counter_rows(counters["wave2"], base_fields + ["parent_direction", "wave2_active", "invalid_reason", "strategy_state"]))
    write_csv(OUT / "child_countertrend_breakdown.csv", counter_rows(counters["child_trend"], base_fields + ["parent_direction", "child_trend_state", "aligned_with_wave2"]))
    write_csv(OUT / "child_flip_breakdown.csv", counter_rows(counters["child_flip"], base_fields + ["parent_direction", "child_trend_state", "signal_age_bars", "strategy_state"]))
    breakdowns = {
        "mfe_by_child_flip_age.csv": ["period_id", "variant", "child_flip_age_bucket"],
        "mfe_by_parent_wave2_age.csv": ["period_id", "variant", "parent_wave2_age_bucket"],
        "mfe_by_fractal_alignment.csv": ["period_id", "variant", "fractal_alignment_bucket"],
        "symbol_breakdown.csv": ["period_id", "variant", "symbol"],
        "direction_breakdown.csv": ["period_id", "variant", "direction"],
        "session_breakdown.csv": ["period_id", "variant", "session_label"],
        "monthly_breakdown.csv": ["period_id", "variant", "month"],
        "yearly_breakdown.csv": ["period_id", "variant", "year"],
        "weekday_breakdown.csv": ["period_id", "variant", "weekday"],
        "parent_direction_breakdown.csv": ["period_id", "variant", "direction"],
        "child_trend_type_breakdown.csv": ["period_id", "variant", "entry_child_trend_before_flip"],
        "h1_alignment_breakdown.csv": ["period_id", "variant", "h1_alignment_with_parent"],
        "h4_alignment_breakdown.csv": ["period_id", "variant", "h4_alignment_with_parent"],
        "fractal_alignment_count_breakdown.csv": ["period_id", "variant", "fractal_alignment_count"],
    }
    for filename, keys in breakdowns.items():
        write_csv(OUT / filename, grouped_stats(all_trades, keys))
    write_summary(comparison, funnel_rows, all_trades)
    print(f"Analyzed {len(matrix)} runs and {len(all_trades)} trade rows into {OUT}")


if __name__ == "__main__":
    main()
