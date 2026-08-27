#!/usr/bin/env python3
"""Append authoritative Step 15A rows to the artifact manifest once."""

from __future__ import annotations

import hashlib
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/research/tick_shock/00_artifact_manifest.md"
BASE = "7a04694297a142d04c3beb331ee9049f32b5ab60"


def git(*args: str) -> str:
    return subprocess.run(["git", "-C", str(ROOT), *args], check=True, text=True,
                          encoding="utf-8", stdout=subprocess.PIPE).stdout.strip()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def kind(path: str) -> tuple[str, str, str]:
    if path.startswith("mql/Include/"):
        return "production module", "source", "IMPLEMENTED_TESTED"
    if path.startswith("mql/Experts/tests/") or path.startswith("tests/"):
        return "test/fixture", "source", "PASS_OR_RETAINED_SKIP"
    if path.startswith("mql/Experts/"):
        return "research EA", "source", "COMPILE_PASS"
    if path.startswith("tools/"):
        return "research tool", "source", "COMPLETE"
    if path.startswith("docs/"):
        return "research document", "source", "COMPLETE"
    if path.startswith("reports/backtest/runs/"):
        return "March run evidence", "generated evidence", "ARCHIVED"
    if path.startswith("reports/compile/"):
        return "compile evidence", "generated evidence", "ZERO_ERRORS_WARNINGS"
    return "research evidence", "generated evidence", "COMPLETE"


def main() -> int:
    text = MANIFEST.read_text(encoding="utf-8-sig")
    if "## Step 15A statistical shock redefinition artifacts" in text:
        raise RuntimeError("Step 15A manifest section already exists; refusing duplicate append")
    head = git("rev-parse", "HEAD")
    changed = set(git("diff", "--name-only", f"{BASE}..{head}").splitlines())
    changed.discard("docs/research/tick_shock/00_artifact_manifest.md")
    paths = sorted(path for path in changed if path and (ROOT / path).is_file())
    rows: list[str] = []
    for index, path in enumerate(paths, 1):
        artifact_type, source_kind, status = kind(path)
        owning = git("log", "-1", "--format=%H", "--", path)
        rows.append(
            f"| TS-S15A-{index:03d} | 15A | `{path}` | {artifact_type} | "
            f"statistical shock V1 development/regression | {source_kind} | `{sha256(ROOT / path)}` | yes | "
            f"explicit control-recorder decision | {status} | no locked OOS authorization | {owning} |"
        )
    section = (
        "\n\n## Step 15A statistical shock redefinition artifacts\n\n"
        "These rows cover the predeclared specification, RED/GREEN implementation,\n"
        "superseded/aborted diagnostics, four same-source March runs, independent\n"
        "comparison, and fail-closed selection evidence. The exact matched-control\n"
        "result remains NOT_ESTIMABLE; no locked OOS is authorized.\n\n"
        "| artifact ID | step | artifact relative path | type | purpose | source/generated | SHA-256 | commit | next Step | status | note | owning_commit |\n"
        "|---|---:|---|---|---|---|---|---|---|---|---|---|\n" + "\n".join(rows) + "\n"
    )
    text = re.sub(r"- status: `[^`]+`", "- status: `STEP15A_DEVELOPMENT_COMPLETE_NO_CANDIDATE`", text, count=1)
    text = re.sub(r"- manifest_revision: `[^`]+`", "- manifest_revision: `15A`", text, count=1)
    text = re.sub(r"- covered_steps: `[^`]+`", "- covered_steps: `01-15A`", text, count=1)
    text = re.sub(r"- last_audited_commit: `[^`]+`", f"- last_audited_commit: `{head}`", text, count=1)
    text = re.sub(r"- last_updated_at: `[^`]+`", "- last_updated_at: `2026-08-27T09:55:00+09:00`", text, count=1)
    text += section
    artifact_ids = re.findall(r"^\| (TS-[^| ]+) \|", text, flags=re.MULTILINE)
    artifact_paths = re.findall(r"^\| TS-[^|]+ \|[^|]+\| `([^`]+)` \|", text, flags=re.MULTILINE)
    if len(artifact_ids) != len(set(artifact_ids)):
        raise RuntimeError("artifact ID duplicate after Step 15A append")
    rollup = (
        f"\nStep 15A appends {len(rows)} authoritative rows. The post-Step-15A rollup is "
        f"{len(artifact_ids)} rows and {len(set(artifact_paths))} unique paths; artifact ID duplicates are zero.\n"
    )
    text += rollup
    MANIFEST.write_text(text, encoding="utf-8", newline="\n")
    print(f"step15a_rows={len(rows)} total_rows={len(artifact_ids)} unique_paths={len(set(artifact_paths))} head={head}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
