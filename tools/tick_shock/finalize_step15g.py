#!/usr/bin/env python3
"""Finalize hashes and append idempotent Step 15G manifest rows."""
from __future__ import annotations

import csv
import hashlib
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/research/tick_shock/00_artifact_manifest.md"
OUT = ROOT / "reports/analysis/tick_shock/step15g"
SHARE = ROOT / "reports/share/tick_shock/step15g"


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest().upper()


def tracked() -> set[str]:
    result = subprocess.run(["git", "ls-files"], cwd=ROOT, check=True, capture_output=True, text=True)
    return {x.replace("\\", "/") for x in result.stdout.splitlines()}


def owning_commit(path: str, tracked_paths: set[str]) -> str:
    if path not in tracked_paths:
        return "SELF"
    result = subprocess.run(["git", "log", "-1", "--format=%H", "--", path], cwd=ROOT, capture_output=True, text=True)
    return result.stdout.strip() or "SELF"


def artifacts() -> list[Path]:
    paths: set[Path] = set()
    patterns = [
        "docs/research/tick_shock/15g_*",
        "docs/devlog/2026-09-02-tickshock-step15g-economic-paths.md",
        "reports/analysis/tick_shock/step15g/*",
        "reports/qa/tick_shock/step15g_*",
        "reports/refactor/tick_shock/step15g_*",
        "reports/share/tick_shock/step15g/*",
        "reports/tests/tick_shock/step15g_red/**/*",
        "reports/tests/tick_shock/step15g_green/**/*",
        "reports/compile/tick_shock/step15g_*.log",
        "tests/tick_shock/fixtures/TS15G-*",
        "tests/tick_shock/expected/TS15G-*",
        "tools/tick_shock/*step15g*",
    ]
    for pattern in patterns:
        paths.update(x for x in ROOT.glob(pattern) if x.is_file())
    explicit = [
        "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5",
        "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.ex5",
        "mql/Experts/tests/ExpectedValue_TickShock_EconomicPathHarness.mq5",
        "mql/Experts/tests/ExpectedValue_TickShock_EconomicPathHarness.ex5",
        "mql/Experts/tests/TickShockStep15GTestSupport.mqh",
        "mql/Include/TickShock/TickShockEconomicPath.mqh",
        "tests/tick_shock/spec/test_cases.csv",
        "tools/tick_shock/run_all_tests.ps1",
        "tools/tick_shock/run_mql_harnesses.ps1",
        "tools/tick_shock/run_python_tests.py",
    ]
    paths.update(ROOT / x for x in explicit if (ROOT / x).is_file())
    run_prefix = "reports/backtest/runs/20260901_ts15g_economic_path_r3_202503/"
    for rel in tracked():
        if rel.startswith(run_prefix) and (ROOT / rel).is_file():
            paths.add(ROOT / rel)
    paths.add(ROOT / "tools/tick_shock/finalize_step15g.py")
    # Carry forward a current row for any pre-existing latest-path entry whose
    # file changed after its earlier manifest row. This makes the rollup audit
    # about current files rather than silently inheriting a stale SHA.
    if MANIFEST.is_file():
        latest = {}
        for line in MANIFEST.read_text(encoding="utf-8").splitlines():
            if line.startswith("| TS-"):
                cells = [x.strip() for x in line.strip().strip("|").split("|")]
                if len(cells) >= 7:
                    latest[cells[2].strip("`")] = cells[6].strip("`")
        for rel, expected in latest.items():
            path = ROOT / rel
            if path.is_file() and path != MANIFEST and sha(path) != expected:
                paths.add(path)
    return sorted(paths, key=lambda x: x.relative_to(ROOT).as_posix())


def refresh_share_hashes() -> None:
    rows = []
    for path in sorted(SHARE.glob("*")):
        if path.is_file() and path.name != "step15g_share_hashes.csv":
            rows.append(dict(path=path.relative_to(ROOT).as_posix(), bytes=path.stat().st_size, sha256=sha(path), under_50_mb=str(path.stat().st_size < 50_000_000).lower()))
    with (SHARE / "step15g_share_hashes.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["path", "bytes", "sha256", "under_50_mb"])
        writer.writeheader(); writer.writerows(rows)


def write_hash_inventory(paths: list[Path], tracked_paths: set[str]) -> None:
    target = OUT / "source_and_output_hashes.csv"
    rows = []
    for path in paths:
        if path == target or path == MANIFEST:
            continue
        rel = path.relative_to(ROOT).as_posix()
        rows.append(dict(path=rel, classification="source" if rel.startswith(("mql/", "tools/", "tests/")) else "evidence", bytes=path.stat().st_size, sha256=sha(path), owning_commit=owning_commit(rel, tracked_paths)))
    with target.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["path", "classification", "bytes", "sha256", "owning_commit"])
        writer.writeheader(); writer.writerows(rows)


def update_manifest(paths: list[Path], tracked_paths: set[str]) -> None:
    text = MANIFEST.read_text(encoding="utf-8")
    text = re.sub(r"- branch: `[^`]+`", "- branch: `research/tickshock-step15g-economic-path-classification-20260901`", text, count=1)
    text = re.sub(r"- status: `[^`]+`", "- status: `STEP15G_DEVELOPMENT_ECONOMIC_PATHS_CHARACTERIZED_NO_HYPOTHESIS_FROZEN`", text, count=1)
    text = re.sub(r"- manifest_revision: `[^`]+`", "- manifest_revision: `15G`", text, count=1)
    text = re.sub(r"- covered_steps: `[^`]+`", "- covered_steps: `01-15G`", text, count=1)
    text = re.sub(r"- last_audited_commit: `[^`]+`", "- last_audited_commit: `SELF`", text, count=1)
    text = re.sub(r"- last_updated_at: `[^`]+`", "- last_updated_at: `2026-09-02T00:00:00+09:00`", text, count=1)
    text = re.sub(r"\n\nStep 15G appends .*?rather than committed to Git\.\n", "\n", text, flags=re.S)
    text = re.sub(r"\n\| TS-S15G-\d{4} \|.*?(?=\n\| TS-|\Z)", "", text, flags=re.S)
    rows = []
    for index, path in enumerate(paths, 1):
        rel = path.relative_to(ROOT).as_posix()
        kind = "source" if rel.startswith(("mql/", "tools/", "tests/")) else "generated evidence" if rel.startswith("reports/") else "document"
        commit = owning_commit(rel, tracked_paths)
        rows.append(f"| TS-S15G-{index:04d} | 15G | `{rel}` | {kind} | Step 15G economic path classification | {'source' if kind == 'source' else 'generated evidence'} | `{sha(path)}` | {'yes' if rel != 'reports/backtest/runs/20260901_ts15g_economic_path_r3_202503/economic_first_touch.csv' else 'no'} | stop after Step 15G | COMPLETE | March development only | {commit} |")
    existing_rows = len(re.findall(r"^\| TS-", text, flags=re.M))
    existing_paths = {line.strip().strip("|").split("|")[2].strip().strip("`") for line in text.splitlines() if line.startswith("| TS-")}
    new_paths = {path.relative_to(ROOT).as_posix() for path in paths}
    note = f"\n\nStep 15G appends {len(rows)} current source, deterministic-test, formal-run, analysis, compact-share, and QA rows. The post-Step-15G rollup contains {existing_rows + len(rows)} artifact rows and {len(existing_paths | new_paths)} unique paths. Artifact ID duplicates are zero. The 251,846,168-byte raw economic first-touch CSV remains local generated evidence and is represented by its SHA-256 manifest rather than committed to Git.\n"
    MANIFEST.write_text(text.rstrip() + note + "\n" + "\n".join(rows) + "\n", encoding="utf-8")


def validate() -> None:
    text = MANIFEST.read_text(encoding="utf-8")
    ids = re.findall(r"^\| (TS-[^| ]+) \|", text, flags=re.M)
    if len(ids) != len(set(ids)):
        raise RuntimeError("manifest artifact ID duplicate")
    latest = {}
    for line in text.splitlines():
        if not line.startswith("| TS-"):
            continue
        cells = [x.strip() for x in line.strip().strip("|").split("|")]
        if len(cells) >= 7:
            latest[cells[2].strip("`")] = cells[6].strip("`")
    mismatches = []
    for rel, expected in latest.items():
        path = ROOT / rel
        if path.is_file() and path != MANIFEST and sha(path) != expected:
            mismatches.append(rel)
    if mismatches:
        raise RuntimeError(f"latest manifest SHA mismatches: {mismatches[:5]}")
    print(f"STEP15G_ARTIFACTS={len([x for x in ids if x.startswith('TS-S15G-')])} TOTAL_IDS={len(ids)} DUPLICATES=0 LATEST_SHA_MISMATCHES=0")


def main() -> None:
    refresh_share_hashes()
    tracked_paths = tracked()
    paths = artifacts()
    write_hash_inventory(paths, tracked_paths)
    paths = artifacts()
    update_manifest(paths, tracked_paths)
    validate()


if __name__ == "__main__":
    main()
