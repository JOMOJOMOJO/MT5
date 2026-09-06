#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/research/tick_shock/00_artifact_manifest.md"
ANALYSIS_COMMIT = "4f24b382dcd38c13a244723f7f69dac59bac7769"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def committed_paths(commit: str) -> list[str]:
    output = subprocess.check_output(
        ["git", "show", "--pretty=format:", "--name-only", commit], cwd=ROOT, text=True
    )
    return [line.strip() for line in output.splitlines() if line.strip()]


def owner(path: str) -> str:
    dirty = subprocess.check_output(
        ["git", "status", "--porcelain", "--", path], cwd=ROOT, text=True
    ).strip()
    if dirty:
        return "SELF"
    output = subprocess.check_output(
        ["git", "log", "-1", "--format=%H", "--", path], cwd=ROOT, text=True
    ).strip()
    return output or "SELF"


def kind(path: str) -> tuple[str, str]:
    suffix = Path(path).suffix.lower()
    if path.startswith(("mql/", "tools/")) and suffix not in {".ex5", ".log", ".csv", ".png", ".html"}:
        return "source", "source"
    if path.startswith("docs/") or suffix == ".md":
        return "document", "generated evidence"
    return "generated evidence", "generated evidence"


def main() -> None:
    final_paths = [
        "docs/research/tick_shock/15n_post_shock_delayed_decision_preanalysis.md",
        "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5",
        "mql/Include/TickShock/TickShockDelayedDecision.mqh",
        "mql/Experts/tests/ExpectedValue_TickShock_DelayedDecisionHarness.mq5",
        "tools/tick_shock/run_step15n_march.ps1",
        *committed_paths(ANALYSIS_COMMIT),
        "docs/research/tick_shock/15n_post_shock_delayed_decision_results.md",
        "docs/research/tick_shock/15n_post_shock_feature_catalog.md",
        "docs/research/tick_shock/02_function_catalog.md",
        "docs/research/tick_shock/02_data_structures_and_globals.md",
        "reports/tests/tick_shock/step15n_validation_summary.md",
        "docs/devlog/2026-09-07-tickshock-step15n-delayed-decision.md",
        "tools/tick_shock/finalize_step15n.py",
    ]
    paths = list(dict.fromkeys(final_paths))
    missing = [path for path in paths if not (ROOT / path).is_file()]
    if missing:
        raise SystemExit("missing artifacts: " + ", ".join(missing))

    text = MANIFEST.read_text(encoding="utf-8")
    text = re.sub(r"^- branch: `.*`$", "- branch: `research/tickshock/2026-09-step15n-post-shock-delayed-decision`", text, count=1, flags=re.M)
    text = re.sub(r"^- status: `.*`$", "- status: `STEP15N_ORACLE_FEASIBILITY_FOUND_TRADE_EDGE_NOT_FOUND_OOS_NOT_JUSTIFIED_PRODUCTION_NOT_ELIGIBLE`", text, count=1, flags=re.M)
    text = re.sub(r"^- manifest_revision: `.*`$", "- manifest_revision: `15N`", text, count=1, flags=re.M)
    text = re.sub(r"^- covered_steps: `.*`$", "- covered_steps: `01-15N`", text, count=1, flags=re.M)
    text = re.sub(r"^- last_audited_commit: `.*`$", "- last_audited_commit: `SELF`", text, count=1, flags=re.M)
    text = re.sub(r"^- last_updated_at: `.*`$", "- last_updated_at: `2026-09-07T23:45:00+09:00`", text, count=1, flags=re.M)

    marker = "\n\nStep 15N adds a preregistered research-only delayed-decision engine"
    if marker in text:
        text = text.split(marker, 1)[0].rstrip() + "\n"
    existing_ids = set(re.findall(r"^\|\s*(TS-[^| ]+)\s*\|", text, flags=re.M))
    rows = []
    for index, path in enumerate(paths, 1):
        artifact_type, provenance = kind(path)
        owning_commit = owner(path)
        if path in {
            "docs/research/tick_shock/15n_post_shock_delayed_decision_results.md",
            "docs/research/tick_shock/15n_post_shock_feature_catalog.md",
            "docs/research/tick_shock/02_function_catalog.md",
            "docs/research/tick_shock/02_data_structures_and_globals.md",
            "reports/tests/tick_shock/step15n_validation_summary.md",
            "docs/devlog/2026-09-07-tickshock-step15n-delayed-decision.md",
            "tools/tick_shock/finalize_step15n.py",
        }:
            owning_commit = "SELF"
        rows.append(
            f"| TS-S15N-{index:04d} | 15N | `{path}` | {artifact_type} | "
            f"Step 15N delayed-decision oracle, causal prediction and QA | {provenance} | "
            f"`{sha(ROOT / path)}` | yes | research conclusion | COMPLETE | "
            f"March development only; no production promotion | {owning_commit} |"
        )

    rollup = (
        "\n\nStep 15N adds a preregistered research-only delayed-decision engine, its formal "
        "March r2 evidence, oracle and chronological OOF analysis, independent recalculation, "
        "deterministic rerun, and final interpretation. The rejected r1 raw run remains local "
        "and is represented only by `rejected_r1_vs_formal_r2.csv`; it is not formal evidence. "
        "Step 15N always remains `PRODUCTION_NOT_ELIGIBLE`.\n\n"
        "| artifact ID | step | artifact path | type | purpose | source/generated | SHA-256 | commit | next step | status | note | owning_commit |\n"
        "|---|---:|---|---|---|---|---|---|---|---|---|---|\n"
        + "\n".join(rows)
        + "\n"
    )
    MANIFEST.write_text(text.rstrip() + rollup, encoding="utf-8")

    updated = MANIFEST.read_text(encoding="utf-8")
    ids = re.findall(r"^\|\s*(TS-[^| ]+)\s*\|", updated, flags=re.M)
    if len(ids) != len(set(ids)):
        raise SystemExit("duplicate artifact IDs detected")
    print(f"step15n_rows={len(rows)} total_ids={len(ids)} duplicate_ids=0")


if __name__ == "__main__":
    main()
