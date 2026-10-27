"""Audit one fixed OFF/ON comparison of conditional Wave33 endpoint extension.

Uses native event snapshots plus separately written accepted upper/lower OHLC.
Checks knowledge time, revision boundaries, immutable identity, source eligibility,
minimum-Fib lock and the opposite-wave exit event source. This is engineering
evidence, not a proof of complete broker history or profitable wave recognition.
"""
from __future__ import annotations

import argparse
from bisect import bisect_left, bisect_right
from collections import Counter, defaultdict
import csv
from datetime import datetime, timedelta
from decimal import Decimal
import json
from pathlib import Path

from audit_fib_close import (Checks, META_KEYS, canonical, identity, number,
                             read_csv, seconds, source, stamp, text_time, truth)

TARGET = "extend_wave1_before_fib"
PREVIOUS = "WAVE1_EXTENSION_PREVIOUS_ANCHORS"
START = "WAVE1_EXTENSION_STARTED"
TRACK = "WAVE1_EXTENSION_TRACKING"
CONFIRM = "WAVE1_EXTENDED_CONFIRMED"
LOCK = "WAVE1_EXTENSION_LOCKED"
INITIAL = "WAVE1_PEAK_CONFIRMED"
ARM = "OPPOSITE_WAVE1_ARMED"
EXTENSION_EVENTS = {PREVIOUS, START, TRACK, CONFIRM, LOCK}
REVISION_FIELDS = {
    "wave1_revision", "wave1_extension_pending", "wave1_extension_started_at",
    "wave1_extension_known_at", "wave1_previous_peak_time", "wave1_previous_peak_known_at",
    "wave1_previous_peak_price", "wave1_extension_locked", "wave1_extension_lock_bar_time",
    "wave1_extension_lock_known_at", "wave1_extension_lock_reason",
    "wave1_provisional_time", "wave1_provisional_price",
}
IDENTITY = ("setup_id", "symbol", "upper_tf", "lower_tf", "direction", "candidate_detected_at",
            "upper_break_level", "upper_break_confirmed_at", "upper_break_bar_time",
            "upper_break_level_time", "upper_break_level_known_at", "wave1_start_time",
            "wave1_start_price", "wave1_start_known_at")
ZERO_PRICES = ("wave1_peak_price", "fib_382_price", "fib_618_price", "wave2_extreme_price",
               "retracement_ratio", "trigger_line_price", "pivot_trigger_price", "trendline_trigger_price",
               "trigger_delta_points", "entry_price", "sl_price", "tp_price", "risk_points",
               "actual_rr", "nearest_obstacle_price", "obstacle_distance_r", "wave1_room_r",
               "wave1_room_price", "first_progress_price", "lower_wave2_price", "fib_close_price", "fib_close_ratio")
ZERO_TIMES = ("wave1_peak_time", "wave1_peak_known_at", "wave1_extension_known_at",
              "wave2_start_time", "wave2_extreme_time", "wave2_extreme_known_at", "fib_touch_at",
              "fib_touch_known_at", "trigger_known_at", "lower_structure_known_at", "signal_at",
              "signal_known_at", "trigger_bar_time", "pivot_trigger_at", "pivot_trigger_known_at",
              "trendline_trigger_at", "trendline_trigger_known_at", "order_sent_at", "fill_at",
              "first_progress_bar_time", "first_progress_close_at", "first_progress_known_at",
              "lower_wave2_time", "fib_close_bar_time", "fib_close_at", "fib_close_known_at",
              "nearest_obstacle_time", "nearest_obstacle_known_at")
ZERO_TEXT = ("lower_pivot_times", "lower_pivot_prices", "trigger_type", "nearest_obstacle_source")
D0 = Decimal(0)
EPS = Decimal("1e-9")  # CSV prices are recorded to 10 decimal places.


def dec(value: object) -> Decimal:
    return number(value) or D0


def revision(row: dict) -> int:
    return int(dec(row.get("wave1_revision")))


def reference(row: dict) -> dict:
    return {key: row.get(key, "") for key in
            ("_csv_row", "setup_id", "event_type", "event_at", "wave1_revision", "reason")}


def load(path: Path) -> dict:
    fields, rows = read_csv(path / "events.csv")
    _, settings = read_csv(path / "config.csv")
    groups: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        if row.get("setup_id"):
            groups[row["setup_id"]].append(row)
    bars = {}
    files = [source(path / "events.csv"), source(path / "config.csv")]
    for label in ("upper", "lower"):
        filename = path / f"{label}_bars.csv"
        _, raw = read_csv(filename) if filename.exists() else ([], [])
        prepared = []
        for row in raw:
            item = dict(row)
            item["_time"] = stamp(row.get("bar_time"))
            item["_known"] = stamp(row.get("known_at"))
            item["_closed"] = stamp(row.get("closed_at"))
            if not all(item[key] for key in ("_time", "_known", "_closed")):
                raise ValueError(f"Invalid {label} source time at {filename}:{row['_csv_row']}")
            prepared.append(item)
        bars[label] = prepared
        if filename.exists():
            files.append(source(filename))
    config = {row["parameter"]: row["value"] for row in settings}
    metadata_path = path / "run.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8-sig")) if metadata_path.exists() else {}
    return {"path": str(path.resolve()), "fields": set(fields), "rows": rows, "config": config,
            "config_count": len(settings), "groups": groups, "bars": bars, "sources": files,
            "metadata": metadata}


class BarIndex:
    def __init__(self, run: dict) -> None:
        self.bars = run["bars"]
        self.starts = {kind: [row["_time"] for row in values] for kind, values in self.bars.items()}
        self.by_time = {kind: {row["_time"]: row for row in values} for kind, values in self.bars.items()}

    def after(self, kind: str, start: datetime, known: datetime, inclusive_known: bool = True) -> list[dict]:
        values = self.bars[kind]
        first = bisect_left(self.starts[kind], start)
        # Accepted source bars are monotone by time/known_at. Slicing by source
        # time and filtering availability also handles deliberately delayed input.
        return [row for row in values[first:] if row["_known"] <= known and
                (inclusive_known or row["_known"] < known)]


def direction(row: dict) -> int:
    if row.get("direction") not in {"LONG", "SHORT"}:
        raise ValueError(f"Invalid direction in {reference(row)}")
    return 1 if row["direction"] == "LONG" else -1


def reaches(bar: dict, anchor: dict, minimum: Decimal) -> bool:
    d = direction(anchor)
    peak, origin = dec(anchor["wave1_peak_price"]), dec(anchor["wave1_start_price"])
    span = d * (peak-origin)
    threshold = peak-d*span*minimum
    price = dec(bar["low" if d > 0 else "high"])
    return span > 0 and d*(price-threshold) <= span*Decimal("1e-12") + EPS


def compare_config(off: dict, on: dict, checks: Checks) -> dict:
    a, b = off["config"], on["config"]
    checks.check(truth(a.get(TARGET)) is False and truth(b.get(TARGET)) is True,
                 "fixed_off_on_extension_flag", off=a.get(TARGET), on=b.get(TARGET))
    differences = {}
    for key in sorted(a.keys() | b.keys()):
        if canonical(a.get(key, "<MISSING>")) == canonical(b.get(key, "<MISSING>")):
            continue
        differences[key] = {"off": a.get(key), "on": b.get(key)}
        checks.check(key == TARGET or key in META_KEYS or key.endswith("_assumption"),
                     "only_extension_changes_trading_config", parameter=key, values=differences[key])
    for arm, run in (("off", off), ("on", on)):
        checks.check(len(run["config"]) == run["config_count"], "config_names_unique", arm=arm)
    period = {}
    for key in ("date_from", "date_to", "model", "symbol", "chart_period"):
        va, vb = off["metadata"].get(key), on["metadata"].get(key)
        if va is not None and vb is not None:
            period[key] = {"off": va, "on": vb}
            checks.check(canonical(va) == canonical(vb), "same_native_requested_period_model", parameter=key, values=period[key])
    return {"differences": differences, "available_requested_run_metadata": period,
            "period_metadata_complete": all(key in period for key in ("date_from", "date_to", "model"))}


def validate_sources(run: dict, checks: Checks, arm: str) -> dict:
    result = {}
    for kind in ("upper", "lower"):
        bars = run["bars"][kind]
        gaps = []
        previous = None
        for bar in bars:
            tf_seconds = seconds(bar.get("tf", ""))
            checks.check(tf_seconds is not None and bar["_closed"] == bar["_time"]+timedelta(seconds=tf_seconds or 0) and
                         bar["_known"] >= bar["_closed"], "independent_source_is_closed_and_available", arm=arm,
                         kind=kind, row=bar["_csv_row"])
            lo, hi, op, cl = [dec(bar[key]) for key in ("low", "high", "open", "close")]
            checks.check(lo <= op <= hi and lo <= cl <= hi, "independent_source_ohlc_consistent", arm=arm,
                         kind=kind, row=bar["_csv_row"])
            if previous:
                checks.check(previous["_time"] < bar["_time"] and previous["_known"] <= bar["_known"],
                             "independent_source_monotone_unique", arm=arm, kind=kind, row=bar["_csv_row"])
                if tf_seconds and bar["_time"]-previous["_time"] != timedelta(seconds=tf_seconds):
                    gaps.append({"after": text_time(previous["_time"]), "before": text_time(bar["_time"])})
            previous = bar
        result[kind] = {"status": "AVAILABLE" if bars else "MISSING", "accepted_bars": len(bars),
                        "source_interval_gaps": gaps}
    return result


def source_eligibility(previous: dict, started: dict, index: BarIndex, minimum: Decimal,
                       checks: Checks, arm: str) -> dict:
    at, peak_time = stamp(started["event_at"]), stamp(previous["wave1_peak_time"])
    duration = seconds(previous["upper_tf"])
    if not at or not peak_time or not duration:
        checks.check(False, "extension_source_times_present", arm=arm, **reference(started))
        return {"status": "FAIL"}
    epoch = peak_time+timedelta(seconds=duration)
    source_time = stamp(started.get("wave1_provisional_time"))
    current = index.by_time["upper"].get(source_time)
    if index.bars["upper"]:
        checks.check(current is not None, "extension_has_independent_upper_source", arm=arm, **reference(started))
    if current is None:
        return {"status": "NOT_VERIFIED_MISSING_UPPER_BAR"}
    d = direction(previous)
    extreme = dec(current["high" if d > 0 else "low"])
    checks.check(current["_known"] == at and current["_time"] >= epoch and d*(extreme-dec(previous["wave1_peak_price"])) > 0,
                 "extension_is_current_closed_directional_extreme", arm=arm, **reference(started))
    checks.check(abs(extreme-dec(started["wave1_provisional_price"])) <= EPS,
                 "extension_provisional_matches_independent_source", arm=arm, **reference(started))
    # Upper is processed ahead of lower on equal close time. The current upper
    # OHLC itself must not contain the old threshold: that would be ambiguous.
    qualifying = []
    for kind in ("upper", "lower"):
        for bar in index.after(kind, epoch, at, inclusive_known=kind == "upper"):
            if reaches(bar, previous, minimum):
                qualifying.append({"kind": kind, "bar_time": text_time(bar["_time"]), "known_at": text_time(bar["_known"])})
    checks.check(not qualifying, "no_known_old_min_fib_before_extension", arm=arm, **reference(started), qualifying=qualifying[:10])
    return {"status": "VERIFIED" if index.bars["lower"] else "NOT_VERIFIED_MISSING_LOWER_SOURCE",
            "setup_id": started["setup_id"], "revision": revision(started), "at": started["event_at"],
            "source_bar": text_time(source_time), "old_peak": previous["wave1_peak_price"],
            "new_provisional": started["wave1_provisional_price"], "qualifying_old_sources": qualifying}


def verify_pivot(row: dict, index: BarIndex, config: dict, checks: Checks, arm: str) -> None:
    at, peak = stamp(row["event_at"]), stamp(row.get("wave1_peak_time"))
    bars, starts = index.bars["upper"], index.starts["upper"]
    if not bars:
        return  # Overall status becomes INCOMPLETE; no invented source proof.
    left, right = int(dec(config.get("swing_left", 2))), int(dec(config.get("swing_right", 2)))
    k = bisect_left(starts, peak) if peak else -1
    complete = k >= left and k+right < len(bars) and starts[k] == peak
    checks.check(complete, "confirmed_endpoint_source_window_present", arm=arm, **reference(row))
    if not complete:
        return
    d = direction(row)
    field = "high" if d > 0 else "low"
    price = dec(bars[k][field])
    unique = all(d*(price-dec(bars[j][field])) > 0 for j in range(k-left, k+right+1) if j != k)
    checks.check(unique and abs(price-dec(row["wave1_peak_price"])) <= EPS and bars[k+right]["_known"] == at and
                 stamp(row.get("wave1_peak_known_at")) == at,
                 "confirmed_endpoint_waits_actual_right_bars", arm=arm, **reference(row),
                 source_right_known=text_time(bars[k+right]["_known"]))


def first_lock_source(anchor: dict, lock: dict, index: BarIndex, minimum: Decimal) -> dict | None:
    """Independently reconstruct first eligible source in adapter/engine order.

    At anchor fixation the engine characterizes already received upper history
    first, then lower history, publishing at CURRENT fixation time. Subsequent
    feed backlog is sorted by closed_at then larger timeframe on equal closes.
    """
    fixed, at = stamp(anchor.get("wave1_peak_known_at")), stamp(lock.get("event_at"))
    epoch = stamp(anchor.get("wave2_start_time"))
    if not fixed or not at or not epoch:
        return None
    future = []
    for kind in ("upper", "lower"):
        candidates = [bar for bar in index.after(kind, epoch, at) if reaches(bar, anchor, minimum)]
        historical = [bar for bar in candidates if bar["_known"] <= fixed]
        if historical:
            first = historical[0]
            return {"kind": kind, "bar_time": text_time(first["_time"]), "known_at": text_time(fixed),
                    "source_known_at": text_time(first["_known"]), "historical_classification": True}
        future += [(kind, bar) for bar in candidates if bar["_known"] > fixed]
    if not future:
        return None
    kind, first = min(future, key=lambda item: (item[1]["_known"], item[1]["_closed"], 0 if item[0] == "upper" else 1))
    return {"kind": kind, "bar_time": text_time(first["_time"]), "known_at": text_time(first["_known"]),
            "source_known_at": text_time(first["_known"]), "historical_classification": False}


def audit_run(run: dict, checks: Checks, arm: str, enabled: bool) -> dict:
    missing = sorted(REVISION_FIELDS-run["fields"])
    checks.check(not missing, "all_revision_snapshot_fields_present", arm=arm, missing=missing)
    sources = validate_sources(run, checks, arm)
    index = BarIndex(run)
    minimum, maximum = dec(run["config"].get("fib_min", ".382")), dec(run["config"].get("fib_max", ".618"))
    extensions, locks, incomplete = [], [], False
    for setup_id, rows in run["groups"].items():
        original = next((row for row in rows if row["event_type"] == "WAVE1_BREAK"), None)
        if original is None:
            continue
        last_revision, active_anchor, pending, locked_revision = 0, None, None, set()
        terminated, signaled = False, False
        previous_row = None
        initial_count = 0
        for row in rows:
            kind, rev, at = row["event_type"], revision(row), stamp(row["event_at"])
            ctx = {"arm": arm, **reference(row)}
            if kind == "WAVE1_BREAK":
                continue
            checks.check(all(canonical(row.get(key, "")) == canonical(original.get(key, "")) for key in IDENTITY),
                         "setup_origin_and_candidate_identity_immutable", **ctx)
            checks.check(rev >= last_revision and rev <= last_revision+1,
                         "revision_monotone_by_one", previous_revision=last_revision, **ctx)
            if not enabled:
                checks.check(rev == 0 and kind not in EXTENSION_EVENTS,
                             "off_retains_fixed_anchor_and_emits_no_extension_events", **ctx)
            if kind in {INITIAL, CONFIRM}:
                initial_count += int(kind == INITIAL)
                checks.check((kind == INITIAL and rev == 0) or (kind == CONFIRM and rev > 0 and pending is not None),
                             "initial_and_extension_confirmation_distinct", **ctx)
                verify_pivot(row, index, run["config"], checks, arm)
                d, peak, origin = direction(row), dec(row["wave1_peak_price"]), dec(row["wave1_start_price"])
                span = d*(peak-origin)
                checks.check(span > 0 and abs(dec(row["fib_382_price"])-(peak-d*span*minimum)) <= EPS and
                             abs(dec(row["fib_618_price"])-(peak-d*span*maximum)) <= EPS and
                             stamp(row.get("wave2_start_time")) == stamp(row["wave1_peak_time"])+timedelta(seconds=seconds(row["upper_tf"]) or 0),
                             "every_fixed_revision_fib_math_and_epoch", **ctx)
                if kind == CONFIRM:
                    checks.check(not truth(row.get("wave1_extension_pending")) and row.get("wave1_extension_known_at") == row["event_at"] and
                                 row.get("wave1_extension_started_at") == pending.get("event_at") and
                                 direction(row)*(dec(row["wave1_peak_price"])-dec(row["wave1_previous_peak_price"])) > 0,
                                 "extension_confirmation_retains_revision_provenance", **ctx)
                active_anchor, pending = row, None
            if kind == PREVIOUS:
                checks.check(not signaled and not terminated and rev not in locked_revision and active_anchor is not None and
                             truth(row.get("wave1_peak_fixed")) is True and not truth(row.get("wave1_extension_locked")),
                             "old_snapshot_precedes_eligible_extension", **ctx)
                if active_anchor:
                    checks.check(row["wave1_peak_time"] == active_anchor["wave1_peak_time"] and
                                 row["wave1_peak_known_at"] == active_anchor["wave1_peak_known_at"] and
                                 dec(row["wave1_peak_price"]) == dec(active_anchor["wave1_peak_price"]),
                                 "old_snapshot_matches_current_fixed_revision", **ctx)
            if kind == START:
                old = previous_row
                checks.check(old is not None and old["event_type"] == PREVIOUS and old["event_at"] == row["event_at"] and
                             revision(old)+1 == rev and not signaled and not terminated and revision(old) not in locked_revision,
                             "start_has_immediate_old_anchor_snapshot", **ctx)
                checks.check(truth(row.get("wave1_extension_pending")) is True and truth(row.get("wave1_peak_fixed")) is False and
                             row.get("wave1_extension_started_at") == row["event_at"] and not truth(row.get("wave1_extension_locked")),
                             "start_pending_has_current_availability", **ctx)
                checks.check(all(dec(row.get(key)) == 0 for key in ZERO_PRICES) and
                             all(not row.get(key) for key in ZERO_TIMES+ZERO_TEXT),
                             "start_clears_prior_fib_w2_lower_risk_and_obstacles", **ctx,
                             nonzero_prices=[key for key in ZERO_PRICES if dec(row.get(key)) != 0],
                             nonempty=[key for key in ZERO_TIMES+ZERO_TEXT if row.get(key)])
                if old:
                    checks.check(row.get("wave1_previous_peak_time") == old.get("wave1_peak_time") and
                                 row.get("wave1_previous_peak_known_at") == old.get("wave1_peak_known_at") and
                                 dec(row.get("wave1_previous_peak_price")) == dec(old.get("wave1_peak_price")),
                                 "previous_anchor_provenance_preserved", **ctx)
                    evidence = source_eligibility(old, row, index, minimum, checks, arm)
                    extensions.append(evidence)
                    incomplete |= evidence["status"] != "VERIFIED"
                pending, active_anchor = row, None
            if kind == TRACK:
                checks.check(pending is not None and truth(row.get("wave1_extension_pending")) is True and
                             truth(row.get("wave1_peak_fixed")) is False,
                             "tracking_never_claims_unconfirmed_endpoint", **ctx)
            if kind == LOCK:
                checks.check(enabled and active_anchor is not None and rev not in locked_revision and not signaled and not terminated,
                             "minimum_fib_locks_one_time_per_fixed_revision", **ctx)
                checks.check(truth(row.get("wave1_extension_locked")) is True and row.get("wave1_extension_lock_known_at") == row["event_at"],
                             "lock_records_current_knowledge", **ctx)
                locked_revision.add(rev)
                source_time = stamp(row.get("wave1_extension_lock_bar_time"))
                candidates = [(kind_, index.by_time[kind_].get(source_time)) for kind_ in ("upper", "lower")]
                candidates = [(kind_, bar) for kind_, bar in candidates if bar and bar["_known"] <= at and reaches(bar, row, minimum)]
                expected = first_lock_source(active_anchor, row, index, minimum) if active_anchor else None
                if index.bars["upper"] and index.bars["lower"]:
                    checks.check(bool(candidates), "lock_has_independent_min_fib_source", **ctx)
                    checks.check(expected is not None and expected["bar_time"] == row.get("wave1_extension_lock_bar_time") and
                                 expected["known_at"] == row["event_at"],
                                 "lock_is_first_qualifying_source_at_current_known_time", expected=expected, **ctx)
                if row.get("wave1_extension_lock_reason") == "AMBIGUOUS_EXTREME_AND_FIB_TOUCH":
                    if index.bars["upper"]:
                        checks.check(any(kind_ == "upper" and direction(row)*(dec(bar["high" if direction(row) > 0 else "low"])-dec(row["wave1_peak_price"])) > 0
                                         for kind_, bar in candidates), "ambiguous_lock_has_both_extremes_in_upper_ohlc", **ctx)
                locks.append({**reference(row), "source_candidates": [kind_ for kind_, _ in candidates], "first_source": expected})
            if active_anchor and kind in {"WAVE2_EXTREME", "LOWER_STRUCTURE_CONFIRMED", "SIGNAL"}:
                epoch, known = stamp(active_anchor.get("wave2_start_time")), stamp(active_anchor.get("wave1_peak_known_at"))
                extreme = stamp(row.get("wave2_extreme_time"))
                checks.check(extreme is not None and epoch is not None and extreme >= epoch and at >= known,
                             "new_w2_observation_belongs_to_current_revision", **ctx)
                if kind == "SIGNAL":
                    trigger_bar = stamp(row.get("trigger_bar_time"))
                    line_known = stamp(row.get("trigger_known_at"))
                    checks.check(trigger_bar is not None and trigger_bar >= known and line_known is not None and line_known <= trigger_bar,
                                 "new_signal_uses_known_new_anchor_and_trigger", **ctx)
            if kind == "FIB_TOUCH":
                # Separate exact-band event is a terminal extension condition,
                # even though lock classification also handles gap-through bars.
                locked_revision.add(rev)
            if kind == "SIGNAL":
                signaled = True
            if kind in {"INVALIDATE", "COMPLETED", "TEST_END"}:
                terminated = True
            checks.check(not (truth(row.get("wave1_extension_pending")) and kind in {"SIGNAL", "ORDER", "FILL"}),
                         "pending_endpoint_cannot_emit_or_execute_signal", **ctx)
            last_revision, previous_row = rev, row
        checks.check(initial_count <= 1, "one_original_opposite_wave_source_per_setup", arm=arm, setup_id=setup_id, count=initial_count)
    armed = []
    for row in run["rows"]:
        if row["event_type"] != ARM:
            continue
        origin_rows = run["groups"].get(row.get("opposite_setup_id"), [])
        matching = [event for event in origin_rows if event["event_type"] == INITIAL and
                    event["event_at"] == row.get("opposite_wave_known_at") == row["event_at"] and event["_csv_row"] < row["_csv_row"]]
        checks.check(len(matching) == 1 and matching[0].get("direction") != row.get("direction"),
                     "opposite_exit_arms_only_on_original_wave_confirmation", arm=arm, **reference(row))
        armed.append(reference(row))
    counts = Counter(row["event_type"] for row in run["rows"])
    realized = [dec(row["realized_r"]) for row in run["rows"] if row["event_type"] == "EXIT"]
    return {"path": run["path"], "sources": run["sources"], "event_counts": dict(sorted(counts.items())),
            "candidates": counts["WAVE1_BREAK"], "source_ohlc": sources,
            "extension_source_checks": extensions, "minimum_fib_locks": locks,
            "opposite_exit_arms": armed, "ancillary_realized_r": {
                "closed_count": len(realized), "total": float(sum(realized, D0)),
                "mean": float(sum(realized, D0)/len(realized)) if realized else None},
            "independent_sources_complete": bool(index.bars["upper"] and index.bars["lower"]) and not incomplete}


def classify_forced_test_end(run: dict, native_checks, exit_audit, arm: str) -> tuple[dict, list[dict]]:
    """Recognize only a provable final native forced close absent from EA EXIT.

    Do not manufacture an EXIT or turn its profit into normal strategy outcome.
    Preserve the raw native pair and money/R separately; retain INCOMPLETE for
    the censored ledger boundary. Any unsupported/mismatching case continues
    through the ordinary report checker and remains a failure.
    """
    deals = run["deals"]
    if len(deals) < 2:
        return run, []
    entered, closed = deals[-2:]
    if not (entered["entry"] == "in" and closed["entry"] == "out" and
            closed.get("comment", "").strip().lower() == "end of test" and
            entered["symbol"] == closed["symbol"] and entered["type"] != closed["type"] and
            entered["volume"] == closed["volume"] and entered["volume"] is not None and entered["volume"] > 0):
        return run, []
    matching = []
    for setup_id, history in run["groups"].items():
        fills = [row for row in history if row["event_type"] == "FILL"]
        ends = [row for row in history if row["event_type"] == "TEST_END"]
        if (len(fills) == 1 and len(ends) == 1 and not any(row["event_type"] == "EXIT" for row in history) and
                fills[0].get("fill_at") == entered["time"] and ends[0].get("event_at") == closed["time"] and
                fills[0].get("direction") == ("LONG" if entered["type"] == "buy" else "SHORT") and
                fills[0].get("execution_position_id") == entered["order"]):
            matching.append((setup_id, fills[0], ends[0]))
    if len(matching) != 1:
        return run, []
    setup_id, fill, end = matching[0]
    native_checks.check(all(deal.get(key) is not None for deal in (entered, closed)
                            for key in ("volume", "price", "commission", "swap", "profit")),
                        "test_end_forced_deals_numeric", arm=arm, setup_id=setup_id)
    if any(deal.get(key) is None for deal in (entered, closed) for key in ("volume", "price", "commission", "swap", "profit")):
        return run, []
    net = sum((deal["commission"]+deal["swap"]+deal["profit"] for deal in (entered, closed)), D0)
    risk = exit_audit.dec(fill.get("execution_initial_risk_money"))
    contract = exit_audit.dec(run["config"].get("contract_size"))
    entry, sl = exit_audit.dec(fill.get("entry_price")), exit_audit.dec(fill.get("sl_price"))
    native_checks.check(entry is not None and abs(entry-entered["price"]) <= exit_audit.MONEY_EPS,
                        "test_end_forced_native_fill_matches_ledger", arm=arm, setup_id=setup_id)
    native_checks.check(risk is not None and risk > 0, "test_end_original_money_risk_recorded", arm=arm, setup_id=setup_id)
    independent_risk = None
    if run["currency"] == "USD" and entered["symbol"].startswith("XAUUSD") and contract and sl is not None:
        independent_risk = abs(entered["price"]-sl)*entered["volume"]*contract
        native_checks.check(independent_risk > 0 and risk is not None and abs(risk-independent_risk) <= exit_audit.MONEY_EPS,
                            "test_end_forced_original_risk_independently_reconciled", arm=arm, setup_id=setup_id)
    native_checks.missing("censored_test_end_native_forced_close_has_no_ea_exit", run=arm,
                          setup_id=setup_id, at=closed["time"], native_out_deal=closed["deal"])
    detail = {"setup_id": setup_id, "direction": fill["direction"], "fill_at": fill["fill_at"],
              "test_end_at": end["event_at"], "ledger_exit": None, "native_forced_close_deal": closed["deal"],
              "native_forced_close_order": closed["order"], "native_comment": closed["comment"],
              "native_price": str(closed["price"]), "native_net_cash": float(net),
              "original_money_risk": float(risk) if risk else None,
              "native_forced_r_auxiliary": float(net/independent_risk) if independent_risk else None,
              "included_in_normal_closed_strategy_r": False,
              "native_deals": [{key: str(value) for key, value in deal.items()} for deal in (entered, closed)]}
    report_scope = dict(run, deals=deals[:-2])
    return report_scope, [detail]


def audit_retained_exits(paths: dict[str, Path], checks: Checks) -> dict:
    """Reuse the established exit checks, without its different-target A/B gate.

    The exit feature is enabled in BOTH extension arms. Its existing OFF/ON
    comparator would incorrectly require an exit-policy difference, so only
    actual per-run source/latch/ticks/orders/native-deal checks are invoked.
    """
    import audit_opposite_exit as exit_audit

    result = {}
    for arm, path in paths.items():
        native_checks = exit_audit.Checks()
        run = exit_audit.load_run(path, native_checks, arm)
        native_checks.check(exit_audit.flag(run["config"].get("exit_on_opposite_wave1")),
                            "retained_opposite_exit_enabled", arm=arm)
        native_checks.check(exit_audit.flag(run["config"].get("tester")) and
                            exit_audit.flag(run["config"].get("tester_orders")),
                            "retained_exit_tester_guard", arm=arm)
        native_checks.check(exit_audit.flag(run["config"].get("audit_opposite_exit_ticks")),
                            "retained_exit_received_tick_audit_enabled", arm=arm)
        armed = exit_audit.source_and_latch(run, native_checks)
        ticks = exit_audit.check_ticks(run, armed, native_checks)
        exit_audit.check_orders(run, native_checks)
        report_scope, censored = classify_forced_test_end(run, native_checks, exit_audit, arm)
        cash = exit_audit.check_report(report_scope, native_checks, arm)
        status = "FAIL" if native_checks.failures else "INCOMPLETE" if native_checks.incomplete else "PASS"
        checks.counts["retained_exit_policy_checks"] += native_checks.count
        for failure in native_checks.failures:
            checks.violations.append({"rule": "retained_exit_"+failure["code"], "arm": arm,
                                      "detail": failure})
        result[arm] = {"status": status, "check_count": native_checks.count,
                       "failures": native_checks.failures, "incomplete": native_checks.incomplete,
                       "armed_cases": ticks, "native_cash_reconciliation": cash,
                       "censored_test_end_positions": censored,
                       "native_metrics": exit_audit.metrics(cash), "source_hashes": run["hashes"]}
    return {"status": "FAIL" if any(run["status"] == "FAIL" for run in result.values()) else
            "INCOMPLETE" if any(run["status"] == "INCOMPLETE" for run in result.values()) else "PASS",
            "runs": result,
            "limitations": [
                "The retained exit feature stays ON in both extension arms; its different-target OFF/ON configuration comparator is intentionally not called.",
                "Native reports expose commission/swap/profit; any separate DEAL_FEE requires separate reconciliation.",
                "Received-tick arithmetic is checked; external feed completeness and positive actual cash after estimated-cost requests are not guaranteed.",
                "A native final 'end of test' close matched to FILL plus TEST_END but no EA EXIT is preserved separately and makes this exit section INCOMPLETE; it is never relabeled as normal strategy EXIT.",
            ]}


def audit(off_path: Path, on_path: Path, audit_exits: bool = False) -> tuple[dict, list[dict]]:
    off, on, checks = load(off_path), load(on_path), Checks()
    config = compare_config(off, on, checks)
    summaries = {arm: audit_run(run, checks, arm, arm == "on") for arm, run in (("off", off), ("on", on))}
    mapping = {}
    for arm, run in (("off", off), ("on", on)):
        mapping[arm] = {identity(row): row for row in run["rows"] if row["event_type"] == "WAVE1_BREAK"}
    comparisons = []
    for key in sorted(mapping["off"].keys() | mapping["on"].keys()):
        a, b = mapping["off"].get(key), mapping["on"].get(key)
        row = {"off_setup_id": a.get("setup_id", "") if a else "", "on_setup_id": b.get("setup_id", "") if b else "",
               "direction": (a or b)["direction"], "candidate_detected_at": (a or b)["candidate_detected_at"],
               "wave1_start_time": (a or b)["wave1_start_time"], "wave1_start_price": (a or b)["wave1_start_price"],
               "coverage": "BOTH" if a and b else "OFF_ONLY" if a else "ON_ONLY"}
        for arm, match, run in (("off", a, off), ("on", b, on)):
            rows = run["groups"].get(match["setup_id"], []) if match else []
            counts = Counter(event["event_type"] for event in rows)
            row[f"{arm}_extensions"] = counts[START]
            for event in ("SIGNAL", "FILL", "EXIT", "INVALIDATE", "SKIP"):
                row[f"{arm}_{event.lower()}"] = counts[event]
        comparisons.append(row)
    extension_checks = sum(checks.counts.values())
    extension_violations = len(checks.violations)
    independent_complete = all(summary["independent_sources_complete"] for summary in summaries.values()) and config["period_metadata_complete"]
    retained_exits = audit_retained_exits({"off": off_path, "on": on_path}, checks) if audit_exits else None
    complete = all(summary["independent_sources_complete"] for summary in summaries.values()) and config["period_metadata_complete"]
    if retained_exits:
        complete = complete and retained_exits["status"] == "PASS"
    status = "FAIL" if checks.violations else "PASS" if complete else "INCOMPLETE"
    result = {"status": status, "passed": status == "PASS", "check_count": sum(checks.counts.values()),
              "checks_by_rule": dict(sorted(checks.counts.items())), "violations": checks.violations,
              "config_comparison": config, "runs": summaries,
              "extension_integrity": {"status": "FAIL" if extension_violations else "PASS" if independent_complete else "INCOMPLETE",
                                      "check_count": extension_checks, "violations": extension_violations},
              "retained_exit_policy": retained_exits if retained_exits else {"status": "NOT_REQUESTED"},
              "candidate_coverage": dict(Counter(row["coverage"] for row in comparisons)),
              "limitations": [
                  "Accepted upper/lower sidecars are independently logged OHLC observations, not a broker-history completeness proof.",
                  "Missing raw source sidecars or requested-period metadata produces INCOMPLETE rather than an inferred PASS.",
                  "A source interval gap is listed without classifying market closure versus missing data.",
                  "Equal-availability upper bars are evaluated before lower bars; ambiguous upper OHLC freezes extension without guessing intrabar order.",
                  "Candidate accounting includes OFF_ONLY and ON_ONLY because longer setup lifetimes can change later discovery opportunities.",
                  "Original setup identity and per-revision anchors are audited; no profit-based example selection or parameter search occurs.",
                  "Realized R is auxiliary native ledger data; this audit does not independently reconstruct fees, fills or broker execution.",
              ]}
    return result, comparisons


def markdown(result: dict) -> str:
    lines = ["# Wave33 条件付き第1波延長 OFF/ON監査", "", f"状態: **{result['status']}**。目視比較用の工学検証。", "",
             "|設定|候補|延長開始|延長確定|延長禁止|SIGNAL|FILL|EXIT|決済R合計|平均R|",
             "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for arm in ("off", "on"):
        run, counts = result["runs"][arm], result["runs"][arm]["event_counts"]
        values = [arm, run["candidates"], counts.get(START, 0), counts.get(CONFIRM, 0), counts.get(LOCK, 0),
                  counts.get("SIGNAL", 0), counts.get("FILL", 0), counts.get("EXIT", 0),
                  round(run["ancillary_realized_r"]["total"], 6), run["ancillary_realized_r"]["mean"]]
        lines.append("|"+"|".join(str(value) if value is not None else "—" for value in values)+"|")
    lines += ["", f"{result['check_count']}チェック、違反{len(result['violations'])}件。候補対応: {result['candidate_coverage']}。", "",
              "延長前の固定アンカーを保存し、同じID・始点で新しい終点の右側確定足を待つ。既知の38.2%到達、同一上位足の高安順序不明、シグナル成立後は延長しない。", "",
              "原本OHLC、全候補差分、設定差、既知時刻、制約: [extension_audit.json](extension_audit.json) / [candidate_comparison.csv](candidate_comparison.csv)。", "",
              "損益は補助集計であり、利益改善・動画との一致・本番採用を意味しない。", ""]
    exits = result.get("retained_exit_policy", {})
    if exits.get("runs"):
        lines += ["逆①プラス決済の維持監査: **"+exits["status"]+"**。両設定とも同じ決済機能を有効にしたまま、実約定後の待機・各受信ティックの費用計算と利益条件・重複決済防止・MT5取引明細の現金損益とRを照合する。", ""]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--off", type=Path, required=True)
    parser.add_argument("--on", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--audit-exits", action="store_true",
                        help="Also reconcile retained opposite-wave exit source, ticks, orders and native report cash in BOTH arms")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    try:
        result, comparison = audit(args.off, args.on, args.audit_exits)
    except (OSError, ValueError, KeyError, TypeError, csv.Error) as error:
        result = {"status": "FAIL", "passed": False, "input_error": str(error)}
        (args.out / "extension_audit.json").write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
        return 1
    (args.out / "extension_audit.json").write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    (args.out / "README.md").write_text(markdown(result), encoding="utf-8")
    with (args.out / "candidate_comparison.csv").open("w", encoding="utf-8-sig", newline="") as stream:
        fields = list(comparison[0]) if comparison else ["off_setup_id", "on_setup_id", "coverage"]
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader(); writer.writerows(comparison)
    print(json.dumps({key: result[key] for key in ("status", "passed", "check_count")}, ensure_ascii=False))
    return 0 if result["passed"] else 2 if result["status"] == "INCOMPLETE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
