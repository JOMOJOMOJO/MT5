"""Open labels only after the blind annotation files have been frozen.

Fixed descriptive comparisons. No EA changes, threshold fitting or new rules.
The balanced 60-case chart sample is case-control, not a win-rate estimator.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
import hashlib
import json
from pathlib import Path


VISUAL = {
    "prior_structure": ("CLEAR_COUNTERTREND", "RANGE_OR_MIXED", "UNCLEAR"),
    "w1_progress": ("CLEAN", "CHOPPY_OR_MIXED", "UNCLEAR"),
    "break_scope": ("OUTER_RANGE_CLEAR", "INTERNAL_ONLY", "UNCLEAR"),
}
FEATURES = {
    "wave1_breaks_pre8_outer_close": ("FALSE", "TRUE"),
    "wave1_range_over_preleg_median": ("LOW", "MID", "HIGH"),
    "wave1_range_over_preorigin_tr14": ("LOW", "MID", "HIGH"),
    "wave1_signed_close_efficiency": ("LOW", "MID", "HIGH"),
    "pre_countertrend_agreement": ("LOW", "MID", "HIGH"),
}
BINS = {
    "wave1_range_over_preleg_median": (1, 2),
    "wave1_range_over_preorigin_tr14": (2, 4),
    "wave1_signed_close_efficiency": (.3, .6),
    "pre_countertrend_agreement": (2/3, 1),
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    if path.suffix.lower() == ".json":
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        if isinstance(data, dict):
            data = data.get("annotations", data.get("cases", data.get("rows")))
        assert isinstance(data, list), path
        return data
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, rows):
    if not rows:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = list(dict.fromkeys(k for r in rows for k in r))
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def dump(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False), encoding="utf-8")


def metrics(rows):
    values = [float(r["net_r"]) for r in rows]
    cash = [float(r["net_cash"]) for r in rows]
    plus = sum(v for v in values if v > 0)
    minus = -sum(v for v in values if v < 0)
    cashplus = sum(v for v in cash if v > 0)
    cashminus = -sum(v for v in cash if v < 0)
    wins, losses = sum(v > 0 for v in values), sum(v < 0 for v in values)
    return dict(n=len(rows), wins=wins, losses=losses, flats=len(rows)-wins-losses,
                win_rate=wins/len(rows) if rows else None,
                mean_r=sum(values)/len(values) if values else None,
                sum_r=sum(values), pf_r=plus/minus if minus > 0 else None,
                net_cash=sum(cash), pf_cash=cashplus/cashminus if cashminus > 0 else None)


def category(row, feature):
    value = row.get(feature)
    if value is None or value == "":
        return "UNAVAILABLE"
    if feature == "wave1_breaks_pre8_outer_close":
        assert value in (True, False, "True", "False", "true", "false"), value
        return "TRUE" if value in (True, "True", "true") else "FALSE"
    value = float(value)
    low, high = BINS[feature]
    result = "LOW" if value < low else "MID" if value < high else "HIGH"
    assert row[feature + "_bin"] == result, (feature, value, row[feature + "_bin"])
    return result


def strata(rows):
    yield "ALL", rows
    for arm in ("A", "B"):
        yield f"ARM:{arm}", [r for r in rows if r["arm"] == arm]
    for direction in ("LONG", "SHORT"):
        yield f"DIRECTION:{direction}", [r for r in rows if r["direction"] == direction]
    for half in ("H1", "H2"):
        yield f"HALF:{half}", [r for r in rows if r["half"] == half]
    # These four cells check whether the A/B conclusion survives both halves;
    # they are descriptive stratification, never a new combined entry rule.
    for arm in ("A", "B"):
        for half in ("H1", "H2"):
            yield f"ARMHALF:{arm}/{half}", [r for r in rows if r["arm"] == arm and r["half"] == half]


def fixed_feature_groups(features):
    groups, missing, totals = [], [], []
    for cohort, rows in (
        ("ALL_440_IN_SAMPLE", features),
        ("SELECTED_60_CASE_CONTROL_IN_SAMPLE", [r for r in features if r["blind_id"]]),
        ("REMAINING_380_IN_SAMPLE", [r for r in features if not r["blind_id"]]),
    ):
        for stratum, subset in strata(rows):
            totals.append(dict(cohort=cohort, stratum=stratum, **metrics(subset)))
            for feature, categories in FEATURES.items():
                partition = defaultdict(list)
                for row in subset:
                    partition[category(row, feature)].append(row)
                missing.append(dict(cohort=cohort, stratum=stratum, feature=feature,
                                    n_total=len(subset), n_available=len(subset)-len(partition["UNAVAILABLE"]),
                                    n_unavailable=len(partition["UNAVAILABLE"])))
                for label in (*categories, "UNAVAILABLE"):
                    groups.append(dict(cohort=cohort, stratum=stratum, feature=feature,
                                       category=label, **metrics(partition[label])))
    return groups, missing, totals


def primary_verdict(groups):
    cells = {(r["cohort"], r["stratum"], r["category"]): r for r in groups
             if r["feature"] == "wave1_breaks_pre8_outer_close"}
    contrasts = []
    for cohort in ("ALL_440_IN_SAMPLE", "SELECTED_60_CASE_CONTROL_IN_SAMPLE", "REMAINING_380_IN_SAMPLE"):
        for stratum in ("ALL", "ARM:A", "ARM:B", "HALF:H1", "HALF:H2",
                        "ARMHALF:A/H1", "ARMHALF:A/H2", "ARMHALF:B/H1", "ARMHALF:B/H2",
                        "DIRECTION:LONG", "DIRECTION:SHORT"):
            clear, internal = cells[(cohort, stratum, "TRUE")], cells[(cohort, stratum, "FALSE")]
            difference = clear["mean_r"]-internal["mean_r"] if clear["n"] and internal["n"] else None
            contrasts.append(dict(cohort=cohort, stratum=stratum,
                                  n_clear=clear["n"], n_internal=internal["n"],
                                  mean_r_clear=clear["mean_r"], mean_r_internal=internal["mean_r"],
                                  difference_clear_minus_internal=difference,
                                  fixed_hypothesis_direction="CLEAR_GREATER_THAN_INTERNAL",
                                  direction_result="UNAVAILABLE" if difference is None else
                                      "SUPPORTS" if difference > 0 else "REVERSES" if difference < 0 else "TIED"))
    main = [r for r in contrasts if r["cohort"] == "ALL_440_IN_SAMPLE"]
    byname = {r["stratum"]: r for r in main}
    required = ("ARM:A", "ARM:B", "HALF:H1", "HALF:H2")
    if any(byname[s]["direction_result"] == "UNAVAILABLE" for s in required):
        verdict = "UNAVAILABLE_ONE_OR_MORE_REQUIRED_STRATA"
    elif all(byname[s]["direction_result"] == "SUPPORTS" for s in required):
        verdict = "DIRECTION_CONSISTENT_A_B_AND_BOTH_HALVES_IN_SAMPLE"
    else:
        verdict = "DIRECTION_NOT_CONSISTENT_A_B_AND_BOTH_HALVES_IN_SAMPLE"
    return contrasts, dict(primary_verdict=verdict,
                           required_strata=list(required),
                           required_results={s: byname[s]["direction_result"] for s in required},
                           note="Descriptive only; no sampling uncertainty or independent replication established.")


def annotation_rows(paths):
    rows = []
    for path in paths:
        for original in read(path):
            row = dict(original)
            row["annotation_file"] = str(path)
            assert row["blind_id"] and all(row[k] in codes for k, codes in VISUAL.items()), row
            rows.append(row)
    assert len(rows) == len({r["blind_id"] for r in rows}), "Duplicate blind IDs across annotation files"
    return rows


def validate_freeze(record_path, annotation_paths):
    record = json.loads(record_path.read_text(encoding="utf-8-sig"))
    expected = record.get("annotation_hashes")
    assert isinstance(expected, dict), "Freeze record must contain annotation_hashes path->SHA256"
    for path in annotation_paths:
        matches = [value for name, value in expected.items()
                   if str(path) == name or path.resolve() == Path(name).resolve()]
        assert len(matches) == 1, ("Annotation missing/ambiguous in freeze record", str(path))
        assert matches[0].lower() == digest(path).lower(), ("Annotation changed after freeze", str(path))


def visual_counts(rows):
    result = []
    for arm in ("ALL", "A", "B"):
        subset = [r for r in rows if arm == "ALL" or r["arm"] == arm]
        for feature, codes in VISUAL.items():
            for outcome in ("WIN", "LOSS"):
                outcome_subset = [r for r in subset if r["outcome"] == outcome]
                for code in codes:
                    count = sum(r[feature] == code for r in outcome_subset)
                    result.append(dict(arm=arm, feature=feature, category=code, outcome=outcome,
                                       count=count, outcome_group_total=len(outcome_subset),
                                       fraction_within_sample_outcome=count/len(outcome_subset) if outcome_subset else None,
                                       population_win_rate="NOT_ESTIMABLE_FROM_CASE_CONTROL_SAMPLE"))
    return result


def root_agreement(primary, checks):
    byid = {r["blind_id"]: r for r in primary}
    pair_rows, aggregate = [], []
    for r in checks:
        assert r["blind_id"] in byid
        for feature in VISUAL:
            left, right = byid[r["blind_id"]][feature], r[feature]
            pair_rows.append(dict(blind_id=r["blind_id"], feature=feature,
                                  primary_annotation=left, root_annotation=right,
                                  agrees=left == right))
    for feature in VISUAL:
        subset = [r for r in pair_rows if r["feature"] == feature]
        aggregate.append(dict(feature=feature, n=len(subset), matches=sum(r["agrees"] for r in subset),
                              agreement_fraction=sum(r["agrees"] for r in subset)/len(subset) if subset else None,
                              note="Root review is an internal reproducibility check, not independent ground truth."))
    return pair_rows, aggregate


def gallery_data(merged):
    """No new case selection: all sixty locked cases, with results now open."""
    return [dict(blind_id=r["blind_id"], arm=r["arm"], direction=r["direction"],
                 outcome=r["outcome"], net_r=float(r["net_r"]),
                 chart=f"../charts/{r['blind_id']}.png",
                 **{k: r.get(k, "") for k in (*VISUAL, "confidence", "concern")}) for r in merged]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", type=Path, default=Path("reports/qa/w33entry60/data"))
    parser.add_argument("--annotations", action="append", required=True, type=Path)
    parser.add_argument("--root-check", type=Path)
    parser.add_argument("--blind-frozen", required=True, type=Path,
                        help="Root-created freeze manifest/record; existence and hash mandatory before label reads")
    parser.add_argument("--out", type=Path, default=Path("reports/qa/w33entry60/analysis"))
    args = parser.parse_args()
    # Execute this entry point only after the root explicitly authorizes opening
    # labels. Mere passage of time or the presence of partially written reviews
    # is never treated as a frozen annotation record.
    assert args.blind_frozen.is_file(), "Blind freeze record is required"
    assert not (args.out / "manifest.json").exists(), "Refusing to overwrite fixed comparison"
    validate_freeze(args.blind_frozen, args.annotations + ([args.root_check] if args.root_check else []))
    inputs = {str(p): digest(p) for p in args.annotations}
    inputs[str(args.blind_frozen)] = digest(args.blind_frozen)
    annotations = annotation_rows(args.annotations)
    assert len(annotations) == 60, "All sixty primary image reviews must be frozen"
    render_manifest = args.data.parent / "charts/render_manifest.json"
    assert render_manifest.is_file()
    render_hash = digest(render_manifest)
    for path in args.annotations + ([args.root_check] if args.root_check else []):
        if path.suffix.lower() == ".json":
            document = json.loads(path.read_text(encoding="utf-8-sig"))
            assert document["render_manifest_sha256"].lower() == render_hash.lower(), ("Render hash differs", str(path))
    inputs[str(render_manifest)] = render_hash
    inputs[str(args.data / "manifest.json")] = digest(args.data / "manifest.json")
    labels_path, features_path = args.data / "labels/label_key.csv", args.data / "labels/features_all.csv"
    # First outcome access occurs only after the freeze assertions above.
    labels, features = read(labels_path), read(features_path)
    inputs[str(labels_path)], inputs[str(features_path)] = digest(labels_path), digest(features_path)
    assert len(features) == 440 and len(labels) == 60
    keys = {r["blind_id"]: r for r in labels}
    assert set(keys) == {r["blind_id"] for r in annotations}
    merged = sorted((dict(keys[r["blind_id"]], **r) for r in annotations), key=lambda r: r["blind_id"])
    assert Counter(r["outcome"] for r in merged) == {"WIN": 30, "LOSS": 30}
    for row in features:
        row["half"] = "H1" if int(row["month"][-2:]) <= 6 else "H2"
        row["net_r"], row["net_cash"] = float(row["net_r"]), float(row["net_cash"])
    assert sum(bool(r["blind_id"]) for r in features) == 60
    assert {(r["arm"], r["setup_id"]) for r in features if r["blind_id"]} == {(r["arm"], r["setup_id"]) for r in merged}
    groups, missing, totals = fixed_feature_groups(features)
    contrasts, verdict = primary_verdict(groups)
    write_csv(args.out / "visual_annotations_unblinded.csv", merged)
    write_csv(args.out / "visual_category_counts.csv", visual_counts(merged))
    write_csv(args.out / "fixed_feature_groups.csv", groups)
    write_csv(args.out / "feature_missing.csv", missing)
    write_csv(args.out / "cohort_totals.csv", totals)
    write_csv(args.out / "primary_contrasts.csv", contrasts)
    if args.root_check:
        validate_freeze(args.blind_frozen, [args.root_check])
        check_rows = read(args.root_check)
        for row in check_rows:
            assert all(row[k] in codes for k, codes in VISUAL.items())
        pairs, agreement = root_agreement(annotations, check_rows)
        write_csv(args.out / "root_agreement_pairs.csv", pairs)
        write_csv(args.out / "root_agreement.csv", agreement)
        inputs[str(args.root_check)] = digest(args.root_check)
    dump(args.out / "gallery_cases.json", gallery_data(merged))
    dump(args.out / "primary_verdict.json", verdict)
    manifest = dict(inputs=inputs, input_hashes_after={str(p): digest(Path(p)) for p in inputs},
                    comparison="five fixed feature definitions and bins; no fitted cutoffs or combined entry filters",
                    annual_n=440, selected_n=60, remainder_n=380,
                    case_control_sample="30 wins / 30 losses; visual group counts do not estimate annual win rate",
                    chronology="All 440 and remaining 380 are observed 2020 in-sample; neither is OOS",
                    profits="Net realized R under the unchanged v1.80 exits and historical test costs",
                    excluded_inferences=["No EA adoption", "No live-readiness claim", "No independent p-value claim",
                                         "No optimized threshold", "No causal treatment-effect estimate"],
                    outputs={p.name: digest(p) for p in args.out.iterdir() if p.is_file() and p.suffix in (".csv", ".json")})
    assert manifest["inputs"] == manifest["input_hashes_after"]
    dump(args.out / "manifest.json", manifest)
    print(json.dumps(dict(rows=len(features), reviewed=len(merged), **verdict)))


if __name__ == "__main__":
    main()
