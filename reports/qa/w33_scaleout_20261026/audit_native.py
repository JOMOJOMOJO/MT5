"""Independent CSV accounting/event-order audit of the bounded native QA run."""
from __future__ import annotations
import csv
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle, delimiter=";"))


def near(a: str | float, b: str | float, tolerance: float = 1e-7) -> bool:
    return math.isclose(float(a), float(b), rel_tol=1e-9, abs_tol=tolerance)


def main() -> None:
    latest = json.loads((ROOT / "native_latest.json").read_text(encoding="utf-8-sig"))
    checks: list[dict] = []

    def check(case: str, name: str, result: bool, **detail) -> None:
        checks.append(dict(case=case, test=name, result="PASS" if result else "FAIL", **detail))

    for case in latest["cases"]:
        tag = case["tag"]
        folder = Path(case["output"])
        events = rows(folder / f"{tag}_events.csv")
        deals = rows(folder / f"{tag}_raw_deals.csv")
        assertions = rows(folder / f"{tag}_assertions.csv")
        exit_events = [row for row in events if row["event_type"] == "EXIT"]
        partial_events = [row for row in events if row["event_type"] == "PARTIAL_EXIT"]
        entry = [row for row in deals if row["entry"] == "DEAL_ENTRY_IN"]
        outgoing = [row for row in deals if row["entry"] in ("DEAL_ENTRY_OUT", "DEAL_ENTRY_OUT_BY")]
        check(case["case"], "event_and_deal_CSV_width_stable", all(None not in row and None not in row.values() for row in events + deals))
        check(case["case"], "one_final_setup_exit", len(exit_events) == 1)
        check(case["case"], "native_deals_unique", len(deals) == len({row["deal_ticket"] for row in deals}))
        check(case["case"], "one_position_identity", len({row["position_id"] for row in deals}) == 1)
        check(case["case"], "entry_and_exit_volume_conserve", near(sum(float(row["volume"]) for row in entry), sum(float(row["volume"]) for row in outgoing)))
        check(case["case"], "history_time_monotone", all(int(b["time_msc"]) >= int(a["time_msc"]) for a, b in zip(deals, deals[1:])))
        cash = sum(sum(float(row[column]) for column in ("profit", "commission", "fee", "swap")) for row in deals)
        if exit_events:
            final = exit_events[0]
            check(case["case"], "all_deal_costs_in_final_setup_net", near(cash, final["execution_net_cash"]), cash=cash)
            risk = float(final["execution_initial_risk_money"])
            check(case["case"], "setup_R_aggregates_partial_cash", risk > 0 and near(cash / risk, final["realized_r"]))
        check(case["case"], "native_duplicate_replay_asserted", len([row for row in assertions if row["test"].startswith("duplicate_native_deal_ignored_") and row["result"] == "PASS"]) == len(deals))
        check(case["case"], "account_mode_explicit", any(row["test"] == "account_margin_mode_reported" and row["detail"].startswith("ACCOUNT_MARGIN_MODE_") for row in assertions))
        if case["scaleout"] and not case.get("single_fallback"):
            scale = rows(folder / f"{tag}_scaleout.csv")
            check(case["case"], "scaleout_CSV_width_stable", all(None not in row and None not in row.values() for row in scale))
            half = [row for row in scale if row["event"] == "SCALEOUT_TP1_FILLED"]
            be = [row for row in scale if row["event"] == "SCALEOUT_BE_CONFIRMED"]
            check(case["case"], "actual_plan_first_kind_matches_case", bool(scale) and scale[0]["first_kind"] == ("WAVE1_INSIDE" if case.get("w1_first") else "BASE_RR"))
            check(case["case"], "one_half_and_one_residual", len(outgoing) == 2 and len(half) == 1 and len(partial_events) == 1)
            check(case["case"], "BE_after_confirmed_half", bool(half) and bool(be) and be[0]["at"] >= half[0]["at"] and float(be[0]["confirmed_close_volume"]) >= float(be[0]["target_close_volume"]) - 1e-8)
            for row in scale:
                if row["event"] == "SCALEOUT_BE_REQUEST":
                    check(case["case"], "BE_request_no_unconfirmed_volume", float(row["confirmed_close_volume"]) >= float(row["target_close_volume"]) > 0)
            check(case["case"], "initial_risk_stays_after_BE", len({row["initial_risk_money"] for row in scale if float(row["filled_volume"]) > 0}) == 1)
            check(case["case"], "last_close_opposite_rule_retained", bool(exit_events) and exit_events[0]["exit_reason"] == "OPPOSITE_WAVE1_PROFIT")
            settled = [row for row in events if row["event_type"] == "SCALEOUT_REQUEST_SETTLED"]
            opposite_requests = [row for row in events if row["event_type"] == "OPPOSITE_CLOSE_REQUEST"]
            check(case["case"], "opposite_request_after_scale_request_settled", bool(settled) and len(opposite_requests) == 1 and opposite_requests[0]["event_at"] >= settled[-1]["event_at"])
            if case["case"] == "long":
                check(case["case"], "injected_requote_logged", any(row["event"] == "SCALEOUT_CLOSE_REJECTED" and "QA_INJECTED_REQUOTE" in row["reason"] for row in scale))
                check(case["case"], "injected_BE_rejection_logged", any(row["event"] == "SCALEOUT_BE_REJECTED" and "QA_INJECTED_BE_STOPS" in row["reason"] for row in scale))
                check(case["case"], "accepted_unobserved_BE_recheck_logged", any(row["event"] == "SCALEOUT_BE_RECHECK" for row in scale))
        elif case.get("single_fallback"):
            scale = rows(folder / f"{tag}_scaleout.csv")
            check(case["case"], "scaleout_CSV_width_stable", all(None not in row and None not in row.values() for row in scale))
            check(case["case"], "minimum_lot_one_full_close", len(outgoing) == 1 and not partial_events)
            check(case["case"], "minimum_lot_no_BE_request", not any(row["event"] == "SCALEOUT_BE_REQUEST" for row in scale))
            check(case["case"], "minimum_lot_explicit_fallback", any(row["event"] == "SCALEOUT_FALLBACK_SINGLE" and "MIN_VOLUME" in row["reason"] for row in scale))
        else:
            check(case["case"], "OFF_one_full_close", len(outgoing) == 1 and not partial_events and not (folder / f"{tag}_scaleout.csv").exists())
    failed = [row for row in checks if row["result"] == "FAIL"]
    output = dict(status="FAIL" if failed else "PASS", checks=len(checks), failures=len(failed), batch=latest["batch"], evidence="Bounded synthetic signal + native MT5 generated ticks, including two injected request failures and delayed BE acceptance. Not a performance/OOS result.", results=checks)
    (ROOT / "native_event_audit.json").write_text(json.dumps(output, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{output['status']} independent checks={len(checks)} failures={len(failed)}")
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
