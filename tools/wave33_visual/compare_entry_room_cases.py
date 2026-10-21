"""Compare fixed user-reviewed Wave33 cases across the v1.40 four-arm native QA.

The CSVs are observations from MT5. This script neither generates signals nor
selects profitable trades. Candidate serial numbers are deliberately ignored.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path


ARMS = ("a_v130_control", "a_recognition_only", "a_room_only", "a_v140_full")
MINIMUM_ROOM_R = 0.25
CASES = (
    ("good_apr26_long", "good", "FILL", "2018.04.26 20:35:00", "LONG"),
    ("good_sep05_long", "good", "FILL", "2018.09.05 16:10:00", "LONG"),
    ("good_sep05_short", "good", "FILL", "2018.09.05 21:30:00", "SHORT"),
    ("late_sep06_long", "late", "FILL", "2018.09.06 11:55:00", "LONG"),
    ("late_sep17_long", "late", "FILL", "2018.09.17 16:20:00", "LONG"),
    ("late_sep24_long", "late", "FILL", "2018.09.24 15:25:00", "LONG"),
    ("missed_jun07_short", "missed", "INVALIDATE", "2018.06.07 04:15:00", "SHORT"),
    ("missed_jun27_short", "missed", "INVALIDATE", "2018.06.27 10:10:00", "SHORT"),
    ("missed_aug27_long", "missed", "INVALIDATE", "2018.08.27 11:00:00", "LONG"),
    ("missed_sep05_early_long", "missed", "INVALIDATE", "2018.09.05 04:00:00", "LONG"),
)
ANCHORS = ("wave1_start_time", "wave1_start_price", "wave1_peak_time", "wave1_peak_price",
           "wave1_peak_known_at", "fib_382_price", "fib_618_price")
SIGNAL_TIMING = ("signal_at", "signal_known_at", "trigger_type", "trigger_line_price", "trigger_known_at")
NUMERIC = {"wave1_start_price", "wave1_peak_price", "fib_382_price", "fib_618_price", "trigger_line_price"}


def number(value: str | float | None) -> float | None:
    try:
        result = float(value) if value not in (None, "") else None
        return result if result is not None and math.isfinite(result) else None
    except (TypeError, ValueError):
        return None


def at(row: dict) -> str:
    return row.get("event_at", "")


def dt(value: str) -> datetime | None:
    if not value or value.startswith("1970."):
        return None
    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")


def source_path(path: Path) -> Path:
    return path / "events.csv" if path.is_dir() else path


def read_events(path: Path) -> list[dict[str, str]]:
    raw = source_path(path).read_bytes()
    encoding = "utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig"
    text = raw.decode(encoding)
    first = text.splitlines()[0] if text else ""
    delimiter = ";" if first.count(";") >= first.count(",") else ","
    return list(csv.DictReader(io.StringIO(text), delimiter=delimiter))


def setup_key(row: dict) -> tuple[str, ...]:
    return tuple(row.get(field, "") for field in (
        "symbol", "upper_tf", "lower_tf", "direction", "candidate_detected_at", "wave1_start_time"
    )) + (f"{number(row.get('wave1_start_price')) or 0:.8f}",)


def grouped(rows: list[dict]) -> dict[tuple[str, ...], list[dict]]:
    result: dict[tuple[str, ...], list[dict]] = defaultdict(list)
    for row in rows:
        if row.get("setup_id"):
            result[setup_key(row)].append(row)
    return dict(result)


def different(expected: dict, actual: dict, fields: tuple[str, ...]) -> dict:
    differences = {}
    for field in fields:
        left, right = expected.get(field, ""), actual.get(field, "")
        same = left == right
        if field in NUMERIC:
            lhs, rhs = number(left), number(right)
            same = lhs is not None and rhs is not None and abs(lhs - rhs) <= 1e-7
        if not same:
            differences[field] = {"source": left, "observed": right}
    return differences


def room(row: dict | None) -> dict:
    if not row:
        return {"signed_price": None, "r": None, "origin": "NO_ROW"}
    if number(row.get("wave1_room_r")) is not None:
        return {"signed_price": number(row.get("wave1_room_price")),
                "r": number(row.get("wave1_room_r")), "origin": "NATIVE_RECORDED",
                "rejected": row.get("wave1_room_rejected") in {"1", "true", "TRUE"}}
    entry, sl, peak = (number(row.get(field)) for field in ("entry_price", "sl_price", "wave1_peak_price"))
    direction = 1 if row.get("direction") == "LONG" else -1
    if None in (entry, sl, peak) or not entry or not sl or abs(entry - sl) <= 0:
        return {"signed_price": None, "r": None, "origin": "UNAVAILABLE"}
    signed_price = direction * (peak - entry)
    return {"signed_price": signed_price, "r": signed_price / abs(entry - sl),
            "origin": "DERIVED_FROM_SOURCE_ENTRY_SL_FIXED_W1"}


def brief(row: dict | None) -> dict | None:
    if row is None:
        return None
    fields = (
        "event_at", "event_type", "reason_kind", "reason", "setup_id", "symbol", "upper_tf", "lower_tf",
        "direction", "candidate_detected_at", "wave1_start_time", "wave1_start_price", "wave1_peak_time",
        "wave1_peak_price", "wave1_peak_known_at", "wave2_extreme_time", "wave2_extreme_price",
        "lower_recognition", "lower_entry_stage", "lower_unmet_reason", "lower_pivot_times", "lower_pivot_prices",
        "lower_wave2_time", "lower_wave2_price", "trigger_type", "trigger_line_price", "trigger_known_at",
        "signal_at", "signal_known_at", "order_sent_at", "fill_at", "entry_price", "sl_price", "tp_price",
        "risk_points", "intended_rr", "actual_rr", "entry_status", "skip_reason", "wave1_room_price",
        "wave1_room_r", "wave1_room_rejected", "nearest_obstacle_price", "nearest_obstacle_tf",
        "nearest_obstacle_time", "nearest_obstacle_known_at", "nearest_obstacle_source", "obstacle_distance_r",
        "first_progress_bar_time", "first_progress_close_at", "first_progress_known_at",
    )
    result = {field: row[field] for field in fields if row.get(field, "") != ""}
    result["signed_wave1_room"] = room(row)
    return result


def first(rows: list[dict], event: str) -> dict | None:
    return next((row for row in rows if row.get("event_type") == event), None)


def candidate_arm(rows: list[dict], run_rows: list[dict], expected: dict, reference_at: str) -> dict:
    peak = first(rows, "WAVE1_PEAK_CONFIRMED")
    signals = [row for row in rows if row.get("event_type") == "SIGNAL"]
    fills = [row for row in rows if row.get("event_type") == "FILL"]
    skips = [row for row in rows if row.get("event_type") == "SKIP"]
    invalidations = [row for row in rows if row.get("event_type") == "INVALIDATE"]
    anchors = different(expected, peak, ANCHORS) if peak else {"fixed_peak": "missing"}
    earlier = [row for row in signals if row.get("signal_at", at(row)) < reference_at]
    result = {
        "candidate_found": bool(rows), "fixed_anchors_match": peak is not None and not anchors,
        "fixed_anchor_differences": anchors,
        "candidate_setup_ids": list(dict.fromkeys(row.get("setup_id", "") for row in rows)),
        "event_counts": dict(sorted(Counter(row.get("event_type", "") for row in rows).items())),
        "event_sequence": [{"at": at(row), "event": row.get("event_type"), "reason": row.get("reason", ""),
                            "recognition": row.get("lower_recognition", ""), "unmet": row.get("lower_unmet_reason", "")}
                           for row in rows if row.get("event_type") != "STATE"],
        "first_signal": brief(signals[0]) if signals else None,
        "signals": [brief(row) for row in signals], "fills": [brief(row) for row in fills],
        "skips": [brief(row) for row in skips], "invalidations": [brief(row) for row in invalidations],
        "last_status": brief(rows[-1]) if rows else None,
        "earlier_signals_than_source_reference": [brief(row) for row in earlier],
        "fills_at_original_reference": [brief(row) for row in fills if row.get("fill_at", at(row)) == reference_at],
        "room_skips": [brief(row) for row in skips if row.get("reason") == "WAVE1_ROOM_TOO_SMALL" or row.get("skip_reason") == "WAVE1_ROOM_TOO_SMALL"],
    }
    if not rows:
        times = [at(row) for row in run_rows if at(row)]
        outside = not times or reference_at < min(times) or reference_at > max(times)
        result["missing_candidate_reason"] = ("RUN_NOT_COVERING_CASE_TIME" if outside else
                                               "CANDIDATE_ABSENT_AFTER_LANE_OR_STRUCTURE_CHANGE_NO_DIRECT_REGRESSION_CLAIM")
        result["same_time_direction_candidates"] = [brief(row) for row in run_rows if row.get("event_type") == "WAVE1_BREAK" and
                                                     row.get("candidate_detected_at") == expected.get("candidate_detected_at") and
                                                     row.get("direction") == expected.get("direction")]
    return result


def baseline_check(expected: dict, source_rows: list[dict], control_rows: list[dict], event: str, reference_at: str) -> dict:
    original_signal = first(source_rows, "SIGNAL")
    original_fill = first(source_rows, "FILL")
    control_signal = first(control_rows, "SIGNAL")
    control_fills = [row for row in control_rows if row.get("event_type") == "FILL"]
    control_peak = first(control_rows, "WAVE1_PEAK_CONFIRMED")
    anchor_differences = different(expected, control_peak, ANCHORS) if control_peak else {"fixed_peak": "missing"}
    if event == "FILL":
        signal_differences = different(original_signal, control_signal, SIGNAL_TIMING) if original_signal and control_signal else {"signal": "missing"}
        matching_fill = [row for row in control_fills if row.get("fill_at", at(row)) == reference_at]
        timing_ok = len(matching_fill) == 1 and not signal_differences
        control_fill = matching_fill[0] if len(matching_fill) == 1 else (control_fills[0] if control_fills else None)
    else:
        matching_invalidations = [row for row in control_rows if row.get("event_type") == "INVALIDATE" and
                                  at(row) == reference_at and row.get("reason") == expected.get("reason")]
        signal_differences = {} if not original_signal and not control_signal else {"unexpected_signal": "source or control contains SIGNAL"}
        timing_ok = len(matching_invalidations) == 1 and not signal_differences
        control_fill = control_fills[0] if control_fills else None
    quote_equal = bool(original_fill and control_fill and
                       abs((number(original_fill.get("entry_price")) or 0) - (number(control_fill.get("entry_price")) or 0)) <= 1e-7)
    return {
        "candidate_found": bool(control_rows), "fixed_anchor_differences": anchor_differences,
        "signal_timing_differences": signal_differences, "reference_event_time_reproduced": timing_ok,
        "passed": bool(control_rows) and not anchor_differences and timing_ok,
        "execution_quote_comparison": {"source_fill": brief(original_fill), "control_fill": brief(control_fill),
                                       "entry_quote_equal": quote_equal,
                                       "scope": "Signal/fixed-anchor reproduction and executable tick quotes are assessed separately."},
    }


def case_result(case: tuple[str, ...], source: list[dict], source_groups: dict,
                arms: dict[str, list[dict]], arm_groups: dict[str, dict]) -> dict:
    name, category, event, reference_at, direction = case
    matches = [row for row in source if row.get("event_type") == event and row.get("direction") == direction and
               (row.get("fill_at", at(row)) if event == "FILL" else at(row)) == reference_at]
    result = {"case": name, "category": category, "direction": direction, "source_reference_at": reference_at,
              "source_reference_event": event, "source_reference_unique": len(matches) == 1, "passed": False}
    if len(matches) != 1:
        result["limitation"] = "SOURCE_REFERENCE_NOT_UNIQUE_NO_CASE_CLAIM"
        return result
    expected = matches[0]
    key = setup_key(expected)
    original_rows = source_groups.get(key, [])
    result["identity_without_serial"] = list(key)
    result["source_reference"] = brief(expected)
    result["source_first_signal"] = brief(first(original_rows, "SIGNAL"))
    result["baseline"] = baseline_check(expected, original_rows, arm_groups[ARMS[0]].get(key, []), event, reference_at)
    result["arms"] = {arm: candidate_arm(arm_groups[arm].get(key, []), arms[arm], expected, reference_at) for arm in ARMS}
    full = result["arms"]["a_v140_full"]
    complete = result["baseline"]["passed"] and full["candidate_found"] and full["fixed_anchors_match"]
    earlier_fills = [row for row in full["fills"] if row.get("fill_at", row.get("event_at", "")) < reference_at and
                     (row["signed_wave1_room"]["r"] is not None and row["signed_wave1_room"]["r"] + 1e-8 >= MINIMUM_ROOM_R)]
    result["comparison_complete"] = complete
    result["full_legitimate_earlier_fills"] = earlier_fills
    if category == "good":
        retained = [row for row in full["fills"] if row.get("fill_at", row.get("event_at", "")) <= reference_at]
        result["passed"] = complete and bool(retained)
        result["outcome"] = "PRESERVED_OR_EARLIER_GOOD_ENTRY" if result["passed"] else "GOOD_ENTRY_NOT_PRESERVED_OR_COMPARISON_INCOMPLETE"
    elif category == "late":
        no_old_late_fill = not full["fills_at_original_reference"]
        direct_mechanism = bool(full["room_skips"]) or bool(earlier_fills)
        result["passed"] = complete and no_old_late_fill and direct_mechanism
        result["outcome"] = "OLD_LATE_ENTRY_BLOCKED_OR_REPLACED_BY_EARLIER_ROOM" if result["passed"] else "LATE_ENTRY_CORRECTION_NOT_DIRECTLY_PROVEN"
    else:
        # These were requests to inspect short pullbacks, not universal must-trade
        # labels. Do not equate no new entry with a regression or invent a win.
        result["passed"] = None
        result["outcome"] = "EARLIER_ENTRY_WITH_ROOM_OBSERVED" if earlier_fills else "NO_EARLIER_ADMISSIBLE_FILL_REVIEW_REQUIRED"
        result["improved_candidate_observed"] = complete and bool(earlier_fills)
        result["review_required"] = True
    if not complete:
        result["limitation"] = ("Control reproduction, same-candidate availability or fixed-W1 equality is incomplete; "
                                "candidate absence never counts as correction.")
    return result


def counts(rows: list[dict], groups: dict, arm: str) -> dict:
    types = Counter(row.get("event_type", "") for row in rows)
    signals = [row for row in rows if row.get("event_type") == "SIGNAL"]
    fills = [row for row in rows if row.get("event_type") == "FILL"]
    entry_rooms = []
    for fill in fills:
        candidate = groups.get(setup_key(fill), [])
        order = next((row for row in reversed(candidate) if row.get("event_type") == "ORDER" and at(row) <= at(fill)), None)
        signal = first(candidate, "SIGNAL")
        planned = order or signal
        planned_room, filled_room = room(planned), room(fill)
        planned_r, filled_r = planned_room["r"], filled_room["r"]
        entry_rooms.append({
            "setup_id": fill.get("setup_id"), "direction": fill.get("direction"), "fill_at": fill.get("fill_at", at(fill)),
            "entry_price": number(fill.get("entry_price")), "sl_price": number(fill.get("sl_price")),
            "tp_price": number(fill.get("tp_price")), "wave1_peak_price": number(fill.get("wave1_peak_price")),
            "recognition": fill.get("lower_recognition", ""), "stage": fill.get("lower_entry_stage", ""),
            "pre_order_room": planned_room, "fill_room": filled_room,
            "pre_order_admissible_at_025r": planned_r is not None and planned_r + 1e-8 >= MINIMUM_ROOM_R,
            "fill_room_at_least_025r": filled_r is not None and filled_r + 1e-8 >= MINIMUM_ROOM_R,
        })
    planned_values = [row["pre_order_room"]["r"] for row in entry_rooms if row["pre_order_room"]["r"] is not None]
    fill_values = [row["fill_room"]["r"] for row in entry_rooms if row["fill_room"]["r"] is not None]
    room_gated = arm in {"a_room_only", "a_v140_full"}
    return {
        "rows": len(rows), "event_counts": dict(sorted(types.items())), "candidate_breaks": types["WAVE1_BREAK"],
        "distinct_candidates": len(groups), "signals": len(signals), "fills": len(fills),
        "room_skips": sum(row.get("event_type") == "SKIP" and (row.get("reason") == "WAVE1_ROOM_TOO_SMALL" or row.get("skip_reason") == "WAVE1_ROOM_TOO_SMALL") for row in rows),
        "signal_recognition_counts": dict(Counter(row.get("lower_recognition") or "LEGACY_UNRECORDED" for row in signals)),
        "fill_recognition_counts": dict(Counter(row.get("lower_recognition") or "LEGACY_UNRECORDED" for row in fills)),
        "signal_stage_counts": dict(Counter(row.get("lower_entry_stage", "") for row in signals)),
        "invalidations": dict(Counter(row.get("reason", "") for row in rows if row.get("event_type") == "INVALIDATE")),
        "room_gate_enabled": room_gated, "minimum_pre_order_room_r": min(planned_values) if planned_values else None,
        "minimum_fill_room_r": min(fill_values) if fill_values else None,
        "all_entries_have_room_fields": len(planned_values) == len(fills) and len(fill_values) == len(fills),
        "admissible_pre_order_count": sum(row["pre_order_admissible_at_025r"] for row in entry_rooms),
        "below_minimum_fill_room_count": sum(not row["fill_room_at_least_025r"] for row in entry_rooms),
        "room_gate_pre_order_passed": all(row["pre_order_admissible_at_025r"] for row in entry_rooms) if room_gated else None,
        "all_entry_rooms": entry_rooms,
    }


def provenance(path: Path) -> dict:
    path = source_path(path)
    return {"path": str(path.resolve()), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def cell(value: object) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def markdown(report: dict) -> str:
    lines = [
        "# W1までの余地・下位足認識：固定画像10事例の比較", "",
        "時刻は元データのブローカー時刻。候補番号を除き、銘柄・上下時間足・方向・候補認識時刻・W1始点日時/価格で照合。",
        "利益や勝敗で抽出しない。controlの再現、同じ候補・固定W1の確認ができない事例は改善済みと判定しない。", "",
        "- control：v1.30の認識、W1余地の制限なし。",
        "- recognition_only：下位足認識のみ変更、余地の制限なし。",
        "- room_only：v1.30の認識、W1まで最低0.25R。",
        "- full：認識変更＋W1まで最低0.25R。", "",
        "## 固定事例", "",
        "|事例|元日時|control再現|full最初のSIGNAL|full約定|余地R・約定時|判定|",
        "|---|---|---|---|---|---|---|",
    ]
    for case in report["cases"]:
        full = case.get("arms", {}).get("a_v140_full", {})
        signal = full.get("first_signal") or {}
        fills = full.get("fills", [])
        fill_times = ", ".join(row.get("fill_at", row.get("event_at", ""))[11:16] for row in fills) or "なし"
        room_values = ", ".join(f"{row['signed_wave1_room']['r']:.3f}" if row["signed_wave1_room"]["r"] is not None else "不明" for row in fills) or "—"
        verdict = "PASS" if case.get("passed") is True else ("要目視" if case.get("passed") is None else "未成立")
        lines.append("|" + "|".join(map(cell, [case["case"], case["source_reference_at"],
                     case.get("baseline", {}).get("passed", False), signal.get("signal_at", "なし"), fill_times, room_values, verdict])) + "|")
    lines += ["", "## 全候補の観測数", "", "|設定|候補|SIGNAL|FILL|余地で見送り|最小余地R・発注前|最小余地R・約定後|",
              "|---|---:|---:|---:|---:|---:|---:|"]
    for arm in ARMS:
        info = report["counts"][arm]
        def fmt(value: float | None) -> str:
            return "—" if value is None else f"{value:.3f}"
        lines.append(f"|{arm}|{info['candidate_breaks']}|{info['signals']}|{info['fills']}|{info['room_skips']}|{fmt(info['minimum_pre_order_room_r'])}|{fmt(info['minimum_fill_room_r'])}|")
    lines += ["", "## 各設定の事例結果", "", "|事例|設定|SIGNAL|FILL|見送り・失効理由|認識|", "|---|---|---|---|---|---|"]
    for case in report["cases"]:
        for arm, info in case.get("arms", {}).items():
            signal = info.get("first_signal") or {}
            times = ",".join(row.get("fill_at", row.get("event_at", ""))[11:16] for row in info.get("fills", [])) or "なし"
            reasons = list(dict.fromkeys(row.get("reason") or row.get("skip_reason", "") for row in info.get("skips", []) + info.get("invalidations", [])))
            if not info["candidate_found"]:
                reasons = [info.get("missing_candidate_reason", "候補なし")]
            lines.append("|" + "|".join(map(cell, [case["case"], arm.removeprefix("a_"), signal.get("signal_at", "なし"), times,
                         ", ".join(reasons), signal.get("lower_recognition", "")])) + "|")
    lines += ["", "簡易認識 `SIMPLE_REACTION_BREAK` は厳密な下位1→2→3の成立を主張しない。",
              "短い調整の見送り4例は、全てを売買必須とは決めず、早い約定が生じたかを観測した。",
              "正の余地は、W1を越えてTPへ進む保証ではない。最低0.25Rは比較のための初期仮定。",
              "全イベント、基準アンカー差、時刻差、注文価格差、全約定の符号付き余地、欠落候補は [entry_room_case_regression.json](entry_room_case_regression.json) に保存。", ""]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path, help="Read-only snapshot of the user's native event CSV")
    parser.add_argument("--batch", required=True, type=Path, help="Directory containing the four named arm subdirectories")
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    source = read_events(args.source)
    arms = {arm: read_events(args.batch / arm) for arm in ARMS}
    source_groups = grouped(source)
    arm_groups = {arm: grouped(rows) for arm, rows in arms.items()}
    report = {
        "purpose": "FIXED_CASE_ENTRY_ROOM_AND_RECOGNITION_REGRESSION_NOT_PROFITABILITY",
        "source_clock": "Original broker/source clock; no UTC conversion inferred.",
        "matching": "symbol, upper_tf, lower_tf, direction, candidate_detected_at, W1 start time/price; setup serial ignored",
        "minimum_wave1_room_r": MINIMUM_ROOM_R,
        "room_definition": "direction*(fixed_W1_endpoint-executable_entry)/abs(executable_entry-structural_SL); signed, not absolute distance",
        "provenance": {"source": provenance(args.source), **{arm: provenance(args.batch / arm) for arm in ARMS}},
        "counts": {arm: counts(rows, arm_groups[arm], arm) for arm, rows in arms.items()},
        "cases": [case_result(case, source, source_groups, arms, arm_groups) for case in CASES],
    }
    acceptance = [case for case in report["cases"] if case["category"] in {"good", "late"}]
    report["fixed_good_and_late_regression_passed"] = all(case["passed"] is True for case in acceptance)
    report["all_case_comparisons_complete"] = all(case.get("comparison_complete", False) for case in report["cases"])
    report["all_room_gated_entries_admissible_pre_order"] = all(report["counts"][arm]["room_gate_pre_order_passed"] for arm in ("a_room_only", "a_v140_full"))
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "entry_room_case_regression.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (args.out / "README.md").write_text(markdown(report), encoding="utf-8")
    print(json.dumps({"fixed_good_and_late_regression_passed": report["fixed_good_and_late_regression_passed"],
                      "all_case_comparisons_complete": report["all_case_comparisons_complete"],
                      "all_room_gated_entries_admissible_pre_order": report["all_room_gated_entries_admissible_pre_order"],
                      "cases": [{"case": case["case"], "passed": case["passed"], "outcome": case.get("outcome"),
                                 "baseline_reproduced": case.get("baseline", {}).get("passed", False)} for case in report["cases"]],
                      "output": str(args.out.resolve())}, ensure_ascii=False))


if __name__ == "__main__":
    main()
