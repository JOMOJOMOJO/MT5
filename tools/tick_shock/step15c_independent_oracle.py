#!/usr/bin/env python3
"""Independent Step 15C oracle; never imports or calls production modules."""

from __future__ import annotations

import csv, hashlib, math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def rows(path: Path):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def main() -> int:
    cases = [r for r in rows(ROOT / "tests/tick_shock/spec/test_cases.csv")
             if r["test_id"].startswith("TS15C-")]
    failures = []
    for case in cases:
        fixture = rows(ROOT / case["fixture_path"])
        expected = rows(ROOT / case["expected_path"])
        times = [int(r["time_msc"]) for r in fixture]
        if times != sorted(times): failures.append((case["test_id"],"fixture not chronological"))
        if not expected or expected[0]["expected_value"] == "": failures.append((case["test_id"],"blank oracle"))

    # Explicit hand-derived oracle anchors used by multiple contracts.
    anchors = {
        "signed_long": math.log(1.001/1.0),
        "signed_short": -math.log(0.999/1.0),
        "stressed_bid": 1.0 - 0.00025/2,
        "stressed_ask": 1.0 + 0.00025/2,
        "episode_overlap": 120000 <= 120000,
        "candidate_hash": hashlib.sha256(b"canonical-policy-v1").hexdigest(),
    }
    if abs(anchors["signed_long"] - 0.0009995003330834232) > 1e-15: failures.append(("ORACLE","log return"))
    if (anchors["stressed_bid"],anchors["stressed_ask"]) != (0.999875,1.000125): failures.append(("ORACLE","spread"))
    print(f"tests={len(cases)} failures={len(failures)} anchors={len(anchors)}")
    for failure in failures: print(*failure)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
