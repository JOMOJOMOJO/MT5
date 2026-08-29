#!/usr/bin/env python3
"""Reconcile frozen Step 15E expected values with production observations."""
from __future__ import annotations
import argparse,csv
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
FIELDS=("test_id","requirement_id","defect_id","test_layer","status","expected","actual","difference","evidence_path")
def read(path):
    with Path(path).open(encoding='utf-8-sig',newline='') as h:return list(csv.DictReader(h))
def expected(tid):return ';'.join(f"{r['field']}={r['expected_value']}" for r in read(ROOT/f'tests/tick_shock/expected/{tid}_expected.csv'))
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--phase',choices=('red','green'),required=True);ap.add_argument('--raw',type=Path);ap.add_argument('--compile-log',type=Path);a=ap.parse_args()
    cases=[r for r in read(ROOT/'tests/tick_shock/spec/test_cases.csv') if r['test_id'].startswith('TS15E-')];raw={r['test_id']:r for r in read(a.raw)} if a.raw and a.raw.exists() else {}
    out=ROOT/f'reports/tests/tick_shock/step15e_{a.phase}';out.mkdir(parents=True,exist_ok=True);rows=[]
    for c in cases:
        tid=c['test_id'];exp=expected(tid)
        if a.phase=='red':status='XFAIL';actual='PRODUCTION_MEDIUM_HORIZON_API_ABSENT';difference=f'expected {exp}; production module absent';evidence='reports/tests/tick_shock/step15e_red/step15e_red_results.csv'
        else:
            obs=raw.get(tid)
            if not obs:status='FAIL';actual='NO_HARNESS_OBSERVATION';difference='missing production-path row'
            else:status='PASS' if obs.get('observed')=='MATCH' else 'FAIL';actual=obs.get('actual','');difference=obs.get('difference','')
            evidence=str(a.raw).replace('\\','/')
        rows.append(dict(test_id=tid,requirement_id=c['requirement_id'],defect_id=c['defect_id'],test_layer=c['test_layer'],status=status,expected=exp,actual=actual,difference=difference,evidence_path=evidence))
    result=out/f'step15e_{a.phase}_results.csv'
    with result.open('w',encoding='utf-8',newline='') as h:w=csv.DictWriter(h,fieldnames=FIELDS);w.writeheader();w.writerows(rows)
    counts=Counter(r['status'] for r in rows);report=out/f'step15e_{a.phase}_report.md';report.write_text(f'# Step 15E {a.phase.upper()} contracts\n\n'+'\n'.join(f'- {s}: {counts[s]}' for s in ('PASS','FAIL','XFAIL','XPASS','SKIP','BLOCKED'))+'\n\nThe MQL harness calls the same production module used by the research EA. Frozen expected files are independent.\n',encoding='utf-8')
    print(' '.join(f'{s}={counts[s]}' for s in ('PASS','FAIL','XFAIL','XPASS','SKIP','BLOCKED')))
    return 0 if a.phase=='red' or counts['FAIL']+counts['XFAIL']+counts['XPASS']+counts['BLOCKED']==0 else 1
if __name__=='__main__':raise SystemExit(main())
