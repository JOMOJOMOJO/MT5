"""Generated ticks allowed; exclude same-minute dual barrier touches. Fixed annual WF."""
from pathlib import Path
import json,hashlib,platform
import numpy as np
import pandas as pd
from sklearn.pipeline import Pipeline
from sklearn.tree import export_text
import build_ready_2024_ml_dataset as builder
import analyze_ready_2024_ml as base
from analyze_ready_multiyear_ml import fast_permutation

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/qa/three_wave/ready_generated_tick_ml'
OLD=ROOT/'reports/qa/three_wave/ready_multiyear_ml'
PREV=ROOT/'reports/qa/three_wave/ready_2024_ml'

def raw_path(year):
    if year==2023:return ROOT/'reports/qa/three_wave/ready_alternate_broker_ml/bybit_2023_refresh_20261001'
    return (PREV if year==2024 else OLD)/f'annual_{year}'

def ambiguity(row,bars):
    first=int(row.entry_msc//60000*60)
    end=int((row.exit_msc if row.exit_msc>0 else row.last_msc)//60000*60)
    window=bars[(bars.time>=first)&(bars.time<=end)]
    both=window[(window.low<=row.sl+1e-10)&(window.high>=row.tp-1e-10)]
    # Full entry/exit-minute extrema are conservative; no assumed intraminute order.
    return dict(dual_touch_minute=bool(len(both)),first_dual_touch_time=int(both.time.iloc[0]) if len(both) else np.nan,
        checked_m1_bars=len(window),entry_bar_present=bool((window.time==first).any()),
        exit_bar_present=bool((window.time==end).any()),entry_subminute=bool(row.entry_msc%60000))

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in json.loads((OLD/'launch_hashes.json').read_text(encoding='utf-8-sig'))}
    frames=[]
    for year in range(2016,2026):
        dest=OUT/f'features_{year}';path=dest/'ready_2024_ml_dataset.csv'
        if not path.exists():
            print(f'BUILD {year}',flush=True)
            builder.main(raw_path(year),dest)
        x=pd.read_csv(path);bars=pd.read_csv(raw_path(year)/'TW_ml_bars_PERIOD_M1.csv')
        flags=pd.DataFrame([ambiguity(row,bars) for row in x.itertuples()])
        x=pd.concat([x,flags],axis=1).copy()
        x['source_run']=str(raw_path(year).relative_to(ROOT));x['year']=year
        x['real_tick_verified_before']=x.target.notna()
        x['label_exclusion']=np.select([x.dual_touch_minute,~x.outcome.isin(['TP','SL']),~x.entry_bar_present|~x.exit_bar_present],
                                      ['SAME_M1_SL_AND_TP','END_CENSORED','MISSING_BOUNDARY_BAR'],default='INCLUDED')
        x['target']=x.tester_target.where(x.label_exclusion.eq('INCLUDED'))
        x['label_status']=np.where(x.target.notna(),'GENERATED_ALLOWED_NO_DUAL_TOUCH',x.label_exclusion)
        frames.append(x)
        print(f'YEAR {year} candidates={len(x)} dual_touch={x.dual_touch_minute.sum()} eligible={x.target.notna().sum()}',flush=True)
    x=pd.concat(frames,ignore_index=True).sort_values('entry_msc').reset_index(drop=True)
    assert x.signal_id.is_unique
    x.to_csv(OUT/'all_candidates.csv',index=False)
    x[x.target.isna()].to_csv(OUT/'excluded_candidates.csv',index=False)
    eligible=x[x.target.notna()].copy();eligible['entry_dt']=pd.to_datetime(eligible.entry_msc,unit='ms')
    yearly=[];monthly=[]
    for y,g in x.groupby('year'):
        q=g[g.target.notna()]
        yearly.append(dict(year=y,all_candidates=len(g),dual_touch=int(g.dual_touch_minute.sum()),censored=int(g.outcome.eq('END_CENSORED').sum()),
                           other_excluded=int(g.label_exclusion.eq('MISSING_BOUNDARY_BAR').sum()),**base.perf(q)))
    for m in pd.period_range('2016-01','2025-12',freq='M').astype(str):
        g=x[x.month.eq(m)];monthly.append(dict(month=m,all_candidates=len(g),excluded=int(g.target.isna().sum()),**base.perf(g[g.target.notna()])))
    pd.DataFrame(yearly).to_csv(OUT/'yearly_statistics.csv',index=False)
    pd.DataFrame(monthly).to_csv(OUT/'monthly_statistics.csv',index=False)
    predictions=[];metrics=[];folds=[];importance=[];rules=[];checks=[]
    # Two initial years; expanding training; each later calendar year tested once.
    for year in range(2018,2026):
        start=pd.Timestamp(year,1,1);end=pd.Timestamp(year+1,1,1);boundary=start-pd.Timedelta(minutes=15)
        test=eligible[(eligible.entry_dt>=start)&(eligible.entry_dt<end)]
        before=eligible[eligible.entry_dt<start]
        train=before[(before.entry_dt<boundary)&(pd.to_datetime(before.exit_msc,unit='ms')<boundary)]
        train=train[~train.parent_id.isin(test.parent_id)]
        assert train.entry_msc.max()<test.entry_msc.min() and not set(train.parent_id)&set(test.parent_id)
        folds.append(dict(year=year,train_n=len(train),test_n=len(test),purged=len(before)-len(train)))
        X=train[base.FEATURES];T=test[base.FEATURES];y=train.target.astype(int);z=test.target.astype(int)
        p=np.repeat(y.mean(),len(test))
        metrics.append(dict(year=year,model='TRAIN_PREVALENCE',**base.scores(z,p)))
        for ix,v in zip(test.index,p):predictions.append(dict(year=year,model='TRAIN_PREVALENCE',row_id=ix,probability=v))
        for name,model in base.models().items():
            print(f'MODEL {year} {name} train={len(train)} test={len(test)}',flush=True)
            pipeline=Pipeline([('pre',base.prep(X)),('model',model)]).fit(X,y)
            p=pipeline.predict_proba(T)[:,1]
            repeat=Pipeline([('pre',base.prep(X)),('model',base.models()[name])]).fit(X,y).predict_proba(T)[:,1]
            np.testing.assert_allclose(p,repeat,rtol=0,atol=1e-12)
            checks.append(dict(year=year,model=name,repeat='PASS'))
            metrics.append(dict(year=year,model=name,**base.scores(z,p)))
            for ix,v in zip(test.index,p):predictions.append(dict(year=year,model=name,row_id=ix,probability=v))
            if name=='LIGHTGBM':
                perm=fast_permutation(pipeline,T,z,'roc_auc',20,0,1)
                for c,v,s in zip(base.FEATURES,perm.importances_mean,perm.importances_std):importance.append(dict(year=year,feature=c,auc_drop=v,std=s))
            if name=='TREE_D2':rules.extend([f'YEAR {year}; numeric thresholds are TRAIN-standardized (diagnostic only)',export_text(model,feature_names=list(pipeline['pre'].get_feature_names_out()))])
    pr=pd.DataFrame(predictions).merge(x[['signal_id','parent_id','month','target','result_r','entry_msc','real_tick_verified_before']].reset_index(names='row_id'),on='row_id',validate='many_to_one')
    pr.to_csv(OUT/'walkforward_predictions.csv',index=False)
    pd.DataFrame(metrics).to_csv(OUT/'walkforward_metrics.csv',index=False)
    pd.DataFrame(folds).to_csv(OUT/'walkforward_folds.csv',index=False)
    pd.DataFrame(importance).to_csv(OUT/'lightgbm_importance.csv',index=False)
    (OUT/'decision_tree_diagnostic.txt').write_text('\n'.join(rules),encoding='utf-8')
    pooled=[];bins=[]
    for name,g in pr.groupby('model'):
        pooled.append(dict(model=name,**base.scores(g.target,g.probability),**base.perf(g)))
        cat=pd.cut(g.probability,base.EDGES,labels=base.LABELS,right=False)
        for label in base.LABELS:
            q=g[cat==label];bins.append(dict(model=name,bin=label,predicted_mean=q.probability.mean(),**base.perf(q)))
    pd.DataFrame(pooled).to_csv(OUT/'pooled_metrics.csv',index=False)
    pd.DataFrame(bins).to_csv(OUT/'probability_bins.csv',index=False)
    stats=[]
    for year,g in eligible.groupby('year'):
        for c in base.FEATURES:
            if pd.api.types.is_numeric_dtype(g[c]):
                w=g.loc[g.target.eq(1),c];l=g.loc[g.target.eq(0),c]
                stats.append(dict(year=year,feature=c,tp_mean=w.mean(),sl_mean=l.mean(),difference=w.mean()-l.mean(),tp_n=w.notna().sum(),sl_n=l.notna().sum()))
    pd.DataFrame(stats).to_csv(OUT/'period_feature_statistics.csv',index=False)
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items())
    (OUT/'audit.json').write_text(json.dumps(dict(candidates=len(x),eligible=len(eligible),dual_touch=int(x.dual_touch_minute.sum()),
        production_unchanged=True,source_hashes=hashes,features=base.FEATURES,repeat_checks=checks,
        split='2016-2017 initial train, expanding annual 2018-2025 tests; known historical data, not untouched OOS',
        outcome_exclusion_is_retrospective=True,python=platform.python_version()),indent=2))
    print(pd.DataFrame(yearly).to_string(index=False),flush=True)
    print(pd.DataFrame(pooled).to_string(index=False),flush=True)

if __name__=='__main__':main()
