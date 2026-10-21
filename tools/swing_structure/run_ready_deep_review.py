"""Fixed, past-only ML diagnostics. No production changes and no threshold search."""
from pathlib import Path
import argparse,hashlib,json,traceback,sys,platform
from datetime import datetime,timezone
import numpy as np
import pandas as pd
from sklearn.pipeline import Pipeline
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score,brier_score_loss,mean_squared_error
from lightgbm import LGBMRegressor
import analyze_ready_2024_ml as base

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'reports/qa/three_wave/ready_generated_tick_ml'
OUT=ROOT/'reports/qa/three_wave/ready_generated_tick_deep_review'
COMPACT=['nearest_resistance_R','m5_wave1_distance_R','resistance_count_before_tp',
 'wave1_strength_atr_formation','wave1_minutes','wave1_er','wave1_bullish_fraction','wave1_max_drawdown_range','m5_choch_break_atr',
 'setup_age_minutes','wave2_retrace','wave2_m5_bars','ready_return_high','m1_wave1_strength','m1_wave1_efficiency','m1_wave2_retrace',
 'm15_regime','m15_raw_position','m15_minutes_since_break','m15_nearest_resistance_R','h1_regime','h1_raw_position','h1_nearest_resistance_R',
 'window10_compression_ratio','window10_upper25_fraction']
FRICTION_CLOCK=['hour_sin','hour_cos','weekday_sin','weekday_cos','spread_R','spread_m1_atr']
GEOMETRY=['risk_over_m1_atr','entry_minus_m1_h1_R','minutes_since_m1_hl_confirmation','minutes_since_m1_choch']
FEATURES={'FULL':base.FEATURES,'NO_CLOCK_SPREAD':[c for c in base.FEATURES if c not in FRICTION_CLOCK],'COMPACT':COMPACT+GEOMETRY}
META=['signal_id','parent_id','year','month','entry_msc','exit_msc','last_msc','outcome','result_r','target','label_exclusion','real_tick_verified_before']

def status(state,detail=''):
    OUT.mkdir(parents=True,exist_ok=True)
    data=dict(state=state,detail=detail,updated=datetime.now(timezone.utc).isoformat())
    tmp=OUT/'status.tmp';tmp.write_text(json.dumps(data,indent=2));tmp.replace(OUT/'status.json')
    print(state,detail,flush=True)

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def add_entry_geometry(x):
    x=x.copy();x['risk_over_m1_atr']=x.risk/x.m1_atr14
    x['entry_minus_m1_h1_R']=(x.entry-x.m1_wave1_high)/x.risk
    now=pd.to_datetime(x.entry_msc,unit='ms')
    for field,source in [('minutes_since_m1_hl_confirmation','m1_wave2_confirmed'),('minutes_since_m1_choch','m1_choch_time')]:
        ts=pd.to_datetime(x[source]);assert ts.notna().all() and (ts<=now).all()
        x[field]=(now-ts).dt.total_seconds()/60
    assert np.isfinite(x[GEOMETRY].to_numpy()).all()
    return x

def train_at(x,year,parents=()):
    boundary=int(pd.Timestamp(year,1,1).timestamp()*1000)-900000
    return x[x.target.notna()&(x.entry_msc<boundary)&(x.exit_msc>0)&(x.exit_msc<boundary)&~x.parent_id.isin(parents)]

def pipeline(cols,regression=False):
    if regression:
        model=LGBMRegressor(n_estimators=100,learning_rate=.03,num_leaves=7,max_depth=3,min_child_samples=15,
                            reg_lambda=5,random_state=0,n_jobs=1,deterministic=True,force_col_wise=True,verbosity=-1)
    else:model=base.models()['LIGHTGBM']
    return Pipeline([('pre',base.prep(cols)),('model',model)])

def logit(p):
    q=np.clip(p,1e-6,1-1e-6);return np.log(q/(1-q)).reshape(-1,1)

def metrics(g):
    q=g[g.target.notna()];score=q.probability if q.probability.notna().all() else q.expected_r
    return dict(n=len(q),roc_auc=roc_auc_score(q.target,score) if q.target.nunique()==2 else np.nan,
        brier=brier_score_loss(q.target,q.probability) if len(q) and q.probability.notna().all() else np.nan,
        rmse_r=np.sqrt(mean_squared_error(q.result_r,q.expected_r)) if len(q) else np.nan)

def perf(g):
    q=g[g.target.notna()];v=q.result_r;loss=-v[v<0].sum()
    return dict(n=len(q),mean_r=v.mean(),pf=v[v>0].sum()/loss if loss>0 else np.nan,win_rate=q.target.mean(),avg_per_month=len(q)/12)

def execution(pred,output=OUT):
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    ledgers=[];stats=[];monthly=[]
    # Annual reset matches the independent annual native runs; no invented censored exit.
    for (year,model),g in pred.groupby(['year','model']):
        busy_until=0;cool_until=0;end=int(pd.Timestamp(int(year)+1,1,1).timestamp()*1000)
        records=[]
        for r in g.sort_values('entry_msc').itertuples():
            if model!='ALL_READY' and r.expected_r<=0:action='SKIP';reason='NONPOSITIVE_EXPECTED_R'
            elif r.entry_msc<busy_until:action='SKIP';reason='POSITION_OPEN'
            elif r.entry_msc<cool_until:action='SKIP';reason='COOLDOWN'
            else:
                action='ACCEPT';reason='FIXED_POSITIVE_EXPECTED_R' if model!='ALL_READY' else 'ALL_READY_BASELINE'
                busy_until=r.exit_msc if r.exit_msc>0 else end
                cool_until=r.entry_msc+900000
            records.append(dict(year=year,model=model,signal_id=r.signal_id,month=r.month,action=action,reason=reason,
                label_exclusion=r.label_exclusion,result_r=r.result_r,scored=bool(pd.notna(r.target)),
                entry_msc=r.entry_msc,exit_msc=r.exit_msc,expected_r=r.expected_r))
        rec=pd.DataFrame(records);acc=rec[rec.action.eq('ACCEPT')];q=acc[acc.scored];v=q.result_r;loss=-v[v<0].sum()
        stats.append(dict(year=year,model=model,accepted=len(acc),scored=len(q),unknown_or_ambiguous=len(acc)-len(q),
            mean_r=v.mean(),pf=v[v>0].sum()/loss if loss>0 else np.nan,avg_per_month=len(acc)/12))
        for m in range(1,13):
            a=acc[acc.month.eq(f'{year}-{m:02d}')]
            monthly.append(dict(year=year,month=f'{year}-{m:02d}',model=model,accepted=len(a),scored=int(a.scored.sum())))
        ledgers.extend(records)
    pd.DataFrame(ledgers).to_csv(output/'execution_ledger.csv',index=False)
    pd.DataFrame(stats).to_csv(output/'execution_statistics.csv',index=False)
    pd.DataFrame(monthly).to_csv(output/'monthly_execution.csv',index=False)

def bootstrap(pred,repeats=1000):
    reference=pred[(pred.model=='TRAIN_BASELINE')&pred.target.notna()].sort_values('signal_id').reset_index(drop=True)
    years=sorted(reference.year.unique());rng=np.random.default_rng(20261001)
    blocks={y:[np.flatnonzero(reference.month.eq(f'{y}-{m:02d}')) for m in range(1,13)] for y in years}
    # Same month-block draws for each model; stratified by year (row weights may vary).
    samples=[np.concatenate([blocks[y][i] for y in years for i in rng.integers(0,12,12)]) for _ in range(repeats)]
    result=[]
    for name,g in pred[(pred.model!='ALL_READY')&pred.target.notna()].groupby('model'):
        g=g.sort_values('signal_id').reset_index(drop=True);assert g.signal_id.equals(reference.signal_id)
        auc_delta=[];brier_delta=[];rs=[]
        for ix in samples:
            q=g.iloc[ix];b=reference.iloc[ix];score=q.probability if q.probability.notna().all() else q.expected_r
            auc_delta.append(roc_auc_score(q.target,score)-roc_auc_score(b.target,b.probability))
            if q.probability.notna().all():brier_delta.append(brier_score_loss(q.target,q.probability)-brier_score_loss(b.target,b.probability))
            rs.append(q.loc[q.expected_r>0,'result_r'].mean())
        def interval(v):
            a=np.asarray(v);a=a[np.isfinite(a)];return np.quantile(a,[.025,.975]) if len(a) else [np.nan,np.nan]
        au=interval(auc_delta);br=interval(brier_delta);er=interval(rs)
        result.append(dict(model=name,auc_delta_low=au[0],auc_delta_high=au[1],brier_delta_low=br[0],brier_delta_high=br[1],
            mean_r_low=er[0],mean_r_high=er[1],repeats=repeats))
    pd.DataFrame(result).to_csv(OUT/'month_block_bootstrap.csv',index=False)

def placebo(x,repeats=30):
    eligible=x[x.target.notna()].copy();rows=[]
    # Shuffle outcome assignment within calendar months. A diagnostic null, not a new strategy search.
    for i in range(repeats):
        status('RUNNING_PLACEBO',f'{i+1}/{repeats}')
        q=eligible.copy();rng=np.random.default_rng(9100+i)
        for _,idx in q.groupby('month').groups.items():q.loc[idx,'target']=rng.permutation(q.loc[idx,'target'].to_numpy())
        yy=[];pp=[]
        for year in range(2018,2026):
            test=q[q.year==year];train=train_at(q,year,test.parent_id)
            p=pipeline(train[base.FEATURES]).fit(train[base.FEATURES],train.target).predict_proba(test[base.FEATURES])[:,1]
            yy.extend(test.target);pp.extend(p)
        rows.append(dict(iteration=i+1,auc=roc_auc_score(yy,pp)))
        pd.DataFrame(rows).to_csv(OUT/'placebo.csv',index=False)

def main():
    if (OUT/'predictions.csv').exists():raise RuntimeError('Preserve completed output; choose a new directory instead of overwriting')
    status('RUNNING_AUDIT')
    x=add_entry_geometry(pd.read_csv(SOURCE/'all_candidates.csv').sort_values('entry_msc').reset_index(drop=True))
    assert len(x)==2091 and x.target.notna().sum()==2083 and x.dual_touch_minute.sum()==4
    assert x.signal_id.is_unique and not x.loc[x.dual_touch_minute,'target'].notna().any()
    old=json.loads((SOURCE/'audit.json').read_text())
    hashes=old['source_hashes'];assert all(sha(ROOT/p)==h for p,h in hashes.items())
    assert len(COMPACT)==25 and all(c in base.FEATURES for c in COMPACT)
    manifest=dict(source_sha256=sha(SOURCE/'all_candidates.csv'),production_hashes=hashes,
        features=FEATURES,regression_features=base.FEATURES,outer_years=list(range(2018,2026)),
        calibration='Platt C=1; inner predictions from prior last 1-2 calendar years; past-only fit',
        hyperparameter_search=False,policy='expected_R > 0 fixed; no threshold tuning',
        script_sha256=sha(__file__),python=platform.python_version())
    manifest['research_dependency_hashes']={name:sha(Path(__file__).parent/name) for name in
        ['analyze_ready_2024_ml.py','report_ready_deep_review.py','run_ready_deep_review.py']}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    x[['signal_id','entry_msc']+GEOMETRY].to_csv(OUT/'additional_entry_geometry.csv',index=False)
    predictions=[];splits=[];calibration=[];checks=[]
    for year in range(2018,2026):
        status('RUNNING_MODELS',str(year))
        test=x[x.year==year].copy();train=train_at(x,year,test.parent_id)
        assert train.entry_msc.max()<test.entry_msc.min()
        means=train.groupby('target').result_r.mean();win=float(means[1]);loss=float(means[0])
        def append(name,p,r):
            z=test[META].copy();z['model']=name;z['probability']=p;z['expected_r']=r;predictions.append(z)
        append('TRAIN_BASELINE',train.target.mean(),train.result_r.mean())
        append('ALL_READY',train.target.mean(),1.)
        for name,cols in FEATURES.items():
            inner_p=[];inner_y=[];inner_ids=[]
            for validation_year in range(max(2017,year-2),year):
                valid=train[train.year==validation_year];past=train_at(x,validation_year,test.parent_id.tolist()+valid.parent_id.tolist())
                assert past.exit_msc.max()<valid.entry_msc.min()
                inner=pipeline(past[cols]).fit(past[cols],past.target)
                p=inner.predict_proba(valid[cols])[:,1];inner_p.extend(p);inner_y.extend(valid.target);inner_ids.extend(valid.signal_id)
                splits.append(dict(outer_year=year,variant=name,validation_year=validation_year,train_n=len(past),valid_n=len(valid),
                    train_max_exit_msc=int(past.exit_msc.max()),valid_min_entry_msc=int(valid.entry_msc.min())))
            calibrator=LogisticRegression(C=1.,max_iter=1000,random_state=0).fit(logit(inner_p),inner_y)
            assert set(inner_ids).isdisjoint(test.signal_id)
            model=pipeline(train[cols]).fit(train[cols],train.target)
            raw=model.predict_proba(test[cols])[:,1];cal=calibrator.predict_proba(logit(raw))[:,1]
            append(name+'_CALIBRATED',cal,cal*win+(1-cal)*loss)
            if name=='FULL':append('FULL_RAW',raw,raw*win+(1-raw)*loss)
            calibration.append(dict(year=year,variant=name,n=len(inner_y),slope=float(calibrator.coef_[0,0]),intercept=float(calibrator.intercept_[0]),
                train_mean_win_R=win,train_mean_loss_R=loss))
            if year==2025:
                repeat=pipeline(train[cols]).fit(train[cols],train.target).predict_proba(test[cols])[:,1]
                np.testing.assert_allclose(raw,repeat,rtol=0,atol=1e-12);checks.append(name+'_REPEAT_PASS')
        cols=base.FEATURES;reg=pipeline(train[cols],True).fit(train[cols],train.result_r)
        expected=reg.predict(test[cols]);append('R_REGRESSION',np.nan,expected)
        if year==2025:
            repeat=pipeline(train[cols],True).fit(train[cols],train.result_r).predict(test[cols])
            np.testing.assert_allclose(expected,repeat,rtol=0,atol=1e-12);checks.append('R_REGRESSION_REPEAT_PASS')
    pred=pd.concat(predictions,ignore_index=True)
    oldpred=pd.read_csv(SOURCE/'walkforward_predictions.csv');oldpred=oldpred[oldpred.model.eq('LIGHTGBM')]
    parity=pred[pred.model.eq('FULL_RAW')&pred.target.notna()].merge(oldpred[['signal_id','probability']],on='signal_id',suffixes=('','_previous'),validate='one_to_one')
    assert len(parity)==1648
    np.testing.assert_allclose(parity.probability,parity.probability_previous,atol=1e-12,rtol=0)
    checks.append('FULL_RAW_PREVIOUS_1648_PREDICTIONS_PARITY_PASS')
    pred.to_csv(OUT/'predictions.csv',index=False)
    pd.DataFrame(splits).to_csv(OUT/'calibration_splits.csv',index=False)
    pd.DataFrame(calibration).to_csv(OUT/'calibration_coefficients.csv',index=False)
    annual=[dict(year=y,model=n,**metrics(g)) for (y,n),g in pred[pred.model!='ALL_READY'].groupby(['year','model'])]
    pd.DataFrame(annual).to_csv(OUT/'annual_metrics.csv',index=False)
    pd.DataFrame([dict(model=n,**metrics(g)) for n,g in pred[pred.model!='ALL_READY'].groupby('model')]).to_csv(OUT/'pooled_metrics.csv',index=False)
    policies=[]
    for (year,name),g in pred.groupby(['year','model']):
        for scope,q in [('ALL',g),('POSITIVE_EXPECTED_R',g[g.expected_r>0])]:policies.append(dict(year=year,model=name,scope=scope,**perf(q)))
    pd.DataFrame(policies).to_csv(OUT/'shadow_policies.csv',index=False)
    status('RUNNING_EXECUTION_DIAGNOSTIC');execution(pred)
    status('RUNNING_MONTH_BOOTSTRAP');bootstrap(pred)
    placebo(x)
    assert sha(SOURCE/'all_candidates.csv')==manifest['source_sha256']
    assert all(sha(ROOT/p)==h for p,h in hashes.items())
    audit=dict(source_hashes=hashes,featurelists=FEATURES,QA=checks,prediction_rows=len(pred),all_outer_candidates=pred.signal_id.nunique(),
        eligible_outer=pred.loc[pred.target.notna(),'signal_id'].nunique(),causal_calibration=True,production_unchanged=True,
        outcome_exclusions_used_for_training_scoring_only=True,execution_is_simplified=True,annual_execution_reset=True,known_period=True)
    (OUT/'audit.json').write_text(json.dumps(audit,indent=2))
    from report_ready_deep_review import main as report
    report(OUT)
    status('COMPLETE_AWAITING_REVIEW','Training and reports complete; no EA changes')

def smoke():
    # Small independent checks; no full research run is started here.
    x=add_entry_geometry(pd.read_csv(SOURCE/'all_candidates.csv'));t=train_at(x,2018)
    assert len(t)==435 and t.target.notna().all()
    assert all(c in x for cols in FEATURES.values() for c in cols)
    a=x[x.year==2017].iloc[:4];m=pipeline(t[COMPACT].iloc[:60]).fit(t[COMPACT].iloc[:60],t.target.iloc[:60]);p=m.predict_proba(a[COMPACT])[:,1]
    assert np.isfinite(p).all()
    origin=int(pd.Timestamp(2020,1,1).timestamp()*1000);rows=[]
    for i,(entry,exit_,label) in enumerate([(0,30,'SAME_M1_SL_AND_TP'),(16,17,'INCLUDED'),(31,32,'INCLUDED'),(33,34,'INCLUDED'),(50,0,'END_CENSORED'),(70,71,'INCLUDED')]):
        rows.append(dict(year=2020,model='SMOKE',signal_id=str(i),month='2020-01',entry_msc=origin+entry*60000,
            exit_msc=origin+exit_*60000 if exit_ else 0,expected_r=.1,label_exclusion=label,result_r=1.2 if exit_ else np.nan,
            target=1 if label=='INCLUDED' else np.nan))
    execution(pd.DataFrame(rows),OUT/'smoke')
    ledger=pd.read_csv(OUT/'smoke/execution_ledger.csv')
    assert ledger.action.tolist()==['ACCEPT','SKIP','ACCEPT','SKIP','ACCEPT','SKIP']
    assert ledger.reason.iloc[1]=='POSITION_OPEN' and ledger.reason.iloc[3]=='COOLDOWN' and ledger.reason.iloc[5]=='POSITION_OPEN'
    assert ledger.scored.tolist()==[False,True,True,True,False,True]
    (OUT/'smoke/qa.json').write_text(json.dumps(dict(schema='PASS',causal_boundary='PASS',new_geometry_finite='PASS',
        classifier='PASS',excluded_position_occupancy='PASS',cooldown='PASS',censored_occupancy='PASS'),indent=2))
    print('SMOKE PASS: schema, boundary, preprocessing, LightGBM, finite prediction')

if __name__=='__main__':
    if '--smoke' in sys.argv:smoke()
    else:
        try:main()
        except Exception:
            OUT.mkdir(parents=True,exist_ok=True);(OUT/'error.txt').write_text(traceback.format_exc(),encoding='utf-8');status('FAILED',str(sys.exc_info()[1]));raise
