#!/usr/bin/env python3
"""Independent Step 15E oracle reconciliation; contains no production formula."""
from __future__ import annotations
import csv,math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
def read(path):
    with Path(path).open(encoding='utf-8-sig',newline='') as h:return list(csv.DictReader(h))
def main():
    raw={r['test_id']:r for r in read(ROOT/'reports/tests/tick_shock/step15e_green/raw/medium_horizon_response.csv')}
    cases=[r for r in read(ROOT/'tests/tick_shock/spec/test_cases.csv') if r['test_id'].startswith('TS15E-')];out=[]
    for case in cases:
        tid=case['test_id'];obs=raw.get(tid,{});actual=dict(part.split('=',1) for part in obs.get('actual','').split(';') if '=' in part)
        for expected in read(ROOT/case['expected_path']):
            field=expected['field'];want=expected['expected_value'];got=actual.get(field,'');tol=float(expected['tolerance'] or 0);match=got==want
            if not match and expected['unit'] in {'ms','count','price','ratio','log_return'}:
                try:match=math.isfinite(float(got)) and abs(float(got)-float(want))<=tol
                except ValueError:pass
            out.append({'test_id':tid,'field':field,'expected':want,'actual':got,'tolerance':expected['tolerance'],'status':'PASS' if match else 'FAIL','oracle_source':case['expected_path']})
    target=ROOT/'reports/tests/tick_shock/step15e_green/independent_oracle.csv'
    with target.open('w',encoding='utf-8',newline='') as h:w=csv.DictWriter(h,fieldnames=out[0]);w.writeheader();w.writerows(out)
    failed=sum(r['status']=='FAIL' for r in out);print(f'rows={len(out)} mismatches={failed}');return 1 if failed else 0
if __name__=='__main__':raise SystemExit(main())
