#!/usr/bin/env python3
"""Independent CSV/JSON-only arithmetic and model/portfolio replay.

This does not import the analyzer, sklearn or LightGBM. It evaluates the frozen
exported model from raw formal features and independently rebuilds deployment.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import struct
from pathlib import Path


def read_csv(path):
    path = Path(path)
    encoding = "utf-16" if path.read_bytes()[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8-sig"
    with path.open(encoding=encoding, newline="") as stream:
        sample = stream.read(8192)
        stream.seek(0)
        dialect = csv.Sniffer().sniff(sample, delimiters=",;\t")
        return list(csv.DictReader(stream, dialect=dialect))


def number(value):
    try:
        result = float(value)
        return result if math.isfinite(result) else math.nan
    except (ValueError, TypeError):
        return math.nan


def score(model, values):
    vector = [v if math.isfinite(v) else median for v, median in zip(values, model["median"])]
    if model["method"] == "SHALLOW_TREE":
        node = 0
        while model["left"][node] >= 0:
            feature = model["feature"][node]
            value = struct.unpack("f", struct.pack("f", vector[feature]))[0]
            node = model["left"][node] if value <= model["threshold"][node] else model["right"][node]
        return model["value"][node]
    if model["method"] == "LIGHTGBM":
        result = 0.0
        for tree in model["trees"]:
            while "leaf_value" not in tree:
                if tree["decision_type"] != "<=":
                    raise ValueError("Categorical tree is outside frozen export spec")
                tree = tree["left_child"] if vector[tree["split_feature"]] <= tree["threshold"] else tree["right_child"]
            result += tree["leaf_value"]
        return result
    if "constant" in model:
        return model["constant"]
    logit = model["intercept"]+sum((v-m)/s*c for v, m, s, c in zip(vector, model["mean"], model["scale"], model["coefficient"]))
    probability = 1/(1+math.exp(-logit)) if logit >= 0 else math.exp(logit)/(1+math.exp(logit))
    return probability*model["win_mean"]+(1-probability)*model["loss_mean"]


def aggregate(rows, extra_cost):
    pips, rs = [], []
    wins = losses = tp = sl = timeout = 0
    equity = peak = dd = 0.0
    for row in rows:
        direction = int(row["direction"])
        risk = number(row["distance"])
        pip = number(row["pip_size"])
        gross_price = direction*(number(row["exit_price"])-number(row["entry_price"]))
        net = gross_price/risk-extra_cost*pip/risk
        rs.append(net)
        pips.append(gross_price/pip-extra_cost)
        wins += net > 0
        losses += net < 0
        tp += row["status"] == "TP"
        sl += row["status"] == "SL"
        timeout += row["status"] in ("TIME", "TIMEOUT")
        equity += net
        peak = max(peak, equity)
        dd = max(dd, peak-equity)
    positive = sum(x for x in rs if x > 0)
    negative = -sum(x for x in rs if x < 0)
    return dict(trades=len(rs), wins=wins, losses=losses, tp=tp, sl=sl, timeout=timeout,
                total_r=sum(rs), expectancy_r=sum(rs)/len(rs) if rs else math.nan,
                total_pips=sum(pips), expectancy_pips=sum(pips)/len(pips) if pips else math.nan,
                pf=positive/negative if negative else math.inf, maxdd_r=dd)


def run(args):
    features = read_csv(args.features)
    outcomes = read_csv(args.outcomes)
    output = Path(args.output)
    analysis = json.loads((output/"analysis_summary.json").read_text(encoding="utf-8"))
    checks = []
    def check(name, actual, expected=0, tolerance=0.0):
        # The analyzer's strict JSON encodes non-finite metrics as null.
        # Compare that representation explicitly, never coerce missing to zero.
        if expected is None:
            ok = isinstance(actual, (int, float)) and not math.isfinite(actual)
        else:
            ok = actual == expected if tolerance == 0 else abs(actual-expected) <= tolerance
        checks.append(dict(check=name, expected=expected, actual=actual, tolerance=tolerance,
                           status="PASS" if ok else "FAIL"))
    check("duplicate_feature_episode", len(features)-len({x["episode_id"] for x in features}))
    check("duplicate_outcome_key", len(outcomes)-len({(x["episode_id"], x["direction"], x["distance_index"]) for x in outcomes}))
    check("feature_future_count", sum(int(x["feature_future_count"]) for x in features))
    check("feature_after_t0", sum(number(x["feature_max_close_msc"]) > number(x["t0_msc"]) for x in features))
    valid = [x for x in outcomes if x["status"] in ("TP", "SL", "TIME", "TIMEOUT")]
    check("entry_before_processing", sum(number(x["entry_msc"]) < number(x["signal_processing_msc"]) for x in valid))
    check("entry_before_eligible", sum(number(x["entry_msc"]) < number(x["entry_eligible_msc"]) for x in valid))
    check("entry_not_after_source_quote", sum(number(x["entry_msc"]) <= number(x["source_quote_msc"]) for x in valid))
    check("entry_not_after_t0", sum(number(x["entry_msc"]) <= number(x["t0_msc"]) for x in valid))
    check("exit_before_entry", sum(number(x["exit_msc"]) < number(x["entry_msc"]) for x in valid))
    violations = {name: 0 for name in ("entry_executable_side", "gross_r", "gross_pips", "equal_tp_sl_distance",
                    "risk_distance", "tp_limit_exit", "stop_gap_not_favorable", "cost_distance_guard")}
    for row in valid:
        d = int(row["direction"])
        entry, exit = number(row["entry_price"]), number(row["exit_price"])
        distance, tick = number(row["distance"]), number(row["tick_size"])
        tolerance = max(1e-10, tick*1e-5)
        violations["entry_executable_side"] += abs(entry-number(row["entry_ask"] if d == 1 else row["entry_bid"])) > tolerance
        violations["gross_r"] += abs((exit-entry)*d/distance-number(row["gross_r"])) > 2e-7
        violations["gross_pips"] += abs((exit-entry)*d/number(row["pip_size"])-number(row["gross_pips"])) > 2e-6
        violations["equal_tp_sl_distance"] += abs(abs(number(row["tp"])-entry)-abs(number(row["sl"])-entry)) > tolerance
        violations["risk_distance"] += abs(abs(number(row["sl"])-entry)-distance) > tolerance
        violations["tp_limit_exit"] += row["status"] == "TP" and abs(exit-number(row["tp"])) > tolerance
        violations["stop_gap_not_favorable"] += row["status"] == "SL" and d*(exit-number(row["sl"])) > tolerance
        violations["cost_distance_guard"] += distance+tick*1e-5 < 3*number(row["entry_spread"])
    for name, value in violations.items():
        check(name, value)
    check("analysis_feature_sha", analysis["feature_sha256"], hashlib.sha256(Path(args.features).read_bytes()).hexdigest())
    check("analysis_outcome_sha", analysis["outcome_sha256"], hashlib.sha256(Path(args.outcomes).read_bytes()).hexdigest())
    model_path = output/"candidate_model.json"
    independent = []
    if model_path.exists():
        spec = json.loads(model_path.read_text(encoding="utf-8"))
        lookup = {(x["episode_id"], int(x["direction"])): x for x in outcomes if int(x["distance_index"]) == spec["distance_index"]}
        recorded_signals = {x["episode_id"]: x for x in read_csv(output/"candidate_all_signals.csv")}
        signal_mismatch = score_mismatch = 0
        choices = []
        for row in features:
            values = [number(row.get(name)) for name in spec["features"]]
            long_score = score(spec["models"]["long"], values)
            short_score = score(spec["models"]["short"], values)
            direction = 1 if long_score > short_score else -1 if short_score > long_score else 0
            if direction == 0:
                signal_mismatch += row["episode_id"] in recorded_signals
                continue
            recorded = recorded_signals.get(row["episode_id"])
            signal_mismatch += recorded is None or int(recorded["direction"]) != direction
            if recorded:
                score_mismatch += abs(number(recorded["long_score"])-long_score) > 1e-10 or abs(number(recorded["short_score"])-short_score) > 1e-10
            if max(long_score, short_score) >= spec["threshold"]:
                choices.append(lookup[(row["episode_id"], direction)])
        choices.sort(key=lambda x: (number(x["signal_processing_msc"]), number(x["t0_msc"]), x["episode_id"]))
        release = -1
        accepted = []
        for row in choices:
            if number(row["signal_processing_msc"]) <= release:
                continue
            if row["status"] not in ("TP", "SL", "TIME", "TIMEOUT"):
                if row["status"] == "NO_ENTRY":
                    release = max(release, number(row["signal_processing_msc"]), number(row["t0_msc"])+30000)
                elif row["status"] == "CENSORED":
                    release = max(release, number(row["entry_msc"])+900000)
                elif number(row["entry_msc"]) > 0:
                    release = max(release, number(row["entry_msc"]))
                continue
            accepted.append(row)
            release = number(row["exit_msc"])
        recorded_trades = read_csv(output/"candidate_portfolio_trades.csv")
        check("model_direction_parity", signal_mismatch)
        check("model_score_parity", score_mismatch)
        check("selected_trade_keys", [(x["episode_id"], x["direction"]) for x in accepted],
              [(x["episode_id"], x["direction"]) for x in recorded_trades])
        stats = aggregate(accepted, spec["primary_extra_cost_pips"])
        selected = analysis["candidate"]
        for name in ("trades", "tp", "sl", "timeout", "total_r", "expectancy_r", "total_pips", "expectancy_pips", "pf", "maxdd_r"):
            check("candidate_"+name, stats[name], selected[name], tolerance=1e-6)
        independent = [{"candidate_id": spec["candidate_id"], **stats}]
    else:
        check("no_candidate_model_consistent", analysis["candidate"] is None, True)
    with (output/"independent_qa_checks.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=("check", "expected", "actual", "tolerance", "status"))
        writer.writeheader()
        writer.writerows(checks)
    if independent:
        with (output/"independent_candidate_recalculation.csv").open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(independent[0]))
            writer.writeheader()
            writer.writerows(independent)
    failures = sum(x["status"] == "FAIL" for x in checks)
    print(json.dumps(dict(checks=len(checks), failures=failures, candidate=independent), indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--features", required=True)
    parser.add_argument("--outcomes", required=True)
    parser.add_argument("--output", required=True)
    run(parser.parse_args())
