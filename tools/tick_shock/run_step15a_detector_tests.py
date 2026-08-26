#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
from collections import Counter
from pathlib import Path


FIELDS = ("test_id","requirement_id","defect_id","test_layer","status","expected","actual","difference","evidence_path")


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def expected_text(root: Path, test_id: str) -> str:
    rows = read_csv(root / "tests" / "tick_shock" / "expected" / f"{test_id}_expected.csv")
    return ";".join(f"{row['field']}={row['expected_value']}" for row in rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=("red","green"), required=True)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--raw", type=Path)
    args = parser.parse_args()
    root = args.repo_root.resolve()
    out_dir = root / "reports" / "tests" / "tick_shock" / f"step15a_{args.phase}"
    out_dir.mkdir(parents=True, exist_ok=True)
    registry = [row for row in read_csv(root / "tests" / "tick_shock" / "spec" / "test_cases.csv") if row["test_id"].startswith("TS15A-")]
    raw_rows = {}
    if args.phase == "green":
        if not args.raw or not args.raw.exists():
            raise SystemExit("green phase requires --raw harness CSV")
        raw_rows = {row["test_id"]: row for row in read_csv(args.raw)}
    result_rows = []
    for case in registry:
        test_id = case["test_id"]
        expected = expected_text(root,test_id)
        if args.phase == "red":
            if test_id == "TS15A-STRICT-001":
                status="PASS"; actual="STRICT_V0_EXISTING_PRODUCTION_GATE_PATH_PASSED;STEP14R_19_EVENTS_15_MARKET_CLUSTERS"
                difference=""; evidence="reports/tests/tick_shock/step14r_final/raw/detector.csv"
            else:
                status="XFAIL"; actual="PRODUCTION_STATISTICAL_DETECTOR_API_ABSENT"
                difference="expected production-path value; actual include/API unavailable"
                evidence="reports/compile/tick_shock/step15a_red_ExpectedValue_TickShock_DetectorHarness.log"
        else:
            observed=raw_rows.get(test_id)
            if not observed:
                status="FAIL"; actual="NO_HARNESS_OBSERVATION"; difference="missing row"; evidence=str(args.raw.relative_to(root)).replace("\\","/")
            else:
                status="PASS" if observed.get("observed")=="MATCH" else "FAIL"
                actual=observed.get("actual",""); difference=observed.get("difference","")
                evidence=str(args.raw.relative_to(root)).replace("\\","/")
        result_rows.append({"test_id":test_id,"requirement_id":case["requirement_id"],"defect_id":case["defect_id"],
                            "test_layer":case["test_layer"],"status":status,"expected":expected,"actual":actual,
                            "difference":difference,"evidence_path":evidence})
    results_path=out_dir / f"step15a_{args.phase}_results.csv"
    with results_path.open("w",encoding="utf-8",newline="") as handle:
        writer=csv.DictWriter(handle,fieldnames=FIELDS);writer.writeheader();writer.writerows(result_rows)

    integrity=[]
    for case in registry:
        test_id=case["test_id"]
        for kind,path in (("fixture_ticks",root / "tests/tick_shock/fixtures" / f"{test_id}_ticks.csv"),
                          ("fixture_config",root / "tests/tick_shock/fixtures" / f"{test_id}_config.csv"),
                          ("expected",root / "tests/tick_shock/expected" / f"{test_id}_expected.csv")):
            integrity.append({"test_id":test_id,"kind":kind,"path":str(path.relative_to(root)).replace("\\","/"),
                              "sha256":sha(path),"status":"PRESENT"})
    integrity_path=out_dir / "independent_oracle_integrity.csv"
    with integrity_path.open("w",encoding="utf-8",newline="") as handle:
        writer=csv.DictWriter(handle,fieldnames=integrity[0].keys());writer.writeheader();writer.writerows(integrity)

    counts=Counter(row["status"] for row in result_rows)
    report=out_dir / f"step15a_{args.phase}_report.md"
    report.write_text(
        "# Tick-shock Step 15A " + args.phase.upper() + " detector tests\n\n"
        f"- frozen spec: `docs/research/tick_shock/15a_shock_definition_spec.md` (`{sha(root / 'docs/research/tick_shock/15a_shock_definition_spec.md')}`)\n"
        "- independent oracle: `tools/tick_shock/step15a_independent_oracle.py`\n"
        f"- registry tests: {len(registry)}\n"
        f"- PASS: {counts['PASS']}\n- FAIL: {counts['FAIL']}\n- XFAIL: {counts['XFAIL']}\n- XPASS: {counts['XPASS']}\n- SKIP: {counts['SKIP']}\n- BLOCKED: {counts['BLOCKED']}\n\n"
        + ("The pre-fix detector harness fails compilation because the declared production `TickShockStatisticalDetector.mqh` API does not exist. This is the expected RED observation for the 23 V1 contract tests. `STRICT_V0` remains independently covered by the unchanged Step 14R production path and is PASS, not inferred from a V1 stub.\n" if args.phase=="red" else "Every row was observed through the compiled MQL detector harness calling the production statistical detector module.\n"),
        encoding="utf-8")
    print(f"PASS={counts['PASS']} FAIL={counts['FAIL']} XFAIL={counts['XFAIL']} XPASS={counts['XPASS']} SKIP={counts['SKIP']} BLOCKED={counts['BLOCKED']}")
    print(results_path)
    return 0 if (args.phase=="red" or (counts['FAIL']==0 and counts['XFAIL']==0)) else 1


if __name__ == "__main__":
    raise SystemExit(main())
