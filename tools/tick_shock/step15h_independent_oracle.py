#!/usr/bin/env python3
"""Independent arithmetic checks for the frozen Step 15H execution contract."""
from __future__ import annotations
import csv, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/tests/tick_shock/step15h_green/independent_oracle.csv'
rows=[]
def check(name, expected, actual, tol=0.0):
    ok=abs(float(expected)-float(actual))<=tol if isinstance(expected,(int,float)) else expected==actual
    rows.append({'check':name,'expected':expected,'actual':actual,'tolerance':tol,'status':'PASS' if ok else 'FAIL'})
t0=max(1500,1600);check('t0_processing_clock',1600,t0)
for delay in (0,100,250):check(f'eligible_delay_{delay}',1600+delay,max(1500+delay,1600+delay))
check('horizon_from_t0',901600,t0+900000)
entry_ask=1.0002;spread=.0002;atr=.004;risk=max(.25*atr,4*spread,0.0)
sl=entry_ask-risk;tick=.0001;tp=math.ceil((entry_ask+1.2*risk)/tick-1e-12)*tick
check('risk_distance',.001,risk,1e-12);check('rr_outward_min',1.2,(tp-entry_ask)/risk,1e-12)
selected=[True,False,True];returns=[.2,-1,.1];check('policy_value',.1,sum(r for s,r in zip(selected,returns) if s)/len(returns),1e-12)
OUT.parent.mkdir(parents=True,exist_ok=True)
with OUT.open('w',encoding='utf-8',newline='') as h:w=csv.DictWriter(h,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
raise SystemExit(0 if all(r['status']=='PASS' for r in rows) else 1)
