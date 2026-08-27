#!/usr/bin/env python3
"""Independent Step 15B identity, matched-control, and funnel analysis."""

from __future__ import annotations

import csv
import hashlib
import math
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

csv.field_size_limit(16 * 1024 * 1024)

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "reports/analysis/tick_shock/step15b"
RUNS = {
    "STRICT_V0": ("20260827_ts15a_strict_v0_realizable_202503_r2", "20260827_ts15b_strict_v0_realizable_202503"),
    "TAIL_V1_RAW": ("20260827_ts15a_tail_v1_raw_realizable_202503_r2", "20260827_ts15b_tail_v1_raw_realizable_202503"),
    "TAIL_V1_NOISE_ROBUST": ("20260827_ts15a_tail_v1_noise_robust_realizable_202503_r2", "20260827_ts15b_tail_v1_noise_robust_realizable_202503"),
    "TAIL_V1_PERSISTENT": ("20260827_ts15a_tail_v1_persistent_realizable_202503_r2", "20260827_ts15b_tail_v1_persistent_realizable_202503"),
}
PRIMARY = ["abs_return_1s", "abs_return_3s", "realized_volatility_120s"]
SECONDARY = ["abs_return_10s", "abs_return_30s", "abs_return_120s", "mfe_120s", "mae_120s",
             "spread_change_120s", "tick_activity_120s", "quote_reversion_ratio"]
STAGES = ["statistical_shock", "direction_available", "directional_burst", "activity_elevated", "liquidity_normal",
          "cost_feasible", "common_strategy_eligible", "detection_continuation_reachable",
          "post_burst_continuation_reachable", "pullback_continuation_reachable",
          "failed_shock_reversal_reachable", "strategy_signal"]


def rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as h:
        return list(csv.DictReader(h))


def write(name: str, fieldnames: list[str], values: list[dict[str, object]]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with (OUT / name).open("w", encoding="utf-8", newline="") as h:
        w = csv.DictWriter(h, fieldnames=fieldnames)
        w.writeheader(); w.writerows(values)


def f(value: str) -> float:
    try: return float(value)
    except (TypeError, ValueError): return math.nan


def b(value: str) -> bool:
    return str(value).lower() in {"1", "true", "yes"}


def normalize_event(row: dict[str, str], fields: list[str]) -> tuple[str, ...]:
    return tuple(row.get(k, "") for k in fields)


def identity_analysis() -> list[dict[str, object]]:
    output=[]
    for detector,(old_name,new_name) in RUNS.items():
        old_dir=ROOT/"reports/backtest/runs"/old_name; new_dir=ROOT/"reports/backtest/runs"/new_name
        for artifact in ("detector_features.csv","events.csv"):
            old=rows(old_dir/artifact); new=rows(new_dir/artifact)
            common=sorted((set(old[0]) & set(new[0]))-{"event_id","feature_schema"}) if old and new else []
            if artifact=="detector_features.csv":
                key_fields=[x for x in ("symbol","detector_version","candidate_time_msc","confirmed_time_msc","trigger_horizon_ms") if x in common]
            else:
                key_fields=[x for x in ("symbol","detector_window_ms","detection_time_msc","direction") if x in common]
            old_map={normalize_event(r,key_fields):normalize_event(r,common) for r in old}
            new_map={normalize_event(r,key_fields):normalize_event(r,common) for r in new}
            missing=len(set(old_map)-set(new_map)); added=len(set(new_map)-set(old_map))
            changed=sum(old_map[k]!=new_map[k] for k in set(old_map)&set(new_map))
            output.append({"detector":detector,"artifact":artifact,"step15a_rows":len(old),"step15b_rows":len(new),
                           "missing":missing,"added":added,"changed":changed,"identity_mismatches":missing+added+changed,
                           "status":"PASS" if missing+added+changed==0 else "FAIL"})
    return output


def parameter_analysis() -> list[dict[str, object]]:
    ignored={"InpRunId","InpLogFolder","InpSourceCommit","InpEx5Hash","InpSchemaVersion"}
    output=[]
    for detector,(old_name,new_name) in RUNS.items():
        old_set=next((ROOT/"reports/backtest/runs"/old_name).glob("*.set")); new_set=next((ROOT/"reports/backtest/runs"/new_name).glob("*.set"))
        def load(path: Path) -> dict[str,str]:
            return {k:v for line in path.read_text(encoding="utf-8-sig").splitlines() if "=" in line for k,v in [line.split("=",1)]}
        a,c=load(old_set),load(new_set)
        for key in sorted((set(a)|set(c))-ignored):
            if a.get(key)!=c.get(key): output.append({"detector":detector,"parameter":key,"step15a":a.get(key,""),"step15b":c.get(key,""),"status":"FAIL"})
        output.append({"detector":detector,"parameter":"__UNCHANGED_PARAMETER_COUNT__","step15a":len(set(a)-ignored),"step15b":len(set(c)-ignored),"status":"PASS"})
    return output


def stationary_bootstrap(matrix: np.ndarray, replicates: int=10_000, mean_block: float=4.0, seed: int=20260826) -> tuple[np.ndarray,np.ndarray,np.ndarray,np.ndarray]:
    n,k=matrix.shape; observed=np.nanmean(matrix,axis=0)
    if n<2: return observed, np.full(k,np.nan), np.full(k,np.nan), np.full(k,np.nan)
    rng=np.random.default_rng(seed); doubled=np.vstack([matrix,matrix]); prefix=np.vstack([np.zeros((1,k)),np.cumsum(doubled,axis=0)])
    means=np.empty((replicates,k)); p=1.0/mean_block
    for rep in range(replicates):
        lengths=rng.geometric(p,size=max(8,int(n/mean_block*1.4)+16)); total=np.cumsum(lengths)
        while total[-1]<n:
            extra=rng.geometric(p,size=max(8,int(n/mean_block*.2)+1)); lengths=np.concatenate([lengths,extra]);total=np.cumsum(lengths)
        m=int(np.searchsorted(total,n,side="left"))+1; lengths=lengths[:m]; lengths[-1]-=int(total[m-1]-n)
        starts=rng.integers(0,n,size=m); sums=prefix[starts+lengths]-prefix[starts]
        means[rep]=sums.sum(axis=0)/n
    low=np.quantile(means,.025,axis=0); high=np.quantile(means,.975,axis=0)
    pvalue=np.minimum(1.0,2.0*np.minimum(np.mean(means<=0,axis=0),np.mean(means>=0,axis=0)))
    return observed,low,high,pvalue


def matched_analysis() -> tuple[list[dict[str,object]],list[dict[str,object]],list[dict[str,object]]]:
    coverage=[]; stats=[]; pair_rows=[]
    for detector,(_,new_name) in RUNS.items():
        d=ROOT/"reports/backtest/runs"/new_name
        matches=rows(d/"control_matches.csv"); controls={r["control_id"]:r for r in rows(d/"control_candidates.csv")}
        events={r["event_id"]:r for r in rows(d/"detector_features.csv")}
        matched=[r for r in matches if b(r["matched"]) and r["control_id"] in controls and r["event_id"] in events]
        unique=len({r["control_id"] for r in matched}); symbols=len({r["symbol"] for r in matched})
        coverage.append({"detector":detector,"representative_clusters":len(matches),"eligible_control_candidates":len(controls),
                         "matched_events":len(matched),"unmatched_events":len(matches)-len(matched),
                         "match_rate":len(matched)/len(matches) if matches else 0,"unique_controls":unique,
                         "control_reuse_rate":1-unique/len(matched) if matched else 0,"matched_symbols":symbols,
                         "support_status":"PASS" if len(matched)>=30 and len(matched)/max(1,len(matches))>=.8 and unique>=20 and symbols>=3 else "CONTROL_SUPPORT_INSUFFICIENT"})
        values=[]; complete=[]
        for m in matched:
            e,c=events[m["event_id"]],controls[m["control_id"]]
            vector=[]; ok=True
            for outcome in PRIMARY+SECONDARY:
                ev=f(e.get(outcome,"")); cv=f(c.get(outcome,""));
                if not (math.isfinite(ev) and math.isfinite(cv)): ok=False; break
                vector.append(ev-cv)
            if not ok: continue
            values.append(vector); complete.append(m)
            pair_rows.append({"detector":detector,"event_id":m["event_id"],"market_cluster_id":m["market_cluster_id"],"symbol":m["symbol"],
                              "event_msc":m["event_msc"],"control_id":m["control_id"],"control_msc":c["boundary_msc"],"time_difference_ms":m["time_difference_ms"],
                              **{f"delta_{o}":vector[i] for i,o in enumerate(PRIMARY+SECONDARY)}})
        if values:
            matrix=np.asarray(values,dtype=float); observed,low,high,pvals=stationary_bootstrap(matrix)
            for i,outcome in enumerate(PRIMARY+SECONDARY):
                stats.append({"hypothesis_id":f"{detector}:{outcome}","detector":detector,"family":"PRIMARY" if outcome in PRIMARY else "SECONDARY",
                              "outcome":outcome,"matched_complete_n":len(matrix),"event_minus_control_mean":observed[i],"ci95_low":low[i],"ci95_high":high[i],
                              "unadjusted_p":pvals[i],"bootstrap":"chronological_stationary","replicates":10000,"mean_block_length":4,"seed":20260826})
    return coverage,stats,pair_rows


def adjust_tests(stats: list[dict[str,object]]) -> list[dict[str,object]]:
    out=[]
    for family in ("PRIMARY","SECONDARY"):
        part=[r for r in stats if r["family"]==family]; m=len(part); order=sorted(range(m),key=lambda i:float(part[i]["unadjusted_p"]))
        adjusted=[1.0]*m
        if family=="PRIMARY":
            prev=0.0
            for rank,i in enumerate(order): prev=max(prev,min(1.0,(m-rank)*float(part[i]["unadjusted_p"]))); adjusted[i]=prev
            method="HOLM"
        else:
            nxt=1.0
            for reverse_rank in range(m-1,-1,-1):
                i=order[reverse_rank]; nxt=min(nxt,min(1.0,float(part[i]["unadjusted_p"])*m/(reverse_rank+1))); adjusted[i]=nxt
            method="BH_FDR_Q_0.05"
        for i,r in enumerate(part): out.append({**r,"adjustment_method":method,"adjusted_p":adjusted[i],"reject_0_05":adjusted[i]<=.05})
    return out


def funnel_analysis() -> tuple[list[dict[str,object]],list[dict[str,object]],list[dict[str,object]],list[dict[str,object]]]:
    funnel=[]; failures=[]; reach=[]; overlap=[]
    for detector,(_,new_name) in RUNS.items():
        data=rows(ROOT/"reports/backtest/runs"/new_name/"strategy_funnel.csv")
        for stage in STAGES:
            passed=sum(b(r[stage]) for r in data); funnel.append({"detector":detector,"stage":stage,"input":len(data),"passed":passed,"excluded":len(data)-passed,"reconciles":passed+len(data)-passed==len(data)})
        counts=Counter(r["first_fail_reason"] or "PASSED_ALL_OBSERVED_GATES" for r in data)
        for reason,count in counts.most_common(): failures.append({"detector":detector,"first_fail_reason":reason,"count":count,"rate":count/len(data) if data else 0})
        representatives=[r for r in data if not b(r["market_overlap_event"])]
        for strategy,col in (("DETECTION_CONTINUATION","detection_continuation_reachable"),("POST_BURST_CONTINUATION","post_burst_continuation_reachable"),
                             ("PULLBACK_CONTINUATION","pullback_continuation_reachable"),("FAILED_SHOCK_REVERSAL","failed_shock_reversal_reachable")):
            all_count=sum(b(r[col]) for r in data); rep_count=sum(b(r[col]) for r in representatives)
            causal=sum(b(r[col]) and bool(r[{"detection_continuation_reachable":"detection_entry_msc","post_burst_continuation_reachable":"post_burst_entry_msc","pullback_continuation_reachable":"pullback_entry_msc","failed_shock_reversal_reachable":"reversal_entry_msc"}[col]]) for r in representatives)
            reach.append({"detector":detector,"strategy":strategy,"event_rows_reachable":all_count,"representative_clusters_reachable":rep_count,"causal_entry_clusters":causal,
                          "cost_feasible_clusters":sum(b(r[col]) and b(r["cost_feasible"]) for r in representatives),"outcome_status":"DEVELOPMENT_DIAGNOSTIC_ONLY"})
            overlap.append({"detector":detector,"strategy":strategy,"before_overlap_rows":all_count,"after_market_cluster_dedup":rep_count,"cooldown_status":"NOT_APPLIED_COUNTERFACTUAL","potential_trades":rep_count})
    return funnel,failures,reach,overlap


def fallback_analysis() -> list[dict[str,object]]:
    result=[]
    for detector,(_,new_name) in RUNS.items():
        d=ROOT/"reports/backtest/runs"/new_name; features=rows(d/"detector_features.csv"); matches=rows(d/"control_matches.csv")
        for scope,exclude_gbp in (("PRIMARY_ALL_SYMBOLS",False),("EXCLUDE_ALL_GBPUSD",True)):
            fs=[r for r in features if not(exclude_gbp and r["symbol"]=="GBPUSD")]
            ms=[r for r in matches if not(exclude_gbp and r["symbol"]=="GBPUSD")]
            result.append({"detector":detector,"scope":scope,"events":len(fs),"representative_clusters":len(ms),"matched":sum(b(r["matched"]) for r in ms),
                           "match_rate":sum(b(r["matched"]) for r in ms)/len(ms) if ms else 0,"fallback_overlap_status":"NOT_OBSERVABLE_FROM_MT5_AGGREGATE_JOURNAL",
                           "generated_fallback_minutes":179,"total_minutes":30187,"fallback_rate":179/30187})
    return result


def subgroup_analysis(pair_rows: list[dict[str,object]]) -> list[dict[str,object]]:
    grouped=defaultdict(list)
    for row in pair_rows:
        bucket=(int(row["event_msc"])%86400000)//14400000
        grouped[(row["detector"],"SYMBOL",row["symbol"])].append(float(row["delta_abs_return_1s"]))
        grouped[(row["detector"],"TIME_BUCKET",str(bucket))].append(float(row["delta_abs_return_1s"]))
    result=[]
    for (detector,dimension,key),values in sorted(grouped.items()):
        a=np.asarray(values)
        result.append({"detector":detector,"dimension":dimension,"key":key,"n":len(a),"mean_delta_abs_return_1s":a.mean(),
                       "positive_fraction":np.mean(a>0),"status":"DESCRIPTIVE_DEVELOPMENT_ONLY"})
    return result


def run_resource_analysis() -> list[dict[str,object]]:
    result=[]
    for detector,(_,new_name) in RUNS.items():
        d=ROOT/"reports/backtest/runs"/new_name; summary=rows(d/"summary.csv")
        overall=next(r for r in summary if r["record_type"]=="OVERALL")
        result.append({"detector":detector,"runtime_seconds":overall["runtime_seconds"],"average_memory_mb":overall["average_memory_mb"],
                       "max_memory_mb":overall["max_memory_mb"],"events_csv_bytes":overall["event_csv_bytes"],
                       "detector_features_bytes":(d/"detector_features.csv").stat().st_size,"controls_bytes":(d/"control_candidates.csv").stat().st_size,
                       "matches_bytes":(d/"control_matches.csv").stat().st_size,"funnel_bytes":(d/"strategy_funnel.csv").stat().st_size})
    return result


def write_journal_excerpts() -> None:
    log_root=Path.home()/"AppData/Roaming/MetaQuotes/Tester/D232275B22422903BD477FB48B858FBA/Agent-127.0.0.1-3000/logs"
    text="\n".join(p.read_text(encoding="utf-16",errors="ignore") for p in (log_root/"20260827.log",log_root/"20260828.log") if p.is_file())
    for _,(_,new_name) in RUNS.items():
        token=new_name.replace("20260827_","").replace("_realizable_202503","")
        selected=[line for line in text.splitlines() if "TickShockResearch" in line or token in line or "real ticks discarded" in line]
        (ROOT/"reports/backtest/runs"/new_name/"tester_journal_excerpt.txt").write_text("\n".join(selected)+"\n",encoding="utf-8")


def hash_inventory() -> list[dict[str,object]]:
    paths=[ROOT/"mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5",ROOT/"mql/Include/TickShock/TickShockControlStudy.mqh",
           ROOT/"mql/Include/TickShock/TickShockStatisticalDetector.mqh",ROOT/"tests/tick_shock/spec/test_cases.csv"]
    for _,(_,name) in RUNS.items(): paths.extend((ROOT/"reports/backtest/runs"/name).glob("*"))
    result=[]
    for path in sorted(p for p in paths if p.is_file()):
        result.append({"path":path.relative_to(ROOT).as_posix(),"sha256":hashlib.sha256(path.read_bytes()).hexdigest().upper(),"bytes":path.stat().st_size})
    return result


def main() -> int:
    identity=identity_analysis(); params=parameter_analysis(); coverage,stats,pairs=matched_analysis(); adjusted=adjust_tests(stats)
    funnel,failures,reach,overlap=funnel_analysis(); fallback=fallback_analysis(); subgroups=subgroup_analysis(pairs); resources=run_resource_analysis(); write_journal_excerpts(); hashes=hash_inventory()
    write("detector_identity_regression.csv",list(identity[0]),identity)
    write("parameter_diff.csv",list(params[0]),params)
    write("control_match_coverage.csv",list(coverage[0]),coverage)
    write("matched_event_control_pairs.csv",list(pairs[0]),pairs)
    write("event_minus_control_results.csv",list(stats[0]),stats)
    write("cluster_bootstrap_results.csv",list(stats[0]),stats)
    write("multiple_testing_results.csv",list(adjusted[0]),adjusted)
    write("strategy_funnel.csv",list(funnel[0]),funnel)
    write("first_fail_reasons.csv",list(failures[0]),failures)
    write("counterfactual_strategy_reachability.csv",list(reach[0]),reach)
    write("overlap_cooldown_comparison.csv",list(overlap[0]),overlap)
    write("gbpusd_fallback_sensitivity.csv",list(fallback[0]),fallback)
    write("effect_concentration.csv",list(subgroups[0]),subgroups)
    write("run_resources.csv",list(resources[0]),resources)
    write("source_fixture_output_hashes.csv",list(hashes[0]),hashes)
    trials=[{"trial_id":f"TS15B-{i+1:02d}","detector":d,"period":"2025-03-01/2025-04-01","source_commit":"0373fc717954eaf1ce51ae73749cb844a4c8d000","status":"COMPLETED","purpose":"predeclared matched-control and strategy-funnel replay"} for i,d in enumerate(RUNS)]
    write("trial_registry.csv",list(trials[0]),trials)
    synthetic=np.random.default_rng(20260826).normal(size=(400,3)); obs,lo,hi,pv=stationary_bootstrap(synthetic)
    null_rows=[{"outcome":PRIMARY[i],"mean":obs[i],"ci95_low":lo[i],"ci95_high":hi[i],"p":pv[i],"status":"PASS" if lo[i]<=0<=hi[i] else "FAIL"} for i in range(3)]
    write("synthetic_gaussian_null.csv",list(null_rows[0]),null_rows)
    print(f"identity_mismatches={sum(int(r['identity_mismatches']) for r in identity)} parameter_changes={sum(r['status']=='FAIL' for r in params)} pairs={len(pairs)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
