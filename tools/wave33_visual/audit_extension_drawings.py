"""Audit recorded W1 revision object inventories against native CSV snapshots.

This is an object/provenance audit, not a pixel-layout test or tester capture.
Repeat --dir to combine independently rendered timeframe pairs in one report.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import csv
from datetime import datetime, timedelta
import hashlib
import json
from pathlib import Path

STAMP = "%Y.%m.%d %H:%M:%S"
GRAY, BLUE, ORANGE = 0x908070, 0xFF901E, 0x008CFF


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rows(path: Path, delimiter: str = ";") -> list[dict]:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream, delimiter=delimiter))


def instant(value: str) -> datetime:
    return datetime.strptime(value, STAMP)


def number(row: dict, key: str) -> float:
    return float(row.get(key) or 0)


def setup_hash(value: str) -> str:
    # MQL5 StringGetCharacter uses UTF-16 code units, not Unicode code points.
    units = list(value.encode("utf-16-le"))
    chars = [units[i] | units[i+1] << 8 for i in range(0, len(units), 2)]
    a, b = 2166136261, 2246822519
    for left, right in zip(chars, reversed(chars)):
        a = ((a ^ left) * 16777619) & 0xFFFFFFFF
        b = ((b ^ right) * 3266489917) & 0xFFFFFFFF
    return f"{a:08X}{b:08X}"


def suffix(name: str, revision: int) -> str:
    return name + (f"_r{revision}" if revision else "")


class Auditor:
    def __init__(self) -> None:
        self.checks = 0
        self.failures: list[dict] = []

    def check(self, condition: bool, label: str, **detail) -> None:
        self.checks += 1
        if not condition:
            self.failures.append({"check": label, **detail})

    def inspect(self, directory: Path) -> dict:
        directory = directory.resolve()
        manifest = json.loads((directory / "fixture_manifest.json").read_text(encoding="utf-8-sig"))
        info = json.loads((directory / "fixture_cases.json").read_text(encoding="utf-8-sig"))
        fixture = rows(directory / "fixture.csv")
        self.check(digest(directory / "fixture.csv").lower() == manifest["fixture_sha256"].lower(), "fixture_hash", directory=str(directory))
        native = rows(Path(manifest["source_run"]) / "events.csv")
        self.check(digest(Path(manifest["source_run"]) / "events.csv").lower() == manifest["source_files"]["events.csv"].lower(), "native_event_hash", directory=str(directory))
        renders = rows(directory / "render_summary.csv", ",")
        source_map = {item["review_index"]: item["source_csv_rows"] for item in manifest["source_row_mapping"]}
        cases = []
        for case in info["cases"]:
            start_count, start_failure = self.checks, len(self.failures)
            index = case["review_index"]
            events = [row for row in fixture if int(row["review_index"]) == index]
            inventory = rows(directory / f"case{index}_objects.csv")
            context = {"directory": str(directory), "case": index}
            self.check(len(events) == len(source_map[index]), "source_row_mapping_length", **context)
            for event, source_row in zip(events, source_map[index]):
                self.check(all(event.get(key, "") == native[source_row-2].get(key, "") for key in manifest["original_event_columns"]), "exact_native_snapshot", source_row=source_row, **context)
                self.check(event["event_at"] <= case["review_cutoff"] and source_row <= case["source_terminal_row"], "native_cutoff", source_row=source_row, **context)
            nonblank = [row for row in events if row["setup_id"]]
            self.check(bool(nonblank) and nonblank[-1]["setup_id"] == case["setup_id"] and nonblank[-1]["event_at"] == case["review_cutoff"], "target_final_snapshot", **context)
            for obj in inventory:
                self.check(len(obj["name"]) <= 63, "object_name_limit", name=obj["name"], **context)
                self.check(obj["type"] not in {"OBJ_LABEL", "OBJ_RECTANGLE_LABEL"}, "no_fixed_panel", name=obj["name"], **context)
                if obj["type"] == "OBJ_TREND":
                    self.check(not int(obj["ray_right"]) and not int(obj["ray_left"]) and obj["time2"] > obj["time1"], "finite_nonzero_line", name=obj["name"], **context)
            groups: dict[str, list[dict]] = defaultdict(list)
            for event in events:
                if event["setup_id"]:
                    groups[event["setup_id"]].append(event)
            revisions = 0
            for setup, history in groups.items():
                code = setup_hash(setup)

                def find(name: str, rev: int = 0) -> dict | None:
                    matches = [obj for obj in inventory if obj["name"].endswith(code+"_"+suffix(name, rev))]
                    self.check(len(matches) <= 1, "unique_revision_object", setup=setup, suffix=suffix(name, rev), **context)
                    return matches[0] if matches else None

                confirmed = {int(event.get("wave1_revision") or 0): event for event in history if event["event_type"] in {"WAVE1_PEAK_CONFIRMED", "WAVE1_EXTENDED_CONFIRMED"}}
                archived = {int(event.get("wave1_revision") or 0): event for event in history if event["event_type"] == "WAVE1_EXTENSION_PREVIOUS_ANCHORS"}
                for rev, event in confirmed.items():
                    revisions += 1
                    detail = {**context, "setup": setup, "revision": rev}
                    line, caption, band = find("W1", rev), find("W1_known", rev), find("fib", rev)
                    self.check(line is not None and caption is not None and band is not None, "confirmed_revision_objects_exist", **detail)
                    if not line or not caption or not band:
                        continue
                    retired = rev in archived
                    self.check(int(line["color"]) == (GRAY if retired else BLUE) and int(line["width"]) == (1 if retired else 3), "old_gray_current_blue", **detail)
                    self.check(not retired or int(line["style"]) == 1, "retired_w1_dashed", **detail)
                    self.check(abs(number(line,"price1")-number(event,"wave1_start_price")) < 1e-7 and abs(number(line,"price2")-number(event,"wave1_peak_price")) < 1e-7, "wave1_anchor_prices", **detail)
                    upper_seconds = {"PERIOD_M15": 900, "PERIOD_M5": 300}[event["upper_tf"]]
                    peak = instant(event["wave1_peak_time"])
                    self.check(peak <= instant(line["time2"]) < peak+timedelta(seconds=upper_seconds), "wave1_peak_plot_within_source_bar", **detail)
                    self.check(caption["time1"] == line["time2"] and abs(number(caption,"price1")-number(event,"wave1_peak_price")) < 1e-7, "caption_at_actual_anchor", **detail)
                    self.check(("旧終点" in caption["text"]) if retired else ("第1波" in caption["text"] and (rev == 0 or f"延長r{rev}" in caption["text"])), "revision_caption_semantics", **detail)
                    self.check("known "+event["wave1_peak_known_at"] in caption["tooltip"] or "confirmed "+event["wave1_peak_known_at"] in caption["tooltip"], "anchor_known_tooltip", **detail)
                    self.check(band["time1"] == event["wave1_peak_known_at"] and abs(number(band,"price1")-number(event,"fib_382_price")) < 1e-7 and abs(number(band,"price2")-number(event,"fib_618_price")) < 1e-7, "fib_new_known_start_and_anchors", **detail)
                    self.check(int(band["color"]) == (GRAY if retired else ORANGE), "fib_history_color", **detail)
                    self.check("anchors known "+event["wave1_peak_known_at"] in band["tooltip"], "fib_tooltip_provenance", **detail)
                    if retired:
                        close = archived[rev]["event_at"]
                        self.check(band["time2"] == close, "old_fib_stops_at_extension", expected=close, actual=band["time2"], **detail)
                        self.check("superseded "+close in caption["tooltip"], "old_anchor_retirement_provenance", **detail)
                    if rev:
                        point = find("ext_known",rev)
                        self.check(point is not None and point["time1"] == event["wave1_peak_known_at"] and abs(number(point,"price1")-number(event,"wave1_peak_price")) < 1e-7, "separate_confirmation_time_marker", **detail)
                        self.check(point is not None and "confirmed now "+event["wave1_peak_known_at"] in point["tooltip"], "confirmation_marker_tooltip", **detail)
                    pullbacks = [row for row in history if int(row.get("wave1_revision") or 0) == rev and row["event_type"] in {"WAVE2_EXTREME", "FIB_TOUCH"} and number(row,"wave2_extreme_price") > 0]
                    if pullbacks:
                        leg, text = find("W2_leg",rev), find("W2",rev)
                        self.check(leg is not None and text is not None, "pullback_revision_exists", **detail)
                        if leg and text:
                            latest = pullbacks[-1]
                            self.check(leg["time1"] == line["time2"] and abs(number(leg,"price1")-number(event,"wave1_peak_price")) < 1e-7 and leg["time2"] == latest["wave2_extreme_time"] and abs(number(leg,"price2")-number(latest,"wave2_extreme_price")) < 1e-7, "pullback_new_anchor_and_observed_extreme", **detail)
                            self.check(int(leg["color"]) == (GRAY if retired else ORANGE) and int(text["color"]) == (GRAY if retired else ORANGE), "old_gray_new_orange_pullback", **detail)
                            self.check(("旧観測" in text["text"]) if retired else "押し・戻り" in text["text"], "pullback_caption_semantics", **detail)
            render = next((row for row in renders if int(row["case"]) == index), None)
            self.check(render is not None and render["saved"] == "1" and (directory/render["image"]).exists(), "native_png_saved", **context)
            cases.append({"index": index, "setup_id": case["setup_id"], "selection": case["selection"], "image": render["image"] if render else "", "object_count": len(inventory), "confirmed_revisions_including_related": revisions, "checks": self.checks-start_count, "failures": len(self.failures)-start_failure})
        return {"directory": str(directory), "cases": cases, "case_count": len(cases), "coverage_shortfall": info["coverage_shortfall"], "manifest_sha256": digest(directory/"fixture_manifest.json"), "fixture_sha256": digest(directory/"fixture.csv")}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", type=Path, action="append", required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    auditor = Auditor()
    rendered = [auditor.inspect(directory) for directory in args.dir]
    report = {"status": "PASS" if not auditor.failures else "FAIL", "checks": auditor.checks, "violation_count": len(auditor.failures), "violations": auditor.failures, "rendered": rendered, "kind": "NORMAL_CHART_RECORDED_W1_REVISION_OBJECT_AUDIT", "pixel_overlap_automatically_tested": False, "actual_visual_tester_capture": False, "auditor_sha256": digest(Path(__file__))}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ("status", "checks", "violation_count")}))
    if auditor.failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
