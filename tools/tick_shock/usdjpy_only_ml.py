"""USDJPY-only research. Development and sealed holdout are separate commands."""
from __future__ import annotations
import argparse
from concurrent.futures import ProcessPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import pickle
import subprocess
import time
import numpy as np
import pandas as pd
import technical_ml_discovery as s

ROOT=s.ROOT
BATCH=ROOT/'reports/backtest/batches/tstech_real_202501_202506_20260910'
OUT=ROOT/'reports/analysis/tick_shock/usdjpy_only_ml_20260912'
PREREG=ROOT/'docs/research/tick_shock/usdjpy_only_ml_preregistration.md'
COUNTS=(100,150,200,300)
KEYS=['family','target','variant','geometry','policy']
DATA=None


def stamp(): return datetime.now(timezone.utc).isoformat()
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def dump(rows,name): s.dump(rows,OUT/name)
def js(obj,name): s.write_json(obj,OUT/name)


def load(months,allow_holdout=False):
    if any(m>=202505 for m in months):
        assert allow_holdout and (OUT/'freeze_record.json').exists()
        check_freeze()
    fs=[];os=[];hashes=[];population=[]
    for m in months:
        folder=BATCH/str(m);qa=json.loads((folder/'collection_qa.json').read_text())
        assert qa['status'] in ('PASS','PASS_WITH_LEGACY_WARNING') and all(qa['checks'].values())
        pair=[]
        for name in ('technical_features.csv','technical_outcomes.csv'):
            p=folder/name;actual=sha(p);assert actual==qa['input_sha256'][name]
            hashes.append(dict(month=m,path=p.relative_to(ROOT).as_posix(),sha256=actual))
            # Filter immediately, before any statistics or preprocessing.
            frame=pd.read_csv(p,encoding='utf-8-sig')
            frame=frame.loc[frame.symbol.eq('USDJPY')].copy()
            frame.episode_id=qa['run_id']+':'+frame.episode_id.astype(str)
            frame.market_cluster_id=qa['run_id']+':'+frame.market_cluster_id.astype(str)
            frame['month']=m
            pair.append(frame)
        f,o=pair;o['calendar_segment']=int(str(m)[-2:])-1
        assert f.symbol.eq('USDJPY').all() and o.symbol.eq('USDJPY').all()
        assert not f.episode_id.duplicated().any()
        assert not o.duplicated(['episode_id','direction','distance_index']).any()
        assert set(f.episode_id)==set(o.episode_id) and len(o)==12*len(f)
        assert f.feature_future_count.sum()==0 and (f.feature_max_close_msc<=f.t0_msc).all()
        summary=pd.read_csv(folder/'summary.csv')
        stat=summary.loc[summary.record_type.eq('STATISTICAL_DETECTOR') & summary.key.eq('USDJPY'),'value'].iloc[0]
        fields=dict(item.split('=',1) for item in stat.split(';') if '=' in item)
        mh=pd.read_csv(folder/'medium_horizon_episode_summary.csv')
        mh=mh[mh.symbol.eq('USDJPY')]
        # Each accepted shock either anchors an episode or increments repeat_count.
        accepted=int(len(mh)+mh.repeat_count.sum())
        for g in s.GEOMETRIES:
            group=o[o.distance_index.eq(g)];v=group[group.status.isin(s.core.EXECUTED)]
            row=dict(month=m,geometry=g,distance_atr=float(group.distance_atr.iloc[0]),
                statistical_candidates=int(fields['statistical_candidates']),
                shock_detections_in_episode_archive=accepted,episode_archive_rows=len(mh),episodes=len(f),
                executable_long=int(v.direction.eq(1).sum()),executable_short=int(v.direction.eq(-1).sum()),
                executable_either=v.episode_id.nunique(),monthly_episode_ceiling_ge_200=len(f)>=200,
                collection_status=qa['status'])
            for side in (1,-1):
                actions=group[group.direction.eq(side)].copy();actions['score']=1.
                row[f'one_position_always_{"long" if side==1 else "short"}']=len(s.simulate(actions,0)[0])
            population.append(row)
        fs.append(f);os.append(o)
    return (pd.concat(fs).sort_values(['t0_msc','episode_id']).reset_index(drop=True),
            pd.concat(os,ignore_index=True),hashes,population)


def split(f,o,month):
    boundary=int(pd.Timestamp(f'{str(month)[:4]}-{str(month)[4:]}-01').timestamp()*1000)
    a=o.groupby('episode_id').agg(exit=('exit_msc','max'),entry=('entry_msc','max'))
    end=np.maximum.reduce([f.episode_id.map(a.exit).fillna(np.inf).to_numpy(),
        f.episode_id.map(a.entry).fillna(np.inf).to_numpy()+900000,f.t0_msc.to_numpy()+930000])
    val=f.index[f.month.eq(month)].to_numpy()
    vc=set(f.loc[val,'market_cluster_id'])
    fit=f.index[(f.month<month)&(end<boundary)&~f.market_cluster_id.isin(vc)].to_numpy()
    assert not set(f.loc[fit,'market_cluster_id'])&vc
    return dict(fit=fit,val=val,boundary=boundary,fit_months=s.equivalent_months(1735689600000,boundary))


def policies(actions,months):
    sc=actions.score.to_numpy();assert len(sc) and np.isfinite(sc).all()
    grid=s.calibration_grid(actions,months)
    rows=[dict(policy=f'ABS_{t:g}',threshold=t,target_count=0) for t in (0.,.05,.1)]
    rows.append(dict(policy='ALL',threshold=float(np.nextafter(sc.min(),-np.inf)),target_count=0))
    for target in COUNTS:
        q=max(0.,1-target*months/len(sc));threshold=float(np.quantile(sc,q))
        rows.append(dict(policy=f'PERCENTILE_{target}',threshold=threshold,target_count=target))
        threshold,achieved,maximum=s.select_count_cutoff(grid,target)
        rows.append(dict(policy=f'FREQUENCY_{target}',threshold=threshold,target_count=target))
    for r in rows:
        r['train_count_per_month']=len(s.simulate(actions,r['threshold'])[0])/months
        q=float((sc<r['threshold']).mean());r['train_cutoff_quantile']=q
        r['neighbor_low']=float(np.quantile(sc,max(0,q-.05)))
        r['neighbor_high']=float(np.quantile(sc,min(1,q+.05)))
    return rows


def initialize(path):
    global DATA
    with open(path,'rb') as fh: DATA=pickle.load(fh)


def run_task(task):
    family,variant,g,month=task
    ident=s.task_id(family,'NET_R',variant,g,month)
    f,o,xf,cols=DATA;x=xf[:,cols[variant]];group=o[o.distance_index.eq(g)]
    sp=split(f,group,month);pair,counts=s.fit_pair(family,'NET_R',x,f,group,sp['fit'])
    actions={};scores={}
    for part in ('fit','val'):
        ix=sp[part];ls=pair[1].predict(x[ix]);ss=pair[-1].predict(x[ix])
        actions[part]=s.choose_actions(group,f.loc[ix],ls,ss)
        scores[part]={'long_score':ls,'short_score':ss}
    np.savez_compressed(OUT/'predictions'/f'{ident}.npz',indices=sp['val'],**scores['val'])
    rows=[]
    for p in policies(actions['fit'],sp['fit_months']):
        tr,skip=s.simulate(actions['val'],p['threshold'])
        neighbors=[s.stats(s.simulate(actions['val'],p[n])[0])['total_r'] for n in ('neighbor_low','neighbor_high')]
        rows.append({**p,**skip,**s.stats(tr),'cost_04_total_r':s.stats(tr,.4)['total_r'],
            'neighbor_low_total_r':neighbors[0],'neighbor_high_total_r':neighbors[1]})
    record=dict(task=task,family=family,target='NET_R',variant=variant,geometry=g,month=month,
        rows=rows,fit_indices=sp['fit'].tolist(),val_indices=sp['val'].tolist(),fitting_counts=counts,
        boundary=sp['boundary'],all_converged=all(m.converged for m in pair.values()),
        quality=s.prediction_quality(pair,x,f,group,sp['val']),
        distributions=[dict(part=p,side=side,n=len(v),mean=float(v.mean()),sd=float(v.std()),
             p10=float(np.quantile(v,.1)),p50=float(np.quantile(v,.5)),p90=float(np.quantile(v,.9)))
             for p,sc in scores.items() for side,v in sc.items()])
    js(record,f'tasks/{ident}.json')
    return ident


def development():
    OUT.mkdir(exist_ok=False,parents=True)
    for n in ('tasks','predictions'): (OUT/n).mkdir()
    f,o,hashes,pop=load((202501,202502,202503,202504))
    x,cat=s.core.feature_matrix(f.drop(columns='month'));assert x.shape[1]==486
    cols={'FULL486':list(range(486)),'SCALE_FREE':[i for i,c in enumerate(x) if not s.raw_scale_feature(c)]}
    assert len(cols['SCALE_FREE'])==448
    dump(pop,'development_population.csv');dump(hashes,'development_input_hashes.csv');dump(cat,'feature_catalog.csv')
    js(dict(started=stamp(),source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        prereg_sha256=sha(PREREG),source_sha256=sha(__file__),sklearn=s.sklearn.__version__,
        numpy=np.__version__,pandas=pd.__version__,lightgbm=s.lightgbm.__version__,
        holdout_read=False,development_episodes=len(f)), 'start_record.json')
    protected=[dict(path=p.relative_to(ROOT).as_posix(),sha256=sha(p)) for p in (ROOT/'mql').rglob('*') if p.is_file() and p.suffix in ('.mq5','.mqh','.ex5')]
    dump(protected,'pre_source_hashes.csv')
    with (OUT/'dataset.pkl').open('wb') as fh: pickle.dump((f,o,x.to_numpy(float),cols),fh,protocol=5)
    s.core.summarize_paths(o[o.distance_index.isin(s.GEOMETRIES)],OUT)
    print(pd.DataFrame(pop).query('geometry==3').to_string(index=False),flush=True)
    tasks=[(a,b,g,m) for a in s.FAMILIES for b in s.VARIANTS for g in s.GEOMETRIES for m in s.MONTHS]
    start=time.perf_counter()
    with ProcessPoolExecutor(max_workers=3,initializer=initialize,initargs=(OUT/'dataset.pkl',)) as pool:
        for n,done in enumerate(as_completed([pool.submit(run_task,t) for t in tasks]),1):
            print(f'{n}/{len(tasks)} {done.result()}',flush=True)
    js(dict(completed=stamp(),tasks=len(tasks),elapsed_seconds=time.perf_counter()-start),'development_complete.json')
    select_and_freeze()


def read_data():
    with (OUT/'dataset.pkl').open('rb') as fh: return pickle.load(fh)


def actions(config,month,data=None): return s.load_actions(OUT,config,month,data or read_data())


def select_and_freeze():
    assert not (OUT/'freeze_record.json').exists()
    data=read_data();f,o,xf,cols=data;rows=[]
    for p in sorted((OUT/'tasks').glob('*.json')):
        r=json.loads(p.read_text())
        for v in r['rows']: rows.append({k:r[k] for k in ('family','target','variant','geometry','month','all_converged')}|v)
    wf=pd.DataFrame(rows);assert len(wf)==2160;dump(wf,'walk_forward.csv')
    frontier=[]
    for key,g in wf.groupby(KEYS,sort=True):
        cfg=dict(zip(KEYS,key));tr=[]
        for row in g.itertuples(): tr.append(s.simulate(actions(cfg,row.month,data),row.threshold)[0])
        tr=pd.concat(tr).sort_values(['signal_processing_msc','t0_msc','episode_id'])
        stats=s.stats(tr)
        gate=(g.expectancy_r.gt(0).all() and stats['pf']>1 and stats['top5_removed_total_r']>0
            and stats['max_day_profit_share']<.35 and g.cost_04_total_r.sum()>0
            and g.neighbor_low_total_r.sum()>0 and g.neighbor_high_total_r.sum()>0 and g.all_converged.all())
        frontier.append({**cfg,**stats,'min_month_trades':int(g.trades.min()),
            'worst_month_ev':float(g.expectancy_r.min()),'positive_months':int(g.expectancy_r.gt(0).sum()),
            'robust_gate':bool(gate),'all_converged':bool(g.all_converged.all()),
            'cost_04_total_r':float(g.cost_04_total_r.sum()),
            'neighbor_low_total_r':float(g.neighbor_low_total_r.sum()),'neighbor_high_total_r':float(g.neighbor_high_total_r.sum())})
    front=pd.DataFrame(frontier);dump(front,'candidate_frontier.csv')
    def rank(pool): return pool.sort_values(['worst_month_ev','expectancy_r','trades',*KEYS],ascending=[False,False,False,*([True]*len(KEYS))])
    passing=front[front.robust_gate & front.min_month_trades.ge(100)]
    mode='DEVELOPMENT_CANDIDATE' if len(passing) else 'HOLDOUT_DIAGNOSTIC_CANDIDATE_NOT_ADOPTED'
    pool=passing if len(passing) else front[front.all_converged]
    for tier in (200,150,100,0):
        possible=pool[pool.min_month_trades.ge(tier)]
        if len(possible): break
    selected=rank(possible).iloc[0].to_dict()
    selected['designation']=mode;selected['frequency_tier']=tier
    js(selected,'selection.json')
    selected_rows=wf.copy()
    for k in KEYS: selected_rows=selected_rows[selected_rows[k].eq(selected[k])]
    dump(selected_rows,'selected_development_monthly.csv')
    trades=pd.concat([s.simulate(actions(selected,row.month,data),row.threshold)[0] for row in selected_rows.itertuples()])
    dump(trades,'selected_development_trades.csv')
    # Freeze all January–April fitting data, using the selected identical policy.
    group=o[o.distance_index.eq(selected['geometry'])];sp=split(f,group,202505)
    names=pd.read_csv(OUT/'feature_catalog.csv').feature.tolist()
    ix=cols[selected['variant']];x=xf[:,ix];features=[names[i] for i in ix]
    pair,counts=s.fit_pair(selected['family'],'NET_R',x,f,group,sp['fit'])
    train=s.choose_actions(group,f.loc[sp['fit']],pair[1].predict(x[sp['fit']]),pair[-1].predict(x[sp['fit']]))
    policy=next(p for p in policies(train,sp['fit_months']) if p['policy']==selected['policy'])
    with (OUT/'frozen_model.pkl').open('wb') as fh: pickle.dump(pair,fh,protocol=5)
    spec=dict(symbol='USDJPY',features=features,full_feature_indices=ix,selection=selected,policy=policy,
        threshold=policy['threshold'],distance_index=int(selected['geometry']),
        distance_atr=float(group.distance_atr.iloc[0]),rr=1,max_hold_seconds=900,primary_extra_cost_pips=.2,
        training_months=[202501,202502,202503,202504],fit_indices=sp['fit'].tolist(),fit_label_counts=counts,
        model_parameters={str(side):model.estimator.get_params() for side,model in pair.items()},
        models={str(side):export_model(model) for side,model in pair.items()})
    js(spec,'frozen_model.json')
    # Independent exported representation evaluated before holdout is opened.
    qa=[]
    for side in (1,-1):
        independent=export_predict(spec['models'][str(side)],x)
        expected=pair[side].predict(x);delta=float(np.abs(independent-expected).max())
        qa.append(dict(check=f'export_parity_{side}',rows=len(x),max_error=delta,status='PASS' if delta<1e-10 else 'FAIL'))
    dump(qa,'export_parity.csv');assert all(q['status']=='PASS' for q in qa)
    freeze=dict(frozen_at=stamp(),designation=mode,holdout_read=False,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        files={n:sha(OUT/n) for n in ('frozen_model.pkl','frozen_model.json','selection.json','development_input_hashes.csv')},
        source_files={str(Path(m.__file__).relative_to(ROOT)):sha(m.__file__) for m in (s,s.core)},
        prereg_sha256=sha(PREREG),driver_sha256=sha(__file__))
    js(freeze,'freeze_record.json');print(json.dumps(s.core.clean_json(selected),indent=2),flush=True)


def export_model(model):
    est=model.estimator
    result=dict(family=model.family,median=model.median.tolist())
    if hasattr(est,'booster_'):
        result['kind']='LIGHTGBM';result['trees']=[t['tree_structure'] for t in est.booster_.dump_model()['tree_info']]
    elif hasattr(est,'tree_') or hasattr(est,'estimators_'):
        result['kind']='FOREST';trees=[est] if hasattr(est,'tree_') else est.estimators_
        result['trees']=[dict(left=t.tree_.children_left.tolist(),right=t.tree_.children_right.tolist(),feature=t.tree_.feature.tolist(),
            threshold=t.tree_.threshold.tolist(),value=t.tree_.value[:,0,0].tolist()) for t in trees]
    else:
        result.update(kind='LINEAR',mean=model.mean.tolist(),scale=model.scale.tolist(),
            coefficient=np.asarray(est.coef_).reshape(-1).tolist(),intercept=float(est.intercept_))
    return result


def export_predict(model,x):
    x=np.where(np.isfinite(x),x,np.array(model['median']))
    if model['kind']=='LINEAR':
        return ((x-np.array(model['mean']))/np.array(model['scale']))@np.array(model['coefficient'])+model['intercept']
    scores=[]
    for row in x:
        total=0.
        for tree in model['trees']:
            if model['kind']=='FOREST':
                node=0
                while tree['left'][node]>=0:
                    node=tree['left'][node] if float(np.float32(row[tree['feature'][node]]))<=tree['threshold'][node] else tree['right'][node]
                total+=tree['value'][node]
            else:
                node=tree
                while 'split_index' in node:
                    assert node['decision_type']=='<='
                    node=node['left_child'] if row[node['split_feature']]<=node['threshold'] else node['right_child']
                total+=node['leaf_value']
        scores.append(total/len(model['trees']) if model['kind']=='FOREST' else total)
    return np.array(scores)


def check_freeze():
    record=json.loads((OUT/'freeze_record.json').read_text())
    for name,value in record['files'].items(): assert sha(OUT/name)==value,name
    assert sha(PREREG)==record['prereg_sha256']
    for name,value in record['source_files'].items(): assert sha(ROOT/name)==value,name
    assert sha(__file__)==record['driver_sha256']
    return record


def holdout():
    record=check_freeze()
    assert not (OUT/'holdout_opened.json').exists(),'One evaluation only; reconcile existing evidence instead'
    js(dict(opened_at=stamp(),freeze_sha256=sha(OUT/'freeze_record.json'),months=[202505,202506]),'holdout_opened.json')
    with (OUT/'frozen_model.pkl').open('rb') as fh: pair=pickle.load(fh)
    spec=json.loads((OUT/'frozen_model.json').read_text());summary=[];alltr=[];population=[];hashes=[]
    for month in (202505,202506):
        check_freeze();f,o,h,p=load((month,),True);hashes+=h;population+=p
        xframe,_=s.core.feature_matrix(f.drop(columns='month'));x=xframe[spec['features']].to_numpy(float)
        scores={side:pair[side].predict(x) for side in (1,-1)}
        for side in (1,-1): assert np.allclose(scores[side],export_predict(spec['models'][str(side)],x),atol=1e-10,rtol=0)
        group=o[o.distance_index.eq(spec['distance_index'])]
        a=s.choose_actions(group,f,scores[1],scores[-1]);tr,skip=s.simulate(a,spec['threshold'])
        dump(a,f'holdout_{month}_actions.csv');dump(tr,f'holdout_{month}_trades.csv')
        row=dict(month=month,**s.stats(tr),**skip,threshold=spec['threshold'],mean_long_score=float(scores[1].mean()),mean_short_score=float(scores[-1].mean()))
        summary.append(row);alltr.append(tr);dump(summary,'holdout_monthly.csv')
        print(json.dumps(s.core.clean_json(row)),flush=True)
    dump(pd.concat(alltr),'holdout_trades.csv');dump(hashes,'holdout_input_hashes.csv');dump(population,'holdout_population.csv')
    js(dict(completed_at=stamp(),freeze_unchanged=True,stats=s.stats(pd.concat(alltr)),
        label='USDJPY_ONLY_UNUSED_HOLDOUT_NOT_PRISTINE_OOS'), 'holdout_complete.json')
    check_freeze()


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('command',choices=['development','holdout'])
    args=p.parse_args()
    if args.command=='development': development()
    else: holdout()
