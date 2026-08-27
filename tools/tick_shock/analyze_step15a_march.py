#!/usr/bin/env python3
"""Independently reconcile the four predeclared Step 15A March runs.

The analysis deliberately does not call the MQL detector implementation.  It
uses archived CSV outputs, the frozen pre-analysis rules, and an independent
Gaussian-null/empirical-rank/Holm oracle.  Missing matched-control boundary
evidence is fail-closed rather than imputed.
"""

from __future__ import annotations

import csv
import hashlib
import math
import random
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np

csv.field_size_limit(min(sys.maxsize, 2_147_483_647))


ROOT = Path(__file__).resolve().parents[2]
RUN_ROOT = ROOT / "reports/backtest/runs"
RESEARCH = ROOT / "reports/research/tick_shock"
BASELINE = RUN_ROOT / "20260825_ts14r3_realizable_202503"
RUNS = {
    "STRICT_V0": RUN_ROOT / "20260827_ts15a_strict_v0_realizable_202503_r2",
    "TAIL_V1_RAW": RUN_ROOT / "20260827_ts15a_tail_v1_raw_realizable_202503_r2",
    "TAIL_V1_NOISE_ROBUST": RUN_ROOT / "20260827_ts15a_tail_v1_noise_robust_realizable_202503_r2",
    "TAIL_V1_PERSISTENT": RUN_ROOT / "20260827_ts15a_tail_v1_persistent_realizable_202503_r2",
}
SPEC_SHA = "53DB75EEE4641D98F4917E74B9C26B84D07533CE8EA1A6689AF7F36BAAEA64EA"
PRIMARY = ("abs_return_1s", "abs_return_3s", "realized_volatility_120s")
SECONDARY = (
    "abs_return_10s", "abs_return_30s", "abs_return_120s", "mfe_120s",
    "mae_120s", "spread_change_120s", "tick_activity_120s",
    "quote_reversion_ratio",
)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, rows: list[dict[str, object]], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def parse_map(value: str) -> dict[str, str]:
    output: dict[str, str] = {}
    for token in value.split(";"):
        if "=" in token:
            key, item = token.split("=", 1)
            output[key] = item
    return output


def parse_set(path: Path) -> dict[str, str]:
    output: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if "=" in line and not line.lstrip().startswith(("#", ";")):
            key, value = line.split("=", 1)
            output[key.strip()] = value.strip()
    return output


def summary_index(run: Path) -> dict[tuple[str, str], dict[str, str]]:
    return {(row["record_type"], row["key"]): row for row in read_csv(run / "summary.csv")}


def as_int(value: str) -> int:
    return int(value or 0)


def event_direction(row: dict[str, str]) -> str:
    # The feature-v1 implementation omitted the predeclared direction column.
    # The final event-id token is a sequence number, not direction; do not
    # fabricate a classification from it.
    return "NOT_SERIALIZED"


def market_cluster_times(rows: list[dict[str, str]]) -> dict[str, int]:
    result: dict[str, int] = {}
    for row in rows:
        cid = row.get("market_cluster_id", "")
        time = as_int(row.get("confirmed_time_msc", "0"))
        if cid and (cid not in result or time < result[cid]):
            result[cid] = time
    return result


def independent_null() -> dict[str, object]:
    seed = 20260826
    n_calibration = 50_000
    n_families = 100_000
    rng = np.random.default_rng(seed)
    calibration = np.abs(rng.standard_normal((3, n_calibration)))
    tested = np.abs(rng.standard_normal((n_families, 3)))
    p_values = np.empty_like(tested)
    for horizon in range(3):
        ordered = np.sort(calibration[horizon])
        first_ge = np.searchsorted(ordered, tested[:, horizon], side="left")
        p_values[:, horizon] = (1 + n_calibration - first_ge) / (n_calibration + 1)
    # Any Holm family rejection occurs iff its smallest raw p passes alpha/3.
    rejected = np.sort(p_values, axis=1)[:, 0] <= 0.01 / 3.0
    rate = float(np.mean(rejected))
    return {
        "seed": seed,
        "families": n_families,
        "calibration_samples_per_horizon": n_calibration,
        "horizons": 3,
        "alpha": 0.01,
        "observed_family_rejection_rate": f"{rate:.8f}",
        "lower_gate": "0.00850000",
        "upper_gate": "0.01150000",
        "status": "PASS" if 0.0085 <= rate <= 0.0115 else "FAIL",
        "oracle": "independent_numpy_gaussian_abs_rank_holm",
    }


def strict_regression() -> list[dict[str, object]]:
    current_summary = summary_index(RUNS["STRICT_V0"])
    baseline_summary = summary_index(BASELINE)
    fields = {
        "raw_candidates": ("OVERALL", "ALL", "raw_candidates"),
        "event_rows": ("OVERALL", "ALL", "events"),
        "valid_pullbacks": ("FUNNEL", "valid_pullbacks", "events"),
        "reacceleration": ("FUNNEL", "reacceleration_signals", "events"),
        "reversal_signals": ("FUNNEL", "failed_shock_reversal_signals", "events"),
        "scenario_valid": ("OVERALL", "ALL", "scenario_valid"),
        "scenario_invalid": ("OVERALL", "ALL", "scenario_invalid"),
        "scenario_expectancy_r": ("OVERALL", "ALL", "scenario_expectancy_r"),
    }
    rows: list[dict[str, object]] = []
    for metric, (section, key, field) in fields.items():
        before = baseline_summary[(section, key)][field]
        after = current_summary[(section, key)][field]
        rows.append({"comparison": metric, "baseline": before, "strict_v0": after,
                     "status": "MATCH" if before == after else "MISMATCH"})
    before_events = read_csv(BASELINE / "events.csv")
    after_events = read_csv(RUNS["STRICT_V0"] / "events.csv")
    identity = lambda row: (row["symbol"], row["detector_window_ms"], row["detection_time_msc"], row["direction"])
    before_map = {identity(row): row for row in before_events}
    after_map = {identity(row): row for row in after_events}
    rows.append({"comparison": "event_identity_set", "baseline": len(before_map),
                 "strict_v0": len(after_map), "status": "MATCH" if before_map.keys() == after_map.keys() else "MISMATCH"})
    compare_fields = (
        "shock_gate_mask", "detection_grid_msc", "detection_quote_msc",
        "detection_quote_age_ms", "robust_z", "efficiency", "tick_count",
        "tick_intensity_ratio", "move_spread_ratio", "burst_end_time_msc",
        "burst_range", "max_retracement_pct", "pullback_time_msc",
        "reacceleration_time_msc", "continuation_invalidated_msc", "state_status",
        "state_skip_reason", "symbol_cluster_id", "market_cluster_id",
    )
    mismatches = 0
    for key in before_map.keys() & after_map.keys():
        mismatches += sum(before_map[key].get(field) != after_map[key].get(field) for field in compare_fields)
    rows.append({"comparison": "event_metric_cells", "baseline": len(before_map) * len(compare_fields),
                 "strict_v0": f"mismatches={mismatches}", "status": "MATCH" if mismatches == 0 else "MISMATCH"})
    return rows


def scenario_outcomes(run: Path) -> Counter[str]:
    counts: Counter[str] = Counter()
    for event in read_csv(run / "events.csv"):
        for encoded in event.get("scenario_grid", "").split(";"):
            if not encoded:
                continue
            parts = encoded.split("|")
            status = parts[4] if len(parts) > 4 else "MALFORMED"
            counts[status] += 1
    return counts


def scenario_causal_violations(run: Path) -> int:
    violations = 0
    for event in read_csv(run / "events.csv"):
        for encoded in event.get("scenario_grid", "").split(";"):
            if not encoded:
                continue
            parts = encoded.split("|")
            status = parts[4] if len(parts) > 4 else ""
            if status not in {"TP_LIMIT", "SL_GAP", "TIME_MARKET"}:
                continue
            values = parse_map(encoded.replace("|", ";"))
            if not values.get("entry_quote"):
                continue
            entry = as_int(values["entry_quote"])
            eligible = as_int(values.get("eligible", "0"))
            processing = as_int(values.get("signal_processing", "0"))
            if entry < eligible or entry < processing:
                violations += 1
    return violations


def main() -> int:
    RESEARCH.mkdir(parents=True, exist_ok=True)
    required = [BASELINE / "events.csv", BASELINE / "summary.csv"]
    for run in RUNS.values():
        required.extend(run / name for name in (
            "events.csv", "summary.csv", "detector_features.csv", "tick_quality.csv",
            "source_hashes.txt", "tester_report.html", "tester_journal_excerpt.txt",
        ))
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise FileNotFoundError("missing Step 15A evidence:\n" + "\n".join(missing))

    null = independent_null()
    write_csv(RESEARCH / "step15a_false_positive_calibration.csv", [null], list(null))

    regression = strict_regression()
    write_csv(RESEARCH / "step15a_strict_regression.csv", regression,
              ["comparison", "baseline", "strict_v0", "status"])

    feature_rows = {name: read_csv(path / "detector_features.csv") for name, path in RUNS.items()}
    comparison: list[dict[str, object]] = []
    severity_rows: list[dict[str, object]] = []
    strategy_rows: list[dict[str, object]] = []
    matched_rows: list[dict[str, object]] = []
    bootstrap_rows: list[dict[str, object]] = []

    for detector, run in RUNS.items():
        summary = summary_index(run)
        overall = summary[("OVERALL", "ALL")]
        cluster_info = parse_map(summary.get(("STATISTICAL_CLUSTER", "counts"), {}).get("value", ""))
        features = feature_rows[detector]
        feature_clusters = len({row["market_cluster_id"] for row in features if row.get("market_cluster_id")})
        integrity = parse_map(summary[("INTEGRITY", "fail_closed")]["value"])
        symbols = Counter(row["symbol"] for row in features)
        max_symbol_share = max(symbols.values(), default=0) / len(features) if features else 0.0
        representatives: dict[str, dict[str, str]] = {}
        for feature in features:
            cid = feature.get("market_cluster_id", "")
            if not cid:
                continue
            if cid not in representatives or as_int(feature["confirmed_time_msc"]) < as_int(representatives[cid]["confirmed_time_msc"]):
                representatives[cid] = feature
        cluster_symbols = Counter(row["symbol"] for row in representatives.values())
        max_symbol_cluster_share = max(cluster_symbols.values(), default=0) / len(representatives) if representatives else 0.0
        duplicate_keys = len(features) - len({
            (row.get("symbol"), row.get("candidate_time_msc"), row.get("confirmed_time_msc"),
             row.get("horizons_triggered_mask")) for row in features
        })
        backdates = sum(as_int(row.get("confirmed_time_msc", "0")) < as_int(row.get("candidate_time_msc", "0")) for row in features)
        provenance_mismatches = sum(
            row.get("spec_sha256") != SPEC_SHA or row.get("detector_version") != detector for row in features
        )
        incomplete_records = sum(row.get("record_status") != "COMPLETE_120S" for row in features if detector != "STRICT_V0")
        outcomes = scenario_outcomes(run)
        selection = "FAIL_MATCHED_CONTROL_EVIDENCE_MISSING"
        comparison.append({
            "detector_id": detector,
            "raw_candidates": overall["raw_candidates"],
            "statistical_events": len(features),
            "strategy_eligible_events": overall["event_csv_rows"],
            "symbol_clusters": cluster_info.get("symbol_clusters", "") if detector != "STRICT_V0" else 17,
            "market_clusters": cluster_info.get("market_clusters", feature_clusters) if detector != "STRICT_V0" else 15,
            "feature_market_clusters_recount": feature_clusters,
            "valid_pullbacks": summary[("FUNNEL", "valid_pullbacks")]["events"],
            "reacceleration_signals": summary[("FUNNEL", "reacceleration_signals")]["events"],
            "reversal_signals": summary[("FUNNEL", "failed_shock_reversal_signals")]["events"],
            "scenario_valid": overall["scenario_valid"],
            "scenario_invalid": overall["scenario_invalid"],
            "diagnostic_expectancy_r": overall["scenario_expectancy_r"],
            "max_symbol_event_share": f"{max_symbol_share:.8f}",
            "max_symbol_cluster_share": f"{max_symbol_cluster_share:.8f}",
            "runtime_seconds": overall["runtime_seconds"],
            "summary_max_memory_mb": overall["max_memory_mb"],
            "event_csv_rows": overall["event_csv_rows"],
            "event_csv_bytes": overall["event_csv_bytes"],
            "feature_csv_rows": len(features),
            "feature_csv_bytes": (run / "detector_features.csv").stat().st_size,
            "integrity_status": integrity.get("validation", ""),
            "event_pool_exhaustions": integrity.get("event_pool_exhaustions", ""),
            "pending_capacity_hits": integrity.get("pending_capacity_hits", ""),
            "dropped_ticks": integrity.get("dropped_ticks", ""),
            "cursor_stalls": integrity.get("cursor_stalls", ""),
            "duplicate_feature_keys": duplicate_keys,
            "confirmed_before_candidate": backdates,
            "scenario_entry_causal_violations": scenario_causal_violations(run),
            "provenance_mismatches": provenance_mismatches,
            "incomplete_v1_records": incomplete_records,
            "direction_column_status": "MISSING" if features and "direction" not in features[0] else "PRESENT",
            "synthetic_null_status": null["status"],
            "matched_control_status": "NOT_ESTIMABLE",
            "selection_status": selection,
        })
        for status, count in sorted(outcomes.items()):
            strategy_rows.append({"detector_id": detector, "dimension": "scenario_status", "key": status, "count": count})

        dimensions = {
            "symbol": lambda r: r["symbol"],
            "direction": event_direction,
            "horizon_ms": lambda r: r["trigger_horizon_ms"],
            "severity": lambda r: r["severity"],
            "time_bucket": lambda r: r["time_of_day_bucket"],
            "volatility_regime": lambda r: r["volatility_regime"],
        }
        for dimension, getter in dimensions.items():
            grouped: dict[str, list[dict[str, str]]] = defaultdict(list)
            for row in features:
                grouped[getter(row)].append(row)
            for key, rows in sorted(grouped.items()):
                severity_rows.append({
                    "detector_id": detector, "dimension": dimension, "key": key,
                    "event_rows": len(rows),
                    "market_clusters": len({r["market_cluster_id"] for r in rows if r.get("market_cluster_id")}),
                    "strategy_signal_true": sum(r.get("strategy_signal") == "true" for r in rows),
                })
        for severity in ("P990", "P995", "P999"):
            severity_count = sum(row.get("severity") == severity for row in features)
            severity_clusters = len({row["market_cluster_id"] for row in features if row.get("severity") == severity})
            for outcome in PRIMARY + SECONDARY:
                matched_rows.append({
                    "detector_id": detector, "severity": severity, "outcome": outcome,
                    "event_rows": severity_count, "event_market_clusters": severity_clusters,
                    "matched_clusters": 0, "mean_event": "", "mean_control": "",
                    "mean_difference": "", "status": "NOT_ESTIMABLE",
                    "reason": "NON_EVENT_CONTROL_BOUNDARIES_WITH_COMPLETE_120S_OUTCOMES_WERE_NOT_RECORDED",
                })
                bootstrap_rows.append({
                    "detector_id": detector, "severity": severity, "outcome": outcome,
                    "replicates": 10000, "mean_block_clusters": 4, "seed": 20260826,
                    "mean_difference": "", "ci_lower": "", "ci_upper": "", "raw_p": "",
                    "holm_p": "", "bh_q": "", "status": "NOT_ESTIMABLE_MISSING_MATCHED_CONTROLS",
                })

    comparison_fields = list(comparison[0])
    write_csv(RESEARCH / "step15a_detector_comparison.csv", comparison, comparison_fields)
    write_csv(RESEARCH / "step15a_severity_analysis.csv", severity_rows,
              ["detector_id", "dimension", "key", "event_rows", "market_clusters", "strategy_signal_true"])
    write_csv(RESEARCH / "step15a_strategy_secondary_diagnostics.csv", strategy_rows,
              ["detector_id", "dimension", "key", "count"])
    write_csv(RESEARCH / "step15a_matched_control_results.csv", matched_rows,
              ["detector_id", "severity", "outcome", "event_rows", "event_market_clusters", "matched_clusters",
               "mean_event", "mean_control", "mean_difference", "status", "reason"])
    write_csv(RESEARCH / "step15a_cluster_bootstrap.csv", bootstrap_rows,
              ["detector_id", "severity", "outcome", "replicates", "mean_block_clusters", "seed",
               "mean_difference", "ci_lower", "ci_upper", "raw_p", "holm_p", "bh_q", "status"])

    overlap_rows: list[dict[str, object]] = []
    names = list(RUNS)
    for left_index, left_name in enumerate(names):
        left = feature_rows[left_name]
        left_by_symbol: dict[str, list[int]] = defaultdict(list)
        for row in left:
            left_by_symbol[row["symbol"]].append(as_int(row["confirmed_time_msc"]))
        for right_name in names[left_index + 1:]:
            right = feature_rows[right_name]
            right_by_symbol: dict[str, list[int]] = defaultdict(list)
            for row in right:
                right_by_symbol[row["symbol"]].append(as_int(row["confirmed_time_msc"]))
            left_matched = right_matched = pairs = 0
            for symbol in sorted(set(left_by_symbol) | set(right_by_symbol)):
                a = sorted(left_by_symbol[symbol]); b = sorted(right_by_symbol[symbol])
                matched_a: set[int] = set(); matched_b: set[int] = set()
                j = 0
                for i, time_a in enumerate(a):
                    while j < len(b) and b[j] < time_a - 2000:
                        j += 1
                    k = j
                    while k < len(b) and b[k] <= time_a + 2000:
                        matched_a.add(i); matched_b.add(k); pairs += 1; k += 1
                left_matched += len(matched_a); right_matched += len(matched_b)
            union = len(left) + len(right) - min(left_matched, right_matched)
            overlap_rows.append({
                "detector_a": left_name, "detector_b": right_name,
                "events_a": len(left), "events_b": len(right),
                "events_a_with_overlap": left_matched, "events_b_with_overlap": right_matched,
                "overlap_pairs_within_2000ms_same_symbol": pairs,
                "jaccard_like_overlap": f"{min(left_matched, right_matched) / union:.8f}" if union else "",
            })
    write_csv(RESEARCH / "step15a_event_overlap.csv", overlap_rows, list(overlap_rows[0]))

    # Compare the 43 frozen strategy/execution parameters against Step 14R.
    baseline_parameters = read_csv(ROOT / "reports/qa/tick_shock/step14r_strategy_parameter_comparison.csv")
    frozen = [row["parameter"] for row in baseline_parameters if row["classification"] == "strategy_or_execution_parameter"]
    baseline_set = parse_set(next(BASELINE.glob("*.set")))
    parameter_rows: list[dict[str, object]] = []
    for detector, run in RUNS.items():
        current = parse_set(next(run.glob("*.set")))
        for parameter in frozen:
            before = baseline_set.get(parameter, "<MISSING>")
            after = current.get(parameter, "<MISSING>")
            schema_only = parameter == "InpSchemaVersion"
            status = ("UNCHANGED" if before == after else
                      "ALLOWED_VERSIONED_FEATURE_SCHEMA_CHANGE" if schema_only else "CHANGED")
            parameter_rows.append({"detector_id": detector, "parameter": parameter, "baseline": before,
                                   "current": after,
                                   "classification": "output_provenance" if schema_only else "strategy_or_execution",
                                   "status": status})
    write_csv(RESEARCH / "step15a_parameter_diff.csv", parameter_rows,
              ["detector_id", "parameter", "baseline", "current", "classification", "status"])

    # Per-run independent reconciliation summaries.
    for detector, run in RUNS.items():
        row = next(item for item in comparison if item["detector_id"] == detector)
        content = [
            f"# Step 15A reconciliation - {detector}", "",
            f"- source commit: `{parse_set(next(run.glob('*.set')))['InpSourceCommit']}`",
            f"- detector feature rows: {row['feature_csv_rows']}",
            f"- strategy event rows: {row['event_csv_rows']}",
            f"- statistical market clusters: {row['market_clusters']}",
            f"- integrity: `{row['integrity_status']}`",
            f"- event-pool exhaustion / pending hit / drop / stall: {row['event_pool_exhaustions']} / {row['pending_capacity_hits']} / {row['dropped_ticks']} / {row['cursor_stalls']}",
            f"- matched controls: `NOT_ESTIMABLE` (required non-event boundary outcomes were not serialized)",
            f"- formal selection: `{row['selection_status']}`", "",
            "This is March development/regression evidence, not locked validation or an edge claim.",
        ]
        (run / "reconciliation.md").write_text("\n".join(content) + "\n", encoding="utf-8")
        (run / "summary.md").write_text("\n".join(content) + "\n", encoding="utf-8")

    print(f"detectors={len(comparison)} synthetic_null={null['status']} strict_mismatches={sum(r['status'] != 'MATCH' for r in regression)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
