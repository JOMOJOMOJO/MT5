#!/usr/bin/env python3
from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def read(path:Path):
    with path.open(encoding="utf-8-sig",newline="") as h:return list(csv.DictReader(h))

def main()->int:
    raw_path=ROOT/"reports/tests/tick_shock/step15c_green/raw/event_response.csv"
    raw={r["test_id"]:r for r in read(raw_path)}
    cases=[r for r in read(ROOT/"tests/tick_shock/spec/test_cases.csv") if r["test_id"].startswith("TS15C-")]
    rows=[]
    for case in cases:
        obs=raw.get(case["test_id"])
        exp=read(ROOT/case["expected_path"])[0]
        expected=f"{exp['field']}={exp['expected_value']}"
        if obs is None: status="FAIL";actual="NO_OBSERVATION";difference="missing production-path row"
        else: status="PASS" if obs.get("observed")=="MATCH" else "FAIL";actual=obs.get("actual","");difference=obs.get("difference","")
        rows.append({"test_id":case["test_id"],"requirement_id":case["requirement_id"],"defect_id":case["defect_id"],
                     "test_layer":case["test_layer"],"status":status,"expected":expected,"actual":actual,
                     "difference":difference,"evidence_path":raw_path.relative_to(ROOT).as_posix()})
    out=ROOT/"reports/tests/tick_shock/step15c_green";out.mkdir(parents=True,exist_ok=True)
    fields=["test_id","requirement_id","defect_id","test_layer","status","expected","actual","difference","evidence_path"]
    with (out/"step15c_green_results.csv").open("w",encoding="utf-8",newline="") as h:w=csv.DictWriter(h,fieldnames=fields);w.writeheader();w.writerows(rows)
    c=Counter(r["status"] for r in rows)
    (out/"step15c_green_report.md").write_text("# Step 15C GREEN evidence\n\n"+"\n".join(f"- {k}: {c[k]}" for k in ("PASS","FAIL","XFAIL","XPASS","SKIP","BLOCKED"))+"\n\nAll observations came from the compiled MQL harness calling `TickShockEventResponse.mqh`.\n",encoding="utf-8")
    print(" ".join(f"{k}={c[k]}" for k in ("PASS","FAIL","XFAIL","XPASS","SKIP","BLOCKED")))
    return 0 if c["FAIL"]==0 else 1

if __name__=="__main__":raise SystemExit(main())
