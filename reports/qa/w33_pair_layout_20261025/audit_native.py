"""Independent complete-ledger parity and pair-cancellation accounting."""
from pathlib import Path
import csv
import json
import hashlib

ROOT = Path(__file__).resolve().parent
latest = json.loads((ROOT / "native_latest.json").read_text(encoding="utf-8-sig"))
assert latest["status"] == "PASS"
checks = []

def require(name, condition, detail=None):
    checks.append({"check": name, "passed": bool(condition), "detail": detail})
    assert condition, name

def rows(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream, delimiter=";"))

main_events = {}
parity_rows = 0
for case in latest["cases"]:
    directory = Path(case["output"])
    tag = case["tag"]
    events = rows(directory / (tag + "_events.csv"))
    main_events[case["case"]] = events
    require(case["case"] + ": real EA no ORDER/FILL", not any(e["event_type"] in {"ORDER", "FILL"} for e in events))
    require(case["case"] + ": no order or fill timestamp", all(not e["order_sent_at"] and not e["fill_at"] for e in events))
    require(case["case"] + ": no paired SIGNAL", not any(e["event_type"] == "SIGNAL" for e in events))
    exclusions = [e for e in events if e["reason"] == "CONNECTED_OPPOSITE_W1_BOTH"]
    require(case["case"] + ": four pairs eight explicit exclusions", len(exclusions) == 8 and all(e["event_type"] == "INVALIDATE" and e["reason_kind"] == "EXCLUSION" and e["entry_status"] == "INVALIDATED" for e in exclusions))
    pair_files = sorted(directory.glob(tag + "_pair_*_events.csv"))
    require(case["case"] + ": sixteen pair fixtures", len(pair_files) == 16)
    for path in pair_files:
        ev = rows(path)
        cancels = [e for e in ev if e["reason"] == "CONNECTED_OPPOSITE_W1_BOTH"]
        require(case["case"] + ": atomic two-sided pair " + path.stem.removeprefix(tag), len(cancels) == 2 and {e["direction"] for e in cancels} == {"LONG", "SHORT"} and cancels[0]["event_at"] == cancels[1]["event_at"])
        require(case["case"] + ": pair never ordered " + path.stem.removeprefix(tag), not any(e["event_type"] in {"ORDER", "FILL", "SIGNAL"} for e in ev))
        newer = next(e["setup_id"] for e in ev if e["event_type"] == "WAVE1_BREAK")
        require(case["case"] + ": newer never resumes tracking " + path.stem.removeprefix(tag), not any(e["setup_id"] == newer and e["event_type"] in {"STATE", "WAVE1_PROVISIONAL"} for e in ev))
    parity_files = sorted(directory.glob(tag + "_parity_current_*_events.csv"))
    require(case["case"] + ": eight complete before/current parity fixtures", len(parity_files) == 8)
    for current in parity_files:
        before = current.with_name(current.name.replace("_parity_current_", "_parity_before_"))
        a, b = rows(current), rows(before)
        require(case["case"] + ": exact all-column legacy parity " + current.stem.removeprefix(tag), a == b, {"rows": len(a), "fields": len(a[0]) if a else 0})
        parity_rows += len(a)

require("readable ON/OFF leaves complete real-EA event ledger identical", main_events["readable_on"] == main_events["readable_off"])
visual_file = ROOT / "display_latest.json"
visual_checks = 0
if visual_file.exists():
    visual = json.loads(visual_file.read_text(encoding="utf-8-sig"))
    require("draw-only normal-chart batch passes", visual["status"] == "PASS" and visual["mode"] == "NORMAL_CHART_LAYOUT_FIXTURE")
    directory = Path(visual["output"])
    native = rows(directory / (visual["tag"] + "_assertions.csv"))
    wanted = {"visual_geometry_available", "label_boxes_no_overlap_initial", "label_boxes_clamped_initial", "label_all_visible_initial", "label_logical_anchors_stable_repeat", "label_finite_leaders", "label_leader_true_source_anchors", "offscreen_viewport_applied", "offscreen_restores_original_font_colour", "label_off_restores_originals", "before_screenshot_saved", "after_screenshot_saved"}
    for name in sorted(wanted):
        require("normal chart: " + name, any(r["test"] == name and r["result"] == "PASS" for r in native))
    for label in ["before", "after"]:
        path = directory / (visual["tag"] + "_dense_" + label + ".png")
        expected = next(s["sha256"] for s in visual["screenshots"] if Path(s["path"]) == path)
        require("normal chart: actual dense " + label + " PNG hash", path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() == expected)
    visual_checks = visual["checks"]
result = {"status": "PASS", "checks": len(checks), "native_assertions": sum(c["checks"] for c in latest["cases"]), "visual_assertions": visual_checks, "all_column_parity_event_rows": parity_rows, "failures": 0, "details": checks, "scope": "Closed synthetic actual-EA and pre-cancellation snapshot fixtures; no annual performance, MT5 real-tick or future profitability claim."}
(ROOT / "native_event_audit.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: result[k] for k in ["status", "checks", "native_assertions", "visual_assertions", "all_column_parity_event_rows", "failures"]}))
