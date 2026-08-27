#!/usr/bin/env python3
"""Create the predeclared Step 15B registry fixtures and independent expected rows."""

from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

CASES = [
    ("TS15B-DIR-SCHEMA-001","TS15B-REQ-DIR-001","direction_schema","schema_contract","NONE","direction_column=present"),
    ("TS15B-DIR-POS-001","TS15B-REQ-DIR-001","direction","unit","LONG","direction=LONG"),
    ("TS15B-DIR-NEG-001","TS15B-REQ-DIR-001","direction","unit","SHORT","direction=SHORT"),
    ("TS15B-DIR-CONFLICT-001","TS15B-REQ-DIR-001","direction_tie","unit","BOTH","trigger_index=0;direction=LONG"),
    ("TS15B-DIR-PERSIST-001","TS15B-REQ-DIR-001","persistence_direction","production_path_integration","SHORT","direction=SHORT;signal_msc=1250"),
    ("TS15B-DIR-FUTURE-001","TS15B-REQ-DIR-001","direction_causality","production_path_integration","LONG","direction=LONG"),
    ("TS15B-CTRL-COMPLETE-001","TS15B-REQ-CTRL-001","control_outcome","production_path_integration","LONG","complete_120s=1;abs_return_1s=0.001"),
    ("TS15B-CTRL-INCOMPLETE-001","TS15B-REQ-CTRL-001","control_outcome","production_path_integration","LONG","complete_120s=0;status=INCOMPLETE_END_OF_RUN"),
    ("TS15B-MATCH-EXCLUDE-001","TS15B-REQ-MATCH-001","shock_exclusion","unit","NONE","eligible_minus120001=1;eligible_minus120000=0;eligible_plus120000=0;eligible_plus120001=1"),
    ("TS15B-MATCH-CLOSEST-001","TS15B-REQ-MATCH-001","matched_control","unit","NONE","selected_id=C2"),
    ("TS15B-MATCH-DIM-001","TS15B-REQ-MATCH-001","matched_control","unit","NONE","matched=0;reason=UNMATCHED_EXACT_KEY"),
    ("TS15B-MATCH-NORELAX-001","TS15B-REQ-MATCH-001","matched_control","production_path_integration","NONE","matched=0;relaxed=0"),
    ("TS15B-MATCH-UNMATCHED-001","TS15B-REQ-MATCH-001","matched_control","unit","NONE","coverage_rows=1;matched=0"),
    ("TS15B-MATCH-TIE-001","TS15B-REQ-MATCH-001","matched_control","unit","NONE","selected_id=C001"),
    ("TS15B-MATCH-REUSE-001","TS15B-REQ-MATCH-001","matched_control","unit","NONE","matched=2;unique_controls=1;reuse_count=1"),
    ("TS15B-MATCH-DUP-001","TS15B-REQ-MATCH-001","control_identity","unit","NONE","accepted_second=0;validation_invalid=1"),
    ("TS15B-CTRL-SAMEMSC-001","TS15B-REQ-CTRL-001","same_millisecond","production_path_integration","LONG","boundary_mid=1.0003;boundary_count=1"),
    ("TS15B-CTRL-CAP-001","TS15B-REQ-CTRL-001","control_capacity","unit","NONE","capacity_hits=1;validation_invalid=1"),
    ("TS15B-CTRL-DROP-001","TS15B-REQ-CTRL-001","control_integrity","production_path_integration","NONE","drops=1;validation_invalid=1"),
    ("TS15B-FUNNEL-FIRST-001","TS15B-REQ-FUNNEL-001","funnel_reason","unit","NONE","first_fail=ACTIVITY_ELEVATED"),
    ("TS15B-FUNNEL-ALL-001","TS15B-REQ-FUNNEL-001","funnel_reason","unit","NONE","all_fail=ACTIVITY_ELEVATED|LIQUIDITY_NORMAL|COST_FEASIBLE"),
    ("TS15B-FUNNEL-RECON-001","TS15B-REQ-FUNNEL-001","funnel_reconciliation","unit","NONE","input=4;passed=1;excluded=3;reconciles=1"),
    ("TS15B-FUNNEL-ELIG-001","TS15B-REQ-FUNNEL-001","common_eligibility","production_path_integration","BOTH","before=0;after=0"),
    ("TS15B-CF-STATE-001","TS15B-REQ-CF-001","counterfactual_isolation","production_path_integration","BOTH","production_mutations=0"),
    ("TS15B-CF-CAUSAL-001","TS15B-REQ-CF-001","counterfactual_clock","production_path_integration","BOTH","entry_quote_msc=1600;eligible_msc=1600;causal=1"),
    ("TS15B-CF-OVERLAP-001","TS15B-REQ-CF-001","overlap_cooldown","unit","NONE","before=3;after=1"),
    ("TS15B-CF-COUNT-001","TS15B-REQ-CF-001","counterfactual_count","unit","NONE","clusters=2;scenario_cells=1104;potential_trades=2"),
    ("TS15B-IDENTITY-001","TS15B-REQ-REG-001","detector_identity","python_reconciliation","BOTH","identity_mismatches=0"),
    ("TS15B-PROV-001","TS15B-REQ-REG-001","provenance","source_contract","NONE","spec_sha=53DB75EEE4641D98F4917E74B9C26B84D07533CE8EA1A6689AF7F36BAAEA64EA;schema=tickshock-detector-feature-v2"),
]


def write(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer=csv.DictWriter(handle,fieldnames=fields)
        writer.writeheader(); writer.writerows(rows)


def main() -> int:
    registry=ROOT/"tests/tick_shock/spec/test_cases.csv"
    with registry.open(encoding="utf-8-sig",newline="") as handle:
        rows=list(csv.DictReader(handle)); fields=list(rows[0])
    existing={r["test_id"] for r in rows}
    for test_id,req,component,layer,direction,desc in CASES:
        if test_id in existing: continue
        rows.append({"test_id":test_id,"requirement_id":req,"defect_id":"TS15B-EVIDENCE-GAP",
                     "component":component,"test_layer":layer,"direction":direction,
                     "fixture_path":f"tests/tick_shock/fixtures/{test_id}_ticks.csv",
                     "expected_path":f"tests/tick_shock/expected/{test_id}_expected.csv",
                     "current_expected_status":"XFAIL","description":desc})
    write(registry,fields,rows)

    for seq,(test_id,req,component,layer,direction,desc) in enumerate(CASES,1):
        fixture=ROOT/f"tests/tick_shock/fixtures/{test_id}_ticks.csv"
        config=ROOT/f"tests/tick_shock/fixtures/{test_id}_config.csv"
        expected=ROOT/f"tests/tick_shock/expected/{test_id}_expected.csv"
        write(fixture,["sequence","symbol","time_msc","bid","ask","processing_msc","note"],[
            {"sequence":1,"symbol":"EURUSD","time_msc":1000,"bid":"1.0000","ask":"1.0002","processing_msc":1000,"note":f"{test_id} independent fixture start"},
            {"sequence":2,"symbol":"EURUSD","time_msc":1250,"bid":"1.0002","ask":"1.0004","processing_msc":1250,"note":desc},
        ])
        write(config,["key","value","unit","note"],[
            {"key":"detector_spec_sha256","value":"53DB75EEE4641D98F4917E74B9C26B84D07533CE8EA1A6689AF7F36BAAEA64EA","unit":"sha256","note":"frozen Step 15A detector contract"},
            {"key":"execution_mode","value":"REALIZABLE_EA","unit":"enum","note":"causal production-path mode"},
            {"key":"oracle_source","value":"docs/research/tick_shock/15b_control_funnel_test_spec.md","unit":"path","note":"predeclared before production implementation"},
            {"key":"production_function_used_for_expected","value":"false","unit":"bool","note":"mandatory independent oracle"},
        ])
        expectation=[]
        for item in desc.split(";"):
            key,value=item.split("=",1)
            tolerance="0" if value.replace(".","",1).isdigit() else "exact"
            unit="value"
            if key.endswith("_msc"): unit="ms"
            expectation.append({"field":key,"expected_value":value,"tolerance":tolerance,"unit":unit,"note":"independent predeclared oracle"})
        write(expected,["field","expected_value","tolerance","unit","note"],expectation)
    print(f"step15b_cases={len(CASES)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
