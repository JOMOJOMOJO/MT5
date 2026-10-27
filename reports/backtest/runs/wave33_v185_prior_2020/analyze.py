"""Preregistered two-arm prior-level comparison, M5/M1, ScaleOut OFF.

No parameter search. Native deal cash is aggregated by position. Matching uses
normalized source-clock times and decimal prices, never run-local setup IDs.
The earlier 119/215 split is descriptive deletion, not the live EA experiment.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
from datetime import datetime
from decimal import Decimal as D
import hashlib
import json
from pathlib import Path

import native_audit as audit

RUNS = ("v185_b_prior_off", "v185_b_prior_on")
OLD_BATCH = "20261026_100045_50909ab6"
OLD_RUN = "v185_b_scale_off"


def norm_time(value):
    value = str(value or "").strip()
    if not value:
        return ""
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(value, fmt).strftime("%Y.%m.%d %H:%M:%S")
        except ValueError:
            pass
    raise ValueError(f"Unsupported source-clock timestamp: {value!r}")


def norm_price(value):
    return format(audit.num(value).normalize(), "f")


def side(value):
    return "LONG" if str(value) in ("LONG", "1") else "SHORT"


def wave_key(row):
    return tuple([
        side(row["direction"]), norm_time(row.get("upper_break_bar_time")),
        norm_time(row.get("upper_break_level_time")),
        norm_time(row.get("wave1_start_time", row.get("start_time"))),
        norm_price(row.get("wave1_start_price", row.get("start_price"))),
        norm_time(row.get("wave1_peak_time", row.get("peak_time"))),
        norm_price(row.get("wave1_peak_price", row.get("peak_price"))),
    ])


def time_key(row):
    return wave_key(row) + (norm_time(row["entry_at"]),)


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def read_inputs(path):
    return dict(line.split("=", 1) for line in path.read_text(encoding="utf-8-sig").splitlines() if "=" in line)


def difference(a, b):
    return {k: [a.get(k), b.get(k)] for k in a.keys() | b.keys() if a.get(k) != b.get(k)}


def aggregate(values):
    values = sorted(values, key=lambda p: (p["exit_at"], p["position_id"]))
    profit = sum((max(p["net_cash"], D(0)) for p in values), D(0))
    loss = sum((min(p["net_cash"], D(0)) for p in values), D(0))
    total_r = sum((p["net_r"] for p in values), D(0))
    return dict(positions=len(values), wins=sum(p["net_cash"] > 0 for p in values),
                losses=sum(p["net_cash"] < 0 for p in values),
                net_cash=sum((p["net_cash"] for p in values), D(0)),
                sum_r=total_r, mean_r=total_r/len(values) if values else None,
                net_pf=audit.ratio(profit, loss),
                max_loss_streak=audit.max_streak([p["net_cash"] for p in values], False))


def prior_observations(path, positions, enabled):
    """One SIGNAL snapshot per setup; no post-entry context substitution."""
    signals, skips, orders, fills = {}, {}, set(), set()
    for row in audit.stream_rows(path/"events.csv"):
        event, setup = row["event_type"], row["setup_id"]
        if event == "SIGNAL":
            audit.check(setup not in signals, "one_signal_snapshot_per_setup", run=path.name, setup=setup)
            signals[setup] = row
        elif event == "SKIP":
            skips[setup] = row
        elif event == "ORDER":
            orders.add(setup)
        elif event == "FILL":
            fills.add(setup)
    contexts = {}
    for row in audit.stream_rows(path/"context.csv"):
        if row["source_event"] != "SIGNAL":
            continue
        setup = row["setup_id"]
        audit.check(setup not in contexts, "one_context_at_signal", run=path.name, setup=setup)
        contexts[setup] = row
    audit.check(set(signals) == set(contexts), "all_signals_have_context_snapshot", run=path.name)
    blocked, output = [], []
    by_setup = {p["setup_id"]: p for p in positions}
    for setup, signal in signals.items():
        row = contexts.get(setup)
        if row is None:
            continue
        evaluated = norm_time(row["evaluation_at"])
        audit.check(evaluated == norm_time(signal["event_at"]), "context_is_signal_time", run=path.name, setup=setup)
        audit.check(audit.num(row["band_fraction"]) == D("0.05"), "fixed_band_halfwidth", run=path.name, setup=setup)
        audit.check((row["entry_filter_enabled"] == "1") == enabled, "actual_context_filter_flag", run=path.name, setup=setup)
        is_blocked = row["status"] == "BLOCKED" and row["blocked"] == "1"
        if is_blocked:
            blocked.append(setup)
            # These are operational invariants, not a new posthoc detector.
            audit.check(row["wave1_near_band"] == row["tp_beyond_band"] == row["has_latest_close"] == "1",
                        "blocked_meets_existing_positive_predicates", run=path.name, setup=setup)
            audit.check(row["entry_passed_band"] == row["latest_close_beyond_band"] == "0",
                        "blocked_band_not_already_passed", run=path.name, setup=setup)
            audit.check(norm_time(row["source_time"]) < norm_time(row["start_time"]),
                        "source_precedes_wave1", run=path.name, setup=setup)
            audit.check(norm_time(row["source_known_at"]) <= evaluated and
                        norm_time(row["latest_close_closed_at"]) <= norm_time(row["latest_close_known_at"]) <= evaluated,
                        "blocked_evidence_available_by_signal", run=path.name, setup=setup)
            if enabled:
                audit.check(skips.get(setup, {}).get("reason") == "PRIOR_LEVEL_RETEST",
                            "blocked_signal_actually_skipped", run=path.name, setup=setup)
                audit.check(setup not in orders and setup not in fills,
                            "blocked_has_no_order_or_fill", run=path.name, setup=setup)
        if enabled and skips.get(setup, {}).get("reason") == "PRIOR_LEVEL_RETEST":
            audit.check(is_blocked, "every_prior_skip_has_asof_blocked_snapshot", run=path.name, setup=setup)
        p = by_setup.get(setup, {})
        output.append(dict(run=path.name, setup_id=setup, direction=side(signal["direction"]),
            signal_at=signal["event_at"], entry_at=p.get("entry_at", ""), context_status=row["status"],
            context_reason=row["reason"], actual_skip_reason=skips.get(setup, {}).get("reason", ""),
            has_fill=setup in fills, net_r=p.get("net_r"), net_cash=p.get("net_cash"),
            source_tf=row["source_tf"], source_time=row["source_time"], source_known_at=row["source_known_at"],
            source_price=row["source_price"], band_fraction=row["band_fraction"],
            latest_close_known_at=row["latest_close_known_at"], evaluation_at=row["evaluation_at"],
            wave_identity="|".join(wave_key(signal))))
    filled_blocked = [p for p in positions if p["setup_id"] in blocked]
    filled_clear = [p for p in positions if p["setup_id"] not in blocked]
    stats = dict(signals=len(signals), status_counts=dict(Counter(r["status"] for r in contexts.values())),
                 blocked_signals=len(blocked), prior_level_skips=sum(r["reason"] == "PRIOR_LEVEL_RETEST" for r in skips.values()),
                 skip_reasons=dict(Counter(r["reason"] for r in skips.values())),
                 filled_blocked=aggregate(filled_blocked), filled_not_blocked=aggregate(filled_clear))
    return stats, output, signals, skips, contexts


def group_metrics(positions):
    groups = defaultdict(list)
    for p in positions:
        month = int(p["entry_at"][5:7])
        quarter = f"2020-Q{(month-1)//3+1}"
        groups[("quarter", quarter)].append(p)
        groups[("direction", p["direction"])].append(p)
        groups[("quarter_direction", quarter+"_"+p["direction"])].append(p)
    return [dict(group_type=k[0], group=k[1], **aggregate(v)) for k, v in sorted(groups.items())]


def deal_signature(path):
    # Tickets and setup IDs also must reproduce; tag is not in raw deal comment.
    result = []
    for r in audit.rows(path/"raw_deals.csv"):
        d = audit.canonical_deal(r)
        result.append(tuple(d[k] for k in ("deal", "order", "position_id", "time_msc", "setup_id",
                                           "entry", "type", "volume", "price", "profit", "commission", "swap", "fee", "comment", "reason")))
    return result


def baseline_reproduction(batch, baseline, smoke, result):
    current = batch/RUNS[0]
    prior = baseline/OLD_RUN
    actual_diff = difference(read_inputs(prior/"inputs.set"), read_inputs(current/"inputs.set"))
    audit.check(set(actual_diff) == {"InpRunTag"}, "off_reproduces_prior_inputs_except_tag", differences=actual_diff)
    old_manifest, new_manifest = (load_json(p/"deployment.json") for p in (baseline, batch))
    for field in ("source_sha256", "binary_sha256", "header_sha256"):
        audit.check(old_manifest[field] == new_manifest[field], "baseline_same_deployment", field=field)
    old_proof, new_proof = (load_json(p/"provenance.json") for p in (baseline, batch))
    for field in ("cache_sha256", "runtime_sha256", "symbol", "model", "deposit", "server"):
        audit.check(old_proof[field] == new_proof[field], "baseline_same_native_environment", field=field)
    same_deals = same_bars = None
    if not smoke:
        same_deals = deal_signature(prior) == deal_signature(current)
        audit.check(same_deals, "off_all_deals_reproduce_prior_baseline")
        same_bars = all(audit.sha(prior/p) == audit.sha(current/p) for p in ("upper_bars.csv", "lower_bars.csv"))
        audit.check(same_bars, "off_all_accepted_bars_reproduce_prior_baseline")
        audit.check(result["closed_positions"] == 334 and result["native"]["net"] == D("-1440.92"),
                    "off_known_334_minus1440_92_reproduced")
    return dict(reference=str(baseline), inputs_diff=actual_diff, all_deals_identical=same_deals,
                accepted_bars_identical=same_bars, full_year_reproduction_required=not smoke)


def compare_positions(off, on, on_signals, on_skips, off_context):
    off_map = {wave_key(p): p for p in off}
    on_map = {wave_key(p): p for p in on}
    audit.check(len(off_map) == len(off) and len(on_map) == len(on), "unique_normalized_wave_identity")
    on_signal_by_wave = defaultdict(list)
    for setup, row in on_signals.items():
        on_signal_by_wave[wave_key(row)].append((setup, row))
    rows, excluded, added, common_fixed, retimed = [], [], [], [], []
    for key in sorted(off_map.keys() | on_map.keys()):
        a, b = off_map.get(key), on_map.get(key)
        row = dict(wave_identity="|".join(key), direction=key[0], off_setup=a["setup_id"] if a else "",
                   on_setup=b["setup_id"] if b else "", off_entry=a["entry_at"] if a else "", on_entry=b["entry_at"] if b else "",
                   off_net_r=a["net_r"] if a else None, on_net_r=b["net_r"] if b else None,
                   off_net_cash=a["net_cash"] if a else None, on_net_cash=b["net_cash"] if b else None)
        if a and b:
            same_time = time_key(a) == time_key(b)
            row["class"] = "MATCHED_SAME_ENTRY_TIME" if same_time else "SAME_WAVE_RETIMED"
            row["delta_r"] = b["net_r"]-a["net_r"]
            row["same_entry_price_sl_tp"] = all(a[k] == b[k] for k in ("entry_price", "initial_sl", "planned_tp"))
            row["same_exit_time_reason"] = all(a[k] == b[k] for k in ("exit_at", "exit_reason"))
            (common_fixed if same_time else retimed).append((a,b))
        elif a:
            candidates = on_signal_by_wave.get(key, [])
            reasons = [on_skips.get(setup, {}).get("reason", "NO_SKIP_EVENT") for setup, _ in candidates]
            row["on_candidate_skips"] = "|".join(reasons)
            row["off_signal_context"] = off_context[a["setup_id"]]["status"]
            row["class"] = "OFF_ONLY_PRIOR_SKIP" if "PRIOR_LEVEL_RETEST" in reasons else "OFF_ONLY_OTHER_OR_NO_SIGNAL"
            excluded.append(a)
        else:
            row["class"] = "ON_ONLY_ADDED_POSITION"
            added.append(b)
        rows.append(row)
    counts = dict(Counter(r["class"] for r in rows))
    direct = [off_map[tuple(r["wave_identity"].split("|"))] for r in rows if r["class"] == "OFF_ONLY_PRIOR_SKIP"]
    return dict(class_counts=counts, off_only_descriptive=aggregate(excluded), direct_prior_skip_descriptive=aggregate(direct),
                on_only_added=aggregate(added), matched_same_time=len(common_fixed), retimed_same_wave=len(retimed),
                matched_same_time_delta_r=sum((b["net_r"]-a["net_r"] for a,b in common_fixed),D(0)),
                matched_exit_changed=sum(any(a[k] != b[k] for k in ("exit_at", "exit_reason")) for a,b in common_fixed),
                caveat="Removing 119 old fills would leave 215 only as a posthoc deletion. Actual ON may free lanes, add candidates, change exits or compounding lots."), rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch", type=Path, required=True)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--short-smoke", action="store_true")
    args = parser.parse_args()
    batch = args.batch.resolve()
    repo = next(p for p in batch.parents if (p/"tools/wave33_visual").is_dir())
    baseline = args.baseline or repo/"reports/backtest/runs/wave33_v185_2020"/OLD_BATCH
    audit.SHORT_SMOKE = args.short_smoke
    manifest, proof = load_json(batch/"deployment.json"), load_json(batch/"provenance.json")
    for filename, expected in proof.get("method_sha256", {}).items():
        audit.check(audit.sha(batch/"method"/filename) == expected, "frozen_analysis_method_hash", file=filename)
    audit.check(audit.sha(batch/"deployment.json") == proof["deployment_sha256"], "frozen_deployment_hash")
    for filename, key in (("Wave33ChopDiagnostic.mq5","source_sha256"), ("Wave33ChopDiagnostic.ex5","binary_sha256")):
        audit.check(audit.sha(batch/filename).lower() == manifest[key].lower(), "frozen_ea_matches_qa", file=filename)
    for name, expected in manifest["header_sha256"].items():
        audit.check(audit.sha(batch/"frozen_include"/name.replace("\\", "/")).lower() == expected.lower(), "frozen_header_matches_qa", file=name)
    results, positions, signals, skips, contexts, observations, groups = {}, {}, {}, {}, {}, [], []
    for name in RUNS:
        results[name], positions[name] = audit.audit_run(batch/name)
        config = {r["parameter"]:r["value"] for r in audit.rows(batch/name/"config.csv")}
        audit.check(config["upper_tf"] == "PERIOD_M5" and config["lower_tf"] == "PERIOD_M1", "fixed_m5_m1", run=name)
        audit.check((config["skip_prior_level_retest"].lower() in {"true","1"}) == name.endswith("_on"), "actual_prior_filter_input", run=name)
        stats, obs, signals[name], skips[name], contexts[name] = prior_observations(batch/name, positions[name], name.endswith("_on"))
        results[name]["prior_context"] = stats
        observations.extend(obs)
        groups.extend(dict(run=name, **r) for r in group_metrics(positions[name]))
    input_diff = difference(*(read_inputs(batch/name/"inputs.set") for name in RUNS))
    audit.check(set(input_diff) == {"InpSkipPriorLevelRetest", "InpRunTag"}, "only_prior_filter_and_tag_change", differences=input_diff)
    config_diff = difference(*({r["parameter"]:r["value"] for r in audit.rows(batch/name/"config.csv")} for name in RUNS))
    audit.check(set(config_diff) == {"skip_prior_level_retest", "resolved_run_tag", "input_hash"}, "actual_config_one_policy_change", differences=config_diff)
    for filename in ("upper_bars.csv", "lower_bars.csv"):
        audit.check(audit.sha(batch/RUNS[0]/filename) == audit.sha(batch/RUNS[1]/filename), "identical_accepted_source_bars", file=filename)
    audit.check(results[RUNS[0]]["native"]["ticks"] == results[RUNS[1]]["native"]["ticks"], "same_native_tick_count")
    audit.check(load_json(batch/RUNS[0]/"runtime_before.json") == load_json(batch/RUNS[1]/"runtime_before.json"), "same_runtime_between_arms")
    reproduction = baseline_reproduction(batch, baseline, args.short_smoke, results[RUNS[0]])
    if not args.short_smoke:
        audit.check(results[RUNS[0]]["prior_context"]["filled_blocked"]["positions"] == 119 and
                    results[RUNS[0]]["prior_context"]["filled_not_blocked"]["positions"] == 215,
                    "prior_119_215_asof_classification_reproduced")
    comparison, paired = compare_positions(positions[RUNS[0]], positions[RUNS[1]], signals[RUNS[1]], skips[RUNS[1]], contexts[RUNS[0]])
    comparison["input_differences"] = input_diff
    comparison["actual_config_differences"] = config_diff
    comparison["net_cash_delta"] = results[RUNS[1]]["native"]["net"]-results[RUNS[0]]["native"]["net"]
    comparison["sum_r_delta"] = results[RUNS[1]]["sum_r"]-results[RUNS[0]]["sum_r"]
    net_positive = results[RUNS[1]]["native"]["net"] > 0 and results[RUNS[1]]["sum_r"] > 0
    outcome = dict(status="PASS" if not audit.FAILURES else "FAIL", checks=audit.CHECKS, failures=audit.FAILURES,
        scope="SHORT_SMOKE_NOT_ANNUAL" if args.short_smoke else "FIXED_KNOWN_2020_PRIOR_LEVEL_COMPARISON",
        baseline_reproduction=reproduction, runs=results, comparison=comparison,
        decision="NO_PROMOTION_NEGATIVE_EXPECTANCY" if not net_positive else "REQUIRES_FIXED_UNUSED_PERIOD_VALIDATION",
        limitations=["Known 2020 and generated ticks; posthoc mechanism diagnostic, not out-of-sample evidence.",
                     "Actual ON is a fresh full EA run. 334 minus 119 equals 215 is only descriptive deletion, not expected native trade count.",
                     "Entry filters can release lanes and alter later candidates and opposite-wave exits; no attribution from deleting old trades alone.",
                     "Position-level PF includes profit, commission, swap and fee; R uses immutable original structural risk.",
                     "Historical commission/swap schedule is not independently established; future execution costs can differ.",
                     "Native equity DD cannot be independently rebuilt without full tick equity trajectory.",
                     "Quarter/direction tables are diagnostics only; no subset selection, band/RR tuning, or 2026 data."])
    out = batch/"analysis"; out.mkdir(exist_ok=True)
    audit.save_json(out/"summary.json", outcome)
    audit.write_csv(out/"positions.csv", [p for values in positions.values() for p in values])
    audit.write_csv(out/"paired_positions.csv", paired)
    audit.write_csv(out/"signal_context.csv", observations)
    audit.write_csv(out/"groups.csv", groups)
    lines = ["# M5×M1 上位高安帯フィルター固定比較", "", f"独立整合監査: **{outcome['status']} / {audit.CHECKS}項目**。技術整合と利益の採用判断は別。", "",
             "| フィルター | 完了position | 費用込み損益 USD | PF | 合計R | 平均R | 最大連敗 | native equity DD |",
             "|---|---:|---:|---:|---:|---:|---:|---|"]
    fmt = lambda v: "—" if v is None else f"{v:.4f}"
    for name in RUNS:
        r=results[name]
        lines.append(f"| {name} | {r['closed_positions']} | {r['native']['net']:.2f} | {fmt(r['position_net_pf'])} | {r['sum_r']:.3f} | {fmt(r['mean_r'])} | {r['max_loss_streak']} | {r['native']['equity_dd']} |")
    lines += ["", "部分利確OFF、RR入力1、risk1%、帯片幅0.05、XAUUSD+、初期5000 USD。変更は既存の見送りスイッチだけ。",
              "", "既知の2020年・生成ティック。同一期間の機序診断であり未使用期間の確認ではない。2026データを使わず、帯幅・RRは探索しない。",
              "", "334件からBLOCKED119件を単純に引くと215件になるが、これは過去約定を削除した参考集計。EAのON結果には枠解放後の追加候補・出口の変化・複利ロットを含む。",
              "", f"採用判定: `{outcome['decision']}`。費用込み損益または合計Rが負なら採用しない。",
              "", "全監査は[summary.json](summary.json)、入口照合は[paired_positions.csv](paired_positions.csv)、判定可能時点の全SIGNAL根拠は[signal_context.csv](signal_context.csv)、四半期・方向別は[groups.csv](groups.csv)。"]
    (out/"README.md").write_text("\n".join(lines)+"\n", encoding="utf-8")
    print(json.dumps(dict(status=outcome["status"], checks=audit.CHECKS, failures=audit.FAILURES,
                          decision=outcome["decision"], comparison=comparison), ensure_ascii=False, default=audit.dump))
    return bool(audit.FAILURES)


if __name__ == "__main__":
    raise SystemExit(main())
