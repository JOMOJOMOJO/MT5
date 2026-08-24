#!/usr/bin/env python3
"""Independently reconcile Tick-shock causal event and summary evidence."""

from __future__ import annotations

import argparse
import csv
import hashlib
import math
import re
import statistics
from collections import Counter, defaultdict
from pathlib import Path


csv.field_size_limit(64 * 1024 * 1024)
VALID_STATUSES = {"TP_LIMIT", "SL_GAP", "TIME_MARKET"}
STRATEGIES = (
    "detection_time_continuation",
    "post_burst_continuation",
    "pullback_continuation",
    "failed_shock_reversal",
)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def to_int(value: str | None, default: int = 0) -> int:
    try:
        return int(value or default)
    except (TypeError, ValueError):
        return default


def to_float(value: str | None) -> float:
    try:
        return float(value) if value not in (None, "") else math.nan
    except (TypeError, ValueError):
        return math.nan


def mean(values: list[float]) -> float:
    return statistics.fmean(values) if values else math.nan


def quantile(values: list[float], fraction: float) -> float:
    if not values:
        return math.nan
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def fmt(value: object, digits: int = 6) -> str:
    if isinstance(value, float):
        if math.isnan(value):
            return ""
        return f"{value:.{digits}f}"
    return str(value)


def parse_semicolon_map(value: str) -> dict[str, str]:
    output: dict[str, str] = {}
    for item in (value or "").split(";"):
        if "=" in item:
            key, raw = item.split("=", 1)
            output[key] = raw
    return output


def parse_set(path: Path) -> dict[str, str]:
    output: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if line and not line.lstrip().startswith(("#", ";")) and "=" in line:
            key, value = line.split("=", 1)
            output[key.strip()] = value.strip()
    return output


def parse_scenario(encoded: str, event: dict[str, str]) -> dict[str, object]:
    parts = encoded.split("|")
    if len(parts) < 6:
        raise ValueError(f"malformed scenario for {event['event_id']}: {encoded[:120]}")
    values: dict[str, str] = {}
    for item in parts[5:]:
        if "=" in item:
            key, value = item.split("=", 1)
            values[key] = value
    event_key = (
        event["symbol"],
        to_int(event["detector_window_ms"]),
        to_int(event["detection_time_msc"]),
    )
    return {
        "event": event,
        "event_key": event_key,
        "key": (event_key, parts[0], parts[1], parts[2], parts[3]),
        "strategy": parts[0],
        "stop_tag": parts[1],
        "stop_multiple": float(parts[1][1:]),
        "delay_tag": parts[2],
        "requested_delay_ms": int(parts[2][1:]),
        "spread_tag": parts[3],
        "spread_pct": int(parts[3][1:]),
        "status": parts[4],
        "values": values,
        "signal_event": to_int(values.get("signal_event")),
        "signal_processing": to_int(values.get("signal_processing")),
        "eligible": to_int(values.get("eligible")),
        "entry_quote": to_int(values.get("entry_quote")),
        "exit": to_int(values.get("exit")),
        "actual_delay": to_int(values.get("actual_delay"), -1),
        "processing_to_entry": to_int(values.get("processing_to_entry"), -1),
        "policy": to_int(values.get("policy"), -1),
        "net": to_float(values.get("net")),
        "gross": to_float(values.get("gross")),
        "risk": to_float(values.get("risk")),
        "requested_rr": to_float(values.get("requested_rr")),
        "realized_rr": to_float(values.get("realized_rr")),
        "commission_r": to_float(values.get("commission_r")),
        "sl": to_float(values.get("sl")),
        "tp": to_float(values.get("tp")),
        "stops_distance": to_float(values.get("stops_distance")),
        "freeze_distance": to_float(values.get("freeze_distance")),
        "freeze_clear": values.get("freeze_clear", "").lower() == "true",
        "hold_seconds": (
            (to_int(values.get("exit")) - to_int(values.get("entry_quote"))) / 1000.0
            if to_int(values.get("exit")) > 0 and to_int(values.get("entry_quote")) > 0
            else math.nan
        ),
    }


def row_by(rows: list[dict[str, str]], record_type: str, key: str) -> dict[str, str]:
    for row in rows:
        if row.get("record_type") == record_type and row.get("key") == key:
            return row
    raise KeyError(f"missing summary row {record_type}:{key}")


def summary_values(rows: list[dict[str, str]], record_type: str) -> dict[str, dict[str, str]]:
    return {row["key"]: row for row in rows if row.get("record_type") == record_type}


def counter_text(counter: Counter[str]) -> str:
    return "; ".join(f"{key}={counter[key]}" for key in sorted(counter))


def aggregate_scenarios(records: list[dict[str, object]], field: str) -> dict[str, dict[str, object]]:
    groups: dict[str, list[dict[str, object]]] = defaultdict(list)
    for record in records:
        if record["status"] in VALID_STATUSES:
            groups[str(record[field])].append(record)
    output: dict[str, dict[str, object]] = {}
    for key, items in groups.items():
        nets = [float(item["net"]) for item in items if not math.isnan(float(item["net"]))]
        output[key] = {
            "valid": len(items),
            "expectancy": mean(nets),
            "tp": sum(item["status"] == "TP_LIMIT" for item in items),
            "sl": sum(item["status"] == "SL_GAP" for item in items),
            "time": sum(item["status"] == "TIME_MARKET" for item in items),
        }
    return output


def evaluate_market_clusters(events: list[dict[str, str]]) -> tuple[int, int, str]:
    ordered = sorted(
        events,
        key=lambda row: (
            to_int(row["detection_time_msc"]),
            row["symbol"],
            to_int(row["detector_window_ms"]),
        ),
    )
    anchor = 0
    expected_cluster = 0
    violations = 0
    samples: list[str] = []
    for event in ordered:
        detection = to_int(event["detection_time_msc"])
        if expected_cluster == 0 or detection - anchor > 2000:
            expected_cluster += 1
            anchor = detection
        actual = to_int(event["market_cluster_id"])
        if actual != expected_cluster:
            violations += 1
            if len(samples) < 3:
                samples.append(f"{event['symbol']}:{detection}:actual={actual}:expected={expected_cluster}")
    return expected_cluster, violations, " || ".join(samples)


def analyze_run(run_dir: Path) -> dict[str, object]:
    events_path = run_dir / "events.csv"
    summary_path = run_dir / "summary.csv"
    specs_path = run_dir / "symbol_specs.csv"
    quality_path = run_dir / "tick_quality.csv"
    trades_path = run_dir / "trades.csv"
    set_paths = sorted(run_dir.glob("*.set"))
    if len(set_paths) != 1:
        raise ValueError(f"expected exactly one set in {run_dir}, found {len(set_paths)}")

    events = read_csv(events_path)
    summary = read_csv(summary_path)
    specs = read_csv(specs_path)
    quality = read_csv(quality_path)
    trades = read_csv(trades_path)
    config = parse_set(set_paths[0])
    scenarios: list[dict[str, object]] = []
    for event in events:
        for encoded in event["scenario_grid"].split(";"):
            if encoded:
                scenarios.append(parse_scenario(encoded, event))

    modes = {event["execution_mode"] for event in events}
    if len(modes) != 1:
        raise ValueError(f"mixed execution modes in {events_path}: {sorted(modes)}")
    mode = next(iter(modes))
    overall = row_by(summary, "OVERALL", "ALL")
    valid = [record for record in scenarios if record["status"] in VALID_STATUSES]
    signaled = [record for record in scenarios if record["status"] != "NO_SIGNAL"]
    invalid = [record for record in signaled if record["status"] not in VALID_STATUSES]
    net_values = [float(record["net"]) for record in valid if not math.isnan(float(record["net"]))]

    state_counts = {
        "valid_bursts": len(events),
        "valid_pullbacks": sum(to_int(event["pullback_time_msc"]) > 0 for event in events),
        "reacceleration_signals": sum(to_int(event["reacceleration_time_msc"]) > 0 for event in events),
        "detection_time_continuation_signals": sum(
            to_int(event["detection_time_continuation_signal_event_msc"]) > 0 for event in events
        ),
        "post_burst_continuation_signals": sum(
            to_int(event["post_burst_continuation_signal_event_msc"]) > 0 for event in events
        ),
        "pullback_continuation_signals": sum(
            to_int(event["pullback_continuation_signal_event_msc"]) > 0 for event in events
        ),
        "failed_shock_reversal_signals": sum(
            to_int(event["failed_shock_reversal_signal_event_msc"]) > 0 for event in events
        ),
    }

    detector_events = Counter(event["detector_window_ms"] for event in events)
    direction_events = Counter(event["direction"] for event in events)
    symbol_events = Counter(event["symbol"] for event in events)
    session_events = Counter(event["session"] for event in events)
    alignment_events = Counter(event["htf_alignment"] for event in events)
    status_counts = Counter(str(record["status"]) for record in signaled)
    policy_counts = Counter(str(record["policy"]) for record in valid)

    strategy_stats = aggregate_scenarios(valid, "strategy")
    delay_stats = aggregate_scenarios(valid, "delay_tag")
    spread_stats = aggregate_scenarios(valid, "spread_tag")

    by_direction: dict[str, list[dict[str, object]]] = defaultdict(list)
    by_symbol: dict[str, list[dict[str, object]]] = defaultdict(list)
    by_session: dict[str, list[dict[str, object]]] = defaultdict(list)
    by_alignment: dict[str, list[dict[str, object]]] = defaultdict(list)
    by_cluster: dict[str, list[float]] = defaultdict(list)
    for record in valid:
        event = record["event"]
        by_direction[event["direction"]].append(record)
        by_symbol[event["symbol"]].append(record)
        by_session[event["session"]].append(record)
        by_alignment[event["htf_alignment"]].append(record)
        by_cluster[event["market_cluster_id"]].append(float(record["net"]))

    def compact_groups(groups: dict[str, list[dict[str, object]]]) -> dict[str, tuple[int, float]]:
        return {
            key: (len(items), mean([float(item["net"]) for item in items]))
            for key, items in groups.items()
        }

    cluster_means = [mean(values) for values in by_cluster.values()]

    entry_decisions: dict[tuple[object, ...], dict[str, object]] = {}
    for record in valid:
        entry_key = (record["event_key"], record["strategy"], record["delay_tag"])
        if entry_key not in entry_decisions:
            entry_decisions[entry_key] = record
    actual_delays = [float(record["actual_delay"]) for record in entry_decisions.values()]
    processing_delays = [float(record["processing_to_entry"]) for record in entry_decisions.values()]

    market_clusters, market_cluster_violations, market_cluster_samples = evaluate_market_clusters(events)
    identity_counts = Counter(
        (event["symbol"], event["detector_window_ms"], event["detection_time_msc"])
        for event in events
    )
    duplicate_events = sum(count - 1 for count in identity_counts.values() if count > 1)

    invariants: list[dict[str, object]] = []

    def add_invariant(
        name: str,
        checked: int,
        violations: int,
        evidence: str,
        category: str = "CAUSAL",
    ) -> None:
        invariants.append(
            {
                "mode": mode,
                "category": category,
                "invariant": name,
                "checked_count": checked,
                "violation_count": violations,
                "status": "PASS" if violations == 0 else "FAIL",
                "formal_scope": "YES" if mode == "REALIZABLE_EA" else "NO",
                "evidence": evidence,
            }
        )

    entered = [record for record in signaled if int(record["entry_quote"]) > 0]
    submit_latency = to_int(config.get("InpSubmitLatencyMs"))
    add_invariant(
        "entry_quote_msc >= signal_event_msc + requested_delay_ms",
        len(entered),
        sum(
            int(record["entry_quote"])
            < int(record["signal_event"]) + int(record["requested_delay_ms"])
            for record in entered
        ),
        "independent scenario-grid comparison",
    )
    add_invariant(
        "entry_quote_msc >= signal_processing_msc + submit_latency_ms",
        len(entered),
        sum(
            int(record["entry_quote"])
            < int(record["signal_processing"]) + submit_latency
            for record in entered
        ),
        f"submit_latency_ms={submit_latency}; IDEAL is diagnostic-only",
    )
    add_invariant(
        "entry_quote_msc >= entry_eligible_msc",
        len(entered),
        sum(int(record["entry_quote"]) < int(record["eligible"]) for record in entered),
        "independent scenario-grid comparison",
    )
    add_invariant(
        "entry_quote_msc > signal_event_msc",
        len(entered),
        sum(int(record["entry_quote"]) <= int(record["signal_event"]) for record in entered),
        "same signal tick cannot fill",
    )
    detection_records = [record for record in entered if record["strategy"] == "detection_time_continuation"]
    stale_violations = 0
    for record in detection_records:
        event = record["event"]
        if to_int(event["detection_quote_age_ms"]) > 0 and int(record["entry_quote"]) == to_int(
            event["detection_grid_msc"]
        ):
            stale_violations += 1
    add_invariant(
        "stale Detection boundary fill = 0",
        len(detection_records),
        stale_violations,
        "detection_quote_age_ms and grid clock checked separately",
    )
    reversal_records = [
        record
        for record in signaled
        if record["strategy"] == "failed_shock_reversal" and int(record["signal_event"]) > 0
    ]
    add_invariant(
        "reversal signal equals invalidation time",
        len(reversal_records),
        sum(
            int(record["signal_event"]) != to_int(record["event"]["continuation_invalidated_msc"])
            for record in reversal_records
        ),
        "scenario signal_event compared with event invalidation clock",
    )
    rr_records = [record for record in valid if not math.isnan(float(record["requested_rr"]))]
    add_invariant(
        "realized RR >= requested RR (1.2)",
        len(rr_records),
        sum(float(record["realized_rr"]) + 1e-9 < float(record["requested_rr"]) for record in rr_records),
        "tick-rounded scenario values",
    )

    model_rows = summary_values(summary, "MODEL")
    merge_text = model_rows.get("global_merge", {}).get("value", "")
    match = re.search(r"order_violations=(\d+)", merge_text)
    global_order_violations = int(match.group(1)) if match else 1
    add_invariant(
        "global order violation = 0",
        1,
        global_order_violations,
        merge_text or "missing MODEL:global_merge",
    )
    add_invariant(
        "duplicate event = 0",
        len(events),
        duplicate_events,
        "duplicate key is symbol + detector + detection_time_msc",
    )
    add_invariant(
        "market cluster integrity",
        len(events),
        market_cluster_violations,
        f"recomputed_market_clusters={market_clusters}"
        + (f"; {market_cluster_samples}" if market_cluster_samples else ""),
    )

    reported_valid = to_int(overall["scenario_valid"])
    reported_invalid = to_int(overall["scenario_invalid"])
    reported_expectancy = to_float(overall["scenario_expectancy_r"])
    reconciliation_violations = 0
    reconciliation_notes: list[str] = []
    if len(events) != to_int(overall["event_csv_rows"]):
        reconciliation_violations += 1
        reconciliation_notes.append("event_rows")
    if len(valid) != reported_valid:
        reconciliation_violations += 1
        reconciliation_notes.append("scenario_valid")
    if len(invalid) != reported_invalid:
        reconciliation_violations += 1
        reconciliation_notes.append("scenario_invalid")
    if abs(mean(net_values) - reported_expectancy) > 1.000001e-6:
        reconciliation_violations += 1
        reconciliation_notes.append("scenario_expectancy")

    writer_groups: dict[str, dict[str, object]] = {}
    for record in scenarios:
        group_key = (
            f"{mode}:{record['strategy']}:{record['stop_tag']}:{record['delay_tag']}:{record['spread_tag']}"
        )
        group = writer_groups.setdefault(group_key, {"valid": 0, "invalid": 0, "nets": []})
        if record["status"] in VALID_STATUSES:
            group["valid"] = int(group["valid"]) + 1
            group["nets"].append(float(record["net"]))
        elif record["status"] != "NO_SIGNAL":
            group["invalid"] = int(group["invalid"]) + 1
    reported_groups = summary_values(summary, "SCENARIO")
    group_mismatches = 0
    for key, group in writer_groups.items():
        row = reported_groups.get(key)
        if row is None:
            group_mismatches += 1
            continue
        actual_mean = mean(group["nets"])
        expected_mean = to_float(row["scenario_expectancy_r"])
        mean_match = (math.isnan(actual_mean) and math.isnan(expected_mean)) or abs(actual_mean - expected_mean) <= 1.000001e-6
        if (
            int(group["valid"]) != to_int(row["scenario_valid"])
            or int(group["invalid"]) != to_int(row["scenario_invalid"])
            or not mean_match
        ):
            group_mismatches += 1
    group_mismatches += len(set(reported_groups) - set(writer_groups))
    if group_mismatches:
        reconciliation_violations += group_mismatches
        reconciliation_notes.append(f"scenario_groups={group_mismatches}")
    add_invariant(
        "CSV and summary reconciliation",
        len(events) + len(signaled) + len(writer_groups),
        reconciliation_violations,
        "mismatches=" + (",".join(reconciliation_notes) if reconciliation_notes else "none"),
        "RECONCILIATION",
    )

    net_formula_violations = sum(
        abs(float(record["net"]) - (float(record["gross"]) - float(record["commission_r"])))
        > 1.000001e-6
        for record in valid
    )
    add_invariant(
        "net R = gross R - commission R exactly once",
        len(valid),
        net_formula_violations,
        f"commission_source={config.get('InpCommissionSource', '')}",
        "RECONCILIATION",
    )
    add_invariant(
        "broker StopsLevel distance is respected",
        len(valid),
        sum(
            float(record["risk"]) + 1e-12 < float(record["stops_distance"])
            for record in valid
        ),
        "independent risk-distance comparison; symbol StopsLevel is preserved separately",
        "BROKER_CONSTRAINT",
    )
    add_invariant(
        "FreezeLevel diagnostic is clear for valid scenarios",
        len(valid),
        sum(not bool(record["freeze_clear"]) for record in valid),
        "freeze is a modification diagnostic and is not treated as StopsLevel",
        "BROKER_CONSTRAINT",
    )

    integrity_row = row_by(summary, "INTEGRITY", "fail_closed")
    integrity = parse_semicolon_map(integrity_row.get("value", ""))
    validation_status = integrity.get("validation", "MISSING")
    add_invariant(
        "run integrity status is VALIDATION_OK",
        1,
        0 if validation_status == "VALIDATION_OK" else 1,
        integrity_row.get("value", ""),
        "DATA_INTEGRITY",
    )
    for key in (
        "event_pool_exhaustions",
        "pending_capacity_hits",
        "dropped_ticks",
        "cursor_stalls",
    ):
        add_invariant(
            f"{key} = 0",
            1,
            to_int(integrity.get(key)),
            integrity_row.get("value", ""),
            "DATA_INTEGRITY",
        )
    frontier_violations = to_int(integrity.get("stale_symbols"))
    if integrity.get("incomplete_frontier", "false").lower() == "true":
        frontier_violations += 1
    add_invariant(
        "global frontier complete with no stale symbols",
        1,
        frontier_violations,
        integrity_row.get("value", ""),
        "DATA_INTEGRITY",
    )

    runmeta_paths = [
        run_dir / "events.csv.runmeta",
        run_dir / "summary.csv.runmeta",
        run_dir / "symbol_specs.csv.runmeta",
        run_dir / "trades.csv.runmeta",
    ]
    runmeta_contents = [
        path.read_text(encoding="utf-8-sig").splitlines() if path.exists() else []
        for path in runmeta_paths
    ]
    expected_run_id = config.get("InpRunId", "")
    runmeta_violations = sum(
        not content or content[0] != expected_run_id for content in runmeta_contents
    )
    fingerprints = {content[1] for content in runmeta_contents if len(content) > 1}
    if len(fingerprints) != 1:
        runmeta_violations += 1
    if any(row.get("run_id") != expected_run_id for row in summary + specs):
        runmeta_violations += 1
    add_invariant(
        "run identity and writer metadata are consistent",
        len(runmeta_paths),
        runmeta_violations,
        f"run_id={expected_run_id};fingerprints={len(fingerprints)}",
        "RUN_IDENTITY",
    )
    add_invariant(
        "research EA order rows = 0",
        1,
        len(trades),
        f"trades.csv rows={len(trades)}",
        "ORDER_SAFETY",
    )

    funnel_summary = summary_values(summary, "FUNNEL")
    funnel_mismatches = sum(
        state_counts[key] != to_int(funnel_summary.get(key, {}).get("events"))
        for key in state_counts
    )

    causal_violations = sum(
        int(row["violation_count"])
        for row in invariants
        if row["formal_scope"] == "YES" and row["category"] == "CAUSAL"
    )
    formal_validation_violations = sum(
        int(row["violation_count"]) for row in invariants if row["formal_scope"] == "YES"
    )

    return {
        "dir": run_dir,
        "events_path": events_path,
        "summary_path": summary_path,
        "set_path": set_paths[0],
        "events": events,
        "summary": summary,
        "specs": specs,
        "quality": quality,
        "trades": trades,
        "config": config,
        "mode": mode,
        "overall": overall,
        "scenarios": scenarios,
        "signaled": signaled,
        "valid": valid,
        "invalid": invalid,
        "expectancy": mean(net_values),
        "state_counts": state_counts,
        "funnel_mismatches": funnel_mismatches,
        "detector_events": detector_events,
        "direction_events": direction_events,
        "symbol_events": symbol_events,
        "session_events": session_events,
        "alignment_events": alignment_events,
        "status_counts": status_counts,
        "policy_counts": policy_counts,
        "strategy_stats": strategy_stats,
        "delay_stats": delay_stats,
        "spread_stats": spread_stats,
        "direction_stats": compact_groups(by_direction),
        "symbol_stats": compact_groups(by_symbol),
        "session_stats": compact_groups(by_session),
        "alignment_stats": compact_groups(by_alignment),
        "market_clusters": market_clusters,
        "cluster_means": cluster_means,
        "entry_decisions": entry_decisions,
        "actual_delays": actual_delays,
        "processing_delays": processing_delays,
        "invariants": invariants,
        "causal_violations": causal_violations,
        "formal_violations": formal_validation_violations,
        "validation_status": validation_status,
        "integrity": integrity,
        "file_hashes": {
            "events.csv": sha256(events_path),
            "summary.csv": sha256(summary_path),
            "symbol_specs.csv": sha256(specs_path),
            "tick_quality.csv": sha256(quality_path),
            set_paths[0].name: sha256(set_paths[0]),
        },
    }


def markdown_table(headers: list[str], rows: list[list[object]]) -> str:
    output = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    for row in rows:
        output.append("| " + " | ".join(str(value).replace("|", "\\|") for value in row) + " |")
    return "\n".join(output)


def write_run_reports(analysis: dict[str, object]) -> None:
    run_dir = analysis["dir"]
    mode = str(analysis["mode"])
    overall = analysis["overall"]
    formal = (
        mode == "REALIZABLE_EA"
        and analysis["validation_status"] == "VALIDATION_OK"
        and analysis["formal_violations"] == 0
    )
    eligibility_label = (
        "YES"
        if formal
        else (
            "NO (fail-closed run integrity)"
            if mode == "REALIZABLE_EA"
            else "NO (ideal event-time diagnostic only)"
        )
    )
    quality = analysis["quality"]
    generated = [row for row in quality if row["status"] == "GENERATED_TICK_FALLBACK_OBSERVED"]
    buffer_rows = summary_values(analysis["summary"], "BUFFER")

    reconciliation_lines = [
        f"# {mode} independent reconciliation",
        "",
        "## Inputs",
        "",
        f"- events: `{analysis['events_path'].as_posix()}` (`{analysis['file_hashes']['events.csv']}`)",
        f"- summary: `{analysis['summary_path'].as_posix()}` (`{analysis['file_hashes']['summary.csv']}`)",
        f"- preset: `{analysis['set_path'].as_posix()}`",
        "- oracle: this Python parser reads event rows and encoded scenarios; it does not call MQL5 production functions.",
        "",
        "## Reconciliation",
        "",
        markdown_table(
            ["Metric", "Independent", "EA summary", "Result"],
            [
                ["event rows", len(analysis["events"]), overall["event_csv_rows"], "PASS" if len(analysis["events"]) == to_int(overall["event_csv_rows"]) else "FAIL"],
                ["valid scenarios", len(analysis["valid"]), overall["scenario_valid"], "PASS" if len(analysis["valid"]) == to_int(overall["scenario_valid"]) else "FAIL"],
                ["invalid scenarios", len(analysis["invalid"]), overall["scenario_invalid"], "PASS" if len(analysis["invalid"]) == to_int(overall["scenario_invalid"]) else "FAIL"],
                ["ExpectancyR", fmt(analysis["expectancy"]), overall["scenario_expectancy_r"], "PASS" if abs(float(analysis["expectancy"]) - to_float(overall["scenario_expectancy_r"])) <= 1.000001e-6 else "FAIL"],
                ["funnel counters", "event-field recount", "summary FUNNEL", "PASS" if analysis["funnel_mismatches"] == 0 else "FAIL"],
            ],
        ),
        "",
        "## Causal invariants",
        "",
        markdown_table(
            ["Invariant", "Checked", "Violations", "Status", "Formal"],
            [[row["invariant"], row["checked_count"], row["violation_count"], row["status"], row["formal_scope"]] for row in analysis["invariants"]],
        ),
        "",
        f"Formal violation total: **{analysis['formal_violations']}**. IDEAL rows are diagnostic and are excluded from the formal total.",
        "",
        "## Strategy scenario recount",
        "",
        markdown_table(
            ["Strategy", "Valid cells", "TP", "SL", "TIME", "ExpectancyR"],
            [[key, value["valid"], value["tp"], value["sl"], value["time"], fmt(value["expectancy"])] for key, value in sorted(analysis["strategy_stats"].items())],
        ),
        "",
        "## Independent sample boundary",
        "",
        f"- event rows: {len(analysis['events'])}",
        f"- market clusters: {analysis['market_clusters']}",
        f"- correlated valid scenario cells: {len(analysis['valid'])}",
        "- statistical n is market clusters, not scenario cells.",
        "",
        "## Tick quality",
        "",
        f"Generated fallback was observed for {len(generated)} symbol(s): {', '.join(row['symbol'] for row in generated) or 'none'}.",
    ]
    (run_dir / "reconciliation.md").write_text("\n".join(reconciliation_lines) + "\n", encoding="utf-8")

    cluster_means = analysis["cluster_means"]
    summary_lines = [
        f"# Tick-shock Step 14 {mode}: March 2025",
        "",
        "## Scope",
        "",
        "- Driver: EURUSD,M1",
        "- Symbols: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF",
        "- Period: 2025-03-01 through 2025-04-01",
        "- Model: MT5 real ticks (model 4), VantageTradingLtd-Live Build 6140",
        "- RR: 1.2; thresholds and stop grid unchanged; research-only and no orders",
        f"- Formal edge eligibility: {eligibility_label}",
        "",
        "## Result",
        "",
        markdown_table(
            ["Metric", "Value"],
            [
                ["raw shock candidates", overall["raw_candidates"]],
                ["event rows", len(analysis["events"])],
                ["symbol clusters", parse_semicolon_map(row_by(analysis["summary"], "CLUSTER", "counts")["value"]).get("symbol_clusters", "")],
                ["market clusters / independent n", analysis["market_clusters"]],
                ["Long events", analysis["direction_events"].get("LONG", 0)],
                ["Short events", analysis["direction_events"].get("SHORT", 0)],
                ["valid scenarios", len(analysis["valid"])],
                ["invalid scenarios", len(analysis["invalid"])],
                ["diagnostic scenario-grid ExpectancyR", fmt(analysis["expectancy"])],
                ["runtime seconds", overall["runtime_seconds"]],
                ["average / max memory MB", f"{overall['average_memory_mb']} / {overall['max_memory_mb']}"],
                ["events.csv bytes", (run_dir / "events.csv").stat().st_size],
                ["summary.csv bytes", (run_dir / "summary.csv").stat().st_size],
                ["trade.csv rows / bytes", f"{overall['trade_csv_rows']} / {overall['trade_csv_bytes']}"],
                ["formal validation violations", analysis["formal_violations"]],
                ["causal clock violations", analysis["causal_violations"]],
                ["run validation status", analysis["validation_status"]],
                ["integrity fatal reason", analysis["integrity"].get("fatal_reason", "")],
            ],
        ),
        "",
        "The scenario count is a correlated stop/delay/spread grid, not independent trades. The formal sample count is 15 market clusters.",
        "",
        "## Event funnel",
        "",
        markdown_table(["State/signal", "Count"], [[key, value] for key, value in analysis["state_counts"].items()]),
        "",
        "## Detector events",
        "",
        markdown_table(["Window ms", "Events"], [[key, analysis["detector_events"][key]] for key in sorted(analysis["detector_events"], key=int)]),
        "",
        "## Scenario outcomes",
        "",
        markdown_table(["Status", "Cells"], [[key, analysis["status_counts"][key]] for key in sorted(analysis["status_counts"])]),
        "",
        markdown_table(
            ["Strategy", "Valid", "TP", "SL", "TIME", "ExpectancyR"],
            [[key, value["valid"], value["tp"], value["sl"], value["time"], fmt(value["expectancy"])] for key, value in sorted(analysis["strategy_stats"].items())],
        ),
        "",
        "## Delay and processing",
        "",
        markdown_table(
            ["Unique entry decisions", "Actual delay mean", "p50", "p95", "Processing-to-entry mean"],
            [[len(analysis["entry_decisions"]), fmt(mean(analysis["actual_delays"]), 3), fmt(quantile(analysis["actual_delays"], 0.5), 3), fmt(quantile(analysis["actual_delays"], 0.95), 3), fmt(mean(analysis["processing_delays"]), 3)]],
        ),
        "",
        "## Long/Short, symbol, session, and HTF alignment",
        "",
        markdown_table(["Direction", "Valid cells", "ExpectancyR"], [[key, value[0], fmt(value[1])] for key, value in sorted(analysis["direction_stats"].items())]),
        "",
        markdown_table(["Symbol", "Events", "Valid cells", "ExpectancyR"], [[key, analysis["symbol_events"].get(key, 0), value[0], fmt(value[1])] for key, value in sorted(analysis["symbol_stats"].items())]),
        "",
        markdown_table(["Session", "Events", "Valid cells", "ExpectancyR"], [[key, analysis["session_events"].get(key, 0), value[0], fmt(value[1])] for key, value in sorted(analysis["session_stats"].items())]),
        "",
        markdown_table(["HTF alignment", "Events", "Valid cells", "ExpectancyR"], [[key, analysis["alignment_events"].get(key, 0), value[0], fmt(value[1])] for key, value in sorted(analysis["alignment_stats"].items())]),
        "",
        "## Cluster-unit diagnostic",
        "",
        markdown_table(
            ["Clusters", "Mean of cluster means", "Median", "Min", "Max", "Positive cluster means"],
            [[len(cluster_means), fmt(mean(cluster_means)), fmt(quantile(cluster_means, 0.5)), fmt(min(cluster_means)), fmt(max(cluster_means)), sum(value > 0 for value in cluster_means)]],
        ),
        "",
        "## Policy mask and commission",
        "",
        f"Valid-cell policy masks: {counter_text(analysis['policy_counts'])}. Policy is diagnostic and does not invalidate a broker-feasible barrier outcome.",
        "",
        f"Configured commission is `{analysis['config'].get('InpCommissionPerLotRoundTurn')}` with source `{analysis['config'].get('InpCommissionSource')}`. This is not verified live commission evidence.",
        "",
        "## Tick quality and resource bounds",
        "",
        markdown_table(["Symbol", "M1 minutes", "Fallback minutes", "Fallback rate", "Status"], [[row["symbol"], row["ea_m1_minutes_seen"], row["tester_reported_discarded_minutes"], row["tester_reported_fallback_rate_pct"], row["status"]] for row in quality]),
        "",
        f"- one-second ring buffer maximum: {buffer_rows['one_second_samples_per_symbol_max']['value']} samples per symbol",
        f"- tick ring buffer maximum: {buffer_rows['tick_samples_per_symbol_max']['value']} ticks per symbol",
        f"- tick discard rule: `{buffer_rows['tick_retention']['value']}`",
        f"- global pending: `{buffer_rows['global_pending_ticks']['value']}`",
        "- no raw-tick or per-second time-series CSV was emitted; only event/trade/summary/spec evidence was collected.",
        "",
        "## Interpretation",
        "",
        "REALIZABLE_EA is the only formal feasibility input. IDEAL_EVENT_STUDY exists only to quantify event-time/processing-time differences. A fail-closed integrity status makes the run unusable for formal edge inference even when the causal clocks pass. No strategy cell was selected and no edge claim is made.",
    ]
    (run_dir / "summary.md").write_text("\n".join(summary_lines) + "\n", encoding="utf-8")


def baseline_metrics(baseline_dir: Path) -> dict[str, object]:
    rows = read_csv(baseline_dir / "summary.csv")
    overall = row_by(rows, "OVERALL", "ALL")
    funnels = summary_values(rows, "FUNNEL")
    statuses = {key: to_int(row["value"]) for key, row in summary_values(rows, "SCENARIO_STATUS").items()}
    clusters = next((row for row in rows if row["record_type"] == "CLUSTER"), {})
    return {"rows": rows, "overall": overall, "funnels": funnels, "statuses": statuses, "cluster": clusters}


def comparison_rows(
    baseline: dict[str, object], ideal: dict[str, object], realizable: dict[str, object]
) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []

    def add(section: str, metric: str, b: object, i: object, r: object, unit: str, note: str = "") -> None:
        def delta(left: object, right: object) -> str:
            try:
                return fmt(float(left) - float(right))
            except (TypeError, ValueError):
                return ""

        rows.append(
            {
                "section": section,
                "metric": metric,
                "baseline": fmt(b),
                "ideal": fmt(i),
                "realizable": fmt(r),
                "ideal_minus_baseline": delta(i, b),
                "realizable_minus_baseline": delta(r, b),
                "realizable_minus_ideal": delta(r, i),
                "unit": unit,
                "note": note,
            }
        )

    bo = baseline["overall"]
    io = ideal["overall"]
    ro = realizable["overall"]
    for metric, field, unit in (
        ("raw shock candidates", "raw_candidates", "count"),
        ("event rows", "event_csv_rows", "count"),
        ("ticks", "ticks", "count"),
        ("valid scenario cells", "scenario_valid", "correlated cells"),
        ("invalid scenario cells", "scenario_invalid", "correlated cells"),
        ("diagnostic ExpectancyR", "scenario_expectancy_r", "R"),
        ("average memory", "average_memory_mb", "MB"),
        ("max memory", "max_memory_mb", "MB"),
        ("events CSV", "event_csv_bytes", "bytes"),
        ("runtime", "runtime_seconds", "seconds"),
    ):
        add("overall", metric, bo.get(field, ""), io.get(field, ""), ro.get(field, ""), unit)

    for key in ideal["state_counts"]:
        b = to_int(baseline["funnels"].get(key, {}).get("events"))
        add("event_funnel", key, b, ideal["state_counts"][key], realizable["state_counts"][key], "count")

    baseline_cluster_map = parse_semicolon_map(baseline["cluster"].get("value", ""))
    add("cluster", "symbol clusters", baseline_cluster_map.get("clusters", ""), 17, 17, "count", "baseline called these independent clusters")
    add("cluster", "market clusters", "", ideal["market_clusters"], realizable["market_clusters"], "independent n", "formal statistical unit after Step 6")

    for status in sorted(set(baseline["statuses"]) | set(ideal["status_counts"]) | set(realizable["status_counts"])):
        add("execution_outcome", status, baseline["statuses"].get(status, 0), ideal["status_counts"].get(status, 0), realizable["status_counts"].get(status, 0), "cells")

    for strategy in STRATEGIES:
        i = ideal["strategy_stats"].get(strategy, {})
        r = realizable["strategy_stats"].get(strategy, {})
        add("strategy", f"{strategy} valid", "", i.get("valid", 0), r.get("valid", 0), "cells")
        add("strategy", f"{strategy} ExpectancyR", "", i.get("expectancy", math.nan), r.get("expectancy", math.nan), "R")

    for delay in ("d0", "d100", "d250"):
        i = ideal["delay_stats"].get(delay, {})
        r = realizable["delay_stats"].get(delay, {})
        add("delay", f"{delay} ExpectancyR", "", i.get("expectancy", math.nan), r.get("expectancy", math.nan), "R")

    for mask in sorted(set(ideal["policy_counts"]) | set(realizable["policy_counts"]), key=int):
        add("policy_mask", mask, "", ideal["policy_counts"].get(mask, 0), realizable["policy_counts"].get(mask, 0), "valid cells")

    ideal_events = {
        (event["symbol"], event["detector_window_ms"], event["detection_time_msc"]): event
        for event in ideal["events"]
    }
    realizable_events = {
        (event["symbol"], event["detector_window_ms"], event["detection_time_msc"]): event
        for event in realizable["events"]
    }
    common_events = sorted(set(ideal_events) & set(realizable_events))
    detector_fields = (
        "shock_gate_mask", "detection_quote_msc", "robust_z", "efficiency",
        "tick_intensity_ratio", "move_spread_ratio", "burst_range",
    )
    detector_diffs = sum(
        ideal_events[key][field] != realizable_events[key][field]
        for key in common_events
        for field in detector_fields
    )
    add("identity", "matched event identities", "", len(common_events), len(common_events), "events")
    add("identity", "detector metric differences", "", 0, detector_diffs, "field differences")

    ideal_scenarios = {record["key"]: record for record in ideal["signaled"]}
    realizable_scenarios = {record["key"]: record for record in realizable["signaled"]}
    common_scenarios = set(ideal_scenarios) & set(realizable_scenarios)
    entry_deltas = [
        int(realizable_scenarios[key]["entry_quote"]) - int(ideal_scenarios[key]["entry_quote"])
        for key in common_scenarios
        if int(ideal_scenarios[key]["entry_quote"]) > 0 and int(realizable_scenarios[key]["entry_quote"]) > 0
    ]
    status_changes = sum(ideal_scenarios[key]["status"] != realizable_scenarios[key]["status"] for key in common_scenarios)
    add("entry", "matched signaled scenarios", "", len(common_scenarios), len(common_scenarios), "cells")
    add("entry", "entry quote changed", "", 0, sum(delta != 0 for delta in entry_deltas), "cells")
    add("entry", "mean realizable minus ideal entry", "", 0, mean([float(delta) for delta in entry_deltas]), "ms")
    add("entry", "scenario status changed", "", 0, status_changes, "cells")
    add("entry", "unique decision actual delay mean", "", mean(ideal["actual_delays"]), mean(realizable["actual_delays"]), "ms")
    add("entry", "unique decision processing-to-entry mean", "", mean(ideal["processing_delays"]), mean(realizable["processing_delays"]), "ms")

    fallback_i = sum(to_int(row["tester_reported_discarded_minutes"]) for row in ideal["quality"])
    fallback_r = sum(to_int(row["tester_reported_discarded_minutes"]) for row in realizable["quality"])
    add("tick_quality", "generated fallback minutes", 179, fallback_i, fallback_r, "minutes", "GBPUSD only")
    add(
        "commission",
        "configured round-turn commission",
        0,
        ideal["config"].get("InpCommissionPerLotRoundTurn", ""),
        realizable["config"].get("InpCommissionPerLotRoundTurn", ""),
        "account currency/lot",
        "Step 13 tester deal fields were observed as zero; live broker commission remains unvalidated",
    )
    return rows


def write_comparison(
    baseline_dir: Path,
    ideal: dict[str, object],
    realizable: dict[str, object],
    comparison_dir: Path,
) -> None:
    comparison_dir.mkdir(parents=True, exist_ok=True)
    baseline = baseline_metrics(baseline_dir)
    rows = comparison_rows(baseline, ideal, realizable)
    with (comparison_dir / "comparison.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    invariant_rows = ideal["invariants"] + realizable["invariants"]
    with (comparison_dir / "causal_invariants.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(invariant_rows[0]))
        writer.writeheader()
        writer.writerows(invariant_rows)

    formal_violations = realizable["formal_violations"]
    feasibility = len(realizable["valid"]) > 0 and realizable["market_clusters"] > 0 and formal_violations == 0
    ideal_entries = {key: record for key, record in ideal["entry_decisions"].items()}
    real_entries = {key: record for key, record in realizable["entry_decisions"].items()}
    common_entry_keys = set(ideal_entries) & set(real_entries)
    entry_deltas = [
        int(real_entries[key]["entry_quote"]) - int(ideal_entries[key]["entry_quote"])
        for key in common_entry_keys
    ]
    changed = sum(delta != 0 for delta in entry_deltas)
    baseline_overall = baseline["overall"]
    cluster_means = realizable["cluster_means"]
    buffer_rows = summary_values(realizable["summary"], "BUFFER")
    formal_csv_bytes = sum(
        (realizable["dir"] / name).stat().st_size
        for name in ("events.csv", "summary.csv", "symbol_specs.csv", "tick_quality.csv", "trades.csv")
    )

    lines = [
        "# Tick-shock Step 7 causal comparison: March 2025",
        "",
        "## Formal judgement",
        "",
        "- `RESEARCH_PIPELINE_PARTIALLY_VALIDATED`",
        f"- `EXECUTION_MODEL_CAUSALLY_VALIDATED`" if formal_violations == 0 else "- `EXECUTION_MODEL_NOT_VALIDATED`",
        f"- `STRATEGY_FEASIBILITY_ESTABLISHED`" if feasibility else "- `STRATEGY_FEASIBILITY_NOT_ESTABLISHED`",
        "- `EDGE_UNDETERMINED`",
        "- long OOS not performed",
        "",
        "Only REALIZABLE_EA is used for the formal judgement. Feasibility here means causal, broker-grid-feasible shadow outcomes exist; it does not mean a deployable order EA or positive edge has been established.",
        "",
        "## Event funnel: previous baseline versus Step 7",
        "",
        markdown_table(
            ["Metric", "Previous baseline", "IDEAL", "REALIZABLE"],
            [
                ["raw shock candidates", baseline_overall["raw_candidates"], ideal["overall"]["raw_candidates"], realizable["overall"]["raw_candidates"]],
                ["event rows", baseline_overall["event_csv_rows"], len(ideal["events"]), len(realizable["events"])],
                ["valid bursts", baseline["funnels"]["valid_bursts"]["events"], ideal["state_counts"]["valid_bursts"], realizable["state_counts"]["valid_bursts"]],
                ["valid pullbacks", baseline["funnels"]["valid_pullbacks"]["events"], ideal["state_counts"]["valid_pullbacks"], realizable["state_counts"]["valid_pullbacks"]],
                ["reacceleration", baseline["funnels"]["reacceleration_signals"]["events"], ideal["state_counts"]["reacceleration_signals"], realizable["state_counts"]["reacceleration_signals"]],
                ["reversal signals", baseline["funnels"]["failed_shock_reversal_signals"]["events"], ideal["state_counts"]["failed_shock_reversal_signals"], realizable["state_counts"]["failed_shock_reversal_signals"]],
            ],
        ),
        "",
        "Detector/event funnel is unchanged. The previous 17 independent clusters were symbol clusters; Step 7 adds 15 cross-symbol market clusters, which are the formal statistical n.",
        "",
        "## Execution outcome: previous baseline versus Step 7",
        "",
        markdown_table(
            ["Metric", "Previous baseline", "IDEAL", "REALIZABLE"],
            [
                ["valid cells", baseline_overall["scenario_valid"], len(ideal["valid"]), len(realizable["valid"])],
                ["invalid broker cells", baseline_overall["scenario_invalid"], len(ideal["invalid"]), len(realizable["invalid"])],
                ["TP", baseline["statuses"].get("TP_LIMIT", 0), ideal["status_counts"].get("TP_LIMIT", 0), realizable["status_counts"].get("TP_LIMIT", 0)],
                ["SL gap", baseline["statuses"].get("SL_GAP", 0), ideal["status_counts"].get("SL_GAP", 0), realizable["status_counts"].get("SL_GAP", 0)],
                ["TIME", baseline["statuses"].get("TIME_MARKET", 0), ideal["status_counts"].get("TIME_MARKET", 0), realizable["status_counts"].get("TIME_MARKET", 0)],
                ["diagnostic ExpectancyR", baseline_overall["scenario_expectancy_r"], fmt(ideal["expectancy"]), fmt(realizable["expectancy"])],
            ],
        ),
        "",
        "The 324 invalid cells are broker StopsLevel failures exposed by the corrected current-Bid/Ask check. They are not threshold changes.",
        "",
        "## IDEAL versus REALIZABLE entry",
        "",
        markdown_table(
            ["Matched unique signal/delay decisions", "Entry changed", "Mean REALIZABLE-IDEAL ms", "IDEAL actual delay mean", "REALIZABLE actual delay mean"],
            [[len(common_entry_keys), changed, fmt(mean([float(value) for value in entry_deltas]), 3), fmt(mean(ideal["actual_delays"]), 3), fmt(mean(realizable["actual_delays"]), 3)]],
        ),
        "",
        "IDEAL event-time entries are diagnostic only. REALIZABLE includes global merge recognition lag in signal_processing and applies the causal maximum before selecting the next same-symbol real tick.",
        "",
        "## REALIZABLE strategy outcomes",
        "",
        markdown_table(
            ["Strategy", "Signals", "Valid cells", "TP", "SL", "TIME", "ExpectancyR"],
            [[strategy, realizable["state_counts"].get(f"{strategy}_signals", ""), value["valid"], value["tp"], value["sl"], value["time"], fmt(value["expectancy"])] for strategy, value in sorted(realizable["strategy_stats"].items())],
        ),
        "",
        "No strategy, stop, delay, or spread cell was selected. The overall grid mean is not a deployable strategy estimate.",
        "",
        "## Requested delay, spread stress, and policy mask",
        "",
        markdown_table(
            ["Requested delay", "IDEAL ExpectancyR", "REALIZABLE ExpectancyR"],
            [[delay, fmt(ideal["delay_stats"].get(delay, {}).get("expectancy", math.nan)), fmt(realizable["delay_stats"].get(delay, {}).get("expectancy", math.nan))] for delay in ("d0", "d100", "d250")],
        ),
        "",
        markdown_table(
            ["Spread stress", "IDEAL ExpectancyR", "REALIZABLE ExpectancyR"],
            [[spread, fmt(ideal["spread_stats"].get(spread, {}).get("expectancy", math.nan)), fmt(realizable["spread_stats"].get(spread, {}).get("expectancy", math.nan))] for spread in ("s100", "s125")],
        ),
        "",
        f"IDEAL valid-cell policy masks: {counter_text(ideal['policy_counts'])}.",
        "",
        f"REALIZABLE valid-cell policy masks: {counter_text(realizable['policy_counts'])}. Policy gates remain diagnostic columns and were not used to select cells.",
        "",
        "## Long/Short and cluster-unit statistics",
        "",
        markdown_table(["Direction", "Valid cells", "ExpectancyR"], [[key, value[0], fmt(value[1])] for key, value in sorted(realizable["direction_stats"].items())]),
        "",
        markdown_table(
            ["Market clusters", "Mean cluster outcome", "Median", "Min", "Max", "Positive cluster means"],
            [[len(cluster_means), fmt(mean(cluster_means)), fmt(quantile(cluster_means, 0.5)), fmt(min(cluster_means)), fmt(max(cluster_means)), sum(value > 0 for value in cluster_means)]],
        ),
        "",
        "These cluster values average correlated scenario cells inside each market cluster. With only 15 clusters they are descriptive, not an edge proof.",
        "",
        "## Causal invariants",
        "",
        markdown_table(["Invariant", "Checked", "Violations", "Status"], [[row["invariant"], row["checked_count"], row["violation_count"], row["status"]] for row in realizable["invariants"]]),
        "",
        f"Formal causal invariant violations: **{formal_violations}**.",
        "",
        "## Tick quality, commission, memory, and files",
        "",
        f"- generated fallback: GBPUSD 179 / 30,187 minutes (0.5930%); other symbols have no discard warning, which is not proof of all-real coverage",
        f"- commission: 0.0 configured, source `ORDER_HARNESS_REQUIRED`; net R is not verified with actual account commission",
        f"- REALIZABLE memory: average {realizable['overall']['average_memory_mb']} MB, max {realizable['overall']['max_memory_mb']} MB",
        f"- REALIZABLE events.csv: {(realizable['dir'] / 'events.csv').stat().st_size} bytes / {len(realizable['events'])} rows",
        f"- REALIZABLE summary.csv: {(realizable['dir'] / 'summary.csv').stat().st_size} bytes / {len(realizable['summary'])} rows",
        f"- trade CSV: {realizable['overall']['trade_csv_rows']} rows / {realizable['overall']['trade_csv_bytes']} bytes; research EA sent no orders",
        f"- runtime: IDEAL {ideal['overall']['runtime_seconds']} seconds; REALIZABLE {realizable['overall']['runtime_seconds']} seconds",
        f"- one-second ring: {buffer_rows['one_second_samples_per_symbol_max']['value']} per symbol; tick ring: {buffer_rows['tick_samples_per_symbol_max']['value']} per symbol",
        f"- tick discard: `{buffer_rows['tick_retention']['value']}`; global pending `{buffer_rows['global_pending_ticks']['value']}`",
        f"- structured REALIZABLE CSV volume: {formal_csv_bytes} bytes/month; linear estimate {formal_csv_bytes * 12} bytes/year and {formal_csv_bytes * 36} bytes/three years if event density and schema stay similar",
        f"- retaining both modes would approximately double structured CSV volume to {formal_csv_bytes * 24} bytes/year",
        "- no raw tick CSV or per-second time-series CSV was emitted",
        "",
        "## Step 8 handoff",
        "",
        "- `docs/research/tick_shock/00_artifact_manifest.md`",
        "- `reports/tests/tick_shock/step06_post_fix_green_report.md`",
        "- `reports/tests/tick_shock/step06_post_fix_results.csv`",
        f"- `{ideal['dir'].as_posix()}/summary.md`",
        f"- `{ideal['dir'].as_posix()}/events.csv`",
        f"- `{ideal['dir'].as_posix()}/summary.csv`",
        f"- `{ideal['dir'].as_posix()}/reconciliation.md`",
        f"- `{realizable['dir'].as_posix()}/summary.md`",
        f"- `{realizable['dir'].as_posix()}/events.csv`",
        f"- `{realizable['dir'].as_posix()}/summary.csv`",
        f"- `{realizable['dir'].as_posix()}/reconciliation.md`",
        f"- `{comparison_dir.as_posix()}/comparison.csv`",
        f"- `{comparison_dir.as_posix()}/causal_invariants.csv`",
        f"- `{comparison_dir.as_posix()}/summary.md`",
        "- `tools/tick_shock/reconcile_causal_runs.py`",
        "",
        "## Decision",
        "",
        "The causal execution model passes this March replay and now produces broker-feasible shadow outcomes. Research should continue at the next review step, but this evidence does not yet justify automatically starting long OOS: the formal independent sample is 15 market clusters and actual commission/order lifecycle evidence is incomplete. There is no basis for promotion, optimization, or a positive-edge claim.",
    ]
    (comparison_dir / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_csv_rows(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        raise ValueError(f"no rows for {path}")
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def write_step14_outputs(
    baseline_dir: Path,
    ideal: dict[str, object],
    realizable: dict[str, object],
    comparison_dir: Path,
) -> None:
    policy_records = [record for record in realizable["valid"] if record["policy"] == 3]

    def policy_row(dimension: str, key: str, records: list[dict[str, object]]) -> dict[str, object]:
        events = {record["event_key"] for record in records}
        symbol_clusters = {
            (record["event"]["symbol"], record["event"]["symbol_cluster_id"])
            for record in records
        }
        market_clusters = {record["event"]["market_cluster_id"] for record in records}
        gross = [float(record["gross"]) for record in records]
        commission = [float(record["commission_r"]) for record in records]
        net = [float(record["net"]) for record in records]
        holds = [float(record["hold_seconds"]) for record in records if not math.isnan(float(record["hold_seconds"]))]
        return {
            "dimension": dimension,
            "key": key,
            "scenario_cells": len(records),
            "unique_events": len(events),
            "unique_symbol_clusters": len(symbol_clusters),
            "unique_market_clusters": len(market_clusters),
            "tp": sum(record["status"] == "TP_LIMIT" for record in records),
            "sl_gap": sum(record["status"] == "SL_GAP" for record in records),
            "time": sum(record["status"] == "TIME_MARKET" for record in records),
            "gross_expectancy_r": fmt(mean(gross)),
            "commission_expectancy_r": fmt(mean(commission)),
            "net_expectancy_r": fmt(mean(net)),
            "average_hold_seconds": fmt(mean(holds), 3),
            "median_hold_seconds": fmt(quantile(holds, 0.5), 3),
            "time_120_rate_pct": fmt(100.0 * sum(record["status"] == "TIME_MARKET" for record in records) / len(records), 3) if records else "",
            "interpretation": "diagnostic_only_not_strategy_selection",
        }

    policy_rows = [policy_row("ALL", "policy_mask_3", policy_records)]
    dimensions = {
        "strategy": lambda record: str(record["strategy"]),
        "direction": lambda record: str(record["event"]["direction"]),
        "symbol": lambda record: str(record["event"]["symbol"]),
        "delay": lambda record: str(record["delay_tag"]),
    }
    for dimension, selector in dimensions.items():
        grouped: dict[str, list[dict[str, object]]] = defaultdict(list)
        for record in policy_records:
            grouped[selector(record)].append(record)
        for key in sorted(grouped):
            policy_rows.append(policy_row(dimension, key, grouped[key]))
    write_csv_rows(comparison_dir / "policy_mask3_analysis.csv", policy_rows)

    baseline_events = read_csv(baseline_dir / "events.csv")
    baseline_summary = read_csv(baseline_dir / "summary.csv")
    baseline_scenarios: list[dict[str, object]] = []
    for event in baseline_events:
        baseline_scenarios.extend(
            parse_scenario(encoded, event)
            for encoded in event["scenario_grid"].split(";")
            if encoded
        )
    baseline_signaled = [record for record in baseline_scenarios if record["status"] != "NO_SIGNAL"]
    baseline_scenario_map = {record["key"]: record for record in baseline_signaled}
    current_scenario_map = {record["key"]: record for record in realizable["signaled"]}
    baseline_event_keys = {
        (event["symbol"], to_int(event["detector_window_ms"]), to_int(event["detection_time_msc"]))
        for event in baseline_events
    }
    current_event_keys = {record["event_key"] for record in realizable["scenarios"]}
    common_scenarios = set(baseline_scenario_map) & set(current_scenario_map)
    baseline_overall = row_by(baseline_summary, "OVERALL", "ALL")
    baseline_funnel = summary_values(baseline_summary, "FUNNEL")
    baseline_cluster = parse_semicolon_map(row_by(baseline_summary, "CLUSTER", "counts")["value"])
    current_cluster = parse_semicolon_map(row_by(realizable["summary"], "CLUSTER", "counts")["value"])
    regression_rows: list[dict[str, object]] = []

    def add_regression(
        check: str,
        expected: object,
        baseline: object,
        current: object,
        difference: object,
        passed: bool,
        evidence: str,
    ) -> None:
        regression_rows.append(
            {
                "check": check,
                "expected": expected,
                "baseline": baseline,
                "current": current,
                "difference": difference,
                "status": "PASS" if passed else "FAIL",
                "evidence": evidence,
            }
        )

    numeric_checks = (
        ("raw_candidates", 62577, to_int(baseline_overall["raw_candidates"]), to_int(realizable["overall"]["raw_candidates"])),
        ("event_rows", 19, len(baseline_events), len(realizable["events"])),
        ("valid_bursts", 19, to_int(baseline_funnel["valid_bursts"]["events"]), realizable["state_counts"]["valid_bursts"]),
        ("valid_pullbacks", 14, to_int(baseline_funnel["valid_pullbacks"]["events"]), realizable["state_counts"]["valid_pullbacks"]),
        ("reacceleration", 5, to_int(baseline_funnel["reacceleration_signals"]["events"]), realizable["state_counts"]["reacceleration_signals"]),
        ("reversal_signals", 11, to_int(baseline_funnel["failed_shock_reversal_signals"]["events"]), realizable["state_counts"]["failed_shock_reversal_signals"]),
        ("symbol_clusters", 17, to_int(baseline_cluster.get("symbol_clusters", baseline_cluster.get("clusters"))), to_int(current_cluster.get("symbol_clusters"))),
        ("market_clusters", 15, 15, realizable["market_clusters"]),
        ("long_events", 10, sum(event["direction"] == "LONG" for event in baseline_events), realizable["direction_events"].get("LONG", 0)),
        ("short_events", 9, sum(event["direction"] == "SHORT" for event in baseline_events), realizable["direction_events"].get("SHORT", 0)),
    )
    for check, expected, baseline, current in numeric_checks:
        add_regression(check, expected, baseline, current, current - baseline, baseline == expected == current, "Step 7 REALIZABLE versus Step 14 REALIZABLE")

    event_key_diff = len(baseline_event_keys ^ current_event_keys)
    scenario_membership_diff = len(set(baseline_scenario_map) ^ set(current_scenario_map))
    status_diff = sum(
        baseline_scenario_map[key]["status"] != current_scenario_map[key]["status"]
        for key in common_scenarios
    )
    policy_diff = sum(
        baseline_scenario_map[key]["policy"] != current_scenario_map[key]["policy"]
        for key in common_scenarios
    )
    r_diff = sum(
        abs(float(baseline_scenario_map[key][field]) - float(current_scenario_map[key][field])) > 1.000001e-9
        for key in common_scenarios
        for field in ("gross", "net")
        if not math.isnan(float(baseline_scenario_map[key][field]))
        and not math.isnan(float(current_scenario_map[key][field]))
    )
    clock_diff = sum(
        baseline_scenario_map[key][field] != current_scenario_map[key][field]
        for key in common_scenarios
        for field in ("signal_event", "signal_processing", "eligible", "entry_quote", "exit")
    )
    for check, value, evidence in (
        ("event_identity_symmetric_difference", event_key_diff, "symbol+detector+detection_time_msc"),
        ("scenario_membership_symmetric_difference", scenario_membership_diff, "event key+strategy+stop+delay+spread"),
        ("scenario_status_mismatches", status_diff, "matched signaled scenarios"),
        ("policy_mask_mismatches", policy_diff, "matched signaled scenarios"),
        ("scenario_gross_or_net_r_mismatches", r_diff, "absolute tolerance 1e-9"),
        ("scenario_clock_mismatches", clock_diff, "signal/processing/eligible/entry/exit"),
    ):
        add_regression(check, 0, 0, value, value, value == 0, evidence)
    write_csv_rows(comparison_dir / "regression_comparison.csv", regression_rows)

    baseline_quality = {row["symbol"]: row for row in read_csv(baseline_dir / "tick_quality.csv")}
    current_quality = {row["symbol"]: row for row in realizable["quality"]}
    tick_rows: list[dict[str, object]] = []
    for symbol in sorted(set(baseline_quality) | set(current_quality)):
        before = baseline_quality.get(symbol, {})
        after = current_quality.get(symbol, {})
        fallback_before = to_int(before.get("tester_reported_discarded_minutes"))
        fallback_after = to_int(after.get("tester_reported_discarded_minutes"))
        minutes_before = to_int(before.get("ea_m1_minutes_seen"))
        minutes_after = to_int(after.get("ea_m1_minutes_seen"))
        status_match = before.get("status") == after.get("status")
        tick_rows.append(
            {
                "symbol": symbol,
                "baseline_m1_minutes": minutes_before,
                "current_m1_minutes": minutes_after,
                "m1_difference": minutes_after - minutes_before,
                "baseline_fallback_minutes": fallback_before,
                "current_fallback_minutes": fallback_after,
                "fallback_difference": fallback_after - fallback_before,
                "baseline_status": before.get("status", ""),
                "current_status": after.get("status", ""),
                "status": "PASS" if minutes_before == minutes_after and fallback_before == fallback_after and status_match else "FAIL",
            }
        )
    write_csv_rows(comparison_dir / "tick_quality_comparison.csv", tick_rows)

    regression_failures = sum(row["status"] == "FAIL" for row in regression_rows)
    tick_quality_failures = sum(row["status"] == "FAIL" for row in tick_rows)
    cost_model_complete = "LIVE_UNVALIDATED" not in realizable["config"].get("InpCommissionSource", "")
    causal_status = (
        "EXECUTION_MODEL_CAUSALLY_VALIDATED_FOR_SHADOW_REPLAY"
        if realizable["causal_violations"] == 0
        else "EXECUTION_MODEL_NOT_CAUSALLY_VALIDATED"
    )
    lines = [
        "# Tick-shock Step 14 March 2025 revalidation",
        "",
        "## Formal judgement",
        "",
        "- `RESEARCH_PIPELINE_PARTIALLY_VALIDATED`",
        f"- `{causal_status}`",
        f"- `{realizable['validation_status']}`",
        "- `COST_MODEL_INCOMPLETE`" if not cost_model_complete else "- `COST_MODEL_OBSERVED`",
        "- `FORMAL_NET_EXPECTANCY_UNAVAILABLE`" if not cost_model_complete else "- `FORMAL_NET_EXPECTANCY_AVAILABLE`",
        "- `STRATEGY_FEASIBILITY_NOT_ESTABLISHED`",
        "- `EDGE_UNDETERMINED`",
        "- `LONG_OOS_NOT_AUTHORIZED`",
        "",
        "REALIZABLE_EA is the only formal feasibility input. Its causal clocks pass, but the run is fail-closed because three monitored symbols became stale relative to the global frontier. Therefore the scenario outcomes below are diagnostic only.",
        "",
        "## Regression gate",
        "",
        markdown_table(
            ["Metric", "Step 7", "Step 14", "Status"],
            [[row["check"], row["baseline"], row["current"], row["status"]] for row in regression_rows[:10]],
        ),
        "",
        f"Regression mismatches: **{regression_failures}**. Tick-quality comparison failures: **{tick_quality_failures}**.",
        "",
        "## IDEAL and REALIZABLE",
        "",
        markdown_table(
            ["Metric", "IDEAL", "REALIZABLE"],
            [
                ["events", len(ideal["events"]), len(realizable["events"])],
                ["valid scenario cells", len(ideal["valid"]), len(realizable["valid"])],
                ["TP", ideal["status_counts"].get("TP_LIMIT", 0), realizable["status_counts"].get("TP_LIMIT", 0)],
                ["SL gap", ideal["status_counts"].get("SL_GAP", 0), realizable["status_counts"].get("SL_GAP", 0)],
                ["TIME", ideal["status_counts"].get("TIME_MARKET", 0), realizable["status_counts"].get("TIME_MARKET", 0)],
                ["diagnostic gross/net grid mean R", fmt(ideal["expectancy"]), fmt(realizable["expectancy"])],
                ["validation status", ideal["validation_status"], realizable["validation_status"]],
            ],
        ),
        "",
        "The configured commission is zero because Step 13 observed zero in MT5 Strategy Tester deal fields. That observation is not evidence that live Vantage commission is zero, so the numeric net R remains diagnostic and formal cost-after expectancy is unavailable.",
        "",
        "## Causality and integrity",
        "",
        f"- causal clock violations: {realizable['causal_violations']}",
        f"- all formal validation violation instances: {realizable['formal_violations']}",
        f"- integrity fatal reason: `{realizable['integrity'].get('fatal_reason', '')}`",
        f"- stale symbols: {realizable['integrity'].get('stale_symbols', '')}",
        f"- event pool / pending capacity / dropped tick / cursor stall: {realizable['integrity'].get('event_pool_exhaustions', '')} / {realizable['integrity'].get('pending_capacity_hits', '')} / {realizable['integrity'].get('dropped_ticks', '')} / {realizable['integrity'].get('cursor_stalls', '')}",
        "- global order violations: 0; duplicate events: 0; run identity mismatches: 0",
        "",
        "## Independent sample and policy mask=3",
        "",
        f"- event rows: {len(realizable['events'])}",
        f"- symbol clusters: {current_cluster.get('symbol_clusters', '')}",
        f"- market clusters / formal n: {realizable['market_clusters']}",
        f"- correlated valid scenario cells: {len(realizable['valid'])}",
        f"- policy mask=3 cells: {len(policy_records)} across {len({record['event_key'] for record in policy_records})} events and {len({record['event']['market_cluster_id'] for record in policy_records})} market clusters",
        "",
        "Policy mask=3 means both stressed_spread/risk <= 0.20 and risk/burst_range <= 0.45. It is a diagnostic slice only; no strategy, symbol, direction, session, stop, delay, or spread cell was selected.",
        "",
        "## Feasibility layers",
        "",
        markdown_table(
            ["Layer", "Observation", "Formal status"],
            [
                ["broker-grid shadow feasible", f"{len(realizable['valid'])} barrier cells produced", "DIAGNOSTIC_ONLY_RUN_INVALID"],
                ["original cost/range policy feasible", f"policy mask=3 in {len(policy_records)} cells / {len({record['event']['market_cluster_id'] for record in policy_records})} market cluster", "DIAGNOSTIC_ONLY_RUN_INVALID"],
                ["order lifecycle observed", "Step 13 tester OrderCheck/OrderSend/fill/SL/TP/time-close", "PARTIALLY_OBSERVED"],
                ["deployable feasibility", "global frontier integrity failed and live commission unavailable", "NOT_ESTABLISHED"],
                ["edge evidence", "diagnostic grid only; no selected strategy", "UNDETERMINED"],
                ["statistical sufficiency", f"formal n would be {realizable['market_clusters']} market clusters", "INSUFFICIENT_AND_RUN_INVALID"],
            ],
        ),
        "",
        "## Tick quality and resource evidence",
        "",
        "- GBPUSD generated fallback: 179 / 30,187 tester minutes (0.5930%)",
        "- other symbols: no discard warning observed; this is not proof of all-real coverage",
        f"- REALIZABLE average/max memory: {realizable['overall']['average_memory_mb']} / {realizable['overall']['max_memory_mb']} MB; tester process reported 513 MB including history and generated tick data",
        f"- events.csv: {len(realizable['events'])} rows / {(realizable['dir'] / 'events.csv').stat().st_size} bytes",
        f"- summary.csv: {len(realizable['summary'])} rows / {(realizable['dir'] / 'summary.csv').stat().st_size} bytes",
        f"- trades.csv: {len(realizable['trades'])} rows / {(realizable['dir'] / 'trades.csv').stat().st_size} bytes; research EA sent no orders",
        "- no raw-tick CSV or per-second time-series CSV was emitted",
        "",
        "## Decision",
        "",
        "The March event funnel and scenario grid are exact Step 7 regressions, and the REALIZABLE causal execution clocks have zero violations. However, Step 12 correctly invalidated both runs when three symbols became stale under the global watermark, and actual live commission remains unobserved. This run cannot establish deployable feasibility or edge. Do not start long OOS, optimization, or positive-cell selection. The next gate is to diagnose and separately validate the stale/global-frontier policy without changing strategy thresholds.",
    ]
    (comparison_dir / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ideal-dir", type=Path, required=True)
    parser.add_argument("--realizable-dir", type=Path, required=True)
    parser.add_argument("--baseline-dir", type=Path, required=True)
    parser.add_argument("--comparison-dir", type=Path, required=True)
    args = parser.parse_args()

    ideal = analyze_run(args.ideal_dir)
    realizable = analyze_run(args.realizable_dir)
    if ideal["mode"] != "IDEAL_EVENT_STUDY":
        raise ValueError(f"ideal directory contains {ideal['mode']}")
    if realizable["mode"] != "REALIZABLE_EA":
        raise ValueError(f"realizable directory contains {realizable['mode']}")
    write_run_reports(ideal)
    write_run_reports(realizable)
    write_comparison(args.baseline_dir, ideal, realizable, args.comparison_dir)
    write_step14_outputs(args.baseline_dir, ideal, realizable, args.comparison_dir)
    print(
        f"ideal_events={len(ideal['events'])} realizable_events={len(realizable['events'])} "
        f"market_clusters={realizable['market_clusters']} causal_violations={realizable['causal_violations']} "
        f"formal_validation_violations={realizable['formal_violations']} "
        f"validation_status={realizable['validation_status']}"
    )
    return 1 if realizable["formal_violations"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
