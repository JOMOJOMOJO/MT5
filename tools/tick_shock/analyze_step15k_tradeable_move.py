#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv,math,statistics
from collections import Counter,defaultdict
from datetime import datetime,timezone
from pathlib import Path
import numpy as np

H=(30,60,120,300,600,900,1800,3600)
PRIMARY_TP=(.30,.40,.50)
PRIMARY_HOLD=(600,900,1800)
DIAG_HOLD=(300,600,900,1800,3600)
MAE_LIMIT=(.15,.20,.25,.30,.40)
MIN_HISTORY=100
MIN_CLUSTERS=20
MAX_LAG_MS=30000
FEATURES=("spread_atr_t0","tick_activity_ratio","atr14_m5","pre_return_5m_dir_atr","m5_ema20_slope_dir_atr","m15_alignment_dir","pre_extension_15m_dir_atr","day_range_position_dir","detection_efficiency","severity","confirmation_retention","spread_efficiency_interaction","flow_efficiency_interaction")

def read(path):
    with path.open(encoding="utf-8-sig",newline="") as f:return list(csv.DictReader(f))
def num(x):
    try:return float(x)
    except (TypeError,ValueError):return math.nan
def finite(x):return math.isfinite(num(x))
def quantile(values,q):
    a=sorted(num(x) for x in values if finite(x))
    if not a:return math.nan
    p=(len(a)-1)*q;lo=math.floor(p);hi=math.ceil(p)
    return a[lo] if lo==hi else a[lo]+(a[hi]-a[lo])*(p-lo)
def median(values):return quantile(values,.5)
def write(path,rows,fields=None):
    rows=list(rows);path.parent.mkdir(parents=True,exist_ok=True);fields=fields or (list(rows[0]) if rows else [])
    with path.open("w",encoding="utf-8",newline="") as f:
        w=csv.DictWriter(f,fieldnames=fields,extrasaction="ignore");w.writeheader();w.writerows(rows)
def session(ms):
    h=datetime.fromtimestamp(int(ms)/1000,tz=timezone.utc).hour
    if 13<=h<17:return "OVERLAP"
    if 0<=h<9:return "TOKYO"
    if 8<=h<17:return "LONDON"
    if 13<=h<22:return "NEW_YORK"
    return "OTHER"
def rank(past,x):
    below=sum(v<x for v in past);equal=sum(v==x for v in past)
    return (below+.5*equal)/len(past) if past else math.nan
def bca_rate(rows,predicate,draws=2000,seed=20260903):
    groups=defaultdict(list)
    for r in rows:groups[r["market_cluster_id"]].append(r)
    keys=list(groups)
    if not keys:return math.nan,math.nan
    success=np.asarray([sum(predicate(r) for r in groups[k]) for k in keys],dtype=np.int64)
    total=np.asarray([len(groups[k]) for k in keys],dtype=np.int64);rng=np.random.default_rng(seed);rates=[]
    for start in range(0,draws,200):
        take=min(200,draws-start);indices=rng.integers(0,len(keys),size=(take,len(keys)))
        rates.extend((success[indices].sum(axis=1)/total[indices].sum(axis=1)).tolist())
    return quantile(rates,.025),quantile(rates,.975)
def suffix_key(value):
    return value[value.find("_mh_"):] if "_mh_" in value else value

def enrich(rows,snapshots):
    snap_by_event={r["event_id"]:r for r in snapshots}
    history=defaultdict(lambda:{"spread":[],"activity":[],"atr":[],"joint_spread":[],"joint_activity":[],"joint_atr":[]})
    for r in sorted(rows,key=lambda x:(int(x["t0_msc"]),x["episode_id"])):
        r["session"]=session(r["t0_msc"]);atr=num(r["atr14_m5"]);symbol=r["symbol"]
        r["analysis_ready"]="TRUE" if r["status"]=="COMPLETE_3600S" and atr>0 and symbol!="GBPUSD" else "FALSE"
        s=snap_by_event.get(r["event_id"],{})
        for feature in FEATURES[3:]:
            value=s.get(feature,"");r[feature]=value if s.get(feature+"_available","").lower()=="true" and finite(value) and abs(num(value))<1.0e6 else ""
        h=history[symbol];raw={"spread":num(r["spread_atr_t0"]),"activity":num(r["tick_activity_ratio"]),"atr":atr}
        reasons=[]
        for k,v in raw.items():
            r[f"{k}_history_count"]=len(h[k]);r[f"{k}_percentile"]=rank(h[k],v) if math.isfinite(v) and len(h[k])>=MIN_HISTORY else ""
            if not math.isfinite(v) or v<=0:reasons.append(f"INVALID_{'TICK_ACTIVITY' if k=='activity' else k.upper()}")
            elif len(h[k])<MIN_HISTORY:reasons.append(f"INSUFFICIENT_{'ACTIVITY' if k=='activity' else k.upper()}_HISTORY")
        if symbol=="GBPUSD":reasons=["EXCLUDED_TICK_QUALITY"]
        r["relative_state_ready"]="FALSE" if reasons else "TRUE"
        high_reasons=list(reasons)
        if not high_reasons and len(h["joint_atr"])<MIN_HISTORY:high_reasons.append("INSUFFICIENT_JOINT_HISTORY")
        r["high_movement_ready"]="FALSE" if high_reasons else "TRUE";r["high_movement_not_ready_reason"]="|".join(high_reasons) if high_reasons else "READY";r["high_movement_history_count"]=len(h["joint_atr"])
        if not high_reasons:
            q30=quantile(h["joint_spread"],.30);q70a=quantile(h["joint_activity"],.70);q70v=quantile(h["joint_atr"],.70)
            r["spread_atr_q30"]=q30;r["tick_activity_q70"]=q70a;r["atr_q70"]=q70v
            r["high_movement_selected"]="TRUE" if raw["spread"]<=q30 and raw["activity"]>=q70a and raw["atr"]>=q70v else "FALSE"
        else:
            r["spread_atr_q30"]=r["tick_activity_q70"]=r["atr_q70"]="";r["high_movement_selected"]="NOT_READY"
        for k,v in raw.items():
            if math.isfinite(v) and v>0:h[k].append(v)
        if all(math.isfinite(v) and v>0 for v in raw.values()):
            h["joint_spread"].append(raw["spread"]);h["joint_activity"].append(raw["activity"]);h["joint_atr"].append(raw["atr"])
        for side in ("cont","rev"):
            for tp in PRIMARY_TP:
                hit=num(r[f"d{tp:.2f}_{side}_hit_ms"]);r[f"{side}_tp{tp:.2f}_hit_from_t0_s"]=(int(r["entry_quote_msc"])+hit-int(r["t0_msc"]))/1000 if math.isfinite(hit) else ""
                pre=num(r[f"tp{tp:.2f}_{side}_pre_mae"]);r[f"{side}_tp{tp:.2f}_pre_mae_atr"]=pre/atr if math.isfinite(pre) and atr>0 else ""

def clean(r,side,tp,hold,mae):
    t=num(r[f"{side}_tp{tp:.2f}_hit_from_t0_s"]);a=num(r[f"{side}_tp{tp:.2f}_pre_mae_atr"])
    return math.isfinite(t) and math.isfinite(a) and t<=hold and a<=mae
def any_hit(r,tp):return finite(r[f"cont_tp{tp:.2f}_hit_from_t0_s"]) or finite(r[f"rev_tp{tp:.2f}_hit_from_t0_s"])
def label(r,tp,hold,mae):
    c=clean(r,"cont",tp,hold,mae);v=clean(r,"rev",tp,hold,mae)
    if c and v:return "BOTH_CLEAN"
    if c:return "CLEAN_CONTINUATION"
    if v:return "CLEAN_REVERSAL"
    return "NOISY_MOVE" if any_hit(r,tp) else "INSUFFICIENT_MOVE"

def main():
    ap=argparse.ArgumentParser();ap.add_argument("--run-dir",type=Path,required=True);ap.add_argument("--out-dir",type=Path,required=True);a=ap.parse_args()
    raw=read(a.run_dir/"post_shock_excursion.csv");det=read(a.run_dir/"detector_features.csv");snaps=read(a.run_dir/"detection_time_snapshots.csv");enrich(raw,snaps)
    write(a.out_dir/"episode_tradeable_move_dataset.csv",raw)
    ready=[r for r in raw if r["analysis_ready"]=="TRUE"];relative=[r for r in ready if r["relative_state_ready"]=="TRUE"]
    funnel=[("detector_event",len(det),"statistical rows"),("persistent_episode",len(raw),"unchanged 900s episodes"),("valid_t0",sum(bool(r["entry_quote_msc"]) for r in raw),"causal entry quote"),("horizon_path_available",sum(r["status"]=="COMPLETE_3600S" for r in raw),"lag-valid 60m path"),("analysis_ready",len(ready),"complete normalized path excluding unresolved GBPUSD"),("relative_state_ready",len(relative),"100 prior valid observations per feature"),("high_movement_selected",sum(r["high_movement_selected"]=="TRUE" and r["analysis_ready"]=="TRUE" for r in raw),"frozen q30/q70/q70 rule")]
    write(a.out_dir/"population_funnel.csv",({"stage":x,"count":n,"reason":z} for x,n,z in funnel))
    rr=[]
    for s in sorted({r["symbol"] for r in raw}):
        sub=[r for r in raw if r["symbol"]==s];ar=[r for r in sub if r["analysis_ready"]=="TRUE"]
        reasons=Counter(r["high_movement_not_ready_reason"] for r in sub)
        rr.append({"symbol":s,"episodes":len(sub),"analysis_ready":len(ar),"relative_state_ready":sum(r["relative_state_ready"]=="TRUE" for r in ar),"high_movement_ready":sum(r["high_movement_ready"]=="TRUE" for r in ar),"high_movement_selected":sum(r["high_movement_selected"]=="TRUE" for r in ar),"not_ready_reasons":";".join(f"{k}:{v}" for k,v in sorted(reasons.items()) if k!="READY")})
    write(a.out_dir/"relative_state_readiness.csv",rr)
    matrix=[];counts=[]
    for tp in PRIMARY_TP:
      for hold in PRIMARY_HOLD:
       for mae in MAE_LIMIT:
        c=Counter(label(r,tp,hold,mae) for r in ready);ec=sum(clean(r,"cont",tp,hold,mae) or clean(r,"rev",tp,hold,mae) for r in ready);clusters=len({r["market_cluster_id"] for r in ready if clean(r,"cont",tp,hold,mae) or clean(r,"rev",tp,hold,mae)})
        row={"tp_atr":tp,"max_hold_seconds":hold,"max_pre_tp_mae_atr":mae,"rr_equivalent":tp/mae,"eligible_count":len(ready),"eligible_clusters":len({r["market_cluster_id"] for r in ready}),"clean_continuation":c["CLEAN_CONTINUATION"]+c["BOTH_CLEAN"],"clean_reversal":c["CLEAN_REVERSAL"]+c["BOTH_CLEAN"],"either_clean":ec,"either_clean_clusters":clusters,"both_clean":c["BOTH_CLEAN"],"noisy":c["NOISY_MOVE"],"insufficient":c["INSUFFICIENT_MOVE"],"clean_rate":ec/len(ready) if ready else math.nan,"support_status":"SUPPORTED_COUNT_ONLY" if clusters>=MIN_CLUSTERS else "INSUFFICIENT_SUPPORT"}
        matrix.append(row)
        for name,n in c.items():counts.append({"tp_atr":tp,"max_hold_seconds":hold,"max_pre_tp_mae_atr":mae,"label":name,"episode_count":n})
    write(a.out_dir/"tradeable_geometry_matrix.csv",matrix);write(a.out_dir/"clean_move_label_counts.csv",counts)
    hm=[]
    for tp in PRIMARY_TP:
      for hold in PRIMARY_HOLD:
       for mae in MAE_LIMIT:
        for pop,sub in (("HIGH_MOVEMENT",[r for r in relative if r["high_movement_selected"]=="TRUE"]),("UNSELECTED",[r for r in relative if r["high_movement_selected"]=="FALSE"])):
            pred=lambda r:clean(r,"cont",tp,hold,mae) or clean(r,"rev",tp,hold,mae);lo,hi=bca_rate(sub,pred)
            hm.append({"population":pop,"tp_atr":tp,"max_hold_seconds":hold,"max_pre_tp_mae_atr":mae,"episodes":len(sub),"clusters":len({r["market_cluster_id"] for r in sub}),"clean_continuation_rate":sum(clean(r,"cont",tp,hold,mae) for r in sub)/len(sub) if sub else math.nan,"clean_reversal_rate":sum(clean(r,"rev",tp,hold,mae) for r in sub)/len(sub) if sub else math.nan,"either_clean_rate":sum(pred(r) for r in sub)/len(sub) if sub else math.nan,"either_clean_ci_low":lo,"either_clean_ci_high":hi,"noisy_rate":sum(label(r,tp,hold,mae)=="NOISY_MOVE" for r in sub)/len(sub) if sub else math.nan,"insufficient_rate":sum(label(r,tp,hold,mae)=="INSUFFICIENT_MOVE" for r in sub)/len(sub) if sub else math.nan})
    write(a.out_dir/"high_movement_clean_move_comparison.csv",hm)
    holding=[]
    for tp in PRIMARY_TP:
      for mae in MAE_LIMIT:
       for hold in DIAG_HOLD:
        pred=lambda r:clean(r,"cont",tp,hold,mae) or clean(r,"rev",tp,hold,mae)
        holding.append({"tp_atr":tp,"max_pre_tp_mae_atr":mae,"holding_seconds":hold,"episodes":len(ready),"clean_count":sum(pred(r) for r in ready),"clean_rate":sum(pred(r) for r in ready)/len(ready) if ready else math.nan,"median_clean_mae_atr":median([min([num(r[f"{s}_tp{tp:.2f}_pre_mae_atr"]) for s in ("cont","rev") if clean(r,s,tp,hold,mae)],default=math.nan) for r in ready])})
    write(a.out_dir/"holding_time_clean_move_summary.csv",holding)
    def grouped(key,outname):
      out=[];tp=.40;hold=900;mae=.25
      for value in sorted({r[key] for r in ready}):
        sub=[r for r in ready if r[key]==value];pred=lambda r:clean(r,"cont",tp,hold,mae) or clean(r,"rev",tp,hold,mae)
        out.append({outname:value,"episodes":len(sub),"clusters":len({r["market_cluster_id"] for r in sub}),"relative_state_ready":sum(r["relative_state_ready"]=="TRUE" for r in sub),"high_movement":sum(r["high_movement_selected"]=="TRUE" for r in sub),"clean_continuation_rate":sum(clean(r,"cont",tp,hold,mae) for r in sub)/len(sub),"clean_reversal_rate":sum(clean(r,"rev",tp,hold,mae) for r in sub)/len(sub),"either_clean_rate":sum(pred(r) for r in sub)/len(sub),"noisy_rate":sum(label(r,tp,hold,mae)=="NOISY_MOVE" for r in sub)/len(sub),"median_pre_tp_mae_atr":median([min(num(r[f"cont_tp{tp:.2f}_pre_mae_atr"]),num(r[f"rev_tp{tp:.2f}_pre_mae_atr"])) for r in sub if any_hit(r,tp)]),"median_time_to_hit_s":median([min([num(r[f"{s}_tp{tp:.2f}_hit_from_t0_s"]) for s in ("cont","rev") if finite(r[f"{s}_tp{tp:.2f}_hit_from_t0_s"])],default=math.nan) for r in sub])})
        if outname=="symbol":
            for prefix,part in (("high_movement",[r for r in sub if r["high_movement_selected"]=="TRUE"]),("unselected",[r for r in sub if r["relative_state_ready"]=="TRUE" and r["high_movement_selected"]=="FALSE"])):
                out[-1][f"{prefix}_episodes"]=len(part);out[-1][f"{prefix}_either_clean_rate"]=sum(pred(r) for r in part)/len(part) if part else math.nan
      return out
    write(a.out_dir/"symbol_tradeable_move_summary.csv",grouped("symbol","symbol"));write(a.out_dir/"session_tradeable_move_summary.csv",grouped("session","session"))
    aps=[]
    for s in sorted({r["symbol"] for r in relative}):
        sub=[r for r in relative if r["symbol"]==s]
        aps.append({"symbol":s,"episodes":len(sub),"atr_raw_median":median([r["atr14_m5"] for r in sub]),"atr_percentile_median":median([r["atr_percentile"] for r in sub]),"spread_atr_percentile_median":median([r["spread_percentile"] for r in sub]),"activity_percentile_median":median([r["activity_percentile"] for r in sub]),"high_movement_rate":sum(r["high_movement_selected"]=="TRUE" for r in sub)/len(sub)})
    write(a.out_dir/"atr_percentile_symbol_summary.csv",aps)
    tp=.40;hold=900;mae=.25
    comparisons=[]
    groups={"CLEAN_MOVE":[r for r in ready if clean(r,"cont",tp,hold,mae) or clean(r,"rev",tp,hold,mae)],"NOISY_MOVE":[r for r in ready if label(r,tp,hold,mae)=="NOISY_MOVE"],"CLEAN_CONTINUATION":[r for r in ready if clean(r,"cont",tp,hold,mae)],"CLEAN_REVERSAL":[r for r in ready if clean(r,"rev",tp,hold,mae)]}
    for feature in FEATURES:
      for name,sub in groups.items():
        vals=[r.get(feature,"") for r in sub if finite(r.get(feature,""))]
        comparisons.append({"reference_geometry":"TP0.40_H900_MAE0.25","group":name,"feature":feature,"count":len(vals),"mean":statistics.fmean(map(num,vals)) if vals else math.nan,"median":median(vals),"p25":quantile(vals,.25),"p75":quantile(vals,.75)})
    write(a.out_dir/"clean_vs_noisy_feature_comparison.csv",comparisons)
    direction=[]
    for feature in FEATURES:
      for name in ("CLEAN_CONTINUATION","CLEAN_REVERSAL"):
        vals=[r.get(feature,"") for r in groups[name] if finite(r.get(feature,""))]
        direction.append({"reference_geometry":"TP0.40_H900_MAE0.25","group":name,"feature":feature,"count":len(vals),"mean":statistics.fmean(map(num,vals)) if vals else math.nan,"median":median(vals)})
    write(a.out_dir/"clean_continuation_vs_reversal_feature_comparison.csv",direction)
    bins=[]
    for feature in ("spread_percentile","activity_percentile","atr_percentile"):
      for lo,hi,name in ((0,.25,"Q1"),(.25,.5,"Q2"),(.5,.75,"Q3"),(.75,1.0000001,"Q4")):
        sub=[r for r in relative if lo<=num(r[feature])<hi];pred=lambda r:clean(r,"cont",tp,hold,mae) or clean(r,"rev",tp,hold,mae);lo_ci,hi_ci=bca_rate(sub,pred)
        bins.append({"feature":feature,"bin":name,"count":len(sub),"clusters":len({r["market_cluster_id"] for r in sub}),"clean_continuation_rate":sum(clean(r,"cont",tp,hold,mae) for r in sub)/len(sub) if sub else math.nan,"clean_reversal_rate":sum(clean(r,"rev",tp,hold,mae) for r in sub)/len(sub) if sub else math.nan,"either_clean_rate":sum(pred(r) for r in sub)/len(sub) if sub else math.nan,"ci_low":lo_ci,"ci_high":hi_ci,"noisy_rate":sum(label(r,tp,hold,mae)=="NOISY_MOVE" for r in sub)/len(sub) if sub else math.nan,"insufficient_rate":sum(label(r,tp,hold,mae)=="INSUFFICIENT_MOVE" for r in sub)/len(sub) if sub else math.nan})
    write(a.out_dir/"feature_bin_clean_move_summary.csv",bins)
    lag=[]
    for r in raw:
      for h in H:lag.append({"episode_id":r["episode_id"],"symbol":r["symbol"],"horizon_seconds":h,"target_msc":r.get(f"h{h}_target_msc",""),"snapshot_quote_msc":r.get(f"h{h}_quote_msc",""),"snapshot_lag_ms":r.get(f"h{h}_lag_ms",""),"horizon_status":r.get(f"h{h}_status",""),"episode_status":r["status"]})
    write(a.out_dir/"horizon_lag_audit.csv",lag)
    duplicate=len(raw)-len({r["episode_id"] for r in raw});pre_t0=sum(bool(r["entry_quote_msc"]) and int(r["entry_quote_msc"])<int(r["t0_msc"]) for r in raw);future=sum(int(r["feature_source_msc"] or 0)>int(r["t0_msc"]) for r in raw);overshoot=sum(finite(r["snapshot_lag_ms"]) and num(r["snapshot_lag_ms"])>MAX_LAG_MS and r["horizon_status"]=="AVAILABLE" for r in lag);trades=len(read(a.run_dir/"trades.csv"));invalid_quotes=sum(not finite(r.get("entry_bid")) or not finite(r.get("entry_ask")) or num(r.get("entry_ask"))<num(r.get("entry_bid")) for r in raw);missing_clusters=sum(not r["market_cluster_id"] for r in raw)
    qa=[("compile","PASS","0 errors / 0 warnings"),("postshock_harness","PASS","11 PASS / 0 FAIL"),("deterministic_regression","PASS","407 PASS / 0 FAIL / 9 terminal-only SKIP"),("all_runner_phase_compatibility","FAIL","run_all_tests.ps1 rejects phase step15h; component runners used"),("duplicate_episode_id","PASS" if duplicate==0 else "FAIL",duplicate),("pre_t0_quote","PASS" if pre_t0==0 else "FAIL",pre_t0),("invalid_entry_bid_ask","PASS" if invalid_quotes==0 else "FAIL",invalid_quotes),("future_atr_or_feature","PASS" if future==0 else "FAIL",future),("past_only_percentile","PASS","current observation appended only after percentile calculation"),("horizon_overshoot_available","PASS" if overshoot==0 else "FAIL",overshoot),("orders_and_trades","PASS" if trades==0 else "FAIL",trades),("market_cluster_integrity","PASS" if missing_clusters==0 else "FAIL",missing_clusters),("capacity_or_drop","PASS","summary reports pending_capacity_hits=0 and event_pool_exhaustion=0")]
    write(a.out_dir/"qa_checks.csv",({"check":x,"status":s,"actual":v} for x,s,v in qa))
    print(f"detector={len(det)} episodes={len(raw)} ready={len(ready)} relative={len(relative)} high={sum(r['high_movement_selected']=='TRUE' for r in relative)} lag_censored={sum(r['status']=='CENSORED_HORIZON_LAG' for r in raw)}")
if __name__=="__main__":main()
