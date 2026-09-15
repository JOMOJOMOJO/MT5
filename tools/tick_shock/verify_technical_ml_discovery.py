"""Refit twelve predetermined discovery configurations and verify frozen inputs.

This is a real deterministic refit, not a comparison of artifact hashes alone.
The models/configurations are fixed independently of their reported profitability.
Only the January-April cache and its recorded input files may be read.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import platform
import sys
import time

import lightgbm
import numpy as np
import pandas as pd
import sklearn

import technical_ml_discovery as ml


SCORE_TOLERANCE = 1e-10
FAMILIES = ("LOGISTIC", "ELASTICNET", "RANDOM_FOREST", "EXTRA_TREES",
            "SHALLOW_TREE", "LIGHTGBM")
SETUPS = (("WIN", "FULL486", 3, 202503),
          ("NET_R", "SCALE_FREE", 5, 202504))
TRAINING_MONTHS = {202501, 202502, 202503, 202504}


def predetermined_tasks():
    return [(family, *setup) for family in FAMILIES for setup in SETUPS]


def safe_recorded_path(value):
    path = (ml.ROOT / value).resolve()
    path.relative_to(ml.ROOT.resolve())
    return path


def first_missing_input(output):
    required = [output / name for name in
                ("environment.json", "input_hashes.csv", "protected_source_hashes.csv", "dataset.pkl")]
    for task in predetermined_tasks():
        ident = ml.task_id(*task)
        required.extend([output / "tasks" / f"{ident}.json",
                         output / "predictions" / f"{ident}.npz"])
    return next((path for path in required if not path.is_file()), None)


def integrity_rows(output, environment):
    rows = []

    def check_file(category, path, expected):
        actual = ml.sha(path) if path.is_file() else "MISSING"
        rows.append(dict(category=category, path=str(path.relative_to(ml.ROOT)),
                         expected=str(expected), actual=actual,
                         status="PASS" if actual.lower() == str(expected).lower() else "FAIL"))

    check_file("analysis_source", Path(ml.__file__).resolve(),
               environment["analysis_source_sha256"])
    check_file("preregistration", ml.ROOT / "docs/research/tick_shock/technical_ml_discovery_preregistration.md",
               environment["preregistration_sha256"])
    current_versions = dict(python=platform.python_version(), sklearn=sklearn.__version__,
                            lightgbm=lightgbm.__version__, numpy=np.__version__, pandas=pd.__version__,
                            seed=ml.SEED)
    for name, actual in current_versions.items():
        expected = environment[name]
        rows.append(dict(category="execution_environment", path=name,
                         expected=str(expected), actual=str(actual),
                         status="PASS" if str(expected) == str(actual) else "FAIL"))
    inputs = pd.read_csv(output / "input_hashes.csv")
    if set(inputs.month.astype(int)) != TRAINING_MONTHS:
        raise ValueError("Input manifest must contain January-April only; no holdout reads permitted")
    for record in inputs.itertuples(index=False):
        path = safe_recorded_path(record.path)
        if path.parent.name != str(record.month):
            raise ValueError(f"Input month/path discrepancy: {record.path}")
        check_file("recorded_training_input", path, record.sha256)
    protected = pd.read_csv(output / "protected_source_hashes.csv")
    for record in protected.itertuples(index=False):
        check_file("protected_mql_fixture_expected", safe_recorded_path(record.path), record.sha256)
    return rows


def numeric_comparison(actual, expected, tolerance):
    actual = np.asarray(actual, dtype=float)
    expected = np.asarray(expected, dtype=float)
    if actual.shape != expected.shape:
        return False, math.inf
    if np.isnan(actual).any() or np.isnan(expected).any():
        return False, math.nan
    finite = np.isfinite(actual) & np.isfinite(expected)
    if not np.array_equal(actual[~finite], expected[~finite]):
        return False, math.inf
    delta = float(np.max(np.abs(actual[finite] - expected[finite]))) if finite.any() else 0.
    return bool(delta <= tolerance), delta


def threshold_value(value):
    # core.clean_json encodes non-finite values as JSON null. The only valid
    # non-finite threshold is +Infinity for an empty/no-entry calibration set.
    return math.inf if value is None else float(value)


def rerun_one(output, task, data):
    family, target, variant, geometry, month = task
    ident = ml.task_id(*task)
    saved_path = output / "tasks" / f"{ident}.json"
    saved = json.loads(saved_path.read_text(encoding="utf-8"))
    if saved["task"] != list(task):
        raise ValueError(f"Task identity mismatch: {ident}")
    f, outcomes, features, columns = data
    x = features[:, columns[variant]]
    group = outcomes[outcomes.distance_index == geometry]
    split = ml.split_indices(f, group, month)
    started = time.perf_counter()
    pair, counts = ml.fit_pair(family, target, x, f, group, split["fit"])
    rows = []

    def append(check, passed, *, count=1, delta=0., expected="", actual="", tolerance=SCORE_TOLERANCE):
        rows.append(dict(task_id=ident, family=family, target=target, variant=variant,
                         geometry=geometry, month=month, check=check, rows=count,
                         tolerance=tolerance, max_absolute_difference=delta,
                         expected=expected, actual=actual, status="PASS" if passed else "FAIL",
                         evidence_path=str(saved_path.relative_to(ml.ROOT))))

    with np.load(output / "predictions" / f"{ident}.npz") as prediction:
        append("validation_indices", np.array_equal(split["val"], prediction["indices"]),
               count=len(split["val"]), tolerance=0,
               expected=len(prediction["indices"]), actual=len(split["val"]))
        for side, key in ((1, "long_score"), (-1, "short_score")):
            actual = pair[side].predict(x[split["val"]])
            passed, delta = numeric_comparison(actual, prediction[key], SCORE_TOLERANCE)
            append(key + "_actual_refit", passed, count=len(actual), delta=delta)
    append("fitting_label_counts", counts == [saved["fitting_long"], saved["fitting_short"]],
           tolerance=0, expected=str([saved["fitting_long"], saved["fitting_short"]]), actual=str(counts))
    for key in ("cut", "boundary", "fit_months", "cal_months"):
        passed, delta = numeric_comparison(split[key], saved["split"][key], SCORE_TOLERANCE)
        append("split_" + key, passed, delta=delta, expected=saved["split"][key], actual=split[key])
    for key in ("fit", "cal", "val"):
        append("split_count_" + key, len(split[key]) == saved["split"][key], tolerance=0,
               expected=saved["split"][key], actual=len(split[key]))
    actions = {}
    for part in ("fit", "cal"):
        ix = split[part]
        actions[part] = ml.choose_actions(group, f.loc[ix],
                                          pair[1].predict(x[ix]), pair[-1].predict(x[ix]))
    recalculated = ml.policies(actions["fit"], actions["cal"], split)
    original = {row["policy"]: row for row in saved["rows"]}
    append("policy_id_set", {row["policy"] for row in recalculated} == set(original),
           tolerance=0, expected=len(original), actual=len(recalculated))
    for row in recalculated:
        if row["policy"] not in original:
            continue
        before = original[row["policy"]]
        for field in ("threshold", "calibration_achieved", "calibration_max"):
            old = before[field]
            new = row[field]
            if field != "threshold" and old is None and math.isnan(float(new)):
                passed, delta = True, 0.
            else:
                old_value = threshold_value(old) if field == "threshold" else old
                passed, delta = numeric_comparison(new, old_value, SCORE_TOLERANCE)
            append(row["policy"] + "_" + field, passed, delta=delta,
                   expected="BLANK" if old is None else old, actual=new)
    for row in rows:
        row["refit_elapsed_seconds"] = time.perf_counter() - started
    return rows


def run(output):
    output = output.resolve()
    output.relative_to(ml.ROOT.resolve())
    missing = first_missing_input(output)
    if missing is not None:
        print(f"NOT_READY: {missing}", flush=True)
        return 3
    environment = json.loads((output / "environment.json").read_text(encoding="utf-8"))
    source_rows = integrity_rows(output, environment)
    ml.dump(source_rows, output / "verify_source_integrity.csv")
    if any(row["status"] != "PASS" for row in source_rows):
        print("FAIL: source/environment integrity mismatch; no refit performed.", flush=True)
        return 2
    ml.init_worker(output / "dataset.pkl")
    data = ml._DATA
    if set(data[0].month.astype(int)) != TRAINING_MONTHS or set(data[1].month.astype(int)) != TRAINING_MONTHS:
        raise ValueError("Cache must contain January-April only")
    result = []
    for number, task in enumerate(predetermined_tasks(), 1):
        try:
            rows = rerun_one(output, task, data)
        except Exception as exc:
            rows = [dict(task_id=ml.task_id(*task), check="refit_exception", status="FAIL",
                         expected="Successful unchanged-configuration refit",
                         actual=f"{type(exc).__name__}: {exc}")]
        result.extend(rows)
        ml.dump(result, output / "deterministic_rerun.csv")
        passed = all(row["status"] == "PASS" for row in rows)
        print(f"{number}/12 {ml.task_id(*task)} {'PASS' if passed else 'FAIL'} ({len(rows)} checks)", flush=True)
    # Check unchanged inputs again after the real computation, not merely before.
    after = integrity_rows(output, environment)
    for row in source_rows:
        row["phase"] = "BEFORE_REFIT"
    for row in after:
        row["phase"] = "AFTER_REFIT"
    ml.dump(source_rows + after, output / "verify_source_integrity.csv")
    failures = sum(row["status"] != "PASS" for row in result + source_rows + after)
    print(f"Actual deterministic refits=12; comparison checks={len(result)}; failures={failures}", flush=True)
    return 1 if failures else 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ml.OUT)
    sys.exit(run(parser.parse_args().output))
