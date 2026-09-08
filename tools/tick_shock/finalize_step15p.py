#!/usr/bin/env python3
"""Append the audited Step 15P artifact rollup to the canonical manifest."""

from __future__ import annotations

import hashlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/research/tick_shock/00_artifact_manifest.md"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest().upper()


fixed = [
    ("docs/research/tick_shock/15p_symmetric_oco_micro_profit_preanalysis.md", "document", "39a57dab"),
    ("mql/Include/TickShock/TickShockSymmetricOco.mqh", "source", "12afc46a"),
    ("mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5", "source", "12afc46a"),
    ("mql/Experts/tests/ExpectedValue_TickShock_SymmetricOcoHarness.mq5", "test source", "12afc46a"),
    ("tools/tick_shock/run_step15p_tests.ps1", "source", "12afc46a"),
]

new_files = [
    "docs/research/tick_shock/15p_symmetric_oco_micro_profit_results.md",
    "docs/devlog/2026-09-08-step15p-symmetric-oco-micro-profit.md",
    "reports/tests/tick_shock/step15p_validation_summary.md",
    "reports/tests/tick_shock/step15p_symmetric_oco_harness.csv",
    "reports/tests/tick_shock/configs/step15p_symmetric_oco.ini",
    "tools/tick_shock/run_step15p_april.ps1",
    "tools/tick_shock/prepare_step15p_evidence.py",
    "tools/tick_shock/analyze_step15p.py",
    "tools/tick_shock/step15p_independent_recalculation.py",
    "tools/tick_shock/verify_step15p_determinism.py",
    "tools/tick_shock/finalize_step15p.py",
]

for directory in (
    ROOT / "reports/analysis/tick_shock/step15p",
    ROOT / "reports/backtest/runs/20260908_ts15p_symmetric_oco_micro_profit_202504",
    ROOT / "reports/backtest/runs/20260908_ts15p_symmetric_oco_micro_profit_rerun_202504",
):
    for path in sorted(p for p in directory.rglob("*") if p.is_file()):
        rel = path.relative_to(ROOT).as_posix()
        if path.name in {
            "symmetric_oco_scenarios.csv",
            "detector_features.csv",
            "detector_features.csv.runmeta",
            "medium_horizon_episode_summary.csv",
            "medium_horizon_episode_summary.csv.runmeta",
        }:
            continue
        new_files.append(rel)

kind_by_suffix = {
    ".py": "source",
    ".ps1": "source",
    ".md": "document",
    ".png": "generated evidence",
    ".html": "generated evidence",
    ".json": "generated evidence",
    ".csv": "generated evidence",
    ".gz": "generated evidence",
    ".txt": "generated evidence",
    ".ini": "generated evidence",
    ".set": "generated evidence",
    ".ex5": "compiled binary",
}

text = MANIFEST.read_text(encoding="utf-8-sig")
text = text.replace(
    "branch: `research/tickshock/2026-09-step15o-cross-fx-lead-lag`",
    "branch: `research/tickshock/2026-09-08-step15p-symmetric-oco-micro-profit`",
)
text = text.replace(
    "status: `STEP15O_CROSS_FX_TRADE_EDGE_NOT_FOUND_OOS_NOT_JUSTIFIED_PRODUCTION_NOT_ELIGIBLE`",
    "status: `MICRO_PROFIT_FEASIBILITY_NOT_FOUND_DEVELOPMENT_ONLY_PRODUCTION_NOT_ELIGIBLE`",
)
text = text.replace("manifest_revision: `15O`", "manifest_revision: `15P`")
text = text.replace("covered_steps: `01-15O`", "covered_steps: `01-15P`")
text = text.replace(
    "last_updated_at: `2026-09-08T10:30:00+09:00`",
    "last_updated_at: `2026-09-08T23:55:00+09:00`",
)

existing_ids = set()
existing_pairs = set()
for line in text.splitlines():
    if line.startswith("| TS-"):
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) >= 3:
            existing_ids.add(cells[0])
            existing_pairs.add((cells[2].strip("`"), cells[1]))

rows = []
counter = 1
for rel, kind, owner in fixed + [
    (rel, kind_by_suffix.get(Path(rel).suffix.lower(), "generated evidence"), "SELF")
    for rel in dict.fromkeys(new_files)
]:
    path = ROOT / rel
    if not path.exists():
        raise SystemExit(f"missing artifact: {rel}")
    if (rel, "15P") in existing_pairs:
        continue
    while f"TS-S15P-{counter:04d}" in existing_ids:
        counter += 1
    artifact_id = f"TS-S15P-{counter:04d}"
    source_class = "source" if kind in {"source", "test source"} else "generated evidence"
    purpose = "Step 15P symmetric OCO micro-profit development evidence"
    rows.append(
        f"| {artifact_id} | 15P | `{rel}` | {kind} | {purpose} | {source_class} | "
        f"`{sha256(path)}` | yes | research closeout | COMPLETE | April 2025 development only; "
        f"no production or OOS claim | {owner} |"
    )
    existing_ids.add(artifact_id)
    counter += 1

note = (
    "\n\nStep 15P adds the frozen symmetric-OCO specification, production path, "
    "deterministic harness, two isolated April development runs, independent "
    "recalculation, normalized deterministic comparison, bounded-storage/data-volume "
    "evidence, and the negative feasibility conclusion. Uncompressed scenario CSVs "
    "remain local and ignored; deterministic gzip representations are registered. "
    "Artifact ID duplicates remain zero.\n"
)

if "Step 15P adds the frozen symmetric-OCO specification" not in text:
    first_table = text.find("\n|")
    text = text[:first_table] + note + text[first_table:]
if rows:
    text = text.rstrip() + "\n" + "\n".join(rows) + "\n"
MANIFEST.write_text(text, encoding="utf-8")
print(f"appended={len(rows)}")


if __name__ == "__main__":
    pass
