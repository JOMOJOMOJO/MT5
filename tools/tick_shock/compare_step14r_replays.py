#!/usr/bin/env python3
"""Compare two completed replays while excluding run identity and resource metadata."""

from __future__ import annotations

import argparse
import csv
import os
import tempfile
from pathlib import Path

csv.field_size_limit(64 * 1024 * 1024)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def atomic_csv(path: Path, rows: list[dict[str, object]]) -> None:
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
            writer.writeheader(); writer.writerows(rows); handle.flush(); os.fsync(handle.fileno())
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", required=True, type=Path)
    parser.add_argument("--current", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    old_events = {(row["symbol"], row["detector_window_ms"], row["detection_time_msc"]): row for row in read_csv(args.baseline / "events.csv")}
    new_events = {(row["symbol"], row["detector_window_ms"], row["detection_time_msc"]): row for row in read_csv(args.current / "events.csv")}
    event_fields = [field for field in next(iter(old_events.values())) if field not in {"run_id", "event_id"}]
    event_field_mismatches = sum(
        old_events[key].get(field, "") != new_events[key].get(field, "")
        for key in set(old_events) & set(new_events)
        for field in event_fields
    )
    old_summary = {(row["record_type"], row["key"]): row for row in read_csv(args.baseline / "summary.csv")}
    new_summary = {(row["record_type"], row["key"]): row for row in read_csv(args.current / "summary.csv")}
    excluded_summary_fields = {"run_id", "runtime_seconds", "average_memory_mb", "max_memory_mb", "event_csv_bytes", "trade_csv_bytes"}
    summary_fields = [field for field in next(iter(old_summary.values())) if field not in excluded_summary_fields]
    common_summary = (set(old_summary) & set(new_summary)) - {("MODEL", "provenance")}
    summary_field_mismatches = sum(
        old_summary[key].get(field, "") != new_summary[key].get(field, "")
        for key in common_summary
        for field in summary_fields
    )
    rows = [
        {"check": "event_identity_symmetric_difference", "baseline": len(old_events), "current": len(new_events), "mismatches": len(set(old_events) ^ set(new_events)), "status": "PASS" if set(old_events) == set(new_events) else "FAIL"},
        {"check": "event_domain_field_mismatches", "baseline": len(old_events), "current": len(new_events), "mismatches": event_field_mismatches, "status": "PASS" if event_field_mismatches == 0 else "FAIL"},
        {"check": "summary_identity_symmetric_difference", "baseline": len(old_summary), "current": len(new_summary), "mismatches": len(set(old_summary) ^ set(new_summary)), "status": "PASS" if set(old_summary) == set(new_summary) else "FAIL"},
        {"check": "summary_domain_field_mismatches", "baseline": len(common_summary), "current": len(common_summary), "mismatches": summary_field_mismatches, "status": "PASS" if summary_field_mismatches == 0 else "FAIL"},
    ]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    atomic_csv(args.output, rows)
    return 1 if any(row["status"] == "FAIL" for row in rows) else 0


if __name__ == "__main__":
    raise SystemExit(main())
