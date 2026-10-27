"""Check native event accounting independently of MQL assertion booleans."""
from pathlib import Path
import csv
import hashlib
import json

ROOT = Path(__file__).resolve().parent
latest = json.loads((ROOT / "native_latest.json").read_text(encoding="utf-8-sig"))
assert latest["status"] == "PASS"
cases = {}
checks = []

def require(name, condition, detail=None):
    checks.append({"check": name, "passed": bool(condition), "detail": detail})
    assert condition, name

for case in latest["cases"]:
    directory = Path(case["output"])
    with (directory / (case["tag"] + "_events.csv")).open(encoding="utf-8-sig", newline="") as stream:
        events = list(csv.DictReader(stream, delimiter=";"))
    signals = [e for e in events if e["event_type"] == "SIGNAL"]
    skips = [e for e in events if e["event_type"] == "SKIP"]
    require(case["case"] + ": no native ORDER/FILL", not any(e["event_type"] in {"ORDER", "FILL"} for e in events))
    require(case["case"] + ": no requested-order timestamps", all(not e["order_sent_at"] and not e["fill_at"] for e in signals + skips))
    require(case["case"] + ": no other exclusion", all(e["reason"] == "CHOPPY_WAVE1" and e["reason_kind"] == "EXCLUSION" for e in skips))
    require(case["case"] + ": zero rejected release calls", not any(e["event_type"] == "CHOP_FINISH_REJECTED" for e in events))
    if case["filter"]:
        rejected = [e for e in signals if e["entry_status"] == "SIGNAL_RISK_REJECTED"]
        require(case["case"] + ": filtered SIGNAL suppresses ENTRY", len(rejected) == 4, len(rejected))
        measurements = [e for e in events if e["event_type"] == "CHOP_ENTRY_FILTER"]
        require(case["case"] + ": four measured skips", sum("outcome=SKIP" in e["reason"] for e in measurements) == 4)
        if not case["orders_input"]:
            require(case["case"] + ": four unavailable explicitly allowed", sum("outcome=ALLOW_UNAVAILABLE" in e["reason"] and "missing_policy=ALLOW" in e["reason"] for e in measurements) == 4)
    cases[case["case"]] = events

economic_fields = ["event_type", "setup_id", "upper_tf", "lower_tf", "direction", "entry_price", "sl_price", "tp_price", "risk_points", "intended_rr", "actual_rr", "entry_status", "skip_reason", "order_sent_at", "fill_at"]
selected_events = {"SIGNAL", "RISK_CHECK", "TP_WAVE1_EXTENDED", "ORDER_DISABLED"}
def projection(events):
    return [tuple(e[field] for field in economic_fields) for e in events if e["event_type"] in selected_events]
require("filter OFF diagnostics ON/OFF economic event identity", projection(cases["off_diag_on"]) == projection(cases["off_diag_off"]), len(projection(cases["off_diag_on"])))
require("filter ON diagnostics ON/OFF economic event identity", projection(cases["on_diag_on"]) == projection(cases["on_diag_off"]), len(projection(cases["on_diag_on"])))
for field in ["entry_price", "sl_price", "tp_price", "risk_points", "intended_rr", "actual_rr"]:
    left = [e[field] for e in cases["off_diag_on"] if e["event_type"] == "SIGNAL"]
    right = [e[field] for e in cases["on_diag_on"] if e["event_type"] == "SIGNAL"]
    require("toggle preserves planned " + field, left == right)

out = {"status": "PASS", "checks": len(checks), "native_batch": latest["batch"], "assertions": sum(c["checks"] for c in latest["cases"]), "failures": 0, "checks_detail": checks,
       "scope": "Synthetic real-EA wrapper; genuine current tester quote used by actual Plan/HandleSignal; no market-period performance inference, screenshot or tooltip-readback claim."}
(ROOT / "native_event_audit.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: out[k] for k in ["status", "checks", "assertions", "failures", "native_batch"]}))
