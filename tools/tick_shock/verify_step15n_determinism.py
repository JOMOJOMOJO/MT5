#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
from pathlib import Path


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--primary", type=Path, required=True)
    parser.add_argument("--rerun", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    external_evidence = {"deterministic_rerun.csv", "independent_recalculation.csv"}
    names = sorted(path.name for path in args.primary.glob("*.csv") if path.name not in external_evidence)
    rows = []
    for name in names:
        left = args.primary / name
        right = args.rerun / name
        left_hash = digest(left)
        right_hash = digest(right) if right.exists() else "MISSING"
        rows.append(
            {
                "path": name,
                "primary_sha256": left_hash,
                "rerun_sha256": right_hash,
                "status": "PASS" if left_hash == right_hash else "FAIL",
            }
        )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
