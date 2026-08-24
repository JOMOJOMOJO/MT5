#!/usr/bin/env python3
"""Exercise fail-closed reconciliation with intentionally corrupt evidence."""
from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


CASES = (
    "missing_required_column", "blank_required_value", "nonnumeric_value", "nan_value", "infinity_value",
    "unknown_enum", "duplicate_event_id", "orphan_symbol", "truncated_csv", "source_hash_mismatch",
    "baseline_missing", "current_missing",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def copy_run(source: Path, destination: Path, repo_root: Path) -> None:
    destination.mkdir(parents=True)
    names = [
        "events.csv", "summary.csv", "symbol_specs.csv", "tick_quality.csv", "trades.csv",
        "events.csv.runmeta", "summary.csv.runmeta", "symbol_specs.csv.runmeta", "trades.csv.runmeta",
        "source_hashes.txt", "tester_config.ini",
    ]
    set_path = next(source.glob("*.set"))
    for name in names:
        shutil.copy2(source / name, destination / name)
    shutil.copy2(set_path, destination / set_path.name)
    hashes_path = destination / "source_hashes.txt"
    lines = hashes_path.read_text(encoding="utf-8-sig").splitlines()
    source_key = "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5"
    current_hash = sha256(repo_root / source_key)
    lines = [f"{source_key}|{current_hash}" if line.startswith(source_key + "|") else line for line in lines]
    hashes_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def rewrite_csv(path: Path, mutate) -> None:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle); rows = list(reader); fields = list(reader.fieldnames or [])
    fields, rows = mutate(fields, rows)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields);writer.writeheader();writer.writerows(rows)


def corrupt(case: str, run_dir: Path) -> None:
    events = run_dir / "events.csv"
    if case == "missing_required_column":
        rewrite_csv(events, lambda f, r: ([x for x in f if x != "detection_time_msc"], [{k:v for k,v in row.items() if k != "detection_time_msc"} for row in r]))
    elif case == "blank_required_value":
        rewrite_csv(events, lambda f, r: (f, [dict(row, detector_window_ms="") if i == 0 else row for i,row in enumerate(r)]))
    elif case == "nonnumeric_value":
        rewrite_csv(events, lambda f, r: (f, [dict(row, detection_time_msc="not-a-number") if i == 0 else row for i,row in enumerate(r)]))
    elif case == "nan_value":
        rewrite_csv(events, lambda f, r: (f, [dict(row, robust_z="NaN") if i == 0 else row for i,row in enumerate(r)]))
    elif case == "infinity_value":
        rewrite_csv(events, lambda f, r: (f, [dict(row, efficiency="Infinity") if i == 0 else row for i,row in enumerate(r)]))
    elif case == "unknown_enum":
        rewrite_csv(events, lambda f, r: (f, [dict(row, direction="SIDEWAYS") if i == 0 else row for i,row in enumerate(r)]))
    elif case == "duplicate_event_id":
        rewrite_csv(events, lambda f, r: (f, r + [dict(r[0])]))
    elif case == "orphan_symbol":
        rewrite_csv(events, lambda f, r: (f, [dict(row, symbol="ORPHAN") if i == 0 else row for i,row in enumerate(r)]))
    elif case == "truncated_csv":
        events.write_text("event_id,execution_mode\n", encoding="utf-8")
    elif case == "source_hash_mismatch":
        path = run_dir / "source_hashes.txt"
        text = path.read_text(encoding="utf-8")
        text = text.replace("mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5|", "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5|BAD", 1)
        path.write_text(text, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--ideal-source", type=Path, required=True)
    parser.add_argument("--realizable-source", type=Path, required=True)
    parser.add_argument("--baseline-source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--git-ref", default="")
    args = parser.parse_args();root=args.repo_root.resolve()
    if args.git_ref:
        source = subprocess.run(["git", "show", f"{args.git_ref}:tools/tick_shock/reconcile_causal_runs.py"], cwd=root, text=True, capture_output=True, check=True).stdout
        strict_api = "def strict_validate_run(" in source and "def atomic_write_text(" in source
        rows = [{"case": case, "expected": "REJECT_NONZERO_NO_OUTPUT", "actual": "NO_STRICT_VALIDATOR_API" if not strict_api else "STRICT_API_PRESENT", "exit_code": "", "pass_artifacts": "", "status": "XFAIL" if not strict_api else "XPASS"} for case in CASES]
    else:
        rows=[]
        with tempfile.TemporaryDirectory(prefix="tickshock_step14r_validator_") as temporary:
            base=Path(temporary)
            for case in CASES:
                case_dir=base/case;ideal=case_dir/"ideal";realizable=case_dir/"realizable";baseline=case_dir/"baseline";comparison=case_dir/"comparison"
                if case != "current_missing": copy_run(args.ideal_source,ideal,root)
                copy_run(args.realizable_source,realizable,root)
                if case != "baseline_missing":
                    baseline.mkdir(parents=True);shutil.copy2(args.baseline_source/"events.csv",baseline/"events.csv");shutil.copy2(args.baseline_source/"summary.csv",baseline/"summary.csv")
                if case not in {"baseline_missing", "current_missing"}: corrupt(case,ideal)
                command=[sys.executable,str(root/"tools/tick_shock/reconcile_causal_runs.py"),"--ideal-dir",str(ideal),"--realizable-dir",str(realizable),"--baseline-dir",str(baseline),"--comparison-dir",str(comparison)]
                proc=subprocess.run(command,cwd=root,text=True,capture_output=True)
                artifacts=sum(1 for p in comparison.rglob("*") if p.is_file()) if comparison.exists() else 0
                passed=proc.returncode!=0 and artifacts==0
                rows.append({"case":case,"expected":"REJECT_NONZERO_NO_OUTPUT","actual":(proc.stderr or proc.stdout).strip().replace("\n"," | ")[:1000],"exit_code":proc.returncode,"pass_artifacts":artifacts,"status":"PASS" if passed else "FAIL"})
    args.output.parent.mkdir(parents=True,exist_ok=True)
    with args.output.open("w",encoding="utf-8",newline="") as handle:
        writer=csv.DictWriter(handle,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    counts={status:sum(row["status"]==status for row in rows) for status in ("PASS","FAIL","XFAIL","XPASS")}
    print(" ".join(f"{key}={value}" for key,value in counts.items()))
    return 1 if counts["FAIL"] or counts["XPASS"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
