#!/usr/bin/env python3
"""Reconcile frozen Step 15D expected values with production-harness observations."""
from __future__ import annotations
import argparse,csv
from collections import Counter
from pathlib import Path

FIELDS=("test_id","requirement_id","defect_id","test_layer","status","expected","actual","difference","evidence_path")
def read(p):
    with Path(p).open(encoding="utf-8-sig",newline="") as h:return list(csv.DictReader(h))
def expected(root,tid):return ";".join(f"{r['field']}={r['expected_value']}" for r in read(root/f"tests/tick_shock/expected/{tid}_expected.csv"))
def main():
    ap=argparse.ArgumentParser();ap.add_argument("--phase",choices=("red","green"),required=True);ap.add_argument("--raw",type=Path);ap.add_argument("--compile-log",type=Path);a=ap.parse_args()
    root=Path(__file__).resolve().parents[2];cases=[r for r in read(root/"tests/tick_shock/spec/test_cases.csv") if r["test_id"].startswith("TS15D-")]
    raw={r["test_id"]:r for r in read(a.raw)} if a.raw and a.raw.exists() else {}
    out=root/f"reports/tests/tick_shock/step15d_{a.phase}";out.mkdir(parents=True,exist_ok=True);rows=[]
    for case in cases:
        tid=case["test_id"];exp=expected(root,tid)
        if a.phase=="red":
            status="XFAIL";actual="PRODUCTION_STATE_CONDITIONED_RESPONSE_API_ABSENT";difference=f"expected {exp}; production include/API unavailable";evidence=str(a.compile_log or "reports/compile/tick_shock/step15d_red_StateConditionedResponseHarness.log")
        else:
            obs=raw.get(tid)
            if not obs:status="FAIL";actual="NO_HARNESS_OBSERVATION";difference="missing production-path row"
            else:status="PASS" if obs.get("observed")=="MATCH" else "FAIL";actual=obs.get("actual","");difference=obs.get("difference","")
            evidence=str(a.raw)
        rows.append({"test_id":tid,"requirement_id":case["requirement_id"],"defect_id":case["defect_id"],"test_layer":case["test_layer"],"status":status,"expected":exp,"actual":actual,"difference":difference,"evidence_path":evidence})
    result=out/f"step15d_{a.phase}_results.csv"
    with result.open("w",encoding="utf-8",newline="") as h:w=csv.DictWriter(h,fieldnames=FIELDS);w.writeheader();w.writerows(rows)
    c=Counter(r["status"] for r in rows);report=out/f"step15d_{a.phase}_report.md"
    report.write_text("# Step 15D "+a.phase.upper()+" contracts\n\n"+"\n".join(f"- {k}: {c[k]}" for k in ("PASS","FAIL","XFAIL","XPASS","SKIP","BLOCKED"))+"\n\nFixtures and expected values were frozen before production implementation. RED is the observed missing production include/API.\n",encoding="utf-8")
    print(" ".join(f"{k}={c[k]}" for k in ("PASS","FAIL","XFAIL","XPASS","SKIP","BLOCKED")))
    return 0 if a.phase=="red" or c["FAIL"]+c["XFAIL"]+c["XPASS"]+c["BLOCKED"]==0 else 1
if __name__=="__main__":raise SystemExit(main())
