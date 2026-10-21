"""Five fixed no-clock/no-spread models for RR1 / RR1.2 / abstention."""
from pathlib import Path
import json,hashlib,sys,traceback,re,platform
from datetime import datetime,timezone
import numpy as np
import pandas as pd
from lightgbm import LGBMClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.metrics import roc_auc_score,brier_score_loss,average_precision_score
from threadpoolctl import threadpool_limits
from tsaug import AddNoise
import tsfresh,tsaug
from prepare_ready_rr_choice import OUT,SOURCE,ROOT,FEATURES,prepare
import analyze_ready_2024_ml as base

VARIANTS=['STRUCTURE_LGBM','COMPACT_LGBM','TSFRESH_LGBM','SEQUENCE_LOGISTIC','SEQUENCE_AUG_LOGISTIC']
METADATA=['signal_id','parent_id','year','month','entry_msc','paired_eligible','label_exclusion','reach_class',
          'rr1_result_r','rr12_result_r','rr1_exit_msc','rr12_exit_msc','rr1_outcome','outcome','real_tick_verified_before']

def status(state,detail=''):
    OUT.mkdir(parents=True,exist_ok=True);f=OUT/'status.tmp'
    f.write_text(json.dumps(dict(state=state,detail=detail,updated=datetime.now(timezone.utc).isoformat()),indent=2));f.replace(OUT/'status.json')
    print(state,detail,flush=True)

def past(x,year,parents=()):
    cutoff=int(pd.Timestamp(year,1,1).timestamp()*1000)-900000
    return x[x.paired_eligible&(x.entry_msc<cutoff)&(x.label_known_msc<cutoff)&~x.parent_id.isin(parents)]

def fit_predict(name,train,test,x,seq,auto_cols):
    y=train.reach_class.astype(int).to_numpy();assert set(y)=={0,1,2}
    if name.startswith('SEQUENCE'):
        A=seq[train.index];B=seq[test.index];weights=np.ones(len(A))
        if name=='SEQUENCE_AUG_LOGISTIC':
            noise=AddNoise(scale=.01,normalize=True,seed=20261001).augment(A)
            assert noise.shape==A.shape and np.isfinite(noise).all()
            A=np.concatenate([A,noise]);y=np.tile(y,2);weights=np.full(len(y),.5)
        A=A.reshape(len(A),-1);B=B.reshape(len(B),-1)
        model=Pipeline([('scale',StandardScaler()),('pca',PCA(n_components=16,svd_solver='randomized',random_state=0)),
                        ('model',LogisticRegression(C=.1,max_iter=2000,random_state=0))])
        model.fit(A,y,model__sample_weight=weights);prob=model.predict_proba(B)
    else:
        cols=FEATURES['NO_CLOCK_SPREAD'] if name=='STRUCTURE_LGBM' else FEATURES['COMPACT']
        if name=='TSFRESH_LGBM':cols=cols+auto_cols
        assert not any(c in cols for c in ['hour_sin','hour_cos','weekday_sin','weekday_cos','spread_R','spread_m1_atr','spread_price','entry_msc','year','month'])
        model=Pipeline([('pre',base.prep(train[cols])),('model',LGBMClassifier(n_estimators=100,learning_rate=.03,num_leaves=7,max_depth=3,
            min_child_samples=15,reg_lambda=5,random_state=0,n_jobs=1,deterministic=True,force_col_wise=True,verbosity=-1))])
        model.fit(train[cols],y);prob=model.predict_proba(test[cols])
    np.testing.assert_allclose(prob.sum(axis=1),1,atol=1e-10)
    assert list(model['model'].classes_)==[0,1,2]
    return prob

def choose(e1,e12):
    return np.where(np.maximum(e1,e12)<=0,'SKIP',np.where(e1>=e12,'RR1','RR12'))

def summary_stats(v):
    v=pd.Series(v).dropna();loss=-v[v<0].sum()
    return dict(n=len(v),mean_r=v.mean(),pf=v[v>0].sum()/loss if loss>0 else np.nan,win_rate=(v>0).mean() if len(v) else np.nan,sum_r=v.sum())

def score(pred):
    metrics=[];actions=[]
    for (year,name),g in pred.groupby(['year','model']):
        q=g[g.paired_eligible]
        y1=q.reach_class.gt(0);y12=q.reach_class.eq(2)
        metrics.append(dict(year=year,model=name,n=len(q),auc_1=roc_auc_score(y1,q.p1),auc_12=roc_auc_score(y12,q.p12),
                            brier_1=brier_score_loss(y1,q.p1),brier_12=brier_score_loss(y12,q.p12),
                            rescue_prevalence=q.reach_class.eq(1).mean(),auc_rescue=roc_auc_score(q.reach_class.eq(1),q.p1-q.p12),
                            ap_rescue=average_precision_score(q.reach_class.eq(1),q.p1-q.p12)))
        for action in ['RR1','RR12','SKIP']:
            s=q[q.action.eq(action)];v=s.rr1_result_r if action=='RR1' else (s.rr12_result_r if action=='RR12' else pd.Series(dtype=float))
            actions.append(dict(year=year,model=name,action=action,selected=int(g.action.eq(action).sum()),**summary_stats(v)))
    pd.DataFrame(metrics).to_csv(OUT/'annual_metrics.csv',index=False)
    pd.DataFrame(actions).to_csv(OUT/'action_statistics.csv',index=False)

def replay(pred):
    records=[]
    for (year,name),g in pred.groupby(['year','model']):
        busy=0;cool=0;end=int(pd.Timestamp(int(year)+1,1,1).timestamp()*1000)
        for r in g.sort_values('entry_msc').itertuples():
            result=np.nan;exit_=0
            if r.action=='SKIP':reason='NO_POSITIVE_EXPECTED_R';accepted=False
            elif r.entry_msc<busy:reason='POSITION_OPEN';accepted=False
            elif r.entry_msc<cool:reason='COOLDOWN';accepted=False
            else:
                accepted=True;reason='ACCEPT'
                exit_=r.rr1_exit_msc if r.action=='RR1' else r.rr12_exit_msc
                busy=exit_ if exit_>0 else end;cool=r.entry_msc+900000
                if r.paired_eligible:result=r.rr1_result_r if r.action=='RR1' else r.rr12_result_r
            records.append(dict(year=year,model=name,signal_id=r.signal_id,month=r.month,entry_msc=r.entry_msc,action=r.action,
                accepted=accepted,reason=reason,paired_eligible=r.paired_eligible,exit_msc=exit_,result_r=result))
    ledger=pd.DataFrame(records);ledger.to_csv(OUT/'execution_ledger.csv',index=False)
    annual=[];monthly=[]
    for (year,name),g in ledger.groupby(['year','model']):
        a=g[g.accepted];annual.append(dict(year=year,model=name,accepted=len(a),**summary_stats(a.result_r)))
        for m in range(1,13):
            v=a[a.month.eq(f'{year}-{m:02d}')];monthly.append(dict(year=year,month=f'{year}-{m:02d}',model=name,accepted=len(v),**summary_stats(v.result_r)))
    pd.DataFrame(annual).to_csv(OUT/'execution_statistics.csv',index=False)
    pd.DataFrame(monthly).to_csv(OUT/'monthly_execution.csv',index=False)
    return ledger

def bootstrap(pred,repeats=1000):
    ref=pred[(pred.model=='ALWAYS_RR12')&pred.paired_eligible].sort_values('signal_id').reset_index(drop=True)
    groups={y:[np.flatnonzero(ref.month.eq(f'{y}-{m:02d}')) for m in range(1,13)] for y in sorted(ref.year.unique())}
    rng=np.random.default_rng(20261001)
    samples=[np.concatenate([groups[y][i] for y in groups for i in rng.integers(0,12,12)]) for _ in range(repeats)]
    rows=[]
    for name,g in pred[pred.paired_eligible].groupby('model'):
        g=g.sort_values('signal_id').reset_index(drop=True);assert g.signal_id.equals(ref.signal_id)
        # 0 for abstention is a portfolio opportunity return, never a losing trade label.
        returns=np.where(g.action.eq('RR1'),g.rr1_result_r,np.where(g.action.eq('RR12'),g.rr12_result_r,0.))
        d12=[];d1=[];selected=[]
        for ix in samples:
            d12.append(np.mean(returns[ix]-ref.rr12_result_r.to_numpy()[ix]))
            d1.append(np.mean(returns[ix]-ref.rr1_result_r.to_numpy()[ix]))
            a=ix[g.action.to_numpy()[ix]!='SKIP'];selected.append(np.mean(returns[a]) if len(a) else np.nan)
        def ci(a):
            q=np.asarray(a);q=q[np.isfinite(q)];return np.quantile(q,[.025,.975]) if len(q) else [np.nan,np.nan]
        c12,c1,cs=ci(d12),ci(d1),ci(selected)
        rows.append(dict(model=name,delta_vs_rr12_low=c12[0],delta_vs_rr12_high=c12[1],delta_vs_rr1_low=c1[0],delta_vs_rr1_high=c1[1],
                         selected_mean_low=cs[0],selected_mean_high=cs[1]))
    pd.DataFrame(rows).to_csv(OUT/'month_bootstrap.csv',index=False)

def main():
    if (OUT/'predictions.csv').exists():raise RuntimeError('Existing results must be preserved')
    status('PREPARING')
    if not (OUT/'dataset_audit.json').exists():prepare()
    x=pd.read_csv(OUT/'candidates.csv');a=pd.read_csv(OUT/'automatic_features.csv')
    a.columns=['signal_id']+['af_'+re.sub('[^A-Za-z0-9_]','_',c) for c in a.columns[1:]]
    assert a.columns.is_unique
    x=x.merge(a,on='signal_id',validate='one_to_one').sort_values('entry_msc').reset_index(drop=True)
    archive=np.load(OUT/'sequences.npz');seq=archive['values'];assert np.array_equal(archive['signal_ids'],x.signal_id.to_numpy())
    auto_cols=list(a.columns[1:]);source_audit=json.loads((SOURCE/'audit.json').read_text());hashes=source_audit['source_hashes']
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items())
    manifest=dict(variants=VARIANTS,structure_features=FEATURES['NO_CLOCK_SPREAD'],compact_features=FEATURES['COMPACT'],automatic_features=auto_cols,
        source_sha256=hashlib.sha256((SOURCE/'all_candidates.csv').read_bytes()).hexdigest(),production_hashes=hashes,
        tsfresh=tsfresh.__version__,python=platform.python_version(),tsaug='0.2.1',augmentation='one training-only normalized noise copy, scale .01, each weight .5',
        class_definitions={'0':'SL_BEFORE_1R','1':'1R_THEN_SL_BEFORE_1P2R','2':'1P2R_BEFORE_SL'},hour_spread_features_removed=True,
        years=list(range(2018,2026)),threshold_search=False,calibration='multinomial logistic on previous 1-2 years OOF only',
        script_hashes={f:hashlib.sha256((Path(__file__).parent/f).read_bytes()).hexdigest() for f in ['prepare_ready_rr_choice.py','run_ready_rr_choice.py','report_ready_rr_choice.py']})
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    predictions=[];calibration=[];checks=[]
    for year in range(2018,2026):
        test=x[x.year==year];train=past(x,year,test.parent_id)
        losses={c:float(train.loc[train.reach_class.eq(c),'rr12_result_r'].mean()) for c in [0,1]}
        assert all(np.isfinite(v) and v<0 for v in losses.values())
        for name in VARIANTS:
            status('TRAINING',f'{year} {name}')
            probs=[];labels=[]
            for vy in range(max(2017,year-2),year):
                valid=train[train.year==vy];previous=past(x,vy,test.parent_id.tolist()+valid.parent_id.tolist())
                assert previous.label_known_msc.max()<valid.entry_msc.min()
                ip=fit_predict(name,previous,valid,x,seq,auto_cols);probs.append(ip);labels.extend(valid.reach_class.astype(int))
                calibration.append(dict(year=year,model=name,validation_year=vy,train_n=len(previous),valid_n=len(valid),
                    train_max_known=int(previous.label_known_msc.max()),valid_min_entry=int(valid.entry_msc.min()),synthetic_rows=len(previous) if name=='SEQUENCE_AUG_LOGISTIC' else 0))
            cal=LogisticRegression(C=1.,max_iter=2000,random_state=0).fit(np.log(np.clip(np.vstack(probs),1e-6,1)),labels)
            raw=fit_predict(name,train,test,x,seq,auto_cols);p=cal.predict_proba(np.log(np.clip(raw,1e-6,1)))
            p1=p[:,1]+p[:,2];p12=p[:,2];assert (p1>=p12).all()
            payoff1=(test.rr1_tp-test.entry)/test.risk;payoff12=(test.tp-test.entry)/test.risk
            e1=p1*payoff1+p[:,0]*losses[0]
            e12=p12*payoff12+p[:,0]*losses[0]+p[:,1]*losses[1]
            z=test[METADATA].copy();z['model']=name;z['p1']=p1;z['p12']=p12;z['e1']=e1;z['e12']=e12;z['action']=choose(e1,e12);predictions.append(z)
            if year==2025:
                rp=fit_predict(name,train,test,x,seq,auto_cols);np.testing.assert_allclose(raw,rp,atol=1e-12,rtol=0);checks.append(name+'_REPEAT_PASS')
        proportions=train.reach_class.value_counts(normalize=True)
        for name,action in [('ALWAYS_RR1','RR1'),('ALWAYS_RR12','RR12')]:
            z=test[METADATA].copy();z['model']=name;z['p1']=proportions[1]+proportions[2];z['p12']=proportions[2]
            z['e1']=np.nan;z['e12']=np.nan;z['action']=action;predictions.append(z)
    pred=pd.concat(predictions,ignore_index=True);pred.to_csv(OUT/'predictions.csv',index=False)
    pd.DataFrame(calibration).to_csv(OUT/'calibration_splits.csv',index=False)
    status('SCORING');score(pred);ledger=replay(pred)
    status('BOOTSTRAP');bootstrap(pred)
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items())
    audit=dict(production_unchanged=True,original_candidates=len(x),original_paired_labels=int(x.paired_eligible.sum()),
        outer_candidates=pred.signal_id.nunique(),outer_paired_labels=pred.loc[pred.paired_eligible,'signal_id'].nunique(),
        QA=checks,augmentation_not_used_in_validation=True,independent_sample_count_not_inflated=True)
    (OUT/'audit.json').write_text(json.dumps(audit,indent=2))
    from report_ready_rr_choice import main as report
    report(OUT);status('COMPLETE_AWAITING_REVIEW','No production EA changes')

def smoke():
    assert choose(np.array([.1,-.2,.1]),np.array([.2,-.1,.1])).tolist()==['RR12','SKIP','RR1']
    assert np.isfinite(AddNoise(scale=.01,normalize=True,seed=1).augment(np.zeros((3,32,12)))).all()
    print('CHOICE / AUGMENTATION SMOKE PASS')

if __name__=='__main__':
    if '--smoke' in sys.argv:smoke()
    else:
        try:
            with threadpool_limits(limits=1):main()
        except Exception:
            OUT.mkdir(parents=True,exist_ok=True);(OUT/'error.txt').write_text(traceback.format_exc(),encoding='utf-8');status('FAILED',str(sys.exc_info()[1]));raise
