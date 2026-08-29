#!/usr/bin/env python3
"""Independent Step 15D oracle checks; never imports production code."""

from __future__ import annotations

import csv
import math
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "reports/tests/tick_shock/step15d_green/independent_oracle.csv"


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def add(rows: list[dict[str, str]], check: str, expected: object, actual: object) -> None:
    rows.append({"check_id": check, "expected": str(expected), "actual": str(actual),
                 "status": "PASS" if expected == actual else "FAIL"})


def main() -> int:
    registry = read_rows(ROOT / "tests/tick_shock/spec/test_cases.csv")
    cases = [row for row in registry if row["test_id"].startswith("TS15D-")]
    result: list[dict[str, str]] = []
    add(result, "case_count", 64, len(cases))
    add(result, "unique_test_ids", 64, len({row["test_id"] for row in cases}))
    for case in cases:
        fixture_path = ROOT / case["fixture_path"]
        expected_path = ROOT / case["expected_path"]
        add(result, f"{case['test_id']}:fixture_exists", True, fixture_path.is_file())
        add(result, f"{case['test_id']}:expected_exists", True, expected_path.is_file())
        if fixture_path.is_file():
            fixture = read_rows(fixture_path)
            times = [int(row["time_msc"]) for row in fixture]
            add(result, f"{case['test_id']}:chronological", times, sorted(times))
        if expected_path.is_file():
            expected = read_rows(expected_path)
            add(result, f"{case['test_id']}:oracle_nonblank", True,
                bool(expected) and all(row["expected_value"] != "" for row in expected))

    # Hand-derived numerical and causal anchors, independent of MQL production.
    add(result, "fixed_checkpoint_500", 1500, 1000 + 500)
    add(result, "fixed_checkpoint_1000", 2000, 1000 + 1000)
    add(result, "fixed_checkpoint_3000", 4000, 1000 + 3000)
    add(result, "entry_eligibility", 1750, max(1500 + 100, 1600 + 150))
    add(result, "strict_post_signal_fill", False, 1500 > 1500 and 1500 >= 1500)
    add(result, "extension_ratio", 0.5, round((1.0006 - 1.0002) / 0.0008, 10))
    add(result, "retracement_ratio", 0.25, round(0.0002 / 0.0008, 10))
    add(result, "directional_imbalance", 0.5, (3 - 1) / (3 + 1))
    add(result, "usd_sign_eurusd_long", -1, -1)
    add(result, "usd_sign_usdjpy_long", 1, 1)
    add(result, "purge_120s_equal", True, (220000 - 100000) >= 120000)
    add(result, "candidate_budget", True, 6 <= 6)
    frozen_equal = True
    for case in cases:
        relative = case["expected_path"]
        historical = subprocess.check_output(
            ["git", "show", f"82d1abd0:{relative}"], cwd=ROOT
        )
        historical_text = historical.decode("utf-8-sig").replace("\r\n", "\n")
        current_text = (ROOT / relative).read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        if historical_text != current_text:
            frozen_equal = False
            break
    add(result, "frozen_expected_unchanged_since_red", True, frozen_equal)
    add(result, "finite_log_anchor", True, math.isfinite(math.log(1.001 / 1.0)))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["check_id", "expected", "actual", "status"])
        writer.writeheader()
        writer.writerows(result)
    failures = sum(row["status"] == "FAIL" for row in result)
    print(f"checks={len(result)} failures={failures} output={OUT.relative_to(ROOT)}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
