"""Fixed, causal resistance-position diagnosis of the existing annual Wave33 run.

No EA changes, parameter search, hypothetical entry deletion, or new tester run.
Definitions: knowledge/experiments/2026-10-23-wave33-pattern-review-plan.md.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
from datetime import datetime, timedelta
import hashlib
import json
from pathlib import Path
import statistics


def read(path, delimiter=";"):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        yield from csv.DictReader(handle, delimiter=delimiter)


def number(row, key):
    return float(row.get(key) or 0)


def stamp(value):
    return datetime.fromisoformat(value.replace(".", "-"))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dump(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def csv_save(path, items):
    if not items:
        return
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(items[0]))
        writer.writeheader()
        writer.writerows(items)


def metrics(items):
    values = [item["net_r"] for item in items]
    wins = [value for value in values if value > 0]
    losses = [value for value in values if value < 0]
    return {"n": len(values), "wins": len(wins), "losses": len(losses),
            "win_rate": len(wins) / len(values) if values else None,
            "sum_r": sum(values), "mean_r": statistics.mean(values) if values else None,
            "pf_r": sum(wins) / -sum(losses) if losses else None,
            "net_cash": sum(item["net_cash"] for item in items)}


def process(run, arm, source_trades):
    config = {row["parameter"]: row["value"] for row in read(run / "config.csv")}
    point = float(config["point"])
    tolerance = point / 2
    bars = list(read(run / "upper_bars.csv"))
    bar_index = 0
    active = {}
    identified = {}
    trades_by_id = {item["setup_id"]: item for item in source_trades if item["arm"] == arm}
    exits = {}
    enriched = []
    audit = Counter()
    for sequence, row in enumerate(read(run / "events.csv")):
        if row["event_type"] == "EXIT":
            exits[row["setup_id"]] = row
        if row["event_type"] not in {"ORDER", "PIVOT_CONFIRMED"}:
            continue
        event_time = stamp(row["event_at"])
        # Only closed upper bars whose availability was recorded by this time.
        while bar_index < len(bars) and stamp(bars[bar_index]["known_at"]) <= event_time:
            close = float(bars[bar_index]["close"])
            spent = [key for key, pivot in active.items()
                     if (pivot["high"] and close > pivot["price"] + tolerance)
                     or (not pivot["high"] and close < pivot["price"] - tolerance)]
            for key in spent:
                del active[key]
            audit["known_upper_bars_processed"] += 1
            bar_index += 1
        if row["event_type"] == "PIVOT_CONFIRMED":
            if row["observed_pivot_tf"] not in {"PERIOD_M15", "PERIOD_H1"}:
                continue
            label = row["observed_pivot_label"]
            if label not in {"H", "HH", "LH", "L", "HL", "LL"}:
                raise ValueError("Unrecognized pivot side")
            known = stamp(row["observed_pivot_known_at"])
            if known > event_time:
                raise ValueError("Future pivot in recorded known-time event")
            key = (row["observed_pivot_tf"], row["observed_pivot_time"], label in {"H", "HH", "LH"})
            pivot = {"tf": key[0], "time": row["observed_pivot_time"], "known_at": row["observed_pivot_known_at"],
                     "known_sequence": sequence, "price": number(row, "observed_pivot_price"), "high": key[2]}
            active[key] = pivot
            identified[key] = pivot
            continue
        if row["setup_id"] not in trades_by_id:
            audit["order_without_completed_trade"] += 1
            continue
        item = dict(trades_by_id[row["setup_id"]])
        direction = 1 if row["direction"] == "LONG" else -1
        entry, sl, tp = (number(row, key) for key in ("entry_price", "sl_price", "tp_price"))
        risk = abs(entry - sl)
        if risk <= 0:
            raise ValueError("Nonpositive order risk")
        peak, origin = number(row, "wave1_peak_price"), row["wave1_start_time"]
        room = direction * (peak - entry) / risk
        room_band = "0.25_TO_0.5" if room < 0.5 else ("0.5_TO_1" if room < 1 else "GE_1")
        candidates = [pivot for pivot in active.values()
                      if pivot["high"] == (direction > 0)
                      and stamp(pivot["time"]) + timedelta(minutes=15 if pivot["tf"] == "PERIOD_M15" else 60) <= stamp(origin)
                      and direction * (pivot["price"] - entry) > tolerance]
        outside = sorted((pivot for pivot in candidates if direction * (pivot["price"] - peak) > tolerance),
                         key=lambda pivot: direction * (pivot["price"] - peak))
        nearest = outside[0] if outside else None
        near_peak = sorted((pivot for pivot in candidates if abs(pivot["price"] - peak) / risk <= 0.1 + 1e-10),
                           key=lambda pivot: abs(pivot["price"] - peak))
        nearby = near_peak[0] if near_peak else None
        blocked = bool(nearest and direction * (tp - nearest["price"]) > tolerance)
        for pivot in candidates:
            if pivot["known_sequence"] >= sequence or stamp(pivot["known_at"]) > event_time:
                raise ValueError("Entry used future pivot")
        item.update(order_at=row["event_at"], order_sequence=sequence, order_entry_price=entry,
                    order_risk_price=risk, wave1_start_time=origin, wave1_start_price=number(row, "wave1_start_price"),
                    wave1_peak_time=row["wave1_peak_time"], wave1_peak_price=peak,
                    wave1_peak_known_at=row["wave1_peak_known_at"], order_room_r=room, order_room_band=room_band,
                    tp_relative_to_w1="TP_BEYOND_W1" if direction * (tp - peak) > tolerance else "TP_BEFORE_OR_AT_W1",
                    external_tp_blocked="BLOCKED" if blocked else "NO_OBSERVED_BLOCK",
                    external_price=nearest["price"] if nearest else None,
                    external_tf=nearest["tf"] if nearest else None,
                    external_source_at=nearest["time"] if nearest else None,
                    external_known_at=nearest["known_at"] if nearest else None,
                    external_distance_r=direction * (nearest["price"] - entry) / risk if nearest else None,
                    near_wave1="NEAR_0.1R" if nearby else "NO_OBSERVED_NEAR",
                    near_wave1_price=nearby["price"] if nearby else None,
                    near_wave1_tf=nearby["tf"] if nearby else None,
                    near_wave1_source_at=nearby["time"] if nearby else None,
                    near_wave1_known_at=nearby["known_at"] if nearby else None,
                    available_external_pivots=len(candidates), known_context_bars=bar_index)
        enriched.append(item)
        audit["orders_joined"] += 1
    if len(enriched) != len(trades_by_id):
        raise ValueError("Lost completed trade in order join")
    for item in enriched:
        close = exits[item["setup_id"]]
        if abs(number(close, "execution_net_cash") - item["net_cash"]) > 1e-6:
            raise ValueError("Trade cash mismatch")
        if abs(number(close, "realized_r") - item["net_r"]) > 1e-6:
            raise ValueError("Trade R mismatch")
        audit["cash_and_r_checks"] += 2
    return enriched, dict(audit)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("reports/backtest/runs/wave33_v170_2020"))
    parser.add_argument("--out", type=Path, default=Path("reports/backtest/runs/wave33_v170_2020/pattern_review_20261023/resistance"))
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    definitions = {"scope": "Known ORDER information, completed original positions; descriptive only",
                   "features_fixed_before_analysis": ["0.25_TO_0.5/0.5_TO_1/GE_1 W1 room", "TP beyond nearest prior outside-W1 M15/H1 pivot", "Prior pivot within +/-0.1 initial risk of W1"],
                   "external_level": "Confirmed M15/H1 same-side pivot, entire source bar closed at/before current W1 origin; beyond executable entry. Current W1 never counted as external.",
                   "definition_repair": "A higher-TF pivot source bar can open before W1 origin but contain part of W1. Require source_time + PeriodSeconds(tf) <= W1 origin. Initial bar-start-only outputs retained in resistance_initial_barstart; no threshold sweep or outcome-based selection.",
                   "spent_policy": "Remove after an observed upper-TF close strictly crosses by more than half a point. A uses M15 closes, B uses M5 closes. Diagnostic assumption, not a video rule.",
                   "causality": "Pivot event sequence strictly before ORDER; pivot known_at and closed bar known_at <= ORDER event time",
                   "limitations": ["Known registry starts with native prospective warmup, not all older market levels", "Near band is fixed 0.1R, no sweep", "All 2020 is already observed, splits are not OOS", "Dense or unbroken levels do not prove human importance", "A and B overlap the same underlying market; they are not independent replications"],
                   "run_manifest_sha256": digest(args.root / "analysis/streak_summary.json")}
    dump(args.out / "definitions.json", definitions)
    native = args.root / "20261022_161002_0ef87d9b"
    trades = list(read(args.root / "analysis/trades.csv", ","))
    for item in trades:
        for key in ("net_r", "net_cash", "risk_cash"):
            item[key] = float(item[key])
    results, audit = [], {}
    hashes = {}
    for arm, name in (("A", "a_extension_on"), ("B", "b_extension_on")):
        items, audit[arm] = process(native / name, arm, trades)
        results.extend(items)
        for file in ("events.csv", "upper_bars.csv", "config.csv"):
            hashes[arm + "/" + file] = digest(native / name / file)
    csv_save(args.out / "trades.csv", results)
    grouped = []
    for arm in ("A", "B"):
        arm_items = [item for item in results if item["arm"] == arm]
        for feature in ("order_room_band", "tp_relative_to_w1", "external_tp_blocked", "near_wave1"):
            for value in sorted({item[feature] for item in arm_items}):
                for period in ("ALL", "2020H1", "2020H2"):
                    items = [item for item in arm_items if item[feature] == value and
                             (period == "ALL" or (item["entry_at"] < "2020-07-01") == (period == "2020H1"))]
                    grouped.append({"arm": arm, "feature": feature, "value": value, "period": period, **metrics(items)})
    csv_save(args.out / "groups.csv", grouped)
    case_items = []
    for arm in ("A", "B"):
        for outcome in ("WIN", "LOSS"):
            candidates = [item for item in results if item["arm"] == arm and item["outcome"] == outcome and item["order_room_band"] == "0.25_TO_0.5"]
            if candidates:
                case_items.append(min(candidates, key=lambda item: (abs((stamp(item["entry_at"]) - datetime(2020, 7, 1)).total_seconds()), item["setup_id"])))
            for feature, value in (("external_tp_blocked", "BLOCKED"), ("near_wave1", "NEAR_0.1R")):
                candidates = [item for item in results if item["arm"] == arm and item["outcome"] == outcome and item[feature] == value and item["setup_id"] not in {case["setup_id"] for case in case_items}]
                if candidates:
                    case_items.append(min(candidates, key=lambda item: (abs((stamp(item["entry_at"]) - datetime(2020, 7, 1)).total_seconds()), item["setup_id"])))
    csv_save(args.out / "cases.csv", case_items)
    dump(args.out / "summary.json", {"status": "PASS", "trades": len(results), "audits": audit,
                                     "source_sha256": hashes, "groups": grouped,
                                     "case_selection": "For each arm and outcome, closest entry to July 1 within fixed mechanism groups, no duplicate; not chosen by profit magnitude",
                                     "case_count": len(case_items), "ea_changed": False, "new_backtest": False})
    for group in grouped:
        if group["period"] == "ALL":
            print(json.dumps(group, ensure_ascii=False))


if __name__ == "__main__":
    main()
