#!/usr/bin/env python3
"""Reconcile Step 15F frozen expected values with production observations."""
from __future__ import annotations
import argparse,csv
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];FIELDS=('test_id','requirement_id','defect_id','test_layer','status','expected','actual','difference','evidence_path')
def read(path):
    with Path(path).open(encoding='utf-8-sig',newline='') as h:return list(csv.DictReader(h))
def exp(tid):return ';'.join(f"{r['field']}={r['expected_value']}" for r in read(ROOT/f'tests/tick_shock/expected/{tid}_expected.csv'))
def main():
    p=argparse.ArgumentParser();p.add_argument('--phase',choices=('red','green'),required=True);p.add_argument('--raw',type=Path);a=p.parse_args();cases=[r for r in read(ROOT/'tests/tick_shock/spec/test_cases.csv') if r['test_id'].startswith('TS15F-')];raw={r['test_id']:r for r in read(a.raw)} if a.raw and a.raw.exists() else {};rows=[]
    for c in cases:
        tid=c['test_id'];expected=exp(tid);obs=raw.get(tid)
        if a.phase=='red':status='XFAIL';actual='PRODUCTION_CONTEXT_FEATURE_API_ABSENT';difference=f'expected {expected}; production module absent'
        elif not obs:status='FAIL';actual='NO_PRODUCTION_OBSERVATION';difference='missing harness row'
        else:status='PASS' if obs.get('observed')=='MATCH' else 'FAIL';actual=obs.get('actual','');difference=obs.get('difference','')
        rows.append(dict(test_id=tid,requirement_id=c['requirement_id'],defect_id=c['defect_id'],test_layer=c['test_layer'],status=status,expected=expected,actual=actual,difference=difference,evidence_path=str(a.raw or 'reports/tests/tick_shock/step15f_red/step15f_red_results.csv').replace('\\','/')))
    out=ROOT/f'reports/tests/tick_shock/step15f_{a.phase}';out.mkdir(parents=True,exist_ok=True);counts=Counter(r['status'] for r in rows)
    with (out/f'step15f_{a.phase}_results.csv').open('w',encoding='utf-8',newline='') as h:w=csv.DictWriter(h,fieldnames=FIELDS);w.writeheader();w.writerows(rows)
    (out/f'step15f_{a.phase}_report.md').write_text(f'# Step 15F {a.phase.upper()} contracts\n\n'+'\n'.join(f'- {s}: {counts[s]}' for s in ('PASS','FAIL','XFAIL','XPASS','SKIP','BLOCKED'))+'\n\nExpected values are frozen independent CSV oracles.\n',encoding='utf-8')
    print(' '.join(f'{s}={counts[s]}' for s in ('PASS','FAIL','XFAIL','XPASS','SKIP','BLOCKED')));return 0 if a.phase=='red' or counts['FAIL']+counts['XFAIL']+counts['XPASS']+counts['BLOCKED']==0 else 1
if __name__=='__main__':raise SystemExit(main())
