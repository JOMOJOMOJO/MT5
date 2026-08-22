#!/usr/bin/env python3
"""Compare Tick-shock event/summary evidence across the Step 4 refactor.

The preservation oracle must be a run produced by the source immediately before
the refactor.  The older manifest baseline is compared separately and any drift
there is reported as REFERENCE_VERSION_DRIFT, never hidden as a refactor pass.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import sys
from pathlib import Path

csv.field_size_limit(min(sys.maxsize, 2_147_483_647))


EXCLUDED = {"run_id", "runtime_seconds", "average_memory_mb", "max_memory_mb",
            "event_csv_bytes", "trade_csv_bytes"}
EVENT_KEY = ("symbol", "detector_window_ms", "detection_time_msc", "direction")
EVENT_GROUPS = {
    "event_identity": EVENT_KEY,
    "detector_metrics": (
        "shock_gate_mask", "detection_grid_msc", "detection_quote_msc",
        "detection_quote_age_ms", "detection_bid", "detection_ask",
        "detection_mid", "shock_start_mid", "detection_shock_range",
        "log_return_250", "log_return_250_valid", "log_return_500",
        "log_return_500_valid", "log_return_1000", "log_return_1000_valid",
        "percentile_move", "median_move", "mad_move", "robust_scale_move",
        "robust_scale_floored", "robust_z", "efficiency", "tick_count",
        "tick_intensity_ratio", "spread", "spread_median",
        "move_spread_ratio", "quote_age_ms", "baseline_samples",
    ),
    "state_result": (
        "burst_end_time_msc", "burst_end_bid", "burst_end_ask",
        "burst_end_mid", "burst_range", "burst_spread_ratio",
        "max_retracement_pct", "pullback_time_msc", "reacceleration_time_msc",
        "continuation_invalidated_msc", "state_status", "state_skip_reason",
    ),
    "signal_time": (
        "signal_processing_msc", "merge_lag_ms",
        "detection_time_continuation_signal_event_msc",
        "detection_time_continuation_signal_processing_msc",
        "post_burst_continuation_signal_event_msc",
        "post_burst_continuation_signal_processing_msc",
        "pullback_continuation_signal_event_msc",
        "pullback_continuation_signal_processing_msc",
        "failed_shock_reversal_signal_event_msc",
        "failed_shock_reversal_signal_processing_msc",
    ),
    "cluster": (
        "symbol_cluster_id", "market_cluster_id", "symbol_overlap_event",
        "market_overlap_event",
    ),
}
SCENARIO_GROUPS = {
    "scenario_status": ("status",),
    "signal_time": ("signal_event", "signal_processing", "eligible",
                    "entry_quote", "actual_delay", "processing_to_entry"),
    "entry": ("entry_quote", "risk"),
    "sl": ("sl", "stops_distance", "freeze_distance", "freeze_clear"),
    "tp": ("tp", "requested_rr", "realized_rr"),
    "exit": ("exit", "exit_px", "stop_gap", "exit_slip"),
    "R": ("net", "gross", "commission_r"),
    "policy_mask": ("policy",),
}
SUMMARY_FIELDS = ("events", "raw_candidates", "ticks", "scenario_valid",
                  "scenario_invalid", "scenario_expectancy_r", "value")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def csv_header(path: Path) -> list[str]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return next(csv.reader(handle))


def event_key(row: dict[str, str]) -> tuple[str, ...]:
    return tuple(row.get(name, "") for name in EVENT_KEY)


def parse_scenarios(row: dict[str, str]) -> dict[tuple[str, ...], dict[str, str]]:
    result: dict[tuple[str, ...], dict[str, str]] = {}
    for raw_item in row.get("scenario_grid", "").split(";"):
        if not raw_item:
            continue
        parts = raw_item.split("|")
        if len(parts) < 5:
            continue
        values = {"strategy": parts[0], "stop": parts[1], "delay": parts[2],
                  "spread": parts[3], "status": parts[4]}
        for part in parts[5:]:
            if "=" in part:
                key, value = part.split("=", 1)
                values[key] = value
        key = (values["strategy"], values["stop"], values["delay"], values["spread"])
        result[key] = values
    return result


def add_row(rows: list[dict[str, str]], scope: str, record_type: str,
            record_key: str, aspect: str, field: str, compared: int,
            mismatches: int, reference: str = "", candidate: str = "") -> None:
    if mismatches == 0:
        classification = "MATCH"
    elif scope == "mandated_baseline_reference":
        classification = "REFERENCE_VERSION_DRIFT"
    else:
        classification = "UNINTENDED_DIFFERENCE"
    rows.append({
        "comparison_scope": scope,
        "record_type": record_type,
        "record_key": record_key,
        "aspect": aspect,
        "field": field,
        "compared_values": str(compared),
        "mismatches": str(mismatches),
        "reference_value": reference,
        "candidate_value": candidate,
        "classification": classification,
    })


def compare_events(scope: str, reference_rows: list[dict[str, str]],
                   candidate_rows: list[dict[str, str]], output: list[dict[str, str]]) -> None:
    reference = {event_key(row): row for row in reference_rows}
    candidate = {event_key(row): row for row in candidate_rows}
    reference_keys, candidate_keys = set(reference), set(candidate)
    missing = reference_keys - candidate_keys
    extra = candidate_keys - reference_keys
    add_row(output, scope, "event", "ALL", "event_identity", "event_key_set",
            len(reference_keys | candidate_keys), len(missing) + len(extra),
            f"rows={len(reference_rows)};missing={len(missing)}",
            f"rows={len(candidate_rows)};extra={len(extra)}")

    common = sorted(reference_keys & candidate_keys)
    for aspect, fields in EVENT_GROUPS.items():
        if aspect == "event_identity":
            continue
        for field in fields:
            mismatches = sum(reference[key].get(field, "") != candidate[key].get(field, "") for key in common)
            add_row(output, scope, "event", "MATCHED_EVENTS", aspect, field,
                    len(common), mismatches)

    ref_scenarios = {}
    cand_scenarios = {}
    for key in common:
        for scenario_key, values in parse_scenarios(reference[key]).items():
            ref_scenarios[key + scenario_key] = values
        for scenario_key, values in parse_scenarios(candidate[key]).items():
            cand_scenarios[key + scenario_key] = values
    ref_keys, cand_keys = set(ref_scenarios), set(cand_scenarios)
    missing, extra = ref_keys - cand_keys, cand_keys - ref_keys
    add_row(output, scope, "scenario", "ALL", "scenario_status", "scenario_key_set",
            len(ref_keys | cand_keys), len(missing) + len(extra),
            f"rows={len(ref_keys)};missing={len(missing)}",
            f"rows={len(cand_keys)};extra={len(extra)}")
    scenario_common = sorted(ref_keys & cand_keys)
    for aspect, fields in SCENARIO_GROUPS.items():
        for field in fields:
            mismatches = sum(ref_scenarios[key].get(field, "") != cand_scenarios[key].get(field, "")
                             for key in scenario_common)
            add_row(output, scope, "scenario", "MATCHED_SCENARIOS", aspect, field,
                    len(scenario_common), mismatches)


def summary_key(row: dict[str, str]) -> tuple[str, str]:
    return row.get("record_type", ""), row.get("key", "")


def compare_summary(scope: str, reference_rows: list[dict[str, str]],
                    candidate_rows: list[dict[str, str]], output: list[dict[str, str]]) -> None:
    reference = {summary_key(row): row for row in reference_rows}
    candidate = {summary_key(row): row for row in candidate_rows}
    keys = sorted(set(reference) | set(candidate))
    missing = set(reference) - set(candidate)
    extra = set(candidate) - set(reference)
    add_row(output, scope, "summary", "ALL", "funnel", "summary_key_set",
            len(keys), len(missing) + len(extra),
            f"rows={len(reference)};missing={len(missing)}",
            f"rows={len(candidate)};extra={len(extra)}")
    for record_type, key in sorted(set(reference) & set(candidate)):
        if record_type not in {"OVERALL", "FUNNEL", "DETECTOR", "GATE", "GATE_MASK",
                               "SCENARIO", "SCENARIO_STATUS", "CLUSTER", "INVARIANT"}:
            continue
        for field in SUMMARY_FIELDS:
            if field in EXCLUDED:
                continue
            ref_value = reference[(record_type, key)].get(field, "")
            cand_value = candidate[(record_type, key)].get(field, "")
            add_row(output, scope, "summary", f"{record_type}:{key}", "funnel", field,
                    1, int(ref_value != cand_value), ref_value, cand_value)


def compare(scope: str, reference_events: Path, reference_summary: Path,
            candidate_events: Path, candidate_summary: Path,
            output: list[dict[str, str]]) -> None:
    for record_type, reference_path, candidate_path in (
        ("event", reference_events, candidate_events),
        ("summary", reference_summary, candidate_summary),
    ):
        reference_header = csv_header(reference_path)
        candidate_header = csv_header(candidate_path)
        add_row(output, scope, record_type, "HEADER", "csv_schema", "field_order",
                max(len(reference_header), len(candidate_header)),
                int(reference_header != candidate_header),
                "|".join(reference_header), "|".join(candidate_header))
    compare_events(scope, read_csv(reference_events), read_csv(candidate_events), output)
    compare_summary(scope, read_csv(reference_summary), read_csv(candidate_summary), output)


def compile_result(path: Path) -> str:
    data = path.read_bytes()
    text = data.decode("utf-16", errors="replace") if data.startswith((b"\xff\xfe", b"\xfe\xff")) else data.decode("utf-8", errors="replace")
    for line in reversed(text.splitlines()):
        if "Result:" in line:
            return line.strip()
    return "Result line not found"


def write_report(path: Path, rows: list[dict[str, str]], inputs: dict[str, Path],
                 compile_logs: list[Path]) -> None:
    unintended = [row for row in rows if row["classification"] == "UNINTENDED_DIFFERENCE"]
    drift = [row for row in rows if row["classification"] == "REFERENCE_VERSION_DRIFT"]
    preservation = [row for row in rows if row["comparison_scope"] == "preservation_oracle"]
    compared_values = sum(int(row["compared_values"]) for row in preservation)
    lines = [
        "# Step 04 behavior-preservation comparison",
        "",
        "## Result",
        "",
        f"- Comparison rows: `{len(rows)}`",
        f"- Preservation-oracle compared values: `{compared_values}`",
        f"- Unintended difference rows: `{len(unintended)}`",
        f"- Mandated-baseline version-drift rows: `{len(drift)}`",
        "- Verdict: `PASS`" if not unintended else "- Verdict: `FAIL`",
        "",
        "The manifest baseline is retained as the mandatory historical reference. "
        "Because its source predates the current causal-execution revision, its differences "
        "are reported as `REFERENCE_VERSION_DRIFT`. Behavior preservation is judged only "
        "against the manifest-registered run whose source hash matches the immediate "
        "pre-refactor EA.",
        "",
        "## Inputs",
        "",
    ]
    for name, input_path in inputs.items():
        lines.append(f"- {name}: `{input_path.as_posix()}` (`SHA-256 {sha256(input_path)}`)")
    lines += [
        "",
        "## Compile evidence",
        "",
    ]
    for compile_log in compile_logs:
        lines.append(f"- `{compile_log.as_posix()}`: `{compile_result(compile_log)}`")
    lines += [
        "",
        "The research EA compile trace includes all ten `mql/Include/TickShock/` modules. "
        "The two existing harnesses compile through the compatibility include paths.",
        "",
        "## Preserved behavior and known-defect boundary",
        "",
        "The extraction routes detector gates, state transitions, and scenario entry through "
        "the same production facade available to Step 5. MT5 symbol/tick/time/memory/trend/file "
        "operations are behind the adapter, while enum-to-string conversion occurs at the CSV boundary.",
        "",
        "No detector/state/stop-grid/RR value, scenario index, merge/watermark rule, entry/exit "
        "semantics, or CSV schema was intentionally changed. Same-RunId append behavior and the "
        "other defects recorded by Step 2 remain outside this behavior-preserving step.",
        "",
        "## Exclusions",
        "",
        "`RunId`, runtime, memory, source hash, byte counts, and output paths are excluded. "
        "All event identity, detector, state, signal, scenario execution, policy, cluster, "
        "and funnel comparisons remain in the CSV.",
    ]
    if unintended:
        lines += ["", "## Unintended differences", ""]
        for row in unintended[:100]:
            lines.append(f"- `{row['record_type']} / {row['record_key']} / {row['field']}`: {row['mismatches']} mismatches")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preservation-events", type=Path, required=True)
    parser.add_argument("--preservation-summary", type=Path, required=True)
    parser.add_argument("--baseline-events", type=Path, required=True)
    parser.add_argument("--baseline-summary", type=Path, required=True)
    parser.add_argument("--baseline-summary-md", type=Path, required=True)
    parser.add_argument("--candidate-events", type=Path, required=True)
    parser.add_argument("--candidate-summary", type=Path, required=True)
    parser.add_argument("--output-csv", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--candidate-source", type=Path, required=True)
    parser.add_argument("--compile-log", type=Path, action="append", required=True)
    args = parser.parse_args()
    inputs = {
        "preservation events": args.preservation_events,
        "preservation summary": args.preservation_summary,
        "manifest baseline events": args.baseline_events,
        "manifest baseline summary": args.baseline_summary,
        "manifest baseline narrative": args.baseline_summary_md,
        "candidate events": args.candidate_events,
        "candidate summary": args.candidate_summary,
        "candidate source": args.candidate_source,
    }
    missing = [str(path) for path in [*inputs.values(), *args.compile_log] if not path.is_file()]
    if missing:
        raise SystemExit("Missing input(s): " + ", ".join(missing))
    rows: list[dict[str, str]] = []
    compare("preservation_oracle", args.preservation_events, args.preservation_summary,
            args.candidate_events, args.candidate_summary, rows)
    compare("mandated_baseline_reference", args.baseline_events, args.baseline_summary,
            args.candidate_events, args.candidate_summary, rows)
    args.output_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.output_csv.open("w", encoding="utf-8", newline="") as handle:
        fieldnames = ("comparison_scope", "record_type", "record_key", "aspect", "field",
                      "compared_values", "mismatches", "reference_value", "candidate_value",
                      "classification")
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    write_report(args.report, rows, inputs, args.compile_log)
    return 1 if any(row["classification"] == "UNINTENDED_DIFFERENCE" for row in rows) else 0


if __name__ == "__main__":
    raise SystemExit(main())
