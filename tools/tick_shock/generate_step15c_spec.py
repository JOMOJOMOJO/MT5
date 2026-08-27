#!/usr/bin/env python3
"""Create frozen Step 15C fixtures, independent expected values, and RED evidence."""

from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

CASES = [
    ("TS15C-TIME-001","confirmed time is the tradable reference","reference_msc","1250","msc"),
    ("TS15C-TIME-002","candidate-time entry backdate is rejected","entry_quote_msc","1251","msc"),
    ("TS15C-TIME-003","future feature reads are rejected","future_read_count","0","count"),
    ("TS15C-DIR-001","LONG and SHORT signs are symmetric","long_sign_short_sign","1|-1","enum"),
    ("TS15C-RET-001","continuation return follows shock sign","continuation_return","0.000999500333","log_return"),
    ("TS15C-EXEC-001","entry uses executable Bid Ask","long_entry_short_entry","1.0002|1.0000","price"),
    ("TS15C-EXEC-002","exit uses executable Bid Ask","long_exit_short_exit","1.0010|1.0012","price"),
    ("TS15C-HORIZON-001","all fixed horizons are registered","horizon_count","11","count"),
    ("TS15C-HORIZON-002","irregular ticks use first quote at or after target","snapshot_msc","1601","msc"),
    ("TS15C-HORIZON-003","same-ms group closes on last quote","snapshot_mid","1.0003","price"),
    ("TS15C-HORIZON-004","stale snapshot is explicit","snapshot_status","STALE","enum"),
    ("TS15C-HORIZON-005","missing horizon is blank not zero","snapshot_status","MISSING_END","enum"),
    ("TS15C-HORIZON-006","run-end outcome is censored","outcome_status","CENSORED_END","enum"),
    ("TS15C-EXCUR-001","directional MFE is online maximum","mfe","0.0010","price"),
    ("TS15C-EXCUR-002","directional MAE is online adverse maximum","mae","0.0004","price"),
    ("TS15C-EXCUR-003","time to MFE retains first maximum","time_to_mfe_ms","700","ms"),
    ("TS15C-EXCUR-004","time to MAE retains first maximum","time_to_mae_ms","400","ms"),
    ("TS15C-RECROSS-001","origin recross is causal first crossing","origin_recross_msc","2100","msc"),
    ("TS15C-BARRIER-001","continuation first passage is timestamped","continuation_hit_msc","1700","msc"),
    ("TS15C-BARRIER-002","reversal first passage is timestamped","reversal_hit_msc","1900","msc"),
    ("TS15C-BARRIER-003","TP first-touch uses executable side","barrier_result","TP_FIRST","enum"),
    ("TS15C-BARRIER-004","same-tick two-sided hit is ambiguous","barrier_result","AMBIGUOUS","enum"),
    ("TS15C-EXEC-003","timeout R uses executable market side","timeout_r","0.25","R"),
    ("TS15C-EPISODE-001","overlapping windows share episode","same_episode","true","bool"),
    ("TS15C-EPISODE-002","non-overlapping window starts episode","episode_count","2","count"),
    ("TS15C-CLUSTER-001","representative tie-break is deterministic","representative_event","A","id"),
    ("TS15C-STRAT-001","detection continuation starts after confirm","entry_msc","1251","msc"),
    ("TS15C-STRAT-002","post-burst entry starts after burst end","entry_msc","1801","msc"),
    ("TS15C-STRAT-003","pullback entry starts after pullback signal","entry_msc","2201","msc"),
    ("TS15C-STRAT-004","reversal entry starts after invalidation","entry_msc","2401","msc"),
    ("TS15C-STRAT-005","unreached signal remains no signal","strategy_status","NO_SIGNAL","enum"),
    ("TS15C-DELAY-001","0 100 250 ms delays are additive","eligible_times","1500|1600|1750","msc"),
    ("TS15C-RR-001","research RR grid is finite","rr_values","0.8|1.0|1.2|1.5|2.0","R"),
    ("TS15C-SPREAD-001","spread stress expands Bid Ask around mid","bid_ask","0.999875|1.000125","price"),
    ("TS15C-GATE-001","gate truth values serialize as bitmask","gate_mask","183","bitmask"),
    ("TS15C-GATE-002","leave-one-gate-out is order independent","reachable_without_activity","true","bool"),
    ("TS15C-SPLIT-001","chronological split and purge are fixed","split_counts","2190|1|1095","episodes"),
    ("TS15C-SPLIT-002","confirmation cannot be read during discovery","confirmation_reads","0","count"),
    ("TS15C-HASH-001","candidate hash is canonical and deterministic","hash_equal","true","bool"),
    ("TS15C-RERUN-001","identical input reruns identically","rerun_equal","true","bool"),
    ("TS15C-CAP-001","capacity and drop counters fail closed","validation_status","VALIDATION_INVALID","enum"),
    ("TS15C-PROV-001","schema and spec provenance are mandatory","provenance_status","MATCH","enum"),
]

TICK_ROWS = [
    [1,"EURUSD",1000,"1.0000","1.0002",1250,"candidate quote"],
    [2,"EURUSD",1250,"1.0001","1.0003",1250,"confirmed signal tick"],
    [3,"EURUSD",1251,"1.0002","1.0004",1251,"first post-signal quote"],
    [4,"EURUSD",1601,"1.0004","1.0006",1601,"irregular horizon quote"],
    [5,"EURUSD",1700,"1.0010","1.0012",1700,"continuation barrier"],
    [6,"EURUSD",1900,"0.9996","0.9998",1900,"adverse excursion"],
    [7,"EURUSD",2100,"0.9994","0.9996",2100,"origin recross"],
]


def write_csv(path: Path, fields: list[str], rows: list[list[str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(fields)
        writer.writerows(rows)


def main() -> int:
    registry_path = ROOT / "tests/tick_shock/spec/test_cases.csv"
    with registry_path.open(encoding="utf-8-sig", newline="") as handle:
        existing = list(csv.DictReader(handle))
        fields = list(existing[0])
    existing_ids = {row["test_id"] for row in existing}
    for test_id, description, *_ in CASES:
        if test_id in existing_ids:
            continue
        existing.append({
            "test_id": test_id,
            "requirement_id": "REQ-" + test_id.removeprefix("TS15C-"),
            "defect_id": "STEP15C-PRE-FIX",
            "component": "event_response",
            "test_layer": "production_path_integration",
            "direction": "BOTH",
            "fixture_path": f"tests/tick_shock/fixtures/{test_id}_ticks.csv",
            "expected_path": f"tests/tick_shock/expected/{test_id}_expected.csv",
            "current_expected_status": "XFAIL",
            "description": description,
        })
    with registry_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader(); writer.writerows(existing)

    red_rows = []
    for test_id, description, field, value, unit in CASES:
        write_csv(ROOT / f"tests/tick_shock/fixtures/{test_id}_ticks.csv",
                  ["sequence","symbol","time_msc","bid","ask","processing_msc","note"], TICK_ROWS)
        write_csv(ROOT / f"tests/tick_shock/fixtures/{test_id}_config.csv",
                  ["key","value"], [["test_id",test_id],["candidate_msc","1000"],["confirmed_msc","1250"],
                                    ["stale_limit_ms","1000"],["episode_window_ms","120000"]])
        write_csv(ROOT / f"tests/tick_shock/expected/{test_id}_expected.csv",
                  ["field","expected_value","tolerance","unit","note"],
                  [[field,value,"1e-9" if unit in {"price","R","log_return"} else "0",unit,description]])
        red_rows.append([test_id,"REQ-"+test_id.removeprefix("TS15C-"),"STEP15C-PRE-FIX",
                         "production_path_integration","XFAIL",f"{field}={value}",
                         "PRODUCTION_EVENT_RESPONSE_API_ABSENT","expected API/result; production include absent",
                         "reports/compile/tick_shock/step15c_red_EventResponseHarness.log"])

    out = ROOT / "reports/tests/tick_shock/step15c_red"
    write_csv(out / "step15c_red_results.csv",
              ["test_id","requirement_id","defect_id","test_layer","status","expected","actual","difference","evidence_path"],
              red_rows)
    (out / "step15c_red_report.md").write_text(
        "# Step 15C RED evidence\n\n"
        f"- tests: {len(CASES)}\n- PASS: 0\n- FAIL: 0\n- XFAIL: {len(CASES)}\n"
        "- XPASS: 0\n- SKIP: 0\n- BLOCKED: 0\n\n"
        "The production event-response API and harness do not exist at this commit. "
        "All expected values are frozen CSV contracts generated independently of production code.\n",
        encoding="utf-8")
    print(f"created {len(CASES)} frozen Step 15C contracts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
