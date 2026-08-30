#!/usr/bin/env python3
"""Independent Step 15E reversal-direction and population-coverage audit."""
from __future__ import annotations
import json, math
from pathlib import Path
import numpy as np
import pandas as pd

ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'reports/backtest/runs/20260830_ts15e_tail_v1_persistent_medium_horizon_202503'
AN=ROOT/'reports/analysis/tick_shock/step15e'
OUT=ROOT/'reports/qa/tick_shock/step15f_step15e_audit'
CLOCKS=('CONFIRMED','CONFIRMED_PLUS_30S','CONFIRMED_PLUS_60S','CONFIRMED_PLUS_120S','CAUSAL_STATE_TRANSITION')
HORIZONS=(300,600,900)
SEED=20260831

def write(df,name):OUT.mkdir(parents=True,exist_ok=True);df.to_csv(OUT/name,index=False)
def b(s):return s.astype(str).str.lower().eq('true')
def day_ci(g,col,seed):
    x=g[['server_day',col]].dropna();days=x.server_day.unique()
    if len(days)<2:return np.nan,np.nan
    by={d:x.loc[x.server_day==d,col].to_numpy() for d in days};rng=np.random.default_rng(seed);means=[]
    for _ in range(2000):
        draw=rng.choice(days,len(days),replace=True);means.append(np.concatenate([by[d] for d in draw]).mean())
    return tuple(np.quantile(means,[.025,.975]))
def ppos(x):
    x=np.asarray(x,float);x=x[np.isfinite(x)]
    if len(x)<2:return 1.0
    sd=x.std(ddof=1)
    if sd<=0:return 0.0 if x.mean()>0 else 1.0
    return .5*math.erfc((x.mean()/(sd/math.sqrt(len(x))))/math.sqrt(2))
def holm(v):
    order=np.argsort(v);out=np.ones(len(v));run=0.;n=len(v)
    for rank,ix in enumerate(order):run=max(run,(n-rank)*v[ix]);out[ix]=min(1.,run)
    return out
def smd(a,b):
    a=np.asarray(a,float);b=np.asarray(b,float);a=a[np.isfinite(a)];b=b[np.isfinite(b)]
    if len(a)<2 or len(b)<2:return np.nan
    pool=math.sqrt(((len(a)-1)*a.var(ddof=1)+(len(b)-1)*b.var(ddof=1))/(len(a)+len(b)-2))
    return (a.mean()-b.mean())/pool if pool>0 else 0.

def main():
    ep=pd.read_csv(AN/'episode_summary.csv',low_memory=False)
    resp=pd.read_csv(RUN/'medium_horizon_response.csv',low_memory=False)
    entry=pd.read_csv(RUN/'medium_horizon_entry_comparison.csv',low_memory=False)
    ep['primary_base']=ep.symbol.ne('GBPUSD')&ep.episode_status.eq('COMPLETE_900S')&ep.validation_status.eq('VALID')&ep.pre_vol_status.eq('AVAILABLE')
    ep['server_day']=pd.to_datetime(ep.anchor_msc,unit='ms',utc=True).dt.strftime('%Y-%m-%d')
    ep['server_hour']=pd.to_datetime(ep.anchor_msc,unit='ms',utc=True).dt.hour
    ep['anchor_spread']=ep.anchor_ask-ep.anchor_bid
    dup=ep.episode_id.duplicated(keep=False)
    # First, reconcile all episodes to the stated primary population.
    base_reason=np.where(ep.symbol.eq('GBPUSD'),'FALLBACK_CONTAMINATION',np.where(~ep.episode_status.eq('COMPLETE_900S'),'HORIZON_INCOMPLETE',np.where(~ep.pre_vol_status.eq('AVAILABLE'),'CAUSAL_VOLATILITY_SCALE_MISSING',np.where(~ep.validation_status.eq('VALID'),'OTHER_VALIDATION','PRIMARY_POPULATION'))))
    base=pd.DataFrame({'stage':'ALL_TO_PRIMARY','horizon_seconds':0,'reason':base_reason}).value_counts().reset_index(name='episodes')
    rows=[base]
    reason_tables=[]
    for h in HORIZONS:
        r=resp[resp.checkpoint_seconds.eq(h)].set_index('episode_id')
        reasons=[]
        accepted=[]
        for _,e in ep[ep.primary_base].iterrows():
            reason='ELIGIBLE'
            if dup.loc[e.name]:reason='EPISODE_OR_CLUSTER_DUPLICATE'
            elif not np.isfinite(e.pre_m1_rms) or e.pre_m1_rms<=0:reason='CAUSAL_VOLATILITY_SCALE_MISSING'
            elif e.shock_direction not in ('LONG','SHORT'):reason='DIRECTION_UNKNOWN'
            elif e.episode_id not in r.index:reason='HORIZON_INCOMPLETE'
            else:
                q=r.loc[e.episode_id]
                if isinstance(q,pd.DataFrame):reason='EPISODE_OR_CLUSTER_DUPLICATE'
                elif q.availability=='STALE':reason='STALE_QUOTE'
                elif q.availability=='EXCLUDED_FALLBACK':reason='FALLBACK_CONTAMINATION'
                elif q.availability!='AVAILABLE':reason='EXIT_BID_ASK_MISSING'
                elif not all(np.isfinite([e.anchor_bid,e.anchor_ask,q.bid,q.ask])):reason='ENTRY_OR_EXIT_BID_ASK_MISSING'
                elif e.anchor_bid<=0 or e.anchor_ask<e.anchor_bid:reason='ENTRY_BID_ASK_INVALID'
                elif q.bid<=0 or q.ask<q.bid or q.ask-q.bid<=0:reason='INVALID_SPREAD'
            reasons.append((e.episode_id,reason));accepted.append(reason=='ELIGIBLE')
        detail=pd.DataFrame(reasons,columns=['episode_id','first_exclusion_reason']);detail['horizon_seconds']=h;reason_tables.append(detail)
        counts=detail.groupby('first_exclusion_reason').size().reset_index(name='episodes');counts['stage']='PRIMARY_TO_HORIZON';counts['horizon_seconds']=h;counts.rename(columns={'first_exclusion_reason':'reason'},inplace=True);rows.append(counts[['stage','horizon_seconds','reason','episodes']])
    funnel=pd.concat(rows,ignore_index=True);write(funnel,'primary_population_funnel.csv')
    detail=pd.concat(reason_tables,ignore_index=True);write(detail,'primary_population_episode_reasons.csv')
    # Selection-bias diagnostics fixed before outcome inspection: |SMD| >= .5
    # in two continuous fields or >=20 percentage-point category shift is major.
    bias=[]
    for h in HORIZONS:
        d=detail[detail.horizon_seconds.eq(h)].merge(ep,on='episode_id');d['accepted']=d.first_exclusion_reason.eq('ELIGIBLE')
        for field in ('severity','anchor_spread','pre_m1_rms'):
            a=d.loc[d.accepted,field];x=d.loc[~d.accepted,field]
            bias.append(dict(horizon_seconds=h,feature=field,kind='CONTINUOUS',accepted_n=a.notna().sum(),excluded_n=x.notna().sum(),accepted_mean=a.mean(),excluded_mean=x.mean(),effect=smd(a,x),threshold=0.5,major=abs(smd(a,x))>=.5))
        for field in ('symbol','server_hour'):
            ap=d.loc[d.accepted,field].value_counts(normalize=True);xp=d.loc[~d.accepted,field].value_counts(normalize=True);delta=max(abs(ap.get(k,0)-xp.get(k,0)) for k in set(ap.index)|set(xp.index))
            bias.append(dict(horizon_seconds=h,feature=field,kind='CATEGORICAL_MAX_SHARE_DELTA',accepted_n=d.accepted.sum(),excluded_n=(~d.accepted).sum(),accepted_mean='',excluded_mean='',effect=delta,threshold=.20,major=delta>=.20))
    bias=pd.DataFrame(bias);write(bias,'exclusion_bias_analysis.csv')
    # Independent actual-Bid/Ask reversal: merge entry quote with exit quote;
    # never negate the continuation return.
    e=entry.merge(ep[['episode_id','shock_direction','sr_rev_001','primary_base','server_day','anchor_msc']],on='episode_id',how='left')
    rr=[]
    for clock in CLOCKS:
        for h in HORIZONS:
            x=e[(e.entry_clock==clock)&b(e.sr_rev_001)&e.primary_base.fillna(False)&e.entry_status.eq('ENTERED')].copy()
            q=resp[resp.checkpoint_seconds.eq(h)][['episode_id','availability','bid','ask']].rename(columns={'bid':'exit_bid','ask':'exit_ask'})
            x=x.merge(q,on='episode_id',how='left');x=x[x.availability.eq('AVAILABLE')]
            x=x[x.entry_quote_msc < ep.set_index('episode_id').loc[x.episode_id,'anchor_msc'].to_numpy()+h*1000]
            if clock!='CAUSAL_STATE_TRANSITION':x=x[x.direction.ne(x.shock_direction)]
            else:x=x.drop_duplicates('episode_id',keep='first')
            long=x.shock_direction.eq('SHORT');x['audit_direction']=np.where(long,'LONG','SHORT');x['actual_reversal']=np.where(long,x.exit_bid-x.entry_ask,x.entry_bid-x.exit_ask)
            ein=(x.entry_ask-x.entry_bid);eout=(x.exit_ask-x.exit_bid);emid=(x.entry_ask+x.entry_bid)/2;omid=(x.exit_ask+x.exit_bid)/2
            x['stress_125']=np.where(long,(omid-.625*eout)-(emid+.625*ein),(emid-.625*ein)-(omid+.625*eout))
            x['fold']=pd.qcut(x.anchor_msc.rank(method='first'),5,labels=False) if len(x)>=5 else -1
            lo,hi=day_ci(x,'actual_reversal',SEED+h)
            foldmeans=x.groupby('fold').actual_reversal.mean();loso=[x.loc[x.symbol.ne(s),'actual_reversal'].mean() for s in sorted(x.symbol.unique())]
            rr.append(dict(clock=clock,horizon_seconds=h,episodes=len(x),market_clusters=x.episode_id.nunique(),server_days=x.server_day.nunique(),actual_bidask_mean=x.actual_reversal.mean(),actual_bidask_median=x.actual_reversal.median(),positive_fraction=(x.actual_reversal>0).mean(),ci_low=lo,ci_high=hi,p_raw=ppos(x.actual_reversal),positive_folds=int((foldmeans>0).sum()),folds=len(foldmeans),all_loso_positive=bool(loso) and all(v>0 for v in loso),stress_125_mean=x.stress_125.mean()))
    rr=pd.DataFrame(rr);rr['p_holm']=holm(rr.p_raw.to_numpy())
    rr['candidate_gate']=rr.episodes.ge(200)&rr.ci_low.gt(0)&rr.p_holm.lt(.05)&rr.positive_folds.eq(5)&rr.folds.eq(5)&rr.all_loso_positive&rr.stress_125_mean.gt(0)
    write(rr,'reversal_direction_results.csv')
    unexplained=int(funnel.reason.eq('OTHER').mul(funnel.episodes).sum())
    major_bias=int(bias.major.sum())
    candidate_changes=int(rr.candidate_gate.sum())
    summary=dict(total_episodes=len(ep),fallback_excluded=int((ep.symbol=='GBPUSD').sum()),primary_population=int(ep.primary_base.sum()),funnel_reconciled=bool(all(detail[detail.horizon_seconds.eq(h)].shape[0]==int(ep.primary_base.sum()) for h in HORIZONS)),unexplained_exclusions=unexplained,major_selection_bias_flags=major_bias,reversal_candidate_gate_passes=candidate_changes,step15e_status_change_required=candidate_changes>0,verdict='STEP15E_AUDIT_REMEDIATION_REQUIRED' if unexplained or major_bias or candidate_changes else 'STEP15E_DIRECTION_AND_COVERAGE_AUDIT_PASSED')
    (OUT/'audit_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    print(json.dumps(summary))

if __name__=='__main__':main()
