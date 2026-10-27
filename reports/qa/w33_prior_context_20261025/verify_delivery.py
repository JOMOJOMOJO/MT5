"""Delivery integrity only. Does not infer market profitability."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

baseline = read(ROOT / "baseline.json")
protected = [{"path": row["path"], "unchanged": sha(REPO / row["path"]) == row["sha256"]}
             for row in baseline["protected"]]
assert all(row["unchanged"] for row in protected)
for row in baseline["snapshots"]:
    assert sha(ROOT / "before" / Path(row["path"]).name) == row["sha256"]

ea = REPO / "mql/Experts/Wave33ChopDiagnostic.mq5"
text = ea.read_text(encoding="utf-8-sig")
inputs = dict(re.findall(r"^input\s+\w+\s+(\w+)=(.*?);", text, re.M))
assert len(inputs) == 42
assert inputs["InpSkipPriorLevelRetest"] == "false"
assert inputs["InpEnableTesterOrders"] == "false"
assert inputs["InpPriorContext"] == "true"
assert inputs["InpPriorContextBandFraction"] == "0.05"
assert '#property version "1.83"' in text

preset_results = []
for arm in ("A", "B"):
    pair = {}
    for mode in ("On", "Off"):
        path = REPO / f"presets/wave33/Wave33Context_v183_{arm}_Filter{mode}.set"
        values = dict(line.split("=", 1) for line in path.read_text(encoding="utf-8-sig").splitlines())
        assert values.keys() == inputs.keys()
        assert values["InpEnableTesterOrders"] == "true"
        assert values["InpSkipChoppyWave1"] == "false"
        assert values["InpPriorContextBandFraction"] == "0.05"
        assert values["InpSkipPriorLevelRetest"] == ("true" if mode == "On" else "false")
        pair[mode] = values
        preset_results.append({"file": str(path.relative_to(REPO)), "inputs": len(values), "sha256": sha(path)})
    assert {key for key in pair["On"] if pair["On"][key] != pair["Off"][key]} == {"InpRunTag", "InpSkipPriorLevelRetest"}

for log in (ROOT / "compile/Wave33ChopDiagnostic.log", ROOT / "compile_harness.log"):
    assert "Result: 0 errors, 0 warnings" in log.read_text(encoding="utf-16")

latest = read(ROOT / "native_latest.json")
run = read(Path(latest["output"]) / "result.json")
assert latest["status"] == "PASS" and run["status"] == "PASS"
for key, path in {
    "harness_source_sha256": "mql/Experts/tests/Wave33PriorContextHarness.mq5",
    "ea_source_sha256": "mql/Experts/Wave33ChopDiagnostic.mq5",
    "harness_ex5_sha256": "mql/Experts/tests/Wave33PriorContextHarness.ex5",
    "context_source_sha256": "mql/Include/Wave33Visual/PriorContext.mqh",
}.items():
    assert run[key] == sha(REPO / path), key
audit = read(ROOT / "native_event_audit.json")
assert audit["status"] == "PASS" and audit["native_batch"] == latest["batch"]
assert all(row["status"] == "PASS" and row["failures"] == 0 for row in latest["cases"])
chop_old = ROOT / "before/Chop.mqh"
assert sha(chop_old) == sha(REPO / "mql/Include/Wave33Visual/Chop.mqh")

artifacts = ["mql/Experts/Wave33ChopDiagnostic.mq5", "mql/Experts/Wave33ChopDiagnostic.ex5",
             "mql/Include/Wave33Visual/PriorContext.mqh", "mql/Include/Wave33Visual/ChopDisplay.mqh",
             "mql/Experts/tests/Wave33PriorContextHarness.mq5", "mql/Experts/tests/Wave33PriorContextHarness.ex5"]
out = {"status": "PASS", "version": "1.83", "native_batch": latest["batch"],
       "native_assertions": sum(row["checks"] for row in latest["cases"]),
       "native_event_audit_checks": audit["checks"], "failures": 0,
       "protected": protected, "chop_unchanged": True, "presets": preset_results,
       "artifact_sha256": {path: sha(REPO / path) for path in artifacts},
       "scope": "Engineering and causal classifier fixtures only; no annual, profitability, OOS or visual appearance gate"}
(ROOT / "final_verification.json").write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps({key: out[key] for key in ("status", "version", "native_assertions", "native_event_audit_checks", "failures", "native_batch")}))
