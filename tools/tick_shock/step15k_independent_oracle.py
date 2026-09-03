#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv,math
from collections import Counter,defaultdict
from pathlib import Path

def read(p):
    with p.open(encoding="utf-8-sig",newline="") as f:return list(csv.DictReader(f))
def n(x):
    try:return float(x)
    except:return math.nan
def finite(x):return math.isfinite(n(x))
def q(values,p):
    a=sorted(values)
    if not a:return math.nan
    x=(len(a)-1)*p;lo=math.floor(x);hi=math.ceil(x)
    return a[lo] if lo==hi else a[lo]+(a[hi]-a[lo])*(x-lo)
def rank(values,x):return (sum(v<x for v in values)+.5*sum(v==x for v in values))/len(values)
def clean(r,side,tp,hold,mae):
    t=n(r[f"{side}_tp{tp:.2f}_hit_from_t0_s"]);a=n(r[f"{side}_tp{tp:.2f}_pre_mae_atr"])
    return math.isfinite(t) and math.isfinite(a) and t<=hold and a<=mae
def label(r,tp,hold,mae):
    c=clean(r,"cont",tp,hold,mae);v=clean(r,"rev",tp,hold,mae)
    if c and v:return "BOTH_CLEAN"
    if c:return "CLEAN_CONTINUATION"
    if v:return "CLEAN_REVERSAL"
    hit=finite(r[f"cont_tp{tp:.2f}_hit_from_t0_s"]) or finite(r[f"rev_tp{tp:.2f}_hit_from_t0_s"])
    return "NOISY_MOVE" if hit else "INSUFFICIENT_MOVE"
def main():
    ap=argparse.ArgumentParser();ap.add_argument("--run-dir",type=Path,required=True);ap.add_argument("--analysis-dir",type=Path,required=True);a=ap.parse_args()
    raw=read(a.run_dir/"post_shock_excursion.csv");data=read(a.analysis_dir/"episode_tradeable_move_dataset.csv");matrix=read(a.analysis_dir/"tradeable_geometry_matrix.csv");funnel={r["stage"]:int(r["count"]) for r in read(a.analysis_dir/"population_funnel.csv")};lag=read(a.analysis_dir/"horizon_lag_audit.csv");holding=read(a.analysis_dir/"holding_time_clean_move_summary.csv");symbols=read(a.analysis_dir/"symbol_tradeable_move_summary.csv")
    checks=[]
    def add(name,expected,actual):checks.append({"check":name,"expected":expected,"actual":actual,"status":"PASS" if str(expected)==str(actual) else "FAIL"})
    add("episode_count",len(raw),len(data));add("detector_funnel_positive",True,funnel["detector_event"]>0);add("relative_not_above_ready",True,funnel["relative_state_ready"]<=funnel["analysis_ready"]);add("high_not_above_relative",True,funnel["high_movement_selected"]<=funnel["relative_state_ready"])
    add("duplicate_episode",0,len(data)-len({r["episode_id"] for r in data}));add("pre_t0_entry",0,sum(bool(r["entry_quote_msc"]) and int(r["entry_quote_msc"])<int(r["t0_msc"]) for r in data));add("future_feature",0,sum(int(r["feature_source_msc"] or 0)>int(r["t0_msc"]) for r in data));add("available_lag_over_30000",0,sum(r["horizon_status"]=="AVAILABLE" and n(r["snapshot_lag_ms"])>30000 for r in lag));add("matrix_cells",45,len(matrix));add("matrix_partition",0,sum(int(r["either_clean"])+int(r["noisy"])+int(r["insufficient"])-int(r["eligible_count"]) for r in matrix))
    add("rr_formula",0,sum(abs(n(r["rr_equivalent"])-n(r["tp_atr"])/n(r["max_pre_tp_mae_atr"]))>1e-12 for r in matrix));add("orders",0,len(read(a.run_dir/"trades.csv")))

    # Rebuild every past-only percentile and the frozen high-movement selector
    # without importing the analysis implementation.
    histories=defaultdict(lambda:{"spread":[],"activity":[],"atr":[],"joint_spread":[],"joint_activity":[],"joint_atr":[]});pct_bad=0;high_bad=0
    for r in sorted(data,key=lambda x:(int(x["t0_msc"]),x["episode_id"])):
        h=histories[r["symbol"]];vals={"spread":n(r["spread_atr_t0"]),"activity":n(r["tick_activity_ratio"]),"atr":n(r["atr14_m5"])}
        valid=all(math.isfinite(v) and v>0 for v in vals.values())
        for k,v in vals.items():
            expected=rank(h[k],v) if math.isfinite(v) and len(h[k])>=100 else math.nan
            actual=n(r[f"{k}_percentile"])
            if (math.isfinite(expected) != math.isfinite(actual)) or (math.isfinite(expected) and abs(expected-actual)>1e-12):pct_bad+=1
        ready=valid and len(h["joint_atr"])>=100 and r["symbol"]!="GBPUSD"
        expected_high="NOT_READY"
        if ready:
            expected_high="TRUE" if vals["spread"]<=q(h["joint_spread"],.30) and vals["activity"]>=q(h["joint_activity"],.70) and vals["atr"]>=q(h["joint_atr"],.70) else "FALSE"
        if r["high_movement_selected"]!=expected_high:high_bad+=1
        for k,v in vals.items():
            if math.isfinite(v) and v>0:h[k].append(v)
        if valid:
            for k,v in vals.items():h[f"joint_{k}"].append(v)
    add("past_only_percentiles",0,pct_bad);add("high_movement_selector",0,high_bad)

    # Recalculate all 45 label partitions from raw directional hit time and MAE.
    ready=[r for r in data if r["analysis_ready"]=="TRUE"];matrix_bad=0
    for m in matrix:
        tp=n(m["tp_atr"]);hold=int(m["max_hold_seconds"]);mae=n(m["max_pre_tp_mae_atr"]);c=Counter(label(r,tp,hold,mae) for r in ready)
        expected={"clean_continuation":c["CLEAN_CONTINUATION"]+c["BOTH_CLEAN"],"clean_reversal":c["CLEAN_REVERSAL"]+c["BOTH_CLEAN"],"both_clean":c["BOTH_CLEAN"],"noisy":c["NOISY_MOVE"],"insufficient":c["INSUFFICIENT_MOVE"]}
        matrix_bad+=sum(int(m[k])!=v for k,v in expected.items())
    add("all_matrix_label_counts",0,matrix_bad)

    # Independently reconcile the registered holding and symbol summaries.
    hold_bad=0
    for r in holding:
        tp=n(r["tp_atr"]);mae=n(r["max_pre_tp_mae_atr"]);hold=int(r["holding_seconds"])
        expected=sum(clean(x,"cont",tp,hold,mae) or clean(x,"rev",tp,hold,mae) for x in ready)
        hold_bad+=int(r["clean_count"])!=expected
    add("holding_summary_counts",0,hold_bad)
    symbol_bad=0
    for r in symbols:
        sub=[x for x in ready if x["symbol"]==r["symbol"]]
        expected=sum(clean(x,"cont",.40,900,.25) or clean(x,"rev",.40,900,.25) for x in sub)
        actual=round(n(r["either_clean_rate"])*len(sub))
        symbol_bad+=expected!=actual
    add("symbol_summary_counts",0,symbol_bad)
    add("analysis_ready_funnel",sum(r["analysis_ready"]=="TRUE" for r in data),funnel["analysis_ready"])
    add("relative_ready_funnel",sum(r["analysis_ready"]=="TRUE" and r["relative_state_ready"]=="TRUE" for r in data),funnel["relative_state_ready"])
    add("high_selected_funnel",sum(r["analysis_ready"]=="TRUE" and r["high_movement_selected"]=="TRUE" for r in data),funnel["high_movement_selected"])
    out=a.analysis_dir/"independent_oracle.csv";out.parent.mkdir(parents=True,exist_ok=True)
    with out.open("w",encoding="utf-8",newline="") as f:w=csv.DictWriter(f,fieldnames=list(checks[0]));w.writeheader();w.writerows(checks)
    bad=sum(r["status"]!="PASS" for r in checks);print(f"oracle={len(checks)} pass={len(checks)-bad} fail={bad}");raise SystemExit(1 if bad else 0)
if __name__=="__main__":main()
