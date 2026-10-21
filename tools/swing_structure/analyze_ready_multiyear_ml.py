"""Fixed 2025 quarterly walk-forward on verified labels; historical candidate inventory."""
from pathlib import Path
import json,hashlib
import numpy as np
import pandas as pd
from sklearn.metrics import roc_auc_score
from sklearn.utils import Bunch
import analyze_ready_2024_ml as base

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/qa/three_wave/ready_multiyear_ml'
PREVIOUS=ROOT/'reports/qa/three_wave/ready_2024_ml'
ANALYSIS=OUT/'analysis'
EQUIVALENCE=[]

def inventory():
    frames=[];rows=[]
    for year in range(2016,2026):
        p=(PREVIOUS if year==2024 else OUT)/f'annual_{year}'
        quality=json.loads((p/'collection_quality.json').read_text())
        q=pd.read_csv(p/'candidate_tick_quality.csv');x=pd.read_csv(p/'TW_ready_shadows.csv')
        q=x.merge(q,on=['signal_id','entry_msc'],validate='one_to_one')
        q['year']=year;q['source_run']=str(p.relative_to(ROOT));q['parent_id']=q.signal_id.str.split('/').str[0]
        q['target']=q.outcome.map({'TP':1,'SL':0}).where(q.training_label_available)
        frames.append(q);v=q[q.training_label_available]
        def pf(z):
            r=z.result_r.dropna();loss=-r[r<0].sum();return r[r>0].sum()/loss if loss>0 else np.nan
        rows.append(dict(year=year,candidates=len(q),verified_labels=len(v),tester_tp=int(q.outcome.eq('TP').sum()),tester_sl=int(q.outcome.eq('SL').sum()),
            censored=int(q.outcome.eq('END_CENSORED').sum()),tester_expectancy_R=q.result_r.mean(),tester_pf=pf(q),
            verified_expectancy_R=v.result_r.mean(),verified_pf=pf(v),real_tick_begin=quality['real_tick_begin']))
    allrows=pd.concat(frames,ignore_index=True)
    assert allrows.signal_id.is_unique
    allrows.to_csv(OUT/'all_years_candidate_inventory.csv',index=False)
    pd.DataFrame(rows).to_csv(OUT/'yearly_collection_statistics.csv',index=False)
    return allrows

def fast_permutation(pipeline,X,y,scoring,n_repeats,random_state,n_jobs):
    assert scoring=='roc_auc'
    pp=pipeline['pre'];model=pipeline['model'];A=pp.transform(X)
    names=list(A.columns);groups={c:[n for n in names if base.original_feature(n)==c] for c in X}
    baseline=roc_auc_score(y,model.predict_proba(A)[:,1]);result=np.zeros((len(X.columns),n_repeats))
    rng=np.random.default_rng(random_state);orders=[rng.permutation(len(X)) for _ in range(n_repeats)]
    weights=getattr(model,'feature_importances_',None)
    for i,c in enumerate(X):
        cols=groups[c];assert cols,c
        if weights is not None and all(weights[names.index(n)]==0 for n in cols):continue
        for j,order in enumerate(orders):
            B=A.copy();B.loc[:,cols]=A.iloc[order][cols].to_numpy()
            pred=model.predict_proba(B)[:,1]
            if j==0 and c in ['nearest_resistance_R','m15_regime','h1_nearest_resistance_R']:
                raw=X.copy();raw[c]=X.iloc[order][c].to_numpy()
                np.testing.assert_allclose(pred,pipeline.predict_proba(raw)[:,1],rtol=0,atol=1e-12)
                EQUIVALENCE.append(dict(model=type(model).__name__,feature=c,n=len(X),result='PASS'))
            result[i,j]=baseline-roc_auc_score(y,pred)
    return Bunch(importances_mean=result.mean(axis=1),importances_std=result.std(axis=1),importances=result)

def main():
    ANALYSIS.mkdir(exist_ok=True)
    allrows=inventory()
    x0=pd.read_csv(PREVIOUS/'ready_2024_ml_dataset.csv')
    x1=pd.read_csv(OUT/'features_2025/ready_2024_ml_dataset.csv')
    assert list(x0)==list(x1)
    assert json.loads((PREVIOUS/'all_feature_columns.json').read_text())==json.loads((OUT/'features_2025/all_feature_columns.json').read_text())
    x=pd.concat([x0,x1],ignore_index=True).copy();x['year']=pd.to_datetime(x.entry_msc,unit='ms').dt.year
    q=x.merge(allrows[['signal_id','target']],on='signal_id',suffixes=('','_inventory'),validate='one_to_one')
    np.testing.assert_allclose(q.target,q.target_inventory,rtol=0,atol=0,equal_nan=True)
    x.to_csv(ANALYSIS/'ready_multiyear_ml_dataset.csv',index=False)
    (ANALYSIS/'all_feature_columns.json').write_text((PREVIOUS/'all_feature_columns.json').read_text())
    assert base.FEATURES==json.loads((PREVIOUS/'model_features.json').read_text())
    base.permutation_importance=fast_permutation
    windows=[(pd.Timestamp(2025,m,1),pd.Timestamp(2025,m,1)+pd.DateOffset(months=3),f'2025Q{1+(m-1)//3}') for m in [1,4,7,10]]
    base.main(output=ANALYSIS,dataset='ready_multiyear_ml_dataset.csv',windows=windows)
    (ANALYSIS/'permutation_equivalence.json').write_text(json.dumps(EQUIVALENCE,indent=2))
    predictions=pd.read_csv(ANALYSIS/'walkforward_predictions.csv');pooled=[];quarter_bins=[]
    for model,g in predictions.groupby('model'):
        pooled.append(dict(model=model,**base.scores(g.target,g.probability),**base.perf(g)))
        bins=pd.cut(g.probability,base.EDGES,labels=base.LABELS,right=False,include_lowest=True)
        for b in base.LABELS:
            z=g[bins==b];quarter_bins.append(dict(model=model,probability_bin=b,predicted_mean=z.probability.mean(),**base.perf(z)))
    pd.DataFrame(pooled).to_csv(ANALYSIS/'pooled_oof_metrics.csv',index=False)
    pd.DataFrame(quarter_bins).to_csv(ANALYSIS/'pooled_probability_bins.csv',index=False)
    checks=json.loads((OUT/'launch_hashes.json').read_text(encoding='utf-8-sig'))
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest().upper()==v for p,v in checks.items())
    (ANALYSIS/'final_audit.json').write_text(json.dumps(dict(all_year_candidates=len(allrows),verified_labels=int(allrows.target.notna().sum()),
        model_dataset_rows=len(x),oof_unique_candidates=predictions.signal_id.nunique(),production_hashes_unchanged=True,
        model_features_unchanged=True,permutation_equivalence_checks=len(EQUIVALENCE)),indent=2))
    print(pd.DataFrame(pooled).to_string(index=False),flush=True)

if __name__=='__main__':main()
