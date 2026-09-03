#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv,math
from collections import Counter
from pathlib import Path

def read(p):
    with p.open(encoding="utf-8-sig",newline="") as f:return list(csv.DictReader(f))
def n(x):
    try:return float(x)
    except:return math.nan
def main():
    ap=argparse.ArgumentParser();ap.add_argument("--run-dir",type=Path,required=True);ap.add_argument("--analysis-dir",type=Path,required=True);a=ap.parse_args()
    raw=read(a.run_dir/"post_shock_excursion.csv");data=read(a.analysis_dir/"episode_tradeable_move_dataset.csv");matrix=read(a.analysis_dir/"tradeable_geometry_matrix.csv");funnel={r["stage"]:int(r["count"]) for r in read(a.analysis_dir/"population_funnel.csv")};lag=read(a.analysis_dir/"horizon_lag_audit.csv")
    checks=[]
    def add(name,expected,actual):checks.append({"check":name,"expected":expected,"actual":actual,"status":"PASS" if str(expected)==str(actual) else "FAIL"})
    add("episode_count",len(raw),len(data));add("detector_funnel_positive",True,funnel["detector_event"]>0);add("relative_not_above_ready",True,funnel["relative_state_ready"]<=funnel["analysis_ready"]);add("high_not_above_relative",True,funnel["high_movement_selected"]<=funnel["relative_state_ready"])
    add("duplicate_episode",0,len(data)-len({r["episode_id"] for r in data}));add("pre_t0_entry",0,sum(bool(r["entry_quote_msc"]) and int(r["entry_quote_msc"])<int(r["t0_msc"]) for r in data));add("future_feature",0,sum(int(r["feature_source_msc"] or 0)>int(r["t0_msc"]) for r in data));add("available_lag_over_30000",0,sum(r["horizon_status"]=="AVAILABLE" and n(r["snapshot_lag_ms"])>30000 for r in lag));add("matrix_cells",45,len(matrix));add("matrix_partition",0,sum(int(r["either_clean"])+int(r["noisy"])+int(r["insufficient"])-int(r["eligible_count"]) for r in matrix))
    add("rr_formula",0,sum(abs(n(r["rr_equivalent"])-n(r["tp_atr"])/n(r["max_pre_tp_mae_atr"]))>1e-12 for r in matrix));add("orders",0,len(read(a.run_dir/"trades.csv")))
    out=a.analysis_dir/"independent_oracle.csv";out.parent.mkdir(parents=True,exist_ok=True)
    with out.open("w",encoding="utf-8",newline="") as f:w=csv.DictWriter(f,fieldnames=list(checks[0]));w.writeheader();w.writerows(checks)
    bad=sum(r["status"]!="PASS" for r in checks);print(f"oracle={len(checks)} pass={len(checks)-bad} fail={bad}");raise SystemExit(1 if bad else 0)
if __name__=="__main__":main()
