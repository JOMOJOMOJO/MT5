"""Two-stage fixed-time study: development only; final holdout remains sealed."""
from __future__ import annotations
import argparse
from concurrent.futures import ProcessPoolExecutor, as_completed
import hashlib
import json
import pickle
from pathlib import Path
import subprocess
import numpy as np
import pandas as pd
import technical_ml_discovery as core
from usdjpy_only_ml import export_model, export_predict

ROOT=Path(__file__).resolve().parents[2]
BATCH=ROOT/'reports/backtest/batches/two_stage_development_20260913'
OUT=ROOT/'reports/analysis/tick_shock/two_stage_ml_20260913'
MONTHS=tuple(range(202501,202507))
COUNTS=(100,150,200,300,500)
HORIZONS=(300,600,900)
GATES=(0,25,50)
DATA=None

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def dump(rows,name):core.dump(rows,OUT/name)
def js(value,name):core.write_json(value,OUT/name)

def load():
    frames=[];outcomes=[];hashes=[];pop=[];names=None
    for month in MONTHS:
        folder=BATCH/str(month)
        qa=json.loads((folder/'fixed_time_qa.json').read_text())
        assert qa['status']=='PASS' and all(qa['checks'].values())
        f=pd.read_csv(folder/'technical_features.csv');o=pd.read_csv(folder/'fixed_time_outcomes.csv')
        original=pd.read_csv(folder/'technical_outcomes.csv')
        current=list(f.columns[13:]);assert len(current)==486
        if names is None:names=current
        assert names==current and not f.episode_id.duplicated().any()
        assert f.feature_future_count.eq(0).all() and f.feature_max_close_msc.le(f.t0_msc).all()
        assert set(f.symbol)=={'EURUSD','GBPUSD','USDJPY','AUDUSD','USDCAD','USDCHF'}
        for symbol,g in f.groupby('symbol'):
            eo=o[o.symbol.eq(symbol)&o.status.eq('TIME')]
            for h in HORIZONS:
                pop.append(dict(month=month,symbol=symbol,horizon=h,episodes=len(g),
                    executable_episodes=eo[eo.horizon_seconds.eq(h)].episode_id.nunique()))
        # Explicit non-entered labels preserve the event population, not just successful hindsight entries.
        entered=set(o.episode_id)
        extras=[]
        for row in original.drop_duplicates('episode_id').itertuples():
            if row.episode_id in entered:continue
            for h in HORIZONS:
                for side in (1,-1):
                    extras.append(dict(episode_id=row.episode_id,symbol=row.symbol,market_cluster_id=row.market_cluster_id,
                        t0_msc=row.t0_msc,signal_processing_msc=row.signal_processing_msc,direction=side,
                        horizon_seconds=h,entry_msc=0,entry_bid=0,entry_ask=0,atr14_m5=row.atr14_m5,
                        pip_size=row.pip_size,status='NO_ENTRY',exit_msc=0,exit_price=np.nan,gross_r=np.nan,gross_pips=np.nan))
        if extras:o=pd.concat([o,pd.DataFrame(extras)],ignore_index=True)
        assert len(o)==6*len(f) and not o.duplicated(['episode_id','direction','horizon_seconds']).any()
        for frame in (f,o):
            frame.episode_id=str(month)+':'+frame.episode_id.astype(str)
            frame.market_cluster_id=str(month)+':'+frame.market_cluster_id.astype(str)
            frame['month']=month
        o['distance']=o.atr14_m5;o['calendar_segment']=month-202501
        o['entry_eligible_msc']=o.signal_processing_msc
        frames.append(f);outcomes.append(o)
        for name in ('technical_features.csv','technical_outcomes.csv','fixed_time_outcomes.csv','fixed_time_qa.json'):
            hashes.append(dict(path=(folder/name).relative_to(ROOT).as_posix(),sha256=sha(folder/name)))
    f=pd.concat(frames,ignore_index=True).sort_values(['t0_processing_msc','symbol','t0_msc']).reset_index(drop=True)
    o=pd.concat(outcomes,ignore_index=True)
    columns={'FULL486':list(range(486)),'SCALE_FREE':[i for i,n in enumerate(names) if not core.raw_scale_feature(n)]}
    assert len(columns['SCALE_FREE'])==448
    x=f[names].to_numpy(float);x[~np.isfinite(x)]=np.nan
    dump(hashes,'input_hashes.csv');dump(pop,'population.csv');dump([dict(feature=n) for n in names],'feature_catalog.csv')
    return f,o,x,columns,names

def split(f,o,month):
    boundary=int(pd.Timestamp(f'{month//100}-{month%100:02d}-01').timestamp()*1000)
    end=o.groupby('episode_id').exit_msc.max()
    complete=o.groupby('episode_id').status.apply(lambda s:s.eq('TIME').all())
    label_end=np.maximum(f.episode_id.map(end).fillna(np.inf),f.t0_msc+930000)
    val=f.index[f.month.eq(month)].to_numpy();vc=set(f.loc[val,'market_cluster_id'])
    fit=f.index[(f.month<month)&(label_end<boundary)&f.episode_id.map(complete).fillna(False)&~f.market_cluster_id.isin(vc)].to_numpy()
    return dict(fit=fit,val=val,boundary=boundary,months=core.equivalent_months(1735689600000,boundary))

def fit_models(family,x,f,o,fit,horizon):
    o=o[o.horizon_seconds.eq(horizon)]
    ys={}
    for side in (1,-1):
        rows=o[o.direction.eq(side)].set_index('episode_id').loc[f.loc[fit,'episode_id']]
        assert rows.status.eq('TIME').all()
        ys[side]=rows.gross_r.to_numpy()-.2*rows.pip_size.to_numpy()/rows.atr14_m5.to_numpy()
    models={key:core.ActionModel(family,'NET_R').fit(x[fit],y,np.full(len(fit),'TIME'))
            for key,y in [('stage1',np.maximum(ys[1],ys[-1])),('long',ys[1]),('short',ys[-1])]}
    return models

def predict(models,x):return {key:model.predict(x) for key,model in models.items()}

def actions(f,o,indices,scores,horizon):
    out=core.choose_actions(o[o.horizon_seconds.eq(horizon)],f.loc[indices],scores['long'],scores['short'])
    out['stage1_score']=out.episode_id.map(dict(zip(f.loc[indices,'episode_id'],scores['stage1'])))
    return out

def gate_value(scores,gate):return -np.inf if gate==0 else float(np.quantile(scores,gate/100))

def select_trades(a,stage1_cut,threshold):
    chosen=a[a.stage1_score.ge(stage1_cut)&a.score.ge(threshold)].copy()
    chosen=chosen.sort_values(['signal_processing_msc','t0_msc','episode_id'],kind='stable')
    busy=-1;selected=[]
    for row in chosen.itertuples():
        if row.signal_processing_msc<=busy:continue
        if row.status=='NO_ENTRY':busy=max(row.signal_processing_msc,row.t0_msc+30000);continue
        if row.status=='CENSORED':busy=max(busy,row.entry_msc+row.horizon_seconds*1000);continue
        if row.status!='TIME':raise ValueError(row.status)
        if row.entry_msc<row.signal_processing_msc or row.exit_msc<row.entry_msc+row.horizon_seconds*1000:
            raise ValueError('Noncausal fixed-time label')
        selected.append(row.Index);busy=row.exit_msc
    return a.loc[selected].copy()

def calibration(train,months):
    if len(train)==0:return [dict(policy='ZERO',threshold=0.,q=1.)]
    grid=core.calibration_grid(train,months)
    result=[dict(policy='ZERO',threshold=0.,q=np.nan)]
    for count in COUNTS:
        q=max(0.,1-count*months/len(train))
        result.append(dict(policy=f'PERCENTILE_{count}',threshold=float(np.quantile(train.score,q)),q=q))
        result.append(dict(policy=f'FREQUENCY_{count}',threshold=core.select_count_cutoff(grid,count)[0],q=np.nan))
        result.append(dict(policy=f'ROLLING_{count}',threshold=float(np.quantile(train.score,q)),q=q))
    return result

def rolling_thresholds(train_times,train_scores,times,scores,q):
    # Feature-only trailing distribution. Equal-time arrivals do not see one another.
    ts=list(np.asarray(train_times,dtype=np.int64));ss=list(np.asarray(train_scores,dtype=float))
    result=np.empty(len(times));start=0;i=0
    while i<len(times):
        t=int(times[i]);j=i+1
        while j<len(times) and times[j]==t:j+=1
        while start<len(ts) and ts[start]<t-30*86400000:start+=1
        prior=np.asarray(ss[start:]);prior=prior[np.isfinite(prior)]
        threshold=float(np.quantile(prior,q)) if len(prior) else np.inf
        result[i:j]=threshold
        ts.extend(int(v) for v in times[i:j]);ss.extend(float(v) for v in scores[i:j]);i=j
    return result

def init_worker(path,output=None):
    global DATA,OUT
    if output is not None:OUT=Path(output)
    with open(path,'rb') as handle:DATA=pickle.load(handle)

def task_id(task):return '_'.join(map(str,task))

def run_task(task):
    family,variant,horizon,month=task;f,o,xf,columns,names=DATA;x=xf[:,columns[variant]]
    sp=split(f,o,month);models=fit_models(family,x,f,o,sp['fit'],horizon)
    train=predict(models,x[sp['fit']]);val=predict(models,x[sp['val']])
    a=actions(f,o,sp['fit'],train,horizon);b=actions(f,o,sp['val'],val,horizon)
    prior=f.index[f.month.lt(month)].to_numpy();prior_scores=predict(models,x[prior])
    np.savez_compressed(OUT/'predictions'/f'{task_id(task)}.npz',**val,indices=sp['val'])
    rows=[];trade_indices={}
    for gate in GATES:
        cut=gate_value(train['stage1'],gate);a1=a[a.stage1_score.ge(cut)]
        for policy in calibration(a1,sp['months']):
            threshold=policy['threshold'];selected=b
            if policy['policy'].startswith('ROLLING'):
                thresholds=rolling_thresholds(f.loc[prior,'t0_processing_msc'].to_numpy(),
                    np.maximum(prior_scores['long'],prior_scores['short']),
                    f.loc[sp['val'],'t0_processing_msc'].to_numpy(),np.maximum(val['long'],val['short']),policy['q'])
                selected=b[b.score.ge(b.episode_id.map(dict(zip(f.loc[sp['val'],'episode_id'],thresholds))))]
                threshold=-np.inf
            trades=select_trades(selected,cut,threshold)
            trade_indices[f'g{gate}_{policy["policy"]}']=trades.index.to_numpy(dtype=np.int64)
            row=dict(family=family,variant=variant,horizon=horizon,month=month,gate=gate,**policy,
                stage1_threshold=cut,fit_n=len(sp['fit']),validation_n=len(sp['val']),
                stage1_rejected=int((val['stage1']<cut).sum()),
                converged=all(m.converged for m in models.values()),**core.stats(trades))
            rows.append(row)
    np.savez_compressed(OUT/'predictions'/f'{task_id(task)}_trades.npz',**trade_indices)
    core.write_json(rows,OUT/'tasks'/f'{task_id(task)}.json')
    print(task_id(task),len(rows),flush=True)
    return rows

def rebuild(task,data):
    family,variant,horizon,month=task;f,o,xf,columns,names=data
    p=np.load(OUT/'predictions'/f'{task_id(task)}.npz')
    return actions(f,o,p['indices'],{key:p[key] for key in ('stage1','long','short')},horizon)

def collect_candidate(cfg,data):
    trades=[]
    for month in MONTHS[1:]:
        task=(cfg['family'],cfg['variant'],int(cfg['horizon']),month)
        b=rebuild(task,data)
        indices=np.load(OUT/'predictions'/f'{task_id(task)}_trades.npz')[f'g{int(cfg["gate"])}_{cfg["policy"]}']
        trades.append(b.loc[indices])
    return pd.concat(trades,ignore_index=True)

def summarize_and_freeze(data):
    wf=pd.read_csv(OUT/'walk_forward.csv');keys=['family','variant','horizon','gate','policy'];rows=[]
    for values,group in wf.groupby(keys,sort=True):
        cfg=dict(zip(keys,values));trades=collect_candidate(cfg,data);stats=core.stats(trades)
        net=trades.gross_r-.2*trades.pip_size/trades.distance
        positive=net.clip(lower=0).groupby(trades.symbol).sum()
        share=float(positive.max()/positive.sum()) if positive.sum()>0 else 1.
        stress=core.stats(trades,.4)
        row=dict(**cfg,**stats,min_month_trades=int(group.trades.min()),positive_months=int(group.expectancy_r.gt(0).sum()),
            worst_month_ev=float(group.expectancy_r.min()),symbol_positive_profit_share=share,
            cost04_total_r=stress['total_r'],all_converged=bool(group.converged.all()))
        row['pass_gate']=bool(row['expectancy_r']>0 and row['pf']>1 and row['min_month_trades']>=200 and
            row['positive_months']>=3 and row['worst_month_ev']>-.1 and row['top5_removed_total_r']>0 and
            row['cost04_total_r']>0 and share<=.5 and row['all_converged'])
        rows.append(row)
    front=pd.DataFrame(rows)
    front['neighbor_positive']=False
    for index,row in front.iterrows():
        if row.policy=='ZERO':continue
        family,count=row.policy.rsplit('_',1);position=COUNTS.index(int(count))
        neighbors=COUNTS[max(0,position-1):position]+COUNTS[position+1:position+2]
        group=front[(front.family==row.family)&(front.variant==row.variant)&(front.horizon==row.horizon)&
            (front.gate==row.gate)&front.policy.isin([f'{family}_{n}' for n in neighbors])]
        front.loc[index,'neighbor_positive']=bool(len(group)==len(neighbors) and len(group)>0 and group.expectancy_r.gt(0).all())
    front['pass_gate'] &=front.neighbor_positive
    dump(front,'candidate_frontier.csv')
    passing=front[front.pass_gate];pool=passing if len(passing) else front[front.all_converged&front.trades.gt(0)]
    for tier in (200,150,100,0):
        possible=pool[pool.min_month_trades.ge(tier)]
        if len(possible):break
    if not len(possible):raise RuntimeError('No converged diagnostic candidate')
    selected=possible.sort_values(['worst_month_ev','expectancy_r']+keys,ascending=[False,False]+[True]*len(keys)).iloc[0].to_dict()
    selected['designation']='PASS_CANDIDATE' if len(passing) else 'DIAGNOSTIC_NOT_ADOPTED'
    selected['frequency_tier']=tier
    js(selected,'selection.json');trades=collect_candidate(selected,data);dump(trades,'selected_development_trades.csv')
    mask=np.ones(len(wf),dtype=bool)
    for key in keys:mask &=wf[key].eq(selected[key]).to_numpy()
    dump(wf[mask],'selected_development_monthly.csv')
    f,o,xf,columns,names=data;ix=columns[selected['variant']];x=xf[:,ix]
    sp=split(f,o,202507);models=fit_models(selected['family'],x,f,o,sp['fit'],int(selected['horizon']))
    assert all(model.converged for model in models.values()),'Final model convergence failed'
    predictions=predict(models,x[sp['fit']]);cut=gate_value(predictions['stage1'],selected['gate'])
    a=actions(f,o,sp['fit'],predictions,int(selected['horizon']));a=a[a.stage1_score.ge(cut)]
    policy=next(p for p in calibration(a,sp['months']) if p['policy']==selected['policy'])
    all_predictions=predict(models,x)
    seed_mask=f.t0_processing_msc.ge(sp['boundary']-30*86400000)
    seed=pd.DataFrame(dict(time_msc=f.loc[seed_mask,'t0_processing_msc'].to_numpy(),
        score=np.maximum(all_predictions['long'],all_predictions['short'])[seed_mask]))
    dump(seed,'rolling_seed.csv')
    with (OUT/'frozen_model.pkl').open('wb') as handle:pickle.dump(models,handle,protocol=5)
    spec=dict(selection=selected,features=[names[i] for i in ix],feature_indices=ix,
        horizon_seconds=int(selected['horizon']),stage1_threshold=cut,policy=policy,
        models={name:export_model(model) for name,model in models.items()},
        model_parameters={name:model.estimator.get_params() for name,model in models.items()},
        training_months=list(MONTHS),holdout_months=[202507,202508],normalization_r='ONE_M5_ATR14_NOT_MAX_LOSS',
        fixed_money_per_atr=10.,max_equity_fraction_per_atr=.0025,emergency_sl=None,tp=None,
        primary_extra_cost_pips=.2,global_positions=1,rolling_seed='rolling_seed.csv')
    js(spec,'frozen_model.json')
    qa=[]
    for name,model in models.items():
        error=float(np.max(np.abs(export_predict(spec['models'][name],x)-all_predictions[name])))
        qa.append(dict(model=name,rows=len(f),max_error=error,status='PASS' if error<1e-10 else 'FAIL'))
    dump(qa,'export_parity.csv');assert all(row['status']=='PASS' for row in qa)
    js(dict(status='PYTHON_FROZEN_AWAITING_MQL_PARITY',holdout_read=False,
        source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        files={name:sha(OUT/name) for name in ('frozen_model.pkl','frozen_model.json','selection.json','input_hashes.csv','rolling_seed.csv')},
        driver_sha256=sha(__file__),prereg_sha256=sha(ROOT/'docs/research/tick_shock/two_stage_ml_preregistration.md')),'python_freeze.json')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--workers',type=int,default=3)
    a=parser.parse_args()
    if OUT.exists():raise RuntimeError('Output exists; no implicit rerun/overwrite')
    # Required six-month evidence before creating model state; never reads July/August.
    for month in MONTHS:
        q=BATCH/str(month)/'fixed_time_qa.json'
        if not q.exists() or json.loads(q.read_text())['status']!='PASS':raise RuntimeError(f'Missing passing input: {q}')
    OUT.mkdir(parents=True);(OUT/'tasks').mkdir();(OUT/'predictions').mkdir()
    data=load();cache=OUT/'dataset.pkl'
    with cache.open('wb') as handle:pickle.dump(data,handle,protocol=5)
    js(dict(status='DEVELOPMENT_RUNNING',holdout_read=False,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        source_sha256=sha(__file__),prereg_sha256=sha(ROOT/'docs/research/tick_shock/two_stage_ml_preregistration.md')),'start_record.json')
    tasks=[(family,variant,h,month) for family in core.FAMILIES for variant in core.VARIANTS for h in HORIZONS for month in MONTHS[1:]]
    results=[]
    with ProcessPoolExecutor(max_workers=a.workers,initializer=init_worker,initargs=(cache,)) as pool:
        futures=[pool.submit(run_task,task) for task in tasks]
        for future in as_completed(futures):results.extend(future.result())
    dump(pd.DataFrame(results).sort_values(['family','variant','horizon','month','gate','policy']),'walk_forward.csv')
    js(dict(status='FORWARD_COMPLETE_AWAITING_SELECTION',tasks=len(tasks),rows=len(results),holdout_read=False),'progress.json')
    summarize_and_freeze(data)


if __name__=='__main__':main()
