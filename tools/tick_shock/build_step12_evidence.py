#!/usr/bin/env python3
from __future__ import annotations

import csv
import hashlib
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STEP11 = "6bbc0be2"


def read_csv(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, rows: list[dict], fields: tuple[str, ...]):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader(); writer.writerows(rows)


manifest = (ROOT / "docs/research/tick_shock/00_artifact_manifest.md").read_text(encoding="utf-8-sig")
reference: dict[str, str] = {}
for line in manifest.splitlines():
    match = re.match(r"^\| [^|]+ \| [^|]+ \| `([^`]+)` \|.*\| `([A-Fa-f0-9]{64})` \|", line)
    if match:
        reference[match.group(1)] = match.group(2).upper()

fixture_rows = []
for folder in ("tests/tick_shock/fixtures", "tests/tick_shock/expected"):
    for path in sorted((ROOT / folder).glob("*.csv")):
        relative = path.relative_to(ROOT).as_posix()
        current = hashlib.sha256(path.read_bytes()).hexdigest().upper()
        baseline = reference.get(relative, "")
        fixture_rows.append({
            "path": relative,
            "step11_sha256": baseline,
            "step12_sha256": current,
            "unchanged": str(bool(baseline) and baseline == current).lower(),
            "status": "PASS" if baseline == current and baseline else "FAIL",
        })
write_csv(ROOT / "reports/qa/tick_shock/step12_fixture_integrity.csv", fixture_rows,
          ("path", "step11_sha256", "step12_sha256", "unchanged", "status"))

step10 = {row["test_id"]: row for row in read_csv(ROOT / "reports/tests/tick_shock/step10_post_refactor_results.csv")}
step12 = {row["test_id"]: row for row in read_csv(ROOT / "reports/tests/tick_shock/step12_post_fix_results.csv")}
comparison = []
for test_id in sorted(step10):
    old, new = step10[test_id], step12[test_id]
    preserved = old["status"] == new["status"] and old["expected"] == new["expected"] and old["actual"] == new["actual"]
    comparison.append({"test_id": test_id, "step10_status": old["status"], "step12_status": new["status"],
                       "expected_equal": str(old["expected"] == new["expected"]).lower(),
                       "actual_equal": str(old["actual"] == new["actual"]).lower(),
                       "preserved": str(preserved).lower(), "status": "PASS" if preserved else "FAIL"})
write_csv(ROOT / "reports/qa/tick_shock/step12_behavior_preservation.csv", comparison,
          ("test_id", "step10_status", "step12_status", "expected_equal", "actual_equal", "preserved", "status"))

ea_path = "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5"
before = subprocess.check_output(["git", "show", f"{STEP11}:{ea_path}"], cwd=ROOT).decode("utf-8-sig")
after = (ROOT / ea_path).read_text(encoding="utf-8-sig")
names = (
    "InpShockPercentile", "InpMinRobustZ", "InpMinEfficiency", "InpMinMoveSpreadRatio",
    "InpPullbackMinPct", "InpPullbackMaxPct", "InpContinuationInvalidPct", "InpRewardRisk",
    "InpMaxHoldSeconds", "TSR_STOP_COUNT", "TSR_DELAY_MS", "TSR_SPREAD_MULT", "TSR_STRATEGY_COUNT",
)
parameter_rows = []
for name in names:
    pattern = re.compile(rf"^.*\b{re.escape(name)}\b.*$", re.MULTILINE)
    old = pattern.search(before); new = pattern.search(after)
    old_value = old.group(0).strip() if old else ""
    new_value = new.group(0).strip() if new else ""
    parameter_rows.append({"name": name, "step11_definition": old_value, "step12_definition": new_value,
                           "unchanged": str(old_value == new_value).lower(), "status": "PASS" if old_value == new_value else "FAIL"})
write_csv(ROOT / "reports/qa/tick_shock/step12_strategy_parameter_integrity.csv", parameter_rows,
          ("name", "step11_definition", "step12_definition", "unchanged", "status"))

if any(row["status"] != "PASS" for row in fixture_rows + comparison + parameter_rows):
    raise SystemExit("Step 12 integrity evidence contains FAIL")
print(f"fixture_rows={len(fixture_rows)} behavior_rows={len(comparison)} strategy_rows={len(parameter_rows)} failures=0")
