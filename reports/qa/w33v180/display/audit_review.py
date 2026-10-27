"""Audit native recorded drawing inventories against v1.80 event fixtures."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from pathlib import Path


def rows(path: Path, delimiter: str = ";") -> list[dict]:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream, delimiter=delimiter))


def setup_hash(value: str) -> str:
    units = value.encode("utf-16-le")
    chars = [units[i] | units[i + 1] << 8 for i in range(0, len(units), 2)]
    a, b = 2166136261, 2246822519
    for left, right in zip(chars, reversed(chars)):
        a = ((a ^ left) * 16777619) & 0xFFFFFFFF
        b = ((b ^ right) * 3266489917) & 0xFFFFFFFF
    return f"{a:08X}{b:08X}"


def audit(directory: Path) -> dict:
    info = json.loads((directory / "fixture_cases.json").read_text(encoding="utf-8-sig"))
    fixture = rows(directory / "fixture.csv")
    summary = {int(row["case"]): row for row in rows(directory / "render_summary.csv", ",")}
    failures = []
    checks = 0

    def check(condition: bool, case: int, rule: str):
        nonlocal checks
        checks += 1
        if not condition:
            failures.append({"case": case, "rule": rule})

    for case in info["cases"]:
        index, expected = case["review_index"], case["expected"]
        source = Path(case["source_run"]) / "events.csv"
        check(hashlib.sha256(source.read_bytes()).hexdigest() == case["source_events_sha256"], index, "native_source_unchanged")
        native = rows(source)
        selected = [row for row in fixture if int(row["review_index"]) == index]
        cutoff_row = case["source_target_csv_row"] - 2
        native_prefix = native[:cutoff_row + 1]
        for event in selected:
            check(event["event_at"] <= case["cutoff"], index, "event_available_by_cutoff")
            check(any(all(event.get(key, "") == row.get(key, "") for key in row) for row in native_prefix), index, "exact_native_prefix_snapshot")
        check(native[cutoff_row] == expected, index, "expected_is_exact_target_snapshot")
        inventory = rows(directory / f"case{index}_objects.csv")
        matching = {row["name"].split(setup_hash(case["setup_id"]) + "_", 1)[1]: row
                    for row in inventory if setup_hash(case["setup_id"]) + "_" in row["name"]}
        for obj in inventory:
            check(len(obj["name"]) <= 63, index, "object_name_limit")
            check(obj["type"] not in {"OBJ_LABEL", "OBJ_RECTANGLE_LABEL"}, index, "no_fixed_panel")
            if obj["type"] == "OBJ_TREND":
                check(obj["ray_right"] == obj["ray_left"] == "0" and obj["time1"] < obj["time2"], index, "finite_nonzero_line")
        render = summary.get(index, {})
        check(render.get("saved") == "1" and (directory / render.get("image", "__missing__")).is_file(), index, "native_png_saved")
        check(render.get("setup_id") == case["setup_id"], index, "primary_review_snapshot")
        if case["category"] == "CONNECTED_CANCEL":
            marker = matching.get("opposite_cancel_known", {})
            leader = matching.get("opposite_cancel_leader", {})
            captions = [obj for suffix, obj in matching.items() if suffix.startswith("skip_")]
            check(marker.get("time1") == expected["connected_opposite_known_at"] == case["cutoff"], index, "cancel_at_candidate_availability")
            check(leader.get("time1") == case["cutoff"] and leader.get("time2", "") > case["cutoff"], index, "cancel_leader_not_backdated")
            check(any("接続する逆①候補" in obj["text"] for obj in captions), index, "cancel_caption")
            check(any(expected["connected_opposite_setup_id"] in obj["tooltip"] and expected["connected_opposite_known_at"] in obj["tooltip"] for obj in captions), index, "cancel_source_and_known_tooltip")
            check(expected["connected_shared_time"] in marker.get("tooltip", "") and "shared swing" in marker.get("tooltip", ""), index, "cancel_shared_swing_tooltip")
            check(expected["connected_opposite_setup_id"] in leader.get("tooltip", "") and expected["connected_shared_time"] in leader.get("tooltip", ""), index, "cancel_source_origin_tooltip")
            for obj in [marker, leader, *captions]:
                check(bool(obj.get("tooltip")) and obj["tooltip"].isascii() and len(obj["tooltip"]) <= 120, index, "compact_complete_cancel_tooltip")
        else:
            target, label = matching.get("TP", {}), matching.get("TP_label", {})
            check(bool(target) and abs(float(target.get("price1") or 0) - float(expected["tp_price"])) < 1e-7, index, "final_tp_price")
            check(label.get("text") == "TP ①手前", index, "extended_tp_caption")
            check("RR-only" in target.get("tooltip", "") and "actual" in target.get("tooltip", ""), index, "tp_base_and_actual_rr_tooltip")
            check(expected["wave1_peak_time"] in label.get("tooltip", "") and expected["wave1_peak_known_at"] in label.get("tooltip", ""), index, "tp_known_w1_source_tooltip")
            check(expected["wave1_peak_known_at"] <= case["cutoff"], index, "tp_source_available")
            for obj in [target, label]:
                check(bool(obj.get("tooltip")) and obj["tooltip"].isascii() and len(obj["tooltip"]) <= 120, index, "compact_complete_tp_tooltip")
            match = re.search(r"RR-only ([0-9.]+)", target.get("tooltip", ""))
            check(bool(match) and abs(float(match.group(1)) - float(expected["tp_rr_price"])) < 1e-7, index, "original_rr_target_retained")
    result = {"kind": "NATIVE_RECORDED_DRAWING_INVENTORY_AUDIT", "status": ("PASS" if info["cases"] else "NO_CASES") if not failures else "FAIL",
              "observed_cases": len(info["cases"]), "shortfall": info["shortfall"], "checks": checks, "failures": failures}
    (directory / "drawing_audit.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", type=Path, required=True)
    args = parser.parse_args()
    result = audit(args.dir)
    print(json.dumps(result, ensure_ascii=False))
    raise SystemExit(0 if result["status"] == "PASS" else 1)
