#!/usr/bin/env python3
"""Preregistered Step 15H development analysis; March 2025 is not OOS."""
from __future__ import annotations
import hashlib, json, math
from pathlib import Path
import numpy as np
import pandas as pd
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeClassifier

ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'reports/backtest/runs/20260902_ts15h_detection_time_continuation_r1_202503'
OUT=ROOT/'reports/analysis/tick_shock/step15h'
SHARE=ROOT/'reports/share/tick_shock/step15h'
SEED=1502; PURGE_MS=900250; BOOT=2000
FEATURES=['spread_atr5','tick_activity_ratio','pre_return_5m_dir_atr','m5_ema20_slope_dir_atr','m15_alignment_dir','pre_extension_15m_dir_atr','day_range_position_dir','detection_efficiency','severity','confirmation_retention','spread_efficiency_interaction','flow_efficiency_interaction']
SETS={'LIQUIDITY_ONLY':FEATURES[0:2],'PRE_CONTEXT':FEATURES[2:7],'DETECTION_SHAPE':FEATURES[7:10],'COMBINED':FEATURES}
THRESHOLDS=[.35,.45,.50,.55,.65]

def write(df,path):path.parent.mkdir(parents=True,exist_ok=True);df.to_csv(path,index=False)
def sha(path):
    h=hashlib.sha256();
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1<<20),b''):h.update(b)
    return h.hexdigest().upper()
def ci_cluster(df,col):
    if df.empty:return (math.nan,math.nan)
    groups={k:g[col].to_numpy() for k,g in df.groupby('market_cluster_id')};keys=np.array(list(groups));rng=np.random.default_rng(SEED);v=[]
    for _ in range(BOOT):
        chosen=rng.choice(keys,len(keys),replace=True);v.append(np.concatenate([groups[k] for k in chosen]).sum()/len(df))
    return tuple(np.quantile(v,[.025,.975]))

def load():
    s=pd.read_csv(RUN/'detection_time_snapshots.csv',low_memory=False);p=pd.read_csv(RUN/'detection_time_first_touch.csv',low_memory=False)
    q=p[(p.requested_delay_ms==0)&(p.horizon_seconds==900)].copy();d=s.merge(q,on=['episode_id','event_id','market_cluster_id','symbol','shock_direction','t0_msc'],validate='one_to_one',suffixes=('','_path'))
    clock=pd.to_datetime(d.t0_msc,unit='ms',utc=True);d['server_day']=clock.dt.strftime('%Y-%m-%d');d['server_hour']=clock.dt.hour
    def session(hour):
        active=sum((0<=hour<9,8<=hour<17,13<=hour<22))
        if active>1:return 'OVERLAP'
        if 0<=hour<9:return 'TOKYO'
        if 8<=hour<17:return 'LONDON'
        if 13<=hour<22:return 'NEW_YORK'
        return 'OTHER'
    d['session']=d.server_hour.map(session);d['valid_path']=d.result.isin(['TP_FIRST','SL_FIRST','TIMEOUT'])
    d['primary_eligible']=d.symbol.ne('GBPUSD')&d.feature_status.eq('AVAILABLE')&d.valid_path&d.fallback_status.eq('CLEAN')
    d['target']=(d.c2_r>0).astype(int);d=d.replace([np.inf,-np.inf],np.nan)
    return s,p,d

def folds(d):
    base=d[d.primary_eligible][['market_cluster_id','t0_msc']].drop_duplicates('market_cluster_id').sort_values('t0_msc');chunks=np.array_split(base.market_cluster_id.to_numpy(),6);rows=[]
    for fold in range(5):
        test=set(chunks[fold+1].tolist());start=int(base[base.market_cluster_id.isin(test)].t0_msc.min());rows.append((fold,test,start))
    return rows

def make_model(kind,param):
    if kind=='LOGISTIC':return Pipeline([('impute',SimpleImputer(strategy='median')),('scale',StandardScaler()),('model',LogisticRegression(C=param,solver='liblinear',random_state=SEED,max_iter=2000))])
    depth,leaf=param;return Pipeline([('impute',SimpleImputer(strategy='median')),('model',DecisionTreeClassifier(max_depth=depth,min_samples_leaf=leaf,random_state=SEED))])

def fit_oof(d,fold_specs):
    pop=d[d.primary_eligible].copy();pred=[];sel=[]
    params={'LOGISTIC':[.1,1.,10.], 'TREE':[(1,100),(2,100),(2,200)]}
    for policy,features in SETS.items():
      for kind in ('LOGISTIC','TREE'):
       for fold,test_ids,start in fold_specs:
        train=pop[(pop.t0_msc<start-PURGE_MS)&(~pop.market_cluster_id.isin(test_ids))].sort_values('t0_msc');test=pop[pop.market_cluster_id.isin(test_ids)].copy()
        cut=int(len(train)*.8);fit=train.iloc[:cut];val=train.iloc[cut:]
        best=(-1e99,None,None)
        for param in params[kind]:
          if len(fit)<50 or fit.target.nunique()<2:continue
          model=make_model(kind,param);model.fit(fit[features],fit.target);pv=model.predict_proba(val[features])[:,1]
          for threshold in THRESHOLDS:
            chosen=pv>=threshold;value=float(val.loc[chosen,'c2_r'].sum()/len(val)) if len(val) else -1e99
            if value>best[0]:best=(value,param,threshold)
        if best[1] is None:continue
        model=make_model(kind,best[1]);model.fit(train[features],train.target);prob=model.predict_proba(test[features])[:,1];chosen=prob>=best[2]
        sel.append(dict(policy=policy,model=kind,fold=fold,train_rows=len(train),test_rows=len(test),selected=int(chosen.sum()),hyperparameter=str(best[1]),threshold=best[2],inner_policy_value=best[0],purge_ms=PURGE_MS))
        for i,(_,r) in enumerate(test.iterrows()):pred.append(dict(episode_id=r.episode_id,market_cluster_id=r.market_cluster_id,symbol=r.symbol,server_day=r.server_day,fold=fold,policy=policy,model=kind,probability=prob[i],threshold=best[2],selected=bool(chosen[i]),result=r.result,c0_r=r.c0_r,c2_r=r.c2_r,target=r.target))
    return pd.DataFrame(pred),pd.DataFrame(sel)

def comparisons(d,oof):
    pop=d[d.primary_eligible].copy();rows=[]
    for name,selected in [('NO_TRADE',np.zeros(len(pop),dtype=bool)),('UNFILTERED',np.ones(len(pop),dtype=bool))]:
        x=pop.assign(selected=selected);lo,hi=ci_cluster(x.assign(value=np.where(selected,x.c2_r,0.0)),'value');rows.append(dict(policy=name,model='FIXED',eligible=len(x),selected=int(selected.sum()),coverage=float(selected.mean()),c0_policy_value=float(np.where(selected,x.c0_r,0).sum()/len(x)),c2_policy_value=float(np.where(selected,x.c2_r,0).sum()/len(x)),c2_ci_low=lo,c2_ci_high=hi,positive_folds=np.nan,total_folds=5,status='BASELINE'))
    for (policy,model),g in oof.groupby(['policy','model']):
        g=g.copy();g['value']=np.where(g.selected,g.c2_r,0.0);lo,hi=ci_cluster(g,'value');foldv=g.groupby('fold').apply(lambda x:np.where(x.selected,x.c2_r,0.0).sum()/len(x),include_groups=False)
        rows.append(dict(policy=policy,model=model,eligible=len(g),selected=int(g.selected.sum()),coverage=float(g.selected.mean()),c0_policy_value=float(np.where(g.selected,g.c0_r,0).sum()/len(g)),c2_policy_value=float(g.value.sum()/len(g)),c2_ci_low=lo,c2_ci_high=hi,positive_folds=int((foldv>0).sum()),total_folds=len(foldv),status='EVALUATED'))
    out=pd.DataFrame(rows);models=out.model.ne('FIXED');order=out.loc[models].c2_ci_low.sort_values(ascending=False).index.tolist();m=len(order);out['holm_rank']=np.nan;out['holm_alpha']=np.nan
    for rank,idx in enumerate(order,1):out.loc[idx,['holm_rank','holm_alpha']]=[rank,.05/(m-rank+1)]
    out['candidate_gate']=False;out['candidate_reason']='INSUFFICIENT_SUPPORT_OR_NONPOSITIVE_STRESS_CI'
    return out

def main():
    OUT.mkdir(parents=True,exist_ok=True);SHARE.mkdir(parents=True,exist_ok=True);s,p,d=load();fs=folds(d);oof,tuning=fit_oof(d,fs);comp=comparisons(d,oof)
    write(pd.DataFrame([dict(fold=f,clusters=len(ids),test_start_msc=start,purge_cutoff_msc=start-PURGE_MS) for f,ids,start in fs]),OUT/'fold_definitions.csv');write(tuning,OUT/'model_selection.csv');write(oof,OUT/'oof_predictions.csv');write(comp,OUT/'filter_policy_comparison.csv')
    availability=[]
    for f in FEATURES:availability.append(dict(feature=f,available=int(s[f'{f}_available'].astype(str).str.lower().eq('true').sum()),missing=int((~s[f'{f}_available'].astype(str).str.lower().eq('true')).sum()),future_source_reads=int((s[f'{f}_source_msc'].fillna(0)>s.t0_msc).sum())))
    write(pd.DataFrame(availability),OUT/'feature_availability.csv')
    write(d.groupby(['symbol','shock_direction','feature_status','result'],dropna=False).size().reset_index(name='episodes'),OUT/'episode_distribution.csv')
    write(d.groupby(['symbol','session','feature_status','result'],dropna=False).size().reset_index(name='episodes'),OUT/'symbol_session_outcome.csv')
    missing=[]
    for symbol,g in s.groupby('symbol'):
        for f in FEATURES:missing.append(dict(symbol=symbol,feature=f,rows=len(g),missing=int((~g[f'{f}_available'].astype(str).str.lower().eq('true')).sum())))
    write(pd.DataFrame(missing),OUT/'feature_missingness_by_symbol.csv')
    td=p.assign(entry_delay_ms=p.entry_quote_msc-p.t0_msc).groupby(['requested_delay_ms','horizon_seconds','result'],dropna=False).agg(rows=('episode_id','size'),median_entry_delay_ms=('entry_delay_ms','median'),mean_c0_r=('c0_r','mean'),mean_c2_r=('c2_r','mean')).reset_index();write(td,OUT/'timing_and_outcome.csv')
    primary=d[d.primary_eligible].copy();fold_map={cluster:fold for fold,ids,_ in fs for cluster in ids};primary['fold']=primary.market_cluster_id.map(fold_map).fillna(-1).astype(int);primary['selected_policy']='NO_TRADE';primary['policy_action']='NO_TRADE';primary['policy_r']=0.0;primary['counterfactual_taken_c0_r']=primary.c0_r;primary['counterfactual_taken_c2_r']=primary.c2_r;primary['avoided_loss_r']=np.maximum(0.0,-primary.c2_r);primary['rejected_profit_r']=np.maximum(0.0,primary.c2_r)
    compact_cols=['episode_id','event_id','market_cluster_id','symbol','shock_direction','candidate_msc','confirmed_msc','confirmed_quote_msc','processed_msc','t0_msc','t0_sequence','quote_age_ms','result','c0_r','c2_r','risk_distance','realized_rr','primary_eligible','server_day','server_hour','session','fold','selected_policy','policy_action','policy_r','counterfactual_taken_c0_r','counterfactual_taken_c2_r','avoided_loss_r','rejected_profit_r']+FEATURES
    write(primary[compact_cols],SHARE/'step15h_detection_time_episodes_compact.csv');write(comp,SHARE/'step15h_filter_policy_comparison.csv')
    checks=[('snapshots_equal_episodes',len(s),3151),('path_rows',len(p),len(s)*9),('duplicate_snapshot',int(s.duplicated('episode_id').sum()),0),('duplicate_paths',int(p.duplicated(['episode_id','requested_delay_ms','horizon_seconds']).sum()),0),('entry_before_processing',int((p.entry_quote_msc.notna()&(p.entry_quote_msc<p.signal_processing_msc)).sum()),0),('entry_not_after_signal_quote',int((p.entry_quote_msc.notna()&(p.entry_quote_msc<=p.signal_quote_msc)).sum()),0),('rr_below_1_2',int((p.realized_rr.notna()&(p.realized_rr<1.2-1e-9)).sum()),0),('future_feature_reads',sum(x['future_source_reads'] for x in availability),0),('trade_rows',max(0,sum(1 for _ in (RUN/'trades.csv').open(encoding='utf-8-sig'))-1),0)]
    qa=pd.DataFrame([dict(check=k,actual=a,expected=e,status='PASS' if a==e else 'FAIL') for k,a,e in checks]);write(qa,OUT/'qa_checks.csv')
    def read_set(path):
        return dict(line.split('=',1) for line in path.read_text(encoding='utf-8-sig').splitlines() if '=' in line)
    prior=read_set(ROOT/'reports/backtest/runs/20260901_ts15g_economic_path_r3_202503/economic_path.set');current=read_set(RUN/'detection_time_continuation.set');ignored={'InpRunId','InpLogFolder','InpSourceCommit','InpEx5Hash','InpSchemaVersion'}
    diffs=[dict(parameter=k,step15g=prior.get(k,''),step15h=current.get(k,''),status='FAIL') for k in sorted(set(prior)|set(current)) if k not in ignored and prior.get(k)!=current.get(k)]
    write(pd.DataFrame(diffs,columns=['parameter','step15g','step15h','status']),ROOT/'reports/refactor/tick_shock/step15h_parameter_diff.csv')
    decision='NO_DETECTION_TIME_CONTINUATION_FILTER_SUPPORTED';support=len(primary)>=2500 and primary.market_cluster_id.nunique()>=2000
    if support and bool((comp.candidate_gate==True).any()):decision='DETECTION_TIME_CONTINUATION_FILTER_HYPOTHESIS_FROZEN_FOR_FUTURE_VALIDATION'
    registry=pd.DataFrame([dict(candidate_id='NONE' if decision.startswith('NO_') else 'TS15H-CANDIDATE-001',decision=decision,eligible_episodes=len(primary),market_clusters=primary.market_cluster_id.nunique(),support_gate=support,cost_status='COST_MODEL_INCOMPLETE',formal_net_expectancy='UNAVAILABLE',edge='EDGE_UNDETERMINED',production='PRODUCTION_NOT_ELIGIBLE')]);write(registry,OUT/'candidate_registry.csv')
    (SHARE/'step15h_data_dictionary.md').write_text('# Step 15H compact data dictionary\n\n- One row in `step15h_detection_time_episodes_compact.csv` is one causal 15-minute episode representative.\n- `t0_msc` is the processing clock at which persistent confirmation was usable.\n- `c0_r` uses observed Bid/Ask; `c2_r` uses 1.25x spread and one tick adverse entry and exit stress.\n- `primary_eligible` excludes GBPUSD, unavailable causal features, fallback paths and invalid outcomes.\n- March 2025 is reused development data, not OOS.\n- `step15h_filter_policy_comparison.csv` reports policy value as selected return sum divided by all eligible episodes.\n',encoding='utf-8')
    summary={'snapshots':len(s),'paths':len(p),'primary_eligible':len(primary),'market_clusters':int(primary.market_cluster_id.nunique()),'support_gate':support,'decision':decision,'qa_failures':int(qa.status.ne('PASS').sum()),'order_rows':checks[-1][1]};(OUT/'analysis_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    hashes=[]
    for path in sorted(SHARE.glob('*')):hashes.append(dict(path=path.relative_to(ROOT).as_posix(),bytes=path.stat().st_size,sha256=sha(path)))
    write(pd.DataFrame(hashes),SHARE/'step15h_share_hashes.csv')
    print(json.dumps(summary))
if __name__=='__main__':main()
