#!/usr/bin/env python3
"""Generate preregistered Step 15E fixtures and independent expected values."""
from __future__ import annotations
import csv
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
BASE=("test_id","requirement_id","defect_id","component","test_layer","direction","fixture_path","expected_path","current_expected_status","description")
CASES=[
 ("TS15E-EPISODE-001","anchor_event_id","EVT-1","text"),("TS15E-EPISODE-002","episode_count","1","count"),
 ("TS15E-EPISODE-003","repeat_count","2","count"),("TS15E-EPISODE-004","cooldown_release_msc","961000","ms"),
 ("TS15E-EPISODE-005","checkpoint_900_status","AVAILABLE","text"),("TS15E-EPISODE-006","end_status","PURGED_END_OF_DATA","text"),
 ("TS15E-CLOCK-001","checkpoint_count","9","count"),("TS15E-CLOCK-002","quote_msc","31050","ms"),
 ("TS15E-CLOCK-003","same_millisecond_ask","1.0005","price"),("TS15E-CLOCK-004","availability","STALE","text"),
 ("TS15E-CLOCK-005","availability","MISSING_WEEKEND","text"),("TS15E-CLOCK-006","availability","MISSING_BID_ASK","text"),
 ("TS15E-VOL-001","primary_inference","EXCLUDED_FALLBACK","text"),("TS15E-VOL-002","completed_m1_count","10","count"),
 ("TS15E-VOL-003","future_m1_reads","0","count"),
 ("TS15E-EXEC-001","long_spread_only_return","0.0002","price"),("TS15E-EXEC-002","short_spread_only_return","0.0002","price"),
 ("TS15E-EXEC-003","mfe","0.0004","price"),("TS15E-EXEC-004","recross_count","1","count"),
 ("TS15E-EXEC-005","entry_quote_msc","1210","ms"),
 ("TS15E-INTEGRITY-001","label_future_reads","0","count"),("TS15E-INTEGRITY-002","cross_symbol_future_reads","0","count"),
 ("TS15E-INTEGRITY-003","first_touch","AMBIGUOUS","text"),("TS15E-INTEGRITY-004","cursor_stalls","0","count"),
 ("TS15E-INTEGRITY-005","capacity_losses","0","count"),("TS15E-INTEGRITY-006","provenance_status","VALID","text"),
 ("TS15E-INTEGRITY-007","step15d_identity_mismatches","0","count"),("TS15E-INTEGRITY-008","order_send_calls","0","count"),
]

def main():
    assert len(CASES)==28
    registry=ROOT/"tests/tick_shock/spec/test_cases.csv"
    with registry.open(encoding="utf-8-sig",newline="") as h: rows=list(csv.DictReader(h))
    rows=[r for r in rows if not r["test_id"].startswith("TS15E-")]
    fixtures=ROOT/"tests/tick_shock/fixtures"; expected=ROOT/"tests/tick_shock/expected"
    for tid,field,value,unit in CASES:
        tick=fixtures/f"{tid}_ticks.csv"
        with tick.open("w",encoding="utf-8",newline="") as h:
            w=csv.writer(h);w.writerow(("sequence","symbol","time_msc","bid","ask","processing_msc","note"))
            for r in ((1,"EURUSD",1000,"1.0000","1.0002",1100,"confirmed"),(2,"EURUSD",1200,"1.0002","1.0004",1210,"first later quote"),(3,"EURUSD",1200,"1.0003","1.0005",1211,"same millisecond final"),(4,"EURUSD",1210,"1.0003","1.0005",1220,"explicit delayed eligible quote"),(5,"EURUSD",31050,"1.0004","1.0006",31100,"irregular checkpoint"),(6,"EURUSD",901000,"1.0001","1.0003",901100,"900 second completion")):w.writerow(r)
        cfg=fixtures/f"{tid}_config.csv"
        with cfg.open("w",encoding="utf-8",newline="") as h:
            w=csv.writer(h);w.writerow(("key","value","unit","note"));w.writerows((("case",tid,"id","independent scenario"),("horizon_ms",900000,"ms","frozen"),("quiet_ms",60000,"ms","frozen"),("m1_window",10,"completed returns","no current M1"),("fallback","false","bool","primary excludes fallback"),("production_function_used_for_expected","false","bool","independent oracle"),("oracle_source","docs/research/tick_shock/15e_shock_episode_spec.md","path","frozen before implementation")))
        exp=expected/f"{tid}_expected.csv"
        with exp.open("w",encoding="utf-8",newline="") as h:
            w=csv.writer(h);w.writerow(("field","expected_value","tolerance","unit","note"));w.writerow((field,value,"1e-9" if unit=="price" else "0",unit,"frozen independent oracle"))
        rows.append(dict(zip(BASE,(tid,"TS15E-REQ-"+tid.split('-')[1],"STEP15E-PRE-FIX","medium_horizon_response","production_path_integration","BOTH",f"tests/tick_shock/fixtures/{tid}_ticks.csv",f"tests/tick_shock/expected/{tid}_expected.csv","XFAIL",tid.replace('-',' ')+' causal contract'))))
    rows.sort(key=lambda r:r["test_id"])
    with registry.open("w",encoding="utf-8-sig",newline="") as h:
        w=csv.DictWriter(h,fieldnames=BASE);w.writeheader();w.writerows(rows)

if __name__=="__main__":main()
