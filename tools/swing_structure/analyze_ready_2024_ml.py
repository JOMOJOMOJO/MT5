"""Fixed-model purged chronological diagnostics; no search or trading changes."""
from pathlib import Path
import json,platform,hashlib,copy
import numpy as np
import pandas as pd
import sklearn,lightgbm
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler,OneHotEncoder
from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier,export_text
from sklearn.metrics import (roc_auc_score,average_precision_score,balanced_accuracy_score,brier_score_loss,
                             precision_recall_curve,auc,silhouette_score,adjusted_rand_score)
from sklearn.inspection import permutation_importance
from sklearn.cluster import KMeans
from sklearn.decomposition import PCA
from lightgbm import LGBMClassifier
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/qa/three_wave/ready_2024_ml'
EDGES=[0,.35,.40,.45,.50,.55,.60,1.00000001]
LABELS=['<0.35','0.35-0.40','0.40-0.45','0.45-0.50','0.50-0.55','0.55-0.60','>=0.60']

# Explicit feature allowlist is fixed before observing model results.
FEATURES=['nearest_resistance_R','m5_wave1_distance_R','resistance_count_before_tp',
 'wave1_strength_atr_choch','wave1_strength_atr_formation','wave1_strength_atr_confirmation','wave1_strength_atr',
 'wave1_minutes','wave1_bullish_fraction','wave1_bullish_body_share','wave1_er','wave1_max_drawdown_range',
 'wave1_max_drawdown_formation_atr','wave1_running_high_drawdown_atr','wave1_max_consecutive_bearish','wave1_body_ratio',
 'wave1_mean_clv','wave1_high_close_fraction','wave1_first_half_speed_atr','wave1_second_half_speed_atr','wave1_acceleration',
 'm5_choch_break_atr','wave1_choch_body_atr','setup_age_minutes','m5_choch_to_ready_minutes','wave2_retrace',
 'wave2_max_pullback_atr','wave2_m5_bars','wave2_lower_high_count','wave2_higher_low_count','wave2_failed_high_tests',
 'wave2_wave1_retests','wave2_atr_ratio','ready_return_high','m1_wave1_strength','m1_wave1_efficiency','m1_wave2_retrace',
 'hour_sin','hour_cos','weekday_sin','weekday_cos','spread_R','spread_m1_atr']
for tf in ['m15','h1']:
    FEATURES += [tf+'_'+c for c in ['regime','position','raw_position','range_location','last_break_direction','minutes_since_break',
        'break_distance_atr','recent_up_swing_atr','recent_down_swing_atr','up_down_swing_ratio','up_swing_vs_previous',
        'down_swing_vs_previous','atr_state','nearest_resistance_R','nearest_support_R',
        'high_line_slope_atr_per_hour','low_line_slope_atr_per_hour','high_line_entry_distance_atr','low_line_entry_distance_atr']]
for n in [5,10,20]:
    FEATURES += [f'window{n}_'+c for c in ['net_return_atr','range_atr','realized_movement_atr','compression_ratio','bullish_fraction',
        'higher_lows','lower_lows','higher_highs','failed_high_tests','upper25_fraction','lower25_fraction','entry_position']]

def prep(X):
    cats=list(X.select_dtypes(include=['object','string']).columns);nums=[c for c in X if c not in cats]
    return ColumnTransformer([
        ('num',Pipeline([('impute',SimpleImputer(strategy='median',keep_empty_features=True)),('scale',StandardScaler())]),nums),
        ('cat',Pipeline([('impute',SimpleImputer(strategy='constant',fill_value='UNKNOWN')),('encode',OneHotEncoder(handle_unknown='ignore',sparse_output=False))]),cats)
    ],verbose_feature_names_out=True).set_output(transform='pandas')

def models():
    return {'LOGISTIC_L2':LogisticRegression(C=.1,max_iter=3000,random_state=0),
        **{f'TREE_D{d}':DecisionTreeClassifier(max_depth=d,min_samples_leaf=15,random_state=0) for d in [2,3,4]},
        'LIGHTGBM':LGBMClassifier(n_estimators=100,learning_rate=.03,num_leaves=7,max_depth=3,
            min_child_samples=15,reg_lambda=5,random_state=0,n_jobs=1,deterministic=True,force_col_wise=True,verbosity=-1)}

def perf(g):
    v=g.result_r.dropna();loss=-v[v<0].sum()
    return dict(n=len(g),tp_rate=float(g.target.mean()),expectancy_R=v.mean(),pf=v[v>0].sum()/loss if loss>0 else np.nan)

def scores(y,p):
    pre,rec,_=precision_recall_curve(y,p)
    return dict(roc_auc=roc_auc_score(y,p),pr_auc=average_precision_score(y,p),pr_auc_trapezoid=auc(rec,pre),average_precision=average_precision_score(y,p),
        balanced_accuracy=balanced_accuracy_score(y,np.asarray(p)>=.5),brier=brier_score_loss(y,p))

def desc(v):
    return dict(n=int(v.notna().sum()),mean=v.mean(),median=v.median(),q25=v.quantile(.25),q75=v.quantile(.75))

def basic(x):
    allcols=json.loads((OUT/'all_feature_columns.json').read_text());numeric=[c for c in allcols if pd.api.types.is_numeric_dtype(x[c])]
    stats=[];monthly=[];baselines=[]
    for scope in ['ALL_TESTER_OBSERVED_NOT_VERIFIED','JOURNAL_CLEAN_REAL_TICK']:
        q=x.copy() if scope.startswith('ALL') else x[x.target.notna()].copy()
        q['target']=q.tester_target if scope.startswith('ALL') else q.target
        baselines.append(dict(scope=scope,**perf(q)))
        for month in pd.period_range(x.month.min(),x.month.max(),freq='M').astype(str):
            g=q[q.month.eq(month)];monthly.append(dict(scope=scope,month=month,tp=int(g.target.eq(1).sum()),sl=int(g.target.eq(0).sum()),**perf(g)))
        for c in numeric:
            win=q.loc[q.target.eq(1),c];loss=q.loc[q.target.eq(0),c];sd=np.sqrt((win.var()+loss.var())/2)
            difference=(win.mean()-loss.mean())/sd if sd>0 else np.nan
            for label,v in [('TP',win),('SL',loss)]:stats.append(dict(scope=scope,feature=c,outcome=label,standardized_difference_win_minus_loss=difference,**desc(v)))
    pd.DataFrame(stats).to_csv(OUT/'win_loss_feature_statistics.csv',index=False)
    pd.DataFrame(monthly).to_csv(OUT/'monthly_statistics.csv',index=False)
    pd.DataFrame(baselines).to_csv(OUT/'baseline_statistics.csv',index=False)

def original_feature(encoded):
    short=encoded.split('__',1)[1]
    matches=[c for c in FEATURES if short==c or short.startswith(c+'_')]
    return max(matches,key=len) if matches else short

def main(output=None,dataset='ready_2024_ml_dataset.csv',windows=None):
    global OUT
    if output is not None:OUT=Path(output);OUT.mkdir(parents=True,exist_ok=True)
    x=pd.read_csv(OUT/dataset);x=x.sort_values('entry_msc').reset_index(drop=True)
    assert len(FEATURES)==len(set(FEATURES))
    assert not any(any(t in c for t in ['target','outcome','mfe','mae','exit','future','result']) for c in FEATURES)
    (OUT/'model_features.json').write_text(json.dumps(FEATURES,indent=2))
    basic(x)
    metrics=[];predictions=[];coeff=[];importance=[];group_importance=[];rules=[];used=[];folds=[];leaves=[]
    assignments=[];cluster_stats=[];cluster_profile=[];cluster_quality=[]
    cluster_reference=None;reference_labels={};previous_labels={}
    eligible=x[x.target.notna()].copy();eligible['entry_dt']=pd.to_datetime(eligible.entry_msc,unit='ms')
    if windows is None:
        windows=[(pd.Timestamp(2024,month,1),pd.Timestamp(2024,month,1)+pd.DateOffset(months=2),f'train_Jan_{month-1:02d}_test_{month:02d}_{month+1:02d}') for month in [5,7,9,11]]
    for start,end,fold in windows:
        boundary=start-pd.Timedelta(minutes=15)
        before=eligible[eligible.entry_dt<start]
        test=eligible[(eligible.entry_dt>=start)&(eligible.entry_dt<end)]
        train=before[(pd.to_datetime(before.exit_msc,unit='ms')<boundary)&(before.entry_dt<boundary)]
        train=train[~train.parent_id.isin(test.parent_id)]
        valid=len(train)>=30 and train.target.value_counts().min()>=5 and train.target.nunique()==2 and test.target.nunique()==2
        folds.append(dict(fold=fold,test_start=str(start),test_end=str(end),raw_train=len(before),train_n=len(train),test_n=len(test),
            train_tp=int(train.target.eq(1).sum()),test_tp=int(test.target.eq(1).sum()),purged=len(before)-len(train),status='EVALUATED' if valid else 'INSUFFICIENT_VERIFIED_LABELS'))
        if not valid:continue
        print(f'FOLD {fold} train={len(train)} test={len(test)}',flush=True)
        X=train[FEATURES];T=test[FEATURES];y=train.target.astype(int);z=test.target.astype(int)
        constant=np.repeat(y.mean(),len(test))
        metrics.append(dict(fold=fold,model='TRAIN_PREVALENCE',train_n=len(train),test_n=len(test),**scores(z,constant)))
        for ix,p in zip(test.index,constant):predictions.append(dict(fold=fold,model='TRAIN_PREVALENCE',row_id=ix,probability=p))
        for name,model in models().items():
            print(f'MODEL {fold} {name}',flush=True)
            pipeline=Pipeline([('pre',prep(X)),('model',model)]);pipeline.fit(X,y)
            p=pipeline.predict_proba(T)[:,1]
            metrics.append(dict(fold=fold,model=name,train_n=len(train),test_n=len(test),**scores(z,p)))
            for ix,v in zip(test.index,p):predictions.append(dict(fold=fold,model=name,row_id=ix,probability=v))
            names=list(pipeline['pre'].get_feature_names_out())
            if name=='LOGISTIC_L2':
                for cname,val in zip(names,model.coef_[0]):coeff.append(dict(fold=fold,encoded_feature=cname,feature=original_feature(cname),coefficient=val))
            if name.startswith('TREE'):
                human=copy.deepcopy(model)
                num_names=pipeline['pre'].transformers_[0][2]
                scaler=pipeline['pre'].named_transformers_['num']['scale']
                for node,j in enumerate(human.tree_.feature):
                    if j>=0 and names[j].startswith('num__'):
                        k=num_names.index(names[j][5:])
                        human.tree_.threshold[node]=scaler.mean_[k]+human.tree_.threshold[node]*scaler.scale_[k]
                rules.extend([f'=== {fold} {name} train={len(train)} test={len(test)} ===',
                    'Thresholds below are converted back to original feature units; one-hot categories remain 0/1.',
                    export_text(human,feature_names=[n.removeprefix('num__') for n in names],decimals=5)])
                for c in set(original_feature(names[j]) for j in model.tree_.feature if j>=0):used.append(dict(fold=fold,model=name,feature=c))
                leaf=model.apply(pipeline['pre'].transform(T))
                for node in np.unique(leaf):leaves.append(dict(fold=fold,model=name,leaf=int(node),**perf(test.iloc[np.where(leaf==node)[0]])))
            perm=permutation_importance(pipeline,T,z,scoring='roc_auc',n_repeats=20,random_state=0,n_jobs=1)
            rank=pd.Series(perm.importances_mean,index=FEATURES).rank(ascending=False,method='min')
            for c,mean,std in zip(FEATURES,perm.importances_mean,perm.importances_std):
                importance.append(dict(fold=fold,model=name,feature=c,auc_drop_mean=mean,auc_drop_std=std,rank=rank[c]))
            for group,cols in [('HTF_BOTH',[c for c in FEATURES if c.startswith(('m15_','h1_'))]),
                               ('H1',[c for c in FEATURES if c.startswith('h1_')]),('M15',[c for c in FEATURES if c.startswith('m15_')])]:
                drops=[];rng=np.random.default_rng(0);base=roc_auc_score(z,p)
                for rep in range(20):
                    shuffled=T.copy();order=rng.permutation(len(T));shuffled.loc[:,cols]=T.iloc[order][cols].to_numpy()
                    drops.append(base-roc_auc_score(z,pipeline.predict_proba(shuffled)[:,1]))
                group_importance.append(dict(fold=fold,model=name,group=group,auc_drop_mean=np.mean(drops),auc_drop_std=np.std(drops)))
        # Outcome-blind fit, then overlay outcomes. No k is selected by performance.
        pp=prep(X);A=pp.fit_transform(X);B=pp.transform(T);names=list(pp.get_feature_names_out())
        if cluster_reference is None:cluster_reference=X.copy()
        pca=PCA(n_components=2,random_state=0).fit(A);coords=pca.transform(B)
        for k in range(2,7):
            km=KMeans(n_clusters=k,n_init=20,random_state=0).fit(A);ca=km.labels_;cb=km.predict(B)
            ref_labels=km.predict(pp.transform(cluster_reference))
            ref_ari=adjusted_rand_score(reference_labels[k],ref_labels) if k in reference_labels else np.nan
            prev_ari=adjusted_rand_score(previous_labels[k],ref_labels) if k in previous_labels else np.nan
            if k not in reference_labels:reference_labels[k]=ref_labels
            previous_labels[k]=ref_labels
            ari=[adjusted_rand_score(ca,KMeans(n_clusters=k,n_init=20,random_state=seed).fit_predict(A)) for seed in [1,2]]
            quality=dict(fold=fold,k=k,train_silhouette=silhouette_score(A,ca),test_silhouette=silhouette_score(B,cb) if 1<len(np.unique(cb))<len(B) else np.nan,
                minimum_train_cluster=int(np.bincount(ca,minlength=k).min()),seed_ari_mean=np.mean(ari),
                reference_rows=len(cluster_reference),reference_ari_vs_first=ref_ari,reference_ari_vs_previous=prev_ari)
            cluster_quality.append(quality)
            for scope,frame,labels in [('TRAIN_DESCRIPTIVE',train,ca),('TEST',test,cb)]:
                for index,label in zip(frame.index,labels):assignments.append(dict(fold=fold,k=k,scope=scope,row_id=index,cluster=int(label)))
                for label in range(k):
                    g=frame.iloc[np.where(labels==label)[0]];cluster_stats.append(dict(fold=fold,k=k,scope=scope,cluster=label,**perf(g)))
                    for c in FEATURES:
                        if pd.api.types.is_numeric_dtype(g[c]):cluster_profile.append(dict(fold=fold,k=k,scope=scope,cluster=label,feature=c,median=g[c].median(),n=int(g[c].notna().sum())))
            if k==3:
                fig,ax=plt.subplots(figsize=(7,5));s=ax.scatter(coords[:,0],coords[:,1],c=cb,cmap='tab10',s=45)
                ax.set(xlabel='PC1 (train fit)',ylabel='PC2 (train fit)',title='Fixed k=3: test features only; colors are clusters')
                fig.colorbar(s,ax=ax,label='Cluster');fig.tight_layout();fig.savefig(OUT/'cluster_pca_k3.png',dpi=150);plt.close(fig)
    pd.DataFrame(folds).to_csv(OUT/'walkforward_fold_status.csv',index=False)
    met=pd.DataFrame(metrics);met.to_csv(OUT/'walkforward_metrics.csv',index=False)
    pr=pd.DataFrame(predictions).merge(x[['signal_id','parent_id','month','target','result_r','entry_msc']].reset_index(names='row_id'),on='row_id',validate='many_to_one')
    pr.to_csv(OUT/'walkforward_predictions.csv',index=False)
    co=pd.DataFrame(coeff);co.to_csv(OUT/'logistic_coefficients_by_fold.csv',index=False)
    imp=pd.DataFrame(importance);imp.to_csv(OUT/'permutation_importance_by_fold.csv',index=False)
    imp[imp.model.eq('LIGHTGBM')].to_csv(OUT/'boosting_importance_by_fold.csv',index=False)
    pd.DataFrame(group_importance).to_csv(OUT/'htf_group_importance.csv',index=False)
    (OUT/'decision_tree_rules_by_fold.txt').write_text('\n'.join(rules),encoding='utf-8')
    pd.DataFrame(leaves).to_csv(OUT/'decision_tree_test_leaves.csv',index=False)
    pd.DataFrame(assignments).merge(x[['signal_id','target','result_r']].reset_index(names='row_id'),on='row_id',validate='many_to_one').to_csv(OUT/'cluster_assignments.csv',index=False)
    pd.DataFrame(cluster_stats).to_csv(OUT/'cluster_statistics.csv',index=False)
    pd.DataFrame(cluster_quality).to_csv(OUT/'cluster_quality.csv',index=False)
    pd.DataFrame(cluster_profile).to_csv(OUT/'cluster_profiles.csv',index=False)
    nfold=sum(f['status']=='EVALUATED' for f in folds);stability=[]
    for c in FEATURES:
        cc=co[(co.feature==c)&(co.encoded_feature=='num__'+c)]
        ti={u['fold'] for u in used if u['feature']==c}
        top=imp[imp.model.eq('LIGHTGBM')&imp.feature.eq(c)&imp['rank'].le(10)&imp.auc_drop_mean.gt(0)]
        stability.append(dict(feature=c,evaluated_folds=nfold,logistic_positive_folds=int(cc.coefficient.gt(0).sum()),
            logistic_negative_folds=int(cc.coefficient.lt(0).sum()),logistic_mean_coefficient=cc.coefficient.mean(),
            tree_any_depth_folds=len(ti),boosting_positive_top10_folds=top.fold.nunique(),
            status='INSUFFICIENT_FOLDS' if nfold<2 else 'DESCRIPTIVE_ONLY'))
    pd.DataFrame(stability).to_csv(OUT/'feature_stability.csv',index=False)
    bins=[]
    for (fold,model),g in pr.groupby(['fold','model']):
        category=pd.cut(g.probability,EDGES,labels=LABELS,right=False,include_lowest=True)
        for label in LABELS:
            q=g[category==label];bins.append(dict(fold=fold,model=model,probability_bin=label,predicted_mean=q.probability.mean(),**perf(q)))
    pd.DataFrame(bins).to_csv(OUT/'probability_bin_statistics.csv',index=False)
    fig,axes=plt.subplots(1,2,figsize=(12,4))
    for name,g in pr.groupby('model'):
        b=pd.DataFrame(bins);b=b[(b.model==name)&b.n.gt(0)]
        axes[0].plot(b.predicted_mean,b.tp_rate,'o-',label=name)
        axes[1].hist(g.probability,bins=np.linspace(0,1,11),histtype='step',label=name)
    axes[0].plot([0,1],[0,1],'k--');axes[0].set(xlabel='Predicted TP probability',ylabel='Observed TP fraction',title='Out-of-fold calibration (small n)')
    axes[1].set(xlabel='Predicted TP probability',ylabel='Count',title='Out-of-fold probability distribution');axes[1].legend(fontsize=7)
    fig.tight_layout();fig.savefig(OUT/'calibration.png',dpi=150);plt.close(fig)
    fig,axes=plt.subplots(2,3,figsize=(13,7))
    focus=['wave1_bullish_fraction','wave1_max_drawdown_formation_atr','wave1_mean_clv','window20_upper25_fraction','h1_down_swing_vs_previous','m15_up_swing_vs_previous']
    for ax,c in zip(axes.flat,focus):
        for label,name in [(0,'SL'),(1,'TP')]:
            v=eligible.loc[eligible.target.eq(label),c].dropna().sort_values();ax.step(v,np.arange(1,len(v)+1)/len(v),where='post',label=f'{name} n={len(v)}')
        ax.set(title=c,ylabel='ECDF');ax.legend(fontsize=8)
    fig.tight_layout();fig.savefig(OUT/'feature_distributions.png',dpi=150);plt.close(fig)
    ver={'python':platform.python_version(),'numpy':np.__version__,'pandas':pd.__version__,'sklearn':sklearn.__version__,'lightgbm':lightgbm.__version__,
        'model_input_count':len(FEATURES),'evaluated_folds':nfold,'pycaret_used':False,'shap_used':False,'random_split':False,'hyperparameter_search':False}
    (OUT/'model_audit.json').write_text(json.dumps(ver,indent=2))
    print(met.to_string(index=False));print(pd.DataFrame(folds).to_string(index=False))

if __name__=='__main__':main()
