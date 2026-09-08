#!/usr/bin/env python3
"""Register all Step 15O artifacts in the canonical manifest."""

from __future__ import annotations

import hashlib
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/research/tick_shock/00_artifact_manifest.md"


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest().upper()


def last_commit(relative: str) -> str:
    dirty = subprocess.run(
        ["git", "status", "--porcelain", "--", relative], cwd=ROOT,
        check=True, text=True, capture_output=True,
    ).stdout.strip()
    if dirty:
        return "SELF"
    value = subprocess.run(
        ["git", "log", "-1", "--format=%H", "--", relative],
        cwd=ROOT, check=True, text=True, capture_output=True,
    ).stdout.strip()
    return value or "SELF"


def artifact_paths() -> list[str]:
    fixed = [
        "docs/research/tick_shock/15o_cross_fx_lead_lag_preanalysis.md",
        "docs/research/tick_shock/15o_cross_fx_feature_catalog.md",
        "docs/research/tick_shock/15o_cross_fx_lead_lag_results.md",
        "docs/devlog/2026-09-08-tickshock-step15o-cross-fx-lead-lag.md",
        "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5",
        "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.ex5",
        "mql/Include/TickShock/TickShockCrossFxLeadLag.mqh",
        "mql/Experts/tests/ExpectedValue_TickShock_CrossFxLeadLagHarness.mq5",
        "mql/Experts/tests/ExpectedValue_TickShock_CrossFxLeadLagHarness.ex5",
        "tools/tick_shock/run_step15o_april.ps1",
        "tools/tick_shock/prepare_step15o_evidence.py",
        "tools/tick_shock/analyze_step15o.py",
        "tools/tick_shock/finalize_step15o.py",
        "reports/analysis/tick_shock/step15o/period_provenance_audit.csv",
        "reports/tests/tick_shock/configs/step15o_cross_fx_lead_lag.ini",
        "reports/tests/tick_shock/step15o_cross_fx_harness.csv",
        "reports/tests/tick_shock/step15o_cross_fx_harness_journal.txt",
        "reports/tests/tick_shock/step15o_validation_summary.md",
        "reports/compile/tick_shock/step15o_final_cross_fx_harness.log",
        "reports/compile/tick_shock/step15o_final_research_ea.log",
    ]
    dirs = [
        "reports/backtest/runs/20260908_ts15o_cross_fx_lead_lag_202504",
        "reports/backtest/runs/20260908_ts15o_cross_fx_lead_lag_r2_202504",
        "reports/analysis/tick_shock/step15o",
    ]
    paths = set(fixed)
    for directory in dirs:
        for path in (ROOT / directory).rglob("*"):
            if path.is_file():
                paths.add(path.relative_to(ROOT).as_posix())
    for path in (ROOT / "reports/tests/tick_shock/tester").glob("step15o_cross_fx_lead_lag*"):
        if path.is_file():
            paths.add(path.relative_to(ROOT).as_posix())
    missing = [p for p in paths if not (ROOT / p).is_file()]
    if missing:
        raise SystemExit(f"Missing Step 15O artifacts: {missing}")
    return sorted(paths)


def classify(path: str) -> tuple[str, str]:
    suffix = Path(path).suffix.lower()
    if suffix in {".mq5", ".mqh", ".py", ".ps1"}:
        return "source", "source"
    if suffix in {".md", ".txt"}:
        return "document", "generated evidence"
    return "generated evidence", "generated evidence"


def main() -> None:
    text = MANIFEST.read_text(encoding="utf-8")
    text = re.sub(r"(?m)^- branch: `.*`$", "- branch: `research/tickshock/2026-09-step15o-cross-fx-lead-lag`", text, count=1)
    text = re.sub(r"(?m)^- status: `.*`$", "- status: `STEP15O_CROSS_FX_TRADE_EDGE_NOT_FOUND_OOS_NOT_JUSTIFIED_PRODUCTION_NOT_ELIGIBLE`", text, count=1)
    text = re.sub(r"(?m)^- manifest_revision: `.*`$", "- manifest_revision: `15O`", text, count=1)
    text = re.sub(r"(?m)^- covered_steps: `.*`$", "- covered_steps: `01-15O`", text, count=1)
    text = re.sub(r"(?m)^- last_audited_commit: `.*`$", "- last_audited_commit: `SELF`", text, count=1)
    text = re.sub(r"(?m)^- last_updated_at: `.*`$", "- last_updated_at: `2026-09-08T10:30:00+09:00`", text, count=1)
    text = "\n".join(line for line in text.splitlines() if not line.startswith("| TS-S15O-")) + "\n"
    rows = []
    for index, relative in enumerate(artifact_paths(), 1):
        kind, provenance = classify(relative)
        owner = last_commit(relative)
        purpose = "Step 15O causal Cross-FX lead-lag development evidence"
        note = "April 2025 development only; OOS not justified; production not eligible"
        rows.append(
            f"| TS-S15O-{index:04d} | 15O | `{relative}` | {kind} | {purpose} | {provenance} | "
            f"`{digest(ROOT / relative)}` | yes | research closeout | COMPLETE | {note} | {owner} |"
        )
    text += "\n" + "\n".join(rows) + "\n"
    MANIFEST.write_text(text, encoding="utf-8", newline="\n")
    print(f"registered={len(rows)}")


if __name__ == "__main__":
    main()
