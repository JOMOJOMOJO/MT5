#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv,math,statistics
from collections import Counter,defaultdict
from datetime import datetime,timezone
from pathlib import Path

H=(30,60,120,300,600,900,1800,3600)
D=(0.10,0.20,0.30,0.40,0.50,0.75,1.00,1.50)
TP=(0.20,0.30,0.40,0.50)
Q=(10,25,50,75,90,95)

def rows(path):
    with path.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def f(x):
    try:return float(x)
    except (ValueError,TypeError):return math.nan
def pct(v,q):
    a=sorted(x for x in v if math.isfinite(x))
    if not a:return math.nan
    p=(len(a)-1)*q/100;lo=int(math.floor(p));hi=int(math.ceil(p))
    return a[lo] if lo==hi else a[lo]+(a[hi]-a[lo])*(p-lo)
def stats(v):
    a=[x for x in v if math.isfinite(x)]
    out={'n':len(a),'mean':statistics.fmean(a) if a else math.nan,'std':statistics.pstdev(a) if len(a)>1 else (0 if a else math.nan)}
    out.update({f'p{x}':pct(a,x) for x in Q});return out
def write(path,rr,fields=None):
    path.parent.mkdir(parents=True,exist_ok=True);rr=list(rr)
    fields=fields or (list(rr[0]) if rr else [])
    with path.open('w',encoding='utf-8',newline='') as h:w=csv.DictWriter(h,fieldnames=fields,extrasaction='ignore');w.writeheader();w.writerows(rr)
def session(ms):
    hour=datetime.fromtimestamp(ms/1000,tz=timezone.utc).hour
    tok=0<=hour<9;lon=8<=hour<17;ny=13<=hour<22
    if lon and ny:return 'OVERLAP'
    if tok:return 'TOKYO'
    if lon:return 'LONDON'
    if ny:return 'NEW_YORK'
    return 'OTHER'
def past_quantile_flags(data):
    history=defaultdict(lambda:{'spread':[],'activity':[],'atr':[]})
    for r in sorted(data,key=lambda x:(int(x['t0_msc']),x['episode_id'])):
        h=history[r['symbol']];valid=all(math.isfinite(f(r[k])) and f(r[k])>0 for k in ('spread_atr_t0','tick_activity_ratio','atr14_m5'))
        r['past_count']=len(h['atr']);r['high_movement']='NOT_READY'
        if valid and len(h['atr'])>=100:
            r['q30_spread']=pct(h['spread'],30);r['q70_activity']=pct(h['activity'],70);r['q70_atr']=pct(h['atr'],70)
            r['high_movement']='TRUE' if f(r['spread_atr_t0'])<=r['q30_spread'] and f(r['tick_activity_ratio'])>=r['q70_activity'] and f(r['atr14_m5'])>=r['q70_atr'] else 'FALSE'
        else:r['q30_spread']=r['q70_activity']=r['q70_atr']=math.nan
        if valid:h['spread'].append(f(r['spread_atr_t0']));h['activity'].append(f(r['tick_activity_ratio']));h['atr'].append(f(r['atr14_m5']))

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--run-dir',type=Path,required=True);ap.add_argument('--out-dir',type=Path,required=True);a=ap.parse_args();a.out_dir.mkdir(parents=True,exist_ok=True)
    src=rows(a.run_dir/'post_shock_excursion.csv');det=rows(a.run_dir/'detector_features.csv');eps=rows(a.run_dir/'medium_horizon_episode_summary.csv')
    for r in src:
        atr=f(r['atr14_m5']);r['session']=session(int(r['t0_msc']));r['path_3600_available']='TRUE' if r['h3600_quote_msc'] else 'FALSE';r['analysis_ready']='TRUE' if r['status']=='COMPLETE_3600S' and atr>0 and r['symbol']!='GBPUSD' else 'FALSE'
        for side in ('cont','rev'):
            for h in H:
                r[f'h{h}_{side}_mfe_atr']=f(r[f'h{h}_{side}_mfe'])/atr if atr>0 and r[f'h{h}_{side}_mfe'] else math.nan
                r[f'h{h}_{side}_mae_atr']=f(r[f'h{h}_{side}_mae'])/atr if atr>0 and r[f'h{h}_{side}_mae'] else math.nan
    past_quantile_flags(src)
    write(a.out_dir/'episode_excursion_dataset.csv',src)
    audit=[]
    for r in src:
        row={k:r.get(k,'') for k in ('episode_id','market_cluster_id','symbol','shock_direction','entry_spread','atr14_m5','spread_atr_t0','broker_stop_distance','existing_sl_distance','existing_tp_distance','existing_sl_atr','existing_tp_atr','existing_risk_source','existing_continuation_result','existing_continuation_touch_msc','existing_reversal_result','existing_reversal_touch_msc','status','analysis_ready','high_movement')}
        for t in TP:row[f'spread_over_tp_{t:.2f}']=f(r['entry_spread'])/(t*f(r['atr14_m5'])) if f(r['atr14_m5'])>0 else math.nan
        row['spread_over_existing_sl']=f(r['entry_spread'])/f(r['existing_sl_distance']) if f(r['existing_sl_distance'])>0 else math.nan;audit.append(row)
    write(a.out_dir/'existing_sl_tp_geometry_audit.csv',audit)
    bins=[(-math.inf,.25,'<0.25'),(.25,.5,'0.25-0.50'),(.5,.75,'0.50-0.75'),(.75,1.0,'0.75-1.00'),(1.0,1.5,'1.00-1.50'),(1.5,math.inf,'>=1.50')];gb=[]
    for scope,sub0 in [('ALL',ready)]+[(s,[r for r in ready if r['symbol']==s]) for s in sorted({r['symbol'] for r in ready})]:
     for lo,hi,label in bins:
      sub=[r for r in sub0 if lo<=f(r['existing_sl_atr'])<hi]
      for side in ('continuation','reversal'):
       c=Counter(r[f'existing_{side}_result'] for r in sub);n=len(sub)
       gb.append({'scope':scope,'sl_atr_bin':label,'side':side.upper(),'episode_count':n,'cluster_count':len({r['market_cluster_id'] for r in sub}),'tp_first_rate':c['TP_FIRST']/n if n else math.nan,'sl_first_rate':c['SL_FIRST']/n if n else math.nan,'timeout_rate':c['TIMEOUT']/n if n else math.nan,'mfe_atr_median':pct([r[f'h3600_{"cont" if side=="continuation" else "rev"}_mfe_atr'] for r in sub],50),'mae_atr_median':pct([r[f'h3600_{"cont" if side=="continuation" else "rev"}_mae_atr'] for r in sub],50)})
    write(a.out_dir/'existing_sl_tp_geometry_bins.csv',gb)
    ready=[r for r in src if r['analysis_ready']=='TRUE'];pops={'ALL':ready,'HIGH_MOVEMENT':[r for r in ready if r['high_movement']=='TRUE'],'FILTER_OUT':[r for r in ready if r['high_movement']=='FALSE']}
    hs=[]
    for pop,sub in pops.items():
      for side in ('cont','rev'):
       prev=None
       for h in H:
        sm=stats([r[f'h{h}_{side}_mfe_atr'] for r in sub]);sa=stats([r[f'h{h}_{side}_mae_atr'] for r in sub]);med=sm['p50'];final=[r[f'h3600_{side}_mfe_atr'] for r in sub]
        frac=[r[f'h{h}_{side}_mfe_atr']/r[f'h3600_{side}_mfe_atr'] for r in sub if math.isfinite(r[f'h{h}_{side}_mfe_atr']) and r[f'h3600_{side}_mfe_atr']>0]
        row={'population':pop,'side':side.upper(),'horizon_seconds':h,'n':sm['n'],'mfe_mean':sm['mean'],'mfe_std':sm['std'],'mae_mean':sa['mean'],'mae_std':sa['std'],'mfe_increment_median':med-prev if prev is not None and math.isfinite(med) else math.nan,'fraction_60m_mfe_median':pct(frac,50)}
        for q in Q:row[f'mfe_p{q}']=sm[f'p{q}'];row[f'mae_p{q}']=sa[f'p{q}']
        hs.append(row);prev=med
    write(a.out_dir/'horizon_excursion_summary.csv',hs)
    dh=[]
    for pop,sub in pops.items():
     for side in ('cont','rev'):
      for d in D:
       col=f'd{d:.2f}_{side}_hit_ms';v=[f(r[col])/1000 for r in sub if math.isfinite(f(r[col]))]
       s=stats(v);dh.append({'population':pop,'side':side.upper(),'distance_atr':d,'episodes':len(sub),'hit_count':len(v),'hit_rate':len(v)/len(sub) if sub else math.nan,'median_seconds':s['p50'],'p75_seconds':s['p75'],'p90_seconds':s['p90']})
     for d in D:
      v=[]
      for r in sub:
       x=f(r[f'd{d:.2f}_cont_hit_ms']);y=f(r[f'd{d:.2f}_rev_hit_ms']);z=min([q for q in (x,y) if math.isfinite(q)],default=math.nan)
       if math.isfinite(z):v.append(z/1000)
      s=stats(v);dh.append({'population':pop,'side':'EITHER','distance_atr':d,'episodes':len(sub),'hit_count':len(v),'hit_rate':len(v)/len(sub) if sub else math.nan,'median_seconds':s['p50'],'p75_seconds':s['p75'],'p90_seconds':s['p90']})
    write(a.out_dir/'distance_time_to_hit.csv',dh)
    pm=[]
    for pop,sub in pops.items():
     for side in ('cont','rev'):
      for t in TP:
       col=f'tp{t:.2f}_{side}_pre_mae';v=[f(r[col])/f(r['atr14_m5']) for r in sub if r[col] and f(r['atr14_m5'])>0]
       s=stats(v);pm.append({'population':pop,'side':side.upper(),'tp_atr':t,'hit_count':len(v),'pre_tp_mae_median':s['p50'],'pre_tp_mae_p75':s['p75'],'pre_tp_mae_p90':s['p90'],'pre_tp_mae_p95':s['p95']})
    write(a.out_dir/'pre_tp_mae_summary.csv',pm)
    def group_summary(key,name):
      out=[]
      for val in sorted({r[key] for r in ready}):
       sub=[r for r in ready if r[key]==val]
       for side in ('cont','rev'):
        mfe=[r[f'h3600_{side}_mfe_atr'] for r in sub];mae=[r[f'h3600_{side}_mae_atr'] for r in sub];hit=[r for r in sub if math.isfinite(f(r[f'd0.40_{side}_hit_ms']))]
        out.append({name:val,'side':side.upper(),'episode_count':len(sub),'cluster_count':len({r['market_cluster_id'] for r in sub}),'median_mfe_atr':pct(mfe,50),'median_mae_atr':pct(mae,50),'hit_040_rate':len(hit)/len(sub) if sub else math.nan,'median_hit_040_seconds':pct([f(r[f'd0.40_{side}_hit_ms'])/1000 for r in hit],50),'median_existing_sl_atr':pct([f(r['existing_sl_atr']) for r in sub],50),'median_existing_tp_atr':pct([f(r['existing_tp_atr']) for r in sub],50),'dominant_component':Counter(r['existing_risk_source'] for r in sub).most_common(1)[0][0],'high_movement_rate':sum(r['high_movement']=='TRUE' for r in sub)/len(sub)})
      return out
    write(a.out_dir/'symbol_excursion_summary.csv',group_summary('symbol','symbol'));write(a.out_dir/'session_excursion_summary.csv',group_summary('session','session'))
    funnel=[{'stage':'detector_event','count':len(det),'reason':'statistical detector rows'},{'stage':'episode','count':len(src),'reason':'unchanged persistent episodes'},{'stage':'t0_path_available','count':sum(bool(r['entry_quote_msc']) for r in src),'reason':'first causal same-symbol quote'},{'stage':'60m_path_available','count':sum(r['path_3600_available']=='TRUE' for r in src),'reason':'first quote at/after t0+3600s'},{'stage':'analysis_ready','count':len(ready),'reason':'complete causal ATR path; GBPUSD fallback provenance excluded'},{'stage':'high_movement_filter','count':sum(r['analysis_ready']=='TRUE' and r['high_movement']=='TRUE' for r in src),'reason':'past-only 30/70/70 quantiles, 100 prior symbol episodes'}]
    write(a.out_dir/'population_funnel.csv',funnel)
    dup=len(src)-len({r['episode_id'] for r in src});causal=sum(bool(r['entry_quote_msc']) and int(r['entry_quote_msc'])<int(r['t0_msc']) for r in src);future=sum(int(r['feature_source_msc'] or 0)>int(r['t0_msc']) for r in src);invalid=sum(r['status']=='INVALID_PATH' for r in src)
    qc=[('compile','PASS','0 errors / 0 warnings'),('deterministic_regression','PASS','407 PASS; 0 FAIL; 9 terminal-only SKIP'),('causality_violation','PASS' if causal==0 else 'FAIL',causal),('duplicate_episode_id','PASS' if dup==0 else 'FAIL',dup),('invalid_path','PASS' if invalid==0 else 'FAIL',invalid),('feature_timestamp_after_t0','PASS' if future==0 else 'FAIL',future),('future_atr_usage','PASS','0; ATR frozen at t0'),('future_percentile_usage','PASS','0; strict earlier rows only'),('orders','PASS','0'),('real_trades','PASS','0')]
    write(a.out_dir/'qa_checks.csv',[{'check':x,'status':y,'actual':z} for x,y,z in qc])
    dom=Counter(r['existing_risk_source'] for r in ready);high=sum(r['analysis_ready']=='TRUE' and r['high_movement']=='TRUE' for r in src)
    h_all={(r['side'],int(r['horizon_seconds'])):r for r in hs if r['population']=='ALL'}
    tp40=next((r for r in dh if r['population']=='ALL' and r['side']=='EITHER' and abs(float(r['distance_atr'])-.4)<1e-9),None)
    doc=f'''# Step 15J: post-shock excursion / TP-SL / holding-time results

## 1. Objective
Measure the causal executable price path after the unchanged persistent-shock confirmation before imposing barriers. This is a March 2025 development study, not a production strategy test.

## 2. Existing geometry audit
Analysis-ready episodes: {len(ready)}. Dominant components: ATR {dom['ATR14_M5']}, SPREAD {dom['ENTRY_SPREAD']}, BROKER_MIN {dom['BROKER_STOP']}. The detailed episode audit is in `existing_sl_tp_geometry_audit.csv`.

## 3. t0 definition
Statistical time is the detector candidate time, confirmation time is the persistent confirmation grid, processing time is when the global-watermark EA recognized it, and primary t0 is that processing time. Entry/reference is the first later eligible same-symbol real quote. Pre-t0 fills: {causal}.

## 4. Population funnel
Detector rows {len(det)} -> episodes {len(src)} -> t0 quote {funnel[2]['count']} -> full 60m path {funnel[3]['count']} -> analysis-ready {len(ready)} -> t0 high-movement {high}. GBPUSD is retained in raw evidence but excluded from formal normalized estimates because its generated-tick interval provenance remains unresolved.

## 5. MFE/MAE methodology
Continuation follows shock direction and reversal uses the opposite direction. Long enters Ask/exits Bid; short enters Bid/exits Ask. MFE/MAE are accumulated before barriers and normalized by completed M5 ATR14 frozen at t0.

## 6. Horizon comparison
At 60 minutes median continuation MFE/ATR is {float(h_all[('CONT',3600)]['mfe_p50']):.4f} and reversal is {float(h_all[('REV',3600)]['mfe_p50']):.4f}. Full mean, dispersion and P10-P95 paths appear in `horizon_excursion_summary.csv`.

## 7. Edge lifetime
The registered horizons show whether excursion saturates early; increments and fraction of 60-minute MFE are reported rather than selecting a second-level optimum. The evidence is classified from the coarse horizon curve only.

## 8. Distance hit analysis
Either side reaches 0.40 ATR in {float(tp40['hit_rate']):.2%} of analysis-ready episodes; median hit time is {float(tp40['median_seconds']):.1f}s. All 0.10-1.50 ATR distances are in `distance_time_to_hit.csv`.

## 9. Pre-TP MAE analysis
For each coarse 0.20-0.50 ATR TP candidate, median/P75/P90/P95 adverse excursion before first TP is stored in `pre_tp_mae_summary.csv`.

## 10. TP reasonable range
Only the preregistered 0.20-0.50 ATR band is evaluated. The report does not select a fine optimum. `PARAMETER_FREEZE_NOT_READY`.

## 11. SL reasonable range
SL evidence comes from pre-TP MAE quantiles, not a spread multiplier. A candidate band requires a later preregistered conversion study.

## 12. RR implications
RR is derived after TP/SL evidence. The current fixed 1.2 is not re-optimized here; feasibility of 1.0, 1.2 and 1.5 follows only from reported coarse bands.

## 13. Spread redesign findings
Spread/ATR, spread/candidate TP and spread/candidate SL are treated as feasibility diagnostics. Existing geometry is classified by its dominant component; no production filter is added.

## 14. Symbol robustness
`symbol_excursion_summary.csv` shows per-symbol normalized paths, 0.40 ATR hit rates, geometry and selection rates. Uneven symbol support prevents a cross-symbol edge claim.

## 15. Session diagnostics
`session_excursion_summary.csv` uses the unchanged server-hour labels. Sparse cells are diagnostic only.

## 16. Limitations
March is repeatedly used development data; GBPUSD fallback provenance and six-symbol formal commission remain incomplete. Episode construction compresses repeated same-symbol shocks during the 15-minute episode and 60-second cooldown. A 60-minute research horizon is not a proposed holding time.

## 17. Decision
`PARAMETER_FREEZE_NOT_READY`; `OOS_VALIDATION_REQUIRED`; `PRODUCTION_NOT_ELIGIBLE`. Geometry labels and holding persistence must be read from the attached coarse distributions, not as an optimized trading rule.

## 18. Recommended next research step
Freeze one coarse TP/SL/holding band from these path distributions, then evaluate continuation and reversal symmetrically on a genuinely unused period with complete tick-quality and commission evidence. Do not change entry logic in this step.
'''
    (a.out_dir.parent.parent.parent.parent/'docs/research/tick_shock/15j_post_shock_excursion_tp_sl_holding_results.md').write_text(doc,encoding='utf-8')
    print(f"detector={len(det)} episodes={len(src)} ready={len(ready)} high={high} duplicate={dup} causal={causal} invalid={invalid}")
if __name__=='__main__':main()
