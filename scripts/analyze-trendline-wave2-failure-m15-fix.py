#!/usr/bin/env python3
from __future__ import annotations

import csv
import html
import json
import re
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OLD_RUN = ROOT / "reports/backtest/runs/20260815_trendline_wave2_failure/new_bucket_only_2024"
OUT = ROOT / "reports/backtest/runs/20260816_trendline_wave2_failure_execution_shadow"
NEW_RUN = OUT / "execution_shadow_2024"


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    fields = list(dict.fromkeys(key for row in rows for key in row))
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def metric_map(path: Path) -> dict[str, int]:
    return {row["metric"]: int(row["value"]) for row in read_csv(path)}


def preset_map(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="ascii").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            result[key] = value
    return result


def report_rows(path: Path) -> list[list[str]]:
    text = path.read_text(encoding="utf-16")
    rows: list[list[str]] = []
    for row_html in re.findall(r"<tr[^>]*>(.*?)</tr>", text, flags=re.I | re.S):
        cells = re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", row_html, flags=re.I | re.S)
        cells = [html.unescape(re.sub(r"<[^>]+>", "", cell)).replace("\xa0", " ").strip()
                 for cell in cells]
        if cells:
            rows.append(cells)
    return rows


def report_value(rows: list[list[str]], label: str) -> str:
    for cells in rows:
        for index, cell in enumerate(cells[:-1]):
            if cell == label:
                return cells[index + 1]
    return ""


def parse_time(value: str) -> datetime | None:
    if not value:
        return None
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            continue
    raise ValueError(f"Unexpected timestamp: {value}")


old = metric_map(OLD_RUN / "new_tw2f_new_bucket_only_2024_summary.csv")
new = metric_map(NEW_RUN / "new_tw2f_execution_shadow_2024_summary.csv")

stages = [
    ("h4_impulses", "h4_impulses", "h4_impulses"),
    ("h4_structure_breaks", "h4_structure_breaks", "h4_structure_breaks"),
    ("h1_mature", "h1_mature", "h1_mature"),
    ("h1_trendline_breaks", "h1_trendline_breaks", "h1_trendline_breaks"),
    ("countertrend_structure", None, "countertrend_structure"),
    ("anchor_frozen", "m15_pullbacks", "anchor_frozen"),
    ("post_anchor_swing", None, "post_anchor_swing"),
    ("equal_extreme", None, "equal_extreme"),
    ("higher_low_or_lower_high", None, "higher_low_or_lower_high"),
    ("false_break_recovery", None, "false_break_recovery"),
    ("failure_invalidated", None, "failure_invalidated"),
    ("continuation_failure", "m15_continuation_failures", "continuation_failure"),
    ("protected_break", "m15_structure_breaks", "protected_break"),
    ("ma_filter_reject", None, "ma_filter_reject"),
    ("execution_pass", "execution_pass", "execution_pass"),
    ("order", "orders", "order"),
]
funnel_rows: list[dict[str, object]] = []
for stage, old_key, new_key in stages:
    old_value: int | str = old.get(old_key, 0) if old_key else "not_recorded"
    new_value = new.get(new_key, 0)
    delta: int | str = new_value - old_value if isinstance(old_value, int) else "not_comparable"
    funnel_rows.append({
        "stage": stage,
        "old_metric": old_key or "not_recorded",
        "old_value": old_value,
        "new_metric": new_key,
        "new_value": new_value,
        "delta": delta,
    })
write_csv(OUT / "funnel_comparison_2024.csv", funnel_rows)

old_preset = preset_map(OLD_RUN / "preset.set")
new_preset = preset_map(NEW_RUN / "preset.set")
parameter_rows: list[dict[str, object]] = []
for key in sorted(set(old_preset) | set(new_preset)):
    if old_preset.get(key) != new_preset.get(key):
        parameter_rows.append({
            "parameter": key,
            "old_value": old_preset.get(key, ""),
            "new_value": new_preset.get(key, ""),
            "classification": "run_identity_only" if key in {
                "InpMagicNumber", "InpTW2FMagicNumber", "InpRunId", "InpLogFolder", "InpTW2FLogFolder"
            } else "strategy_parameter_change",
        })
write_csv(OUT / "parameter_diff_2024.csv", parameter_rows)

events = read_csv(NEW_RUN / "new_tw2f_execution_shadow_2024_events.csv")
reversal = next((row for row in events if row["state_after"] == "H1_REVERSAL_LEG"), None)
timeline: list[dict[str, object]] = []
if reversal:
    setup_id = reversal["setup_id"]
    keep_states = {"H1_TREND_MATURE", "H1_TRENDLINE_BROKEN", "H1_REVERSAL_LEG", "EXPIRED"}
    for row in events:
        if row["setup_id"] == setup_id and row["state_after"] in keep_states:
            timeline.append({
                "timestamp": row["timestamp"],
                "symbol": row["symbol"],
                "direction": row["direction"],
                "setup_id": row["setup_id"],
                "state_before": row["state_before"],
                "state_after": row["state_after"],
                "reason": row["reject_reason"],
                "pivot_time": row["pivot_time"],
                "confirmation_time": row["confirmation_time"],
            })
write_csv(OUT / "representative_state_timeline_2024.csv", timeline)

checks = [
    ("generic", "pivot_time", "confirmation_time"),
    ("reference", "m15_reference_pivot_time", "m15_reference_confirmation_time"),
    ("protected", "m15_protected_pivot_time", "m15_protected_confirmation_time"),
    ("post_anchor", "m15_post_anchor_pivot_time", "m15_post_anchor_confirmation_time"),
]
causality_rows: list[dict[str, object]] = []
for name, pivot_key, confirmation_key in checks:
    populated = pivot_after_confirmation = confirmation_after_event = 0
    for row in events:
        pivot = parse_time(row.get(pivot_key, ""))
        confirmation = parse_time(row.get(confirmation_key, ""))
        event_time = parse_time(row["timestamp"])
        if pivot is None or confirmation is None:
            continue
        populated += 1
        pivot_after_confirmation += int(pivot > confirmation)
        confirmation_after_event += int(confirmation > event_time)
    causality_rows.append({
        "time_pair": name,
        "populated_event_rows": populated,
        "pivot_after_confirmation_violations": pivot_after_confirmation,
        "confirmation_after_event_violations": confirmation_after_event,
        "status": "PASS" if pivot_after_confirmation == 0 and confirmation_after_event == 0 else "FAIL",
    })
write_csv(OUT / "causality_audit_2024.csv", causality_rows)

report = report_rows(NEW_RUN / "report.html")
trades = int(report_value(report, "取引数:") or "0")
deals = int(report_value(report, "約定数:") or "0")
trade_integrity = [{
    "check": "lot_sl_post_fill_2r_total_risk_currency_risk_margin_mt5_vs_csv",
    "status": "NOT_APPLICABLE_NO_NEW_BUCKET_TRADES" if trades == 0 else "REQUIRES_TRADE_LEVEL_AUDIT",
    "mt5_trades": trades,
    "mt5_deals": deals,
    "custom_order_count": new.get("order", 0),
}]
write_csv(OUT / "trade_integrity_2024.csv", trade_integrity)

test_rows = [
    {
        "test_suite": "pattern_classification_reachability",
        "scope": "Long/Short equal, higher-low/lower-high, false-break through M15_CONTINUATION_FAILED",
        "passed": new.get("pattern_reachability_tests_passed", 0),
        "failed": new.get("pattern_reachability_tests_failed", 0),
        "full_m15_path": False,
        "candidate_assertions": "not_applicable",
    },
    {
        "test_suite": "m15_end_to_end_state_reachability",
        "scope": "Long and Short H1_REVERSAL_LEG through ENTRY_READY",
        "passed": new.get("m15_path_tests_passed", 0),
        "failed": new.get("m15_path_tests_failed", 0),
        "full_m15_path": True,
        "candidate_assertions": "valid,stateIndex,direction,stopLoss,takeProfit,volume",
    },
]
write_csv(OUT / "m15_test_summary_2024.csv", test_rows)

shadow_rows = read_csv(NEW_RUN / "new_tw2f_execution_shadow_2024_expiry_shadow.csv")
shadow_summary: list[dict[str, object]] = []
shadow_temporal_violations = 0
for row in shadow_rows:
    expiry_time = parse_time(row.get("expiry_time", ""))
    counter_time = parse_time(row.get("first_counter_structure_time", ""))
    anchor_time = parse_time(row.get("shadow_anchor_time", ""))
    origin_break_time = parse_time(row.get("h1_wave1_origin_break_time", ""))
    ordered = (
        expiry_time is not None and
        (counter_time is None or counter_time > expiry_time) and
        (anchor_time is None or anchor_time > expiry_time) and
        (counter_time is None or anchor_time is None or anchor_time >= counter_time) and
        (anchor_time is None or origin_break_time is None or anchor_time < origin_break_time)
    )
    shadow_temporal_violations += int(not ordered)
    shadow_summary.append({
        **row,
        "expiry_to_anchor_h1_bars": row.get("anchor_h1_bars_after_expiry", ""),
        "anchor_within_original_72_h1_bars": (
            int(row["anchor_h1_bars_from_break"]) <= 72 if row.get("anchor_h1_bars_from_break") else False
        ),
        "anchor_within_shadow_240_h1_bars": bool(row.get("shadow_anchor_time")),
        "shadow_order_safety": "PASS" if row.get("shadow_order_attempts") == "0" else "FAIL",
        "temporal_order_audit": "PASS" if ordered else "FAIL",
    })
write_csv(OUT / "shadow_diagnostic_2024.csv", shadow_summary)

summary = {
    "period": "2024.01.01..2024.12.31",
    "tester_model": 4,
    "history_quality": "99% real ticks" if report_value(report, "ヒストリー品質:").startswith("99%")
                       else report_value(report, "ヒストリー品質:"),
    "ticks": int(report_value(report, "ティック:") or "0"),
    "mt5_trades": trades,
    "mt5_deals": deals,
    "custom_orders": new.get("order", 0),
    "pattern_reachability_tests_passed": new.get("pattern_reachability_tests_passed", 0),
    "pattern_reachability_tests_failed": new.get("pattern_reachability_tests_failed", 0),
    "m15_path_tests_passed": new.get("m15_path_tests_passed", 0),
    "m15_path_tests_failed": new.get("m15_path_tests_failed", 0),
    "shadow_started": new.get("shadow_started", 0),
    "shadow_anchor": new.get("shadow_anchor", 0),
    "shadow_anchor_before_origin_break": new.get("shadow_anchor_before_origin_break", 0),
    "shadow_no_anchor_within_240": new.get("shadow_no_anchor_within_240", 0),
    "shadow_order_attempts": new.get("shadow_order_attempts", 0),
    "shadow_temporal_order_violations": shadow_temporal_violations,
    "strategy_parameter_change_count": sum(
        row["classification"] == "strategy_parameter_change" for row in parameter_rows
    ),
    "runtime_causality_violation_count": sum(
        int(row["pivot_after_confirmation_violations"]) + int(row["confirmation_after_event_violations"])
        for row in causality_rows
    ),
    "m15_runtime_rows": sum(
        int(row["populated_event_rows"]) for row in causality_rows if row["time_pair"] != "generic"
    ),
}
(OUT / "validation_summary_2024.json").write_text(
    json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
print(json.dumps(summary, ensure_ascii=False, indent=2))
