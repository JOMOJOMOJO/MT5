"""Audit a fixed-period OFF/ON comparison of the Wave33 upper-close Fib guard.

Read native events/config and, when supplied, independent upper_bars.csv.
No strategy decisions or profit-based selection are performed. Missing source
bars produce INCOMPLETE, not a fabricated first-close verification.
"""
from __future__ import annotations

import argparse
from bisect import bisect_left
import csv
import hashlib
import json
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from decimal import Decimal, InvalidOperation
from pathlib import Path
from statistics import mean, median


TARGET = "reject_deep_fib_close"
DEEP = "FIB_CLOSE_TOO_DEEP"
TRADE_EVENTS = {"SIGNAL", "ORDER", "FILL"}
END_EVENTS = {"SIGNAL", "INVALIDATE", "SKIP", "COMPLETED", "TEST_END"}
FIB_FIELDS = ("fib_close_bar_time", "fib_close_at", "fib_close_known_at",
              "fib_close_price", "fib_close_ratio")
META_KEYS = {
    "version", "ea_version", "resolved_run_tag", "run_tag", "draw",
    "keep_objects", "screenshots", "screenshot_limit", "show_info_panel",
    "diagnostic_labels", "show_swing_paths", "visual", "terminal_build",
}
CORE_KEYS = {
    "symbol", "upper_tf", "lower_tf", "swing_left", "swing_right", "fib_min",
    "fib_max", "require_fib_touch", "reject_deep_fib", "timeout_upper_bars",
    "strict_wave_lifecycle", "lower_recognition_mode", "minimum_wave1_room_r",
    "trigger_mode", "obstacle_mode", "reward_r", "risk_percent",
    "sl_extra_points", "tester_orders", "deviation_points", "point",
    "tick_size", "volume_min", "volume_step", "contract_size", "stops_level",
    "freeze_level", "chart_tf", "tester", "magic", "manual_levels_display_only",
}
IDENTITY_FIELDS = ("symbol", "upper_tf", "lower_tf", "direction",
                   "upper_break_bar_time", "upper_break_level_time",
                   "upper_break_level", "wave1_start_time", "wave1_start_price")
EPS = Decimal("1e-12")  # Arithmetic equality allowance, not a tradable buffer.


def read_csv(path: Path) -> tuple[list[str], list[dict]]:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        header = stream.readline()
        stream.seek(0)
        reader = csv.DictReader(stream, delimiter=";" if ";" in header else ",")
        fields = reader.fieldnames or []
        rows = [dict(row, _csv_row=index + 2) for index, row in enumerate(reader)]
    return fields, rows


def number(value: object) -> Decimal | None:
    try:
        result = Decimal(str(value))
        return result if result.is_finite() else None
    except (InvalidOperation, ValueError):
        return None


def stamp(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")
    except ValueError:
        return None


def text_time(value: datetime | None) -> str:
    return value.strftime("%Y.%m.%d %H:%M:%S") if value else ""


def seconds(frame: str) -> int | None:
    frame = frame.removeprefix("PERIOD_")
    if frame.startswith("M") and frame[1:].isdigit():
        return int(frame[1:]) * 60
    if frame.startswith("H") and frame[1:].isdigit():
        return int(frame[1:]) * 3600
    return {"D1": 86400, "W1": 604800}.get(frame)


def truth(value: object) -> bool | None:
    value = str(value).strip().lower()
    return True if value in {"true", "1"} else False if value in {"false", "0"} else None


def canonical(value: object) -> str:
    raw = str(value).strip()
    if raw.lower() in {"true", "false"}:
        return "1" if raw.lower() == "true" else "0"
    parsed = number(raw)
    return str(parsed.normalize()) if parsed is not None else raw


def identity(row: dict) -> tuple:
    return tuple(canonical(row.get(field, "")) for field in IDENTITY_FIELDS)


def source(path: Path) -> dict:
    return {"path": str(path.resolve()), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def row_reference(row: dict) -> dict:
    return {key: row.get(key, "") for key in
            ("_csv_row", "setup_id", "event_type", "event_at", "reason", "reason_kind")}


class Checks:
    def __init__(self) -> None:
        self.counts: Counter = Counter()
        self.violations: list[dict] = []

    def check(self, ok: bool, rule: str, **detail: object) -> None:
        self.counts[rule] += 1
        if not ok:
            self.violations.append({"rule": rule, **detail})


def load_run(path: Path) -> dict:
    fields, rows = read_csv(path / "events.csv")
    _, config_rows = read_csv(path / "config.csv")
    config = {row["parameter"]: row["value"] for row in config_rows}
    grouped: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        if row.get("setup_id"):
            grouped[row["setup_id"]].append(row)
    bars_path = path / "upper_bars.csv"
    bar_fields, bars = read_csv(bars_path) if bars_path.exists() else ([], [])
    run_path = path / "run.json"
    metadata = json.loads(run_path.read_text(encoding="utf-8-sig")) if run_path.exists() else {}
    return {"path": path, "fields": fields, "rows": rows, "config": config,
            "config_row_count": len(config_rows), "groups": grouped,
            "bar_fields": bar_fields, "bars": bars, "metadata": metadata}


def compare_configs(off: dict, on: dict, checks: Checks) -> dict:
    a, b = off["config"], on["config"]
    checks.check(truth(a.get(TARGET)) is False, "off_guard_disabled", value=a.get(TARGET))
    checks.check(truth(b.get(TARGET)) is True, "on_guard_enabled", value=b.get(TARGET))
    missing = {"off": sorted(CORE_KEYS - a.keys()), "on": sorted(CORE_KEYS - b.keys())}
    checks.check(not missing["off"] and not missing["on"], "core_config_fields_present", missing=missing)
    differences, allowed = {}, {}
    for key in sorted(a.keys() | b.keys()):
        if canonical(a.get(key, "<MISSING>")) == canonical(b.get(key, "<MISSING>")):
            continue
        item = {"off": a.get(key), "on": b.get(key)}
        if key == TARGET or key in META_KEYS or key.endswith("_assumption"):
            allowed[key] = item
        else:
            differences[key] = item
    checks.check(not differences, "only_guard_changes_trading_config", differences=differences)
    for arm, run in (("off", off), ("on", on)):
        checks.check(len(run["config"]) == run["config_row_count"], "config_parameter_unique", arm=arm)
    return {"trading_differences_other_than_guard": differences,
            "allowed_metadata_and_guard_differences": allowed, "missing_core_fields": missing}


def compare_periods(off: dict, on: dict, checks: Checks) -> dict:
    period_keys = ("date_from", "date_to", "symbol", "chart_period", "model")
    values = {key: {"off": off["metadata"].get(key), "on": on["metadata"].get(key)} for key in period_keys}
    # Native run.json historically leaves symbol to config.csv.
    for arm, run in (("off", off), ("on", on)):
        if values["symbol"][arm] is None:
            values["symbol"][arm] = run["config"].get("symbol")
        if values["chart_period"][arm] is None:
            values["chart_period"][arm] = run["config"].get("chart_tf", "").removeprefix("PERIOD_") or None
    complete = all(values[key][arm] is not None for key in period_keys for arm in ("off", "on"))
    if complete:
        checks.check(all(canonical(item["off"]) == canonical(item["on"]) for item in values.values()),
                     "same_requested_native_period_and_model", values=values)
    return {"status": "VERIFIED" if complete else "NOT_VERIFIED_MISSING_RUN_METADATA", "values": values}


def run_statistics(run: dict) -> dict:
    rows = run["rows"]
    events = Counter(row.get("event_type", "") for row in rows)
    closed: dict[str, dict] = {}
    for row in rows:
        if row.get("event_type") == "EXIT":
            closed[row.get("setup_id", "")] = row
    values = [float(value) for row in closed.values() if (value := number(row.get("realized_r"))) is not None]
    return {
        "rows": len(rows), "event_counts": dict(sorted(events.items())),
        "candidates": events["WAVE1_BREAK"], "signals": events["SIGNAL"],
        "orders": events["ORDER"], "fills": events["FILL"], "skips": events["SKIP"],
        "invalidations": events["INVALIDATE"], "exits": events["EXIT"],
        "candidate_directions": dict(Counter(row.get("direction", "") for row in rows if row.get("event_type") == "WAVE1_BREAK")),
        "skip_reasons": dict(Counter(row.get("reason") or row.get("skip_reason", "") for row in rows if row.get("event_type") == "SKIP")),
        "invalidation_reasons": dict(Counter(row.get("reason", "") for row in rows if row.get("event_type") == "INVALIDATE")),
        "ancillary_realized_r": {
            "scope": "CLOSED_SETUPS_ONLY_NOT_OPTIMIZATION_OR_PROMOTION",
            "basis": "last EXIT per setup; do not sum cumulative PARTIAL_EXIT rows",
            "cost_basis": "EA-recorded realized_r; current EA includes profit, commission, swap and fee. This auditor does not independently reconcile broker cash deals.",
            "closed_setups": len(closed), "numeric_exit_r": len(values),
            "total_r": sum(values) if values else None,
            "mean_r": mean(values) if values else None,
            "median_r": median(values) if values else None,
            "positive": sum(value > 0 for value in values),
            "negative": sum(value < 0 for value in values),
            "zero": sum(value == 0 for value in values),
            "unclosed_filled_setups": sorted({row.get("setup_id", "") for row in rows if row.get("event_type") == "FILL"} - closed.keys()),
        },
    }


def audit_run(run: dict, enabled: bool, checks: Checks) -> dict:
    arm = "on" if enabled else "off"
    required_events = {"event_type", "event_at", "setup_id", "reason", "reason_kind", *IDENTITY_FIELDS}
    checks.check(bool(run["rows"]) and not (required_events - set(run["fields"])),
                 "nonempty_native_event_stream_and_schema", arm=arm,
                 missing=sorted(required_events - set(run["fields"])))
    checks.check(not (set(FIB_FIELDS) - set(run["fields"])), "fib_columns_present", arm=arm,
                 missing=sorted(set(FIB_FIELDS) - set(run["fields"])))
    previous_time = None
    for row in run["rows"]:
        at = stamp(row.get("event_at"))
        checks.check(at is not None and (previous_time is None or at >= previous_time),
                     "events_in_observation_order", arm=arm, **row_reference(row))
        if at:
            previous_time = at
    duration = seconds(run["config"].get("upper_tf", ""))
    limit = number(run["config"].get("fib_max"))
    checks.check(duration is not None and limit is not None, "upper_frame_and_threshold_valid", arm=arm)
    bar_columns = {"symbol", "tf", "bar_time", "closed_at", "known_at", "open", "high", "low", "close"}
    raw_available = bool(run["bars"]) and not (bar_columns - set(run["bar_fields"]))
    if run["bars"]:
        checks.check(not (bar_columns - set(run["bar_fields"])), "upper_source_columns_present", arm=arm,
                     missing=sorted(bar_columns - set(run["bar_fields"])))
    valid_bars = []
    bar_keys = set()
    previous_bar = previous_known = None
    for bar in run["bars"]:
        opened, closed, known = (stamp(bar.get(key)) for key in ("bar_time", "closed_at", "known_at"))
        prices = [number(bar.get(key)) for key in ("open", "high", "low", "close")]
        valid = bool(duration and opened and closed and known and closed == opened + timedelta(seconds=duration)
                     and closed <= known and all(price is not None for price in prices)
                     and bar.get("symbol") == run["config"].get("symbol")
                     and bar.get("tf") == run["config"].get("upper_tf"))
        checks.check(valid, "source_upper_bar_valid", arm=arm, source_row=bar.get("_csv_row"))
        if not valid:
            continue
        op, high, low, close = prices
        checks.check(low <= min(op, close) <= max(op, close) <= high,
                     "source_upper_ohlc_consistent", arm=arm, source_row=bar.get("_csv_row"))
        key = (bar["symbol"], bar["tf"], bar["bar_time"])
        checks.check(key not in bar_keys, "source_upper_bar_unique", arm=arm, bar_time=bar["bar_time"])
        checks.check((previous_bar is None or opened > previous_bar) and
                     (previous_known is None or known >= previous_known),
                     "source_upper_bars_in_feed_order", arm=arm, bar_time=bar["bar_time"])
        bar_keys.add(key)
        previous_bar, previous_known = opened, known
        valid_bars.append((bar, opened, closed, known, close))
    bar_index_by_time = {entry[1]: index for index, entry in enumerate(valid_bars)}
    bar_times = [entry[1] for entry in valid_bars]
    source_gaps = [{"after_bar": text_time(previous[1]), "before_bar": text_time(current[1]),
                    "elapsed_seconds": int((current[1] - previous[1]).total_seconds())}
                   for previous, current in zip(valid_bars, valid_bars[1:])
                   if duration and current[1] - previous[1] > timedelta(seconds=duration)]
    results = {}
    equality_count = wick_only_count = raw_candidate_checks = 0
    ambiguities, preemptions, coverage_gaps = [], [], []
    for setup_id, history in run["groups"].items():
        breaks = [row for row in history if row.get("event_type") == "WAVE1_BREAK"]
        checks.check(len(breaks) == 1, "each_setup_has_one_candidate", arm=arm, setup_id=setup_id, count=len(breaks))
        if breaks:
            checks.check(breaks[0].get("direction") in {"LONG", "SHORT"}
                         and all(breaks[0].get(field, "") != "" for field in IDENTITY_FIELDS),
                         "candidate_identity_fields_present", arm=arm, setup_id=setup_id)
        deep = [row for row in history if row.get("event_type") == DEEP]
        checks.check(len(deep) <= 1, "first_upper_close_measurement_unique", arm=arm, setup_id=setup_id)
        peaks = [row for row in history if row.get("event_type") == "WAVE1_PEAK_CONFIRMED"]
        checks.check(len(peaks) <= 1, "fixed_peak_confirmation_unique", arm=arm, setup_id=setup_id)
        peak = peaks[0] if peaks else None
        info = {"setup_id": setup_id, "deep_events": len(deep), "raw_status": "NO_FIXED_W1" if not peak else "NOT_VERIFIED_SOURCE_BARS_MISSING"}
        if peak:
            anchors = ("symbol", "upper_tf", "lower_tf", "direction", "wave1_start_time", "wave1_start_price",
                       "wave1_peak_time", "wave1_peak_price", "wave1_peak_known_at", "fib_382_price", "fib_618_price")
            for later in history[history.index(peak) + 1:]:
                changed = {key: {"fixed": peak.get(key), "later": later.get(key)} for key in anchors
                           if canonical(peak.get(key, "")) != canonical(later.get(key, ""))}
                checks.check(not changed, "fixed_w1_anchors_do_not_rewrite", arm=arm, **row_reference(later), changes=changed)
        for row in deep:
            index = history.index(row)
            checks.check(peak is not None and history.index(peak) < index
                         and not any(prior.get("event_type") in END_EVENTS for prior in history[:index]),
                         "fib_measurement_belongs_to_live_fixed_candidate", arm=arm, **row_reference(row))
            opened, closed, known = (stamp(row.get(key)) for key in FIB_FIELDS[:3])
            event_at = stamp(row.get("event_at"))
            peak_known = stamp(row.get("wave1_peak_known_at"))
            start, end, price, recorded = (number(row.get(key)) for key in
                                           ("wave1_start_price", "wave1_peak_price", "fib_close_price", "fib_close_ratio"))
            direction = 1 if row.get("direction") == "LONG" else -1
            span = direction * (end - start) if start is not None and end is not None else None
            ratio = direction * (end - price) / span if span and span > 0 and price is not None else None
            checks.check(bool(opened and closed and known and duration and closed == opened + timedelta(seconds=duration)
                              and closed <= known == event_at and peak_known and peak_known <= known),
                         "fib_close_is_closed_and_currently_knowable", arm=arm, **row_reference(row))
            checks.check(ratio is not None and recorded is not None and abs(ratio - recorded) <= Decimal("1e-8"),
                         "fib_ratio_from_fixed_anchors_and_close", arm=arm, **row_reference(row))
            checks.check(ratio is not None and limit is not None and ratio > limit + EPS,
                         "strictly_deeper_than_limit_equality_allowed", arm=arm, **row_reference(row))
            checks.check(row.get("reason_kind") == ("EXCLUSION" if enabled else "MEASUREMENT"),
                         "measurement_or_exclusion_matches_input", arm=arm, **row_reference(row))
            checks.check(not any(prior.get("event_type") == "SIGNAL" for prior in history[:index]),
                         "fib_guard_applies_before_signal_only", arm=arm, **row_reference(row))
            if enabled:
                invalidations = [later for later in history[index + 1:] if later.get("event_type") == "INVALIDATE" and later.get("reason") == DEEP]
                checks.check(len(invalidations) == 1 and invalidations[0].get("event_at") == row.get("event_at"),
                             "on_exclusion_invalidates_at_same_known_time", arm=arm, **row_reference(row))
                checks.check(index + 1 < len(history) and history[index + 1].get("event_type") == "INVALIDATE"
                             and history[index + 1].get("reason") == DEEP
                             and history[index + 1].get("event_at") == row.get("event_at"),
                             "invalidation_is_next_setup_event", arm=arm, **row_reference(row))
                checks.check(not any(later.get("event_type") in TRADE_EVENTS for later in history[index + 1:]),
                             "no_signal_order_fill_after_exclusion", arm=arm, **row_reference(row))
            else:
                checks.check(not any(later.get("event_type") == "INVALIDATE" and later.get("reason") == DEEP for later in history),
                             "off_measurement_does_not_exclude", arm=arm, **row_reference(row))
        for row in history:
            if row.get("event_type") == "INVALIDATE" and row.get("reason") == DEEP:
                checks.check(enabled and bool(deep), "fib_invalidation_has_enabled_measurement", arm=arm, **row_reference(row))
        if peak and raw_available and duration and limit is not None:
            raw_candidate_checks += 1
            direction = 1 if peak.get("direction") == "LONG" else -1
            start, end = number(peak.get("wave1_start_price")), number(peak.get("wave1_peak_price"))
            peak_known = stamp(peak.get("wave1_peak_known_at"))
            peak_time = stamp(peak.get("wave1_peak_time"))
            wave2_start = peak_time + timedelta(seconds=duration) if peak_time else None
            recorded_start = stamp(peak.get("wave2_start_time"))
            checks.check(recorded_start is None or recorded_start == wave2_start,
                         "wave2_begins_after_fixed_peak_candle", arm=arm, setup_id=setup_id)
            span = direction * (end - start) if start is not None and end is not None else None
            checks.check(bool(span and span > 0 and peak_known and wave2_start), "raw_oracle_fixed_anchors_valid", arm=arm, setup_id=setup_id)
            if not (span and span > 0 and peak_known and wave2_start):
                results[setup_id] = info
                continue
            after_peak = history[history.index(peak) + 1:]
            terminal = next((row for row in after_peak if row.get("event_type") in END_EVENTS), None)
            stop = stamp(terminal.get("event_at")) if terminal else stamp(history[-1].get("event_at"))
            source_peak = bar_index_by_time.get(peak_time)
            right = number(run["config"].get("swing_right"))
            confirmation_index = source_peak + int(right) if source_peak is not None and right is not None else None
            if confirmation_index is None or confirmation_index >= len(valid_bars):
                info["raw_status"] = "NOT_VERIFIED_SOURCE_DOES_NOT_COVER_PEAK_CONFIRMATION"
                coverage_gaps.append({"setup_id": setup_id, "peak_time": text_time(peak_time)})
                results[setup_id] = info
                continue
            confirmation = valid_bars[confirmation_index]
            checks.check(confirmation[3] == peak_known,
                         "peak_confirmation_matches_independent_right_hand_bars", arm=arm, setup_id=setup_id,
                         peak_known_at=text_time(peak_known), source_confirmation_known_at=text_time(confirmation[3]))
            source_peak_price = number(valid_bars[source_peak][0]["high" if direction > 0 else "low"])
            checks.check(source_peak_price == end, "fixed_peak_matches_independent_upper_extreme", arm=arm, setup_id=setup_id)
            if stop:
                midnight = stop.replace(hour=0, minute=0, second=0, microsecond=0)
                required_close = midnight + timedelta(seconds=(int((stop - midnight).total_seconds()) // duration) * duration)
                if not valid_bars or valid_bars[-1][2] < required_close:
                    info["raw_status"] = "NOT_VERIFIED_SOURCE_TAIL_BEFORE_GUARD_WINDOW_END"
                    coverage_gaps.append({"setup_id": setup_id, "required_closed_at": text_time(required_close),
                                          "source_last_closed_at": text_time(valid_bars[-1][2]) if valid_bars else ""})
                    results[setup_id] = info
                    continue
            observable = []
            first_index = bisect_left(bar_times, wave2_start)
            last_index = bisect_left(bar_times, stop) if stop else first_index
            for bar_index in range(first_index, last_index):
                bar, opened, closed, known, close = valid_bars[bar_index]
                availability = max(known, peak_known)
                if opened < wave2_start or stop is None or availability > stop:
                    continue
                # The confirmation feed scans only the upper prefix already in
                # memory. Later bars sharing its known_at are not retroactive
                # members of that prefix. A prior lower close may end the lane.
                nominal_terminal = stamp(terminal.get("signal_at")) if terminal and terminal.get("event_type") == "SIGNAL" else None
                if terminal and terminal.get("reason") == "INITIAL_MOVE_MISSED":
                    nominal_terminal = stamp(terminal.get("first_progress_close_at"))
                if bar_index > confirmation_index and nominal_terminal and availability == stop and closed > nominal_terminal:
                    continue
                ratio = direction * (end - close) / span
                equality_count += abs(ratio - limit) <= EPS
                wick = number(bar["low"] if direction > 0 else bar["high"])
                wick_only_count += bool(wick is not None and direction * (end - wick) / span > limit + EPS and ratio <= limit + EPS)
                if ratio > limit + EPS:
                    observable.append((availability, closed, opened, bar, ratio, bar_index))
            observable.sort(key=lambda item: item[:3])
            expected = observable[0] if observable else None
            info["raw_status"] = "VERIFIED"
            info["first_expected_close"] = None if not expected else {
                "bar_time": text_time(expected[2]), "closed_at": text_time(expected[1]),
                "known_at": text_time(expected[0]), "close": expected[3]["close"], "ratio": str(expected[4]),
            }
            # Current-upper timeout/origin checks precede the new close guard.
            # Other same-tick terminal orderings require LTF source/sequence and
            # remain explicitly NOT_VERIFIED, never silently counted as PASS.
            competing = bool(expected and not deep and terminal and terminal.get("event_type") != "SIGNAL"
                             and terminal.get("reason") != DEEP and stamp(terminal.get("event_at")) == expected[0])
            if competing:
                current_upper = expected[5] > confirmation_index
                low_or_high = number(expected[3]["low" if direction > 0 else "high"])
                origin_preempts = (current_upper and terminal.get("reason") == "WAVE1_ORIGIN_BROKEN"
                                   and low_or_high is not None and direction * (low_or_high - start) <= 0)
                break_time = stamp(breaks[0].get("upper_break_bar_time")) if breaks else None
                break_index = bar_index_by_time.get(break_time)
                timeout = number(run["config"].get("timeout_upper_bars"))
                timeout_preempts = (current_upper and str(terminal.get("reason", "")).startswith("TIMEOUT")
                                    and break_index is not None and timeout is not None
                                    and expected[5] - break_index >= int(timeout))
                item = {"setup_id": setup_id, "terminal": row_reference(terminal), "expected": info["first_expected_close"]}
                if origin_preempts or timeout_preempts:
                    info["raw_status"] = "VERIFIED_CURRENT_UPPER_PRECEDENCE"
                    preemptions.append(item)
                else:
                    info["raw_status"] = "NOT_VERIFIED_COMPETING_TERMINAL_SAME_KNOWN_TICK"
                    ambiguities.append(item)
            else:
                checks.check(bool(deep) == bool(expected), "raw_first_close_breach_is_accounted", arm=arm, setup_id=setup_id,
                             expected=info["first_expected_close"], measured=len(deep))
            if deep and expected:
                measured = deep[0]
                checks.check(measured.get("fib_close_bar_time") == text_time(expected[2])
                             and measured.get("fib_close_at") == text_time(expected[1])
                             and measured.get("fib_close_known_at") == text_time(expected[0])
                             and number(measured.get("fib_close_price")) == number(expected[3]["close"]),
                             "native_measurement_is_independent_first_upper_close", arm=arm, **row_reference(measured), expected=info["first_expected_close"])
                recorded_ratio = number(measured.get("fib_close_ratio"))
                checks.check(recorded_ratio is not None and abs(recorded_ratio - expected[4]) <= Decimal("1e-8"),
                             "recorded_ratio_matches_independent_first_source_close", arm=arm, **row_reference(measured), expected_ratio=str(expected[4]))
            elif deep:
                checks.check(False, "measurement_requires_observable_source_close", arm=arm, **row_reference(deep[0]))
        results[setup_id] = info
    stats = run_statistics(run)
    stats.update({"run": str(run["path"].resolve()), "guard_enabled": enabled,
                  "independent_upper_close_audit": {
                      "status": ("NOT_VERIFIED_SOURCE_BARS_MISSING_OR_EMPTY" if not raw_available else
                                 "INCOMPLETE_UNRESOLVED_SOURCE_OR_EVENT_ORDER" if ambiguities or coverage_gaps else
                                 "NOT_OBSERVED_NO_FIXED_CANDIDATE" if not raw_candidate_checks else "VERIFIED"),
                      "source_bars": len(run["bars"]), "fixed_candidate_checks": raw_candidate_checks,
                      "source_time_gaps": source_gaps,
                      "broker_history_completeness": "NOT_VERIFIED_GAPS_MAY_BE_MARKET_CLOSURES_OR_MISSING_DATA",
                      "equal_boundary_observations": equality_count,
                      "equality_status": "OBSERVED_AND_CHECKED" if equality_count else "NOT_OBSERVED_NATIVE_REQUIRES_HARNESS",
                      "wick_only_deep_observations": wick_only_count, "verified_upper_preemptions": preemptions,
                      "unverified_same_tick_terminals": ambiguities, "source_coverage_gaps": coverage_gaps,
                  }, "setups": results})
    return stats


def compare_candidates(off: dict, on: dict, reports: dict, checks: Checks) -> tuple[dict, list[dict]]:
    inventories = {}
    for arm, run in (("off", off), ("on", on)):
        inventory = defaultdict(list)
        for row in run["rows"]:
            if row.get("event_type") == "WAVE1_BREAK":
                inventory[identity(row)].append(row)
        for key, rows in inventory.items():
            checks.check(len(rows) == 1, "candidate_identity_unique", arm=arm, identity=list(key), setup_ids=[row.get("setup_id") for row in rows])
        inventories[arm] = inventory
    a, b = inventories["off"], inventories["on"]
    missing_on, missing_off = sorted(a.keys() - b.keys()), sorted(b.keys() - a.keys())
    checks.check(not missing_on and not missing_off, "all_candidates_accounted_in_both_arms",
                 missing_on=[list(key) for key in missing_on], missing_off=[list(key) for key in missing_off])
    comparison = []
    for key in sorted(a.keys() | b.keys()):
        item = dict(zip(IDENTITY_FIELDS, key))
        for arm, run in (("off", off), ("on", on)):
            candidate = inventories[arm].get(key, [])
            setup_id = candidate[0].get("setup_id", "") if candidate else ""
            history = run["groups"].get(setup_id, [])
            item[arm + "_setup_id"] = setup_id
            counts = Counter(row.get("event_type") for row in history)
            for event in ("SIGNAL", "ORDER", "FILL", "SKIP", "INVALIDATE", DEEP):
                item[arm + "_" + event.lower()] = counts[event]
            deep = next((row for row in history if row.get("event_type") == DEEP), {})
            for field in FIB_FIELDS:
                item[arm + "_" + field] = deep.get(field, "")
            exits = [row for row in history if row.get("event_type") == "EXIT"]
            item[arm + "_realized_r_closed"] = exits[-1].get("realized_r", "") if exits else ""
            item[arm + "_raw_status"] = reports[arm]["setups"].get(setup_id, {}).get("raw_status", "MISSING_CANDIDATE")
        comparison.append(item)
    return {"identity_fields": list(IDENTITY_FIELDS), "matched": len(a.keys() & b.keys()),
            "off_count": sum(map(len, a.values())), "on_count": sum(map(len, b.values())),
            "missing_on": [list(key) for key in missing_on], "missing_off": [list(key) for key in missing_off]}, comparison


def audit(off_path: Path, on_path: Path) -> tuple[dict, list[dict]]:
    off, on = load_run(off_path), load_run(on_path)
    checks = Checks()
    configuration = compare_configs(off, on, checks)
    period = compare_periods(off, on, checks)
    reports = {"off": audit_run(off, False, checks), "on": audit_run(on, True, checks)}
    if off["bars"] and on["bars"]:
        source_fields = ("symbol", "tf", "bar_time", "closed_at", "known_at", "open", "high", "low", "close")
        a = [tuple(canonical(row.get(key, "")) for key in source_fields) for row in off["bars"]]
        b = [tuple(canonical(row.get(key, "")) for key in source_fields) for row in on["bars"]]
        checks.check(a == b, "off_on_independent_upper_bars_identical", off_bars=len(a), on_bars=len(b))
    coverage, comparison = compare_candidates(off, on, reports, checks)
    raw_verified = all(report["independent_upper_close_audit"]["status"] == "VERIFIED" for report in reports.values())
    complete = raw_verified and period["status"] == "VERIFIED"
    status = "FAIL" if checks.violations else "PASS" if complete else "INCOMPLETE"
    inputs = {}
    for arm, run in (("off", off), ("on", on)):
        inputs[arm] = {name: source(run["path"] / name) for name in ("events.csv", "config.csv", "run.json", "upper_bars.csv") if (run["path"] / name).exists()}
    result = {"scope": "UPPER_CLOSED_FIB_OFF_ON_ENGINEERING_NOT_PROFIT_OPTIMIZATION",
              "status": status, "passed": status == "PASS", "inputs": inputs,
              "configuration": configuration, "period": period, "candidate_coverage": coverage,
              "runs": reports, "checks": dict(checks.counts), "check_count": sum(checks.counts.values()),
              "violations": checks.violations,
              "limits": [
                  "All source bars are accepted upper candles logged independently by the EA adapter; no broker-data completeness proof is inferred.",
                  "Candidate coverage means every recorded WAVE1_BREAK in the OFF/ON pair; omitted opportunities are not independently reconstructed.",
                  "OHLC cannot determine intrabar high/low ordering; only final upper closes are tested.",
                  "Current-upper origin/timeout priority is checked from source bars; other unresolved same-known-tick terminal order is NOT_VERIFIED.",
                  "No observed exact equality is reported as NOT_OBSERVED; harness evidence is separate.",
                  "Realized R is a closed-setup auxiliary summary; no thresholds or winners were selected from it.",
              ]}
    return result, comparison


def markdown(result: dict) -> str:
    lines = ["# Wave33 上位確定終値Fib：OFF/ON監査", "",
             f"状態: **{result['status']}**。利益最適化・動画一致・昇格の判定ではない。", "",
             "記録された全候補を連番に依存しない固定キーで対応付け、片側欠落も記録する。元足からの候補再抽出は行わず、未記録の機会がないことまでは保証しない。", "",
             "|設定|候補|SIGNAL|ORDER|FILL|SKIP|INVALIDATE|EXIT|確定決済R合計|平均R|", "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for arm in ("off", "on"):
        row = result["runs"][arm]
        total = row["ancillary_realized_r"]["total_r"]
        average = row["ancillary_realized_r"]["mean_r"]
        lines.append("|" + "|".join(map(str, [arm, row["candidates"], row["signals"], row["orders"], row["fills"], row["skips"], row["invalidations"], row["exits"], "—" if total is None else round(total, 6), "—" if average is None else round(average, 6)])) + "|")
    lines += ["", "Rは各setupの最終EXITだけを集計する。現EAがprofit・commission・swap・feeを含めて記録したRを使い、監査側で個々の口座通貨決済と再照合するものではない。未決済や診断シグナルを損益ゼロの取引へ置換しない。", "",
              f"候補対応: {result['candidate_coverage']['matched']}件。ON欠落{len(result['candidate_coverage']['missing_on'])}件、OFF欠落{len(result['candidate_coverage']['missing_off'])}件。",
              f"設定・期間・候補・イベント監査: {result['check_count']}チェック、違反{len(result['violations'])}件。", ""]
    for arm in ("off", "on"):
        raw = result["runs"][arm]["independent_upper_close_audit"]
        lines += [f"- {arm}: 原本上位足 {raw['source_bars']}本、初回終値監査 {raw['status']}。",
                  f"  等号: {raw['equality_status']}（{raw['equal_boundary_observations']}観測）、ヒゲだけの超過{raw['wick_only_deep_observations']}観測、元足で確認した上位優先失効{len(raw['verified_upper_preemptions'])}件、順序未確認{len(raw['unverified_same_tick_terminals'])}件。",
                  f"  上位足ログの不連続区間{len(raw['source_time_gaps'])}件は列挙するが、市場休止とデータ欠落の独立判別はしていない。監査対象は記録された受理済み上位足である。"]
    lines += ["", "原本上位足がなければ初回・ヒゲと終値・等号の独立検証をPASSにしない。除外後SIGNAL/ORDER/FILL禁止とON同時刻INVALIDATEはイベント行順で検査する。", "",
              "全候補: [candidate_comparison.csv](candidate_comparison.csv)。設定差、原本SHA256、初回該当足、既知時刻、全違反・検証限界: [fib_close_audit.json](fib_close_audit.json)。", ""]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--off", type=Path, required=True)
    parser.add_argument("--on", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    try:
        result, comparison = audit(args.off, args.on)
    except (OSError, ValueError, KeyError, csv.Error) as error:
        result = {"status": "FAIL", "passed": False, "input_error": str(error)}
        (args.out / "fib_close_audit.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
        return 1
    (args.out / "fib_close_audit.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (args.out / "README.md").write_text(markdown(result), encoding="utf-8")
    with (args.out / "candidate_comparison.csv").open("w", encoding="utf-8-sig", newline="") as stream:
        fields = list(comparison[0]) if comparison else list(IDENTITY_FIELDS)
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(comparison)
    print(json.dumps({key: result[key] for key in ("status", "passed", "check_count")}, ensure_ascii=False))
    return 0 if result["passed"] else 2 if result["status"] == "INCOMPLETE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
