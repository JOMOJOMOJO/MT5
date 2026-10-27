"""Read-only frozen Feb-Mar native comparison audit. Never starts MT5."""
from __future__ import annotations

import csv
import hashlib
import html
import json
import re
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path

HERE = Path(__file__).resolve().parent
BATCH = HERE.parents[1]
REPO = BATCH.parents[4]
D = Decimal
FMT = "%Y.%m.%d %H:%M:%S"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def readcsv(path):
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter=";"))


def mapping(path, separator):
    return dict(x.split(separator, 1) for x in path.read_text(encoding="utf-8-sig").splitlines() if separator in x)


def report(path):
    text = path.read_text(encoding="utf-16")
    rows = [[html.unescape(re.sub(r"<[^>]+>", "", cell)).strip() for cell in re.findall(r"<t[dh]\b[^>]*>(.*?)</t[dh]>", row, re.I | re.S)] for row in re.findall(r"<tr\b[^>]*>(.*?)</tr>", text, re.I | re.S)]
    pairs = {cell[:-1]: row[i + 1] for row in rows for i, cell in enumerate(row[:-1]) if cell.endswith(":")}
    return rows, pairs


def number(s):
    return D(s.replace(" ", "").replace(",", ""))


def main():
    checks, results, sources, exposure_rows = [], {}, {}, []
    status = json.loads((BATCH / "status.json").read_text(encoding="utf-8-sig"))
    jan = json.loads((REPO / "reports/backtest/runs/wave33_h1er_2025jan/20261027_005658_UTC_0796b021/status.json").read_text(encoding="utf-8-sig"))

    def check(name, value, detail=None):
        checks.append({"name": name, "pass": bool(value), "detail": detail})

    for arm in status["arms"]:
        name, rt, tag = arm["id"], Path(arm["runtime"]), arm["tag"]
        src = BATCH / name / "source"
        f = lambda suffix: src / f"{tag}_{suffix}.csv"
        logpath = rt / "Tester" / f"Agent-127.0.0.1-{arm['port']}" / "logs/20261027.log"
        journal = logpath.read_text(encoding="utf-16")
        lines = journal.splitlines()
        excerpts = [line for line in lines if any(s in line for s in ["history synchronized from", "history ticks synchronized from", "generating based on real ticks", "real ticks begin from", "final balance", "bars generated", "thread finished", "TEST_END", "end of test", "real ticks absent", "real ticks discarded", "tick prices mismatch", "last prices absent", "failed market", "2025.03.20 01:01:00", "2025.03.20 01:19:36"])]
        (HERE / f"{name}_journal_integrity_excerpts.txt").write_text("\n".join(excerpts) + "\n", encoding="utf-8")
        warnings = [line for line in lines if re.search(r"absent|discarded|mismatch|no real ticks|not enough|failed|invalid|error", line, re.I) and "W33 " not in line and "H1_EFFICIENCY_POLICY" not in line]
        completion = next((i for i, line in enumerate(lines) if "thread finished" in line), None)
        forced = next((i for i, line in enumerate(lines) if "tester forced to close" in line), None)
        check(f"{name}_native_finished", "Test passed in" in journal and completion is not None)
        check(f"{name}_shutdown_only_after_completion", forced is None or completion is not None and forced > completion)
        tick_warnings = [line.split("\t")[-1] for line in warnings if "\tTicks\t" in line]
        trade_rejections = [line.split("\t")[-1] for line in warnings if "\tTrades\t" in line and "Market closed" in line]
        unknown_errors = [line for line in warnings if "\tTicks\t" not in line and not ("\tTrades\t" in line and "Market closed" in line)]
        check(f"{name}_no_unclassified_engine_error_found", not unknown_errors, unknown_errors)
        ticks = re.search(r"XAUUSD\+,M1: (\d+) ticks, (\d+) bars generated", journal)
        rows, metrics = report(src / f"{tag}.htm")
        check(f"{name}_native_requested_period", metrics["期間"] == "M1 (2025.02.01 - 2025.04.01)")
        check(f"{name}_native_rounded_quality_label_and_requested_mode", metrics["ヒストリー品質"] == "100% リアルティック" and "generating based on real ticks" in journal)
        tests = list(csv.reader(f("h1efficiency_policy_tests").open(encoding="utf-8-sig"), delimiter=";"))
        check(f"{name}_45_policy_tests", len(tests) == 46 and tests[-1] == ["SUMMARY", "PASS", "45", "0"] and all(r[1] == "PASS" for r in tests))
        bars = {}
        for kind in ["lower_bars", "upper_bars"]:
            rr = readcsv(f(kind))
            check(f"{name}_{kind}_chronological", all(x["bar_time"] < y["bar_time"] for x, y in zip(rr, rr[1:])))
            check(f"{name}_{kind}_closed_before_known", all(x["closed_at"] <= x["known_at"] for x in rr))
            bars[kind] = {"count": len(rr), "first": rr[0], "last": rr[-1], "sha256": sha(f(kind))}
        check(f"{name}_reaches_mar31_close", bars["lower_bars"]["last"]["bar_time"] == "2025.03.31 23:56:00")
        preset = mapping(BATCH / name / "inputs.set", "=")
        actual = dict(cell.split("=", 1) for row in rows for cell in row if cell.startswith("Inp") and "=" in cell)
        baseline = next(x for x in jan["arms"] if x["id"] == name)["inputs"]
        check(f"{name}_54_actual_native_inputs_match_frozen", len(actual) == len(preset) == 54 and actual == preset)
        check(f"{name}_54_inputs_match_january_except_tag", preset.keys() == baseline.keys() and all(k == "InpRunTag" or v == baseline[k] for k, v in preset.items()))
        config = mapping(f("config"), ";")
        runtime_missing = [relative for relative in arm["artifact_sha256"] if not (rt / relative).is_file()]
        binary_changes = [relative for relative, value in arm["artifact_sha256"].items() if (rt / relative).is_file() and sha(rt / relative) != value]
        check(f"{name}_available_runtime_artifact_hashes_unchanged", not binary_changes, {"changed": binary_changes, "missing_not_rechecked": runtime_missing})
        check(f"{name}_private_ini_hash_unchanged", sha(Path(arm["ini"])) == arm["ini_sha256"])

        h1 = readcsv(f("h1_efficiency"))
        bad_formula, bad_time, bad_gate = [], [], []
        for row in h1:
            if row["valid"] != "true":
                bad_gate.extend([row["setup_id"]] if row["outcome"] != "ALLOW_UNAVAILABLE" else [])
                continue
            closes = [D(x) for x in row["closes"].split("|")]
            times = [datetime.strptime(x, FMT) for x in row["bar_open_times"].split("|")]
            decision = datetime.strptime(row["decision_at"], FMT)
            path = sum((abs(y - x) for x, y in zip(closes, closes[1:])), D(0))
            er = abs(closes[-1] - closes[0]) / path
            if len(closes) != 13 or abs(er - D(row["er"])) > D("1e-12") or abs(1 - er - D(row["roundtrip"])) > D("1e-12"):
                bad_formula.append(row["setup_id"])
            if len(times) != 13 or any(x >= y for x, y in zip(times, times[1:])) or any(t + timedelta(hours=1) > decision for t in times):
                bad_time.append(row["setup_id"])
            reject = name == "on" and er <= D(".25") + D("1e-12")
            expected = ("SKIP" if row["precedence"] == "ELIGIBLE" else "WOULD_SKIP_PRECEDENCE") if reject else "ALLOW"
            if row["outcome"] != expected:
                bad_gate.append(row["setup_id"])
        check(f"{name}_all_native_h1_decimal_formula", not bad_formula, bad_formula)
        check(f"{name}_all_native_h1_closed_before_decision", not bad_time, bad_time)
        check(f"{name}_all_h1_gate_outcomes", not bad_gate, bad_gate)

        deals = readcsv(f("raw_deals"))
        components = {key: sum((D(row[key]) for row in deals), D(0)) for key in ["profit", "commission", "swap", "fee"]}
        net = sum(components.values(), D(0))
        positions = defaultdict(lambda: {"in": D(0), "out": D(0), "net": D(0), "setup_id": ""})
        for row in deals:
            position = positions[row["position_id"]]
            position["in" if row["entry"] == "DEAL_ENTRY_IN" else "out"] += D(row["volume"])
            position["net"] += sum((D(row[key]) for key in components), D(0))
            position["setup_id"] = row["setup_id"]
        check(f"{name}_all_positions_fully_closed", all(x["in"] == x["out"] for x in positions.values()))
        check(f"{name}_raw_deals_match_native_count", len(deals) == int(metrics["約定数"]))
        exit_count = sum(row["entry"] == "DEAL_ENTRY_OUT" for row in deals)
        check(f"{name}_native_trades_equal_exit_legs", exit_count == int(metrics["取引数"]))
        check(f"{name}_raw_net_matches_report", net == number(metrics["総損益"]) == number(metrics["総利益"]) + number(metrics["総損失"]))
        final_balance = D(re.search(r"final balance ([0-9.]+) USD", journal)[1])
        check(f"{name}_raw_net_matches_final_balance", net == final_balance - D(5000))
        pf = number(metrics["総利益"]) / abs(number(metrics["総損失"]))
        check(f"{name}_native_pf_rounding_matches", abs(pf - number(metrics["プロフィットファクター"])) <= D(".005"))
        quality_exposure = []
        for pid, position in positions.items():
            rr = [row for row in deals if row["position_id"] == pid]
            start = datetime.fromtimestamp(min(int(row["time_msc"]) for row in rr) / 1000, timezone.utc).replace(tzinfo=None)
            stop = datetime.fromtimestamp(max(int(row["time_msc"]) for row in rr) / 1000, timezone.utc).replace(tzinfo=None)
            affected = [day for day in ["2025-02-27", "2025-03-27"] if start.date().isoformat() <= day <= stop.date().isoformat()]
            if affected:
                quality_exposure.append({"arm": name, "position_id": pid, "setup_id": position["setup_id"], "entry_source_clock": start.isoformat(sep=" "), "exit_source_clock": stop.isoformat(sep=" "), "warning_dates": "|".join(affected), "net_cash": str(position["net"])})
        exposure_rows.extend(quality_exposure)
        exposed_net = sum((D(row["net_cash"]) for row in quality_exposure), D(0))

        events = readcsv(f("events"))
        end = [row for row in events if row["event_type"] == "TEST_END"]
        forced_deals = [row for row in deals if re.search(r"end of test|test.?end|stop.?test", row["comment"], re.I)]
        traded_setups = {row["setup_id"] for row in deals}
        check(f"{name}_test_end_candidate_unfilled", len(end) == 1 and end[0]["entry_status"] == "CANDIDATE" and end[0]["setup_id"] not in traded_setups)
        check(f"{name}_no_test_end_forced_deals", not forced_deals, forced_deals)
        check(f"{name}_test_end_reaches_final_market_tick", end[0]["event_at"] == "2025.03.31 23:57:54")
        check(f"{name}_last_actual_deal_before_test_end", max(int(row["time_msc"]) for row in deals) < int(datetime(2025, 3, 31, 23, 57, 54, tzinfo=timezone.utc).timestamp() * 1000))
        results[name] = {"native_report": metrics, "actual_ticks": int(ticks[1]), "generated_m1_bars": int(ticks[2]), "bars": bars, "unique_entry_positions": len(positions), "native_exit_legs": exit_count, "raw_deals": len(deals), "cash_components": {k: str(v) for k, v in components.items()}, "net_cash": str(net), "final_balance": str(final_balance), "native_pf_exact": str(pf), "max_equity_dd": metrics["証拠金最大ドローダウン"], "max_balance_dd": metrics["残高最大ドローダウン"], "native_h1_rows": len(h1), "native_h1_valid": sum(row["valid"] == "true" for row in h1), "test_end": [{key: row.get(key) for key in ["event_at", "event_type", "reason", "setup_id", "state", "entry_status", "signal_at", "order_sent_at", "fill_at", "entry_price"]} for row in end], "forced_end_deals": forced_deals, "last_actual_deal": deals[-1], "data_quality": {"pure_real_tick_gate": "NOT_PASSED", "native_rounded_report": metrics["ヒストリー品質"], "absent_minutes_generated": 6, "discarded_minutes_generated": 14, "total_generated_fallback_minutes": 20, "total_minute_bars": 56327, "fallback_percentage": 20 / 56327 * 100, "last_prices_absent_bid_used_minute_bars": 2741, "tick_warnings": tick_warnings}, "trade_market_closed_rejection_count": len(trade_rejections), "trade_market_closed_rejections": trade_rejections, "runtime_artifacts_missing_not_rechecked": runtime_missing, "journal_sha256": sha(logpath), "report_sha256": sha(src / f"{tag}.htm")}
        results[name]["conservative_warning_day_exposure_sensitivity"] = {"exposed_positions": len(quality_exposure), "exposed_net_cash": str(exposed_net), "remaining_positions": len(positions) - len(quality_exposure), "remaining_net_cash": str(net - exposed_net), "caveat": "Flag entire warning dates, not exact bad minutes; arithmetic removal only, no equity/lot/candidate path rerun and no data-correction claim."}
        sources[name] = {"preset": preset, "config": config, "h1": {(row["decision_at"], row["setup_id"]): row for row in h1}}

    for kind in ["lower_bars", "upper_bars"]:
        check(f"same_actual_{kind}_byte_hash", results["off"]["bars"][kind]["sha256"] == results["on"]["bars"][kind]["sha256"])
    check("same_actual_tick_and_generated_bar_counts", (results["off"]["actual_ticks"], results["off"]["generated_m1_bars"]) == (results["on"]["actual_ticks"], results["on"]["generated_m1_bars"]))
    check("same_tick_fallback_warning_signatures", results["off"]["data_quality"]["tick_warnings"] == results["on"]["data_quality"]["tick_warnings"])
    input_diff = {k: [sources["off"]["preset"].get(k), sources["on"]["preset"].get(k)] for k in sources["off"]["preset"] if sources["off"]["preset"].get(k) != sources["on"]["preset"].get(k)}
    config_diff = {k: [sources["off"]["config"].get(k), sources["on"]["config"].get(k)] for k in sources["off"]["config"] if sources["off"]["config"].get(k) != sources["on"]["config"].get(k)}
    check("single_behavioral_flag_plus_run_tag", set(input_diff) == {"InpSkipH1LowEfficiency", "InpRunTag"} and input_diff["InpSkipH1LowEfficiency"] == ["false", "true"])
    check("only_expected_native_config_differences", set(config_diff) == {"skip_h1_low_efficiency", "resolved_run_tag", "input_hash"})
    common = sources["off"]["h1"].keys() & sources["on"]["h1"].keys()
    h1fields = ["valid", "reason", "close_count", "first_open", "last_open", "last_close", "span_seconds", "gap_count", "net_distance", "path_distance", "er", "roundtrip", "threshold", "bar_open_times", "closes"]
    unequal_h1 = [key for key in common if any(sources["off"]["h1"][key][field] != sources["on"]["h1"][key][field] for field in h1fields)]
    check("same_native_h1_windows_for_matching_decisions", not unequal_h1, {"matching_decisions": len(common), "unequal": unequal_h1, "off_only": len(sources["off"]["h1"].keys() - common), "on_only": len(sources["on"]["h1"].keys() - common)})
    check("initial_cache_symbol_fingerprints_equal", status["arms"][0]["cache_sha256"] == status["arms"][1]["cache_sha256"] and status["arms"][0]["symbols_sha256"] == status["arms"][1]["symbols_sha256"])
    hash_groups = {"protected125": json.loads((REPO / "reports/qa/w33_h1eff_20261027/protected_before.json").read_text(encoding="utf-8-sig")), "deployment34": json.loads((BATCH / "deployment.json").read_text(encoding="utf-8-sig"))["files_sha256"]}
    for group, before in hash_groups.items():
        changed = [path for path, value in before.items() if not (REPO / path).is_file() or sha(REPO / path) != value]
        check(f"{group}_current_hashes_unchanged", not changed, {"files": len(before), "changed": changed})
    job_changed = [name for name, value in status["job_sha256"].items() if sha(BATCH / "job" / name) != value]
    check("frozen_job_hashes_match_prepared_state", not job_changed, job_changed)
    result = {"status": "PASS_WITH_DATA_LIMITATIONS" if all(x["pass"] for x in checks) else "FAIL", "passed": sum(x["pass"] for x in checks), "check_count": len(checks), "pure_real_tick_gate": "NOT_PASSED", "checks": checks, "arms": results, "input_diff": input_diff, "config_diff": config_diff, "h1_matching_decisions": len(common), "limitations": ["Native rounded report says100% real ticks, but journals explicitly show20 of56327 minute bars used generated ticks (6absent,14discarded), and2741last-price-absent bars usedBid. Both arms have the same warnings. This is a mixed real/generated tick comparison, not a pure real-tick validation.", "TEST_END censorship applies to one unfilled candidate, not an open position. All actual positions close before test end, so terminal-forced-close exclusion has zero effect on this report's realized P/L.", "Runtime terminal/tester executable files are absent from TEMP after the run, so post-run binary hashes cannot be rechecked. Prelaunch frozen hashes and verification document their launch identity; remaining artifacts are checked normally.", "M1/M5 bars and matching H1 windows are identical across arms; complete executable tick streams were not independently exported.", "OFF has16MarketClosed partial-close rejections Mar20 01:00:29–55; retry succeeds01:01:00, remaining halfSLcloses01:19:36. These are real tester execution outcomes, not initialization/test-completion failures.", "Historical broker specifications and source-time UTC offset are not independently reconstructed.", "Continuous Feb-Mar run; retain entry-month attribution and account/equity path rather than pretending each month reset to5000.", "No profitability/promotion implied by engineering PASS; both runs remain negative and native results worsen with ON."]}
    (HERE / "integrity.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    with (HERE / "warning_day_position_exposure.csv").open("w", encoding="utf-8-sig", newline="") as out:
        writer = csv.DictWriter(out, fieldnames=["arm", "position_id", "setup_id", "entry_source_clock", "exit_source_clock", "warning_dates", "net_cash"])
        writer.writeheader()
        writer.writerows(exposure_rows)
    table = []
    for metric, getter in [("Unique actual entry positions", lambda x: x["unique_entry_positions"]), ("Native trade count (exit legs)", lambda x: x["native_exit_legs"]), ("Raw deals", lambda x: x["raw_deals"]), ("Net USD including all costs", lambda x: x["net_cash"]), ("Native PF", lambda x: x["native_report"]["プロフィットファクター"]), ("Native maximum equity DD", lambda x: x["max_equity_dd"]), ("Native maximum balance DD", lambda x: x["max_balance_dd"]), ("Final balance USD", lambda x: x["final_balance"]), ("Native H1 observations", lambda x: x["native_h1_rows"])]:
        table.append(f"| {metric} | {getter(results['off'])} | {getter(results['on'])} |")
    note = f"""# Feb–Mar2025 H1 ER native integrity audit

**{result['status']}: {result['passed']}/{result['check_count']} checks.** Read-only audit; no MT5 launch, no EA edits, no threshold changes. Frozen comparison: XAUUSD+, M5×M1, native period2025.02.01–2025.04.01.

| Item | OFF | ON |
|---|---:|---:|
""" + "\n".join(table) + f"""

Both arms show the rounded native label100% real ticks, 8,306,849 ticks and56,327 generated M1 bars, finish through the final market tick2025.03.31 23:57:54, and state Test passed/thread finished. However, the journal explicitly reports6minutes with absent real ticks and14minutes with discarded real ticks, all20using generated ticks; this is approximately0.0355% of56,327minute bars. February27 has5discarded minute bars/169mismatched tick prices; March27 has6absent+9discarded minute bars/1,297mismatched tick prices. The day-summary timestamp23:59does not identify which minutes were affected. Another2,741minute bars have absent last prices and useBid. Both arms have exactly the same data warning signatures. **The pure real-tick gate is NOT PASSED.** Comparable mixed-data results remain descriptive, with no assumption that generated execution exactly matches unseen real ticks. Native journal excerpts and SHA256 identities are saved beside this report.

Actual closed M1 and M5 CSV files are byte-identical between arms, including OHLC and known_at. All{len(common)} matching decision H1 windows agree on all13 prices/times and ER metadata. Every logged valid H1 ER was independently recalculated using Decimal and checked for closed-bar availability. Missing data are recorded and allowed, not silently converted toER0. Both arms execute45 pure policy checks with no failures.

All54 actual native inputs match the frozen presets and January baseline except run tag. The only behavioral OFF/ON difference is InpSkipH1LowEfficiency. All125 protected prior sources/presets and34 deployment artifact hashes remain unchanged. Remaining runtime artifacts/presets/private INI hashes and frozen job hashes match their prepared identities. TEMP runtime terminal64.exe/metatester64.exe files are absent after execution, so their current hashes cannot be rechecked; prelaunch hashes/verification retain their launch identities. No earlier verification script was rerun and no QA/runtime status was reset.

Cash reconciliation includes profit, commissions, swaps and fees across all in/out deals. Net equals both native report and final balance minus5000 exactly. Partial exits are grouped once per position for completeness; native trade count includes multiple exit legs and must not be used as the number of independent entries.

OFF also records16partial-close rejections for Market closed on March20 01:00:29–55 for LONG setup196. The retry succeeds at01:01:00 for0.10lot; the remaining0.10lot later closes atSL01:19:36. No rejection appears in ON because this trade is filtered. These are execution effects already included in realized P/L; they are not an initializer failure or an unresolved position.

As a conservative descriptive sensitivity, [warning_day_position_exposure.csv](warning_day_position_exposure.csv) flags any position whose holding interval overlaps the entire February27/March27 dates. OFF has2positions totaling−84USD; ON has1totaling−36USD. Arithmetic removal leavesOFF−205.67USD versusON−364.64USD, so ON remains worse in this limited check. Exact bad minutes are unknown; this does not reconstruct a corrected tick stream, rerun lot/equity/candidate paths, or justify a strategy day filter.

## TEST_END and censoring

Both TEST_END rows refer to the same LONG candidate W33_XAUUSD+_5_1_LONG_1743455700_243 in LOWER_COUNTERTREND, entry_status=CANDIDATE, no order/fill. That candidate has no raw deals. All actual position in/out volumes balance; no positions remain open, and no raw deal or journal close is labelled end-of-test. Last actual exits are regular SL exits several hours before23:57:54. Consequently, removing terminal-forced closures changes realized profit/loss by0 in both arms. The unfinished setup is right-censored for candidate-conversion studies, not an extra losing/winning trade. A weekend closure in the raw deals is the strategy's normal weekend rule, not tester censorship.

February/March are a continuous account path. Monthly attribution should use original entry month and disclose crossing positions rather than resetting capital at each month boundary. Broker/source clock mapping and historical symbol specification changes remain assumptions. These results do not establish causality or profitability; both arms lose money and the ON native PF/DD are worse.

Machine evidence: [integrity.json](integrity.json). Reproduce read-only: python audit_native_integrity.py.
"""
    (HERE / "README.md").write_text(note, encoding="utf-8")
    print(json.dumps({"status": result["status"], "passed": result["passed"], "count": result["check_count"], "failed": [x for x in checks if not x["pass"]]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
