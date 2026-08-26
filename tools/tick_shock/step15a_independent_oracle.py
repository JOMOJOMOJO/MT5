#!/usr/bin/env python3
"""Independent Step 15A fixture/oracle builder.

This file intentionally contains no import from production or test runner
modules. It implements the frozen mathematical specification from the Step
15A pre-analysis and writes literal fixture/expected evidence.
"""
from __future__ import annotations

import csv
import hashlib
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "tests" / "tick_shock" / "fixtures"
EXPECTED = ROOT / "tests" / "tick_shock" / "expected"
SPEC = ROOT / "docs" / "research" / "tick_shock" / "15a_shock_definition_spec.md"


TESTS = (
    ("TS15A-RET-001", "independent 250/500/1000ms log returns"),
    ("TS15A-MID-001", "Mid and log Mid"),
    ("TS15A-SAMEMSC-001", "last quote in one millisecond group"),
    ("TS15A-IRREG-001", "irregular exact anchors"),
    ("TS15A-STALE-001", "stale quote fail closed"),
    ("TS15A-SPREAD-001", "spread-only expansion separation"),
    ("TS15A-ANOMALY-001", "isolated quote anomaly attenuation"),
    ("TS15A-REVERSAL-001", "immediately reversing spike"),
    ("TS15A-PERSIST-001", "genuine persistent shock"),
    ("TS15A-VOL-HIGH-001", "high local volatility score"),
    ("TS15A-VOL-LOW-001", "low local volatility score"),
    ("TS15A-TOD-001", "time-of-day bucket boundary"),
    ("TS15A-EXCLUDE-001", "current window excluded from calibration"),
    ("TS15A-FUTURE-001", "future anchor forbidden"),
    ("TS15A-CALIB-001", "tail calibration sample minimum"),
    ("TS15A-QUANTILE-001", "inclusive empirical tail rank"),
    ("TS15A-SEVERITY-001", "99.0/99.5/99.9 severity boundaries"),
    ("TS15A-MULTI-001", "Holm multi-horizon family"),
    ("TS15A-CLUSTER-001", "multi-horizon dedup and cluster boundary"),
    ("TS15A-CLOCK-001", "candidate and confirmed time separation"),
    ("TS15A-BACKDATE-001", "persistence signal is not backdated"),
    ("TS15A-NOISE-001", "raw and pre-averaged estimator difference"),
    ("TS15A-STRICT-001", "STRICT_V0 exact legacy gates"),
    ("TS15A-PROV-001", "detector/schema/spec provenance"),
)


def mid(bid: float, ask: float) -> float:
    if not (bid > 0 and ask > bid):
        raise ValueError("invalid quote")
    return (bid + ask) / 2.0


def log_return(newer: float, older: float) -> float:
    return math.log(newer / older)


def preaverage(current: float, lag250: float, lag500: float) -> float:
    return (current + 2.0 * lag250 + lag500) / 4.0


def bipower_scale(returns: list[float], noise_return: float) -> tuple[float, float]:
    products = [abs(returns[i]) * abs(returns[i - 1]) for i in range(1, len(returns))]
    bv = math.pi / 2.0 * sum(products) / len(products)
    return bv, max(math.sqrt(bv), noise_return)


def wilson_half_width(p: float, n: int) -> float:
    z = 1.95996398454
    return z / (1 + z * z / n) * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))


def holm(raw: list[float]) -> list[float]:
    order = sorted(range(len(raw)), key=lambda i: (raw[i], i))
    out = [1.0] * len(raw)
    running = 0.0
    m = len(raw)
    for rank, index in enumerate(order):
        running = max(running, min(1.0, (m - rank) * raw[index]))
        out[index] = running
    return out


def write_csv(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def tick_rows(points: list[tuple[int, int, float, float, str]]) -> list[dict[str, object]]:
    return [
        {"sequence": seq, "symbol": "EURUSD", "time_msc": time_msc,
         "bid": f"{bid:.8f}", "ask": f"{ask:.8f}",
         "processing_msc": time_msc, "note": note}
        for seq, time_msc, bid, ask, note in points
    ]


def cfg_rows(items: list[tuple[str, object, str, str]]) -> list[dict[str, object]]:
    return [{"key": k, "value": v, "unit": u, "note": n} for k, v, u, n in items]


def exp_rows(items: list[tuple[str, object, float, str, str]]) -> list[dict[str, object]]:
    rows = []
    for field, value, tolerance, unit, note in items:
        if isinstance(value, bool):
            value = "true" if value else "false"
        elif isinstance(value, float):
            value = f"{value:.12f}"
        rows.append({"field": field, "expected_value": value, "tolerance": tolerance,
                     "unit": unit, "note": note})
    return rows


def build() -> None:
    base = tick_rows([(1, 1000, 0.9999, 1.0001, "base")])
    cases: dict[str, tuple[list[dict[str, object]], list[dict[str, object]], list[dict[str, object]]]] = {}

    points = [(1,1000,.9999,1.0001,"1000 anchor"),(2,1250,1.0000,1.0002,"750 lag"),
              (3,1500,1.0001,1.0003,"500 anchor"),(4,1750,1.0003,1.0005,"250 anchor"),
              (5,2000,1.0009,1.0011,"event")]
    mids = [mid(p[2], p[3]) for p in points]
    cases["TS15A-RET-001"] = (tick_rows(points), cfg_rows([]), exp_rows([
        ("return_250",log_return(mids[4],mids[3]),1e-12,"ratio","exact 250ms"),
        ("return_500",log_return(mids[4],mids[2]),1e-12,"ratio","exact 500ms"),
        ("return_1000",log_return(mids[4],mids[0]),1e-12,"ratio","exact 1000ms"),
        ("all_valid",True,0,"bool","all exact anchors")]))

    m = mid(1.1000,1.1002)
    cases["TS15A-MID-001"] = (tick_rows([(1,1000,1.1000,1.1002,"valid quote")]), cfg_rows([]), exp_rows([
        ("mid",m,1e-12,"price","Bid Ask midpoint"),("log_mid",math.log(m),1e-12,"ratio","natural log")]))

    cases["TS15A-SAMEMSC-001"] = (tick_rows([(1,1000,1.1000,1.1002,"first"),(2,1000,1.1001,1.1003,"second"),(3,1000,1.1002,1.1004,"last")]), cfg_rows([]), exp_rows([
        ("group_size",3,0,"count","all same-ms ticks"),("closing_mid",1.1003,1e-12,"price","last quote closes grid")]))

    cases["TS15A-IRREG-001"] = (tick_rows([(1,999,.9999,1.0001,"not exact 1000"),(2,1501,1.0001,1.0003,"not exact 1500"),(3,1750,1.0003,1.0005,"exact 250"),(4,2000,1.0009,1.0011,"event")]), cfg_rows([]), exp_rows([
        ("valid_250",True,0,"bool","exact 1750 anchor"),("valid_500",False,0,"bool","1501 is not 1500"),("valid_1000",False,0,"bool","999 is not 1000")]))

    cases["TS15A-STALE-001"] = (tick_rows([(1,1499,1.0000,1.0002,"source quote")]), cfg_rows([("grid_msc",2000,"ms","boundary"),("max_quote_age_ms",500,"ms","fixed")]), exp_rows([
        ("quote_age_ms",501,0,"ms","boundary minus source"),("data_integrity_ok",False,0,"bool","501 exceeds fixed 500"),("statistical_shock",False,0,"bool","fail closed")]))

    cases["TS15A-SPREAD-001"] = (tick_rows([(1,1000,.9999,1.0001,"normal spread"),(2,2000,.9998,1.0002,"spread only")]), cfg_rows([("spread_median",.0002,"price","reference")]), exp_rows([
        ("abs_log_return",0.0,1e-12,"ratio","Mid unchanged"),("statistical_shock",False,0,"bool","zero return"),("liquidity_normal",False,0,"bool","spread ratio two"),("cost_feasible",False,0,"bool","zero move")]))

    raw = log_return(1.01,1.0); robust_mid = preaverage(1.01,1.0,1.0); robust = log_return(robust_mid,1.0)
    anomaly_ticks=tick_rows([(1,1500,.9999,1.0001,"lag500"),(2,1750,.9999,1.0001,"lag250"),(3,2000,1.0099,1.0101,"isolated quote")])
    cases["TS15A-ANOMALY-001"]=(anomaly_ticks,cfg_rows([]),exp_rows([
        ("raw_abs_return",abs(raw),1e-12,"ratio","raw spike"),("robust_abs_return",abs(robust),1e-12,"ratio","pre-averaged spike"),("robust_smaller",True,0,"bool","attenuation")]))

    cases["TS15A-REVERSAL-001"]=(tick_rows([(1,1000,.9999,1.0001,"window start"),(2,1500,.9999,1.0001,"lag500"),(3,1750,.9999,1.0001,"lag250"),(4,2000,1.0099,1.0101,"candidate"),(5,2250,.9799,.9801,"reverse overshoot")]),cfg_rows([("direction",1,"side","up"),("retained_fraction",.5,"ratio","fixed")]),exp_rows([
        ("candidate_time_msc",2000,0,"ms","candidate"),("confirmed",False,0,"bool","reversal fails persistence"),("signal_time_msc",0,0,"ms","no signal")]))

    cases["TS15A-PERSIST-001"]=(tick_rows([(1,1000,.9999,1.0001,"window start"),(2,1500,.9999,1.0001,"lag500"),(3,1750,.9999,1.0001,"lag250"),(4,2000,1.0099,1.0101,"candidate"),(5,2250,1.0109,1.0111,"persists")]),cfg_rows([("direction",1,"side","up"),("retained_fraction",.5,"ratio","fixed")]),exp_rows([
        ("candidate_time_msc",2000,0,"ms","candidate"),("confirmed",True,0,"bool","retained move"),("confirmed_time_msc",2250,0,"ms","next grid"),("signal_time_msc",2250,0,"ms","no backdate")]))

    high_returns=[.01,-.01,.012,-.011,.009,-.01]
    bv,sigma=bipower_scale(high_returns,1e-5)
    cases["TS15A-VOL-HIGH-001"]=(base,cfg_rows([("returns","|".join(map(str,high_returns)),"ratio","local pool"),("current_abs_return",.005,"ratio","candidate"),("noise_return",1e-5,"ratio","floor")]),exp_rows([
        ("bipower_variance",bv,1e-12,"ratio","bipower"),("local_sigma",sigma,1e-12,"ratio","high scale"),("score",.005/sigma,1e-12,"ratio","standardized")]))

    low_returns=[.0001,-.0001,.00012,-.00011,.00009,-.0001]
    bv,sigma=bipower_scale(low_returns,1e-5)
    cases["TS15A-VOL-LOW-001"]=(base,cfg_rows([("returns","|".join(map(str,low_returns)),"ratio","local pool"),("current_abs_return",.005,"ratio","candidate"),("noise_return",1e-5,"ratio","floor")]),exp_rows([
        ("bipower_variance",bv,1e-12,"ratio","bipower"),("local_sigma",sigma,1e-12,"ratio","low scale"),("score",.005/sigma,1e-9,"ratio","standardized")]))

    cases["TS15A-TOD-001"]=(base,cfg_rows([("times_msc","0|14399999|14400000|86399999","ms","server day")]),exp_rows([
        ("bucket_0",0,0,"index","midnight"),("bucket_14399999",0,0,"index","before boundary"),("bucket_14400000",1,0,"index","inclusive boundary"),("bucket_86399999",5,0,"index","last bucket")]))

    cases["TS15A-EXCLUDE-001"]=(base,cfg_rows([("sample_msc",1000,"ms","candidate sample"),("exclude_ms",2000,"ms","fixed")]),exp_rows([
        ("eligible_at_2999",False,0,"bool","too early"),("eligible_at_3000",True,0,"bool","inclusive after exclusion")]))

    cases["TS15A-FUTURE-001"]=(tick_rows([(1,2000,1.0009,1.0011,"event"),(2,2001,.9999,1.0001,"future anchor")]),cfg_rows([("window_ms",1000,"ms","horizon")]),exp_rows([
        ("return_valid",False,0,"bool","future is forbidden"),("future_reads",0,0,"count","fail closed")]))

    cases["TS15A-CALIB-001"]=(base,cfg_rows([("minimum",10000,"count","fixed")]),exp_rows([
        ("ready_9999",False,0,"bool","below"),("ready_10000",True,0,"bool","inclusive"),("ready_10001",True,0,"bool","above")]))

    p=(1+3)/(100+1)
    cases["TS15A-QUANTILE-001"]=(base,cfg_rows([("histogram","0|0|2|3|0","count","bins"),("current_bin",3,"index","equal bin included"),("calibration_count",100,"count","includes unshown lower bins")]),exp_rows([
        ("exceedances",3,0,"count","equal bin included"),("raw_p",p,1e-12,"ratio","plus-one rank"),("empirical_percentile",100*(1-p),1e-9,"percent","one minus p")]))

    cases["TS15A-SEVERITY-001"]=(base,cfg_rows([]),exp_rows([
        ("severity_0_010001","NONE",0,"label","outside 99"),("severity_0_010000","P990",0,"label","inclusive 99"),("severity_0_005000","P995",0,"label","inclusive 99.5"),("severity_0_001000_n49999","P995",0,"label","99.9 sample insufficient"),("severity_0_001000_n50000","P999",0,"label","inclusive valid 99.9")]))

    adjusted=holm([.001,.004,.02])
    cases["TS15A-MULTI-001"]=(base,cfg_rows([("raw_p","0.001|0.004|0.020","ratio","250 500 1000")]),exp_rows([
        ("adjusted_250",adjusted[0],1e-12,"ratio","Holm"),("adjusted_500",adjusted[1],1e-12,"ratio","Holm"),("adjusted_1000",adjusted[2],1e-12,"ratio","Holm"),("trigger_horizon_ms",250,0,"ms","minimum adjusted p"),("horizon_mask",3,0,"mask","250 and 500")]))

    cases["TS15A-CLUSTER-001"]=(base,cfg_rows([("candidate_times","1000|1000|2999|3001","ms","multi horizon and boundary"),("candidate_horizons","250|500|250|250","ms","same first boundary"),("cluster_window_ms",2000,"ms","fixed")]),exp_rows([
        ("deduplicated_events",3,0,"count","two horizons at 1000 become one"),("symbol_clusters",2,0,"count","3001 starts new cluster")]))

    cases["TS15A-CLOCK-001"]=(base,cfg_rows([("candidate_msc",2000,"ms","candidate"),("confirmed_msc",2250,"ms","confirmation")]),exp_rows([
        ("candidate_msc",2000,0,"ms","preserved"),("confirmed_msc",2250,0,"ms","preserved"),("signal_msc",2250,0,"ms","confirmation")]))

    cases["TS15A-BACKDATE-001"]=(base,cfg_rows([("candidate_msc",2000,"ms","candidate"),("confirmed_msc",2250,"ms","confirmation")]),exp_rows([
        ("signal_before_confirm",False,0,"bool","forbidden"),("backdate_violations",0,0,"count","none")]))

    cases["TS15A-NOISE-001"]=(anomaly_ticks,cfg_rows([]),exp_rows([
        ("raw_mid",1.01,1e-12,"price","current"),("robust_mid",robust_mid,1e-12,"price","causal pre-average"),("estimators_distinct",True,0,"bool","not copied")]))

    cases["TS15A-STRICT-001"]=(base,cfg_rows([("move",10,"price","equal percentile"),("percentile",10,"price","gate"),("robust_z",3.5,"ratio","gate"),("efficiency",.65,"ratio","gate"),("intensity",1.5,"ratio","gate"),("move_spread",4,"ratio","gate"),("spread_ratio",1.5,"ratio","gate")]),exp_rows([
        ("accepted",True,0,"bool","all inclusive"),("gate_mask",63,0,"mask","six gates"),("default_detector","STRICT_V0",0,"label","backward compatible")]))

    spec_hash=hashlib.sha256(SPEC.read_bytes()).hexdigest().upper()
    cases["TS15A-PROV-001"]=(base,cfg_rows([("expected_spec_sha256",spec_hash,"sha256","frozen spec")]),exp_rows([
        ("detector_count",4,0,"count","V0 plus three V1"),("default_detector","STRICT_V0",0,"label","default"),("feature_schema","tickshock-detector-feature-v1",0,"label","versioned"),("spec_sha256",spec_hash,0,"sha256","exact frozen spec")]))

    if set(cases) != {test_id for test_id, _ in TESTS}:
        raise RuntimeError("case registry mismatch")
    for test_id, _ in TESTS:
        ticks, config, expected = cases[test_id]
        write_csv(FIXTURES / f"{test_id}_ticks.csv",
                  ["sequence","symbol","time_msc","bid","ask","processing_msc","note"], ticks)
        write_csv(FIXTURES / f"{test_id}_config.csv", ["key","value","unit","note"], config)
        write_csv(EXPECTED / f"{test_id}_expected.csv",
                  ["field","expected_value","tolerance","unit","note"], expected)


if __name__ == "__main__":
    build()
    print(f"generated {len(TESTS)} fixture/expected triples")
