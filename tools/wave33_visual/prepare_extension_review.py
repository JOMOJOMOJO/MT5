"""Prepare five chronological, coverage-selected W1 revision drawing cases.

Only recorded snapshots are replayed. No market/entry recognition is rerun and
neither P/L nor a later chart shape is used for selection. --out accepts a CSV
filename or directory, matching prepare_opposite_review.py.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
from datetime import datetime, timedelta
import hashlib
import json
from pathlib import Path

STAMP = "%Y.%m.%d %H:%M:%S"
PREFIX = ["review_index", "review_id", "review_cutoff"]
TARGET_COUNT = 5
STARTED = "WAVE1_EXTENSION_STARTED"
CONFIRMED = "WAVE1_EXTENDED_CONFIRMED"
TERMINALS = {"EXIT", "INVALIDATE", "TEST_END"}


def stamp(value: str) -> datetime:
    return datetime.strptime(value, STAMP)


def digest(path: Path) -> str | None:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None


def load_events(path: Path) -> tuple[list[str], list[dict]]:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream, delimiter=";")
        fields = reader.fieldnames or []
        if not {"event_at", "event_type", "setup_id"}.issubset(fields):
            raise ValueError("events.csv requires event_at, event_type and setup_id")
        if set(fields) & set(PREFIX):
            raise ValueError("Input is already a review fixture")
        events = []
        for number, row in enumerate(reader, 2):
            if None in row or not row.get("event_at"):
                raise ValueError(f"Malformed CSV row {number}")
            stamp(row["event_at"])
            events.append({**row, "_row": number})
    return fields, events


def first(rows: list[dict], kind: str) -> dict | None:
    return next((row for row in rows if row["event_type"] == kind), None)


def lifecycle_end(rows: list[dict]) -> dict:
    # A monitoring COMPLETED can precede the real position EXIT. Retain the
    # actual fill lifecycle when present, otherwise the first real terminal.
    return (first(rows, "EXIT") or first(rows, "INVALIDATE")
            or first(rows, "TEST_END") or rows[-1])


def revision(row: dict) -> int:
    return int(row.get("wave1_revision") or 0)


def build(run: Path, out: Path) -> dict:
    run = run.resolve()
    fields, events = load_events(run / "events.csv")
    groups: dict[str, list[dict]] = defaultdict(list)
    for row in events:
        if row["setup_id"]:
            groups[row["setup_id"]].append(row)
    candidates = {key: rows for key, rows in groups.items() if first(rows, "WAVE1_BREAK")}
    order = sorted(candidates, key=lambda key: (candidates[key][0]["event_at"], candidates[key][0]["_row"]))

    def extended(key: str) -> bool:
        return first(candidates[key], STARTED) is not None

    def signaled(key: str) -> bool:
        return first(candidates[key], "SIGNAL") is not None

    def direction(key: str) -> str:
        return next((row.get("direction", "") for row in candidates[key] if row.get("direction")), "")

    def fib_locked(key: str) -> bool:
        return not extended(key) and any(
            row["event_type"] == "WAVE1_EXTENSION_LOCKED"
            and (row.get("wave1_extension_lock_reason") or row.get("reason")) == "MIN_FIB_RETRACEMENT_OBSERVED"
            for row in candidates[key])

    predicates = [
        ("EXTENDED_LONG_SIGNAL", lambda key: extended(key) and direction(key) == "LONG" and signaled(key)),
        ("EXTENDED_SHORT_SIGNAL", lambda key: extended(key) and direction(key) == "SHORT" and signaled(key)),
        ("EXTENDED_TERMINAL_NO_SIGNAL", lambda key: extended(key) and not signaled(key)
         and lifecycle_end(candidates[key])["event_type"] in TERMINALS),
        ("MULTIPLE_REVISIONS", lambda key: max(revision(row) for row in candidates[key]) >= 2),
        ("UNEXTENDED_FIB_LOCKED_CONTROL", fib_locked),
    ]
    selected: list[tuple[str, str]] = []
    selected_ids = set()
    for label, predicate in predicates:
        chosen = next((key for key in order if key not in selected_ids and predicate(key)), None)
        if chosen:
            selected.append((chosen, label))
            selected_ids.add(chosen)
    for label, eligible in (("CHRONOLOGICAL_EXTENDED_FALLBACK", [key for key in order if extended(key)]),
                            ("CHRONOLOGICAL_CANDIDATE_FALLBACK", order)):
        for key in eligible:
            if len(selected) >= TARGET_COUNT:
                break
            if key not in selected_ids:
                selected.append((key, label))
                selected_ids.add(key)

    result, cases, mappings = [], [], []
    for index, (key, selection) in enumerate(selected):
        history = candidates[key]
        terminal = lifecycle_end(history)
        cutoff, cutoff_row = terminal["event_at"], terminal["_row"]
        native_target = [row for row in history if row["_row"] <= cutoff_row and row["event_at"] <= cutoff]
        arms = [row for row in native_target if row["event_type"] == "OPPOSITE_WAVE1_ARMED"]
        sources = sorted({row.get("opposite_setup_id", "") for row in arms} - {""})
        for source in sources:
            if source not in groups:
                raise ValueError(f"Opposite source history missing: {key} / {source}")
        included_ids = {key, *sources}
        as_of = [row for row in events if row["_row"] <= cutoff_row and row["event_at"] <= cutoff]
        related = [row for row in as_of if row["setup_id"] in included_ids]
        origins = [stamp(row["wave1_start_time"]) for row in related if row.get("wave1_start_time")]
        fallback = history[0].get("candidate_detected_at") or history[0]["event_at"]
        background = (min(origins, default=stamp(fallback)) - timedelta(hours=1)).strftime(STAMP)
        chosen_rows = [row for row in as_of if row["setup_id"] in included_ids
                       or (not row["setup_id"] and row["event_type"] == "PIVOT_CONFIRMED" and row["event_at"] >= background)]
        if not chosen_rows or chosen_rows[-1]["_row"] != cutoff_row or chosen_rows[-1]["setup_id"] != key:
            raise ValueError(f"Fixture final nonblank snapshot is not the target cutoff: {key}")
        for row in chosen_rows:
            result.append({"review_index": index, "review_id": key, "review_cutoff": cutoff,
                           **{field: row.get(field, "") for field in fields}})
        mappings.append({"review_index": index, "source_csv_rows": [row["_row"] for row in chosen_rows]})
        anchor_rows = [row for row in native_target if row["event_type"] in {"WAVE1_PEAK_CONFIRMED", CONFIRMED}]
        fill = first(native_target, "FILL")
        signal = first(native_target, "SIGNAL")
        cases.append({
            "review_index": index, "review_id": key, "setup_id": key, "selection": selection,
            "coverage": [label for label, predicate in predicates if predicate(key)],
            **{field: terminal.get(field, "") for field in ("direction", "symbol", "upper_tf", "lower_tf", "candidate_detected_at",
               "wave1_start_time", "wave1_peak_time", "wave1_peak_known_at", "entry_price", "sl_price", "tp_price", "exit_reason", "realized_r")},
            "wave1_revision": revision(terminal),
            "extension_started_count": sum(row["event_type"] == STARTED for row in native_target),
            "extension_confirmed_count": sum(row["event_type"] == CONFIRMED for row in native_target),
            "anchor_history": [{field: row.get(field, "") for field in ("event_at", "event_type", "wave1_revision", "wave1_peak_time", "wave1_peak_price", "wave1_peak_known_at")} for row in anchor_rows],
            "signal_at": signal["event_at"] if signal else "", "fill_at": fill["event_at"] if fill else "",
            "opposite_setup_ids": sources, "opposite_setup_id": sources[0] if sources else "",
            "review_cutoff": cutoff, "terminal_event": terminal["event_type"],
            "lifecycle_complete": terminal["event_type"] in TERMINALS,
            "background_pivots_from": background, "source_terminal_row": cutoff_row,
            "fixture_event_rows": len(chosen_rows), "target_event_rows": len(native_target),
            "opposite_source_event_rows": sum(row["setup_id"] in sources for row in chosen_rows),
            "background_pivot_rows": sum(not row["setup_id"] for row in chosen_rows),
            "event_counts": dict(Counter(row["event_type"] for row in chosen_rows)),
        })
    if out.suffix.lower() == ".csv":
        fixture = out.resolve()
        cases_json, cases_md, manifest_path = [fixture.with_name(fixture.stem + suffix) for suffix in ("_cases.json", "_cases.md", "_manifest.json")]
    else:
        fixture = out.resolve() / "fixture.csv"
        cases_json = fixture.with_name("fixture_cases.json")
        cases_md = fixture.with_name("fixture_cases.md")
        manifest_path = fixture.with_name("fixture_manifest.json")
    fixture.parent.mkdir(parents=True, exist_ok=True)
    with fixture.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=PREFIX + fields, delimiter=";")
        writer.writeheader()
        writer.writerows(result)
    coverage = {label: {"observed": sum(predicate(key) for key in order),
                        "selected": sum(predicate(key) for key, _ in selected)} for label, predicate in predicates}
    summary = {
        "kind": "RECORDED_W1_REVISION_LIFECYCLE_DRAW_ONLY_FIXTURE", "run": str(run), "fixture": str(fixture),
        "selection_policy": "First chronological distinct candidate per coverage category, then chronological extended candidates, then other candidates; no P/L selection",
        "requested_cases": TARGET_COUNT, "observed_candidates": len(candidates),
        "observed_extended_candidates": sum(extended(key) for key in order),
        "coverage": coverage, "coverage_shortfall": [label for label, counts in coverage.items() if not counts["selected"]],
        "selected_cases": len(cases), "shortfall": max(0, TARGET_COUNT-len(cases)), "cases": cases,
        "fixture_event_rows": len(result), "future_event_rows": 0, "native_sequence_cutoff_enforced": True,
        "signal_recalculation": False, "profit_loss_used_for_selection": False,
    }
    cases_json.write_text(json.dumps(summary, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    lines = ["# 第1波延長・記録再生レビュー", "", "記録済みの全revisionを終了時点まで再生。認識の再計算・発注はしない。",
             "延長LONG成立、延長SHORT成立、延長後未成立、複数延長、Fib到達で延長停止した対照を時系列で選定。損益は選定に使わない。",
             f"候補 {len(candidates)} 件、延長 {summary['observed_extended_candidates']} 件。採用 {len(cases)}/{TARGET_COUNT} 件。",
             "分類の不足: "+(", ".join(summary["coverage_shortfall"]) or "なし"), "",
             "| # | 方向・分類 | 候補 / 延長数 | ①終点の位置 → 知り得た時刻 | SIGNAL / 終了 |", "|---|---|---|---|---|"]
    for case in cases:
        anchors = "<br>".join(f"r{item['wave1_revision'] or 0}: {item['wave1_peak_time']} → {item['wave1_peak_known_at']}" for item in case["anchor_history"]) or "終点未確定"
        lines.append(f"| {case['review_index']} | {case['direction']} / {case['selection']} | {case['setup_id']}<br>{case['extension_started_count']}回 | {anchors} | {case['signal_at'] or 'なし'}<br>{case['review_cutoff']} {case['terminal_event']} {case['exit_reason']} |")
    lines.extend(["", "旧①・旧②・旧Fibの履歴と新しい①の確定時刻を分けて照合する。背景スイングは関連候補の最古の起点の1時間前から。",
                  "同じ秒でも終了行より後のイベントは取り込まない。元CSVの行番号はmanifestへ保存。"])
    cases_md.write_text("\n".join(lines)+"\n", encoding="utf-8")
    manifest = {
        "kind": summary["kind"], "source_run": str(run),
        "source_files": {name: digest(run/name) for name in ("events.csv", "config.csv", "run.json", "upper_bars.csv", "lower_bars.csv")},
        "preparer": str(Path(__file__).resolve()), "preparer_sha256": digest(Path(__file__)),
        "fixture": str(fixture), "fixture_sha256": digest(fixture),
        "cases_json": str(cases_json), "cases_json_sha256": digest(cases_json),
        "cases_md": str(cases_md), "cases_md_sha256": digest(cases_md),
        "original_event_columns": fields, "source_event_rows": len(events), "fixture_event_rows": len(result),
        "selected_cases": len(cases), "cases": cases, "source_row_mapping": mappings,
        "coverage": coverage, "coverage_shortfall": summary["coverage_shortfall"],
        "native_sequence_cutoff_enforced": True, "no_future_events": True, "profit_loss_used_for_selection": False,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    return {"fixture": str(fixture), "cases": str(cases_json), "manifest": str(manifest_path),
            "selected_cases": len(cases), "fixture_event_rows": len(result), "shortfall": summary["shortfall"],
            "coverage_shortfall": summary["coverage_shortfall"]}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.run, args.out), ensure_ascii=False))


if __name__ == "__main__":
    main()
