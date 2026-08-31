#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
FIELDS=('test_id','requirement_id','defect_id','test_layer','status','expected','actual','difference','evidence_path')
def read(p):
    with Path(p).open(encoding='utf-8-sig',newline='') as h:return list(csv.DictReader(h))
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--phase',choices=('red','green'),required=True);ap.add_argument('--raw',type=Path);a=ap.parse_args()
    cases=[r for r in read(ROOT/'tests/tick_shock/spec/test_cases.csv') if r['test_id'].startswith('TS15G-')];raw={r['test_id']:r for r in read(a.raw)} if a.raw and a.raw.exists() else {};out=[]
    for c in cases:
        tid=c['test_id'];e=read(ROOT/c['expected_path'])[0];expected=f"{e['field']}={e['expected_value']}";obs=raw.get(tid)
        if a.phase=='red':status='XFAIL';actual='PRODUCTION_ECONOMIC_PATH_API_ABSENT';difference='production API absent'
        elif not obs:status='FAIL';actual='NO_PRODUCTION_OBSERVATION';difference='missing harness row'
        else:status='PASS' if obs.get('observed')=='MATCH' else 'FAIL';actual=obs.get('actual','');difference=obs.get('difference','')
        out.append(dict(test_id=tid,requirement_id=c['requirement_id'],defect_id=c['defect_id'],test_layer=c['test_layer'],status=status,expected=expected,actual=actual,difference=difference,evidence_path=str(a.raw or '').replace('\\','/')))
    folder=ROOT/f'reports/tests/tick_shock/step15g_{a.phase}';folder.mkdir(parents=True,exist_ok=True);counts=Counter(r['status'] for r in out)
    with (folder/f'step15g_{a.phase}_results.csv').open('w',encoding='utf-8',newline='') as h:w=csv.DictWriter(h,fieldnames=FIELDS);w.writeheader();w.writerows(out)
    (folder/f'step15g_{a.phase}_report.md').write_text('# Step 15G '+a.phase.upper()+' report\n\n'+'\n'.join(f'- {x}: {counts[x]}' for x in ('PASS','FAIL','XFAIL','XPASS','SKIP','BLOCKED'))+'\n',encoding='utf-8')
    print(' '.join(f'{x}={counts[x]}' for x in ('PASS','FAIL','XFAIL','XPASS','SKIP','BLOCKED')))
    return 0 if a.phase=='red' or counts['FAIL']+counts['XFAIL']+counts['XPASS']+counts['BLOCKED']==0 else 1
if __name__=='__main__':raise SystemExit(main())
