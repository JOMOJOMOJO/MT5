"""Report and deterministic prediction QA; no model search or strategy changes."""
from pathlib import Path
import json,hashlib
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from sklearn.pipeline import Pipeline
import analyze_ready_2024_ml as model
from analyze_normal_ready_m15 import markdown

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/qa/three_wave/ready_multiyear_ml'
A=OUT/'analysis'

def main():
    x=pd.read_csv(A/'ready_multiyear_ml_dataset.csv').sort_values('entry_msc').reset_index(drop=True)
    pr=pd.read_csv(A/'walkforward_predictions.csv');folds=pd.read_csv(A/'walkforward_fold_status.csv')
    z=x[x.target.notna()].copy();z['dt']=pd.to_datetime(z.entry_msc,unit='ms')
    checks=[]
    for _,f in folds.iterrows():
        start=pd.Timestamp(f.test_start);end=pd.Timestamp(f.test_end);boundary=start-pd.Timedelta(minutes=15)
        test=z[(z.dt>=start)&(z.dt<end)]
        train=z[(z.dt<boundary)&(pd.to_datetime(z.exit_msc,unit='ms')<boundary)]
        train=train[~train.parent_id.isin(test.parent_id)]
        assert len(train)==f.train_n and len(test)==f.test_n
        for name,estimator in model.models().items():
            pipe=Pipeline([('pre',model.prep(train[model.FEATURES])),('model',estimator)])
            pipe.fit(train[model.FEATURES],train.target.astype(int));p=pipe.predict_proba(test[model.FEATURES])[:,1]
            saved=pr[(pr.fold==f.fold)&(pr.model==name)].set_index('row_id').loc[test.index]
            np.testing.assert_allclose(p,saved.probability,rtol=0,atol=1e-12)
            checks.append(dict(fold=f.fold,model=name,n=len(p),prediction_repeat='PASS'))
    (A/'prediction_repeat_audit.json').write_text(json.dumps(checks,indent=2))
    # Shared source integrity across the entire collection and analysis.
    hashes=json.loads((ROOT/'reports/qa/three_wave/ready_failure_diagnostics/production_hashes_before.json').read_text())
    assert all(hashlib.sha256((ROOT/k).read_bytes()).hexdigest()==v for k,v in hashes.items())
    old=pd.read_csv(ROOT/'reports/qa/three_wave/m15_normal_ready_ema_off/known_2025h1/TW_ready_shadows.csv')
    match=x[x.year.eq(2025)].merge(old,on='signal_id',suffixes=('_new','_old'))
    assert len(match)==len(old)==93
    for c in ['entry_msc','entry','sl','tp','risk']:np.testing.assert_allclose(match[c+'_new'],match[c+'_old'],rtol=0,atol=1e-10)
    (OUT/'collection_review.json').write_text(json.dumps(dict(status='COLLECTION_AND_FIXED_ANALYSIS_REVIEWED',years=list(range(2016,2026)),
        total_candidates=2091,verified_labels=295,recovered_2016=True,reran_MT5=False,source_hashes_unchanged=len(hashes),
        prior_2025h1_entry_sl_tp_parity=93,repeat_model_checks=len(checks)),indent=2))
    yearly=pd.read_csv(OUT/'yearly_collection_statistics.csv');fig,ax=plt.subplots(figsize=(11,4))
    ax.bar(yearly.year,yearly.candidates-yearly.verified_labels,label='Unverified tick labels',color='lightgray')
    ax.bar(yearly.year,yearly.verified_labels,bottom=yearly.candidates-yearly.verified_labels,label='Journal-clean real-tick labels',color='#2878a8')
    ax.set(xticks=yearly.year,ylabel='READY candidates',title='2016-2025: 2091 candidates, 295 verified labels');ax.legend()
    fig.tight_layout();fig.savefig(OUT/'yearly_label_coverage.png',dpi=150);plt.close(fig)
    metrics=pd.read_csv(A/'walkforward_metrics.csv');fig,axes=plt.subplots(1,2,figsize=(12,4))
    for name,g in metrics.groupby('model'):
        axes[0].plot(g.fold,g.roc_auc,'o-',label=name);axes[1].plot(g.fold,g.brier,'o-',label=name)
    axes[0].axhline(.5,color='gray',linestyle='--');axes[0].set(title='Quarterly test ROC-AUC',ylim=(.3,.75))
    axes[1].set(title='Quarterly Brier score (lower is better)');axes[1].legend(fontsize=7)
    fig.tight_layout();fig.savefig(A/'quarterly_model_metrics.png',dpi=150);plt.close(fig)
    # OOF calibration must pool the same fixed bin across folds, not join fold points.
    bins=pd.read_csv(A/'pooled_probability_bins.csv');fig,ax=plt.subplots(figsize=(7,5))
    for name,g in bins.groupby('model'):
        g=g[g.n>0];ax.plot(g.predicted_mean,g.tp_rate,'o-',label=name)
    ax.plot([0,1],[0,1],'k--');ax.set(xlabel='Predicted probability (fixed bin mean)',ylabel='Observed TP fraction',title='2025 pooled out-of-fold calibration');ax.legend(fontsize=7)
    fig.tight_layout();fig.savefig(A/'pooled_calibration.png',dpi=150);fig.savefig(A/'calibration.png',dpi=150);plt.close(fig)
    rows=[];focus=['m1_wave2_retrace','m5_choch_to_ready_minutes','wave1_mean_clv','window20_upper25_fraction','h1_down_swing_vs_previous']
    for quarter,g in x[x.year.eq(2025)].groupby(pd.to_datetime(x.loc[x.year.eq(2025),'entry_msc'],unit='ms').dt.to_period('Q').astype(str)):
        for c in focus:
            w=g.loc[g.target.eq(1),c];l=g.loc[g.target.eq(0),c]
            rows.append(dict(quarter=quarter,feature=c,tp_n=w.count(),sl_n=l.count(),tp_mean=w.mean(),sl_mean=l.mean(),tp_median=w.median(),sl_median=l.median()))
    pd.DataFrame(rows).to_csv(A/'quarterly_hypothesis_statistics.csv',index=False)
    tables=['# Fixed quarterly validation tables','']
    for file in ['walkforward_fold_status','walkforward_metrics','pooled_oof_metrics','pooled_probability_bins','htf_group_importance','cluster_quality']:
        tables+=['## '+file,'',markdown(pd.read_csv(A/(file+'.csv'))),'']
    (A/'tables.md').write_text('\n'.join(tables),encoding='utf-8')
    print('All 20 fixed-model repeat predictions PASS; prior 93 entries unchanged; shared hashes unchanged',flush=True)

if __name__=='__main__':main()
