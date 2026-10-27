"""Independent native event/CSV accounting; fixtures are not an annual backtest."""
from pathlib import Path
import csv
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
latest = json.loads((ROOT / "native_latest.json").read_text(encoding="utf-8-sig"))
assert latest["status"] == "PASS"
checks = []
cases = {}

def require(name, condition, detail=None):
    checks.append({"check": name, "passed": bool(condition), "detail": detail})
    assert condition, name

def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream, delimiter=";"))

for case in latest["cases"]:
    directory = Path(case["output"])
    events_path = directory / (case["tag"] + "_events.csv")
    events = read_csv(events_path) if events_path.exists() else []
    require(case["case"] + ": no native ORDER/FILL", not any(e["event_type"] in {"ORDER", "FILL"} for e in events))
    require(case["case"] + ": no order timestamps", all(not e["order_sent_at"] and not e["fill_at"] for e in events))
    if case["invalid_input"]:
        require(case["case"] + ": init rejected before event ledger", not events)
        continue
    signals = [e for e in events if e["event_type"] == "SIGNAL"]
    skips = [e for e in events if e["event_type"] == "SKIP"]
    require(case["case"] + ": only canonical exclusion", all(e["reason"] == "PRIOR_LEVEL_RETEST" and e["reason_kind"] == "EXCLUSION" for e in skips))
    require(case["case"] + ": release calls accepted", not any(e["event_type"] in {"CONTEXT_FINISH_REJECTED", "PRIOR_CONTEXT_FINISH_REJECTED"} for e in events))
    measurements = [e for e in events if e["event_type"] == "PRIOR_CONTEXT_FILTER"]
    if case["filter"]:
        require(case["case"] + ": four rejected signals suppress green ENTRY", sum(e["entry_status"] == "SIGNAL_RISK_REJECTED" for e in signals) == 4)
        require(case["case"] + ": four measured skips", sum("outcome=SKIP" in e["reason"] for e in measurements) == 4)
        if not case["orders_input"]:
            require(case["case"] + ": missing evidence explicitly allowed", sum("outcome=ALLOW_UNAVAILABLE" in e["reason"] and "missing_policy=ALLOW" in e["reason"] for e in measurements) == 4)
    if case["filter"] or case["diagnostic"]:
        # Each fixture intentionally resets the real observer to a unique tag;
        # pure classifier/drawing fixtures have _p/_d tags and are separate.
        context_files = sorted(directory.glob(case["tag"] + "_c*_context.csv"), key=lambda p: int(re.search(r"_c(\d+)_context", p.name)[1]))
        context = [row for path in context_files for row in read_csv(path)]
        decisions = [e for e in context if e["source_event"] == "SIGNAL"]
        require(case["case"] + ": context captures each SIGNAL", len(decisions) == len(signals))
        require(case["case"] + ": context planned prices agree", all(all(abs(float(row[key]) - float(signal[field])) < 1e-8 for key, field in [("entry_price", "entry_price"), ("sl_price", "sl_price"), ("final_tp_price", "tp_price")]) for row, signal in zip(decisions, signals)))
        require(case["case"] + ": four known barriers", sum(row["status"] == "BLOCKED" for row in decisions) == 4)
        require(case["case"] + ": prior source time strictly before W1", all(not row["source_time"] or row["source_time"] < row["start_time"] for row in decisions))
        require(case["case"] + ": source and close known by decision", all((not row["source_known_at"] or row["source_known_at"] <= row["evaluation_at"]) and (not row["latest_close_known_at"] or row["latest_close_known_at"] <= row["evaluation_at"]) and (not row["latest_close_closed_at"] or row["latest_close_closed_at"] <= row["evaluation_at"]) for row in decisions))
    cases[case["case"]] = events

fields = ["event_type", "setup_id", "upper_tf", "lower_tf", "direction", "entry_price", "sl_price", "tp_price", "risk_points", "intended_rr", "actual_rr", "entry_status", "skip_reason", "order_sent_at", "fill_at"]
selected = {"SIGNAL", "RISK_CHECK", "TP_WAVE1_EXTENDED", "ORDER_DISABLED"}
def projection(events):
    return [tuple(e[field] for field in fields) for e in events if e["event_type"] in selected]

require("filter OFF diagnostic ON/OFF economic identity", projection(cases["off_diag_on"]) == projection(cases["off_diag_off"]))
require("filter ON diagnostic ON/OFF economic identity", projection(cases["on_diag_on"]) == projection(cases["on_diag_off"]))
for field in ["entry_price", "sl_price", "tp_price", "risk_points", "intended_rr", "actual_rr"]:
    left = [e[field] for e in cases["off_diag_on"] if e["event_type"] == "SIGNAL"]
    right = [e[field] for e in cases["on_diag_on"] if e["event_type"] == "SIGNAL"]
    require("filter toggle preserves planned " + field, left == right)

module = (REPO / "mql/Include/Wave33Visual/PriorContext.mqh").read_text(encoding="utf-8-sig")
require("finite horizontal/connector rays", "OBJPROP_RAY_LEFT,false" in module and "OBJPROP_RAY_RIGHT,false" in module)
require("finite band starts at decision", "OBJ_RECTANGLE,0,e.at,r.band_low,end,r.band_high" in module)
require("finite band horizon", "end=e.at+12*PeriodSeconds(s.lower_tf)" in module)
require("no terminal-history lookup in context evaluator", all(token not in module for token in ["CopyRates(", "iClose(", "iHigh(", "iLow("]))
require("source identity retained in context CSV", all(token in module for token in ['"source_tf"', '"source_time"', '"source_known_at"', '"source_price"']))

out = {"status": "PASS", "checks": len(checks), "native_batch": latest["batch"], "assertions": sum(c["checks"] for c in latest["cases"]), "failures": 0, "checks_detail": checks,
       "scope": "Synthetic actual-EA wrapper and recorded classifier fixture; no market-period profitability inference, screenshot or tooltip-readback claim."}
(ROOT / "native_event_audit.json").write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: out[k] for k in ["status", "checks", "assertions", "failures", "native_batch"]}))
