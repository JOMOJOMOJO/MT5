from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
csv.field_size_limit(min(sys.maxsize, 2**31 - 1))


def read_csv(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def raw_observations():
    rows = {}
    raw_dir = ROOT / "reports" / "tests" / "tick_shock" / "raw"
    for path in sorted(raw_dir.glob("*.csv")):
        for row in read_csv(path):
            test_id = row.get("test_id")
            if test_id:
                rows[test_id] = row
    return rows


def parse_scenario(item: str):
    parts = item.split("|")
    data = {"strategy": parts[0]} if parts else {}
    for part in parts[1:]:
        if "=" in part:
            key, value = part.split("=", 1)
            data[key] = value
    return data
