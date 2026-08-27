#!/usr/bin/env python3
"""Independent Step 15C event-response analysis with frozen chronological split."""
from __future__ import annotations

import argparse,csv,hashlib,json,math
from collections import Counter
from datetime import datetime
from pathlib import Path
import numpy as np
import pandas as pd

ROOT=Path(__file__).resolve().parents[2]
HORIZONS=[250,500,1000,2000,3000,5000,10000,15000,30000,60000,120000]
GATES=[("statistical_shock",1),("direction_available",2),("directional_burst",4),("activity_elevated",8),("liquidity_normal",16),("cost_feasible",32),("efficiency_gate",64),("persistence_gate",128)]
PRIMARY=[1000,3000,10000,30000,120000]

def sha(path:Path)->str:return hashlib.sha256(path.read_bytes()).hexdigest().upper()
def b(v):return str(v).lower() in {"true","1","yes"}
def num(series):return pd.to_numeric(series,errors="coerce")
def write(df:pd.DataFrame,path:Path):path.parent.mkdir(parents=True,exist_ok=True);df.to_csv(path,index=False)

def episodes(reps:pd.DataFrame):
    order=reps.sort_values(["confirmed_time_msc","event_id"]).copy(); current=-1;end=-1;ids=[]
    for t in order.confirmed_time_msc.astype("int64"):
        if t>end:current+=1;end=t+120000
        else:end=max(end,t+120000)
        ids.append(current)
    order["response_episode_id"]=ids
    ep=order.groupby("response_episode_id",as_index=False).agg(start_msc=("confirmed_time_msc","min"),end_confirmed_msc=("confirmed_time_msc","max"),market_clusters=("market_cluster_id","nunique"),representative_events=("event_id","size"))
    ep["window_end_msc"]=ep.end_confirmed_msc.astype("int64")+120000
    ep["partition"]="INTERNAL_CONFIRMATION";ep.loc[ep.response_episode_id<2190,"partition"]="DISCOVERY";ep.loc[ep.response_episode_id==2190,"partition"]="PURGE"
    mapping=order.set_index("market_cluster_id")["response_episode_id"].to_dict()
    return order,ep,mapping

def stationary_indices(n:int,B:int=10000,mean_block:int=4,seed:int=20260828):
    rng=np.random.default_rng(seed);idx=np.empty((B,n),dtype=np.int32);idx[:,0]=rng.integers(0,n,B)
    restart=1.0/mean_block
    for j in range(1,n):
        fresh=rng.random(B)<restart;idx[:,j]=(idx[:,j-1]+1)%n;idx[fresh,j]=rng.integers(0,n,fresh.sum())
    return idx

def holm(p):
    order=np.argsort(p);out=np.ones(len(p));running=0.0
    for rank,i in enumerate(order):running=max(running,(len(p)-rank)*p[i]);out[i]=min(1.0,running)
    return out

def bh(p):
    order=np.argsort(p);out=np.ones(len(p));running=1.0;m=len(p)
    for rank in range(m-1,-1,-1):i=order[rank];running=min(running,p[i]*m/(rank+1));out[i]=min(1.0,running)
    return out

def bootstrap_primary(rep:pd.DataFrame,episode_table:pd.DataFrame,partition:str):
    subset=rep[rep.partition==partition].copy();epids=episode_table[episode_table.partition==partition].response_episode_id.astype(int).tolist();pos={e:i for i,e in enumerate(epids)}
    idx=stationary_indices(len(epids));rows=[];raw_p=[]
    outcomes=[(f"continuation_return_{h}ms",f"h{h}_continuation_return") for h in PRIMARY]
    cont=(subset.barrier_10_result=="CONTINUATION_FIRST").astype(float);rev=(subset.barrier_10_result=="REVERSAL_FIRST").astype(float);subset["barrier_10_probability_difference"]=cont-rev;outcomes.append(("barrier_10_probability_difference","barrier_10_probability_difference"))
    for name,col in outcomes:
        vals=num(subset[col]);tmp=pd.DataFrame({"episode":subset.response_episode_id.astype(int),"v":vals}).groupby("episode").v.mean()
        arr=np.array([tmp.get(e,np.nan) for e in epids],dtype=float);obs=float(np.nanmean(arr));boot=np.nanmean(arr[idx],axis=1);lo,hi=np.nanpercentile(boot,[2.5,97.5]);p=2*min((np.count_nonzero(boot<=0)+1)/(len(boot)+1),(np.count_nonzero(boot>=0)+1)/(len(boot)+1));raw_p.append(min(1.0,p))
        rows.append({"partition":partition,"outcome":name,"effect":obs,"ci95_low":lo,"ci95_high":hi,"raw_p":p,"episodes":int(np.isfinite(arr).sum()),"bootstrap_replicates":len(boot),"mean_block":4,"seed":20260828})
    adjusted=holm(raw_p)
    for r,a in zip(rows,adjusted):r["adjusted_p_holm"]=a;r["supported"]=bool(r["ci95_low"]>0 and a<0.05)
    return pd.DataFrame(rows)

def svg(path:Path,title:str,labels:list[str],values:list[float]):
    path.parent.mkdir(parents=True,exist_ok=True);w,h=900,420;mx=max([abs(v) for v in values]+[1e-12]);parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}"><rect width="100%" height="100%" fill="white"/><text x="20" y="28" font-size="18">{title}</text>']
    n=max(1,len(values));bw=800/n
    for i,(lab,v) in enumerate(zip(labels,values)):
        bh=300*abs(v)/mx;x=60+i*bw;y=350-bh if v>=0 else 350;parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{max(2,bw-4):.1f}" height="{bh:.1f}" fill="#{"3478c8" if v>=0 else "c84a4a"}"/><text x="{x:.1f}" y="380" font-size="9" transform="rotate(35 {x:.1f},380)">{lab}</text>')
    parts.append('</svg>');path.write_text("".join(parts),encoding="utf-8")

def analyze(run_dir:Path,out:Path,partition:str):
    features=pd.read_csv(run_dir/"detector_features.csv",low_memory=False);response=pd.read_csv(run_dir/"event_response.csv",low_memory=False);funnel=pd.read_csv(run_dir/"strategy_funnel.csv",low_memory=False)
    if len(features)!=21799 or len(response)!=21799:raise SystemExit(f"row accounting failed features={len(features)} response={len(response)}")
    for frame in (features,response,funnel):frame["event_id"]=frame.event_id.astype(str)
    df=features.merge(response,on=["event_id","symbol","market_cluster_id"],suffixes=("_feature","_response"),validate="one_to_one")
    df=df.merge(funnel[[c for c in funnel.columns if c not in {"symbol","direction","severity","detector_version"}]],on=["event_id","market_cluster_id"],how="left",validate="one_to_one")
    df["confirmed_time_msc"]=num(df.confirmed_time_msc_feature).astype("int64");df["candidate_time_msc"]=num(df.candidate_time_msc_feature).astype("int64")
    reps=df.sort_values(["confirmed_time_msc","event_id"]).drop_duplicates("market_cluster_id",keep="first").copy();reps_order,ep,map_ep=episodes(reps)
    df["response_episode_id"]=df.market_cluster_id.map(map_ep).astype(int);reps=reps.merge(reps_order[["event_id","response_episode_id"]],on="event_id",suffixes=("","_ep"));reps["response_episode_id"]=reps.response_episode_id_ep;reps.drop(columns=["response_episode_id_ep"],inplace=True)
    partition_map=ep.set_index("response_episode_id").partition.to_dict();df["partition"]=df.response_episode_id.map(partition_map);reps["partition"]=reps.response_episode_id.map(partition_map)
    chosen="DISCOVERY" if partition=="discovery" else "INTERNAL_CONFIRMATION";d=df[df.partition==chosen].copy();r=reps[reps.partition==chosen].copy();e=ep[ep.partition==chosen].copy()
    out.mkdir(parents=True,exist_ok=True)
    timeline=pd.DataFrame({"event_id":d.event_id,"market_cluster_id":d.market_cluster_id,"response_episode_id":d.response_episode_id,"server_time_msc":d.confirmed_time_msc,"server_time":d.confirmed_time_msc.map(lambda x:datetime.utcfromtimestamp(x/1000).strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]),"utc":"","jst":"","timezone_status":"TIMEZONE_MAPPING_NOT_VERIFIED","symbol":d.symbol,"direction":d.direction,"severity":d.severity_feature,"candidate_time_msc":d.candidate_time_msc,"confirmed_time_msc":d.confirmed_time_msc,"cluster_breadth":d.groupby("market_cluster_id").event_id.transform("size"),"partition":d.partition})
    write(timeline,out/"event_timeline.csv")
    path_cols=["event_id","market_cluster_id","response_episode_id","symbol","direction","partition","mfe","mae","time_to_mfe_ms","time_to_mae_ms","origin_recross_msc","initial_shock_size","local_sigma_response","reference_mid","validation_status"]
    write(d[path_cols],out/"event_path_outcomes.csv");write(d[["event_id","market_cluster_id","response_episode_id","mfe","mae","time_to_mfe_ms","time_to_mae_ms","origin_recross_msc","partition"]],out/"excursion_timing.csv")
    horizon=[]
    for h in HORIZONS:
        for _,x in d.iterrows():horizon.append({"event_id":x.event_id,"market_cluster_id":x.market_cluster_id,"response_episode_id":x.response_episode_id,"symbol":x.symbol,"server_hour":datetime.utcfromtimestamp(x.confirmed_time_msc/1000).hour,"horizon_ms":h,"status":x[f"h{h}_status"],"tick_msc":x[f"h{h}_boundary_msc"],"quote_msc":x[f"h{h}_quote_msc"],"target_lag_ms":x[f"h{h}_target_lag_ms"],"quote_age_ms":x[f"h{h}_quote_age_ms"],"bid":x[f"h{h}_bid"],"ask":x[f"h{h}_ask"],"mid":x[f"h{h}_mid"],"raw_log_return":x[f"h{h}_raw_log_return"],"continuation_return":x[f"h{h}_continuation_return"],"absolute_return":x[f"h{h}_absolute_return"],"spread":x[f"h{h}_spread"],"partition":x.partition})
    hz=pd.DataFrame(horizon);write(hz,out/"event_response_by_horizon.csv")
    agg=hz.groupby(["symbol","server_hour","horizon_ms"],as_index=False).agg(events=("event_id","size"),valid=("continuation_return","count"),mean_continuation=("continuation_return","mean"),median_continuation=("continuation_return","median"),mean_absolute=("absolute_return","mean"),mean_spread=("spread","mean"));write(agg,out/"event_response_by_symbol_time.csv")
    barrier=[]
    for _,x in d.iterrows():
        for label in ("05","10","20"):barrier.append({"event_id":x.event_id,"market_cluster_id":x.market_cluster_id,"response_episode_id":x.response_episode_id,"barrier_local_sigma":float(label)/10,"result":x[f"barrier_{label}_result"],"continuation_hit_msc":x[f"barrier_{label}_continuation_hit_msc"],"reversal_hit_msc":x[f"barrier_{label}_reversal_hit_msc"],"partition":x.partition})
    write(pd.DataFrame(barrier),out/"barrier_first_passage.csv");write(e,out/"response_episode_registry.csv")
    d["direction_available"]=d.direction.isin(["LONG","SHORT"]);d["efficiency_gate"]=num(d.efficiency)>=0.65;d["persistence_gate"]=True
    for name,_ in GATES:
        if name not in d:d[name]=False
        d[name]=d[name].map(b) if d[name].dtype==object else d[name].astype(bool)
    d["gate_mask"]=sum(d[name].astype(int)*bit for name,bit in GATES);d["gate_fail_count"]=sum((~d[name]).astype(int) for name,_ in GATES)
    gate_cols=["event_id","market_cluster_id","response_episode_id","symbol","partition","gate_mask","gate_fail_count"]+[n for n,_ in GATES];write(d[gate_cols],out/"gate_pass_fail_matrix.csv")
    overlap=[]
    for a,_ in GATES:
        for c,_ in GATES:overlap.append({"gate_a":a,"gate_b":c,"both_pass":int((d[a]&d[c]).sum()),"both_fail":int((~d[a]&~d[c]).sum()),"a_pass_b_fail":int((d[a]&~d[c]).sum())})
    write(pd.DataFrame(overlap),out/"gate_overlap.csv")
    full=255;leave=[]
    for name,bit in GATES:leave.append({"removed_gate":name,"baseline_reachable":int((d.gate_mask==full).sum()),"reachable_without_gate":int(((d.gate_mask|bit)==full).sum()),"increment":int(((d.gate_mask|bit)==full).sum()-(d.gate_mask==full).sum())})
    write(pd.DataFrame(leave),out/"gate_leave_one_out.csv")
    reach_cols=["event_id","market_cluster_id","response_episode_id","symbol","partition","common_strategy_eligible","detection_continuation_reachable","post_burst_continuation_reachable","pullback_continuation_reachable","failed_shock_reversal_reachable","detection_entry_msc","post_burst_entry_msc","pullback_entry_msc","reversal_entry_msc","record_status"]
    write(d[reach_cols],out/"strategy_causal_reachability.csv")
    rr=[]
    for strategy in ("detection_time_continuation","post_burst_continuation","pullback_continuation","failed_shock_reversal"):
        for stop in np.arange(1.0,12.01,0.5):
            for rv in (0.8,1.0,1.2,1.5,2.0):
                for delay in (0,100,250):
                    for spread in (1.0,1.25):rr.append({"partition":chosen,"strategy":strategy,"stop_multiple":stop,"rr":rv,"delay_ms":delay,"spread_multiplier":spread,"status":"NOT_EVALUABLE_WITH_FIXED_HORIZON_ONLY","tp_first":0,"sl_first":0,"timeout":0,"gross_expectancy_r":"","after_observed_spread_expectancy_r":"","after_stress_expectancy_r":"","commission_status":"UNVERIFIED","candidate_eligible":False})
    write(pd.DataFrame(rr),out/"research_rr_grid_results.csv")
    primary=bootstrap_primary(r,ep,chosen);write(primary,out/"cluster_episode_bootstrap_results.csv")
    cond=[]
    r["server_hour"]=r.confirmed_time_msc.map(lambda x:datetime.utcfromtimestamp(x/1000).hour);r["weekday"]=r.confirmed_time_msc.map(lambda x:datetime.utcfromtimestamp(x/1000).weekday())
    for feature in ("symbol","severity_feature","trigger_horizon_ms","volatility_regime_feature","server_hour","weekday"):
        for value,g in r.groupby(feature,dropna=False):
            y=num(g.h10000_continuation_return);cond.append({"partition":chosen,"feature":feature,"bucket":value,"events":len(g),"episodes":g.response_episode_id.nunique(),"mean_continuation_10s":y.mean(),"median_continuation_10s":y.median(),"positive_rate_10s":float((y>0).mean()),"raw_p":1.0})
    continuous=("local_score","local_sigma_feature","noise_return","efficiency","tick_intensity_ratio","move_spread_ratio","spread_ratio","quote_age_ms")
    boundaries={}
    for feature in continuous:
        vals=num(r[feature]);cuts=np.unique(vals.quantile([0,.25,.5,.75,1]).dropna().values);boundaries[feature]=cuts.tolist()
        if len(cuts)<2:continue
        buckets=pd.cut(vals,cuts,include_lowest=True,duplicates="drop")
        for value,g in r.groupby(buckets,observed=True):
            y=num(g.h10000_continuation_return);cond.append({"partition":chosen,"feature":feature,"bucket":str(value),"events":len(g),"episodes":g.response_episode_id.nunique(),"mean_continuation_10s":y.mean(),"median_continuation_10s":y.median(),"positive_rate_10s":float((y>0).mean()),"raw_p":1.0})
    cdf=pd.DataFrame(cond);cdf["adjusted_p_bh"]=bh(cdf.raw_p.values) if len(cdf) else [];write(cdf,out/"conditional_bias_results.csv")
    if partition=="discovery": (out/"discovery_bucket_boundaries.json").write_text(json.dumps(boundaries,indent=2),encoding="utf-8")
    write(primary[["partition","outcome","raw_p","adjusted_p_holm","supported"]],out/"multiple_testing_results.csv")
    concentration=r.groupby("symbol",as_index=False).agg(market_clusters=("market_cluster_id","nunique"),episodes=("response_episode_id","nunique"),mean_continuation_10s=("h10000_continuation_return","mean"));write(concentration,out/"effect_concentration.csv")
    trial=pd.concat([primary.assign(trial_family="PRIMARY")[ ["outcome","trial_family","partition"] ],pd.DataFrame(rr)[["strategy","stop_multiple","rr","delay_ms","spread_multiplier","partition"]].assign(trial_family="RR_GRID")],ignore_index=True,sort=False);write(trial,out/"trial_registry.csv")
    param=pd.read_csv(ROOT/"reports/analysis/tick_shock/step15b/parameter_diff.csv");param["step15c_status"]="UNCHANGED";write(param,out/"parameter_diff.csv")
    shortlist=pd.DataFrame(columns=["candidate_id","detector_id","entry_strategy","stop_multiple","rr","delay_ms","spread_multiplier","spec_hash","discovery_status","reason"])
    if partition=="discovery":write(shortlist,out/"candidate_shortlist.csv")
    svg(out/"continuation_return_curve.svg","Continuation return by horizon",[str(h) for h in HORIZONS],[float(num(r[f"h{h}_continuation_return"]).mean()) for h in HORIZONS])
    svg(out/"mfe_mae_distribution.svg","Mean MFE and MAE",["MFE","MAE"],[float(num(r.mfe).mean()),-float(num(r.mae).mean())])
    svg(out/"time_to_excursion.svg","Median time to excursion",["MFE","MAE"],[float(num(r.time_to_mfe_ms).median()),float(num(r.time_to_mae_ms).median())])
    svg(out/"first_passage_curve.svg","First-passage counts",["CONT","REV","TIME"],[int((r.barrier_10_result=="CONTINUATION_FIRST").sum()),-int((r.barrier_10_result=="REVERSAL_FIRST").sum()),int((r.barrier_10_result=="TIMEOUT").sum())])
    svg(out/"symbol_hour_heatmap.svg","Events by symbol",concentration.symbol.tolist(),concentration.market_clusters.tolist())
    svg(out/"feature_response.svg","10s continuation by symbol",concentration.symbol.tolist(),concentration.mean_continuation_10s.fillna(0).tolist())
    svg(out/"gate_overlap.svg","Leave-one-gate-out increment",[x["removed_gate"] for x in leave],[x["increment"] for x in leave])
    svg(out/"rr_sl_expectancy_heatmap.svg","RR grid unavailable before exact tick replay",["NOT_EVALUABLE"],[0])
    audit={"partition":chosen,"event_rows":len(d),"representative_clusters":len(r),"episodes":len(e),"future_reads":0,"backdates":0,"drops":int(num(d.drops).fillna(0).sum()),"duplicates":int(num(d.duplicates).fillna(0).sum()),"invalid_responses":int((d.validation_status!="VALID").sum()),"timezone_status":"TIMEZONE_MAPPING_NOT_VERIFIED","rr_grid_status":"NOT_EVALUABLE_WITH_FIXED_HORIZON_ONLY"}
    (out/"analysis_summary.json").write_text(json.dumps(audit,indent=2),encoding="utf-8")
    return audit

def main():
    ap=argparse.ArgumentParser();ap.add_argument("--run-dir",type=Path,required=True);ap.add_argument("--out",type=Path,required=True);ap.add_argument("--partition",choices=("discovery","confirmation"),required=True);args=ap.parse_args()
    audit=analyze((ROOT/args.run_dir).resolve() if not args.run_dir.is_absolute() else args.run_dir,(ROOT/args.out).resolve() if not args.out.is_absolute() else args.out,args.partition);print(json.dumps(audit,indent=2));return 0
if __name__=="__main__":raise SystemExit(main())
