#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv
from pathlib import Path

EXCLUDE={"run_id","episode_id","event_id","anchor_event_id","source_commit","schema_version","status"}
def read(p):
    with p.open(encoding="utf-8-sig",newline="") as f:return list(csv.DictReader(f))
def key(r):
    if "candidate_time_msc" in r:return (r.get("symbol"),r.get("candidate_time_msc"),r.get("trigger_horizon_ms"),r.get("direction"))
    if "anchor_msc" in r:return (r.get("symbol"),r.get("anchor_msc"))
    return (r.get("symbol"),r.get("statistical_msc"))
def main():
    ap=argparse.ArgumentParser();ap.add_argument("--baseline",type=Path,required=True);ap.add_argument("--candidate",type=Path,required=True);ap.add_argument("--out",type=Path,required=True);a=ap.parse_args();out=[]
    for filename,component in (("detector_features.csv","detector"),("medium_horizon_episode_summary.csv","episode")):
        left=read(a.baseline/filename);right=read(a.candidate/filename);lm={key(r):r for r in left};rm={key(r):r for r in right};cols=sorted((set(left[0])&set(right[0]))-EXCLUDE);bad=0
        for k in set(lm)&set(rm):bad+=any(lm[k].get(c,"")!=rm[k].get(c,"") for c in cols)
        out.append({"component":component,"baseline_rows":len(left),"candidate_rows":len(right),"matched_keys":len(set(lm)&set(rm)),"compared_columns":len(cols),"mismatch_rows":bad,"expected_difference":"none","status":"PASS" if len(left)==len(right)==len(set(lm)&set(rm)) and bad==0 else "FAIL"})
    left=read(a.baseline/"post_shock_excursion.csv");right=read(a.candidate/"post_shock_excursion.csv");lm={key(r):r for r in left};complete=[r for r in right if r["status"]=="COMPLETE_3600S"];cols=sorted(((set(left[0])&set(right[0]))-EXCLUDE)-{"h30_quote_msc","h60_quote_msc","h120_quote_msc","h300_quote_msc","h600_quote_msc","h900_quote_msc","h1800_quote_msc","h3600_quote_msc"});bad=0
    for r in complete:
        old=lm.get(key(r));bad+=old is None or any(old.get(c,"")!=r.get(c,"") for c in cols)
    out.append({"component":"complete_excursion","baseline_rows":len(left),"candidate_rows":len(right),"matched_keys":len(complete),"compared_columns":len(cols),"mismatch_rows":bad,"expected_difference":"46 lag-censored plus end-of-data status; new lag columns","status":"PASS" if bad==0 else "FAIL"})
    a.out.parent.mkdir(parents=True,exist_ok=True)
    with a.out.open("w",encoding="utf-8",newline="") as f:w=csv.DictWriter(f,fieldnames=list(out[0]));w.writeheader();w.writerows(out)
    print(out);raise SystemExit(1 if any(r["status"]!="PASS" for r in out) else 0)
if __name__=="__main__":main()
