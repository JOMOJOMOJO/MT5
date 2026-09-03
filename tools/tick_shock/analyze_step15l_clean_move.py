#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import platform
from collections import Counter, defaultdict
from pathlib import Path

import lightgbm
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import scipy
import sklearn
from lightgbm import LGBMClassifier
from scipy.stats import mannwhitneyu
from sklearn.cluster import KMeans
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.inspection import permutation_importance
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (accuracy_score, average_precision_score, balanced_accuracy_score,
                             fbeta_score, precision_score, recall_score, roc_auc_score)
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.tree import DecisionTreeClassifier

SEED=20260903
TOP_COUNTS=(100,200,300,500,800,1000)
RECALL_TARGETS=(.95,.90,.80,.70,.60)
FOLD_BOUNDS=((.00,.40,.40,.55),(.00,.55,.55,.70),(.00,.70,.70,.85),(.00,.85,.85,1.00))

A_NUM=["spread_atr_t0","tick_activity_ratio","atr14_m5","spread_percentile","activity_percentile","atr_percentile",
       "pre_return_5m_dir_atr","m5_ema20_slope_dir_atr","m15_alignment_dir","pre_extension_15m_dir_atr",
       "day_range_position_dir","detection_efficiency","severity","confirmation_retention",
       "spread_efficiency_interaction","flow_efficiency_interaction"]
B_ADD=["return_5s_dir_atr","return_10s_dir_atr","return_30s_dir_atr","return_60s_dir_atr","return_120s_dir_atr","return_300s_dir_atr","return_900s_dir_atr",
       "accel_10s_vs_prev30s","return_30s_vs_prev30s","direction_consistency_30s"]
C_ADD=["spread_5s_atr","spread_10s_atr","spread_30s_atr","spread_change_5s_atr","spread_change_10s_atr","spread_change_30s_atr",
       "ticks_5s","ticks_10s","ticks_30s","ticks_60s","ticks_120s","tick_ratio_5s_prev5s","tick_ratio_30s_prev30s"]
D_ADD=["range_30s_atr","range_60s_atr","range_180s_atr","range_300s_atr","range_900s_atr","range_1800s_atr","range_3600s_atr",
       "realized_abs_30s_atr","realized_abs_60s_atr","realized_abs_180s_atr","realized_abs_300s_atr",
       "range_position_900s_dir","distance_high_900s_dir_atr","distance_low_900s_dir_atr","atr14_m5_slope_3bars"]
E_ADD=["abs_return_10s_atr","shock_to_range_60s","spread_contraction_activity","atr_spread_state","momentum_efficiency_interaction"]
GROUPS={"A_EXISTING":A_NUM,"B_PRICE_LAGS":A_NUM+B_ADD,"C_SPREAD_ACTIVITY":A_NUM+B_ADD+C_ADD,
        "D_MARKET_STRUCTURE":A_NUM+B_ADD+C_ADD+D_ADD,"E_FULL":A_NUM+B_ADD+C_ADD+D_ADD+E_ADD}
BASE_CATS=["shock_direction","session"]

def suffix(value:str)->str:
    i=value.find("_mh_")
    return value[i:] if i>=0 else value

def safe_metric(fn,y,p,default=math.nan):
    try:return float(fn(y,p))
    except ValueError:return default

def model_pipeline(kind:str,numeric:list[str],categorical:list[str])->Pipeline:
    if kind=="LOGISTIC":
        num=Pipeline([("impute",SimpleImputer(strategy="median",keep_empty_features=True)),("scale",StandardScaler())])
        estimator=LogisticRegression(C=1.0,class_weight="balanced",max_iter=2000,random_state=SEED)
    else:
        num=SimpleImputer(strategy="median",keep_empty_features=True)
        if kind=="TREE": estimator=DecisionTreeClassifier(max_depth=3,min_samples_leaf=100,class_weight="balanced",random_state=SEED)
        else: estimator=LGBMClassifier(objective="binary",n_estimators=200,learning_rate=.03,num_leaves=15,max_depth=4,min_child_samples=50,
                                        colsample_bytree=.8,subsample=.8,subsample_freq=1,reg_alpha=1.0,reg_lambda=1.0,class_weight="balanced",
                                        random_state=SEED,n_jobs=1,verbosity=-1)
    prep=ColumnTransformer([("num",num,numeric),("cat",OneHotEncoder(handle_unknown="ignore",sparse_output=False),categorical)],verbose_feature_names_out=True)
    return Pipeline([("prep",prep),("model",estimator)])

def fold_indices(df:pd.DataFrame):
    clusters=(df.groupby("market_cluster_id",as_index=False)["t0_msc"].min().sort_values(["t0_msc","market_cluster_id"])["market_cluster_id"].tolist())
    n=len(clusters);out=[]
    for fold,(_,train_hi,val_lo,val_hi) in enumerate(FOLD_BOUNDS,1):
        train=set(clusters[:int(n*train_hi)]);valid=set(clusters[int(n*val_lo):int(n*val_hi)])
        ti=df.index[df.market_cluster_id.isin(train)].to_numpy();vi=df.index[df.market_cluster_id.isin(valid)].to_numpy();out.append((fold,ti,vi))
    return out

def metrics(y,score,threshold=.5):
    pred=(score>=threshold).astype(int);base=float(np.mean(y))
    return {"episodes":len(y),"positives":int(np.sum(y)),"positive_rate":base,"average_precision":safe_metric(average_precision_score,y,score),
            "roc_auc":safe_metric(roc_auc_score,y,score),"recall":recall_score(y,pred,zero_division=0),"precision":precision_score(y,pred,zero_division=0),
            "f2":fbeta_score(y,pred,beta=2,zero_division=0),"balanced_accuracy":safe_metric(balanced_accuracy_score,y,pred),"accuracy":accuracy_score(y,pred),"selected":int(pred.sum())}

def walk_forward(df,kind,features,with_symbol,target="is_clean_move"):
    cats=BASE_CATS+(["symbol"] if with_symbol else []);rows=[];predictions=[]
    for fold,ti,vi in fold_indices(df):
        train=df.loc[ti];valid=df.loc[vi];pipe=model_pipeline(kind,features,cats);pipe.fit(train[features+cats],train[target])
        score=pipe.predict_proba(valid[features+cats])[:,1];m=metrics(valid[target].to_numpy(),score)
        overlap=len(set(train.market_cluster_id)&set(valid.market_cluster_id));m.update(model=kind,feature_group=next((k for k,v in GROUPS.items() if v==features),"CUSTOM"),with_symbol=with_symbol,fold=fold,
                                                                                       train_episodes=len(train),train_positives=int(train[target].sum()),train_clusters=train.market_cluster_id.nunique(),validation_clusters=valid.market_cluster_id.nunique(),cluster_overlap=overlap)
        rows.append(m)
        for idx,s in zip(vi,score):predictions.append({"row_index":int(idx),"fold":fold,"score":float(s),"model":kind,"feature_group":m["feature_group"],"with_symbol":with_symbol,"target":target})
    return rows,predictions

def pooled_summary(df,preds):
    p=pd.DataFrame(preds);rows=[]
    for keys,g in p.groupby(["model","feature_group","with_symbol","target"]):
        merged=g.merge(df[["is_clean_move","is_clean_continuation","is_clean_reversal"]],left_on="row_index",right_index=True)
        target=keys[3];y=merged[target].to_numpy();m=metrics(y,merged.score.to_numpy());m.update(model=keys[0],feature_group=keys[1],with_symbol=keys[2],target=target,evaluation_scope="POOLED_WALK_FORWARD_OOF",folds=g.fold.nunique(),validation_clusters=df.loc[g.row_index,"market_cluster_id"].nunique());rows.append(m)
    return rows

def frontier(df,preds,model,group,with_symbol,scope):
    p=pd.DataFrame(preds);p=p[(p.model==model)&(p.feature_group==group)&(p.with_symbol==with_symbol)&(p.target=="is_clean_move")].copy();p=p.merge(df,left_on="row_index",right_index=True)
    p=p.sort_values(["score","t0_msc","episode_id"],ascending=[False,True,True]);positive=int(p.is_clean_move.sum());baseline=float(p.is_clean_move.mean());rows=[]
    for count in TOP_COUNTS:
        sub=p.head(min(count,len(p)));captured=int(sub.is_clean_move.sum());rows.append({"evaluation_scope":scope,"frontier_type":"TOP_COUNT","frontier_value":count,"selected":len(sub),"clusters":sub.market_cluster_id.nunique(),"clean_captured":captured,"clean_total":positive,"recall":captured/positive if positive else math.nan,"precision":captured/len(sub) if len(sub) else math.nan,"enrichment":(captured/len(sub))/baseline if len(sub) and baseline else math.nan,"symbol_distribution":";".join(f"{k}:{v}" for k,v in sorted(Counter(sub.symbol).items()))})
    cumulative=p.is_clean_move.cumsum().to_numpy()
    for target in RECALL_TARGETS:
        needed=math.ceil(positive*target);pos=np.flatnonzero(cumulative>=needed);count=int(pos[0]+1) if len(pos) else len(p);sub=p.head(count);captured=int(sub.is_clean_move.sum());rows.append({"evaluation_scope":scope,"frontier_type":"RECALL_TARGET","frontier_value":target,"selected":len(sub),"clusters":sub.market_cluster_id.nunique(),"clean_captured":captured,"clean_total":positive,"recall":captured/positive if positive else math.nan,"precision":captured/len(sub),"enrichment":(captured/len(sub))/baseline if baseline else math.nan,"symbol_distribution":";".join(f"{k}:{v}" for k,v in sorted(Counter(sub.symbol).items()))})
    return rows,p

def bootstrap_mean_diff(df,feature,draws=500):
    z=df[["market_cluster_id","is_clean_move",feature]].dropna();rng=np.random.default_rng(SEED);values=[]
    if z.empty:return math.nan,math.nan
    aggregates=[]
    for _,g in z.groupby("market_cluster_id"):
        pos=g[g.is_clean_move==1][feature];neg=g[g.is_clean_move==0][feature]
        aggregates.append((float(pos.sum()),len(pos),float(neg.sum()),len(neg)))
    agg=np.asarray(aggregates,dtype=float);n=len(agg)
    for _ in range(draws):
        multiplicity=np.bincount(rng.integers(0,n,n),minlength=n).astype(float)
        pos_count=float(multiplicity@agg[:,1]);neg_count=float(multiplicity@agg[:,3])
        if pos_count and neg_count:
            values.append(float((multiplicity@agg[:,0])/pos_count-(multiplicity@agg[:,2])/neg_count))
    return (float(np.quantile(values,.025)),float(np.quantile(values,.975))) if values else (math.nan,math.nan)

def bootstrap_clean_rate(frame,draws=500):
    aggregates=np.asarray([(float(g.is_clean_move.sum()),len(g)) for _,g in frame.groupby("market_cluster_id")],dtype=float)
    if len(aggregates)==0:return math.nan,math.nan
    rng=np.random.default_rng(SEED);rates=[];n=len(aggregates)
    for _ in range(draws):
        multiplicity=np.bincount(rng.integers(0,n,n),minlength=n).astype(float);count=float(multiplicity@aggregates[:,1])
        if count:rates.append(float((multiplicity@aggregates[:,0])/count))
    return (float(np.quantile(rates,.025)),float(np.quantile(rates,.975))) if rates else (math.nan,math.nan)

def main():
    ap=argparse.ArgumentParser();ap.add_argument("--step15k",type=Path,required=True);ap.add_argument("--run-dir",type=Path,required=True);ap.add_argument("--out-dir",type=Path,required=True);a=ap.parse_args();a.out_dir.mkdir(parents=True,exist_ok=True)
    base=pd.read_csv(a.step15k/"episode_tradeable_move_dataset.csv");lag=pd.read_csv(a.run_dir/"clean_move_causal_features.csv");base["join_key"]=base.symbol+base.episode_id.map(suffix);lag["join_key"]=lag.symbol+lag.episode_id.map(suffix)
    lag_keep=["join_key","t0_msc","t0_quote_msc","available_count","future_sources"]
    lag_features=[]
    for c in lag.columns:
        if c.endswith("_available"):
            name=c[:-10];lag[name]=pd.to_numeric(lag[name],errors="coerce").where(lag[c].astype(str).str.lower()=="true");lag_features.append(name);lag_keep.extend([name,name+"_source_msc",c])
    lag=lag[lag_keep].rename(columns={"t0_msc":"lag_t0_msc"});df=base.merge(lag,on="join_key",how="left",validate="one_to_one")
    for c in set(sum(GROUPS.values(),[]))|set(lag_features):
        if c in df:df[c]=pd.to_numeric(df[c],errors="coerce")
    df["is_clean_continuation"]=((df["cont_tp0.40_hit_from_t0_s"]<=900)&(df["cont_tp0.40_pre_mae_atr"]<=.25)).astype(int)
    df["is_clean_reversal"]=((df["rev_tp0.40_hit_from_t0_s"]<=900)&(df["rev_tp0.40_pre_mae_atr"]<=.25)).astype(int);df["is_clean_move"]=((df.is_clean_continuation+df.is_clean_reversal)>0).astype(int)
    df=df[df.analysis_ready.astype(str).str.upper()=="TRUE"].copy().reset_index(drop=True)
    df["abs_return_10s_atr"]=df.return_10s_dir_atr.abs();df["shock_to_range_60s"]=df.return_5s_dir_atr.abs()/df.range_60s_atr.replace(0,np.nan)
    df["spread_contraction_activity"]=-df.spread_change_5s_atr*df.tick_ratio_5s_prev5s;df["atr_spread_state"]=df.atr_percentile*(1-df.spread_percentile);df["momentum_efficiency_interaction"]=df.return_10s_dir_atr*df.detection_efficiency
    export_cols=["episode_id","event_id","join_key","market_cluster_id","symbol","shock_direction","session","t0_msc","feature_source_msc","lag_t0_msc","t0_quote_msc","analysis_ready","relative_state_ready","high_movement_selected","is_clean_move","is_clean_continuation","is_clean_reversal"]+list(dict.fromkeys(sum(GROUPS.values(),[])))
    df[export_cols].to_csv(a.out_dir/"clean_move_ml_dataset.csv",index=False)

    # Univariate and bins precede model interpretation.
    uni=[];bins=[]
    for feature in dict.fromkeys(sum(GROUPS.values(),[])):
        z=df[["is_clean_move","market_cluster_id",feature]].dropna();pos=z[z.is_clean_move==1][feature];neg=z[z.is_clean_move==0][feature]
        if len(pos) and len(neg):
            pooled=math.sqrt(((len(pos)-1)*pos.var(ddof=1)+(len(neg)-1)*neg.var(ddof=1))/max(1,len(pos)+len(neg)-2));std_diff=(pos.mean()-neg.mean())/pooled if pooled>0 else math.nan;u,p=mannwhitneyu(pos,neg,alternative="two-sided");rb=2*u/(len(pos)*len(neg))-1;lo,hi=bootstrap_mean_diff(df,feature)
        else:std_diff=u=p=rb=lo=hi=math.nan
        uni.append({"feature":feature,"count":len(z),"missing":len(df)-len(z),"clean_count":len(pos),"non_clean_count":len(neg),"clean_mean":pos.mean(),"non_clean_mean":neg.mean(),"clean_median":pos.median(),"non_clean_median":neg.median(),"clean_std":pos.std(),"non_clean_std":neg.std(),"standardized_difference":std_diff,"rank_biserial":rb,"mann_whitney_u":u,"mann_whitney_p":p,"cluster_bootstrap_mean_diff_low":lo,"cluster_bootstrap_mean_diff_high":hi})
        try:qbin=pd.qcut(df[feature],5,labels=["Q1","Q2","Q3","Q4","Q5"],duplicates="drop")
        except ValueError:continue
        for name,g in df.assign(_bin=qbin).dropna(subset=["_bin"]).groupby("_bin",observed=True):
            rate_lo,rate_hi=bootstrap_clean_rate(g);bins.append({"feature":feature,"bin":str(name),"episodes":len(g),"clusters":g.market_cluster_id.nunique(),"clean_count":int(g.is_clean_move.sum()),"clean_rate":g.is_clean_move.mean(),"clean_rate_cluster_bootstrap_low":rate_lo,"clean_rate_cluster_bootstrap_high":rate_hi,"relative_risk":g.is_clean_move.mean()/df.is_clean_move.mean()})
    pd.DataFrame(uni).to_csv(a.out_dir/"feature_univariate_summary.csv",index=False);pd.DataFrame(bins).to_csv(a.out_dir/"feature_bin_summary.csv",index=False)

    all_fold=[];all_pred=[]
    for group,features in GROUPS.items():
        for kind in ("LOGISTIC","TREE","LIGHTGBM"):
            rows,preds=walk_forward(df,kind,features,False);all_fold+=rows;all_pred+=preds
    for kind in ("LOGISTIC","TREE","LIGHTGBM"):
        rows,preds=walk_forward(df,kind,GROUPS["E_FULL"],True);all_fold+=rows;all_pred+=preds
    fold_df=pd.DataFrame(all_fold);fold_df.to_csv(a.out_dir/"walk_forward_results.csv",index=False);model_df=pd.DataFrame(pooled_summary(df,all_pred));model_df.to_csv(a.out_dir/"model_comparison.csv",index=False)
    oof=pd.DataFrame(all_pred).merge(df[["episode_id","market_cluster_id","symbol","t0_msc","is_clean_move"]],left_on="row_index",right_index=True)
    oof.to_csv(a.out_dir/"model_oof_predictions.csv",index=False)

    # Development-only refit scores answer the compression question over all 188
    # positives. They are never reported as validation performance.
    refit_pred=[]
    for kind,with_symbol in (("LOGISTIC",False),("TREE",False),("LIGHTGBM",False),("LIGHTGBM",True)):
        cats=BASE_CATS+(["symbol"] if with_symbol else []);pipe=model_pipeline(kind,GROUPS["E_FULL"],cats)
        pipe.fit(df[GROUPS["E_FULL"]+cats],df.is_clean_move);score=pipe.predict_proba(df[GROUPS["E_FULL"]+cats])[:,1]
        for idx,s in zip(df.index,score):refit_pred.append({"row_index":int(idx),"fold":0,"score":float(s),"model":kind,"feature_group":"E_FULL","with_symbol":with_symbol,"target":"is_clean_move"})
    pd.DataFrame(refit_pred).merge(df[["episode_id","market_cluster_id","symbol","t0_msc","is_clean_move"]],left_on="row_index",right_index=True).to_csv(a.out_dir/"development_refit_predictions.csv",index=False)

    # Registered frontiers for full no-symbol models and with-symbol LightGBM.
    frontier_rows=[];scored={}
    for kind,with_symbol in (("LOGISTIC",False),("TREE",False),("LIGHTGBM",False),("LIGHTGBM",True)):
        fr,p=frontier(df,all_pred,kind,"E_FULL",with_symbol,"WALK_FORWARD_OOF");
        for r in fr:r.update(model=kind,feature_group="E_FULL",with_symbol=with_symbol)
        frontier_rows+=fr;scored[(kind,with_symbol)]=p
        diagnostic,_=frontier(df,refit_pred,kind,"E_FULL",with_symbol,"DEVELOPMENT_REFIT_DIAGNOSTIC")
        for r in diagnostic:r.update(model=kind,feature_group="E_FULL",with_symbol=with_symbol)
        frontier_rows+=diagnostic
    pd.DataFrame(frontier_rows).to_csv(a.out_dir/"recall_precision_frontier.csv",index=False)
    pd.DataFrame([r for r in frontier_rows if r["frontier_type"]=="TOP_COUNT"]).to_csv(a.out_dir/"selected_count_frontier.csv",index=False)

    # Leave-one-symbol-out, cluster purged.
    loso=[]
    for symbol in sorted(df.symbol.unique()):
        test=df[df.symbol==symbol];blocked=set(test.market_cluster_id);train=df[(df.symbol!=symbol)&~df.market_cluster_id.isin(blocked)]
        for kind in ("LOGISTIC","LIGHTGBM"):
            for with_symbol in (False,True):
                cats=BASE_CATS+(["symbol"] if with_symbol else []);pipe=model_pipeline(kind,GROUPS["E_FULL"],cats);pipe.fit(train[GROUPS["E_FULL"]+cats],train.is_clean_move);score=pipe.predict_proba(test[GROUPS["E_FULL"]+cats])[:,1];m=metrics(test.is_clean_move.to_numpy(),score);m.update(symbol=symbol,model=kind,with_symbol=with_symbol,train_episodes=len(train),train_clusters=train.market_cluster_id.nunique(),test_clusters=test.market_cluster_id.nunique(),cluster_overlap=len(set(train.market_cluster_id)&set(test.market_cluster_id)));loso.append(m)
    pd.DataFrame(loso).to_csv(a.out_dir/"leave_one_symbol_out.csv",index=False)
    model_df[model_df.feature_group.eq("E_FULL")].to_csv(a.out_dir/"symbol_feature_ablation.csv",index=False)
    model_df[["model","feature_group","with_symbol","episodes","positives","positive_rate","average_precision","recall","precision","f2","selected"]].to_csv(a.out_dir/"feature_ablation_results.csv",index=False)

    # Fit final descriptive LightGBM, no symbol. Importance is not validation performance.
    cats=BASE_CATS;full=GROUPS["E_FULL"];final_pipe=model_pipeline("LIGHTGBM",full,cats);final_pipe.fit(df[full+cats],df.is_clean_move);prep=final_pipe.named_steps["prep"];model=final_pipe.named_steps["model"];names=prep.get_feature_names_out();gain=model.booster_.feature_importance("gain");split=model.booster_.feature_importance("split")
    pd.DataFrame({"transformed_feature":names,"gain":gain,"split":split}).sort_values("gain",ascending=False).to_csv(a.out_dir/"lightgbm_feature_importance.csv",index=False)
    _,_,final_vi=fold_indices(df)[-1];perm=permutation_importance(final_pipe,df.loc[final_vi,full+cats],df.loc[final_vi,"is_clean_move"],scoring="average_precision",n_repeats=10,random_state=SEED,n_jobs=1)
    pd.DataFrame({"feature":full+cats,"importance_mean":perm.importances_mean,"importance_std":perm.importances_std}).sort_values("importance_mean",ascending=False).to_csv(a.out_dir/"lightgbm_permutation_importance.csv",index=False)
    transformed=prep.transform(df.loc[final_vi,full+cats]);contrib=model.booster_.predict(transformed,pred_contrib=True);shap_abs=np.abs(contrib[:,:-1]).mean(axis=0);pd.DataFrame({"transformed_feature":names,"mean_abs_contribution":shap_abs}).sort_values("mean_abs_contribution",ascending=False).to_csv(a.out_dir/"lightgbm_shap_summary.csv",index=False)

    # Calibration and high-movement comparisons use pooled OOF only.
    p=scored[("LIGHTGBM",False)].copy();p["score_bin"]=pd.qcut(p.score,10,duplicates="drop");cal=[]
    for name,g in p.groupby("score_bin",observed=True):cal.append({"bin":str(name),"episodes":len(g),"clusters":g.market_cluster_id.nunique(),"mean_score":g.score.mean(),"observed_clean_rate":g.is_clean_move.mean(),"clean_count":int(g.is_clean_move.sum())})
    pd.DataFrame(cal).to_csv(a.out_dir/"prediction_calibration.csv",index=False)
    hm=[];hard=p[p.high_movement_selected.astype(str).str.upper()=="TRUE"];top=p.head(len(hard));intersection=hard.merge(top[["episode_id"]],on="episode_id")
    for name,g in (("HIGH_MOVEMENT_HARD",hard),("ML_TOP_SAME_COUNT",top),("HIGH_MOVEMENT_AND_ML_TOP",intersection),("OOF_ALL",p)):
        hm.append({"strategy":name,"episodes":len(g),"clusters":g.market_cluster_id.nunique(),"clean_count":int(g.is_clean_move.sum()),"recall":g.is_clean_move.sum()/p.is_clean_move.sum(),"precision":g.is_clean_move.mean() if len(g) else math.nan,"symbol_distribution":";".join(f"{k}:{v}" for k,v in sorted(Counter(g.symbol).items()))})
    pd.DataFrame(hm).to_csv(a.out_dir/"high_movement_vs_ml.csv",index=False)

    # Direction only among clean episodes; chronological folds are retained.
    clean=df[df.is_clean_move==1].copy().reset_index(drop=True);clean["clean_direction_continuation"]=(clean.is_clean_continuation==1).astype(int);direction=[]
    for kind in ("LOGISTIC","LIGHTGBM"):
        try:
            rows,preds=walk_forward(clean,kind,full,False,target="clean_direction_continuation");direction+=rows;pdir=pd.DataFrame(preds);merged=pdir.merge(clean[["clean_direction_continuation"]],left_on="row_index",right_index=True);m=metrics(merged.clean_direction_continuation.to_numpy(),merged.score.to_numpy());m.update(model=kind,feature_group="E_FULL",with_symbol=False,target="clean_direction_continuation",evaluation_scope="POOLED_WALK_FORWARD_OOF",folds=pdir.fold.nunique());direction.append(m)
        except ValueError as exc:direction.append({"model":kind,"status":"INSUFFICIENT_FOLD_CLASS_SUPPORT","reason":str(exc)})
    pd.DataFrame(direction).to_csv(a.out_dir/"clean_direction_results.csv",index=False)

    # Secondary cluster exploration, no rule extraction.
    x=SimpleImputer(strategy="median",keep_empty_features=True).fit_transform(df[full]);x=StandardScaler().fit_transform(x);cluster_rows=[]
    for k in (2,3,4,5):
        labels=KMeans(n_clusters=k,random_state=SEED,n_init=20).fit_predict(x)
        for label in range(k):
            g=df[labels==label];cluster_rows.append({"k":k,"cluster":label,"episodes":len(g),"market_clusters":g.market_cluster_id.nunique(),"clean_count":int(g.is_clean_move.sum()),"clean_rate":g.is_clean_move.mean(),"symbol_distribution":";".join(f"{a}:{b}" for a,b in sorted(Counter(g.symbol).items()))})
    pd.DataFrame(cluster_rows).to_csv(a.out_dir/"cluster_exploration.csv",index=False)

    # QA and reproducibility.
    forbidden=[c for c in export_cols if any(x in c.lower() for x in ("mfe","mae","hit_ms","time_to_hit","horizon"))];source_cols=[c for c in lag.columns if c.endswith("_source_msc")];future=int(sum((pd.to_numeric(df[c],errors="coerce")>df.t0_msc).sum() for c in source_cols if c in df));fold_overlap=int(fold_df.cluster_overlap.sum());loso_overlap=int(pd.DataFrame(loso).cluster_overlap.sum())
    qa=[("dataset_count",2696,len(df)),("positive_count",188,int(df.is_clean_move.sum())),("negative_count",2508,int((1-df.is_clean_move).sum())),("duplicate_episode_id",0,int(df.episode_id.duplicated().sum())),("feature_timestamp_violation",0,future),("target_leakage_feature",0,len(forbidden)),("train_validation_cluster_overlap",0,fold_overlap),("loso_cluster_overlap",0,loso_overlap),("orders",0,len(pd.read_csv(a.run_dir/"trades.csv"))),("model_nan_score",0,int(sum(pd.DataFrame(all_pred).score.isna())))]
    pd.DataFrame([{"check":name,"expected":expected,"actual":actual,"status":"PASS" if expected==actual else "FAIL"} for name,expected,actual in qa]).to_csv(a.out_dir/"qa_checks.csv",index=False)
    (a.out_dir/"python_environment.txt").write_text("\n".join([f"python={platform.python_version()}",f"numpy={np.__version__}",f"pandas={pd.__version__}",f"scipy={scipy.__version__}",f"scikit_learn={sklearn.__version__}",f"lightgbm={lightgbm.__version__}",f"matplotlib={matplotlib.__version__}",f"seed={SEED}"])+"\n",encoding="utf-8")

    # Required compact plots.
    def savefig(name):plt.tight_layout();plt.savefig(a.out_dir/name,dpi=140);plt.close()
    best=p.sort_values("score",ascending=False);y=best.is_clean_move.cumsum()/best.is_clean_move.sum();x=np.arange(1,len(best)+1);precision=best.is_clean_move.cumsum()/x
    plt.plot(x,y);plt.xlabel("selected episodes");plt.ylabel("clean recall");savefig("recall_vs_selected_count.png")
    plt.plot(x,precision);plt.axhline(best.is_clean_move.mean(),color="grey",ls="--");plt.xlabel("selected episodes");plt.ylabel("precision");savefig("precision_vs_selected_count.png")
    from sklearn.metrics import precision_recall_curve
    pr,rc,_=precision_recall_curve(p.is_clean_move,p.score);plt.plot(rc,pr);plt.axhline(p.is_clean_move.mean(),color="grey",ls="--");plt.xlabel("recall");plt.ylabel("precision");savefig("precision_recall_curve.png")
    imp=pd.read_csv(a.out_dir/"lightgbm_feature_importance.csv").head(15).iloc[::-1];plt.barh(imp.transformed_feature,imp.gain);savefig("lightgbm_feature_importance.png")
    sh=pd.read_csv(a.out_dir/"lightgbm_shap_summary.csv").head(15).iloc[::-1];plt.barh(sh.transformed_feature,sh.mean_abs_contribution);savefig("lightgbm_shap_summary.png")
    dep=pd.read_csv(a.out_dir/"feature_bin_summary.csv");top_feature=pd.read_csv(a.out_dir/"lightgbm_permutation_importance.csv").iloc[0].feature;dep=dep[dep.feature==top_feature]
    plt.plot(dep.bin,dep.clean_rate,marker="o");plt.axhline(df.is_clean_move.mean(),color="grey",ls="--");plt.xlabel(top_feature);plt.ylabel("clean rate");savefig("major_feature_dependence.png")
    sym=p.groupby("symbol").agg(score=("score","mean"),clean=("is_clean_move","mean"));sym.plot(kind="bar");savefig("symbol_performance.png")
    wf=fold_df[(fold_df.model=="LIGHTGBM")&(fold_df.feature_group=="E_FULL")&(~fold_df.with_symbol)];plt.plot(wf.fold,wf.average_precision,marker="o",label="AP");plt.plot(wf.fold,wf.positive_rate,marker="o",label="baseline");plt.legend();savefig("walk_forward_performance.png")
    print(json.dumps({"rows":len(df),"positive":int(df.is_clean_move.sum()),"models":len(model_df),"qa_fail":sum(x[1]!=x[2] for x in qa)},sort_keys=True))

if __name__=="__main__":main()
