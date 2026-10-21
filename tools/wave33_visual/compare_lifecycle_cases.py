"""Compare the three user-identified USDJPY cases without relying on setup serials.

This is a causal lifecycle regression, not a profitability or video-match test.
The original user's event CSV is read only. Native runs are supplied separately.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from collections import Counter
from datetime import datetime, timedelta
from pathlib import Path


CASES = (
    ("20160512_short", "2016.05.12 01:55:00", "SHORT"),
    ("20160516_long", "2016.05.16 14:30:00", "LONG"),
    ("20160523_short", "2016.05.23 16:50:00", "SHORT"),
)
TIME_FORMAT = "%Y.%m.%d %H:%M:%S"
ANCHOR_FIELDS = (
    "wave1_start_time", "wave1_start_price", "wave1_peak_time",
    "wave1_peak_price", "wave1_peak_known_at", "fib_382_price", "fib_618_price",
)
SIGNAL_FIELDS = (
    "signal_at", "signal_known_at", "trigger_type", "trigger_line_price",
    "trigger_known_at", "pivot_trigger_price", "trendline_trigger_price",
    "lower_pivot_times", "lower_pivot_prices",
)
PRICE_FIELDS = {
    "wave1_start_price", "wave1_peak_price", "fib_382_price", "fib_618_price",
    "trigger_line_price", "pivot_trigger_price", "trendline_trigger_price",
    "entry_price", "sl_price", "tp_price",
}


def read_events(path: Path) -> list[dict[str, str]]:
    if path.is_dir():
        path = path / "events.csv"
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream, delimiter=";"))


def at(row: dict[str, str]) -> str:
    return row.get("event_at", row.get("signal_known_at", ""))


def dt(value: str) -> datetime | None:
    return datetime.strptime(value, TIME_FORMAT) if value else None


def setup_key(row: dict[str, str]) -> tuple[str, ...]:
    # Fixed setup identity excludes serials, which may change when lanes are freed earlier.
    return (
        row.get("symbol", ""), row.get("upper_tf", ""), row.get("lower_tf", ""),
        row.get("direction", ""), row.get("candidate_detected_at", ""),
        row.get("wave1_start_time", ""), f"{float(row.get('wave1_start_price') or 0):.8f}",
    )


def same_value(field: str, left: str, right: str) -> bool:
    if field in PRICE_FIELDS:
        return abs(float(left or 0) - float(right or 0)) <= 1e-7
    if field == "lower_pivot_prices":
        lhs, rhs = left.split("|"), right.split("|")
        return len(lhs) == len(rhs) and all(abs(float(a) - float(b)) <= 1e-7 for a, b in zip(lhs, rhs))
    return left == right


def mismatches(expected: dict[str, str], observed: dict[str, str], fields: tuple[str, ...]) -> dict:
    return {
        field: {"source": expected.get(field, ""), "observed": observed.get(field, "")}
        for field in fields
        if not same_value(field, expected.get(field, ""), observed.get(field, ""))
    }


def brief(row: dict[str, str]) -> dict:
    fields = (
        "event_at", "event_type", "reason_kind", "reason", "setup_id", "direction",
        "candidate_detected_at", "wave1_start_time", "wave1_start_price", "wave1_peak_time",
        "wave1_peak_price", "wave1_peak_known_at", "wave2_extreme_time", "wave2_extreme_price",
        "trigger_line_price", "pivot_trigger_price", "signal_at", "signal_known_at", "entry_price",
        "first_progress_bar_time", "first_progress_close_at", "first_progress_known_at", "first_progress_price",
        "lower_wave2_time", "lower_wave2_price", "entry_status", "skip_reason",
    )
    return {field: row[field] for field in fields if row.get(field, "") != ""}


def counts(rows: list[dict[str, str]]) -> dict:
    types = Counter(row.get("event_type", "") for row in rows)
    signals = [row for row in rows if row.get("event_type") == "SIGNAL"]
    return {
        "rows": len(rows), "event_counts": dict(sorted(types.items())),
        "candidate_breaks": types["WAVE1_BREAK"], "signals": len(signals),
        "signal_directions": dict(Counter(row.get("direction", "") for row in signals)),
        "invalidations": dict(Counter(row.get("reason", "") for row in rows if row.get("event_type") == "INVALIDATE")),
    }


def case_result(case: tuple[str, str, str], source: list[dict[str, str]],
                legacy: list[dict[str, str]], strict: list[dict[str, str]]) -> dict:
    name, signal_at, direction = case
    original = [row for row in source if row.get("event_type") == "SIGNAL" and
                row.get("direction") == direction and row.get("signal_at") == signal_at]
    result = {"case": name, "original_signal_at": signal_at, "direction": direction,
              "source_signal_unique": len(original) == 1, "passed": False}
    if len(original) != 1:
        result["limitation"] = "Original signal not uniquely identified; no reproduction or removal claim allowed."
        return result
    expected = original[0]
    key = setup_key(expected)
    old_rows = [row for row in legacy if setup_key(row) == key]
    new_rows = [row for row in strict if setup_key(row) == key]
    old_signals = [row for row in old_rows if row.get("event_type") == "SIGNAL"]
    new_signals = [row for row in new_rows if row.get("event_type") == "SIGNAL"]
    old_matching = [row for row in old_signals if row.get("signal_at") == signal_at]
    mismatch = mismatches(expected, old_matching[0], ANCHOR_FIELDS + SIGNAL_FIELDS) if len(old_matching) == 1 else {"signal": "missing or duplicated"}
    reproduced = len(old_matching) == 1 and not mismatch
    cutoffs = [row for row in new_rows if row.get("event_type") == "INVALIDATE" and
               row.get("reason") == "INITIAL_MOVE_MISSED" and at(row) < signal_at]
    cutoff = cutoffs[0] if cutoffs else None
    later_reuse = [row for row in new_rows if cutoff and row.get("event_type") in
                   {"SIGNAL", "ORDER", "FILL", "LOWER_STRUCTURE_CONFIRMED"} and at(row) > at(cutoff)]
    new_peak = next((row for row in new_rows if row.get("event_type") == "WAVE1_PEAK_CONFIRMED"), None)
    anchors_match = new_peak is not None and not mismatches(expected, new_peak, ANCHOR_FIELDS)
    progress = [row for row in new_rows if row.get("event_type") == "INITIAL_MOVE_PROGRESS"]
    day = dt(signal_at).replace(hour=0, minute=0, second=0)
    day_end = day + timedelta(days=1)
    # All same-day new signals are listed, including fresh candidates; never imply all trades were removed.
    other_signals = [brief(row) for row in strict if row.get("event_type") == "SIGNAL" and
                     dt(at(row)) and day <= dt(at(row)) < day_end and setup_key(row) != key]
    source_fill = next((row for row in source if setup_key(row) == key and row.get("event_type") == "FILL"), None)
    legacy_fill = next((row for row in old_rows if row.get("event_type") == "FILL"), None)
    result.update({
        "source": brief(expected), "identity_without_serial": list(key),
        "legacy_candidate_found": bool(old_rows), "legacy_signal_reproduced": reproduced,
        "legacy_source_mismatches": mismatch, "legacy_signals": [brief(row) for row in old_signals],
        "execution_quote_comparison": {
            "source_fill": brief(source_fill) if source_fill else None,
            "legacy_fill": brief(legacy_fill) if legacy_fill else None,
            "quotes_equal": bool(source_fill and legacy_fill and same_value("entry_price", source_fill.get("entry_price", ""), legacy_fill.get("entry_price", ""))),
            "scope": "Signal/anchor reproduction is separate from tick-model execution quotes.",
        },
        "strict_candidate_found": bool(new_rows), "strict_fixed_anchors_match": anchors_match,
        "strict_initial_progress": [brief(row) for row in progress],
        "strict_invalidation_before_old_signal": brief(cutoff) if cutoff else None,
        "strict_signals_same_candidate": [brief(row) for row in new_signals],
        "strict_events_after_invalidation": [brief(row) for row in later_reuse],
        "strict_other_signals_on_image_day": other_signals,
        "passed": reproduced and bool(new_rows) and anchors_match and cutoff is not None and not new_signals and not later_reuse,
    })
    if not new_rows:
        result["limitation"] = "Candidate absent after earlier lane changes; absence alone does not prove this case's lifecycle correction."
    elif not result["passed"]:
        result["limitation"] = "Required reproduction, fixed-anchor equality, direct lifecycle invalidation, or no-reuse check is incomplete."
    return result


def path_and_hash(path: Path) -> dict:
    path = path / "events.csv" if path.is_dir() else path
    return {"path": str(path.resolve()), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def markdown(report: dict) -> str:
    lines = [
        "# 画像3事例：旧設定の再現と候補寿命の修正確認", "",
        "時刻は元データのブローカー時刻。セットアップ番号を使わず、銘柄・方向・候補時刻・第1波始点で照合する。",
        "旧挙動を再現できない事例は、修正済みとは判定しない。成績・動画との完全一致を評価する比較ではない。", "",
        "|事例|旧シグナル再現|同じ候補を特定|同じ第1波|旧エントリー前の終了|同候補の売買数|判定|",
        "|---|---|---|---|---|---:|---|",
    ]
    for case in report["cases"]:
        cutoff = case.get("strict_invalidation_before_old_signal") or {}
        lines.append("|" + "|".join([
            case["case"], str(case.get("legacy_signal_reproduced", False)),
            str(case.get("strict_candidate_found", False)), str(case.get("strict_fixed_anchors_match", False)),
            cutoff.get("event_at", "未確認"), str(len(case.get("strict_signals_same_candidate", []))),
            "PASS" if case["passed"] else "未成立",
        ]) + "|")
    lines += ["", "## 全体の観測数", "", "|設定|候補|SIGNAL|FILL|EXIT|", "|---|---:|---:|---:|---:|"]
    for label in ("legacy", "strict"):
        counts_ = report["counts"][label]
        types = counts_["event_counts"]
        lines.append(f"|{label}|{counts_['candidate_breaks']}|{counts_['signals']}|{types.get('FILL', 0)}|{types.get('EXIT', 0)}|")
    for case in report["cases"]:
        lines += ["", f"## {case['case']}", ""]
        if case.get("limitation"):
            lines += [case["limitation"], ""]
        for event in case.get("strict_initial_progress", []):
            lines.append(f"- 最初の進行を観測：{event.get('event_at')}、価格 {event.get('first_progress_price', '')}。")
        cutoff = case.get("strict_invalidation_before_old_signal")
        if cutoff:
            lines.append(f"- 候補終了：{cutoff.get('event_at')}、`{cutoff.get('reason')}`。")
        others = case.get("strict_other_signals_on_image_day", [])
        lines.append(f"- 同日の別候補SIGNAL：{len(others)}件。別候補を含むすべての売買を消したという意味ではない。")
        for event in others:
            lines.append(f"  - {event.get('signal_at')} {event.get('direction')}、候補認識 {event.get('candidate_detected_at')}、W1 {event.get('wave1_start_time')} → {event.get('wave1_peak_time')}。")
    lines += ["", "元CSV・各runのSHA256、固定アンカーとシグナル価格の差、同日の別候補は [case_regression.json](case_regression.json) に保存した。", ""]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--legacy", required=True, type=Path)
    parser.add_argument("--strict", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    source, legacy, strict = (read_events(path) for path in (args.source, args.legacy, args.strict))
    report = {
        "purpose": "CAUSAL_LIFECYCLE_CASE_REGRESSION_NOT_PROFITABILITY",
        "source_clock": "Original broker/source clock; no UTC conversion inferred.",
        "matching": "symbol, upper_tf, lower_tf, direction, candidate_detected_at, W1 start time/price; setup serial ignored",
        "provenance": {label: path_and_hash(path) for label, path in (("source", args.source), ("legacy", args.legacy), ("strict", args.strict))},
        "counts": {"legacy": counts(legacy), "strict": counts(strict)},
        "cases": [case_result(case, source, legacy, strict) for case in CASES],
    }
    report["passed"] = all(case["passed"] for case in report["cases"])
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "case_regression.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (args.out / "README.md").write_text(markdown(report), encoding="utf-8")
    print(json.dumps({"passed": report["passed"], "cases": [{"case": case["case"], "passed": case["passed"], "baseline_reproduced": case.get("legacy_signal_reproduced", False)} for case in report["cases"]], "output": str(args.out.resolve())}, ensure_ascii=False))


if __name__ == "__main__":
    main()
