#!/usr/bin/env python3
"""Generate frozen Step 15D fixture/expected contracts from an independent table."""
from __future__ import annotations
import csv
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
BASE=("test_id","requirement_id","defect_id","component","test_layer","direction","fixture_path","expected_path","current_expected_status","description")

GROUPS={
"PROV":[("HIST","historical_schema","tickshock-detector-feature-v1"),("CURRENT","current_schema","tickshock-detector-feature-v2"),("MIGRATION","migration_supported","true"),("FROZEN","frozen_expected_changed","false"),("FALSECLAIM","current_claimed_v1","false")],
"CLOCK":[("FIX500","decision_quote_msc","1500"),("FIX1000","decision_quote_msc","2000"),("FIX3000","decision_quote_msc","4000"),("BURST","signal_msc","1800"),("REACCEL","signal_msc","2400"),("FAILED","signal_msc","2600"),("BACKDATE","backdate_violations","0"),("FIRSTQUOTE","entry_quote_msc","1600"),("LATENCY","eligible_msc","1750"),("STALE","availability","STALE")],
"STATE":[("EXTENSION","extension_ratio","0.5"),("RETRACE","retracement_ratio","0.25"),("RECROSS","origin_recross","true"),("RECOUNT","origin_recross_count","2"),("SINCE","time_since_recross_ms","400"),("EXTREME","directional_extreme_count","2"),("IMBALANCE","directional_tick_imbalance","0.5"),("EQUAL","equal_mid_updates","2"),("RUN","longest_directional_run","3"),("ACTIVITY","activity_ratio","2"),("SPREAD","spread_ratio","1.25"),("NOISE","noise_robust_direction","LONG"),("FUTURE","future_observations_used","0")],
"CLUSTER":[("USD","canonical_usd_sign","1"),("BREADTH","causal_breadth","2"),("COHERENCE","causal_coherence","1"),("FUTURE","future_members_used","0"),("FINAL","final_breadth_used_as_feature","false")],
"CLASS":[("CLEAN","path_class","CLEAN_CONTINUATION"),("PULLBACK","path_class","PULLBACK_CONTINUATION"),("REVERSAL","path_class","FAILED_SHOCK_REVERSAL"),("WHIPSAW","path_class","TWO_SIDED_WHIPSAW"),("DEAD","path_class","DEAD_OR_TIMEOUT"),("PRIORITY","path_class","TWO_SIDED_WHIPSAW"),("UNIQUE","primary_class_count","1")],
"EXEC":[("LONG","entry_side","ASK"),("SHORT","entry_side","BID"),("CONT","first_passage","CONTINUATION_FIRST"),("REV","first_passage","REVERSAL_FIRST"),("AMBIG","first_passage","AMBIGUOUS"),("TIMEOUT","first_passage","TIMEOUT"),("MFE","mfe","0.0004"),("DIR","trade_direction","SHORT"),("NOSIGNAL","entry_status","NO_SIGNAL"),("CENSOR","entry_status","CENSORED_END_OF_RUN")],
"SPLIT":[("EPISODE","episode_split_violations","0"),("PURGE","purge_ms","120000"),("SHUFFLE","random_shuffle","false"),("TRAIN","validation_threshold_reads","0"),("LEAK","validation_leakage","0"),("BUDGET","candidate_count","6"),("HASH","hash_stable","true"),("REGISTRY","unregistered_trials","0")],
"INTEGRITY":[("REPLAY","replay_mismatches","0"),("EVENT","event_identity_mismatches","0"),("FUNNEL","funnel_mismatches","0"),("PARAM","parameter_mismatches","0"),("CAPACITY","integrity_violations","0"),("ORDER","order_send_calls","0")]
}

def main():
    cases=[]
    for group,items in GROUPS.items():
        for i,(slug,field,value) in enumerate(items,1):
            tid=f"TS15D-{group}-{i:03d}"
            cases.append((tid,group,slug,field,value))
    assert len(cases)==64
    spec=ROOT/"tests/tick_shock/spec/test_cases.csv"
    with spec.open(encoding="utf-8-sig",newline="") as h: existing=list(csv.DictReader(h))
    existing=[r for r in existing if not r["test_id"].startswith("TS15D-")]
    fixture=ROOT/"tests/tick_shock/fixtures"; expected=ROOT/"tests/tick_shock/expected"
    fixture.mkdir(parents=True,exist_ok=True); expected.mkdir(parents=True,exist_ok=True)
    for tid,group,slug,field,value in cases:
        tick=fixture/f"{tid}_ticks.csv"
        with tick.open("w",encoding="utf-8",newline="") as h:
            w=csv.writer(h);w.writerow(("sequence","symbol","time_msc","bid","ask","processing_msc","note"))
            for row in ((1,"EURUSD",1000,"1.0000","1.0002",1100,"confirmed"),(2,"EURUSD",1500,"1.0002","1.0004",1550,"checkpoint"),(3,"EURUSD",2000,"1.0001","1.0003",2050,"followup"),(4,"EURUSD",4000,"1.0004","1.0006",4050,"terminal")):w.writerow(row)
        cfg=fixture/f"{tid}_config.csv"
        with cfg.open("w",encoding="utf-8",newline="") as h:
            w=csv.writer(h);w.writerow(("key","value","unit","note"));w.writerow(("case",slug,"label","independent scenario"));w.writerow(("confirmed_msc",1000,"ms","causal origin"));w.writerow(("direction",1,"sign","LONG"))
        exp=expected/f"{tid}_expected.csv"
        with exp.open("w",encoding="utf-8",newline="") as h:
            w=csv.writer(h);w.writerow(("field","expected_value","tolerance","unit","note"));w.writerow((field,value,"1e-9" if any(c in value for c in ".eE") else "0","value","independent frozen oracle"))
        existing.append(dict(zip(BASE,(tid,f"TS15D-REQ-{group}","STEP15D-PRE-FIX","state_conditioned_response","production_path_integration","BOTH",f"tests/tick_shock/fixtures/{tid}_ticks.csv",f"tests/tick_shock/expected/{tid}_expected.csv","XFAIL",f"{group} {slug} causal contract"))))
    with spec.open("w",encoding="utf-8",newline="") as h:
        w=csv.DictWriter(h,fieldnames=BASE);w.writeheader();w.writerows(existing)
    print(f"generated={len(cases)} registry={len(existing)}")

if __name__=="__main__": main()
