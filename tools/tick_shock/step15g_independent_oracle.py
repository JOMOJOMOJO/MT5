#!/usr/bin/env python3
"""Independent reconciliation of frozen Step15G CSV oracles and MQL observations."""
from __future__ import annotations
import csv
from decimal import Decimal, ROUND_CEILING, ROUND_FLOOR
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/tests/tick_shock/step15g_green/independent_oracle.csv'
def read(path):
    with Path(path).open(encoding='utf-8-sig',newline='') as h:return list(csv.DictReader(h))
def main():
    raw={r['test_id']:r for r in read(ROOT/'reports/tests/tick_shock/step15g_green/raw/economic_path.csv')};cases=[r for r in read(ROOT/'tests/tick_shock/spec/test_cases.csv') if r['test_id'].startswith('TS15G-')];rows=[]
    for case in cases:
        exp=read(ROOT/case['expected_path'])[0];obs=raw.get(case['test_id'],{});actual_pairs=dict(x.split('=',1) for x in obs.get('actual','').split(';') if '=' in x);actual=actual_pairs.get(exp['field'],'');match=obs.get('observed')=='MATCH' and actual==exp['expected_value'];rows.append(dict(check_id=case['test_id'],oracle='FROZEN_EXPECTED_CSV',expected=exp['expected_value'],actual=actual,difference='' if match else f"{exp['expected_value']}!={actual}",status='PASS' if match else 'FAIL'))
    # Hand calculation independent of MQL: max(.25*.004,4*.0002,0)=.001;
    # long entry 1.0002, SL .9992, TP ceil(1.0014/tick)*tick gives 1.2R.
    atr=Decimal('.004');spread=Decimal('.0002');tick=Decimal('.0001');risk=max(Decimal('.25')*atr,Decimal('4')*spread,Decimal('0'));entry=Decimal('1.0002');sl=((entry-risk)/tick).to_integral_value(rounding=ROUND_FLOOR)*tick;actual_risk=entry-sl;tp=((entry+actual_risk*Decimal('1.2'))/tick).to_integral_value(rounding=ROUND_CEILING)*tick;rr=(tp-entry)/actual_risk
    for cid,expected,actual in [('TS15G-ORACLE-RISK','0.001',str(risk)),('TS15G-ORACLE-LONG-SL','0.9992',str(sl)),('TS15G-ORACLE-LONG-TP','1.0014',str(tp)),('TS15G-ORACLE-RR','1.2',str(rr))]:rows.append(dict(check_id=cid,oracle='DECIMAL_HAND_CALCULATION',expected=expected,actual=actual,difference='' if Decimal(expected)==Decimal(actual) else f'{expected}!={actual}',status='PASS' if Decimal(expected)==Decimal(actual) else 'FAIL'))
    OUT.parent.mkdir(parents=True,exist_ok=True)
    with OUT.open('w',encoding='utf-8',newline='') as h:w=csv.DictWriter(h,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
    failures=sum(r['status']=='FAIL' for r in rows);print(f'ORACLE_CHECKS={len(rows)} DIFFERENCES={failures}');return 1 if failures else 0
if __name__=='__main__':raise SystemExit(main())
