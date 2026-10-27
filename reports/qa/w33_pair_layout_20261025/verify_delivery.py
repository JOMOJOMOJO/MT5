"""Check final delivery integrity; no profitability inference."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]

def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

baseline = read(ROOT / "baseline.json")
integrity = []
for row in baseline["before"]:
    assert sha(ROOT / "before" / Path(row["path"]).name) == row["sha256"]
    changed = sha(REPO / row["path"]) != row["sha256"]
    intentional = row["path"] in baseline["intentional_changes"]
    assert not changed or intentional, row["path"]
    integrity.append({"path": row["path"], "changed": changed, "intentional": intentional})

ea = REPO / "mql/Experts/Wave33ChopDiagnostic.mq5"
source = ea.read_text(encoding="utf-8-sig")
inputs = dict(re.findall(r"^input\s+\w+\s+(\w+)=(.*?);", source, re.M))
assert len(inputs) == 44
assert inputs["InpSkipBothConnectedWave1"] == "true"
assert inputs["InpReadableLabels"] == "true"
assert inputs["InpEnableTesterOrders"] == "false"
assert inputs["InpSkipPriorLevelRetest"] == "false"
presets = []
for arm in ("A", "B"):
    pair = {}
    for mode in ("On", "Off"):
        path = REPO / f"presets/wave33/Wave33Pair_v184_{arm}_Both{mode}.set"
        values = dict(line.split("=", 1) for line in path.read_text(encoding="utf-8-sig").splitlines())
        assert values.keys() == inputs.keys()
        assert values["InpEnableTesterOrders"] == "true"
        assert values["InpReadableLabels"] == "true"
        assert values["InpSkipBothConnectedWave1"] == ("true" if mode == "On" else "false")
        assert values["InpSkipChoppyWave1"] == values["InpSkipPriorLevelRetest"] == "false"
        pair[mode] = values
        presets.append({"path": str(path.relative_to(REPO)), "inputs": len(values), "sha256": sha(path)})
    assert {key for key in pair["On"] if pair["On"][key] != pair["Off"][key]} == {"InpRunTag", "InpSkipBothConnectedWave1"}

assert "Result: 0 errors, 0 warnings" in (ROOT / "compile/Wave33ChopDiagnostic.log").read_text(encoding="utf-16")
native = read(ROOT / "native_latest.json")
display = read(ROOT / "display_latest.json")
event_audit = read(ROOT / "native_event_audit.json")
assert native["status"] == display["status"] == event_audit["status"] == "PASS"
assert display["mode"] == "NORMAL_CHART_LAYOUT_FIXTURE" and display["failures"] == 0
for manifest in (native,):
    assert all(case["status"] == "PASS" and case["failures"] == 0 for case in manifest["cases"])
    for key, path in {
        "ea_source_sha256": "mql/Experts/Wave33ChopDiagnostic.mq5",
        "harness_source_sha256": "mql/Experts/tests/Wave33PairLayoutHarness.mq5",
        "harness_ex5_sha256": "mql/Experts/tests/Wave33PairLayoutHarness.ex5",
    }.items():
        assert manifest[key] == sha(REPO / path), (key, manifest["batch"])
for path, expected in display["source_hashes"].items():
    assert expected == sha(REPO / path), path
assert read(ROOT / "audit/connected_pair_source_review.json")["result"] == "PASS"
assert read(ROOT / "audit/label_source_review.json")["result"] == "PASS"
images = []
for item in display["screenshots"]:
    path = Path(item["path"])
    assert sha(path) == item["sha256"]
    images.append(str(path.relative_to(ROOT)))
assert len(images) == 2 and any(path.endswith("_dense_before.png") for path in images) and any(path.endswith("_dense_after.png") for path in images)
artifacts = ["mql/Experts/Wave33ChopDiagnostic.mq5", "mql/Experts/Wave33ChopDiagnostic.ex5",
             "mql/Include/Wave33Visual/Engine.mqh", "mql/Include/Wave33Visual/ConnectedPair.mqh",
             "mql/Include/Wave33Visual/ChopDisplay.mqh", "mql/Include/Wave33Visual/LabelLayout.mqh",
             "mql/Experts/tests/Wave33PairLayoutHarness.mq5", "mql/Experts/tests/Wave33PairLayoutHarness.ex5",
             "mql/Experts/tests/Wave33LabelReplay.mq5", "mql/Experts/tests/Wave33LabelReplay.ex5"]
out = {"status": "PASS", "version": "1.84", "integrity": integrity, "presets": presets,
       "native_batch": native["batch"], "display_output": display["output"], "display_mode": display["mode"],
       "native_assertions": event_audit["native_assertions"], "visual_assertions": event_audit["visual_assertions"],
       "independent_csv_checks": event_audit["checks"], "failures": 0,
       "all_column_parity_event_rows": event_audit["all_column_parity_event_rows"],
       "screenshots": images, "artifact_sha256": {path: sha(REPO / path) for path in artifacts},
       "scope": "Engineering, causal fixtures and native visual drawing. Not annual strategy profitability."}
(ROOT / "final_verification.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({key: out[key] for key in ("status", "version", "native_assertions", "visual_assertions", "independent_csv_checks", "failures")}))
