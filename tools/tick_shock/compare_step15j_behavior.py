#!/usr/bin/env python3
from __future__ import annotations
import csv
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'reports/backtest/runs/20260902_ts15h_detection_time_continuation_r1_202503'
RUN=ROOT/'reports/backtest/runs/20260902_ts15j_post_shock_excursion_r2_202503'
OUT=ROOT/'reports/analysis/tick_shock/step15j/behavior_comparison.csv'
def read(p):
    with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def compare(name,file,ignore):
    a=read(BASE/file);b=read(RUN/file);cols=[c for c in a[0] if c not in ignore]
    mismatches=0
    if len(a)==len(b):
        for x,y in zip(a,b):mismatches+=any(x.get(c,'')!=y.get(c,'') for c in cols)
    else:mismatches=max(len(a),len(b))
    return {'component':name,'baseline_rows':len(a),'step15j_rows':len(b),'compared_columns':len(cols),'mismatch_rows':mismatches,'status':'PASS' if mismatches==0 else 'FAIL'}
def main():
    result=[compare('detector_features','detector_features.csv',{'event_id'}),compare('persistent_episodes','medium_horizon_episode_summary.csv',{'episode_id','anchor_event_id'})]
    OUT.parent.mkdir(parents=True,exist_ok=True)
    with OUT.open('w',encoding='utf-8',newline='') as f:w=csv.DictWriter(f,fieldnames=result[0]);w.writeheader();w.writerows(result)
    print(result);return int(any(r['status']=='FAIL' for r in result))
if __name__=='__main__':raise SystemExit(main())
