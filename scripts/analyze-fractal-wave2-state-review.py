import csv
import math
import shutil
from collections import defaultdict
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
OUT = REPO / "reports" / "backtest" / "runs" / "20260714_fractal_wave2_transition_state_review"
MATRIX = OUT / "run_matrix.csv"
COMMON = Path.home() / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "Common" / "Files"
EA_NAME = "ExpectedValue_MultiCurrency_FractalWave2TransitionTrader"
DEPOSIT = 10000.0


def fnum(value):
    try:
        return float(str(value or "0").replace(",", ""))
    except (TypeError, ValueError):
        return 0.0


def bval(value):
    return str(value or "").lower() in {"1", "true", "yes"}


def read_csv(path):
    if not path.exists():
        return []
    for encoding in ("utf-8-sig", "cp932", "mbcs"):
        try:
            with path.open("r", encoding=encoding, newline="") as handle:
                return list(csv.DictReader(handle))
        except UnicodeDecodeError:
            continue
    return []


def write_csv(path, rows, fields=None):
    rows = list(rows)
    if fields is None:
        fields = list(dict.fromkeys(key for row in rows for key in row))
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
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
    pf = gross_profit / abs(gross_loss) if gross_loss < 0 else (math.inf if gross_profit else 0.0)
    return {
        "trades": count,
        "wins": sum(value > 0 for value in profits),
        "win_rate": sum(value > 0 for value in profits) / count if count else 0.0,
        "net_profit": net,
        "gross_profit": gross_profit,
        "gross_loss": gross_loss,
        "profit_factor": pf,
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
        "avg_child_flip_signal_age": sum(fnum(row.get("entry_signal_age_bars")) for row in rows) / count if count else 0.0,
        "avg_parent_wave2_age": sum(fnum(row.get("entry_parent_wave2_age")) for row in rows) / count if count else 0.0,
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
    return (directions >= {"LONG", "SHORT"}
            and concentration_share(rows, "symbol") <= 0.70
            and concentration_share(rows, "session_label") <= 0.70)


def run_paths(run):
    folder = COMMON / run["log_folder"]
    prefix = f"fw2t_{run['run_id']}_"
    return {name: folder / f"{prefix}{name}.csv"
            for name in ("events", "funnel", "rejections", "summary", "trades")}


def add_trade_metadata(row, run):
    for key, value in run.items():
        if key not in {"preset", "tester_ini"}:
            row[key] = value
    entry = row.get("entry_time", "")
    row["year"] = entry[:4]
    row["month"] = entry[:7].replace(".", "-")
    age = int(fnum(row.get("entry_signal_age_bars")))
    row["child_flip_age_bucket"] = "age_0" if age == 0 else "age_1" if age == 1 else "age_2_plus"
    updates = int(fnum(row.get("child_anchor_update_count")))
    row["child_anchor_update_bucket"] = "0" if updates == 0 else "1" if updates == 1 else "2_plus"


def copy_artifacts(run, paths):
    target = OUT / run["run_id"]
    target.mkdir(parents=True, exist_ok=True)
    copied_events = target / "events.csv"
    if copied_events.exists():
        copied_events.unlink()
    for key, name in (("preset", "preset.set"), ("tester_ini", "tester.ini")):
        source = REPO / run[key]
        if source.exists():
            shutil.copy2(source, target / name)
    for name, source in paths.items():
        if name != "events" and source.exists():
            shutil.copy2(source, target / f"{name}.csv")
    report_root = REPO / "reports" / "backtest"
    for source in report_root.glob(f"{EA_NAME}_fw2sr_{run['run_id']}_report*"):
        shutil.copy2(source, target / source.name.replace(f"{EA_NAME}_fw2sr_{run['run_id']}_", ""))


def event_stages(row):
    state = row.get("strategy_state", "")
    event = row.get("event", "")
    reason = row.get("state_change_reason", "")
    stage = row.get("signal_consumption_stage", "")
    output = []
    if state == "PARENT_FLIP_DETECTED": output.append("parent_flips_detected")
    if state == "PARENT_WAVE1_CONFIRMED": output.append("parent_wave1_confirmed")
    if state == "PARENT_WAVE2_PENDING": output.append("parent_wave2_pending")
    if state == "PARENT_WAVE2_ACTIVE":
        if reason == "first_opposite_close": output.append("parent_wave2_started_first_close")
        elif reason == "confirmed_wave1_terminal_pivot": output.append("parent_wave2_started_confirmed_pivot")
        elif reason == "child_countertrend_confirmed": output.append("parent_wave2_started_child_trend")
    if state == "CHILD_COUNTER_TREND_CONFIRMED": output.append("child_countertrend_confirmed")
    if event == "child_anchor_created": output.append("child_anchor_created")
    if event == "child_anchor_updated": output.append("child_anchor_updated")
    if state == "CHILD_TREND_FLIPPED":
        output.append("child_flip_detected")
        if bval(row.get("child_flip_is_fresh")): output.append("fresh_first_flip_signal")
    if state == "SIGNAL_RESERVED": output.extend(("valid_candidate", "signal_reserved"))
    if state == "SIGNAL_CONSUMED":
        if stage == "invalid_candidate": output.append("candidate_invalid")
        elif stage == "position_cap": output.extend(("portfolio_selected", "position_cap_reject"))
        elif stage == "risk_block": output.extend(("portfolio_selected", "risk_reject"))
        elif stage == "order_failure": output.extend(("portfolio_selected", "order_failure"))
        elif stage == "traded": output.extend(("portfolio_selected", "trades_taken"))
    if state == "EXPIRED": output.append("expired")
    if state == "INVALIDATED": output.append("parent_invalidated")
    return output


def fmt(row):
    if not row:
        return "missing"
    return (f"{int(fnum(row.get('trades')))} trades / PF {fnum(row.get('profit_factor')):.2f} / "
            f"avg_R {fnum(row.get('avg_r')):+.4f} / net {fnum(row.get('net_profit')):+.2f} / "
            f"MFE>=1R {fnum(row.get('mfe_ge_1_0r_rate')):.1%}")


def write_summary(comparison, summary_by_run, events_by_run, rejection_rows):
    full = {row["variant"]: row for row in comparison if row["period_id"] == "full2025_validation"}
    mode0 = full.get("f_base_first_child_flip_mode0")
    mode1 = full.get("g_base_first_child_flip_mode1")
    mode2 = full.get("h_base_first_child_flip_mode2")
    parent_stop = full.get("j_parent_stop_extreme_mode2")
    diagnostic = summary_by_run.get("full2025_e_latest_child_anchor_diagnostic", {})
    mode2_summary = summary_by_run.get("full2025_h_base_first_child_flip_mode2", {})
    legacy = summary_by_run.get("full2025_a_diagnostic_current_code", {})
    mode_counts = {
        0: summary_by_run.get("full2025_b_wave2_start_first_close", {}).get("parent_wave2_started", "missing"),
        1: summary_by_run.get("full2025_c_wave2_start_confirmed_pivot", {}).get("parent_wave2_started", "missing"),
        2: summary_by_run.get("full2025_d_wave2_start_child_countertrend", {}).get("parent_wave2_started", "missing"),
    }
    changed = set()
    for row in events_by_run.get("full2025_e_latest_child_anchor_diagnostic", []):
        if bval(row.get("child_anchor_changed_after_initial_detection")):
            changed.add(row.get("parent_event_id"))
    legacy_flip_ids = {row.get("child_event_id") or row.get("child_trend_flip_event_id")
                       for row in events_by_run.get("full2025_a_diagnostic_current_code", [])
                       if row.get("strategy_state") == "CHILD_TREND_FLIPPED"}
    legacy_latest_ids = {row.get("child_event_id") or row.get("child_trend_flip_event_id")
                         for row in events_by_run.get("full2025_a_diagnostic_current_code", [])
                         if row.get("strategy_state") == "CHILD_TREND_FLIPPED"
                         and bval(row.get("child_anchor_is_latest_valid"))}
    legacy_old_anchor_flips = len({value for value in legacy_flip_ids if value}) - len(
        {value for value in legacy_latest_ids if value})
    invalid_reasons = defaultdict(int)
    for row in rejection_rows:
        if row.get("run_id") == "full2025_h_base_first_child_flip_mode2" and "candidate_invalid" in row.get("reason", ""):
            invalid_reasons[row.get("reason", "unknown")] += int(fnum(row.get("count")))
    invalid_text = ", ".join(f"{key}={value}" for key, value in sorted(invalid_reasons.items())) or "none"
    continued = [row["run_id"] for row in comparison if bval(row.get("passed_research_continuation"))]
    passed = [row["run_id"] for row in comparison if bval(row.get("passed_2025_gate"))]
    lines = [
        "# Fractal Wave2 Transition State Review",
        "",
        "## Scope",
        "- 対象は新EAのみ。旧 `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` は変更していない。",
        "- M15/M5 pivotは左右 `InpPivotDepth` 本が閉じた後だけ利用する。未確定足・未来参照・repaint ZigZagは使わない。",
        "- tester=M15だがscanは各symbolのM5確定足更新で実行する。H1=16385、M15=15、M5=5をpresetで確認した。",
        "- `[Experts] Enabled=0`、`AllowLiveTrading=0`、Model=4、Deposit=10000の固定run。",
        "",
        "## Full 2025 Trade Runs",
        f"- Mode 0: {fmt(mode0)}",
        f"- Mode 1: {fmt(mode1)}",
        f"- Mode 2: {fmt(mode2)}",
        f"- Mode 2 parent-stop reference: {fmt(parent_stop)}",
        "",
        "## Required Answers",
        "1. 修正前のM15 wave2開始は、parent break後に前足終値と逆方向へ動いた最初のM15 closeだった。",
        "2. はい。逆方向close 1本だけで `PARENT_WAVE2_ACTIVE` へ遷移していた。",
        "3. `PARENT_WAVE2_PENDING` と `SIGNAL_RESERVED` を追加した。pending親は確認待ち中に新しい親候補へ不正置換されない。",
        f"4. 通年wave2開始数は Mode 0={mode_counts[0]}、Mode 1={mode_counts[1]}、Mode 2={mode_counts[2]}。",
        "5. 修正前 `UpdateChildTrend()` は最古から走査し、最初に成立した3-pivot構造とanchorを使っていた。",
        "6. 修正後は確定pivotのみで新安値/新高値ごとに最新有効anchorを版管理し、旧anchorを置換する。",
        f"7. first/latest anchorが異なったparent eventは {len(changed)} 件。",
        f"8. 修正前相当では旧anchor flipが {legacy_old_anchor_flips} 件あった。latest modeでは取引がすべて最新anchorだが、同一signalの反実仮想ではないため損益の単独因果は断定しない。",
        f"9. Mode 2 child countertrend成立数は {diagnostic.get('child_countertrend_confirmed', 'missing')}。",
        f"10. Mode 2 child anchor作成数は {diagnostic.get('child_anchor_created', 'missing')}。",
        f"11. Mode 2 child anchor更新数は {diagnostic.get('child_anchor_updated', 'missing')}。",
        f"12. Mode 2 child flip数は {diagnostic.get('child_trend_flips_detected', 'missing')}。",
        f"13. Mode 2 fresh first flip数は {diagnostic.get('fresh_first_flip_signals', 'missing')}。",
        f"14. Mode 2 candidate validationは有効={mode2_summary.get('valid_candidates', 'missing')}、失効={mode2_summary.get('candidate_invalid', 'missing')}。理由は {invalid_text}。portfolio rejectionとは分離した。",
        "15. 技術無効は `invalid_candidate`、有効候補は `before_portfolio` で予約し、その後をposition/risk/order/tradedに分離した。",
        f"16. 実trade数は Mode 0={int(fnum(mode0.get('trades') if mode0 else 0))}、Mode 1={int(fnum(mode1.get('trades') if mode1 else 0))}、Mode 2={int(fnum(mode2.get('trades') if mode2 else 0))}。",
        f"17. mode別成績: Mode 0 {fmt(mode0)} / Mode 1 {fmt(mode1)} / Mode 2 {fmt(mode2)}。",
        f"18. 研究継続条件通過: {', '.join(continued) if continued else 'none'}。",
        f"19. 2025 shallow gate通過: {', '.join(passed) if passed else 'none'}。",
        f"20. 3年BT/OOS: {'gate通過候補があるため検討対象' if passed else '実施しない。2025 gate未通過'}。",
        "",
        "## Code Review Findings",
        "- Mode 1が初回Q1で0件になった原因は、pending親がterminal pivot確定前に新parentへ置換される状態機械バグだった。親確認窓を保持して修正し、全runを再実行した。",
        "- candidate invalidは再評価ごとに重複計数せず、parent signalごとに一度失効するよう修正した。",
        "- 最新anchorの最初の終値breakだけをfresh signalとし、過去breakの再利用は `stale_child_flip_not_reused` として失効する。",
        "",
        "## Decision",
        ("- 2025 shallow gate通過候補があるため、依存性と3年固定BT条件を追加確認する。" if passed else
         "- 2025 shallow gate通過候補なし。3年BT/OOS、demo/live、細かい閾値最適化へは進めない。"),
        f"- 修正前相当diagnostic child flips={legacy.get('child_trend_flips_detected', 'missing')}、latest Mode 2 diagnostic child flips={diagnostic.get('child_trend_flips_detected', 'missing')}。",
    ]
    (OUT / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    matrix = read_csv(MATRIX)
    comparison, all_trades = [], []
    funnel_rows, rejection_rows = [], []
    events_by_run, summary_by_run = {}, {}
    by_symbol = defaultdict(int)
    by_direction = defaultdict(int)
    state_counts = defaultdict(int)
    signal_counts = defaultdict(int)
    child_counter_counts = defaultdict(int)
    child_flip_counts = defaultdict(int)

    for run in matrix:
        paths = run_paths(run)
        copy_artifacts(run, paths)
        summary = read_csv(paths["summary"])
        summary_row = summary[-1] if summary else {}
        summary_by_run[run["run_id"]] = summary_row
        events = read_csv(paths["events"])
        events_by_run[run["run_id"]] = events
        trades = dedupe(read_csv(paths["trades"]))
        for trade in trades:
            add_trade_metadata(trade, run)
            all_trades.append(trade)
        result = stats(trades)
        stopped = bval(summary_row.get("daily_stopped")) or bval(summary_row.get("drawdown_stopped"))
        common_gate = (result["profit_factor"] >= 1.05 and result["avg_r"] > 0
                       and result["net_profit"] > 0 and not stopped and dependence_ok(trades))
        research = (run["period_id"] == "full2025_validation" and common_gate
                    and result["trades"] >= 100 and result["mfe_ge_1_0r_rate"] >= 0.27)
        shallow = run["period_id"] == "full2025_validation" and common_gate and result["trades"] >= 200
        comparison.append({
            **run, **result, "daily_or_dd_stopped": stopped,
            "max_symbol_positive_profit_share": concentration_share(trades, "symbol") if trades else 0.0,
            "max_session_positive_profit_share": concentration_share(trades, "session_label") if trades else 0.0,
            "passed_research_continuation": research, "passed_2025_gate": shallow,
        })
        for row in read_csv(paths["funnel"]):
            funnel_rows.append({**{k: run[k] for k in ("run_id", "period_id", "variant", "variant_name")}, **row})
        for row in read_csv(paths["rejections"]):
            rejection_rows.append({**{k: run[k] for k in ("run_id", "period_id", "variant", "variant_name")}, **row})
        for row in events:
            direction = row.get("parent_direction", "NONE") or "NONE"
            symbol = row.get("symbol", "unknown") or "unknown"
            for stage in event_stages(row):
                by_symbol[(run["run_id"], run["period_id"], run["variant"], symbol, stage)] += 1
                by_direction[(run["run_id"], run["period_id"], run["variant"], direction, stage)] += 1
            if row.get("event") == "state_transition":
                state_counts[(run["run_id"], run["period_id"], run["variant"],
                              row.get("previous_strategy_state", ""), row.get("strategy_state", ""),
                              row.get("state_change_reason", ""))] += 1
            if row.get("strategy_state") in {"SIGNAL_RESERVED", "SIGNAL_CONSUMED", "EXPIRED"}:
                signal_counts[(run["run_id"], run["period_id"], run["variant"],
                               row.get("signal_consumption_stage", ""), row.get("signal_not_traded_reason", ""),
                               row.get("signal_validation_pass", ""), row.get("signal_validation_reject_reason", ""))] += 1
            if row.get("event") in {"child_anchor_created", "child_anchor_updated"}:
                child_counter_counts[(run["run_id"], run["period_id"], run["variant"],
                                      row.get("child_countertrend_confirmed", ""),
                                      row.get("child_countertrend_reject_reason", ""),
                                      row.get("child_countertrend_swing_count", ""),
                                      row.get("child_countertrend_extension_count", ""))] += 1
            if row.get("strategy_state") == "CHILD_TREND_FLIPPED":
                child_flip_counts[(run["run_id"], run["period_id"], run["variant"],
                                   row.get("child_flip_is_fresh", ""),
                                   row.get("child_anchor_is_latest_valid", ""),
                                   row.get("child_flip_anchor_version", ""),
                                   row.get("child_flip_signal_age_bars", ""))] += 1

    write_csv(OUT / "q1_comparison.csv", [row for row in comparison if row["period_id"] == "q1_quick"])
    write_csv(OUT / "full2025_comparison.csv", [row for row in comparison if row["period_id"] == "full2025_validation"])
    write_csv(OUT / "trades_all_scenarios.csv", all_trades)
    write_csv(OUT / "funnel_breakdown.csv", funnel_rows)
    write_csv(OUT / "funnel_by_symbol.csv", [
        {"run_id": k[0], "period_id": k[1], "variant": k[2], "symbol": k[3], "stage": k[4], "count": v}
        for k, v in sorted(by_symbol.items())])
    write_csv(OUT / "funnel_by_direction.csv", [
        {"run_id": k[0], "period_id": k[1], "variant": k[2], "direction": k[3], "stage": k[4], "count": v}
        for k, v in sorted(by_direction.items())])
    write_csv(OUT / "state_transition_breakdown.csv", [
        {"run_id": k[0], "period_id": k[1], "variant": k[2], "previous_state": k[3],
         "strategy_state": k[4], "reason": k[5], "count": v}
        for k, v in sorted(state_counts.items())])
    write_csv(OUT / "rejection_reason_breakdown.csv", rejection_rows)
    write_csv(OUT / "signal_consumption_breakdown.csv", [
        {"run_id": k[0], "period_id": k[1], "variant": k[2], "consumption_stage": k[3],
         "not_traded_reason": k[4], "validation_pass": k[5], "validation_reject_reason": k[6], "count": v}
        for k, v in sorted(signal_counts.items())])
    write_csv(OUT / "parent_wave2_start_mode_breakdown.csv",
              grouped_stats(all_trades, ["period_id", "parent_wave2_start_mode", "variant"]))
    write_csv(OUT / "child_anchor_update_breakdown.csv",
              grouped_stats(all_trades, ["period_id", "child_anchor_update_bucket", "child_anchor_is_latest_valid"]))
    first_latest_rows = []
    for run in matrix:
        if run["variant"] not in {"a_diagnostic_current_code", "e_latest_child_anchor_diagnostic"}:
            continue
        events = events_by_run.get(run["run_id"], [])
        changed = {row.get("parent_event_id") for row in events
                   if bval(row.get("child_anchor_changed_after_initial_detection"))}
        flip_ids = {row.get("child_event_id") or row.get("child_trend_flip_event_id") for row in events
                    if row.get("strategy_state") == "CHILD_TREND_FLIPPED"}
        latest_flips = {row.get("child_event_id") or row.get("child_trend_flip_event_id") for row in events
                        if row.get("strategy_state") == "CHILD_TREND_FLIPPED"
                        and bval(row.get("child_anchor_is_latest_valid"))}
        first_latest_rows.append({
            "comparison_type": "diagnostic_structure", "run_id": run["run_id"],
            "period_id": run["period_id"], "variant": run["variant"],
            "child_anchor_mode": run["child_anchor_mode"],
            "parent_events_with_anchor_change": len(changed),
            "child_flip_events": len({value for value in flip_ids if value}),
            "latest_valid_anchor_flip_events": len({value for value in latest_flips if value}),
        })
    for row in grouped_stats(all_trades, ["period_id", "child_anchor_mode", "child_anchor_is_latest_valid",
                                         "child_anchor_changed_after_initial_detection"]):
        first_latest_rows.append({"comparison_type": "trade_performance", **row})
    write_csv(OUT / "first_vs_latest_child_anchor.csv", first_latest_rows)
    write_csv(OUT / "child_countertrend_breakdown.csv", [
        {"run_id": k[0], "period_id": k[1], "variant": k[2], "confirmed": k[3],
         "reject_reason": k[4], "swing_count": k[5], "extension_count": k[6], "count": v}
        for k, v in sorted(child_counter_counts.items())])
    write_csv(OUT / "child_flip_breakdown.csv", [
        {"run_id": k[0], "period_id": k[1], "variant": k[2], "fresh": k[3],
         "latest_valid_anchor": k[4], "anchor_version": k[5], "signal_age_bars": k[6], "count": v}
        for k, v in sorted(child_flip_counts.items())])
    write_csv(OUT / "mfe_by_child_anchor_update_count.csv",
              grouped_stats(all_trades, ["period_id", "child_anchor_update_bucket"]))
    write_csv(OUT / "mfe_by_child_flip_age.csv",
              grouped_stats(all_trades, ["period_id", "child_flip_age_bucket"]))
    write_csv(OUT / "mfe_by_parent_wave2_start_mode.csv",
              grouped_stats(all_trades, ["period_id", "parent_wave2_start_mode"]))
    for filename, key in (("symbol_breakdown.csv", "symbol"), ("direction_breakdown.csv", "direction"),
                          ("session_breakdown.csv", "session_label"), ("monthly_breakdown.csv", "month"),
                          ("yearly_breakdown.csv", "year")):
        write_csv(OUT / filename, grouped_stats(all_trades, ["period_id", "variant", key]))
    compile_log = REPO / "reports" / "compile" / "metaeditor.log"
    if compile_log.exists():
        shutil.copy2(compile_log, OUT / "compile.log")
    write_summary(comparison, summary_by_run, events_by_run, rejection_rows)
    print(f"Analyzed {len(matrix)} runs, {len(all_trades)} trades -> {OUT}")


if __name__ == "__main__":
    main()
