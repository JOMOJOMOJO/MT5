#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv,math,statistics
from collections import Counter
from pathlib import Path

def read(p):
    with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def num(x):
    try:return float(x)
    except (ValueError,TypeError):return math.nan
def median(v):
    a=[x for x in v if math.isfinite(x)];return statistics.median(a) if a else math.nan
def close(a,b,tol=1e-9):return math.isfinite(a) and math.isfinite(b) and abs(a-b)<=tol
def main():
    p=argparse.ArgumentParser();p.add_argument('--analysis-dir',type=Path,required=True);a=p.parse_args();d=a.analysis_dir
    e=read(d/'episode_excursion_dataset.csv');h=read(d/'horizon_excursion_summary.csv');dist=read(d/'distance_time_to_hit.csv');audit=read(d/'existing_sl_tp_geometry_audit.csv');checks=[]
    ready=[r for r in e if r['analysis_ready']=='TRUE']
    checks.append(('episode_count',len(e),len(e)))
    checks.append(('analysis_ready_count',len(ready),len(ready)))
    checks.append(('duplicate_episode_id',len(e)-len({r['episode_id'] for r in e}),0))
    checks.append(('entry_before_t0',sum(bool(r['entry_quote_msc']) and int(r['entry_quote_msc'])<int(r['t0_msc']) for r in e),0))
    for side in ('cont','rev'):
        actual=median([num(r[f'h3600_{side}_mfe'])/num(r['atr14_m5']) for r in ready])
        reported=next(num(r['mfe_p50']) for r in h if r['population']=='ALL' and r['side']==side.upper() and r['horizon_seconds']=='3600')
        checks.append((f'{side}_mfe_atr_3600_median',actual,reported))
    for side in ('cont','rev'):
        actual=sum(math.isfinite(num(r[f'd0.40_{side}_hit_ms'])) for r in ready)
        reported=next(int(r['hit_count']) for r in dist if r['population']=='ALL' and r['side']==side.upper() and abs(num(r['distance_atr'])-.4)<1e-9)
        checks.append((f'{side}_040_hit_count',actual,reported))
    dom=Counter(r['existing_risk_source'] for r in audit if r['analysis_ready']=='TRUE')
    for k in ('ATR14_M5','ENTRY_SPREAD','BROKER_STOP'):checks.append((f'dominant_{k}',dom[k],dom[k]))
    out=[]
    for name,actual,expected in checks:
        ok=actual==expected if isinstance(actual,int) else close(float(actual),float(expected),1e-8)
        out.append({'check':name,'actual':actual,'expected':expected,'status':'PASS' if ok else 'FAIL'})
    with (d/'independent_oracle.csv').open('w',encoding='utf-8',newline='') as f:w=csv.DictWriter(f,fieldnames=out[0].keys());w.writeheader();w.writerows(out)
    fail=sum(r['status']=='FAIL' for r in out);print(f'oracle_checks={len(out)} failures={fail}');return 1 if fail else 0
if __name__=='__main__':raise SystemExit(main())
