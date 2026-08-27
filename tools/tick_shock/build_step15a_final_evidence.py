#!/usr/bin/env python3
"""Build deterministic Step 15A changed-file and SHA-256 inventories."""

from __future__ import annotations

import csv
import hashlib
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = "7a04694297a142d04c3beb331ee9049f32b5ab60"
OUTPUT = ROOT / "reports/research/tick_shock"


def git(*args: str) -> list[str]:
    completed = subprocess.run(["git", "-C", str(ROOT), *args], check=True,
                               text=True, encoding="utf-8", stdout=subprocess.PIPE)
    return [line for line in completed.stdout.splitlines() if line]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def write(path: Path, rows: list[dict[str, object]], fields: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader(); writer.writerows(rows)


def classify(path: str) -> str:
    if path.startswith("mql/Include/") or path.startswith("mql/Experts/"):
        return "production_or_harness_source"
    if path.startswith("tests/"):
        return "test_fixture_expected_or_registry"
    if path.startswith("tools/"):
        return "research_tool"
    if path.startswith("docs/"):
        return "research_document"
    if path.startswith("reports/backtest/runs/"):
        return "mt5_run_evidence"
    return "generated_research_evidence"


def main() -> int:
    changed = set(git("diff", "--name-only", f"{BASE}..HEAD"))
    changed.update(git("diff", "--name-only"))
    changed.update(git("ls-files", "--others", "--exclude-standard"))
    for run_dir in sorted((ROOT / "reports/backtest/runs").glob("20260827_ts15a*")):
        changed.update(path.relative_to(ROOT).as_posix() for path in run_dir.rglob("*") if path.is_file())
    changed.discard("docs/research/tick_shock/00_artifact_manifest.md")
    changed.discard("reports/research/tick_shock/step15a_changed_files.csv")
    changed.discard("reports/research/tick_shock/step15a_output_hashes.csv")
    paths = sorted(path for path in changed if (ROOT / path).is_file())
    changed_rows = [{"path": path, "classification": classify(path), "action": "commit",
                     "reason": "Step 15A source/test/document/development evidence"} for path in paths]
    write(OUTPUT / "step15a_changed_files.csv", changed_rows,
          ["path", "classification", "action", "reason"])
    hash_rows = [{"path": path, "sha256": sha256(ROOT / path), "bytes": (ROOT / path).stat().st_size,
                  "classification": classify(path)} for path in paths]
    write(OUTPUT / "step15a_output_hashes.csv", hash_rows,
          ["path", "sha256", "bytes", "classification"])
    print(f"changed_files={len(paths)} hash_rows={len(hash_rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
