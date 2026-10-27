"""Freeze a reviewed build only after native QA and independent deal audit pass."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main():
    checks = []

    def check(name, ok, detail=None):
        checks.append({"name": name, "pass": bool(ok), "detail": detail})

    baseline = read_json(HERE / "baseline.json")
    for item in baseline["before"]:
        if item["path"] not in baseline["intentional_changes"]:
            check("preserved:" + item["path"], digest(ROOT / item["path"]) == item["sha256"])
    source = ROOT / "mql/Experts/Wave33ChopDiagnostic.mq5"
    binary = source.with_suffix(".ex5")
    native = read_json(HERE / "native_latest.json")
    audit = read_json(HERE / "native_event_audit.json")
    check("native_six_cases_pass", native["status"] == "PASS" and len(native["cases"]) == 6)
    check("native_no_assertion_failure", all(c["failures"] == 0 for c in native["cases"]))
    check("independent_deal_audit_pass", audit.get("status") == "PASS", audit.get("failures"))
    check("independent_audit_same_batch", audit.get("batch") == native["batch"])
    check("native_uses_current_main", native["ea_source_sha256"] == digest(source))
    check("native_uses_current_policy", native["policy_sha256"] == digest(ROOT / "mql/Include/Wave33Visual/ScaleOut.mqh"))
    # The final runner records the adapter separately because it owns the stateful execution path.
    adapter_hash = digest(ROOT / "mql/Include/Wave33Visual/ScaleOutExecution.mqh")
    check("native_uses_current_execution_adapter", native.get("execution_source_sha256") == adapter_hash)
    display = read_json(HERE / "display_latest.json")
    check("changed_risk_label_timing_pass", display["status"] == "PASS" and display["failures"] == 0)
    check("display_uses_current_layout", display["source_hashes"]["mql/Include/Wave33Visual/LabelLayout.mqh"] == digest(ROOT / "mql/Include/Wave33Visual/LabelLayout.mqh"))
    check("native_uses_current_layout", native["source_hashes"].get("mql/Include/Wave33Visual/LabelLayout.mqh") == digest(ROOT / "mql/Include/Wave33Visual/LabelLayout.mqh"))
    log = HERE / "compile/Wave33ChopDiagnostic.log"
    compile_text = log.read_text(encoding="utf-16")
    check("compile_zero_errors_warnings", "Result: 0 errors, 0 warnings" in compile_text)
    check("binary_newer_than_sources", binary.stat().st_mtime >= max(p.stat().st_mtime for p in [source, *(ROOT / "mql/Include/Wave33Visual").glob("*.mqh")]))
    failed = [c["name"] for c in checks if not c["pass"]]
    result = {"status": "FAIL" if failed else "PASS", "checks": checks, "failed": failed,
              "native_batch": native["batch"], "assertions": sum(c["checks"] for c in native["cases"]),
              "display_checks": display["checks"], "independent_csv_checks": audit["checks"],
              "ea_source_sha256": digest(source), "ea_binary_sha256": digest(binary),
              "account_scope": "Native RETAIL_HEDGING; netting API path reviewed, no native netting claim."}
    (HERE / "final_verification.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    if failed:
        raise SystemExit("Final verification failed: " + ", ".join(failed))
    manifest = {"qa_status": "PASS", "ea_version": "1.85", "source_sha256": digest(source),
                "binary_sha256": digest(binary), "header_sha256": {},
                "qa_evidence": "reports/qa/w33_scaleout_20261026/final_verification.json"}
    for header in sorted((ROOT / "mql/Include/Wave33Visual").glob("*.mqh")):
        manifest["header_sha256"]["Wave33Visual/" + header.name] = digest(header)
    (ROOT / "reports/backtest/runs/wave33_v185_2020/deployment.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps({"status": result["status"], "checks": len(checks), "assertions": result["assertions"]}))


if __name__ == "__main__":
    main()
