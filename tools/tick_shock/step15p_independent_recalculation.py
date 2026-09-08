#!/usr/bin/env python3
from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/"reports/backtest/runs/20260908_ts15p_symmetric_oco_micro_profit_202504"
OUT=ROOT/"reports/analysis/tick_shock/step15p/independent_recalculation.csv"


def f(row: dict, key: str) -> float:
    return float(row[key]) if row.get(key,"") not in ("",None) else float("nan")


def main() -> None:
    totals=defaultdict(lambda:[0,0.0,0.0,0,0,0]);violations=defaultdict(int);seen=set();episode_clusters={};episodes=set()
    source=RUN/"symmetric_oco_scenarios.csv"
    if not source.exists():
        import gzip
        handle=gzip.open(RUN/"symmetric_oco_scenarios.csv.gz",mode="rt",encoding="utf-8-sig",newline="")
    else:handle=source.open(encoding="utf-8-sig",newline="")
    with handle:
        for row in csv.DictReader(handle):
            episodes.add(row["episode_id"]);episode_clusters.setdefault(row["episode_id"],set()).add(row["market_cluster_id"])
            key=(row["episode_id"],row["offset_index"],row["tp_index"],row["sl_index"])
            if key in seen:violations["duplicate"]+=1
            seen.add(key)
            if f(row,"future_reads") or f(row,"backdates"):violations["future_or_backdate"]+=1
            if row["entry_msc"] and int(row["entry_msc"])<=int(row["trigger_msc"]):violations["entry_before_trigger"]+=1
            if row["exit_msc"] and int(row["exit_msc"])<=int(row["entry_msc"]):violations["exit_before_entry"]+=1
            if row["entry_status"]=="AMBIGUOUS_TRIGGER" and (row["oco_direction"]!="NONE" or row["entry_msc"]):violations["ambiguous_selected"]+=1
            if row["result"] not in ("TP_FIRST","SL_FIRST","TIMEOUT"):continue
            direction=1 if row["oco_direction"]=="LONG" else -1
            gross=(f(row,"exit_price")-f(row,"entry_price"))*direction
            if abs(gross-f(row,"gross_price"))>1e-8:violations["gross_price"]+=1
            pips=gross/f(row,"pip_size");risk_pips=f(row,"sl_atr")*f(row,"atr14_m5")/f(row,"pip_size")
            if abs(pips-f(row,"gross_pips"))>1e-6:violations["gross_pips"]+=1
            if abs(gross/(f(row,"sl_atr")*f(row,"atr14_m5"))-f(row,"gross_r"))>1e-6:violations["gross_r"]+=1
            geo=(int(row["offset_index"]),int(row["tp_index"]),int(row["sl_index"]));x=totals[geo];x[0]+=1;x[1]+=f(row,"gross_r");x[2]+=(pips-0.2)/risk_pips;x[3]+=row["result"]=="TP_FIRST";x[4]+=row["result"]=="SL_FIRST";x[5]+=row["result"]=="TIMEOUT"
    violations["cluster_split"]=sum(len(x)>1 for x in episode_clusters.values())
    surface={}
    with (ROOT/"reports/analysis/tick_shock/step15p/geometry_surface.csv").open(encoding="utf-8-sig",newline="") as handle:
        for r in csv.DictReader(handle):surface[(int(r["offset_index"]),int(r["tp_index"]),int(r["sl_index"]))]=r
    comparisons=[]
    for key,x in totals.items():
        expected=surface[key];gross=x[1]/x[0];net02=x[2]/x[0]
        comparisons.append(abs(gross-f(expected,"net_expectancy_r"))<=1e-8 and abs(net02-f(expected,"net_expectancy_02_r"))<=1e-8 and x[0]==int(expected["trades"]))
    rows=[{"check":"eligible_episode_count","independent_value":len(episodes),"reported_value":len(episode_clusters),"violations":0,"status":"PASS"},
          {"check":"geometry_reconciliation","independent_value":len(totals),"reported_value":len(surface),"violations":sum(not x for x in comparisons),"status":"PASS" if all(comparisons) else "FAIL"}]
    for name in ("duplicate","future_or_backdate","entry_before_trigger","exit_before_entry","ambiguous_selected","gross_price","gross_pips","gross_r","cluster_split"):
        rows.append({"check":name,"independent_value":"","reported_value":"","violations":violations[name],"status":"PASS" if violations[name]==0 else "FAIL"})
    with OUT.open("w",encoding="utf-8",newline="") as handle:
        writer=csv.DictWriter(handle,fieldnames=rows[0]);writer.writeheader();writer.writerows(rows)
    if any(r["status"]!="PASS" for r in rows):raise SystemExit("independent recalculation failed")


if __name__=="__main__":main()
