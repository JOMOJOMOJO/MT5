#!/usr/bin/env python3
"""Build deterministic Step 14R change, parameter, and source-hash evidence."""

from __future__ import annotations

import argparse
import csv
import hashlib
import subprocess
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def git_lines(repo: Path, *args: str) -> list[str]:
    output = subprocess.check_output(["git", *args], cwd=repo, text=True)
    return [line for line in output.splitlines() if line]


def read_set(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        if "=" not in raw or raw.lstrip().startswith("#"):
            continue
        key, value = raw.split("=", 1)
        result[key.strip()] = value.strip()
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--base-commit", default="43c4f93ce072c618db92a596e45278cb1d61e96c")
    parser.add_argument("--baseline-set", type=Path, required=True)
    parser.add_argument("--current-set", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("reports/qa/tick_shock"))
    args = parser.parse_args()
    repo = args.repo.resolve()
    output = (repo / args.output).resolve() if not args.output.is_absolute() else args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    changed = sorted(set(
        git_lines(repo, "diff", "--name-only", f"{args.base_commit}..HEAD")
        + git_lines(repo, "diff", "--name-only")
        + git_lines(repo, "diff", "--cached", "--name-only")
        + git_lines(repo, "ls-files", "--others", "--exclude-standard")
    ))
    scoped_generated = []
    for relative_root in (
        "reports/backtest/runs/20260825_ts14r3_ideal_202503",
        "reports/backtest/runs/20260825_ts14r3_realizable_202503",
        "reports/backtest/runs/20260825_ts14r3_comparison_202503",
        "reports/tests/tick_shock/step14r_final",
        "reports/tests/tick_shock/step14r_order_observation_final",
    ):
        scoped_generated.extend(path.relative_to(repo).as_posix() for path in (repo / relative_root).rglob("*") if path.is_file())
    scoped_generated.extend(path.relative_to(repo).as_posix() for path in (repo / "reports/compile/tick_shock").glob("step14r_ExpectedValue_*.log"))
    changed = sorted(set(changed + scoped_generated))
    change_rows = []
    for relative in changed:
        path = repo / relative
        change_rows.append({
            "path": relative,
            "classification": "production_source" if relative.startswith("mql/") else ("test_spec_or_source" if relative.startswith("tests/") else ("validation_tool" if relative.startswith("tools/") else "evidence_or_document")),
            "sha256": sha256(path) if path.is_file() else "GENERATED_OR_DELETED",
            "base_commit": args.base_commit,
            "head_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
        })
    with (output / "step14r_changed_files.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(change_rows[0]))
        writer.writeheader(); writer.writerows(change_rows)

    baseline_path = (repo / args.baseline_set).resolve() if not args.baseline_set.is_absolute() else args.baseline_set.resolve()
    current_path = (repo / args.current_set).resolve() if not args.current_set.is_absolute() else args.current_set.resolve()
    baseline = read_set(baseline_path); current = read_set(current_path)
    provenance_keys = {
        "InpRunId", "InpLogFolder", "InpSourceCommit", "InpEx5Hash",
        "InpCommissionSource", "InpCommissionEvidenceStatus", "InpCommissionSymbolScope", "InpCommissionUnit",
    }
    parameter_rows = []
    for key in sorted(set(baseline) | set(current)):
        old = baseline.get(key, "<MISSING>"); new = current.get(key, "<MISSING>")
        classification = "provenance_or_evidence" if key in provenance_keys else "strategy_or_execution_parameter"
        unchanged_required = classification == "strategy_or_execution_parameter"
        status = "UNCHANGED" if old == new else ("ALLOWED_PROVENANCE_CHANGE" if not unchanged_required else "UNINTENDED_CHANGE")
        parameter_rows.append({"parameter": key, "baseline": old, "current": new, "classification": classification, "status": status})
    with (output / "step14r_strategy_parameter_comparison.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(parameter_rows[0]))
        writer.writeheader(); writer.writerows(parameter_rows)

    source_paths = [
        Path("mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5"),
        *sorted(Path("mql/Include/TickShock").glob("*.mqh")),
        Path("mql/Include/TickShockStateMachine.mqh"),
        Path("mql/Include/TickShockResearchExecution.mqh"),
        *sorted(Path("mql/Experts/tests").glob("ExpectedValue_TickShock_*Harness.mq5")),
        *sorted(Path("mql/Experts/tests").glob("TickShock*.mqh")),
        Path("tests/tick_shock/spec/test_cases.csv"),
    ]
    lines = [
        f"base_commit={args.base_commit}",
        f"current_commit={subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()}",
    ]
    for relative in source_paths:
        path = repo / relative
        if path.is_file():
            lines.append(f"{sha256(path)}  {relative.as_posix()}")
    (output / "step14r_source_hashes.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

    bad_parameters = [row for row in parameter_rows if row["status"] == "UNINTENDED_CHANGE"]
    print(f"changed_files={len(change_rows)} parameter_rows={len(parameter_rows)} unintended_parameter_changes={len(bad_parameters)}")
    return 1 if bad_parameters else 0


if __name__ == "__main__":
    raise SystemExit(main())
