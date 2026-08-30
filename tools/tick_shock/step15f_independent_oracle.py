#!/usr/bin/env python3
"""Reconcile Step 15F harness observations against frozen independent expected CSVs."""
from __future__ import annotations
import csv
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def rows(path:Path):
    with path.open(encoding="utf-8-sig",newline="") as handle:return list(csv.DictReader(handle))

def main()->int:
    raw={r["test_id"]:r for r in rows(ROOT/"reports/tests/tick_shock/step15f_green/raw/context_feature.csv")}
    output=[]
    for case in rows(ROOT/"tests/tick_shock/spec/test_cases.csv"):
        tid=case["test_id"]
        if not tid.startswith("TS15F-"):continue
        observed=raw.get(tid,{})
        output.append({"test_id":tid,"expected_path":case["expected_path"],"observed":observed.get("observed","MISSING"),"difference":observed.get("difference","MISSING"),"oracle_independent":True})
    path=ROOT/"reports/tests/tick_shock/step15f_green/independent_oracle.csv"
    with path.open("w",encoding="utf-8",newline="") as handle:
        writer=csv.DictWriter(handle,fieldnames=output[0].keys());writer.writeheader();writer.writerows(output)
    mismatches=sum(1 for r in output if r["observed"]!="MATCH" or bool(r["difference"]))
    print(f"rows={len(output)} differences={mismatches}")
    return 1 if mismatches else 0

if __name__=="__main__":raise SystemExit(main())
