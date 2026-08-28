#!/usr/bin/env python3
"""Append the complete Step 15C artifact rollup and audit latest-path hashes."""
from __future__ import annotations

import hashlib
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/research/tick_shock/00_artifact_manifest.md"
SELF_EXCLUDED = {
    "docs/research/tick_shock/00_artifact_manifest.md",
    "reports/qa/tick_shock/step15c_hashes.txt",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def owning_commit(rel: str) -> str:
    if subprocess.run(["git", "diff", "--quiet", "--", rel], cwd=ROOT).returncode != 0:
        return "SELF"
    if subprocess.run(["git", "ls-files", "--error-unmatch", rel], cwd=ROOT,
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
        return "SELF"
    return subprocess.run(["git", "log", "-1", "--format=%H", "--", rel], cwd=ROOT,
                          text=True, capture_output=True, check=True).stdout.strip() or "SELF"


def selected(path: Path) -> bool:
    rel = str(path.relative_to(ROOT)).replace("\\", "/")
    return (
        rel.startswith("docs/research/tick_shock/15c_")
        or rel == "docs/research/tick_shock/02_function_catalog.md"
        or rel == "docs/research/tick_shock/02_data_structures_and_globals.md"
        or rel.startswith("docs/devlog/2026-08-29-tickshock-step15c")
        or rel == "mql/Include/TickShock/TickShockEventResponse.mqh"
        or rel == "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5"
        or "ExpectedValue_TickShock_EventResponseHarness" in rel
        or rel.endswith("TickShockStep15CTestSupport.mqh")
        or rel.startswith("tools/tick_shock/") and "step15c" in path.name.lower()
        or rel.startswith("tests/tick_shock/fixtures/TS15C-")
        or rel.startswith("tests/tick_shock/expected/TS15C-")
        or rel == "tests/tick_shock/spec/test_cases.csv"
        or rel == "tests/tick_shock/python/test_fixture_integrity.py"
        or rel.startswith("reports/analysis/tick_shock/step15c/")
        or rel.startswith("reports/backtest/runs/20260828_ts15c_")
        or rel.startswith("reports/compile/tick_shock/step15c")
        or rel.startswith("reports/tests/tick_shock/step15c")
        or rel.startswith("reports/qa/tick_shock/step15c")
    )


def main() -> int:
    text = MANIFEST.read_text(encoding="utf-8")
    roots = [ROOT / name for name in ("docs", "mql", "tools", "tests", "reports")]
    paths = sorted(path for base in roots for path in base.rglob("*") if path.is_file() and selected(path))
    existing_ids = re.findall(r"^\|\s*([^|]+?)\s*\|", text, flags=re.MULTILINE)
    existing_ids = [value for value in existing_ids if value not in {"artifact ID", "---"}]
    if len(existing_ids) != len(set(existing_ids)):
        raise SystemExit("pre-existing manifest artifact ID duplicate")
    rows = []
    for index, path in enumerate(paths, 1):
        rel = str(path.relative_to(ROOT)).replace("\\", "/")
        kind = "source" if rel.startswith(("mql/", "tools/", "tests/", "docs/")) else "generated evidence"
        status = "INVALID_DEVELOPMENT_RUN" if any(f"_r{n}/" in rel for n in range(1, 5)) else "COMPLETE"
        digest = "SELF_EXCLUDED" if rel in SELF_EXCLUDED else sha(path)
        rows.append(f"| TS-S15C-C{index:04d} | 15C | `{rel}` | step15c_{kind.replace(' ', '_')} | "
                    f"event-response development study and QA | {kind} | `{digest}` | yes | stop after Step 15C | "
                    f"{status} | candidate frozen before confirmation; no locked OOS | {owning_commit(rel)} |")
    text = re.sub(r"- branch: `[^`]+`", "- branch: `research/tickshock-step15c-event-response-20260828`", text, count=1)
    text = re.sub(r"- status: `[^`]+`", "- status: `STEP15C_DEVELOPMENT_EVENT_RESPONSE_COMPLETE_WITH_ONE_LEGACY_PROVENANCE_FAIL`", text, count=1)
    text = re.sub(r"- manifest_revision: `[^`]+`", "- manifest_revision: `15C`", text, count=1)
    text = re.sub(r"- covered_steps: `[^`]+`", "- covered_steps: `01-15C`", text, count=1)
    text = re.sub(r"- last_audited_commit: `[^`]+`", "- last_audited_commit: `SELF`", text, count=1)
    text = re.sub(r"- last_updated_at: `[^`]+`", "- last_updated_at: `2026-08-29T03:30:00+09:00`", text, count=1)
    text = text.rstrip() + "\n\n" + "\n".join(rows) + "\n\n"
    final_ids = existing_ids + [f"TS-S15C-C{index:04d}" for index in range(1, len(rows)+1)]
    unique_paths = {str(path.relative_to(ROOT)).replace("\\", "/") for path in paths}
    text += (f"Step 15C complete rollup adds {len(rows)} rows; artifact ID duplicates 0. "
             f"The rollup contains {len(unique_paths)} unique Step 15C paths. Manifest/self-hash inventories are "
             "excluded from recursive digest checks.\n")
    MANIFEST.write_text(text, encoding="utf-8")

    # Latest-row SHA audit across the complete manifest.
    latest: dict[str, str] = {}
    ids: list[str] = []
    for line in text.splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) < 7 or cells[0] in {"artifact ID", "---"}:
            continue
        ids.append(cells[0])
        rel = cells[2].strip("`")
        digest = cells[6].strip("`")
        latest[rel] = digest
    if len(ids) != len(set(ids)):
        raise SystemExit("post-update artifact ID duplicate")
    mismatches = []
    for rel, digest in latest.items():
        path = ROOT / rel
        if digest in {"SELF", "SELF_EXCLUDED", "", "N/A"} or not path.is_file():
            continue
        if re.fullmatch(r"[0-9A-Fa-f]{64}", digest) and sha(path) != digest.upper():
            mismatches.append(rel)
    print(f"rows_added={len(rows)} ids={len(ids)} id_duplicates=0 latest_sha_mismatches={len(mismatches)}")
    if mismatches:
        print("\n".join(mismatches[:20]))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
