"""Select actual v1.80 events for draw-only review; never synthesize signals.

Usage: python prepare_review.py --run <native run> [--run <run>] --out <dir>
Each available direction gets one connected cancellation and one extended TP.
Missing categories remain explicit shortfalls rather than fabricated examples.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path


def read_rows(path: Path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream, delimiter=";")
        return list(reader.fieldnames or []), list(reader)


def truth(value: str) -> bool:
    return value.lower() in {"1", "true"}


def prepare(runs: list[Path], out: Path):
    keys: list[str] = []
    source_runs = []
    for run in runs:
        path = run / "events.csv"
        columns, rows = read_rows(path)
        keys.extend(key for key in columns if key not in keys)
        source_runs.append((run, rows, hashlib.sha256(path.read_bytes()).hexdigest()))
    cases = []
    fixtures = []
    missing = []
    for category in ("CONNECTED_CANCEL", "EXTENDED_TP"):
        for direction in ("LONG", "SHORT"):
            selected = None
            for run, rows, digest in source_runs:
                for row_index, row in enumerate(rows):
                    if row.get("direction") != direction:
                        continue
                    if category == "CONNECTED_CANCEL":
                        match = row.get("event_type") == "INVALIDATE" and row.get("reason") == "CONNECTED_OPPOSITE_W1_CANDIDATE"
                    else:
                        match = row.get("event_type") in {"FILL", "SIGNAL"} and truth(row.get("tp_extended_to_wave1", ""))
                    if match:
                        selected = (run, rows, digest, row_index, row)
                        break
                if selected:
                    break
            if not selected:
                missing.append(f"{category}_{direction}")
                continue
            run, rows, digest, cutoff_index, row = selected
            index = len(cases)
            cutoff = row["event_at"]
            setup_id = row["setup_id"]
            source_id = row.get("connected_opposite_setup_id", "") if category == "CONNECTED_CANCEL" else ""
            include_ids = {setup_id, source_id} - {""}
            start = row.get("wave1_start_time", "")
            selected_rows = []
            for event_index, event in enumerate(rows):
                if event_index > cutoff_index or event.get("event_at", "") > cutoff:
                    continue
                related = event.get("setup_id") in include_ids
                pivot = bool(event.get("observed_pivot_time")) and start <= event.get("observed_pivot_time", "")
                if not related and not pivot:
                    continue
                fixture = {"review_index": str(index), "review_id": setup_id, "review_cutoff": cutoff, **event}
                selected_rows.append(fixture)
            fixtures.extend(selected_rows)
            cases.append({
                "review_index": index, "category": category, "direction": direction,
                "setup_id": setup_id, "source_setup_id": source_id, "cutoff": cutoff,
                "upper_tf": row.get("upper_tf"), "lower_tf": row.get("lower_tf"),
                "source_run": str(run), "source_events_sha256": digest,
                "event_count": len(selected_rows), "expected": row,
                "source_target_csv_row": cutoff_index + 2,
            })
    out.mkdir(parents=True, exist_ok=True)
    # MQL's CSV reader preserves an ANSI UTF-8 BOM as part of the first key.
    # Use the same BOM-free encoding as the established review fixtures.
    with (out / "fixture.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=["review_index", "review_id", "review_cutoff", *keys], delimiter=";")
        writer.writeheader()
        writer.writerows(fixtures)
    manifest = {"kind": "RECORDED_NATIVE_EVENTS_ONLY", "signal_recalculation": False,
                "requested_categories": 4, "observed_cases": len(cases), "shortfall": missing,
                "cases": cases}
    (out / "fixture_cases.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"observed_cases": len(cases), "shortfall": missing, "out": str(out)}, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="append", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    prepare(args.run, args.out)
