#!/usr/bin/env python3
"""Validate Step 15C March output against the frozen Step 15B replay."""
from __future__ import annotations

import argparse
import csv
from collections import Counter
from pathlib import Path

import pandas as pd


IGNORED = {"run_id", "feature_schema", "event_id"}


def compare_frame(old_path: Path, new_path: Path, keys: list[str]) -> dict[str, object]:
    old = pd.read_csv(old_path, dtype=str, keep_default_na=False)
    new = pd.read_csv(new_path, dtype=str, keep_default_na=False)
    common = sorted((set(old.columns) & set(new.columns)) - IGNORED)
    key = [column for column in keys if column in common]
    old_map = {tuple(row[column] for column in key): tuple(row[column] for column in common)
               for _, row in old.iterrows()}
    new_map = {tuple(row[column] for column in key): tuple(row[column] for column in common)
               for _, row in new.iterrows()}
    missing = len(set(old_map) - set(new_map))
    added = len(set(new_map) - set(old_map))
    changed = sum(old_map[k] != new_map[k] for k in set(old_map) & set(new_map))
    return {"artifact": old_path.name, "baseline_rows": len(old), "current_rows": len(new),
            "missing": missing, "added": added, "changed": changed,
            "mismatches": missing + added + changed,
            "status": "PASS" if missing + added + changed == 0 else "FAIL"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--current", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    rows = [
        compare_frame(args.baseline / "detector_features.csv", args.current / "detector_features.csv",
                      ["symbol", "detector_version", "candidate_time_msc", "confirmed_time_msc", "trigger_horizon_ms"]),
        compare_frame(args.baseline / "strategy_funnel.csv", args.current / "strategy_funnel.csv",
                      ["symbol", "detector_version", "candidate_msc", "confirmed_msc", "trigger_horizon_ms"]),
    ]
    response = pd.read_csv(args.current / "event_response.csv", low_memory=False)
    features = pd.read_csv(args.current / "detector_features.csv", low_memory=False)
    funnel = pd.read_csv(args.current / "strategy_funnel.csv", low_memory=False)
    rows.extend([
        {"artifact": "event_response.csv", "baseline_rows": 21799, "current_rows": len(response),
         "missing": 0, "added": 0, "changed": 0,
         "mismatches": abs(len(response) - 21799), "status": "PASS" if len(response) == 21799 else "FAIL"},
        {"artifact": "market_clusters", "baseline_rows": 10245,
         "current_rows": features.market_cluster_id.nunique(), "missing": 0, "added": 0, "changed": 0,
         "mismatches": abs(features.market_cluster_id.nunique() - 10245),
         "status": "PASS" if features.market_cluster_id.nunique() == 10245 else "FAIL"},
    ])
    horizon_status = Counter()
    horizon_violations = 0
    for horizon in (250, 500, 1000, 2000, 3000, 5000, 10000, 15000, 30000, 60000, 120000):
        status = response[f"h{horizon}_status"].fillna("").astype(str)
        horizon_status.update(status)
        valid = status.eq("VALID")
        horizon_violations += int((valid & (response[f"h{horizon}_quote_msc"] < response[f"h{horizon}_boundary_msc"])).sum())
    invalid = int((response.validation_status != "VALID").sum())
    drops = int(response.drops.fillna(0).sum())
    duplicate_events = int(response.event_id.duplicated().sum())
    expected_reach = {
        "detection_continuation_reachable": 10245,
        "post_burst_continuation_reachable": 10245,
        "pullback_continuation_reachable": 1033,
        "failed_shock_reversal_reachable": 7282,
    }
    expected_entries = {"post_burst_entry_msc": 10244, "reversal_entry_msc": 7281}
    cluster_funnel = funnel[~funnel.market_overlap_event.astype(str).str.lower().isin(["true", "1", "yes"])]
    for column, expected in expected_reach.items():
        actual = int(cluster_funnel[column].astype(str).str.lower().isin(["true", "1", "yes"]).sum())
        rows.append({"artifact": column, "baseline_rows": expected, "current_rows": actual,
                     "missing": 0, "added": 0, "changed": 0, "mismatches": abs(actual - expected),
                     "status": "PASS" if actual == expected else "FAIL"})
    for column, expected in expected_entries.items():
        actual = int((pd.to_numeric(cluster_funnel[column], errors="coerce").fillna(0) > 0).sum())
        rows.append({"artifact": column, "baseline_rows": expected, "current_rows": actual,
                     "missing": 0, "added": 0, "changed": 0, "mismatches": abs(actual - expected),
                     "status": "PASS" if actual == expected else "FAIL"})
    for name, actual in (("horizon_time_violations", horizon_violations), ("response_drops", drops),
                         ("invalid_response_rows", invalid), ("duplicate_response_events", duplicate_events)):
        rows.append({"artifact": name, "baseline_rows": 0, "current_rows": actual,
                     "missing": 0, "added": 0, "changed": 0, "mismatches": actual,
                     "status": "PASS" if actual == 0 else "FAIL"})

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f"rows={len(rows)} failures={sum(row['status'] != 'PASS' for row in rows)} "
          f"horizon_status={dict(horizon_status)}")
    return 1 if any(row["status"] != "PASS" for row in rows) else 0


if __name__ == "__main__":
    raise SystemExit(main())
