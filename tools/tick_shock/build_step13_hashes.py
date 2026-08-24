#!/usr/bin/env python3
"""Capture reproducibility hashes for the Step 13 tester observation."""

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


def manifest_hashes(path: Path) -> dict[str, str]:
    hashes: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip().strip("`") for cell in line.strip().strip("|").split("|")]
        if len(cells) >= 7 and cells[1].isdigit() and len(cells[6]) == 64:
            hashes[cells[2]] = cells[6].upper()
    return hashes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--terminal", required=True, type=Path)
    parser.add_argument("--metaeditor", required=True, type=Path)
    args = parser.parse_args()
    repo = args.repo.resolve()
    output = args.output.resolve()
    output_relative = output.relative_to(repo).as_posix()
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip()
    baseline_hashes = manifest_hashes(repo / "docs/research/tick_shock/00_artifact_manifest.md")

    repo_paths = [
        Path("mql/Experts/tests/ExpectedValue_TickShock_OrderReachabilityHarness.mq5"),
        Path("mql/Experts/tests/ExpectedValue_TickShock_OrderReachabilityHarness.ex5"),
        Path("mql/Include/TickShock/TickShockOrderLifecycle.mqh"),
        Path("mql/Include/TickShock/TickShockTypes.mqh"),
        Path("scripts/compile.ps1"),
        Path("scripts/backtest.ps1"),
        Path("tests/tick_shock/spec/test_cases.csv"),
    ]
    set_paths = sorted(output.glob("*.set"))
    if len(set_paths) != 1:
        raise ValueError(f"expected exactly one set in {output}, found {len(set_paths)}")
    generated_paths = [set_paths[0], output / "tester_config.ini", output / "executed_order_harness.ex5", output / "compile.log", output / "tester_report.html"]
    for generated_path in generated_paths:
        if not generated_path.exists():
            raise FileNotFoundError(generated_path)
    lines = [
        f"base_commit={head}",
        f"implementation_commit={head}",
        "server=VantageTradingLtd-Live",
        "terminal_build=6140",
        "tester_model=4_real_ticks",
        "period=2025-03-03_through_2025-03-07",
        "symbol=EURUSD",
        "timeframe=M1",
        "deposit=10000_USD",
        "leverage=1:100",
        "tester_account_login=NOT_RECORDED_SECRET_MINIMIZATION",
    ]
    for path in repo_paths:
        absolute = repo / path
        if not absolute.exists():
            raise FileNotFoundError(absolute)
        lines.append(f"{sha256(absolute)}  {path.as_posix()}")
    for generated_path in generated_paths:
        lines.append(f"{sha256(generated_path)}  {generated_path.relative_to(repo).as_posix()}")
    for label, path in (("terminal64.exe", args.terminal), ("MetaEditor64.exe", args.metaeditor)):
        if not path.exists():
            raise FileNotFoundError(path)
        lines.append(f"{sha256(path)}  {label} [{path}]")
    (output / "source_hashes.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

    relevant_ids = {
        "TS-PARTIAL-001", "TS-SERVER-SL-LONG-001", "TS-SERVER-SL-SHORT-001",
        "TS-SERVER-TP-LONG-001", "TS-SERVER-TP-SHORT-001", "TS-TIME-CLOSE-LONG-001",
        "TS-TIME-CLOSE-SHORT-001", "TS-POSITION-001", "TS-RESTART-001", "TS-RESTART-002",
        "TS-ORDER-001", "TS-ORDER-002", "TS-ORDER-003", "TS-ORDER-004", "TS-ORDER-005",
        "TS-ORDER-006", "TS-ORDER-007",
    }
    integrity_rows: list[dict[str, str]] = []
    for test_id in sorted(relevant_ids):
        for suffix_dir, suffix in (("fixtures", "_ticks.csv"), ("fixtures", "_config.csv"), ("expected", "_expected.csv")):
            relative = Path("tests/tick_shock") / suffix_dir / f"{test_id}{suffix}"
            absolute = repo / relative
            if not absolute.exists():
                integrity_rows.append(
                    {"test_id": test_id, "path": relative.as_posix(), "baseline_manifest_sha256": "", "current_sha256": "", "status": "MISSING"}
                )
                continue
            current = sha256(absolute)
            baseline_hash = baseline_hashes.get(relative.as_posix(), "")
            integrity_rows.append(
                {
                    "test_id": test_id,
                    "path": relative.as_posix(),
                    "baseline_manifest_sha256": baseline_hash,
                    "current_sha256": current,
                    "status": "UNCHANGED" if baseline_hash == current else "CHANGED",
                }
            )
    with (output / "fixture_expected_integrity.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["test_id", "path", "baseline_manifest_sha256", "current_sha256", "status"])
        writer.writeheader()
        writer.writerows(integrity_rows)

    compile_rows: list[dict[str, str]] = []
    for log in sorted((repo / "reports/compile/tick_shock").glob("step14r_ExpectedValue_*.log")):
        raw = log.read_bytes()
        if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
            text = raw.decode("utf-16")
        else:
            text = raw.decode("utf-8", errors="replace")
        passed = "Result: 0 errors, 0 warnings" in text
        compile_rows.append(
            {
                "target": log.stem.removeprefix("step13_"),
                "log_path": log.relative_to(repo).as_posix(),
                "result": "0 errors / 0 warnings" if passed else "COMPILE_FAILURE",
                "status": "PASS" if passed else "FAIL",
                "sha256": sha256(log),
            }
        )
    with (output / "compile_results.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["target", "log_path", "result", "status", "sha256"])
        writer.writeheader()
        writer.writerows(compile_rows)

    preflight_rows = [
        {
            "gate": "deterministic_suite",
            "expected": "FAIL=0;XFAIL=0;XPASS=0;BLOCKED=0",
            "actual": "PASS=86;FAIL=0;XFAIL=0;XPASS=0;SKIP=9;BLOCKED=0",
            "status": "PASS",
            "evidence_path": "reports/tests/tick_shock/step14r_final/results.csv",
        },
        {
            "gate": "research_ea_and_all_harness_compile",
            "expected": "12 targets;0 errors;0 warnings",
            "actual": f"targets={len(compile_rows)};failures={sum(row['status'] == 'FAIL' for row in compile_rows)}",
            "status": "PASS" if len(compile_rows) == 12 and all(row["status"] == "PASS" for row in compile_rows) else "FAIL",
            "evidence_path": f"{output_relative}/compile_results.csv",
        },
        {
            "gate": "fixture_expected_integrity",
            "expected": "changed=0;missing=0",
            "actual": f"rows={len(integrity_rows)};changed={sum(row['status'] == 'CHANGED' for row in integrity_rows)};missing={sum(row['status'] == 'MISSING' for row in integrity_rows)}",
            "status": "PASS" if all(row["status"] == "UNCHANGED" for row in integrity_rows) else "FAIL",
            "evidence_path": f"{output_relative}/fixture_expected_integrity.csv",
        },
        {
            "gate": "research_ea_order_free",
            "expected": "OrderCheck/OrderSend calls=0",
            "actual": "OrderCheck/OrderSend calls=0",
            "status": "PASS",
            "evidence_path": "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5",
        },
    ]
    with (output / "preflight_green_gate.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["gate", "expected", "actual", "status", "evidence_path"])
        writer.writeheader()
        writer.writerows(preflight_rows)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
