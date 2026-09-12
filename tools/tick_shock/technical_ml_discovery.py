"""Bounded analysis-only technical ML discovery; never modifies MT5 sources.

Training/calibration are before the outer month. Every estimator is frozen after
the chronological calibration tail, with no score-changing post-calibration refit.
"""
from __future__ import annotations
import argparse
from concurrent.futures import ProcessPoolExecutor, as_completed
import hashlib
import json
import math
import os
from pathlib import Path
import pickle
import platform
import re
import time
import warnings

import numpy as np
import pandas as pd
import lightgbm
import sklearn
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor, ExtraTreesClassifier, ExtraTreesRegressor
from sklearn.linear_model import LogisticRegression, Ridge, ElasticNet
from sklearn.tree import DecisionTreeClassifier, DecisionTreeRegressor
from sklearn.metrics import roc_auc_score, brier_score_loss, mean_squared_error
from sklearn.exceptions import ConvergenceWarning
from threadpoolctl import threadpool_limits
import analyze_technical_discovery as core
from analyze_technical_4m2m_real import load_months, sha

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'reports/analysis/tick_shock/technical_ml_discovery_20260911'
FAMILIES = ('LOGISTIC','ELASTICNET','RANDOM_FOREST','EXTRA_TREES','SHALLOW_TREE','LIGHTGBM')
TARGETS = ('WIN','TP_FIRST','NET_R')
VARIANTS = ('FULL486','SCALE_FREE')
GEOMETRIES = (1,2,3,4,5)
MONTHS = (202502,202503,202504)
COUNTS = (100,200,300,500,800)
SEED = 20260911
choose_actions = core.choose_actions
_DATA = None


def raw_scale_feature(name):
    return (name in ('quote_mid','quote_spread') or
            bool(re.fullmatch(r'(m1|m5|m15)_(atr(7|14|28)|tick_volume|(?:ema|sma)\d+_value)', name)))


def dump(rows, path):
    core.dump_csv(rows, Path(path))


def write_json(value, path):
    core.write_json(value, Path(path))


def simulate(actions, threshold):
    return core.portfolio(actions, threshold)


def stats(trades, cost=.2):
    result = core.profit_stats(trades, cost)
    # The old four-segment helper is not a valid three-month stability metric.
    result.pop('positive_segments', None)
    result.pop('min_segment_trades', None)
    if len(trades):
        net = trades.gross_r.to_numpy() - cost/(trades.distance/trades.pip_size).to_numpy()
        result['mean_hold_seconds'] = float(((trades.exit_msc-trades.entry_msc)/1000).mean())
        result['timeout_rate'] = float(trades.status.isin(['TIME','TIMEOUT']).mean())
        result['clusters'] = int(trades.market_cluster_id.nunique())
        result['days'] = int((trades.t0_msc//86400000).nunique())
        result['predicted_ev'] = float(trades.score.mean()) if 'score' in trades else math.nan
        streak = maximum = 0
        for r in net:
            streak = streak+1 if r < 0 else 0
            maximum = max(maximum, streak)
        result['longest_loss_streak'] = maximum
    return result


def equivalent_months(start, end):
    # Server timestamps treated as naive server weekdays, not UTC localization.
    dates = pd.date_range(pd.Timestamp(start, unit='ms').normalize(),
                          pd.Timestamp(end-1, unit='ms').normalize(), freq='D')
    return max(float((dates.dayofweek < 5).sum())/21.75, 1/21.75)


def split_indices(f, o, month):
    boundary = int(pd.Timestamp(f'{str(month)[:4]}-{str(month)[4:]}-01').timestamp()*1000)
    start = int(pd.Timestamp('2025-01-01').timestamp()*1000)
    cut = start + int(.75*(boundary-start))
    available = o.groupby('episode_id').agg(exit=('exit_msc','max'), entry=('entry_msc','max'))
    end = np.maximum.reduce([f.episode_id.map(available.exit).fillna(np.inf).to_numpy(),
                             f.episode_id.map(available.entry).fillna(np.inf).to_numpy()+900000,
                             f.t0_msc.to_numpy()+930000])
    val = f.index[f.month == month].to_numpy()
    val_clusters = set(f.loc[val,'market_cluster_id'])
    cal_mask = (f.t0_msc >= cut) & (f.month < month) & (end < boundary) & ~f.market_cluster_id.isin(val_clusters)
    cal = f.index[cal_mask].to_numpy()
    cal_clusters = set(f.loc[cal,'market_cluster_id'])
    fit = f.index[(f.t0_msc < cut) & (end < cut) & ~f.market_cluster_id.isin(cal_clusters|val_clusters)].to_numpy()
    assert not set(f.loc[fit,'market_cluster_id']) & set(f.loc[cal,'market_cluster_id'])
    assert not set(f.loc[fit,'market_cluster_id']) & val_clusters
    return dict(fit=fit, cal=cal, val=val, cut=cut, boundary=boundary,
                fit_months=equivalent_months(start,cut),cal_months=equivalent_months(cut,boundary))


class ActionModel:
    def __init__(self, family, target):
        self.family, self.target = family, target

    def transform(self, x):
        x = np.where(np.isfinite(x), x, self.median)
        if self.family in ('LOGISTIC','ELASTICNET'):
            return (x-self.mean)/self.scale
        return x

    def fit(self, x, y, status):
        self.median = np.array([np.median(v[np.isfinite(v)]) if np.isfinite(v).any() else 0. for v in x.T])
        z = np.where(np.isfinite(x), x, self.median)
        self.mean, self.scale = z.mean(axis=0), z.std(axis=0)
        self.scale[self.scale < 1e-12] = 1
        cls = self.target != 'NET_R'
        label = (y > 0) if self.target == 'WIN' else ((np.asarray(status) == 'TP') if cls else y)
        self.positive_payoff = float(y[label].mean()) if cls and label.any() else 0.
        self.negative_payoff = float(y[~label].mean()) if cls and (~label).any() else 0.
        self.constant = None
        self.converged = True
        self.warning_messages = []
        if cls and len(np.unique(label)) < 2:
            self.constant = float(label.mean())
            self.estimator = None
            return self
        if self.family == 'LOGISTIC':
            self.estimator = LogisticRegression(C=.1,solver='lbfgs',max_iter=1200,tol=1e-5,random_state=SEED) if cls else Ridge(alpha=10)
        elif self.family == 'ELASTICNET':
            self.estimator = (LogisticRegression(C=.1,l1_ratio=.5,solver='saga',max_iter=2500,tol=1e-3,random_state=SEED)
                              if cls else ElasticNet(alpha=.02,l1_ratio=.5,max_iter=4000,tol=1e-4,random_state=SEED))
        elif self.family in ('RANDOM_FOREST','EXTRA_TREES'):
            factory = ((RandomForestClassifier if cls else RandomForestRegressor) if self.family=='RANDOM_FOREST'
                       else (ExtraTreesClassifier if cls else ExtraTreesRegressor))
            self.estimator = factory(n_estimators=96,max_depth=6,min_samples_leaf=40,max_features='sqrt',n_jobs=1,random_state=SEED)
        elif self.family == 'SHALLOW_TREE':
            self.estimator = (DecisionTreeClassifier if cls else DecisionTreeRegressor)(max_depth=4,min_samples_leaf=60,random_state=SEED)
        elif self.family == 'LIGHTGBM':
            self.estimator = (lightgbm.LGBMClassifier if cls else lightgbm.LGBMRegressor)(n_estimators=80,max_depth=3,
                num_leaves=8,min_child_samples=60,learning_rate=.04,reg_alpha=1.,reg_lambda=2.,
                deterministic=True,force_col_wise=True,n_jobs=1,verbosity=-1,random_state=SEED)
        else:
            raise ValueError(self.family)
        with warnings.catch_warnings(record=True) as caught, threadpool_limits(limits=1):
            warnings.simplefilter('always')
            self.estimator.fit(self.transform(x),label)
        self.warning_messages = [str(w.message) for w in caught]
        self.converged = not any(issubclass(w.category,ConvergenceWarning) for w in caught)
        return self

    def raw_predict(self,x):
        if self.constant is not None:
            return np.full(len(x),self.constant)
        z = self.transform(x)
        with threadpool_limits(limits=1):
            if self.family == 'LIGHTGBM':
                return self.estimator.booster_.predict(z,num_threads=1)
            return self.estimator.predict(z) if self.target=='NET_R' else self.estimator.predict_proba(z)[:,1]

    def predict(self,x):
        raw = self.raw_predict(x)
        return raw if self.target=='NET_R' else raw*self.positive_payoff+(1-raw)*self.negative_payoff


def fit_pair(family,target,x,f,group,indices):
    pair, counts = {}, []
    for side in (1,-1):
        labels = group[(group.direction==side)&group.status.isin(core.EXECUTED)].set_index('episode_id')
        idx = np.array([i for i in indices if f.at[i,'episode_id'] in labels.index],dtype=int)
        if len(idx) < 100:
            raise ValueError(f'Insufficient fitting labels: {len(idx)}')
        rows = labels.loc[f.loc[idx,'episode_id']]
        y = rows.gross_r.to_numpy(float)-.2/(rows.distance/rows.pip_size).to_numpy(float)
        pair[side] = ActionModel(family,target).fit(x[idx],y,rows.status.to_numpy())
        counts.append(len(idx))
    return pair, counts


def calibration_grid(actions, months):
    scores = actions.score.to_numpy(float)
    scores = scores[np.isfinite(scores)]
    if not len(scores):
        return [(math.inf,0.)]
    thresholds = np.unique(np.r_[np.nextafter(scores.min(),-np.inf),np.quantile(scores,np.linspace(0,1,33)),np.nextafter(scores.max(),np.inf)])
    return [(float(t),len(simulate(actions,float(t))[0])/months) for t in thresholds]


def select_count_cutoff(grid,target):
    t, rate = min(grid,key=lambda p:(abs(p[1]-target),-p[0]))
    return t, rate, max(v for _,v in grid)


def calibrate(actions,months,target):
    return select_count_cutoff(calibration_grid(actions,months),target)


def policies(fit_actions,cal_actions,split):
    grid_fit = calibration_grid(fit_actions,split['fit_months'])
    grid_cal = calibration_grid(cal_actions,split['cal_months'])
    rows = [dict(policy=f'ABS_{t:g}',calibration='ABS',target_count=0,threshold=t,
                 calibration_achieved=math.nan,calibration_max=math.nan) for t in (0.,.05,.1)]
    scores = fit_actions.score.to_numpy()
    for target in COUNTS:
        quantile = max(0.,1-target*split['fit_months']/max(len(scores),1))
        threshold = float(np.quantile(scores,quantile)) if len(scores) else math.inf
        rows.append(dict(policy=f'PERCENTILE_{target}',calibration='PERCENTILE',target_count=target,
                         threshold=threshold,calibration_achieved=len(simulate(fit_actions,threshold)[0])/split['fit_months'],
                         calibration_max=max(v for _,v in grid_fit)))
        for name,grid in (('FREQUENCY',grid_fit),('TAIL_FREQUENCY',grid_cal)):
            t,achieved,maximum = select_count_cutoff(grid,target)
            rows.append(dict(policy=f'{name}_{target}',calibration=name,target_count=target,threshold=t,
                             calibration_achieved=achieved,calibration_max=maximum))
    return rows


def prediction_quality(pair,x,f,group,indices):
    rows=[]
    for side in (1,-1):
        labels=group[(group.direction==side)&group.status.isin(core.EXECUTED)].set_index('episode_id')
        ix=np.array([i for i in indices if f.at[i,'episode_id'] in labels.index],dtype=int)
        actual=labels.loc[f.loc[ix,'episode_id']]
        y=actual.gross_r.to_numpy()-.2/(actual.distance/actual.pip_size).to_numpy()
        model=pair[side]
        score,raw=model.predict(x[ix]),model.raw_predict(x[ix])
        row=dict(direction=side,rows=len(ix),actual_ev=float(y.mean()),predicted_ev=float(score.mean()),
                 ev_rmse=float(np.sqrt(mean_squared_error(y,score))),score_actual_corr=float(pd.Series(score).corr(pd.Series(y))),
                 converged=model.converged)
        if model.target!='NET_R':
            truth=(y>0) if model.target=='WIN' else (actual.status.to_numpy()=='TP')
            row.update(brier=brier_score_loss(truth,raw),auc=roc_auc_score(truth,raw) if len(np.unique(truth))>1 else math.nan,
                       actual_probability=float(truth.mean()),predicted_probability=float(raw.mean()))
        rows.append(row)
    return rows


def task_id(family,target,variant,geometry,month):
    return f'{family}__{target}__{variant}__g{geometry}__m{month}'


def init_worker(cache):
    global _DATA
    with open(cache,'rb') as fh:
        _DATA=pickle.load(fh)


def run_task(task,output):
    started=time.perf_counter()
    family,target,variant,geometry,month=task
    ident=task_id(*task)
    output=Path(output)
    dest=output/'tasks'/f'{ident}.json'
    if dest.exists():
        return ident,'cached'
    f,o,xf,columns=_DATA
    x=xf[:,columns[variant]]
    group=o[o.distance_index==geometry]
    split=split_indices(f,group,month)
    pair,counts=fit_pair(family,target,x,f,group,split['fit'])
    actions={}
    distributions=[]
    for part in ('fit','cal','val'):
        ix=split[part]
        ls,ss=pair[1].predict(x[ix]),pair[-1].predict(x[ix])
        actions[part]=choose_actions(group,f.loc[ix],ls,ss)
        for side,sc in ((1,ls),(-1,ss)):
            distributions.append(dict(part=part,direction=side,rows=len(sc),mean=float(np.mean(sc)),std=float(np.std(sc)),
                                      **{f'p{q}':float(np.percentile(sc,q)) for q in (0,10,25,50,75,90,95,99,100)}))
        if part=='val':
            np.savez_compressed(output/'predictions'/f'{ident}.npz',indices=ix,long_score=ls,short_score=ss)
    rows=[]
    for p in policies(actions['fit'],actions['cal'],split):
        trades,skips=simulate(actions['val'],p['threshold'])
        rows.append({**p,**skips,**stats(trades)})
    data=dict(task=task,task_id=ident,rows=rows,distributions=distributions,
              quality=prediction_quality(pair,x,f,group,split['val']),
              split={k:(len(v) if isinstance(v,np.ndarray) else v) for k,v in split.items()},
              fitting_long=counts[0],fitting_short=counts[1],
              all_converged=all(p.converged for p in pair.values()),
              warnings={str(s):p.warning_messages for s,p in pair.items()},elapsed_seconds=time.perf_counter()-started)
    write_json(data,dest)
    return ident,round(data['elapsed_seconds'],2)


def load_actions(output,config,month,data=None):
    f,o,xf,columns=data or _DATA
    task=(config['family'],config['target'],config['variant'],int(config['geometry']),int(month))
    z=np.load(Path(output)/'predictions'/f'{task_id(*task)}.npz')
    return choose_actions(o[o.distance_index==int(config['geometry'])],f.loc[z['indices']],z['long_score'],z['short_score'])


def prepare(output):
    output.mkdir(parents=True,exist_ok=False)
    (output/'tasks').mkdir(); (output/'predictions').mkdir()
    f,o,hashes=load_months((202501,202502,202503,202504))
    x,catalog=core.feature_matrix(f.drop(columns='month'))
    assert x.shape==(11230,486)
    selected=[i for i,name in enumerate(x.columns) if not raw_scale_feature(name)]
    assert len(selected)==448
    for c in catalog:
        c['scale_free_included']=not raw_scale_feature(c['feature'])
        c['interaction']=('_x_' in c['feature'])
    dump(catalog,output/'feature_catalog.csv')
    dump(hashes,output/'input_hashes.csv')
    columns={'FULL486':list(range(486)),'SCALE_FREE':selected}
    # This trusted local cache is created by this script, never loaded externally.
    with (output/'dataset.pkl').open('wb') as fh:
        pickle.dump((f,o,x.to_numpy(float),columns),fh,protocol=5)
    protected=[]
    for folder in (ROOT/'mql',ROOT/'tests/tick_shock/fixtures',ROOT/'tests/tick_shock/expected'):
        for p in sorted(folder.rglob('*')):
            if p.is_file() and p.suffix in ('.mq5','.mqh','.ex5','.csv'):
                protected.append(dict(path=p.relative_to(ROOT).as_posix(),sha256=sha(p)))
    dump(protected,output/'protected_source_hashes.csv')
    write_json(dict(python=platform.python_version(),sklearn=sklearn.__version__,lightgbm=lightgbm.__version__,
                    numpy=np.__version__,pandas=pd.__version__,seed=SEED,xgboost='NOT_INSTALLED',shap='NATIVE_LIGHTGBM_TREE_SHAP',
                    actual_commission='NOT_OBSERVED_IN_COLLECTION',primary_extra_cost_pips=.2,
                    preregistration_sha256=sha(ROOT/'docs/research/tick_shock/technical_ml_discovery_preregistration.md'),
                    analysis_source_sha256=sha(__file__),holdout_outcomes_read=False),output/'environment.json')
    core.summarize_paths(o[o.distance_index.isin(GEOMETRIES)],output)
    print(f'Prepared {len(f)} episodes,486/448 features; no holdout loaded.',flush=True)


def summarize(output):
    init_worker(output/'dataset.pkl')
    allrows,distributions,quality,splits=[],[],[],[]
    for path in sorted((output/'tasks').glob('*.json')):
        t=json.loads(path.read_text())
        fam,target,variant,g,month=t['task']
        meta=dict(family=fam,target=target,variant=variant,geometry=g,month=month,all_converged=t['all_converged'],task_id=t['task_id'])
        allrows.extend([{**meta,**r} for r in t['rows']])
        distributions.extend([{**meta,**r} for r in t['distributions']])
        quality.extend([{**meta,**r} for r in t['quality']])
        splits.append({**meta,**t['split'], 'fitting_long':t['fitting_long'],'fitting_short':t['fitting_short'],'elapsed_seconds':t['elapsed_seconds']})
    frame=pd.DataFrame(allrows)
    dump(frame,output/'walk_forward.csv'); dump(distributions,output/'score_distributions.csv')
    dump(quality,output/'prediction_quality.csv'); dump(splits,output/'split_audit.csv')
    aggregate=[]
    keys=['family','target','variant','geometry','policy']
    for key,g in frame.groupby(keys,sort=True):
        assert set(g.month)==set(MONTHS),f'Incomplete folds {key}'
        row=dict(zip(keys,key))
        row.update(calibration=g.calibration.iloc[0],target_count=int(g.target_count.iloc[0]),
                   min_month_trades=int(g.trades.min()),max_month_trades=int(g.trades.max()),trades=int(g.trades.sum()),
                   worst_month_ev=float(g.expectancy_r.min()),total_r=float(g.total_r.sum()),
                   expectancy_r=float(g.total_r.sum()/g.trades.sum()) if g.trades.sum() else math.nan,
                   positive_months=int((g.total_r>0).sum()),all_converged=bool(g.all_converged.all()))
        row['basic_gate']=row['min_month_trades']>=200 and row['positive_months']==3 and row['all_converged']
        row['robustness_gate']=False; row['adjacent_gate']=False
        if row['basic_gate']:
            trade_frames=[]
            for rec in g.to_dict('records'):
                a=load_actions(output,rec,rec['month'])
                trade_frames.append(simulate(a,rec['threshold'])[0])
            trades=pd.concat(trade_frames).sort_values(['signal_processing_msc','episode_id'])
            net=trades.gross_r-.2/(trades.distance/trades.pip_size)
            totals=[]
            date=pd.to_datetime(trades.t0_msc,unit='ms')
            for label in (trades.symbol,date.dt.to_period('W').astype(str)):
                grouped=net.groupby(label).sum()
                positive=grouped.clip(lower=0)
                totals.append((float(positive.max()/positive.sum()) if positive.sum() else 1.,bool((net.sum()-grouped>0).all())))
            row.update(top5_removed_total_r=float(net.sum()-net.nlargest(5).sum()),
                       max_symbol_profit_share=totals[0][0],max_week_profit_share=totals[1][0],
                       ex_each_symbol_positive=totals[0][1],ex_each_week_positive=totals[1][1])
            row['robustness_gate']=(row['top5_removed_total_r']>0 and totals[0][0]<.60 and totals[1][0]<.35 and totals[0][1] and totals[1][1])
        aggregate.append(row)
    result=pd.DataFrame(aggregate)
    for _,idx in result.groupby(['family','target','variant','geometry','calibration']).groups.items():
        ordered=result.loc[idx].sort_values('target_count' if result.loc[idx,'calibration'].iloc[0]!='ABS' else 'policy')
        for j,(i,r) in enumerate(ordered.iterrows()):
            neigh=ordered.iloc[max(0,j-1):j+2].drop(index=i)
            result.loc[i,'adjacent_gate']=bool(neigh.basic_gate.any())
    result['candidate_gate']=result.basic_gate&result.robustness_gate&result.adjacent_gate
    result=result.sort_values(['candidate_gate','min_month_trades','worst_month_ev','total_r'],ascending=False)
    dump(result,output/'candidate_frontier.csv')
    pool=result[result.min_month_trades>=200]
    diagnostic=(pool if len(pool) else result).sort_values(['worst_month_ev','total_r','family','target','variant','geometry','policy'],ascending=[False,False,True,True,True,True,True]).iloc[0].to_dict()
    eligible=result[result.candidate_gate]
    chosen=(eligible.sort_values(['worst_month_ev','total_r'],ascending=False).iloc[0].to_dict() if len(eligible) else None)
    write_json(dict(status='ANALYSIS_COMPLETE',fold_configurations=len(splits),candidate_policies=len(result),
                    passing_candidates=len(eligible),basic_gate_candidates=int(result.basic_gate.sum()),
                    frequency_qualified=int((result.min_month_trades>=200).sum()),
                    selected_candidate=chosen,diagnostic_candidate=diagnostic,
                    ea_created=False,holdout_outcomes_read=False),output/'selection.json')
    print(f'Summary: {len(splits)} folds; {len(eligible)} passing candidates.',flush=True)


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=OUT)
    p.add_argument('--workers',type=int,default=3);p.add_argument('--prepare-only',action='store_true')
    p.add_argument('--summarize-only',action='store_true');p.add_argument('--resume',action='store_true')
    p.add_argument('--limit',type=int,default=0)
    args=p.parse_args(); output=args.output
    if args.summarize_only:
        summarize(output);return
    if not args.resume:
        prepare(output)
    else:
        env=json.loads((output/'environment.json').read_text())
        assert env['analysis_source_sha256']==sha(__file__),'Resume refuses changed analyzer'
        for r in pd.read_csv(output/'input_hashes.csv').itertuples():
            assert sha(ROOT/r.path)==r.sha256
    if args.prepare_only:return
    tasks=[(fam,target,variant,g,month) for fam in FAMILIES for target in TARGETS for variant in VARIANTS for g in GEOMETRIES for month in MONTHS]
    if args.limit:tasks=tasks[:args.limit]
    started=time.perf_counter()
    with ProcessPoolExecutor(max_workers=args.workers,initializer=init_worker,initargs=(output/'dataset.pkl',)) as executor:
        futures={executor.submit(run_task,t,str(output)):t for t in tasks}
        for n,future in enumerate(as_completed(futures),1):
            ident,elapsed=future.result()
            print(f'{n}/{len(tasks)} {ident} {elapsed}s',flush=True)
            write_json(dict(status='RUNNING',completed=n,total=len(tasks),elapsed_seconds=time.perf_counter()-started,
                            latest=ident,holdout_outcomes_read=False),output/'progress.json')
    if not args.limit:summarize(output)


if __name__=='__main__':
    main()
