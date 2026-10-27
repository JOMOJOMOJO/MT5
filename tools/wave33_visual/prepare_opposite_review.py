"""Build bounded, draw-only lifecycle fixtures from recorded native events.

Select the first five armed positions in time order, then ordinary filled
positions if needed. Profit/loss never determines selection. No signal or
wave recognition is recomputed. --out accepts a directory or a .csv filename.
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
ARMED = "OPPOSITE_WAVE1_ARMED"
PREFIX = ["review_index", "review_id", "review_cutoff"]
TARGET_COUNT = 5


def stamp(value: str) -> datetime:
    return datetime.strptime(value, STAMP)


def digest(path: Path) -> str | None:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None


def load_events(path: Path) -> tuple[list[str], list[dict]]:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream, delimiter=";")
        fields = reader.fieldnames or []
        if not {"event_at", "event_type", "setup_id"}.issubset(fields):
            raise ValueError("events.csv must contain event_at, event_type and setup_id")
        if set(fields) & set(PREFIX):
            raise ValueError("Input is already a review fixture")
        events = []
        for row_number, row in enumerate(reader, 2):
            if None in row:
                raise ValueError(f"Malformed CSV row {row_number}")
            if not row.get("event_at"):
                raise ValueError(f"Missing event_at at row {row_number}")
            stamp(row["event_at"])
            events.append({**row, "_row": row_number})
    return fields, events


def first(rows: list[dict], event_type: str) -> dict | None:
    return next((row for row in rows if row["event_type"] == event_type), None)


def build(run: Path, out: Path) -> dict:
    run = run.resolve()
    events_path = run / "events.csv"
    fields, events = load_events(events_path)
    groups = defaultdict(list)
    for row in events:
        if row["setup_id"]:
            groups[row["setup_id"]].append(row)
    fills = {setup: first(rows, "FILL") for setup, rows in groups.items()}
    fills = {setup: row for setup, row in fills.items() if row is not None}
    arms = {setup: first(rows, ARMED) for setup, rows in groups.items()}
    arms = {setup: row for setup, row in arms.items() if row is not None}
    for setup, arm in arms.items():
        if setup not in fills or fills[setup]["_row"] >= arm["_row"]:
            raise ValueError(f"Armed position has no preceding native FILL: {setup}")
    armed_order = sorted(arms, key=lambda setup: (arms[setup]["event_at"], arms[setup]["_row"]))
    selected = [(setup, "FIRST_CHRONOLOGICAL_ARMED") for setup in armed_order[:TARGET_COUNT]]
    selected_ids = {setup for setup, _ in selected}
    exemplar = next(iter(fills.values()), events[0] if events else {})
    is_a = exemplar.get("upper_tf") == "PERIOD_M15" and exemplar.get("lower_tf") == "PERIOD_M5"
    ordinary_after = "2018.11.12 00:00:00" if is_a else None
    ordinary = sorted(
        (setup for setup, fill in fills.items()
         if setup not in selected_ids and setup not in arms
         and (ordinary_after is None or fill["event_at"] > ordinary_after)),
        key=lambda setup: (fills[setup]["event_at"], fills[setup]["_row"]),
    )
    selected.extend((setup, "FIRST_CHRONOLOGICAL_ORDINARY_FILL")
                    for setup in ordinary[:TARGET_COUNT - len(selected)])
    result, cases = [], []
    included_source_rows = []
    for index, (setup, selection) in enumerate(selected):
        history = groups[setup]
        fill, arm = fills[setup], arms.get(setup)
        terminal = next((row for row in history if row["_row"] >= fill["_row"]
                         and row["event_type"] in {"EXIT", "TEST_END"}), None)
        complete = terminal is not None
        if terminal is None:
            terminal = history[-1]
        cutoff, cutoff_row = terminal["event_at"], terminal["_row"]
        source = arm.get("opposite_setup_id", "") if arm else ""
        if arm:
            if not source or source not in groups:
                raise ValueError(f"Opposite W1 source history missing: {setup} / {source}")
            source_peak = next((row for row in groups[source]
                                if row["event_type"] == "WAVE1_PEAK_CONFIRMED"
                                and row["_row"] < arm["_row"]), None)
            if source_peak is None:
                raise ValueError(f"Opposite source has no prior confirmed W1: {source}")
        else:
            source_peak = None
        included_ids = {setup} | ({source} if source else set())
        as_of = [row for row in events
                 if row["_row"] <= cutoff_row and row["event_at"] <= cutoff]
        related = [row for row in as_of if row["setup_id"] in included_ids]
        origins = [stamp(row["wave1_start_time"]) for row in related
                   if row.get("wave1_start_time")]
        if not origins:
            origins = [stamp(fill.get("candidate_detected_at") or fill["event_at"])]
        background_start = (min(origins) - timedelta(hours=1)).strftime(STAMP)
        chosen = [row for row in as_of
                  if row["setup_id"] in included_ids
                  or (not row["setup_id"] and row["event_type"] == "PIVOT_CONFIRMED"
                      and row["event_at"] >= background_start)]
        # Preserve native row order, including same-second event order. The
        # target terminal is the final nonblank setup so replay's snapshot is
        # always the position under review, never its opposite source.
        if not chosen or chosen[-1]["_row"] != cutoff_row:
            raise ValueError(f"Fixture does not end at target lifecycle cutoff: {setup}")
        for row in chosen:
            result.append({"review_index": index, "review_id": setup,
                           "review_cutoff": cutoff,
                           **{field: row.get(field, "") for field in fields}})
        source_rows = [row["_row"] for row in chosen]
        included_source_rows.append({"review_index": index, "source_csv_rows": source_rows})
        cases.append({
            "review_index": index, "review_id": setup, "setup_id": setup,
            "selection": selection, "direction": fill.get("direction", ""),
            "symbol": fill.get("symbol", ""), "upper_tf": fill.get("upper_tf", ""),
            "lower_tf": fill.get("lower_tf", ""),
            "candidate_detected_at": fill.get("candidate_detected_at", ""),
            "wave1_start_time": fill.get("wave1_start_time", ""),
            "wave1_peak_time": fill.get("wave1_peak_time", ""),
            "wave1_peak_known_at": fill.get("wave1_peak_known_at", ""),
            "fill_at": fill.get("fill_at") or fill["event_at"],
            "entry_price": fill.get("entry_price", ""),
            "sl_price": fill.get("sl_price", ""), "tp_price": fill.get("tp_price", ""),
            "armed_at": arm["event_at"] if arm else "",
            "opposite_setup_id": source,
            "opposite_wave_peak_time": source_peak.get("wave1_peak_time", "") if source_peak else "",
            "opposite_wave_known_at": source_peak["event_at"] if source_peak else "",
            "opposite_wave_price": source_peak.get("wave1_peak_price", "") if source_peak else "",
            "review_cutoff": cutoff, "terminal_event": terminal["event_type"],
            "lifecycle_complete": complete, "exit_reason": terminal.get("exit_reason", ""),
            "realized_r": terminal.get("realized_r", ""),
            "background_pivots_from": background_start,
            "source_target_fill_row": fill["_row"],
            "source_arm_row": arm["_row"] if arm else None,
            "source_terminal_row": cutoff_row,
            "fixture_event_rows": len(chosen),
            "target_event_rows": sum(row["setup_id"] == setup for row in chosen),
            "opposite_source_event_rows": sum(row["setup_id"] == source for row in chosen) if source else 0,
            "background_pivot_rows": sum(not row["setup_id"] for row in chosen),
            "event_counts": dict(Counter(row["event_type"] for row in chosen)),
        })
    if out.suffix.lower() == ".csv":
        fixture = out.resolve()
        cases_json = fixture.with_name(fixture.stem + "_cases.json")
        cases_md = fixture.with_name(fixture.stem + "_cases.md")
        manifest_path = fixture.with_name(fixture.stem + "_manifest.json")
    else:
        fixture = out.resolve() / "fixture.csv"
        cases_json, cases_md = fixture.parent / "cases.json", fixture.parent / "cases.md"
        manifest_path = fixture.parent / "manifest.json"
    fixture.parent.mkdir(parents=True, exist_ok=True)
    with fixture.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=PREFIX + fields, delimiter=";")
        writer.writeheader()
        writer.writerows(result)
    summary = {
        "kind": "RECORDED_POSITION_LIFECYCLE_DRAW_ONLY_FIXTURE",
        "run": str(run), "fixture": str(fixture),
        "selection_policy": "First chronological armed positions up to 5, then first chronological ordinary fills; never select by P/L",
        "a_ordinary_fill_strictly_after": ordinary_after,
        "requested_cases": TARGET_COUNT, "observed_armed_positions": len(arms),
        "observed_native_filled_positions": len(fills),
        "eligible_ordinary_fallback_positions": len(ordinary),
        "selected_cases": len(cases), "shortfall": max(0, TARGET_COUNT - len(cases)),
        "fixture_event_rows": len(result), "cases": cases,
        "future_event_rows": 0, "native_sequence_cutoff_enforced": True,
        "signal_recalculation": False, "profit_loss_used_for_selection": False,
    }
    cases_json.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["# 逆方向第1波後の決済・記録再生レビュー", "",
             "記録済みのイベントを実際のEXITまたはTEST_ENDまで描画するための資料。シグナル再計算・発注はしない。",
             "損益を選定条件にせず、逆方向W1監視が始まった順に最大5件を採用。不足分は通常約定を時系列で補完。",
             f"観測数: 監視開始 {len(arms)} 件、約定 {len(fills)} 件。採用 {len(cases)}/{TARGET_COUNT} 件。",
             f"Aの通常約定補完は {ordinary_after} より後。" if ordinary_after else "Bの通常約定補完は全期間。", "",
             "| # | 方向・分類 | 元候補 / 約定 | 逆方向①の位置 / 知り得た時刻 | 終了 / 理由 |",
             "|---|---|---|---|---|"]
    for case in cases:
        source_label = (f"{case['opposite_wave_peak_time']} / {case['opposite_wave_known_at']}<br>{case['opposite_setup_id']}"
                        if case["opposite_setup_id"] else "監視開始なし")
        lines.append(f"| {case['review_index']} | {case['direction']} / {case['selection']} | {case['setup_id']}<br>{case['fill_at']} | {source_label} | {case['review_cutoff']} / {case['terminal_event']} {case['exit_reason']} |")
    lines.extend(["", "全ケースで、元候補と逆方向W1の履歴を開始時刻で切り落とさず保持する。背景の確定スイングは両候補の最も古い起点の1時間前から。",
                  "終了時刻の後のイベントと、同じ秒でも終了イベントより後の行は取り込まない。元CSVの行番号はmanifestに保存。",
                  "利益決済条件を満たさず通常SL/TPまたはテスト終了へ至った場合も、その結果を残す。"])
    cases_md.write_text("\n".join(lines) + "\n", encoding="utf-8")
    manifest = {
        "kind": summary["kind"], "source_run": str(run),
        "source_files": {name: digest(run / name) for name in ("events.csv", "config.csv", "run.json", "upper_bars.csv")},
        "preparer": str(Path(__file__).resolve()), "preparer_sha256": digest(Path(__file__)),
        "fixture": str(fixture), "fixture_sha256": digest(fixture),
        "cases_json": str(cases_json), "cases_json_sha256": digest(cases_json),
        "cases_md": str(cases_md), "cases_md_sha256": digest(cases_md),
        "original_event_columns": fields, "source_event_rows": len(events),
        "fixture_event_rows": len(result), "selected_cases": len(cases),
        "source_row_mapping": included_source_rows,
        "native_sequence_cutoff_enforced": True,
        "no_future_events": True, "profit_loss_used_for_selection": False,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return {"fixture": str(fixture), "cases": str(cases_json), "manifest": str(manifest_path),
            "selected_cases": len(cases), "observed_armed_positions": len(arms),
            "fixture_event_rows": len(result), "shortfall": summary["shortfall"]}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.run, args.out), ensure_ascii=False))


if __name__ == "__main__":
    main()
