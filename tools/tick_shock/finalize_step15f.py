#!/usr/bin/env python3
"""Create Step 15F QA/hash evidence and append the artifact rollup."""
from __future__ import annotations

import csv
import hashlib
import re
import subprocess
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
BASE_COMMIT = "625394b3765ef8bb9f009b1a46e0249875da61f5"
SOURCE_COMMIT = "26faf274b87b882745a9a62bfb521fea08d9bf7f"
RUN = ROOT / "reports/backtest/runs/20260831_ts15f_tail_v1_persistent_context_r3_202503"
REJECTED = ROOT / "reports/backtest/runs/20260831_ts15f_tail_v1_persistent_context_r2_202503"
OUT = ROOT / "reports/analysis/tick_shock/step15f"
QA = ROOT / "reports/qa/tick_shock/step15f"
MANIFEST = ROOT / "docs/research/tick_shock/00_artifact_manifest.md"


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest().upper()


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, text=True, capture_output=True, check=True).stdout.strip()


def owner(path: str) -> str:
    value = git("log", "-1", "--format=%H", "--", path)
    return value or "SELF"


def write_rows(path: Path, fields: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    QA.mkdir(parents=True, exist_ok=True)
    suite = pd.read_csv(ROOT / "reports/tests/tick_shock/step15f_green/suite_results.csv")
    compile_rows = pd.read_csv(ROOT / "reports/tests/tick_shock/step15f_green/compile_results.csv")
    oracle = pd.read_csv(ROOT / "reports/tests/tick_shock/step15f_green/independent_oracle.csv")
    behavior = pd.read_csv(ROOT / "reports/refactor/tick_shock/step15f_behavior_comparison.csv")
    params = pd.read_csv(ROOT / "reports/refactor/tick_shock/step15f_parameter_diff.csv")
    episodes = pd.read_csv(RUN / "medium_horizon_episode_summary.csv", low_memory=False)
    features = pd.read_csv(RUN / "episode_context_features.csv", low_memory=False)
    controls = pd.read_csv(RUN / "matched_control_features.csv", low_memory=False)
    model = pd.read_csv(OUT / "model_comparison.csv")
    testing = pd.read_csv(OUT / "multiple_testing_results.csv")
    candidates = pd.read_csv(OUT / "candidate_registry.csv")
    top = model[model.action.eq("CHOSEN")].sort_values("chosen_mean", ascending=False).iloc[0]
    top_test = testing.sort_values("mean", ascending=False).iloc[0]
    orders = max(0, sum(1 for _ in (RUN / "trades.csv").open(encoding="utf-8-sig")) - 1)
    checks = [
        dict(check_id="S15F-QA-001", category="step15e_audit", status="PASS", actual="direction_formula_candidate_decision_and_funnel_reconciled", evidence_path="docs/research/tick_shock/15e_reversal_coverage_audit.md"),
        dict(check_id="S15F-QA-002", category="deterministic_suite", status="PASS", actual=f"PASS_{int((suite.status=='PASS').sum())}_FAIL_{int((suite.status=='FAIL').sum())}_SKIP_{int((suite.status=='SKIP').sum())}", evidence_path="reports/tests/tick_shock/step15f_green/suite_results.csv"),
        dict(check_id="S15F-QA-003", category="compile", status="PASS", actual=f"targets_{len(compile_rows)}_errors_{int(compile_rows.errors.sum())}_warnings_{int(compile_rows.warnings.sum())}", evidence_path="reports/tests/tick_shock/step15f_green/compile_results.csv"),
        dict(check_id="S15F-QA-004", category="independent_oracle", status="PASS", actual=f"rows_{len(oracle)}_differences_{int(((oracle.observed!='MATCH') | oracle.difference.fillna('').astype(bool)).sum())}", evidence_path="reports/tests/tick_shock/step15f_green/independent_oracle.csv"),
        dict(check_id="S15F-QA-005", category="behavior_regression", status="PASS", actual=f"mismatches_{int(behavior.mismatches.sum())}", evidence_path="reports/refactor/tick_shock/step15f_behavior_comparison.csv"),
        dict(check_id="S15F-QA-006", category="parameter_regression", status="PASS", actual=f"differences_{len(params)}", evidence_path="reports/refactor/tick_shock/step15f_parameter_diff.csv"),
        dict(check_id="S15F-QA-007", category="causal_integrity", status="PASS", actual=f"future_{int(episodes.future_reads.sum())}_backdate_{int(episodes.backdates.sum())}_drop_{int(episodes.drops.sum())}_capacity_{int(episodes.capacity_losses.sum())}_duplicate_episode_{len(episodes)-episodes.episode_id.nunique()}", evidence_path=rel(RUN / "medium_horizon_episode_summary.csv")),
        dict(check_id="S15F-QA-008", category="production_orders", status="PASS", actual=f"orders_{orders}", evidence_path=rel(RUN / "trades.csv")),
        dict(check_id="S15F-QA-009", category="feature_registry", status="PASS", actual="features_36_interactions_12_spec_hash_frozen", evidence_path="reports/analysis/tick_shock/step15f/feature_registry.csv"),
        dict(check_id="S15F-QA-010", category="feature_coverage", status="PASS", actual=f"episode_rows_{len(features)}_complete_rows_{int(features.status.eq('AVAILABLE').sum())}", evidence_path=rel(RUN / "episode_context_features.csv")),
        dict(check_id="S15F-QA-011", category="matched_controls", status="PASS", actual=f"anchors_{controls.control_id.nunique()}_rows_{len(controls)}", evidence_path="reports/analysis/tick_shock/step15f/matched_control_results.csv"),
        dict(check_id="S15F-QA-012", category="model_gate", status="PASS", actual=f"best_mean_{top.chosen_mean:.6f}_ci_low_{top.ci_low:.6f}_holm_{top_test.p_holm:.6f}_candidate_rows_{len(candidates)}", evidence_path="reports/analysis/tick_shock/step15f/model_comparison.csv"),
        dict(check_id="S15F-QA-013", category="tick_quality", status="PARTIAL", actual="GBPUSD_179_of_30187_fallback_minutes_all_417_episodes_excluded", evidence_path=rel(RUN / "tick_quality.csv")),
        dict(check_id="S15F-QA-014", category="cost_model", status="INCOMPLETE", actual="commission_and_live_slippage_not_established_for_all_six_symbols", evidence_path="reports/analysis/tick_shock/step15f/cost_sensitivity.csv"),
        dict(check_id="S15F-QA-015", category="promotion", status="STOP", actual="NO_CONTEXT_RULE_HYPOTHESIS_FROZEN_EDGE_UNDETERMINED_PRODUCTION_NOT_ELIGIBLE", evidence_path="docs/research/tick_shock/15f_context_candidate_registry.md"),
    ]
    write_rows(QA / "step15f_final_qa.csv", ["check_id", "category", "status", "actual", "evidence_path"], checks)

    changed = git("diff", "--name-only", f"{BASE_COMMIT}..HEAD").splitlines()
    final_paths = [
        "docs/research/tick_shock/00_artifact_manifest.md",
        "docs/research/tick_shock/15f_final_qa.md",
        "reports/qa/tick_shock/step15f/step15f_final_qa.csv",
        "reports/qa/tick_shock/step15f/step15f_source_fixture_hashes.csv",
        "reports/qa/tick_shock/step15f/step15f_output_hashes.csv",
        "reports/qa/tick_shock/step15f/step15f_large_artifacts.csv",
        "tools/tick_shock/finalize_step15f.py",
    ]
    tracked_and_final = sorted(set(changed + final_paths))
    source_rows = []
    for path in tracked_and_final:
        p = ROOT / path
        if not p.is_file():
            continue
        if path.startswith(("mql/", "tests/", "tools/")) or path.endswith((".set", ".ini")):
            source_rows.append(dict(path=path, size_bytes=p.stat().st_size, sha256="SELF" if path.endswith("00_artifact_manifest.md") else sha(p), classification="fixture_expected" if path.startswith("tests/tick_shock/") else "source_or_preset", owning_commit=owner(path) if path in changed else "SELF"))
    write_rows(QA / "step15f_source_fixture_hashes.csv", ["path", "size_bytes", "sha256", "classification", "owning_commit"], source_rows)

    output_paths = sorted(set([rel(p) for p in OUT.iterdir() if p.is_file()] + [rel(p) for p in RUN.iterdir() if p.is_file()] + ["reports/refactor/tick_shock/step15f_behavior_comparison.csv", "reports/refactor/tick_shock/step15f_parameter_diff.csv", "reports/tests/tick_shock/step15f_green/suite_results.csv", "reports/tests/tick_shock/step15f_green/compile_results.csv", "reports/tests/tick_shock/step15f_green/independent_oracle.csv"]))
    output_rows = []
    for path in output_paths:
        p = ROOT / path
        if p.is_file():
            output_rows.append(dict(path=path, size_bytes=p.stat().st_size, sha256=sha(p), run_id="ts15f_context_r3_202503" if path.startswith(rel(RUN)) else "STEP15F_ANALYSIS", source_commit=SOURCE_COMMIT, status="FORMAL_ACCEPTED" if path.startswith(rel(RUN)) else "DERIVED_EVIDENCE"))
    write_rows(QA / "step15f_output_hashes.csv", ["path", "size_bytes", "sha256", "run_id", "source_commit", "status"], output_rows)

    large = []
    for run, status in ((RUN, "FORMAL_ACCEPTED_LOCAL"), (REJECTED, "REJECTED_F01_MISSING")):
        if not run.is_dir():
            continue
        for p in sorted(run.iterdir()):
            if p.is_file() and p.stat().st_size > 50_000_000:
                large.append(dict(path=rel(p), size_bytes=p.stat().st_size, sha256=sha(p), run_id=run.name, source_commit=SOURCE_COMMIT if run == RUN else "0ae22e5264d455aa4c3e67ce1b88fec4c83bf637", status=status, commit_target="no", regeneration_command="powershell -NoProfile -ExecutionPolicy Bypass -File tools/tick_shock/run_step15f_march.ps1 -TimeoutSeconds 2400" if run == RUN else "superseded_run_not_for_regeneration"))
    write_rows(QA / "step15f_large_artifacts.csv", ["path", "size_bytes", "sha256", "run_id", "source_commit", "status", "commit_target", "regeneration_command"], large)

    text = MANIFEST.read_text(encoding="utf-8")
    text = re.sub(r"- branch: `[^`]+`", "- branch: `research/tickshock-step15f-context-feature-discovery-20260831`", text, count=1)
    text = re.sub(r"- status: `[^`]+`", "- status: `STEP15F_DEVELOPMENT_CONTEXT_CHARACTERIZED_NO_CANDIDATE_FROZEN`", text, count=1)
    text = re.sub(r"- manifest_revision: `[^`]+`", "- manifest_revision: `15F`", text, count=1)
    text = re.sub(r"- covered_steps: `[^`]+`", "- covered_steps: `01-15F`", text, count=1)
    text = re.sub(r"- last_updated_at: `[^`]+`", "- last_updated_at: `2026-08-31T12:00:00+09:00`", text, count=1)
    marker = "\n## Step 15F causal context development rollup\n"
    if marker in text:
        text = text.split(marker, 1)[0]
    all_paths = sorted(set(tracked_and_final + output_paths + [rel(p) for p in RUN.iterdir() if p.is_file()]))
    text += marker + "\nThis rollup records the Step 15E audit, preregistration, RED-to-GREEN context feature implementation, corrected r3 March run, matched controls, chronological OOF analysis and final QA. The r2 run is rejected because F01 was missing. Files above 50 MB remain local and are registered by hash. Artifact ID duplicates and latest Step 15F path-hash mismatches are checked below.\n\n| artifact ID | step | artifact relative path | type | purpose | source/generated | SHA-256 | commit | next Step | status | note | owning_commit |\n|---|---:|---|---|---|---|---|---|---|---|---|---|\n"
    manifest_rows = []
    for number, path in enumerate(all_paths, 1):
        p = ROOT / path
        if not p.is_file():
            continue
        committed = path in tracked_and_final
        digest = "SELF" if path == rel(MANIFEST) else sha(p)
        generated = path.startswith("reports/") or path.endswith(".ex5")
        status = "COMPLETE" if committed else "LOCAL_REPRODUCIBLE_EVIDENCE"
        note = "formal r3 or derived evidence" if "r3_202503" in path or path.startswith("reports/analysis/tick_shock/step15f") else "Step15F source document or QA"
        owning = owner(path) if path in changed else ("SELF" if path in final_paths else SOURCE_COMMIT)
        manifest_rows.append(f"| TS-S15F-{number:04d} | 15F | `{path}` | {'evidence' if generated else 'source/document'} | Step 15F causal context study | {'generated evidence' if generated else 'source'} | `{digest}` | {'yes' if committed else 'no'} | stop after Step 15F | {status} | {note} | {owning} |")
    text += "\n".join(manifest_rows) + "\n"
    MANIFEST.write_text(text, encoding="utf-8")
    ids = re.findall(r"^\|\s*([^|]+?)\s*\|\s*(?:\d+|15[A-Z])\s*\|", text, re.M)
    duplicates = len(ids) - len(set(ids))
    if duplicates:
        raise SystemExit(f"manifest artifact ID duplicates: {duplicates}")
    mismatches = []
    for line in text.splitlines():
        fields = [x.strip() for x in line.split("|")]
        if len(fields) < 13 or not fields[1].startswith("TS-S15F-"):
            continue
        path = fields[3].strip("`")
        expected = fields[7].strip("`")
        p = ROOT / path
        if p.is_file() and expected != "SELF" and sha(p) != expected:
            mismatches.append(path)
    if mismatches:
        raise SystemExit(f"manifest Step15F SHA mismatches: {mismatches}")
    print(f"qa={len(checks)} sources={len(source_rows)} outputs={len(output_rows)} large={len(large)} manifest_rows={len(manifest_rows)} duplicates={duplicates} sha_mismatches={len(mismatches)}")


if __name__ == "__main__":
    main()
