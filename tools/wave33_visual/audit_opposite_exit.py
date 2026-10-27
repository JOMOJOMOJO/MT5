"""Audit one fixed OFF/ON comparison of Wave33 opposite-W1 profit exits.

Inputs are native run directories containing events.csv, config.csv,
opposite_ticks.csv (ON), upper_bars.csv and report.htm. No optimization or
profit-based case selection is performed. Decimal arithmetic independently
checks the cost gate; XAUUSD / USD-account quote profit and native deal tables
provide an additional independent money/R check.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
from datetime import datetime
from decimal import Decimal, InvalidOperation
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re


TARGET = "exit_on_opposite_wave1"
META = {"resolved_run_tag", "run_tag", "version", "ea_version", "draw", "visual",
        "screenshots", "screenshot_limit", "show_info_panel", "diagnostic_labels",
        "show_swing_paths", "keep_objects", "terminal_build", "audit_opposite_exit_ticks"}
IDENTITY = ("symbol", "upper_tf", "lower_tf", "direction", "upper_break_bar_time",
            "upper_break_level_time", "upper_break_level", "wave1_start_time", "wave1_start_price")
MONEY_EPS = Decimal("0.00001")
R_EPS = Decimal("0.000001")
ARM = "OPPOSITE_WAVE1_ARMED"
REQUEST = "OPPOSITE_CLOSE_REQUEST"
REJECT = "OPPOSITE_CLOSE_REJECTED"
ACCEPT = "OPPOSITE_CLOSE_ACCEPTED"
SPECIAL = "OPPOSITE_WAVE1_PROFIT"


def dec(value, default=None):
    try:
        result = Decimal(str(value).replace(" ", "").replace("\xa0", "").replace(",", ""))
        return result if result.is_finite() else default
    except (InvalidOperation, ValueError, TypeError):
        return default


def flag(value):
    return str(value).lower() in {"1", "true"}


def stamp(value):
    try:
        return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")
    except (ValueError, TypeError):
        return None


def read_rows(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        first = stream.readline()
        stream.seek(0)
        return [dict(row, _row=i + 2) for i, row in enumerate(
            csv.DictReader(stream, delimiter=";" if ";" in first else ","))]


def canonical(value):
    number = dec(value)
    return str(number.normalize()) if number is not None else str(value).lower()


def identity(row):
    return tuple(canonical(row.get(key, "")) for key in IDENTITY)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None


class Checks:
    def __init__(self):
        self.count = 0
        self.failures = []
        self.incomplete = []

    def check(self, condition, code, **context):
        self.count += 1
        if not condition:
            self.failures.append(dict(code=code, **context))

    def missing(self, code, **context):
        self.incomplete.append(dict(code=code, **context))


class Cells(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows = []
        self.row = []
        self.cell = None

    def handle_starttag(self, tag, attrs):
        if tag == "tr":
            self.row = []
        elif tag in {"td", "th"}:
            self.cell = []

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if tag in {"td", "th"} and self.cell is not None:
            self.row.append("".join(self.cell).strip())
            self.cell = None
        elif tag == "tr":
            self.rows.append(self.row)
            self.row = []


def report_deals(path):
    if not path.exists():
        return []
    raw = path.read_bytes()
    encoding = "utf-16" if raw[:2] in {b"\xff\xfe", b"\xfe\xff"} else "utf-8-sig"
    parser = Cells()
    parser.feed(raw.decode(encoding, errors="replace"))
    deals = []
    for row in parser.rows:
        if len(row) < 12 or stamp(row[0]) is None or row[3].lower() not in {"buy", "sell"}:
            continue
        if row[4].lower() not in {"in", "out", "in/out", "out by"}:
            continue
        deals.append(dict(time=row[0], deal=row[1], symbol=row[2], type=row[3].lower(),
                          entry=row[4].lower(), volume=dec(row[5]), price=dec(row[6]),
                          order=row[7], commission=dec(row[8]), swap=dec(row[9]),
                          profit=dec(row[10]), comment=row[12] if len(row) > 12 else ""))
    return deals


def load_run(path, checks, label):
    events = read_rows(path / "events.csv")
    config = {row.get("parameter", ""): row.get("value", "") for row in read_rows(path / "config.csv")}
    groups = defaultdict(list)
    for row in events:
        if row.get("setup_id"):
            groups[row["setup_id"]].append(row)
    ticks = read_rows(path / "opposite_ticks.csv") if (path / "opposite_ticks.csv").exists() else []
    ini = (path / "tester_public.ini").read_text(encoding="utf-8-sig", errors="replace") if (path / "tester_public.ini").exists() else ""
    currency = re.search(r"(?im)^Currency\s*=\s*(\w+)\s*$", ini)
    currency = currency.group(1).upper() if currency else config.get("account_currency", "")
    run = dict(path=str(path), events=events, config=config, groups=groups, ticks=ticks,
               deals=report_deals(path / "report.htm"), currency=currency)
    checks.check(bool(events), "events_present", run=label)
    checks.check(bool(config), "config_present", run=label)
    for name in ("events.csv", "config.csv", "opposite_ticks.csv", "upper_bars.csv", "report.htm"):
        run.setdefault("hashes", {})[name] = sha(path / name)
    return run


def configurations(off, on, checks):
    a, b = off["config"], on["config"]
    checks.check(not flag(a.get(TARGET)) and flag(b.get(TARGET)), "off_on_target_flag")
    differences = {}
    for key in sorted(a.keys() | b.keys()):
        if canonical(a.get(key, "")) != canonical(b.get(key, "")):
            differences[key] = [a.get(key), b.get(key)]
            if key not in META and key != TARGET:
                checks.check(False, "unexpected_config_difference", parameter=key, values=differences[key])
    checks.check(a.get("symbol") == b.get("symbol"), "same_symbol")
    checks.check(a.get("upper_tf") == b.get("upper_tf") and a.get("lower_tf") == b.get("lower_tf"), "same_timeframes")
    for label, run in (("off", off), ("on", on)):
        checks.check(flag(run["config"].get("tester_orders")), "tester_orders_enabled", run=label)
        checks.check(flag(run["config"].get("tester")), "tester_guard", run=label)
    checks.check(flag(b.get("audit_opposite_exit_ticks")), "on_tick_audit_enabled")
    return differences


def source_and_latch(on, checks):
    armed = {}
    for row in on["events"]:
        setup = row.get("setup_id", "")
        if row.get("event_type") == ARM:
            history = on["groups"][setup]
            fills = [r for r in history if r.get("event_type") == "FILL" and r["_row"] < row["_row"]]
            previous_exit = [r for r in history if r.get("event_type") == "EXIT" and r["_row"] < row["_row"]]
            source = row.get("opposite_setup_id", "")
            peaks = [r for r in on["groups"].get(source, []) if r.get("event_type") == "WAVE1_PEAK_CONFIRMED" and r["_row"] < row["_row"]]
            checks.check(bool(fills) and not previous_exit, "arm_only_after_actual_fill", setup_id=setup, row=row["_row"])
            checks.check(len(peaks) == 1, "arm_has_unique_prior_peak", setup_id=setup, source=source)
            checks.check(setup not in armed, "one_sticky_arm_per_position", setup_id=setup)
            if peaks and fills:
                peak = peaks[0]
                checks.check(peak["direction"] != row["direction"], "opposite_direction", setup_id=setup)
                checks.check(peak["symbol"] == row["symbol"] and peak["upper_tf"] == row["upper_tf"] and peak["lower_tf"] == row["lower_tf"], "same_source_pair", setup_id=setup)
                checks.check(peak["_row"] > fills[0]["_row"] and peak["event_at"] >= fills[0]["event_at"], "source_known_after_fill_including_same_second", setup_id=setup)
                checks.check(peak["event_at"] == row.get("opposite_wave_known_at") == row["event_at"], "arm_uses_known_time", setup_id=setup)
                checks.check(peak["wave1_peak_time"] == row.get("opposite_wave_peak_time"), "arm_preserves_peak_location", setup_id=setup)
                checks.check(dec(peak["wave1_peak_price"]) == dec(row.get("opposite_wave_price")), "arm_preserves_peak_price", setup_id=setup)
            armed[setup] = row
        if setup in armed:
            origin = armed[setup]
            checks.check(flag(row.get("opposite_exit_armed")), "latch_remains_armed", setup_id=setup, row=row["_row"])
            checks.check(row.get("opposite_setup_id") == origin.get("opposite_setup_id") and row.get("opposite_wave_known_at") == origin.get("opposite_wave_known_at"), "latch_source_unchanged", setup_id=setup, row=row["_row"])
    return armed


def check_ticks(on, armed, checks):
    by_setup = defaultdict(list)
    for row in on["ticks"]:
        by_setup[row.get("setup_id", "")].append(row)
    checks.check(bool(on["ticks"]) or not armed, "tick_audit_available")
    summaries = []
    for setup, arm in armed.items():
        ticks = by_setup.get(setup, [])
        checks.check(bool(ticks), "armed_has_tick_rows", setup_id=setup)
        history = on["groups"][setup]
        actions = [row for row in history if row["event_type"] == REQUEST or row["event_type"] == REJECT and row.get("reason", "").startswith("ORDER_CHECK ")]
        checks.check(len(actions) == sum(row.get("status") == "READY" for row in ticks), "every_ready_has_request_or_check_rejection", setup_id=setup)
        checks.check([row["event_at"] for row in actions] == [row["known_at"] for row in ticks if row.get("status") == "READY"], "ready_action_time_sequence", setup_id=setup)
        fills = [row for row in history if row["event_type"] == "FILL"]
        first_request = next((row for row in history if row["event_type"] == REQUEST), None)
        previous_key = None
        previous_attempts = 0
        ticket_identity = None
        first_ready = None
        for row in ticks:
            location = dict(setup_id=setup, tick_row=row["_row"])
            key = (int(row["tick_order"]), int(row["tick_time_msc"]))
            checks.check(previous_key is None or key > previous_key, "tick_order_monotone_no_duplicate", **location)
            previous_key = key
            checks.check(row.get("opposite_setup_id") == arm.get("opposite_setup_id"), "tick_sticky_source", **location)
            checks.check(row["known_at"] >= arm["event_at"], "tick_not_before_arm", **location)
            checks.check(int(row["position_id"]) > 0 and int(row["position_ticket"]) > 0, "positive_native_position_identity", **location)
            if ticket_identity is None:
                ticket_identity = row["position_id"]
            checks.check(row["position_id"] == ticket_identity, "stable_position_identifier", **location)
            status = row.get("status")
            attempts = int(row["attempts"])
            checks.check(attempts >= previous_attempts and attempts <= previous_attempts + 1, "attempt_counter_monotone", **location)
            previous_attempts = attempts
            if status == "PROFIT_CALC_FAILED":
                continue
            values = [dec(row.get(name)) for name in ("quote_profit", "booked_cash", "remaining_swap", "entry_cost_rate", "volume", "estimated_exit_cost", "net_estimate", "bid", "ask")]
            checks.check(all(value is not None for value in values), "finite_tick_values", **location)
            if any(value is None for value in values):
                continue
            profit, booked, swap, rate, volume, cost, net, bid, ask = values
            expected_cost = max(Decimal(0), rate) * volume
            checks.check(abs(cost - expected_cost) <= MONEY_EPS, "closing_cost_independent_arithmetic", **location)
            checks.check(abs(net - (profit + booked + swap - expected_cost)) <= MONEY_EPS, "net_independent_arithmetic", **location)
            checks.check(ask >= bid > 0 and volume > 0 and rate >= 0, "valid_executable_quote_and_volume", **location)
            pending = flag(row.get("request_pending"))
            ready = net > 0 and not pending
            checks.check((status == "READY") == ready, "strict_profit_gate_and_pending_guard", **location)
            checks.check((status == "REQUEST_PENDING") == pending, "pending_status_consistency", **location)
            if status == "READY" and first_ready is None:
                first_ready = row
            if ready and first_request is not None and row["known_at"] < first_request["event_at"]:
                checks.check(any(action["event_type"] == REJECT and action["event_at"] == row["known_at"] for action in actions), "earlier_positive_only_allowed_after_check_rejection", **location)
            if on["config"].get("symbol", "").startswith("XAUUSD") and on["currency"] == "USD":
                known_fills = [fill for fill in fills if fill["event_at"] <= row["known_at"]]
                if known_fills:
                    direction = Decimal(1 if arm["direction"] == "LONG" else -1)
                    entry = dec(known_fills[-1]["entry_price"])
                    contract = dec(on["config"].get("contract_size"))
                    if entry is not None and contract is not None:
                        expected_profit = direction * ((bid if direction > 0 else ask) - entry) * volume * contract
                        checks.check(abs(expected_profit - profit) <= MONEY_EPS, "xau_usd_quote_profit_from_bid_ask", **location)
        summaries.append(dict(setup_id=setup, opposite_setup_id=arm.get("opposite_setup_id"),
                              armed_at=arm["event_at"], ticks=len(ticks), ready_ticks=sum(row.get("status") == "READY" for row in ticks),
                              first_ready_at=first_ready.get("known_at") if first_ready else None,
                              requests=sum(row["event_type"] == REQUEST for row in history),
                              rejections=sum(row["event_type"] == REJECT for row in history)))
    if not (on["config"].get("symbol", "").startswith("XAUUSD") and on["currency"] == "USD"):
        checks.missing("independent_quote_profit_requires_xauusd_usd_account", symbol=on["config"].get("symbol"), currency=on["currency"])
    for setup in by_setup:
        checks.check(setup in armed, "tick_only_for_armed_record", setup_id=setup)
    return summaries


def check_orders(on, checks):
    for setup, history in on["groups"].items():
        pending = False
        request_count = 0
        for row in history:
            name = row["event_type"]
            context = dict(setup_id=setup, row=row["_row"])
            if name == REQUEST:
                checks.check(not pending, "no_duplicate_close_while_pending", **context)
                checks.check(flag(row.get("opposite_exit_armed")) and dec(row.get("opposite_exit_net_estimate"), Decimal(0)) > 0, "request_armed_and_positive", **context)
                checks.check(row.get("opposite_exit_requested_at") == row["event_at"], "request_actual_known_time", **context)
                pending = True
                request_count += 1
            elif name == REJECT:
                checks.check(pending or row.get("reason", "").startswith("ORDER_CHECK "), "rejection_has_attempt", **context)
                pending = False
            elif name == ACCEPT:
                checks.check(pending, "acceptance_has_pending_request", **context)
            elif name in {"PARTIAL_EXIT", "EXIT"}:
                if row.get("exit_reason") == SPECIAL:
                    checks.check(request_count > 0 and flag(row.get("opposite_exit_armed")), "custom_exit_has_request_and_latch", **context)
                    checks.check(row.get("exit_deal_reason") == "DEAL_REASON_EXPERT", "custom_exit_preserves_broker_expert_reason", **context)
                    checks.check(int(row.get("opposite_close_order_ticket", "0")) > 0, "custom_exit_has_native_close_order", **context)
                else:
                    checks.check(row.get("exit_reason") == row.get("exit_deal_reason"), "ordinary_exit_keeps_actual_broker_reason", **context)
                pending = False
                checks.check(dec(row.get("exit_price"), Decimal(0)) > 0, "exit_actual_price_present", **context)
                cash, risk = dec(row.get("execution_net_cash")), dec(row.get("execution_initial_risk_money"))
                checks.check(cash is not None and risk is not None and risk > 0, "exit_cash_and_original_money_risk_present", **context)
                if cash is not None and risk is not None and risk > 0:
                    checks.check(abs(dec(row.get("realized_r"), Decimal(0)) - cash / risk) <= R_EPS, "recorded_net_cash_over_money_risk", **context)
                fills = [prior for prior in history if prior["event_type"] == "FILL" and prior["_row"] < row["_row"]]
                if fills:
                    checks.check(row.get("execution_position_id") == fills[0].get("execution_position_id") and int(row.get("execution_position_id", "0")) > 0, "exit_same_native_position_as_fill", **context)


def check_report(run, checks, label):
    if not run["deals"]:
        checks.missing("native_report_deals_unavailable", run=label)
        return []
    positions = []
    current = None
    for deal in run["deals"]:
        checks.check(all(deal.get(name) is not None for name in ("volume", "price", "commission", "swap", "profit")), "report_deal_numeric", run=label, deal=deal["deal"])
        if any(deal.get(name) is None for name in ("volume", "price", "commission", "swap", "profit")):
            continue
        if deal["entry"] == "in":
            if current is None:
                current = dict(in_deals=[], out_deals=[], volume=Decimal(0), net=Decimal(0))
            current["in_deals"].append(deal)
            current["volume"] += deal["volume"]
        elif deal["entry"] in {"out", "out by"} and current is not None:
            current["out_deals"].append(deal)
            current["volume"] -= deal["volume"]
        else:
            checks.check(False, "unsupported_or_unmatched_report_deal", run=label, deal=deal["deal"])
            continue
        current["net"] += deal["commission"] + deal["swap"] + deal["profit"]
        checks.check(current["volume"] >= 0, "native_exit_volume_not_excessive", run=label, deal=deal["deal"])
        if current["volume"] == 0:
            positions.append(current)
            current = None
    if current:
        checks.missing("open_report_position_at_stop", run=label)
    fill_groups = [(setup, history) for setup, history in run["groups"].items() if any(row["event_type"] == "FILL" for row in history)]
    matched = set()
    result = []
    contract = dec(run["config"].get("contract_size"))
    for position in positions:
        first, last = position["in_deals"][0], position["out_deals"][-1]
        matches = [(setup, history) for setup, history in fill_groups if setup not in matched and any(row["event_type"] == "FILL" and row.get("fill_at") == first["time"] and row["direction"] == ("LONG" if first["type"] == "buy" else "SHORT") for row in history)]
        checks.check(len(matches) == 1, "report_position_has_unique_event_fill", run=label, first_deal=first["deal"])
        if len(matches) != 1:
            continue
        setup, history = matches[0]
        matched.add(setup)
        fills = [row for row in history if row["event_type"] == "FILL"]
        exits = [row for row in history if row["event_type"] == "EXIT"]
        checks.check(len(exits) == 1, "one_final_exit_per_native_position", run=label, setup_id=setup)
        if not exits:
            continue
        exit_row = exits[0]
        total_volume = sum(deal["volume"] for deal in position["in_deals"])
        entry = sum(deal["price"] * deal["volume"] for deal in position["in_deals"]) / total_volume
        checks.check(abs(entry - dec(fills[-1]["entry_price"], Decimal(0))) <= MONEY_EPS, "report_matches_average_fill", run=label, setup_id=setup)
        checks.check(exit_row.get("exit_at") == last["time"] and abs(dec(exit_row.get("exit_price"), Decimal(0)) - last["price"]) <= MONEY_EPS, "report_matches_actual_exit", run=label, setup_id=setup)
        actual_cash = dec(exit_row.get("execution_net_cash"))
        actual_risk = dec(exit_row.get("execution_initial_risk_money"))
        checks.check(actual_cash is not None and abs(actual_cash - position["net"]) <= MONEY_EPS, "native_report_matches_booked_event_cash", run=label, setup_id=setup)
        checks.check(actual_risk is not None and actual_risk > 0, "native_event_original_risk_available", run=label, setup_id=setup)
        if actual_cash is not None and actual_risk is not None and actual_risk > 0:
            checks.check(abs(dec(exit_row.get("realized_r"), Decimal(0)) - position["net"] / actual_risk) <= R_EPS, "native_report_cash_over_recorded_risk", run=label, setup_id=setup)
        if exit_row.get("exit_reason") == SPECIAL:
            checks.check(str(exit_row.get("opposite_close_order_ticket", "")) == last["order"], "custom_exit_order_matches_native_report", run=label, setup_id=setup)
        risk = None
        if contract is not None and run["currency"] == "USD" and first["symbol"].startswith("XAUUSD"):
            risk = abs(entry - dec(fills[-1]["sl_price"])) * total_volume * contract
            checks.check(risk > 0, "independent_initial_risk_positive", run=label, setup_id=setup)
            checks.check(actual_risk is not None and abs(actual_risk - risk) <= MONEY_EPS, "native_event_matches_independent_initial_risk", run=label, setup_id=setup)
            checks.check(risk > 0 and abs(dec(exit_row.get("realized_r"), Decimal(0)) - position["net"] / risk) <= R_EPS, "native_cash_independent_realized_r", run=label, setup_id=setup)
        result.append(dict(setup_id=setup, direction=exit_row["direction"], fill_at=first["time"], exit_at=last["time"],
                           net_cash=float(position["net"]), independent_r=float(position["net"] / risk) if risk else None,
                           recorded_r=float(dec(exit_row.get("realized_r"), Decimal(0))), exit_reason=exit_row.get("exit_reason")))
    checks.check(len(matched) == len([1 for _, history in fill_groups if any(row["event_type"] == "EXIT" for row in history)]), "all_closed_fills_native_reconciled", run=label)
    return result


def metrics(rows):
    result = {}
    for direction in ("ALL", "LONG", "SHORT"):
        selected = [row for row in rows if direction == "ALL" or row["direction"] == direction]
        values = [row["recorded_r"] for row in selected]
        positives, negatives = sum(value for value in values if value > 0), -sum(value for value in values if value < 0)
        result[direction] = dict(closed_fills=len(values), total_r=sum(values), mean_r=sum(values) / len(values) if values else None,
                                 winners=sum(value > 0 for value in values), profit_factor_r=positives / negatives if negatives else None,
                                 custom_exits=sum(row.get("exit_reason") == SPECIAL for row in selected))
    return result


def comparisons(off, on, checks):
    first_custom = next((row for row in on["events"] if row["event_type"] in {"PARTIAL_EXIT", "EXIT"} and row.get("exit_reason") == SPECIAL), None)
    stop = first_custom["event_at"] if first_custom else None
    a = [identity(row) for row in off["events"] if row["event_type"] == "WAVE1_BREAK" and (stop is None or row["event_at"] < stop)]
    b = [identity(row) for row in on["events"] if row["event_type"] == "WAVE1_BREAK" and (stop is None or row["event_at"] < stop)]
    checks.check(a == b, "candidate_discovery_unchanged_before_first_custom_close", stop=stop)
    off_bars, on_bars = Path(off["path"]) / "upper_bars.csv", Path(on["path"]) / "upper_bars.csv"
    if off_bars.exists() and on_bars.exists():
        left = [{key: value for key, value in row.items() if key != "_row"} for row in read_rows(off_bars)]
        right = [{key: value for key, value in row.items() if key != "_row"} for row in read_rows(on_bars)]
        checks.check(left == right, "upper_bar_observations_identical")
    else:
        checks.missing("independent_upper_bars_unavailable")
    fills = {}
    for label, run in (("off", off), ("on", on)):
        indexed = {}
        for setup, history in run["groups"].items():
            fill = next((row for row in history if row["event_type"] == "FILL"), None)
            if fill is None:
                continue
            exit_row = next((row for row in history if row["event_type"] == "EXIT"), {})
            key = identity(fill)
            checks.check(key not in indexed, "unique_candidate_fill_identity", run=label, setup_id=setup)
            indexed[key] = dict(setup_id=setup, direction=fill["direction"], fill_at=fill["fill_at"], entry_price=fill["entry_price"],
                                sl_price=fill["sl_price"], tp_price=fill["tp_price"], exit_at=exit_row.get("exit_at"),
                                exit_reason=exit_row.get("exit_reason"), recorded_r=float(dec(exit_row.get("realized_r"), Decimal(0))) if exit_row else None)
        fills[label] = indexed
    common = fills["off"].keys() & fills["on"].keys()
    rows = []
    for key in sorted(fills["off"].keys() | fills["on"].keys()):
        left, right = fills["off"].get(key), fills["on"].get(key)
        rows.append(dict(identity=list(key), status="COMMON" if left and right else "OFF_ONLY" if left else "ON_ONLY", off=left, on=right,
                         delta_r=right["recorded_r"] - left["recorded_r"] if left and right and left["recorded_r"] is not None and right["recorded_r"] is not None else None))
        if left and right:
            checks.check(all(canonical(left[field]) == canonical(right[field]) for field in ("fill_at", "entry_price", "sl_price", "tp_price")), "common_fill_entry_plan_unchanged", off_setup=left["setup_id"], on_setup=right["setup_id"])
    all_metrics = {label: metrics([row for row in index.values() if row["recorded_r"] is not None]) for label, index in fills.items()}
    common_metrics = {label: metrics([index[key] for key in common if index[key]["recorded_r"] is not None]) for label, index in fills.items()}
    return dict(common_fills=len(common), off_only=len(fills["off"].keys() - common), on_only=len(fills["on"].keys() - common),
                all_fills=all_metrics, common_fills_metrics=common_metrics, candidate_prefix_cutoff=stop), rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--off", type=Path, required=True)
    parser.add_argument("--on", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    checks = Checks()
    off, on = load_run(args.off, checks, "off"), load_run(args.on, checks, "on")
    differences = configurations(off, on, checks)
    checks.check(not any(row["event_type"].startswith("OPPOSITE_") for row in off["events"]), "off_no_opposite_exit_events")
    armed = source_and_latch(on, checks)
    ticks = check_ticks(on, armed, checks)
    check_orders(on, checks)
    native = {"off": check_report(off, checks, "off"), "on": check_report(on, checks, "on")}
    comparison, cases = comparisons(off, on, checks)
    status = "FAIL" if checks.failures else "INCOMPLETE" if checks.incomplete else "PASS"
    report = dict(status=status, checks=checks.count, violations=len(checks.failures), failures=checks.failures,
                  incomplete=checks.incomplete, config_differences=differences, comparison=comparison,
                  armed_cases=ticks, native_cash_reconciliation=native,
                  limitations=["Report deal tables expose commission/swap/profit; separate DEAL_FEE is not exposed and must be zero or separately reconciled.",
                               "Tick arithmetic is independently checked; completeness of every received tester tick is evidenced by caller logging, not external tick-feed certification.",
                               "Future commission and slippage are estimates; positive requested net does not guarantee positive actual exit cash.",
                               "Candidate and fill changes after first custom close can result from earlier release of holding/side restrictions; no profitability promotion is implied."],
                  provenance={label: dict(path=run["path"], hashes=run["hashes"]) for label, run in (("off", off), ("on", on))})
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "opposite_exit_audit.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (args.out / "fill_comparison.json").write_text(json.dumps(cases, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["# 反対 W1 後プラス決済の固定比較", "", f"状態: {status} / {checks.count} checks / {len(checks.failures)} violations", "",
             f"待機 {len(armed)} 件、共通 fill {comparison['common_fills']} 件、OFF のみ {comparison['off_only']} 件、ON のみ {comparison['on_only']} 件。", "",
             "| 対象 | 側 | 終了数 | 合計 R | 平均 R | 専用決済数 |", "| --- | --- | ---: | ---: | ---: | ---: |"]
    for population, source in (("全取引", comparison["all_fills"]), ("共通取引", comparison["common_fills_metrics"])):
        for label in ("off", "on"):
            metric = source[label]["ALL"]
            avg = f"{metric['mean_r']:.6f}" if metric["mean_r"] is not None else "—"
            lines.append(f"| {population} | {label.upper()} | {metric['closed_fills']} | {metric['total_r']:.6f} | {avg} | {metric['custom_exits']} |")
    lines += ["", "LONG/SHORT 別集計、全待機事例、違反、欠落、ハッシュは opposite_exit_audit.json。共通／追加／消失 fill は fill_comparison.json。", "",
              "決済費用の事前値は推定。独立した価格損益・R 再計算の対応範囲は XAUUSD / USD 口座。収益性改善の合格判定や最適化は実施しない。", ""]
    (args.out / "README.md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps(dict(status=status, checks=checks.count, violations=len(checks.failures), incomplete=len(checks.incomplete), output=str(args.out)), ensure_ascii=False))
    return 1 if status == "FAIL" else 2 if status == "INCOMPLETE" else 0


if __name__ == "__main__":
    raise SystemExit(main())
