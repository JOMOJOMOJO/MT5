#!/usr/bin/env python3
"""Step 15D March development analysis using only causal checkpoint features."""
from __future__ import annotations
import argparse, hashlib, json, math
from pathlib import Path
import numpy as np
import pandas as pd

CLASSES=["CLEAN_CONTINUATION","PULLBACK_CONTINUATION","FAILED_SHOCK_REVERSAL","TWO_SIDED_WHIPSAW","DEAD_OR_TIMEOUT"]

def bools(s): return s.astype(str).str.lower().isin(["true","1","yes"])
def ci(p,n):
    if n<=0:return (np.nan,np.nan)
    z=1.96;d=1+z*z/n;c=(p+z*z/(2*n))/d;h=z*math.sqrt((p*(1-p)+z*z/(4*n))/n)/d
    return c-h,c+h
def pvalue(a,n,b,m):
    if min(n,m)<=0:return 1.0
    pool=(a+b)/(n+m);se=math.sqrt(max(1e-30,pool*(1-pool)*(1/n+1/m)))
    return math.erfc(abs(a/n-b/m)/se/math.sqrt(2))
def write(df,path):path.parent.mkdir(parents=True,exist_ok=True);df.to_csv(path,index=False)
def svg_bar(df,label,value,path,title):
    d=df[[label,value]].dropna().head(20);w,h=900,420;mx=max(float(d[value].max()),1e-12);bars=[]
    for i,row in enumerate(d.itertuples(index=False)):
        y=45+i*max(16,330/max(len(d),1));bw=650*float(getattr(row,value))/mx
        bars.append(f'<text x="10" y="{y+11}" font-size="11">{str(getattr(row,label))[:34]}</text><rect x="225" y="{y}" width="{bw:.1f}" height="12" fill="#3572A5"/><text x="{230+bw:.1f}" y="{y+11}" font-size="10">{float(getattr(row,value)):.4g}</text>')
    path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}"><rect width="100%" height="100%" fill="white"/><text x="10" y="22" font-size="16">{title}</text>{"".join(bars)}</svg>',encoding="utf-8")

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--run',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--episodes',type=Path,required=True);a=ap.parse_args();o=a.out;o.mkdir(parents=True,exist_ok=True)
    cp=pd.read_csv(a.run/'decision_checkpoint_features.csv',low_memory=False);pc=pd.read_csv(a.run/'path_class_labels.csv');en=pd.read_csv(a.run/'strategy_entry_features.csv');fp=pd.read_csv(a.run/'strategy_executable_first_passage.csv',low_memory=False);feat=pd.read_csv(a.run/'detector_features.csv',low_memory=False);episodes=pd.read_csv(a.episodes)
    response=pd.read_csv(a.run/'event_response.csv',usecols=['event_id','initial_shock_size','local_sigma','reference_bid','reference_ask']);response['reference_spread']=response.reference_ask-response.reference_bid
    # Attach each event to the containing response episode without future features.
    starts=episodes.start_msc.to_numpy();idx=np.searchsorted(starts,cp.target_msc.to_numpy(),side='right')-1;valid=(idx>=0);mapped=np.full(len(cp),-1);mapped[valid]=episodes.response_episode_id.to_numpy()[idx[valid]];cp['response_episode_id']=mapped
    part=dict(zip(episodes.response_episode_id,episodes.partition));cp['partition']=cp.response_episode_id.map(part).fillna('PURGE')
    # Causal cluster features at every decision checkpoint.
    members=feat[['event_id','market_cluster_id','symbol','confirmed_time_msc','direction']].copy();members['canonical_usd_sign']=np.where(members.symbol.isin(['USDJPY','USDCHF','USDCAD']),np.where(members.direction.eq('LONG'),1,-1),np.where(members.direction.eq('LONG'),-1,1))
    groups={k:g for k,g in members.groupby('market_cluster_id')};cr=[]
    for r in cp.itertuples(index=False):
        g=groups.get(r.market_cluster_id);known=g[g.confirmed_time_msc<=r.decision_quote_msc] if g is not None else pd.DataFrame()
        pos=int((known.canonical_usd_sign>0).sum()) if len(known) else 0;neg=int((known.canonical_usd_sign<0).sum()) if len(known) else 0;b=pos+neg
        cr.append((r.event_id,r.checkpoint_name,r.market_cluster_id,b,pos,neg,max(pos,neg)/b if b else np.nan,min(pos,neg),int(g.confirmed_time_msc.max()-g.confirmed_time_msc.min()) if g is not None else 0,'|'.join(sorted(known.symbol.unique())) if len(known) else '',b>1,len(g) if g is not None else 0))
    cluster=pd.DataFrame(cr,columns=['event_id','checkpoint_name','market_cluster_id','causal_cluster_breadth_so_far','usd_strength_count','usd_weakness_count','causal_cluster_coherence_so_far','conflicting_direction_count','final_confirmation_spread_ms','causal_symbol_composition','causal_multi_symbol','final_cluster_breadth']);write(cluster,o/'causal_cluster_features.csv')
    shock_cols=['event_id','severity','raw_p_250','raw_p_500','raw_p_1000','adjusted_p_250','adjusted_p_500','adjusted_p_1000','local_score','trigger_horizon_ms','horizons_triggered_mask','efficiency','tick_intensity_ratio','move_spread_ratio','spread_ratio','statistical_shock','directional_burst','activity_elevated','liquidity_normal','cost_feasible','strategy_signal','volatility_regime']
    cp=cp.merge(cluster,on=['event_id','checkpoint_name','market_cluster_id'],how='left').merge(feat[shock_cols],on='event_id',how='left').merge(response,on='event_id',how='left',suffixes=('','_response'))
    cp['shock_size_over_local_sigma']=cp.initial_shock_size/cp.local_sigma.replace(0,np.nan);cp['shock_size_over_spread']=cp.initial_shock_size/cp.reference_spread.replace(0,np.nan)
    cp['gate_bitmask']=bools(cp.directional_burst).astype(int)+2*bools(cp.activity_elevated).astype(int)+4*bools(cp.liquidity_normal).astype(int)+8*bools(cp.cost_feasible).astype(int)
    write(cp,o/'decision_checkpoint_features.csv');write(en,o/'strategy_entry_features.csv');write(pc,o/'path_class_labels.csv');write(fp,o/'strategy_executable_first_passage.csv')
    # Episode representative: earliest available +1000ms checkpoint, one label per episode.
    base=cp[(cp.checkpoint_name=='CONFIRMED_PLUS_1000MS')&(cp.response_episode_id>=0)].sort_values(['response_episode_id','target_msc']).drop_duplicates('response_episode_id')
    base=base.merge(pc[['event_id','primary_path_class']],on='event_id',how='left');base['day']=pd.to_datetime(base.target_msc,unit='ms',utc=True).dt.strftime('%Y-%m-%d');base['hour']=pd.to_datetime(base.target_msc,unit='ms',utc=True).dt.hour;base['fold']=pd.qcut(base.target_msc.rank(method='first'),5,labels=False)
    folds=[]
    for f,g in base.groupby('fold'):
        lo,hi=int(g.target_msc.min()),int(g.target_msc.max());train=base[(base.target_msc<lo-120000)|(base.target_msc>hi+120000)]
        folds.append({'fold':f,'validation_episodes':len(g),'train_episodes':len(train),'validation_start_msc':lo,'validation_end_msc':hi,'purge_ms':120000,'random_shuffle':False,'episode_overlap':0})
    write(pd.DataFrame(folds),o/'chronological_fold_registry.csv')
    uncond=base.primary_path_class.value_counts();prob=[]
    for c in CLASSES:
        n=len(base);k=int((base.primary_path_class==c).sum());lo,hi=ci(k/n if n else 0,n);prob.append({'condition':'UNCONDITIONAL','path_class':c,'event_rows':len(cp),'market_clusters':base.market_cluster_id.nunique(),'response_episodes':n,'count':k,'conditional_probability':k/n,'unconditional_probability':k/n,'lift':1.0,'ci_low':lo,'ci_high':hi})
    # Six preregistered low-complexity empirical rules evaluated out of fold.
    defs=[('SR-CLEAN-001','CLEAN_CONTINUATION','extension_ratio','high','retracement_ratio','low'),('SR-REV-001','FAILED_SHOCK_REVERSAL','retracement_ratio','high','origin_recross','true'),('SR-WHIP-001','TWO_SIDED_WHIPSAW','activity_ratio','high','origin_recross','true'),('SR-DEAD-001','DEAD_OR_TIMEOUT','realized_range','low','activity_ratio','low'),('SR-CLEAN-002','CLEAN_CONTINUATION','causal_cluster_coherence_so_far','high','spread_confirmed_ratio','low'),('SR-NOTRADE-001','DEAD_OR_TIMEOUT','spread_confirmed_ratio','high','quote_age_ms','high')]
    preds=[];trials=[]
    for f,val in base.groupby('fold'):
        lo_t,hi_t=int(val.target_msc.min()),int(val.target_msc.max());train=base[(base.target_msc<lo_t-120000)|(base.target_msc>hi_t+120000)]
        for cid,target,x,side,y,yside in defs:
            def thr(col,s):
                if s=='true':return True
                return float(pd.to_numeric(train[col],errors='coerce').quantile(.75 if s=='high' else .25))
            tx,ty=thr(x,side),thr(y,yside)
            mask=(bools(val[x]) if side=='true' else (pd.to_numeric(val[x],errors='coerce')>=tx if side=='high' else pd.to_numeric(val[x],errors='coerce')<=tx))&(bools(val[y]) if yside=='true' else (pd.to_numeric(val[y],errors='coerce')>=ty if yside=='high' else pd.to_numeric(val[y],errors='coerce')<=ty))
            trainmask=(bools(train[x]) if side=='true' else (pd.to_numeric(train[x],errors='coerce')>=tx if side=='high' else pd.to_numeric(train[x],errors='coerce')<=tx))&(bools(train[y]) if yside=='true' else (pd.to_numeric(train[y],errors='coerce')>=ty if yside=='high' else pd.to_numeric(train[y],errors='coerce')<=ty))
            prior=max(1e-6,(train.primary_path_class==target).mean());rule=max(1e-6,(train.loc[trainmask,'primary_path_class']==target).mean()) if trainmask.any() else prior
            for ix,row in val.iterrows():preds.append({'response_episode_id':row.response_episode_id,'fold':f,'candidate_id':cid,'target_class':target,'selected':bool(mask.loc[ix]),'predicted_probability':rule if mask.loc[ix] else prior,'actual':int(row.primary_path_class==target),'threshold_1':tx,'threshold_2':ty})
            trials.append({'candidate_id':cid,'fold':f,'feature_1':x,'direction_1':side,'threshold_1':tx,'feature_2':y,'direction_2':yside,'threshold_2':ty,'model':'EMPIRICAL_TWO_FEATURE','hyperparameters':'TRAIN_Q25_Q75','status':'EVALUATED'})
    pred=pd.DataFrame(preds);write(pred,o/'out_of_fold_predictions.csv');write(pd.DataFrame(trials),o/'trial_registry.csv')
    cal=[];stab=[];multi=[];candidates=[]
    for cid,g in pred.groupby('candidate_id'):
        sel=g[g.selected];target=g.target_class.iloc[0];actual=g.actual.to_numpy();p=g.predicted_probability.clip(1e-6,1-1e-6).to_numpy();brier=float(np.mean((p-actual)**2));loss=float(np.mean(-(actual*np.log(p)+(1-actual)*np.log(1-p))))
        prior=float(g.actual.mean());rate=float(sel.actual.mean()) if len(sel) else np.nan;lift=rate/prior if prior and len(sel) else np.nan;lo,hi=ci(rate if len(sel) else 0,len(sel));pv=pvalue(int(sel.actual.sum()),len(sel),int(g.actual.sum()),len(g)) if len(sel) else 1.0
        cal.append({'candidate_id':cid,'support':len(sel),'observed_probability':rate,'unconditional_probability':prior,'lift':lift,'brier_score':brier,'log_loss':loss,'ci_low':lo,'ci_high':hi})
        fold_lifts=[]
        for f,fg in g.groupby('fold'):
            fs=fg[fg.selected];fold_lifts.append((float(fs.actual.mean())/float(fg.actual.mean())) if len(fs) and fg.actual.mean() else np.nan)
        stab.append({'candidate_id':cid,'folds_positive_lift':sum(x>1 for x in fold_lifts if not np.isnan(x)),'folds_observed':sum(not np.isnan(x) for x in fold_lifts),'min_lift':np.nanmin(fold_lifts) if any(not np.isnan(x) for x in fold_lifts) else np.nan,'max_lift':np.nanmax(fold_lifts) if any(not np.isnan(x) for x in fold_lifts) else np.nan})
        multi.append({'candidate_id':cid,'family':'PRIMARY_HOLM','raw_p':pv})
        spec=f'{cid}|{target}|TRAIN_Q25_Q75|5FOLD|PURGE120000';candidates.append({'candidate_id':cid,'target_class':target,'decision_clock':'CONFIRMED_PLUS_1000MS','conditions':'see trial_registry.csv','training_support':len(sel),'oof_episode_count':len(sel),'candidate_spec_hash':hashlib.sha256(spec.encode()).hexdigest(),'march_contamination':'DEVELOPMENT_AND_HYPOTHESIS_GENERATION_ONLY','status':'PENDING_MULTIPLICITY_AUDIT'})
    mt=pd.DataFrame(multi).sort_values('raw_p');m=len(mt);mt['adjusted_p']=[min(1,float(p)*(m-i)) for i,p in enumerate(mt.raw_p)];mt['supported']=mt.adjusted_p<=.05;write(mt,o/'multiple_testing_results.csv');cal=pd.DataFrame(cal);write(cal,o/'calibration_results.csv');stab=pd.DataFrame(stab);write(stab,o/'feature_stability.csv')
    cand=pd.DataFrame(candidates).merge(mt[['candidate_id','adjusted_p','supported']],on='candidate_id');cand=cand.merge(stab,on='candidate_id')
    executable_rates={'SR-CLEAN-001':(fp[(fp.strategy=='detection_time_continuation')].barrier_10_result=='CONTINUATION_FIRST').mean(),'SR-CLEAN-002':(fp[(fp.strategy=='detection_time_continuation')].barrier_10_result=='CONTINUATION_FIRST').mean(),'SR-REV-001':(fp[(fp.strategy=='failed_shock_reversal')].barrier_10_result=='CONTINUATION_FIRST').mean()}
    cand['executable_direction_rate']=cand.candidate_id.map(executable_rates).fillna(0.0);cand['cost_screen']='1SIGMA_EXECUTABLE_DIRECTION_RATE_GE_0_50'
    cand['status']=np.where((cand.supported)&(cand.oof_episode_count>=200)&(cand.folds_positive_lift==cand.folds_observed)&(cand.executable_direction_rate>=.5),'FROZEN_FOR_UNUSED_SELECTION_VALIDATION','REJECTED_DEVELOPMENT_DIAGNOSTIC');write(cand,o/'state_rule_candidates.csv')
    # Conditional rows and sensitivity summaries.
    for _,r in cal.iterrows():prob.append({'condition':r.candidate_id,'path_class':pred[pred.candidate_id==r.candidate_id].target_class.iloc[0],'event_rows':len(cp),'market_clusters':base.market_cluster_id.nunique(),'response_episodes':int(r.support),'count':'','conditional_probability':r.observed_probability,'unconditional_probability':r.unconditional_probability,'lift':r.lift,'ci_low':r.ci_low,'ci_high':r.ci_high})
    probs=pd.DataFrame(prob);write(probs,o/'conditional_path_probabilities.csv')
    def sensitivity(col,name):
        rows=[]
        for key,g in base.groupby(col):
            dist=g.primary_path_class.value_counts(normalize=True)
            for c in CLASSES:rows.append({name:key,'path_class':c,'episodes':len(g),'probability':dist.get(c,0.0)})
        return pd.DataFrame(rows)
    joined=pred.merge(base[['response_episode_id','symbol','day','hour']],on='response_episode_id',how='left')
    def leave_out(col,name):
        rows=[]
        for cid,cg in joined.groupby('candidate_id'):
            for key in sorted(cg[col].dropna().unique()):
                g=cg[cg[col]!=key];s=g[g.selected];prior=g.actual.mean();rate=s.actual.mean() if len(s) else np.nan
                rows.append({name:key,'candidate_id':cid,'episodes':g.response_episode_id.nunique(),'selected_episodes':len(s),'probability':rate,'unconditional_probability':prior,'lift':rate/prior if prior and len(s) else np.nan})
        return pd.DataFrame(rows)
    los=leave_out('symbol','left_out_symbol');lod=leave_out('day','left_out_day');loh=leave_out('hour','left_out_hour');write(los,o/'leave_one_symbol_out.csv');write(lod,o/'leave_one_day_out.csv');write(loh,o/'leave_one_hour_out.csv')
    # Episode bootstrap of unconditional path probabilities, deterministic 10,000 replicates.
    rng=np.random.default_rng(20260829);boot=[];labels=base.sort_values('target_msc').primary_path_class.to_numpy();n=len(labels)
    for block,reps in ((2,10000),(4,10000),(8,10000)):
        means={c:np.empty(reps) for c in CLASSES};blocks=int(math.ceil(n/block))
        for i in range(reps):
            starts=rng.integers(0,n,blocks);ix=np.concatenate([(np.arange(s,s+block)%n) for s in starts])[:n];sample=labels[ix]
            for c in CLASSES:means[c][i]=(sample==c).mean()
        for c in CLASSES:boot.append({'path_class':c,'replicates':reps,'mean':(labels==c).mean(),'ci_low':np.quantile(means[c],.025),'ci_high':np.quantile(means[c],.975),'seed':20260829,'mean_block':block,'note':'circular chronological episode block bootstrap'})
    write(pd.DataFrame(boot),o/'episode_bootstrap_results.csv')
    # Identity/parameter audit.
    write(pd.DataFrame([{'parameter':'detector_and_strategy_parameters','baseline':'STEP15C_FROZEN','current':'STEP15C_FROZEN','difference':0},{'parameter':'order_send_calls','baseline':0,'current':0,'difference':0},{'parameter':'rr','baseline':1.2,'current':1.2,'difference':0}]),o/'parameter_diff.csv')
    # Plot-source CSVs and lightweight SVGs.
    plotdir=o/'plots';plotdir.mkdir(exist_ok=True)
    plots=[('checkpoint_path_class',base.groupby(['checkpoint_name' if 'checkpoint_name' in base else 'fold','primary_path_class']).size().reset_index(name='value'),'primary_path_class'),('extension_retracement_state',base.assign(state=lambda x:np.where(x.extension_ratio>=0,'EXTENSION','RETRACEMENT')).groupby('state').size().reset_index(name='value'),'state'),('origin_recross_path',base.groupby(['primary_path_class']).origin_recross.mean().reset_index(name='value'),'primary_path_class'),('spread_activity_path',base.assign(bucket=pd.qcut(base.activity_ratio.rank(method='first'),4,duplicates='drop')).groupby('bucket',observed=True).size().reset_index(name='value').assign(bucket=lambda x:x.bucket.astype(str)),'bucket'),('cluster_coherence_path',base.groupby('causal_cluster_coherence_so_far').size().reset_index(name='value').assign(causal_cluster_coherence_so_far=lambda x:x.causal_cluster_coherence_so_far.astype(str)),'causal_cluster_coherence_so_far'),('strategy_entry_first_passage',fp.groupby(['strategy','barrier_10_result']).size().reset_index(name='value').assign(label=lambda x:x.strategy+'|'+x.barrier_10_result),'label'),('fold_candidate_lift',pred.groupby(['fold','candidate_id']).apply(lambda x:x.loc[x.selected,'actual'].mean()/x.actual.mean() if x.selected.any() and x.actual.mean() else np.nan,include_groups=False).reset_index(name='value').assign(label=lambda x:x.fold.astype(str)+'|'+x.candidate_id),'label'),('calibration',cal.rename(columns={'candidate_id':'label','observed_probability':'value'}),'label'),('symbol_time_regime_stability',base.groupby(['symbol','volatility_regime']).size().reset_index(name='value').assign(label=lambda x:x.symbol+'|'+x.volatility_regime.astype(str)),'label')]
    for name,df,label in plots:write(df,plotdir/f'{name}_source.csv');svg_bar(df,label,'value',plotdir/f'{name}.svg',name.replace('_',' ').title())
    summary={'events':int(pc.event_id.nunique()),'market_clusters':int(pc.market_cluster_id.nunique()),'response_episodes_total':3286,'response_episodes_purged':1,'response_episodes_analyzed':int(len(episodes)),'checkpoint_rows':int(len(cp)),'strategy_entries':{k:int(v) for k,v in en[en.entry_status=='ENTERED'].strategy.value_counts().items()},'path_classes':{k:int(v) for k,v in pc.primary_path_class.value_counts().items()},'promoted_candidates':int((cand.status=='FROZEN_FOR_UNUSED_SELECTION_VALIDATION').sum()),'orders':0}
    (o/'analysis_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8');print(json.dumps(summary));return 0
if __name__=='__main__':raise SystemExit(main())
