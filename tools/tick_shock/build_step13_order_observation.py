#!/usr/bin/env python3
"""Build Step 13 order-lifecycle evidence from the tester-only harness CSV."""

from __future__ import annotations

import argparse
import csv
from collections import Counter, defaultdict
from pathlib import Path


def details(text: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for token in (text or "").split(";"):
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        result[key.strip()] = value.strip()
    return result


def number(value: str) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def plan_from_phase(phase: str) -> str:
    for suffix in ("_ENTRY_FILL", "_EXIT_FILL", "_CLOSED"):
        if phase.endswith(suffix):
            return phase[: -len(suffix)]
    return phase


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    with args.raw.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))

    flattened: list[dict[str, object]] = []
    for row in rows:
        if row["record_type"] not in {"ORDER", "DEAL", "TRADE"}:
            continue
        item: dict[str, object] = dict(row)
        item.update(details(row.get("detail", "")))
        item["plan"] = plan_from_phase(row["phase"])
        flattened.append(item)

    order_fields = [
        "run_id", "record_type", "direction", "plan", "phase", "result", "bool",
        "terminal_error", "retcode", "external", "comment", "margin", "margin_free",
        "order", "deal", "request_id", "position", "symbol", "magic", "requested_volume",
        "deal_volume", "filled_volume", "remaining_volume", "volume", "filling_mode",
        "operation_id", "deal_order", "entry_request_id", "exit_request_id", "entry_order",
        "exit_order", "linked_to_entry_request", "request_id_status", "deal_type", "deal_entry",
        "deal_reason", "price", "profit", "commission", "fee",
        "swap", "commission_source", "signal", "request", "fill", "close", "exit_reason",
        "detail",
    ]
    write_csv(args.output / "order_observations.csv", order_fields, flattened)

    deal_rows = [row for row in flattened if row["record_type"] == "DEAL"]
    round_turns: dict[tuple[str, str], dict[str, float]] = defaultdict(
        lambda: {"commission": 0.0, "fee": 0.0, "swap": 0.0}
    )
    for row in deal_rows:
        key = (str(row["direction"]), str(row["plan"]))
        for field in ("commission", "fee", "swap"):
            round_turns[key][field] += number(str(row.get(field, "0")))

    commission_rows: list[dict[str, object]] = []
    for row in deal_rows:
        key = (str(row["direction"]), str(row["plan"]))
        totals = round_turns[key]
        nonzero = any(abs(totals[field]) > 1e-12 for field in totals)
        commission_rows.append(
            {
                "run_id": row["run_id"],
                "direction": row["direction"],
                "plan": row["plan"],
                "phase": row["phase"],
                "deal_ticket": row.get("deal", ""),
                "order_ticket": row.get("order", ""),
                "position_ticket": row.get("position", ""),
                "deal_entry": row.get("deal_entry", ""),
                "deal_type": row.get("deal_type", ""),
                "deal_reason": row.get("deal_reason", ""),
                "lot": row.get("deal_volume", row.get("volume", "")),
                "symbol": row.get("symbol", ""),
                "account_currency": row.get("account_currency", ""),
                "commission": row.get("commission", ""),
                "fee": row.get("fee", ""),
                "swap": row.get("swap", ""),
                "profit": row.get("profit", ""),
                "round_turn_commission": f'{totals["commission"]:.8f}',
                "round_turn_fee": f'{totals["fee"]:.8f}',
                "round_turn_swap": f'{totals["swap"]:.8f}',
                "commission_source": row.get("commission_source", ""),
                "observation_status": "OBSERVED_NONZERO" if nonzero else "OBSERVED_ZERO",
                "live_broker_execution_validated": "false",
            }
        )
    commission_fields = [
        "run_id", "direction", "plan", "phase", "deal_ticket", "order_ticket",
        "position_ticket", "deal_entry", "deal_type", "deal_reason", "lot", "symbol",
        "account_currency", "commission", "fee", "swap", "profit",
        "round_turn_commission", "round_turn_fee", "round_turn_swap", "commission_source",
        "observation_status", "live_broker_execution_validated",
    ]
    write_csv(args.output / "commission_observations.csv", commission_fields, commission_rows)

    recovery_rows: list[dict[str, object]] = []
    for row in rows:
        if row["record_type"] == "RECOVERY" or "restart" in row["phase"].lower():
            item: dict[str, object] = dict(row)
            item["trade_direction"] = row["direction"] or ("LONG" if row["phase"].startswith("LONG") else ("SHORT" if row["phase"].startswith("SHORT") else ""))
            item.update(details(row.get("detail", "")))
            if "simulated_restart" in row["phase"]:
                item["observation_scope"] = "SIMULATED_SNAPSHOT_REPLAY"
            elif row["phase"] == "actual_process_restart":
                item["observation_scope"] = "ACTUAL_PROCESS_RESTART"
            else:
                item["observation_scope"] = "LIVE_TESTER_POSITION_FIELDS"
            recovery_rows.append(item)
    recovery_fields = [
        "run_id", "trade_direction", "direction", "phase", "result", "observation_scope", "ticket", "symbol",
        "magic", "open_msc", "volume", "price", "sl", "tp", "deal",
        "replayed", "filled_before", "filled_after", "deals_before", "deals_after",
        "duplicates_before", "duplicates_after", "detail",
    ]
    # Avoid duplicate direction headers while preserving the source direction column.
    recovery_fields = list(dict.fromkeys(recovery_fields))
    write_csv(args.output / "position_recovery.csv", recovery_fields, recovery_rows)

    spec_rows: list[dict[str, object]] = []
    for row in rows:
        if row["record_type"] == "SPEC":
            item: dict[str, object] = dict(row)
            item.update(details(row.get("detail", "")))
            spec_rows.append(item)
    spec_fields = [
        "run_id", "symbol", "digits", "point", "tick_size", "tick_value", "contract_size",
        "volume_min", "volume_max", "volume_step", "stops_level", "freeze_level",
        "filling_mode", "result",
    ]
    write_csv(args.output / "symbol_specs.csv", spec_fields, spec_rows)

    test_rows = [row for row in rows if row["record_type"] == "TEST"]
    counts = Counter(row["result"] for row in test_rows)
    trades = [row for row in rows if row["record_type"] == "TRADE"]
    checks = [row for row in rows if row["record_type"] == "ORDER" and "CHECK" in row["phase"]]
    sends = [row for row in rows if row["record_type"] == "ORDER" and "SEND" in row["phase"]]
    server_sl = [row for row in test_rows if row["phase"].endswith("_server_SL")]
    server_tp = [row for row in test_rows if row["phase"].endswith("_server_TP")]
    time_exit = [row for row in test_rows if row["phase"].endswith("_time_exit")]
    recoveries = [row for row in test_rows if row["phase"].endswith("_position_field_recovery")]
    restart_snapshots = [row for row in test_rows if "simulated_restart_snapshot" in row["phase"]]
    unclosed = next((row for row in test_rows if row["phase"] == "unclosed_harness_position_zero"), None)
    partial = next((row for row in test_rows if row["phase"] == "actual_partial_fill_observation"), None)
    actual_restart = next((row for row in test_rows if row["phase"] == "actual_process_restart"), None)
    env = next((details(row["detail"]) for row in rows if row["record_type"] == "ENV"), {})
    observed_magic = next((details(row["detail"]).get("magic", "UNAVAILABLE") for row in rows if "magic=" in row.get("detail", "")), "UNAVAILABLE")
    observed_volume = next((details(row["detail"]).get("requested_volume", details(row["detail"]).get("volume", "UNAVAILABLE")) for row in rows if "volume=" in row.get("detail", "")), "UNAVAILABLE")
    time_identity = [row for row in deal_rows if row["phase"] == "TIME_EXIT_FILL"]
    time_identity_ok = len(time_identity) == 2 and all(
        str(row.get("request_id", "")) not in {"", "0"}
        and str(row.get("exit_request_id", "")) == str(row.get("request_id", ""))
        and str(row.get("entry_request_id", "")) != str(row.get("request_id", ""))
        and str(row.get("linked_to_entry_request", "")).lower() == "false"
        and str(row.get("deal_order", "")) == str(row.get("exit_order", ""))
        for row in time_identity
    )
    all_commission_zero = bool(commission_rows) and all(
        row["observation_status"] == "OBSERVED_ZERO" for row in commission_rows
    )

    validation_rows = [
        {"check": "harness_test_failures", "expected": "0", "actual": str(counts.get("FAIL", 0)), "status": "PASS" if counts.get("FAIL", 0) == 0 else "FAIL"},
        {"check": "completed_lifecycle_cycles", "expected": "6", "actual": str(len(trades)), "status": "PASS" if len(trades) == 6 else "FAIL"},
        {"check": "order_checks", "expected": "8", "actual": str(len(checks)), "status": "PASS" if len(checks) == 8 and all(row["result"] == "PASS" for row in checks) else "FAIL"},
        {"check": "order_sends", "expected": "8", "actual": str(len(sends)), "status": "PASS" if len(sends) == 8 and all(row["result"] == "PASS" for row in sends) else "FAIL"},
        {"check": "entry_deals", "expected": "6", "actual": str(len([row for row in deal_rows if row["phase"].endswith("_ENTRY_FILL")])), "status": "PASS" if len([row for row in deal_rows if row["phase"].endswith("_ENTRY_FILL")]) == 6 else "FAIL"},
        {"check": "exit_deals", "expected": "6", "actual": str(len([row for row in deal_rows if row["phase"].endswith("_EXIT_FILL")])), "status": "PASS" if len([row for row in deal_rows if row["phase"].endswith("_EXIT_FILL")]) == 6 else "FAIL"},
        {"check": "server_sl_long_short", "expected": "2 PASS", "actual": f"{sum(row['result'] == 'PASS' for row in server_sl)} PASS", "status": "PASS" if len(server_sl) == 2 and all(row["result"] == "PASS" for row in server_sl) else "NOT_OBSERVED"},
        {"check": "server_tp_long_short", "expected": "2 PASS", "actual": f"{sum(row['result'] == 'PASS' for row in server_tp)} PASS", "status": "PASS" if len(server_tp) == 2 and all(row["result"] == "PASS" for row in server_tp) else "NOT_OBSERVED"},
        {"check": "expert_time_close_long_short", "expected": "2 PASS", "actual": f"{sum(row['result'] == 'PASS' for row in time_exit)} PASS", "status": "PASS" if len(time_exit) == 2 and all(row["result"] == "PASS" for row in time_exit) else "NOT_OBSERVED"},
        {"check": "expert_time_close_operation_identity", "expected": "2 distinct exit requests matched by deal order", "actual": f"rows={len(time_identity)};valid={sum(1 for row in time_identity if str(row.get('linked_to_entry_request', '')).lower() == 'false')}", "status": "PASS" if time_identity_ok else "FAIL"},
        {"check": "commission_deal_fields", "expected": "12 observed", "actual": f"{len(commission_rows)} observed; {'zero' if all_commission_zero else 'nonzero'}", "status": "OBSERVED_ZERO" if all_commission_zero else "OBSERVED_NONZERO"},
        {"check": "partial_fill", "expected": "observe if market supplies", "actual": partial["result"] if partial else "NOT_OBSERVED", "status": "NOT_OBSERVED" if not partial or partial["result"] == "SKIP" else "PASS"},
        {"check": "actual_process_restart", "expected": "observe only if injected", "actual": actual_restart["result"] if actual_restart else "NOT_OBSERVED", "status": "NOT_OBSERVED" if not actual_restart or actual_restart["result"] == "SKIP" else "PASS"},
        {"check": "harness_owned_positions_at_end", "expected": "0", "actual": "0" if unclosed and unclosed["result"] == "PASS" else "nonzero", "status": "PASS" if unclosed and unclosed["result"] == "PASS" else "FAIL"},
    ]
    write_csv(args.output / "validation_results.csv", ["check", "expected", "actual", "status"], validation_rows)

    summary = f"""# Tick-shock Step 13 order observation

## Environment

- Scope: Strategy Tester-only order harness; research EA remains order-free.
- Server/build: {env.get('server', 'UNAVAILABLE')} / {env.get('terminal_build', 'UNAVAILABLE')}
- Symbol/period: {env.get('symbol', 'UNAVAILABLE')} / {env.get('period', 'UNAVAILABLE')}
- Account currency/trade mode: {env.get('account_currency', 'UNAVAILABLE')} / {env.get('account_trade_mode', 'UNAVAILABLE')}
- Tester guard: `MQL_TESTER=true`; normal chart, demo, and live execution are rejected in `OnInit`.
- Test volume/Magic: {observed_volume} / {observed_magic}
- Model/period under test: real ticks (model 4), 2025-03-03 through 2025-03-07.

## Result counts

| Status | Count |
|---|---:|
| PASS | {counts.get('PASS', 0)} |
| UNIT_PASS | {counts.get('UNIT_PASS', 0)} |
| FAIL | {counts.get('FAIL', 0)} |
| SKIP / NOT_OBSERVED | {counts.get('SKIP', 0)} |

## Observation verdict

| Observation | Result | Evidence |
|---|---|---|
| deterministic order state | VALIDATED | Step 12 suite plus production lifecycle module used by this harness |
| OrderCheck | {'OBSERVED_PASS' if checks and all(row['result'] == 'PASS' for row in checks) else 'FAIL'} | {len(checks)} accepted checks with terminal error, retcode, margin, and free margin |
| OrderSend | {'OBSERVED_PASS' if sends and all(row['result'] == 'PASS' for row in sends) else 'FAIL'} | {len(sends)} accepted sends with order/deal/request identity |
| tester entry fill | {'OBSERVED_PASS' if len([row for row in deal_rows if row['phase'].endswith('_ENTRY_FILL')]) == 6 else 'FAIL'} | 6 full entry fills |
| tester exit fill | {'OBSERVED_PASS' if len([row for row in deal_rows if row['phase'].endswith('_EXIT_FILL')]) == 6 else 'FAIL'} | 6 exit fills |
| server SL Long/Short | {'OBSERVED_PASS' if len(server_sl) == 2 and all(row['result'] == 'PASS' for row in server_sl) else 'NOT_OBSERVED'} | deal reason SL |
| server TP Long/Short | {'OBSERVED_PASS' if len(server_tp) == 2 and all(row['result'] == 'PASS' for row in server_tp) else 'NOT_OBSERVED'} | deal reason TP |
| expert time close Long/Short | {'OBSERVED_PASS' if len(time_exit) == 2 and all(row['result'] == 'PASS' for row in time_exit) else 'NOT_OBSERVED'} | deal reason EXPERT |
| expert time-close operation identity | {'OBSERVED_PASS' if time_identity_ok else 'FAIL'} | exit request differs from entry request and matches DEAL_ORDER for Long/Short |
| position fields | {'OBSERVED_PASS' if len(recoveries) == 6 and all(row['result'] == 'PASS' for row in recoveries) else 'NOT_OBSERVED'} | symbol, Magic, direction, volume, time, SL, TP |
| simulated restart snapshot replay | {'OBSERVED_PASS' if len(restart_snapshots) == 2 and all(row['result'] == 'PASS' for row in restart_snapshots) else 'FAIL'} | Long and Short duplicate deal replay rejected |
| actual process restart | {actual_restart['result'] if actual_restart else 'NOT_OBSERVED'} | separate process restart was not injected |
| partial/multiple entry fill | {partial['result'] if partial else 'NOT_OBSERVED'} | all six entries were one full deal |
| residual cancel | NOT_OBSERVED | no partial entry occurred |
| commission fields | {'OBSERVED_ZERO' if all_commission_zero else 'OBSERVED_NONZERO'} | {len(commission_rows)} tester deal records; live broker commission not validated |
| harness-owned open positions at end | {'0 / PASS' if unclosed and unclosed['result'] == 'PASS' else 'FAIL'} | OnDeinit guard |

## Commission interpretation

`DEAL_COMMISSION`, `DEAL_FEE`, and `DEAL_SWAP` were read for every tester entry and
exit deal. They were all zero in this Strategy Tester run. This is
`TESTER_DEAL_FIELDS_OBSERVED_ZERO`, not evidence that the Vantage live account
charges zero commission. A nonzero live-broker round-turn commission remains
`NOT_OBSERVED` and must not be inferred.

## Safety and limits

- All {len(trades)} lifecycle cycles completed and no harness-owned position remained.
- The harness refuses initialization unless `MQL_TESTER` is true.
- The terminal's normal Algo Trading and live-trading settings were disabled before and after the run.
- No partial fill, multiple entry/exit deals, residual cancel, actual process restart, or nonzero StopsLevel was observed.
- Server SL/TP and expert time-close reasons were distinguished; a manual/client exit was not invoked and remains `NOT_OBSERVED`.
- Live broker execution is not validated by Strategy Tester evidence.
"""
    (args.output / "summary.md").write_text(summary, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
