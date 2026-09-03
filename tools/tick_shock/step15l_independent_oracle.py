#!/usr/bin/env python3
"""Independent Step 15L reconciliation; does not import the analysis pipeline."""
from __future__ import annotations

import argparse
import math
from pathlib import Path

import pandas as pd
from sklearn.metrics import average_precision_score, fbeta_score, precision_score, recall_score


def add(rows, check, expected, actual, tolerance=0.0, note=""):
    if isinstance(expected, (int, float)) and isinstance(actual, (int, float)):
        ok = abs(float(expected) - float(actual)) <= tolerance
    else:
        ok = expected == actual
    rows.append({"check": check, "expected": expected, "actual": actual,
                 "tolerance": tolerance, "status": "PASS" if ok else "FAIL", "note": note})


def main():
    parser=argparse.ArgumentParser();parser.add_argument("--analysis-dir",type=Path,required=True);parser.add_argument("--run-dir",type=Path,required=True)
    args=parser.parse_args();out=args.analysis_dir
    data=pd.read_csv(out/"clean_move_ml_dataset.csv");oof=pd.read_csv(out/"model_oof_predictions.csv")
    wf=pd.read_csv(out/"walk_forward_results.csv");front=pd.read_csv(out/"recall_precision_frontier.csv")
    raw=pd.read_csv(args.run_dir/"clean_move_causal_features.csv")
    rows=[]
    add(rows,"episode_count",2696,len(data));add(rows,"clean_positive",188,int(data.is_clean_move.sum()))
    add(rows,"clean_negative",2508,int((1-data.is_clean_move).sum()));add(rows,"duplicate_episode",0,int(data.episode_id.duplicated().sum()))
    expected_symbols={"AUDUSD":500,"EURUSD":248,"USDCAD":631,"USDCHF":311,"USDJPY":1006}
    for symbol,count in expected_symbols.items():add(rows,f"symbol_{symbol}",count,int((data.symbol==symbol).sum()))
    add(rows,"feature_future_sources",0,int(raw.future_sources.sum()))
    add(rows,"feature_timestamp_after_t0",0,int(sum((pd.to_numeric(raw[c],errors="coerce")>raw.t0_msc).sum() for c in raw.columns if c.endswith("_source_msc"))))
    add(rows,"walk_forward_cluster_overlap",0,int(wf.cluster_overlap.sum()));add(rows,"orders",0,len(pd.read_csv(args.run_dir/"trades.csv")))
    key=oof[(oof.model=="LIGHTGBM")&(oof.feature_group=="E_FULL")&(oof.with_symbol.astype(str).str.lower()=="false")]
    y=key.is_clean_move.astype(int).to_numpy();score=key.score.to_numpy();pred=(score>=.5).astype(int)
    saved=pd.read_csv(out/"model_comparison.csv");saved=saved[(saved.model=="LIGHTGBM")&(saved.feature_group=="E_FULL")&(saved.with_symbol.astype(str).str.lower()=="false")].iloc[0]
    add(rows,"oof_average_precision",float(saved.average_precision),float(average_precision_score(y,score)),1e-12)
    add(rows,"oof_recall_at_0.5",float(saved.recall),float(recall_score(y,pred,zero_division=0)),1e-12)
    add(rows,"oof_precision_at_0.5",float(saved.precision),float(precision_score(y,pred,zero_division=0)),1e-12)
    add(rows,"oof_f2_at_0.5",float(saved.f2),float(fbeta_score(y,pred,beta=2,zero_division=0)),1e-12)
    ranked=key.sort_values(["score","t0_msc","episode_id"],ascending=[False,True,True]);total=int(ranked.is_clean_move.sum())
    for n in (100,200,300,500,800,1000):
        g=ranked.head(n);saved_row=front[(front.evaluation_scope=="WALK_FORWARD_OOF")&(front.model=="LIGHTGBM")&(front.with_symbol.astype(str).str.lower()=="false")&(front.frontier_type=="TOP_COUNT")&(front.frontier_value==n)].iloc[0]
        add(rows,f"frontier_top_{n}_captured",int(saved_row.clean_captured),int(g.is_clean_move.sum()))
    result=pd.DataFrame(rows);result.to_csv(out/"independent_recalculation.csv",index=False)
    lines=["# Step 15L independent reconciliation","",f"- Checks: {len(result)}",f"- PASS: {(result.status=='PASS').sum()}",f"- FAIL: {(result.status=='FAIL').sum()}",f"- OOF episodes: {len(key)}",f"- OOF clean positives: {total}","","> This oracle reads persisted datasets and predictions and independently recomputes counts, chronology, AP, threshold metrics, and ranking frontiers. It does not import the production feature code or the analysis module.",""]
    (out/"independent_recalculation.md").write_text("\n".join(lines),encoding="utf-8")
    print(f"checks={len(result)} pass={(result.status=='PASS').sum()} fail={(result.status=='FAIL').sum()}")


if __name__=="__main__":main()
