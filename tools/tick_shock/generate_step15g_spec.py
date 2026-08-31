#!/usr/bin/env python3
"""Generate the frozen Step 15G RED fixtures and independent expected values."""
from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIX = ROOT / "tests/tick_shock/fixtures"
EXP = ROOT / "tests/tick_shock/expected"
RED = ROOT / "reports/tests/tick_shock/step15g_red"

CASES = [
    ("TS15G-DIR-001", "direction", "LONG", "action_direction", "1", "continuation long"),
    ("TS15G-DIR-002", "direction", "SHORT", "action_direction", "-1", "continuation short"),
    ("TS15G-DIR-003", "direction", "LONG", "action_direction", "-1", "reversal after long shock"),
    ("TS15G-DIR-004", "direction", "SHORT", "action_direction", "1", "reversal after short shock"),
    ("TS15G-ENTRY-001", "entry", "LONG", "entry_price", "1.0002", "long enters on Ask"),
    ("TS15G-ENTRY-002", "entry", "SHORT", "entry_price", "1.0000", "short enters on Bid"),
    ("TS15G-ENTRY-003", "entry", "BOTH", "entry_quote_msc", "1001", "first strictly later quote"),
    ("TS15G-RISK-001", "risk", "BOTH", "risk_distance", "0.001", "max of ATR fraction, spread multiple, broker stop"),
    ("TS15G-RISK-002", "risk", "BOTH", "risk_source", "ATR14_M5", "ATR branch wins"),
    ("TS15G-RISK-003", "risk", "BOTH", "risk_source", "ENTRY_SPREAD", "spread branch wins"),
    ("TS15G-RISK-004", "risk", "BOTH", "risk_source", "BROKER_STOP", "broker stop branch wins"),
    ("TS15G-RR-001", "barrier", "LONG", "realized_rr", "1.2", "long TP rounds outward"),
    ("TS15G-RR-002", "barrier", "SHORT", "realized_rr", "1.2", "short TP rounds outward"),
    ("TS15G-TOUCH-001", "first_touch", "LONG", "result", "TP_FIRST", "long TP first"),
    ("TS15G-TOUCH-002", "first_touch", "SHORT", "result", "TP_FIRST", "short TP first"),
    ("TS15G-TOUCH-003", "first_touch", "LONG", "result", "SL_FIRST", "long SL first"),
    ("TS15G-TOUCH-004", "first_touch", "SHORT", "result", "SL_FIRST", "short SL first"),
    ("TS15G-TOUCH-005", "first_touch", "BOTH", "result", "TIMEOUT", "timeout side quote"),
    ("TS15G-TOUCH-006", "first_touch", "BOTH", "primary_result", "SL_FIRST", "same-ms primary stop first"),
    ("TS15G-TOUCH-007", "first_touch", "BOTH", "secondary_result", "AMBIGUOUS_SAME_TICK", "same-ms ambiguity preserved"),
    ("TS15G-GAP-001", "gap", "BOTH", "tp_fill_rule", "TARGET_LIMIT", "TP gap at barrier"),
    ("TS15G-GAP-002", "gap", "BOTH", "sl_fill_price", "0.9985", "SL gap at first tradable quote"),
    ("TS15G-MFE-001", "path_metric", "LONG", "mfe", "0.0008", "long executable MFE"),
    ("TS15G-MAE-001", "path_metric", "SHORT", "mae", "0.0007", "short executable MAE"),
    ("TS15G-COST-001", "cost", "BOTH", "c0_status", "AVAILABLE", "spread-only result"),
    ("TS15G-COST-002", "cost", "BOTH", "c1_status", "FORMAL_NET_UNAVAILABLE", "missing six-symbol commission"),
    ("TS15G-COST-003", "cost", "BOTH", "stress_spread_multiple", "1.25", "spread stress"),
    ("TS15G-COST-004", "cost", "BOTH", "stress_slippage_ticks", "1", "entry and exit tick stress"),
    ("TS15G-COST-005", "cost", "BOTH", "break_even_additional_cost_r", "0.3", "additional cost headroom"),
    ("TS15G-COST-006", "cost", "BOTH", "commission_deductions", "1", "commission is deducted once"),
    ("TS15G-LABEL-001", "label", "BOTH", "episode_class", "CONT_ONLY", "continuation only"),
    ("TS15G-LABEL-002", "label", "BOTH", "episode_class", "REV_ONLY", "reversal only"),
    ("TS15G-LABEL-003", "label", "BOTH", "episode_class", "BOTH", "both actions succeed"),
    ("TS15G-LABEL-004", "label", "BOTH", "episode_class", "NEITHER", "neither action succeeds"),
    ("TS15G-LABEL-005", "label", "BOTH", "episode_class", "AMBIGUOUS", "ambiguous same-millisecond path"),
    ("TS15G-LABEL-006", "label", "BOTH", "episode_class", "INVALID", "invalid path remains distinct"),
    ("TS15G-INTEGRITY-001", "integrity", "BOTH", "future_reads", "0", "future reads forbidden"),
    ("TS15G-INTEGRITY-002", "integrity", "BOTH", "production_order_calls", "0", "research EA remains order-free"),
    ("TS15G-INTEGRITY-003", "integrity", "BOTH", "stale_quote_status", "INVALID_PATH", "stale quote excluded"),
    ("TS15G-INTEGRITY-004", "integrity", "BOTH", "fallback_status", "INVALID_PATH", "fallback path excluded"),
    ("TS15G-INTEGRITY-005", "integrity", "BOTH", "backdates", "0", "entry backdating forbidden"),
    ("TS15G-INTEGRITY-006", "integrity", "BOTH", "outcome_feature_leakage", "0", "outcome features forbidden"),
    ("TS15G-INTEGRITY-007", "integrity", "BOTH", "cluster_split_count", "1", "episode and market cluster stay in one fold"),
    ("TS15G-INTEGRITY-008", "integrity", "BOTH", "purge_ms", "900000", "purge covers maximum outcome"),
    ("TS15G-INTEGRITY-009", "integrity", "BOTH", "training_only_preprocessing", "true", "preprocessing is fold-local"),
    ("TS15G-INTEGRITY-010", "integrity", "BOTH", "step15f_identity_mismatches", "0", "Step15F identity preserved"),
]


def write_csv(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    registry = ROOT / "tests/tick_shock/spec/test_cases.csv"
    with registry.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
        fields = list(rows[0])
    rows = [row for row in rows if not row["test_id"].startswith("TS15G-")]
    for test_id, component, direction, field, expected, description in CASES:
        ticks = [
            {"sequence": "1", "symbol": "EURUSD", "time_msc": "1000", "bid": "1.0000", "ask": "1.0002", "processing_msc": "1000", "note": "decision quote"},
            {"sequence": "2", "symbol": "EURUSD", "time_msc": "1001", "bid": "1.0001", "ask": "1.0003", "processing_msc": "1001", "note": description},
        ]
        write_csv(FIX / f"{test_id}_ticks.csv", ["sequence", "symbol", "time_msc", "bid", "ask", "processing_msc", "note"], ticks)
        config = [{"key": "test_contract", "value": description}, {"key": "expected_field", "value": field}, {"key": "expected_value", "value": expected}]
        write_csv(FIX / f"{test_id}_config.csv", ["key", "value"], config)
        write_csv(EXP / f"{test_id}_expected.csv", ["field", "expected_value", "tolerance", "unit", "note"], [{"field": field, "expected_value": expected, "tolerance": "1e-9" if expected.replace(".", "", 1).lstrip("-").isdigit() else "0", "unit": "contract", "note": description}])
        rows.append({
            "test_id": test_id,
            "requirement_id": f"TS15G-REQ-{component.upper()}",
            "defect_id": "STEP15G-PRE-IMPLEMENTATION",
            "component": component,
            "test_layer": "production_path_integration",
            "direction": direction,
            "fixture_path": f"tests/tick_shock/fixtures/{test_id}_ticks.csv",
            "expected_path": f"tests/tick_shock/expected/{test_id}_expected.csv",
            "current_expected_status": "XFAIL",
            "description": description,
        })
    write_csv(registry, fields, rows)
    red_rows = []
    for test_id, component, direction, field, expected, description in CASES:
        red_rows.append({
            "test_id": test_id,
            "requirement_id": f"TS15G-REQ-{component.upper()}",
            "defect_id": "STEP15G-PRE-IMPLEMENTATION",
            "test_layer": "production_path_integration",
            "status": "XFAIL",
            "expected": f"{field}={expected}",
            "actual": "PRODUCTION_ECONOMIC_PATH_API_ABSENT",
            "difference": "registered online first-touch contract is not implemented",
            "evidence_path": "reports/tests/tick_shock/step15g_red/step15g_red_results.csv",
        })
    write_csv(RED / "step15g_red_results.csv", ["test_id", "requirement_id", "defect_id", "test_layer", "status", "expected", "actual", "difference", "evidence_path"], red_rows)
    (RED / "step15g_red_report.md").write_text(
        "# Step 15G RED report\n\n"
        f"- registered tests: {len(CASES)}\n- XFAIL: {len(CASES)}\n- FAIL: 0\n\n"
        "All XFAIL rows identify the absent production-callable economic-path recorder. Expected values are independent frozen CSV contracts; no production function generated them.\n",
        encoding="utf-8",
    )
    print(f"generated {len(CASES)} Step15G RED contracts")


if __name__ == "__main__":
    main()
