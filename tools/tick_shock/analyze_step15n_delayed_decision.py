#!/usr/bin/env python3
from __future__ import annotations
import argparse, math
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from lightgbm import LGBMClassifier
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.inspection import permutation_importance
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

SEED=20260904
FOLD_BOUNDS=((0,.40,.40,.55),(0,.55,.55,.70),(0,.70,.70,.85),(0,.85,.85,1.0))
CHECKPOINTS=(15,30,60,120)
POST_FEATURES=[
 "postshock_return_atr","postshock_mfe_to_decision_atr","postshock_mae_to_decision_atr","postshock_range_atr",
 "retracement_from_peak_pct","retracement_from_trough_pct","current_location_in_postshock_range","new_extreme_count",
 "origin_recross_count","time_since_last_extreme_ms","distance_from_last_extreme_atr","net_move_over_path_length",
 "shock_direction_tick_ratio","direction_consistency","realized_abs_move_atr","realized_volatility","recent_5s_acceleration",
 "recent_10s_acceleration","peak_update_interval_ms","extreme_update_rate","path_contraction_ratio","path_expansion_ratio",
 "decision_spread_atr","spread_vs_t0_ratio","spread_vs_postshock_mean","spread_contraction_from_t0","tick_count_postshock",
 "tick_rate_recent_5s","tick_rate_recent_10s","tick_activity_vs_t0","activity_decay","activity_acceleration","checkpoint_quote_lag_ms"]
PRE_FEATURES=["spread_atr_t0","tick_activity_ratio","atr14_m5","pre_return_5m_dir_atr","m5_ema20_slope_dir_atr",
 "m15_alignment_dir","pre_extension_15m_dir_atr","day_range_position_dir","detection_efficiency","severity",
 "confirmation_retention","spread_efficiency_interaction","flow_efficiency_interaction"]
SIGNED=("postshock_return_atr","recent_5s_acceleration","recent_10s_acceleration","pre_return_5m_dir_atr",
 "m5_ema20_slope_dir_atr","m15_alignment_dir","pre_extension_15m_dir_atr","day_range_position_dir","confirmation_retention")

def folds(episodes):
    clusters=(episodes.groupby("market_cluster_id").t0_msc.min().sort_values().index.tolist());n=len(clusters)
    return [(i,set(clusters[:int(n*b)]),set(clusters[int(n*c):int(n*d)])) for i,(_,b,c,d) in enumerate(FOLD_BOUNDS,1)]

def pipe(kind,nums,with_symbol=False):
    if kind=="LOGISTIC":
        num=Pipeline([("impute",SimpleImputer(strategy="median",keep_empty_features=True)),("scale",StandardScaler())]);model=LogisticRegression(C=1,class_weight="balanced",max_iter=2000,random_state=SEED)
    else:
        num=SimpleImputer(strategy="median",keep_empty_features=True);model=LGBMClassifier(objective="binary",n_estimators=200,learning_rate=.03,num_leaves=15,max_depth=4,min_child_samples=50,colsample_bytree=.8,subsample=.8,subsample_freq=1,reg_alpha=1,reg_lambda=1,class_weight="balanced",random_state=SEED,n_jobs=1,verbosity=-1)
    cats=["action","shock_direction"]+(["symbol"] if with_symbol else [])
    prep=ColumnTransformer([("num",num,nums),("cat",OneHotEncoder(handle_unknown="ignore",sparse_output=False),cats)])
    return Pipeline([("prep",prep),("model",model)])

def metrics(z):
    if z.empty:return dict(trades=0,tp=0,sl=0,timeout=0,mean_r=np.nan,total_r=0,pf=np.nan,tp_rate=np.nan,max_consecutive_losses=0,ci_low=np.nan,ci_high=np.nan,mean_r_cost_002=np.nan,mean_r_cost_005=np.nan,mean_r_cost_010=np.nan)
    pos=z.loc[z.realized_r>0,"realized_r"].sum();neg=-z.loc[z.realized_r<0,"realized_r"].sum()
    run=best=0
    for loss in z.sort_values("entry_quote_msc").realized_r.lt(0):run=run+1 if loss else 0;best=max(best,run)
    rng=np.random.default_rng(SEED);groups=[v.realized_r.to_numpy() for _,v in z.groupby("market_cluster_id")];boots=[]
    if groups:
      for _ in range(2000):boots.append(np.concatenate([groups[i] for i in rng.integers(0,len(groups),len(groups))]).mean())
    ci=np.quantile(boots,[.025,.975]) if boots else (np.nan,np.nan)
    return dict(trades=len(z),tp=int((z.result=="TP_FIRST").sum()),sl=int((z.result=="SL_FIRST").sum()),timeout=int((z.result=="TIMEOUT").sum()),mean_r=z.realized_r.mean(),total_r=z.realized_r.sum(),pf=pos/neg if neg else np.nan,tp_rate=(z.result=="TP_FIRST").mean(),max_consecutive_losses=best,ci_low=ci[0],ci_high=ci[1],mean_r_cost_002=(z.realized_r-.02).mean(),mean_r_cost_005=(z.realized_r-.05).mean(),mean_r_cost_010=(z.realized_r-.10).mean())

def bootstrap_oracle(x,n=2000):
    g=[v.oracle_r.to_numpy() for _,v in x.groupby("market_cluster_id")]
    if not g:return (np.nan,np.nan)
    rng=np.random.default_rng(SEED);vals=[]
    for _ in range(n):
        s=[g[i] for i in rng.integers(0,len(g),len(g))];vals.append(np.concatenate(s).mean())
    return tuple(np.quantile(vals,[.025,.975]))

def classify_pair(g):
    c=g[g.action=="CONTINUATION"].iloc[0];r=g[g.action=="REVERSAL"].iloc[0]
    if c.result=="TP_FIRST" and r.result=="TP_FIRST":return "BOTH_TP"
    if c.result=="TP_FIRST":return "CONTINUATION_ONLY_TP"
    if r.result=="TP_FIRST":return "REVERSAL_ONLY_TP"
    if c.result=="SL_FIRST" and r.result=="SL_FIRST":return "BOTH_SL"
    return "TIMEOUT_INVOLVED"

def main():
    ap=argparse.ArgumentParser();ap.add_argument("--run-dir",type=Path,required=True);ap.add_argument("--base-dataset",type=Path,required=True);ap.add_argument("--out-dir",type=Path,required=True);a=ap.parse_args();a.out_dir.mkdir(parents=True,exist_ok=True)
    cp=pd.read_csv(a.run_dir/"delayed_decision_checkpoints.csv");act=pd.read_csv(a.run_dir/"delayed_decision_actions.csv");base=pd.read_csv(a.base_dataset)
    keys=base[["symbol","t0_msc"]].drop_duplicates();raw_keys=cp[["symbol","t0_msc"]].drop_duplicates();identity=keys.merge(raw_keys,on=["symbol","t0_msc"],how="outer",indicator=True)
    identity.groupby("_merge",observed=False).size().rename("episodes").reset_index().rename(columns={"_merge":"identity_status"}).to_csv(a.out_dir/"episode_identity_check.csv",index=False)
    cp=cp.merge(keys,on=["symbol","t0_msc"],how="inner",validate="many_to_one");act=act.merge(keys,on=["symbol","t0_msc"],how="inner",validate="many_to_one")
    base_keep=["symbol","t0_msc","session"]+[x for x in PRE_FEATURES if x in base.columns]
    cp=cp.merge(base[base_keep],on=["symbol","t0_msc"],how="left",validate="many_to_one",suffixes=("","_pre"))
    cp["week"]=pd.to_datetime(cp.t0_msc,unit="ms",utc=True).dt.strftime("%Y-W%U")
    ep=cp[["symbol","t0_msc","market_cluster_id"]].drop_duplicates();fmap={}
    for f,_,va in folds(ep):
        for k in va:fmap[k]=f
    cp["fold"]=cp.market_cluster_id.map(fmap);act["fold"]=act.market_cluster_id.map(fmap)
    cp.to_csv(a.out_dir/"checkpoint_episode_status.csv",index=False)
    features=POST_FEATURES+[x for x in PRE_FEATURES if x in cp.columns]
    ds=act.merge(cp[["symbol","t0_msc","checkpoint_seconds","session","week"]+features],on=["symbol","t0_msc","checkpoint_seconds"],how="left",validate="many_to_one")
    ds["tp_first"]=(ds.result=="TP_FIRST").astype(int);ds["action_sign"]=np.where(ds.action=="CONTINUATION",1,-1)
    for x in SIGNED:
        if x in ds:ds[x+"_action"]=pd.to_numeric(ds[x],errors="coerce")*ds.action_sign
    model_features=[x+"_action" if x in SIGNED else x for x in features]
    ds.to_csv(a.out_dir/"checkpoint_action_dataset.csv",index=False)
    eligible=ds[(ds.checkpoint_status=="ELIGIBLE")&ds.result.isin(["TP_FIRST","SL_FIRST","TIMEOUT"])].copy()
    pairs=[]
    for (eid,d),g in eligible.groupby(["episode_id","checkpoint_seconds"]):
        if len(g)!=2:continue
        rr=g.realized_r.to_numpy(float);row=g.iloc[0];pairs.append(dict(episode_id=eid,checkpoint_seconds=d,market_cluster_id=row.market_cluster_id,symbol=row.symbol,session=row.session,week=row.week,fold=row.fold,path_class=classify_pair(g),continuation_r=g.loc[g.action=="CONTINUATION","realized_r"].iloc[0],reversal_r=g.loc[g.action=="REVERSAL","realized_r"].iloc[0],oracle_r=max(rr.max(),0),remaining_mfe=max(g.mfe_r.max(),0),consumed_move=abs(row.postshock_return_atr)))
    pair=pd.DataFrame(pairs);pair.to_csv(a.out_dir/"checkpoint_remaining_opportunity.csv",index=False)
    oracle=[]
    for d in CHECKPOINTS:
        q=pair[pair.checkpoint_seconds==d];status=cp[cp.checkpoint_seconds==d].status.value_counts();ci=bootstrap_oracle(q);trades=(q.oracle_r>0)
        row=dict(checkpoint_seconds=d,total_episodes=int((cp.checkpoint_seconds==d).sum()),eligible_episodes=len(q),eligible_market_clusters=q.market_cluster_id.nunique(),continuation_tp=int((q.continuation_r>=1.6-1e-9).sum()),reversal_tp=int((q.reversal_r>=1.6-1e-9).sum()),both_tp=int((q.path_class=="BOTH_TP").sum()),both_sl=int((q.path_class=="BOTH_SL").sum()),timeout_involved=int((q.path_class=="TIMEOUT_INVOLVED").sum()),oracle_trade_count=int(trades.sum()),oracle_tp_count=int(trades.sum()),oracle_expectancy=q.oracle_r.mean(),oracle_total_r=q.oracle_r.sum(),oracle_pf=np.inf if trades.any() else np.nan,oracle_positive_rate=trades.mean(),oracle_ci_low=ci[0],oracle_ci_high=ci[1],remaining_mfe_median=q.remaining_mfe.median(),consumed_move_median=q.consumed_move.median())
        for k,v in status.items():row["status_"+str(k)]=int(v)
        row["oracle_feasibility"]="ORACLE_FEASIBILITY_PRESENT" if row["oracle_trade_count"]>0 and row["oracle_expectancy"]-.10>0 else ("ORACLE_FEASIBILITY_WEAK" if row["oracle_trade_count"]>0 else "ORACLE_FEASIBILITY_ABSENT")
        oracle.append(row)
    od=pd.DataFrame(oracle);od.to_csv(a.out_dir/"checkpoint_oracle_summary.csv",index=False)
    for col,name in [("symbol","checkpoint_oracle_symbol.csv"),("session","checkpoint_oracle_session.csv"),("week","checkpoint_oracle_week.csv"),("fold","checkpoint_oracle_fold.csv")]:
        pair.groupby(["checkpoint_seconds",col],dropna=False).agg(episodes=("episode_id","nunique"),clusters=("market_cluster_id","nunique"),oracle_expectancy=("oracle_r","mean"),oracle_total_r=("oracle_r","sum"),both_sl=("path_class",lambda x:(x=="BOTH_SL").sum())).reset_index().to_csv(a.out_dir/name,index=False)
    phase=set(od.loc[od.oracle_feasibility!="ORACLE_FEASIBILITY_ABSENT","checkpoint_seconds"])
    fold_rows=[];pred_rows=[];threshold_rows=[]
    for d in CHECKPOINTS:
      if d not in phase:continue
      z=eligible[eligible.checkpoint_seconds==d].copy();episodes=ep[ep.t0_msc.isin(z.t0_msc.unique())]
      variants=(("LOGISTIC","ALL_NO_SYMBOL",False),("LIGHTGBM","ALL_NO_SYMBOL",False),("LIGHTGBM","ALL_WITH_SYMBOL",True),("LIGHTGBM","USDJPY_ONLY",False))
      for kind,scope,with_symbol in variants:
       for f,trc,vac in folds(episodes):
        tr=z[z.market_cluster_id.isin(trc)];va=z[z.market_cluster_id.isin(vac)]
        if scope=="USDJPY_ONLY":tr=tr[tr.symbol=="USDJPY"];va=va[va.symbol=="USDJPY"]
        if tr.tp_first.nunique()<2 or va.empty:continue
        cats=["action","shock_direction"]+(["symbol"] if with_symbol else []);m=pipe(kind,model_features,with_symbol);m.fit(tr[model_features+cats],tr.tp_first);ts=m.predict_proba(tr[model_features+cats])[:,1];vs=m.predict_proba(va[model_features+cats])[:,1]
        # Training-only no-trade threshold: highest-recall score cut with positive observed R after 0.05R cost and at least 20 actions.
        candidates=[]
        for q in np.unique(np.quantile(ts,[.5,.6,.7,.8,.9,.95,.98,.99])):
            sel=tr[ts>=q]
            if len(sel)>=20 and (sel.realized_r-.05).mean()>0:candidates.append(q)
        threshold=min(candidates) if candidates else np.inf;threshold_rows.append(dict(checkpoint_seconds=d,model=kind,scope=scope,fold=f,threshold=threshold,training_rows=len(tr),training_selected=int((ts>=threshold).sum())))
        fold_rows.append(dict(checkpoint_seconds=d,model=kind,scope=scope,fold=f,validation_rows=len(va),positives=int(va.tp_first.sum()),ap=average_precision_score(va.tp_first,vs),auc=roc_auc_score(va.tp_first,vs) if va.tp_first.nunique()>1 else np.nan,train_clusters=tr.market_cluster_id.nunique(),validation_clusters=va.market_cluster_id.nunique(),train_max_msc=tr.t0_msc.max(),validation_min_msc=va.t0_msc.min()))
        for idx,score in zip(va.index,vs):pred_rows.append(dict(action_row_index=idx,checkpoint_seconds=d,model=kind,scope=scope,fold=f,score=score,threshold=threshold))
    fd=pd.DataFrame(fold_rows);pd.DataFrame(threshold_rows).to_csv(a.out_dir/"checkpoint_threshold_diagnostics.csv",index=False);fd.to_csv(a.out_dir/"checkpoint_model_comparison.csv",index=False)
    preds=pd.DataFrame(pred_rows);preds.to_csv(a.out_dir/"checkpoint_oof_predictions.csv",index=False)
    policies=[];chosen=pd.DataFrame()
    for d in CHECKPOINTS:
        z=eligible[eligible.checkpoint_seconds==d]
        for label,q in (("ALWAYS_CONTINUATION",z[z.action=="CONTINUATION"]),("ALWAYS_REVERSAL",z[z.action=="REVERSAL"])):
            r=metrics(q);r.update(checkpoint_seconds=d,policy=label,positive_folds=int((q.groupby("fold").realized_r.mean()>0).sum()));policies.append(r)
        q=pair[pair.checkpoint_seconds==d]
        random_r=.5*(q.continuation_r+q.reversal_r)
        policies.append(dict(checkpoint_seconds=d,policy="RANDOM_DIRECTION_THEORETICAL",trades=len(q),tp=np.nan,sl=np.nan,timeout=np.nan,mean_r=random_r.mean(),total_r=random_r.sum(),pf=np.nan,tp_rate=np.nan,positive_folds=np.nan))
        best_r=q[["continuation_r","reversal_r"]].max(axis=1)
        policies.append(dict(checkpoint_seconds=d,policy="ORACLE_DIRECTION_TRADE_ALL",trades=len(q),tp=int((best_r>=1.6-1e-9).sum()),sl=int((best_r<0).sum()),timeout=int(((best_r>=0)&(best_r<1.6-1e-9)).sum()),mean_r=best_r.mean(),total_r=best_r.sum(),pf=np.nan,tp_rate=(best_r>=1.6-1e-9).mean(),positive_folds=np.nan))
        policies.append(dict(checkpoint_seconds=d,policy="ORACLE_DIRECTION_PLUS_NO_TRADE",trades=int((q.oracle_r>0).sum()),tp=int((q.oracle_r>0).sum()),sl=0,timeout=0,mean_r=q.oracle_r.mean(),total_r=q.oracle_r.sum(),pf=np.inf,tp_rate=1.0,positive_folds=np.nan))
    if not preds.empty:
      p=preds[(preds.model=="LIGHTGBM")&(preds.scope=="ALL_NO_SYMBOL")].merge(eligible.reset_index().rename(columns={"index":"action_row_index"}).drop(columns=["fold"]),on=["action_row_index","checkpoint_seconds"],how="left")
      ranked=p.sort_values("score",ascending=False).groupby(["episode_id","checkpoint_seconds","fold"],as_index=False).first();best=ranked[ranked.score>=ranked.threshold].copy();chosen=best
      for d in CHECKPOINTS:
        q=best[best.checkpoint_seconds==d];all_q=ranked[ranked.checkpoint_seconds==d];oracle_ids=set(pair[(pair.checkpoint_seconds==d)&(pair.oracle_r>0)].episode_id);oq=all_q[all_q.episode_id.isin(oracle_ids)];r=metrics(q);r.update(checkpoint_seconds=d,policy="LIGHTGBM_TRAIN_ONLY_THRESHOLD",positive_folds=int((q.groupby("fold").realized_r.mean()>0).sum()),oracle_tradeable_direction_count=len(oq),oracle_tradeable_direction_correct=int(oq.tp_first.sum()),oracle_tradeable_direction_accuracy=oq.tp_first.mean() if len(oq) else np.nan);policies.append(r)
    pd.DataFrame(policies).to_csv(a.out_dir/"checkpoint_policy_results.csv",index=False)
    for col,name in [("fold","checkpoint_fold_performance.csv"),("symbol","checkpoint_symbol_performance.csv"),("session","checkpoint_session_performance.csv"),("week","checkpoint_weekly_performance.csv")]:
        rows=[]
        if not chosen.empty:
          for (d,k),q in chosen.groupby(["checkpoint_seconds",col],dropna=False):r=metrics(q);r.update(checkpoint_seconds=d,**{col:k});rows.append(r)
        pd.DataFrame(rows).to_csv(a.out_dir/name,index=False)
    # Final descriptive importance only; never used as validation evidence.
    imp=[];perm=[];shap_rows=[]
    for d in phase:
        z=eligible[eligible.checkpoint_seconds==d]
        if z.tp_first.nunique()<2:continue
        m=pipe("LIGHTGBM",model_features);X=z[model_features+["action","shock_direction"]];m.fit(X,z.tp_first);names=m.named_steps["prep"].get_feature_names_out();vals=m.named_steps["model"].booster_.feature_importance(importance_type="gain")
        imp.extend(dict(checkpoint_seconds=d,feature=n,importance_gain=v) for n,v in zip(names,vals))
        pr=permutation_importance(m,X,z.tp_first,n_repeats=5,random_state=SEED,scoring="average_precision")
        perm.extend(dict(checkpoint_seconds=d,feature=n,importance_mean=v,importance_std=s) for n,v,s in zip(X.columns,pr.importances_mean,pr.importances_std))
        sx=X.sample(n=min(2000,len(X)),random_state=SEED).sort_index();tx=m.named_steps["prep"].transform(sx);sv=m.named_steps["model"].booster_.predict(tx,pred_contrib=True)[:,:-1]
        shap_rows.extend(dict(checkpoint_seconds=d,feature=n,mean_abs_shap=v,status="DESCRIPTIVE_ONLY") for n,v in zip(names,np.abs(np.asarray(sv)).mean(axis=0)))
    pd.DataFrame(imp).to_csv(a.out_dir/"checkpoint_feature_importance.csv",index=False);pd.DataFrame(perm).to_csv(a.out_dir/"checkpoint_permutation_importance.csv",index=False);pd.DataFrame(shap_rows).to_csv(a.out_dir/"checkpoint_shap_summary.csv",index=False)
    comp=od[["checkpoint_seconds","total_episodes","eligible_episodes","oracle_trade_count","both_sl","oracle_expectancy","remaining_mfe_median","consumed_move_median"]].copy();comp.insert(0,"source","STEP15N");comp.to_csv(a.out_dir/"checkpoint_comparison_summary.csv",index=False)
    pd.DataFrame([dict(source="STEP15M_FROZEN",checkpoint_seconds=0,oof_episodes=1620,direction_correct=26,tp=26,mean_r=-.584,ci_low=-.896,ci_high=-.168),*[{"source":"STEP15N","checkpoint_seconds":r.checkpoint_seconds,"oof_episodes":r.eligible_episodes,"direction_correct":"","tp":r.oracle_tp_count,"mean_r":r.oracle_expectancy,"ci_low":r.oracle_ci_low,"ci_high":r.oracle_ci_high} for r in od.itertuples()]]).to_csv(a.out_dir/"step15m_vs_step15n.csv",index=False)
    fold_overlap=0;episode_overlap=0;chronology=0
    for _,trc,vac in folds(ep):
        fold_overlap+=len(trc&vac);tr_ep=set(ep[ep.market_cluster_id.isin(trc)].t0_msc);va_ep=set(ep[ep.market_cluster_id.isin(vac)].t0_msc);episode_overlap+=len(tr_ep&va_ep)
        trmax=ep[ep.market_cluster_id.isin(trc)].t0_msc.max();vamin=ep[ep.market_cluster_id.isin(vac)].t0_msc.min();chronology+=int(trmax>=vamin)
    status_reconcile=sum(int((cp.checkpoint_seconds==d).sum()) for d in CHECKPOINTS)
    qa=[("source_episode_count",2696,cp[["symbol","t0_msc"]].drop_duplicates().shape[0]),("checkpoint_population_rows",2696*4,len(cp)),("episode_checkpoint_duplicate",0,int(cp.duplicated(["symbol","t0_msc","checkpoint_seconds"]).sum())),("action_key_duplicate",0,int(act.duplicated(["symbol","t0_msc","checkpoint_seconds","action"]).sum())),("decision_before_target",0,int((pd.to_numeric(cp.decision_quote_msc,errors="coerce")<cp.checkpoint_target_msc).sum())),("entry_before_target",0,int((pd.to_numeric(act.entry_quote_msc,errors="coerce")<act.t0_msc+act.checkpoint_seconds*1000).sum())),("entry_not_after_feature",0,int((pd.to_numeric(act.entry_quote_msc,errors="coerce")<=pd.to_numeric(act.feature_max_source_msc,errors="coerce")).sum())),("entry_before_eligible",0,int((pd.to_numeric(act.entry_quote_msc,errors="coerce")<pd.to_numeric(act.entry_eligible_msc,errors="coerce")).sum())),("future_feature",0,int((pd.to_numeric(cp.feature_max_source_msc,errors="coerce")>pd.to_numeric(cp.decision_processing_msc,errors="coerce")).sum())),("episode_fold_overlap",0,episode_overlap),("market_cluster_fold_overlap",0,fold_overlap),("chronology_violation",0,chronology),("status_rows_reconcile",len(cp),status_reconcile),("orders",0,len(pd.read_csv(a.run_dir/"trades.csv")))]
    pd.DataFrame(qa,columns=["check","expected","actual"]).assign(status=lambda x:np.where(x.expected==x.actual,"PASS","FAIL")).to_csv(a.out_dir/"qa_checks.csv",index=False)
    pd.DataFrame([dict(checkpoint_seconds=r.checkpoint_seconds,eligible_recomputed=int(((act.checkpoint_seconds==r.checkpoint_seconds)&(act.checkpoint_status=="ELIGIBLE")).sum()/2),oracle_total_r_recomputed=pair.loc[pair.checkpoint_seconds==r.checkpoint_seconds,"oracle_r"].sum(),reported_eligible=r.eligible_episodes,reported_oracle_total_r=r.oracle_total_r) for r in od.itertuples()]).to_csv(a.out_dir/"independent_recalculation.csv",index=False)
    for y,name in [("oracle_positive_rate","delay_vs_oracle_feasibility.png"),("both_sl","delay_vs_both_sl_rate.png"),("remaining_mfe_median","delay_vs_remaining_mfe.png"),("oracle_expectancy","delay_vs_expectancy.png")]:
        plt.figure();plt.plot(od.checkpoint_seconds,od[y],marker="o");plt.xlabel("observation delay sec");plt.ylabel(y);plt.grid(True,alpha=.3);plt.tight_layout();plt.savefig(a.out_dir/name,dpi=140);plt.close()
    plt.figure();
    if not chosen.empty: chosen.groupby("checkpoint_seconds").tp_first.mean().reindex(CHECKPOINTS).plot(marker="o")
    plt.xlabel("observation delay sec");plt.ylabel("selected TP rate");plt.grid(True,alpha=.3);plt.tight_layout();plt.savefig(a.out_dir/"delay_vs_direction_accuracy.png",dpi=140);plt.close()

if __name__=="__main__":main()
