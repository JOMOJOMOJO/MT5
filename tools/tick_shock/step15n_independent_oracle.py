#!/usr/bin/env python3
from __future__ import annotations
import argparse
from pathlib import Path
import numpy as np
import pandas as pd

def main():
    p=argparse.ArgumentParser();p.add_argument("--run-dir",type=Path,required=True);p.add_argument("--base-dataset",type=Path,required=True);p.add_argument("--reported",type=Path,required=True);p.add_argument("--output",type=Path,required=True);a=p.parse_args()
    actions=pd.read_csv(a.run_dir/"delayed_decision_actions.csv")
    base=pd.read_csv(a.base_dataset,usecols=["symbol","t0_msc"]).drop_duplicates()
    actions=actions.merge(base,on=["symbol","t0_msc"],how="inner",validate="many_to_one")
    reported=pd.read_csv(a.reported).set_index("checkpoint_seconds")
    analysis_dir=a.reported.parent
    policies=pd.read_csv(analysis_dir/"checkpoint_policy_results.csv")
    rows=[]
    for delay,g in actions.groupby("checkpoint_seconds"):
        eligible=g[(g.checkpoint_status=="ELIGIBLE")&g.result.isin(["TP_FIRST","SL_FIRST","TIMEOUT"])].copy()
        tp_r_violation=int(((eligible.result=="TP_FIRST")&(~np.isclose(eligible.realized_r,1.6))).sum())
        sl_r_violation=int(((eligible.result=="SL_FIRST")&(~np.isclose(eligible.realized_r,-1.0))).sum())
        wide=eligible.pivot(index=["symbol","t0_msc","episode_id","market_cluster_id"],columns="action",values="realized_r").dropna()
        oracle=np.maximum(np.maximum(wide.CONTINUATION,wide.REVERSAL),0.0)
        r=reported.loc[delay]
        path_both_sl=int(((wide.CONTINUATION==-1.0)&(wide.REVERSAL==-1.0)).sum())
        reported_policy=policies[(policies.checkpoint_seconds==delay)&(policies.policy=="LIGHTGBM_TRAIN_ONLY_THRESHOLD")].iloc[0]
        predictions=pd.read_csv(analysis_dir/"checkpoint_oof_predictions.csv")
        predictions=predictions[(predictions.checkpoint_seconds==delay)&(predictions.model=="LIGHTGBM")&(predictions.scope=="ALL_NO_SYMBOL")]
        indexed=eligible.reset_index().rename(columns={"index":"action_row_index"}).drop(columns=["fold"],errors="ignore")
        selected=predictions.merge(indexed,on=["action_row_index","checkpoint_seconds"],how="left").sort_values("score",ascending=False).groupby(["episode_id","checkpoint_seconds","fold"],as_index=False).first()
        selected=selected[selected.score>=selected.threshold]
        selected_total_r=float(selected.realized_r.sum())
        rows.append(dict(checkpoint_seconds=delay,eligible_episodes=len(wide),reported_eligible=int(r.eligible_episodes),tp_first=int((eligible.result=="TP_FIRST").sum()),sl_first=int((eligible.result=="SL_FIRST").sum()),timeout=int((eligible.result=="TIMEOUT").sum()),both_sl=path_both_sl,reported_both_sl=int(r.both_sl),oracle_total_r=float(oracle.sum()),reported_oracle_total_r=float(r.oracle_total_r),oracle_expectancy=float(oracle.mean()),reported_oracle_expectancy=float(r.oracle_expectancy),selected_trades=len(selected),reported_selected_trades=int(reported_policy.trades),selected_total_r=selected_total_r,reported_selected_total_r=float(reported_policy.total_r),tp_r_violation=tp_r_violation,sl_r_violation=sl_r_violation,status="PASS" if len(wide)==int(r.eligible_episodes) and path_both_sl==int(r.both_sl) and np.isclose(oracle.sum(),r.oracle_total_r) and len(selected)==int(reported_policy.trades) and np.isclose(selected_total_r,reported_policy.total_r) and tp_r_violation==0 and sl_r_violation==0 else "FAIL"))
    pd.DataFrame(rows).to_csv(a.output,index=False)

if __name__=="__main__":main()
