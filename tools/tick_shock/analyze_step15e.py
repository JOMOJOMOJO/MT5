#!/usr/bin/env python3
"""Analyze preregistered Step 15E medium-horizon development evidence."""
from __future__ import annotations
import argparse,csv,hashlib,json,math,re
from collections import Counter
from pathlib import Path
import numpy as np
import pandas as pd

ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'reports/backtest/runs/20260830_ts15e_tail_v1_persistent_medium_horizon_202503'
BASE=ROOT/'reports/backtest/runs/20260829_ts15d_tail_v1_persistent_state_response_202503_r3'
OUT=ROOT/'reports/analysis/tick_shock/step15e'
JOURNAL=Path.home()/'AppData/Roaming/MetaQuotes/Tester/D232275B22422903BD477FB48B858FBA/Agent-127.0.0.1-3000/logs/20260830.log'
HORIZONS=(5,10,30,60,120,180,300,600,900)
COHORTS=('ALL','SR-CLEAN-001','SR-REV-001')

def write(df:pd.DataFrame,name:str):
    path=OUT/name;path.parent.mkdir(parents=True,exist_ok=True);df.to_csv(path,index=False);return path
def boolcol(s):return s.astype(str).str.lower().eq('true')
def cohort_mask(df,name):
    if name=='ALL':return pd.Series(True,index=df.index)
    return boolcol(df['sr_clean_001']) if name=='SR-CLEAN-001' else boolcol(df['sr_rev_001'])
def ci_days(g,col,seed):
    x=g[['server_day',col]].dropna();days=x.server_day.unique()
    if len(days)<2:return (np.nan,np.nan)
    rng=np.random.default_rng(seed);means=[]
    grouped={d:x.loc[x.server_day==d,col].to_numpy() for d in days}
    for _ in range(2000):
        draw=rng.choice(days,len(days),replace=True);values=np.concatenate([grouped[d] for d in draw]);means.append(values.mean())
    return tuple(np.quantile(means,[.025,.975]))
def one_sided_p(values):
    x=np.asarray(values,dtype=float);x=x[np.isfinite(x)]
    if len(x)<2:return 1.0
    sd=x.std(ddof=1)
    if sd<=0:return 0.0 if x.mean()>0 else 1.0
    z=x.mean()/(sd/math.sqrt(len(x)));return .5*math.erfc(z/math.sqrt(2))
def holm(p):
    order=np.argsort(p);adj=np.ones(len(p));running=0.0;m=len(p)
    for rank,ix in enumerate(order):running=max(running,(m-rank)*p[ix]);adj[ix]=min(1.0,running)
    return adj
def parse_set(path):
    out={}
    for line in path.read_text(encoding='utf-8-sig').splitlines():
        if '=' in line:
            k,v=line.split('=',1);out[k]=v
    return out

def journal_evidence():
    text=JOURNAL.read_text(encoding='utf-16',errors='replace')
    lines=text.splitlines();start=next(i for i,line in enumerate(lines) if 'InpRunId=ts15e_medium_horizon_202503' in line);passed=False;end=len(lines)-1
    for i in range(start,len(lines)):
        if 'Test passed in' in lines[i]:passed=True
        if passed and 'memory used' in lines[i]:end=i;break
    keep=[line for line in lines[start:end+1] if any(token in line for token in ('InpRunId=ts15e_medium_horizon_202503','real ticks discarded','tick prices mismatch','tick volumes not matched','last prices absent','Test passed in','total ticks for all symbols','memory used','deinitialized reason='))]
    (RUN/'tester_journal_excerpt.txt').write_text('\n'.join(keep)+'\n',encoding='utf-8')
    rows=[]
    minutes={'EURUSD':30192,'GBPUSD':30188,'USDJPY':30195,'AUDUSD':30193,'USDCAD':30193,'USDCHF':30191}
    for symbol,count in minutes.items():
        if symbol=='GBPUSD':rows.append(dict(symbol=symbol,ea_m1_minutes_seen=count,tester_reported_total_minutes=30187,tester_reported_discarded_minutes=179,tester_reported_fallback_rate_pct=0.5930,status='GENERATED_TICK_FALLBACK_OBSERVED',primary_treatment='ALL_GBPUSD_EPISODES_EXCLUDED_INTERVAL_MAP_UNAVAILABLE',evidence='new Step15E tester journal'))
        else:rows.append(dict(symbol=symbol,ea_m1_minutes_seen=count,tester_reported_total_minutes='',tester_reported_discarded_minutes='',tester_reported_fallback_rate_pct=0.0,status='NO_DISCARD_WARNING_OBSERVED',primary_treatment='PRIMARY_ELIGIBLE_IF_OTHER_GATES_PASS',evidence='new Step15E tester journal'))
    pd.DataFrame(rows).to_csv(RUN/'tick_quality.csv',index=False)

def main():
    ap=argparse.ArgumentParser();ap.parse_args();OUT.mkdir(parents=True,exist_ok=True);journal_evidence()
    ep=pd.read_csv(RUN/'medium_horizon_episode_summary.csv',low_memory=False);resp=pd.read_csv(RUN/'medium_horizon_response.csv',low_memory=False);entry=pd.read_csv(RUN/'medium_horizon_entry_comparison.csv',low_memory=False)
    ep['server_time']=pd.to_datetime(ep.anchor_msc,unit='ms',utc=True);ep['server_day']=ep.server_time.dt.strftime('%Y-%m-%d');ep['server_hour']=ep.server_time.dt.hour
    def session(h):
        if 13<=h<17:return 'SERVER_HOUR_OVERLAP'
        if 0<=h<9:return 'SERVER_HOUR_TOKYO'
        if 8<=h<17:return 'SERVER_HOUR_LONDON'
        if 17<=h<22:return 'SERVER_HOUR_NEW_YORK'
        return 'SERVER_HOUR_OTHER'
    ep['session']=ep.server_hour.map(session);ep['fallback_interval_mappable']=ep.symbol.ne('GBPUSD');ep['primary_episode']=ep.validation_status.eq('VALID')&ep.episode_status.eq('COMPLETE_900S')&ep.pre_vol_status.eq('AVAILABLE')&ep.fallback_interval_mappable
    ep['fold']=pd.qcut(ep.anchor_msc.rank(method='first'),5,labels=False)
    write(ep,'episode_summary.csv')
    merged=resp.merge(ep[['episode_id','sr_clean_001','sr_rev_001','server_day','server_hour','session','fold','primary_episode','anchor_ask','anchor_bid','repeat_count']],on='episode_id',how='left')
    merged['shock_exec_move']=np.where(merged.shock_direction.eq('LONG'),merged.long_spread_only_move,merged.short_spread_only_move);merged['anchor_spread']=merged.anchor_ask-merged.anchor_bid;merged['shock_exec_spread_multiple']=merged.shock_exec_move/merged.anchor_spread.replace(0,np.nan)
    merged['primary_row']=merged.primary_episode.fillna(False)&merged.primary_inference.eq('ELIGIBLE')&merged.availability.eq('AVAILABLE')
    stats=[]
    for cohort in COHORTS:
        for horizon in HORIZONS:
            g=merged[cohort_mask(merged,cohort)&merged.checkpoint_seconds.eq(horizon)&merged.primary_row]
            lo,hi=ci_days(g,'shock_exec_spread_multiple',20260830+horizon)
            vals=g.shock_exec_spread_multiple.dropna();stats.append(dict(cohort=cohort,horizon_seconds=horizon,episodes=len(g),market_clusters=g.market_cluster_id.nunique(),server_days=g.server_day.nunique(),mean_signed_log_return=g.signed_log_return.mean(),median_signed_log_return=g.signed_log_return.median(),prob_positive_mid=(g.signed_log_return>0).mean(),q25_signed_log_return=g.signed_log_return.quantile(.25),q75_signed_log_return=g.signed_log_return.quantile(.75),mean_shock_exec_spread_multiple=vals.mean(),median_shock_exec_spread_multiple=vals.median(),prob_positive_exec=(vals>0).mean(),exec_ci_low=lo,exec_ci_high=hi,p_raw=one_sided_p(vals)))
    hs=pd.DataFrame(stats);hs['p_holm']=holm(hs.p_raw.to_numpy());write(hs,'horizon_response.csv')
    folds=[]
    for cohort in COHORTS:
        for horizon in HORIZONS:
            for fold in range(5):
                g=merged[cohort_mask(merged,cohort)&merged.checkpoint_seconds.eq(horizon)&merged.primary_row&merged.fold.eq(fold)]
                folds.append(dict(cohort=cohort,horizon_seconds=horizon,fold=fold,episodes=len(g),market_clusters=g.market_cluster_id.nunique(),mean_exec_spread_multiple=g.shock_exec_spread_multiple.mean(),prob_positive=(g.shock_exec_spread_multiple>0).mean()))
    fold=pd.DataFrame(folds);write(fold,'fold_stability.csv')
    symbol=[]
    for cohort in COHORTS:
        for (sym,sess,h),g in merged[cohort_mask(merged,cohort)&merged.primary_row].groupby(['symbol','session','checkpoint_seconds']):symbol.append(dict(cohort=cohort,symbol=sym,session=sess,horizon_seconds=h,episodes=len(g),mean_exec_spread_multiple=g.shock_exec_spread_multiple.mean(),prob_positive=(g.shock_exec_spread_multiple>0).mean()))
    write(pd.DataFrame(symbol),'symbol_session_results.csv')
    repeat=merged.copy();repeat['repeat_bucket']=pd.cut(repeat.repeat_count,[-1,0,1,3,np.inf],labels=['0','1','2-3','4+'])
    rep=[]
    for (bucket,h),g in repeat[repeat.primary_row].groupby(['repeat_bucket','checkpoint_seconds'],observed=True):rep.append(dict(repeat_bucket=bucket,horizon_seconds=h,episodes=len(g),mean_exec_spread_multiple=g.shock_exec_spread_multiple.mean(),prob_positive=(g.shock_exec_spread_multiple>0).mean()))
    write(pd.DataFrame(rep),'repeat_shock_analysis.csv')
    # Wide entry records: retain actual Bid/Ask and 1.25x-spread columns.
    entry=entry.merge(ep[['episode_id','shock_direction','sr_clean_001','sr_rev_001','primary_episode','server_day','fold']],on='episode_id',how='left');entry=entry[entry.primary_episode.fillna(False)&entry.entry_status.eq('ENTERED')]
    erows=[]
    for cohort in COHORTS:
        cg=entry[cohort_mask(entry,cohort)]
        grouped=list(cg.groupby(['entry_clock','direction']))
        grouped.extend(((clock,'SHOCK_DIRECTION'),g[g.direction.eq(g.shock_direction)]) for clock,g in cg.groupby('entry_clock'))
        for (clock,direction),g in grouped:
            for h in HORIZONS:
                col=f'h{h}_spread_only';stress=f'h{h}_spread_125x';gross=f'h{h}_gross_mid'
                if col not in g:continue
                x=g[[col,stress,gross]].dropna()
                erows.append(dict(cohort=cohort,entry_clock=clock,direction=direction,exit_horizon_seconds=h,episodes=len(x),gross_mid_mean=x[gross].mean(),spread_only_mean=x[col].mean(),spread_125x_mean=x[stress].mean(),prob_positive_spread_only=(x[col]>0).mean(),break_even_additional_cost_mean=x[col].clip(lower=0).mean(),formal_net_status='UNAVAILABLE_COMMISSION_SLIPPAGE_INCOMPLETE'))
    et=pd.DataFrame(erows);write(et,'entry_time_comparison.csv');write(et.copy(),'cost_headroom.csv')
    controls=pd.DataFrame([dict(cohort=c,horizon_seconds=h,status='NOT_ESTIMABLE',matched_controls=0,coverage=0.0,reuse_rate='',reason='NO_CAUSALLY_RECORDED_15M_CONTROL_PATH;SHORT_HORIZON_CONTROLS_NOT_REPURPOSED') for c in COHORTS for h in HORIZONS]);write(controls,'matched_control_results.csv')
    loso=[]
    for cohort in COHORTS:
        for h in HORIZONS:
            base=merged[cohort_mask(merged,cohort)&merged.primary_row&merged.checkpoint_seconds.eq(h)]
            for sym in sorted(ep.symbol.unique()):
                g=base[base.symbol.ne(sym)];loso.append(dict(cohort=cohort,horizon_seconds=h,omitted_symbol=sym,episodes=len(g),mean_exec_spread_multiple=g.shock_exec_spread_multiple.mean(),sign_positive=bool(g.shock_exec_spread_multiple.mean()>0) if len(g) else False))
    loso=pd.DataFrame(loso);write(loso,'leave_one_symbol_out.csv')
    lodo=[]
    for cohort in COHORTS:
        for h in HORIZONS:
            base=merged[cohort_mask(merged,cohort)&merged.primary_row&merged.checkpoint_seconds.eq(h)]
            for day in sorted(base.server_day.unique()):
                g=base[base.server_day.ne(day)];lodo.append(dict(cohort=cohort,horizon_seconds=h,omitted_server_day=day,episodes=len(g),mean_exec_spread_multiple=g.shock_exec_spread_multiple.mean()))
    write(pd.DataFrame(lodo),'leave_one_day_out.csv')
    write(hs[['cohort','horizon_seconds','episodes','p_raw','p_holm']].assign(method='HOLM_FWER_PRIMARY_0.05'),'multiple_testing_results.csv')
    # Step 15D regression by causal event key and path multiset.
    now=pd.read_csv(RUN/'detector_features.csv',low_memory=False);old=pd.read_csv(BASE/'detector_features.csv',low_memory=False);key=['symbol','direction','candidate_time_msc','confirmed_time_msc','trigger_horizon_ms','market_cluster_id'];nk=Counter(map(tuple,now[key].astype(str).to_numpy()));ok=Counter(map(tuple,old[key].astype(str).to_numpy()));
    pc_now=pd.read_csv(RUN/'path_class_labels.csv');pc_old=pd.read_csv(BASE/'path_class_labels.csv');pk=['symbol','shock_direction','market_cluster_id','primary_path_class'];pn=Counter(map(tuple,pc_now[pk].astype(str).to_numpy()));po=Counter(map(tuple,pc_old[pk].astype(str).to_numpy()))
    fn=pd.read_csv(RUN/'strategy_funnel.csv',low_memory=False);fo=pd.read_csv(BASE/'strategy_funnel.csv',low_memory=False);fcols=[c for c in fn.columns if c!='event_id'];fnc=Counter(map(tuple,fn[fcols].astype(str).to_numpy()));foc=Counter(map(tuple,fo[fcols].astype(str).to_numpy()))
    compare=pd.DataFrame([dict(component='detector_event_identity',baseline_rows=len(old),step15e_rows=len(now),missing_rows=sum((ok-nk).values()),extra_rows=sum((nk-ok).values()),mismatches=sum((ok-nk).values())+sum((nk-ok).values()),status='PASS' if nk==ok else 'FAIL'),dict(component='step15d_path_identity',baseline_rows=len(pc_old),step15e_rows=len(pc_now),missing_rows=sum((po-pn).values()),extra_rows=sum((pn-po).values()),mismatches=sum((po-pn).values())+sum((pn-po).values()),status='PASS' if pn==po else 'FAIL'),dict(component='strategy_funnel_identity',baseline_rows=len(fo),step15e_rows=len(fn),missing_rows=sum((foc-fnc).values()),extra_rows=sum((fnc-foc).values()),mismatches=sum((foc-fnc).values())+sum((fnc-foc).values()),status='PASS' if fnc==foc else 'FAIL'),dict(component='market_clusters',baseline_rows=old.market_cluster_id.nunique(),step15e_rows=now.market_cluster_id.nunique(),missing_rows=0,extra_rows=0,mismatches=abs(old.market_cluster_id.nunique()-now.market_cluster_id.nunique()),status='PASS' if old.market_cluster_id.nunique()==now.market_cluster_id.nunique() else 'FAIL')]);write(compare,'step15d_behavior_comparison.csv')
    oldset=parse_set(BASE/'persistent.set');newset=parse_set(RUN/'persistent_medium_horizon.set');ignored={'InpRunId','InpLogFolder','InpSourceCommit','InpEx5Hash','InpSchemaVersion'};diff=[]
    for k in sorted(set(oldset)|set(newset)):
        if k in ignored:continue
        if oldset.get(k)!=newset.get(k):diff.append(dict(parameter=k,baseline=oldset.get(k,''),step15e=newset.get(k,''),status='FAIL'))
    write(pd.DataFrame(diff,columns=['parameter','baseline','step15e','status']),'parameter_diff.csv')
    # Candidate gate: preregistered robustness and spread-headroom conditions.
    candidates=[]
    for _,r in hs[hs.cohort.ne('ALL')&hs.horizon_seconds.ge(30)].iterrows():
        f=fold[(fold.cohort==r.cohort)&(fold.horizon_seconds==r.horizon_seconds)];l=loso[(loso.cohort==r.cohort)&(loso.horizon_seconds==r.horizon_seconds)]
        stress=et[(et.cohort==r.cohort)&(et.entry_clock=='CONFIRMED')&(et.direction=='SHOCK_DIRECTION')&(et.exit_horizon_seconds==r.horizon_seconds)]
        stress_pass=len(stress)==1 and int(stress.iloc[0].episodes)>=200 and float(stress.iloc[0].spread_125x_mean)>0
        eligible=r.episodes>=200 and r.exec_ci_low>0 and r.p_holm<.05 and len(f)==5 and (f.mean_exec_spread_multiple>0).all() and len(l)>0 and (l.mean_exec_spread_multiple>0).all() and stress_pass
        if eligible:candidates.append(dict(candidate_id=f'TS15E-MH-{len(candidates)+1:03d}',cohort=r.cohort,direction='SHOCK_DIRECTION',entry_clock='CONFIRMED_NEXT_REAL_QUOTE',exit_seconds=int(r.horizon_seconds),sl='NONE_FIXED_TIME_STUDY',tp='NONE_FIXED_TIME_STUDY',rr='NOT_APPLICABLE_NO_BARRIER',max_hold_seconds=int(r.horizon_seconds),cost='ACTUAL_BID_ASK_SPREAD_ONLY;FORMAL_NET_UNAVAILABLE',no_trade='STALE_OR_MISSING_OR_FALLBACK_OR_PREVOL_UNAVAILABLE',development_period='2025-03-01_TO_2025-04-01',status='DEVELOPMENT_DERIVED_NOT_VALIDATED'))
        if len(candidates)>=3:break
    cand=pd.DataFrame(candidates,columns=['candidate_id','cohort','direction','entry_clock','exit_seconds','sl','tp','rr','max_hold_seconds','cost','no_trade','development_period','status']);write(cand,'candidate_registry.csv')
    summary=dict(events=len(now),market_clusters=int(now.market_cluster_id.nunique()),episodes=len(ep),completed=int((ep.episode_status=='COMPLETE_900S').sum()),purged=int((ep.episode_status=='PURGED_END_OF_DATA').sum()),primary_episodes=int(ep.primary_episode.sum()),fallback_excluded_episodes=int((ep.symbol=='GBPUSD').sum()),duplicate_episode_ids=int(len(ep)-ep.episode_id.nunique()),response_rows=len(resp),entry_rows=len(entry),behavior_mismatches=int(compare.mismatches.sum()),parameter_differences=len(diff),candidate_count=len(cand),matched_control_status='NOT_ESTIMABLE',orders=max(0,sum(1 for _ in open(RUN/'trades.csv',encoding='utf-8-sig'))-1),formal_net='UNAVAILABLE',server_timezone='BROKER_SERVER_TIME;UTC_OFFSET_AND_DST_NOT_INJECTED')
    (OUT/'analysis_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    print(json.dumps(summary))
if __name__=='__main__':main()
