"""Freeze causal ORDER snapshots and a deterministic balanced blind chart sample.

No EA mutation, tester invocation, outcome-group report or threshold selection.
Outcomes live under data/labels only; the blind JSON is intentionally label-free.
"""
from __future__ import annotations

import argparse
from bisect import bisect_left, bisect_right
from collections import Counter, defaultdict
import csv
from datetime import datetime, timedelta
import hashlib
import json
import math
from pathlib import Path
import random
from statistics import median


STRATA = {
    ("A", "LONG", "WIN"): 8, ("A", "SHORT", "WIN"): 7,
    ("B", "LONG", "WIN"): 7, ("B", "SHORT", "WIN"): 8,
    ("A", "LONG", "LOSS"): 7, ("A", "SHORT", "LOSS"): 8,
    ("B", "LONG", "LOSS"): 8, ("B", "SHORT", "LOSS"): 7,
}
SEED = 20261023
SNAPSHOT_FIELDS = """
setup_id symbol upper_tf lower_tf direction candidate_detected_at
upper_break_level upper_break_confirmed_at upper_break_bar_time
upper_break_level_time upper_break_level_known_at wave1_start_time
wave1_start_price wave1_start_known_at wave1_peak_time wave1_peak_price
wave1_peak_known_at wave1_peak_fixed fib_382_price fib_618_price
wave2_extreme_time wave2_extreme_price wave2_extreme_known_at
retracement_ratio fib_touch_at fib_touch_known_at lower_structure_known_at
lower_entry_stage lower_recognition lower_unmet_reason lower_pivot_times
lower_pivot_prices trigger_type trigger_line_price trigger_known_at
signal_at signal_known_at trigger_bar_time order_sent_at entry_price
sl_price tp_price risk_points intended_rr actual_rr spread_points
nearest_obstacle_price nearest_obstacle_tf nearest_obstacle_time
nearest_obstacle_known_at nearest_obstacle_source nearest_obstacle_is_high
obstacle_distance_r h1_direction wave1_room_price wave1_room_r
candle_body_ratio candle_body_atr wave2_start_time lower_wave2_time
lower_wave2_price first_progress_bar_time first_progress_close_at
first_progress_known_at first_progress_price wave1_revision
wave1_extension_pending wave1_extension_started_at wave1_extension_known_at
wave1_previous_peak_time wave1_previous_peak_known_at wave1_previous_peak_price
wave1_extension_locked wave1_extension_lock_bar_time
wave1_extension_lock_known_at wave1_extension_lock_reason wave1_provisional_time
wave1_provisional_price tp_rr_price tp_wave1_target_price tp_wave1_buffer_points
tp_extended_to_wave1 tp_adjustment_reason
""".split()


def dt(value):
    return datetime.fromisoformat(value.replace(".", "-")) if value else None


def iso(value):
    return value.isoformat(" ") if isinstance(value, datetime) else value


def read(path, delimiter=";"):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        yield from csv.DictReader(handle, delimiter=delimiter)


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(2 ** 20), b""):
            h.update(chunk)
    return h.hexdigest()


def dump(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2,
                               allow_nan=False), encoding="utf-8")


def write_csv(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    keys = list(dict.fromkeys(k for row in rows for k in row))
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=keys)
        writer.writeheader()
        writer.writerows(rows)


def public_pivot(p):
    return {k: iso(v) for k, v in p.items()}


def normalize(pivots):
    """Causal extrema of consecutive same-side pivots, with ambiguity barriers.

    An outside bar with both H/L has unknowable intrabar order. Drop both and
    reset the path; never draw an invented H->L or L->H through that bar.
    """
    normalized = []
    ambiguity_count = 0
    for p in pivots:
        if p["ambiguous_same_time"]:
            normalized = []
            ambiguity_count += 1
            continue
        if normalized and normalized[-1]["is_high"] == p["is_high"]:
            prior = normalized[-1]
            if (p["price"] > prior["price"]) == p["is_high"] and p["price"] != prior["price"]:
                normalized[-1] = p
        else:
            normalized.append(p)
    return normalized, ambiguity_count


def load_bars(path):
    bars = []
    for row_number, row in enumerate(read(path), 2):
        bars.append(dict(time=dt(row["bar_time"]), closed_at=dt(row["closed_at"]),
                         known_at=dt(row["known_at"]), source_row=row_number,
                         **{k: float(row[k]) for k in ("open", "high", "low", "close")}))
    assert all(a["time"] < b["time"] for a, b in zip(bars, bars[1:])), path
    assert all(a["known_at"] <= b["known_at"] for a, b in zip(bars, bars[1:])), path
    return bars


def load_events(path, wanted):
    orders, candidates, pivots = {}, {}, defaultdict(list)
    for sequence, row in enumerate(read(path)):
        event = row["event_type"]
        if event == "PIVOT_CONFIRMED":
            pivots[row["observed_pivot_tf"]].append(dict(
                time=dt(row["observed_pivot_time"]),
                known_at=dt(row["observed_pivot_known_at"]),
                price=float(row["observed_pivot_price"]),
                is_high=row["observed_pivot_label"] in ("H", "HH", "LH"),
                label=row["observed_pivot_label"], event_sequence=sequence,
                ambiguous_same_time=False))
        if row["setup_id"] in wanted:
            if event == "WAVE1_BREAK":
                assert row["setup_id"] not in candidates
                candidates[row["setup_id"]] = dict(row, _sequence=sequence)
            elif event == "ORDER":
                assert row["setup_id"] not in orders
                orders[row["setup_id"]] = dict(row, _sequence=sequence)
    for group in pivots.values():
        counts = Counter(p["time"] for p in group)
        for p in group:
            p["ambiguous_same_time"] = counts[p["time"]] > 1
        assert all(a["time"] <= b["time"] for a, b in zip(group, group[1:]))
    return orders, candidates, pivots


def asof_bars(bars, times, known_by, close_by):
    stop = bisect_right(times, known_by)
    # The CSV has no cross-file global event sequence. close_by is the lower
    # trigger close, not wall-clock now: later closed bars in a delayed FeedClosed
    # batch may share known_at but are processed only after this ORDER.
    return [b for b in bars[:stop] if b["closed_at"] <= close_by]


def feature_row(order, candidate, upper, upper_pivots, point):
    sign = 1 if order["direction"] == "LONG" else -1
    origin, peak = dt(order["wave1_start_time"]), dt(order["wave1_peak_time"])
    candidate_at = dt(candidate["event_at"])
    pre_cutoff = dt(order["upper_break_bar_time"])
    span = abs(float(order["wave1_peak_price"]) - float(order["wave1_start_price"]))
    raw_pre = [p for p in upper_pivots if p["time"] < origin
               and p["known_at"] <= pre_cutoff
               and p["event_sequence"] < candidate["_sequence"]]
    normalized, ambiguous = normalize(raw_pre)
    pre = normalized[-8:]
    complete = len(pre) == 8
    missing = []
    out = dict(order_at=iso(dt(order["event_at"])), order_sequence=order["_sequence"],
               candidate_at=iso(candidate_at), candidate_sequence=candidate["_sequence"],
               pre_cutoff_at=iso(pre_cutoff),
               wave1_range=span, pre_pivot_count=len(pre),
               pre_ambiguous_raw_pivots=ambiguous,
               pre_pivots_complete8=complete,
               wave1_range_over_preleg_median=None,
               preorigin_tr_mean14=None, wave1_range_over_preorigin_tr14=None,
               wave1_signed_close_efficiency=None,
               pre_countertrend_agreement=None,
               wave1_breaks_pre8_outer_close=None,
               wave1_outer_close_margin_ratio=None)
    if complete:
        leg_median = median(abs(b["price"] - a["price"]) for a, b in zip(pre, pre[1:]))
        if leg_median > 0:
            out["wave1_range_over_preleg_median"] = span / leg_median
        else:
            missing.append("ZERO_PRELEG_MEDIAN")
        highs = [p["price"] for p in pre if p["is_high"]]
        lows = [p["price"] for p in pre if not p["is_high"]]
        assert len(highs) == len(lows) == 4
        diffs = [b-a for series in (highs, lows) for a, b in zip(series, series[1:])]
        # LONG W1 expects a preceding falling trend; SHORT expects rising.
        out["pre_countertrend_agreement"] = sum(-sign * d > 0 for d in diffs) / 6
    else:
        missing.append("PRE8_INCOMPLETE_OR_AMBIGUITY_BARRIER")
    pre_bars = [b for b in upper if b["closed_at"] <= origin and b["known_at"] <= pre_cutoff]
    if len(pre_bars) >= 15:
        recent = pre_bars[-15:]
        trs = [max(b["high"] - b["low"], abs(b["high"] - a["close"]),
                   abs(b["low"] - a["close"])) for a, b in zip(recent, recent[1:])]
        tr = sum(trs) / 14
        out["preorigin_tr_mean14"] = tr
        if tr > 0:
            out["wave1_range_over_preorigin_tr14"] = span / tr
        else:
            missing.append("ZERO_PREORIGIN_TR14")
    else:
        missing.append("PREORIGIN_15_BARS_UNAVAILABLE")
    w1 = [b for b in upper if origin <= b["time"] <= peak]
    if len(w1) >= 2:
        closes = [b["close"] for b in w1]
        path = sum(abs(b-a) for a, b in zip(closes, closes[1:]))
        if path > 0:
            out["wave1_signed_close_efficiency"] = sign * (closes[-1]-closes[0]) / path
        else:
            missing.append("ZERO_W1_CLOSE_PATH")
        if complete and span > 0:
            boundary = max(p["price"] for p in pre) if sign > 0 else min(p["price"] for p in pre)
            strongest = max(closes) if sign > 0 else min(closes)
            margin = sign * (strongest-boundary)
            out["wave1_breaks_pre8_outer_close"] = margin > point * .5
            out["wave1_outer_close_margin_ratio"] = margin / span
    else:
        missing.append("W1_FEWER_THAN_TWO_CLOSED_UPPER_BARS")
    out["feature_unavailable_reasons"] = "|".join(missing)
    out["wave1_upper_bar_count"] = len(w1)
    bins = {
        "wave1_range_over_preleg_median": (1, 2),
        "wave1_range_over_preorigin_tr14": (2, 4),
        "wave1_signed_close_efficiency": (.3, .6),
        "pre_countertrend_agreement": (2/3, 1),
    }
    for key, (low, high) in bins.items():
        value = out[key]
        out[key + "_bin"] = ("UNAVAILABLE" if value is None else
                              "LOW" if value < low else "MID" if value < high else "HIGH")
    return out, pre


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch", type=Path, default=Path("reports/backtest/runs/wave33_v180_2020/20261023_164915_831ff154"))
    parser.add_argument("--trades", type=Path, default=Path("reports/backtest/runs/wave33_v180_2020/analysis/trades.csv"))
    parser.add_argument("--out", type=Path, default=Path("reports/qa/w33entry60/data"))
    args = parser.parse_args()
    if (args.out / "manifest.json").exists():
        raise SystemExit("Refusing to overwrite a frozen data manifest. Choose a fresh output directory.")
    trades = list(read(args.trades, ","))
    assert len(trades) == 440 and len({(t["arm"], t["setup_id"]) for t in trades}) == 440
    selected = []
    strata_audit = []
    for (arm, direction, outcome), request in STRATA.items():
        pool = sorted((t for t in trades if (t["arm"], t["direction"], t["outcome"]) == (arm, direction, outcome)),
                      key=lambda t: (t["entry_at"], t["setup_id"]))
        count = min(request, len(pool))
        indices = [math.floor((i+.5)*len(pool)/count) for i in range(count)] if count else []
        selected.extend(pool[i] for i in indices)
        strata_audit.append(dict(arm=arm, direction=direction, outcome=outcome,
                                 available=len(pool), requested=request, selected=count,
                                 sorted_indices=indices))
    random.Random(SEED).shuffle(selected)
    blind_lookup = {(t["arm"], t["setup_id"]): f"V{i:03}" for i, t in enumerate(selected, 1)}
    inputs = {str(args.trades): digest(args.trades)}
    packets, features, label_key = [], [], []
    checks = Counter()
    for arm in ("A", "B"):
        run = args.batch / f"v180_{arm.lower()}_both"
        for name in ("events.csv", "upper_bars.csv", "lower_bars.csv", "config.csv", "inputs.set"):
            inputs[str(run / name)] = digest(run / name)
        arm_trades = [t for t in trades if t["arm"] == arm]
        wanted = {t["setup_id"] for t in arm_trades}
        orders, candidates, pivot_map = load_events(run / "events.csv", wanted)
        assert orders.keys() == candidates.keys() == wanted
        config = {r["parameter"]: r["value"] for r in read(run / "config.csv")}
        point = float(config["point"])
        upper, lower = load_bars(run / "upper_bars.csv"), load_bars(run / "lower_bars.csv")
        up_known, low_known = [b["known_at"] for b in upper], [b["known_at"] for b in lower]
        for trade in arm_trades:
            order, candidate = orders[trade["setup_id"]], candidates[trade["setup_id"]]
            cutoff = dt(order["event_at"])
            lower_tf = int(order["lower_tf"].removeprefix("PERIOD_M"))
            close_cutoff = dt(order["trigger_bar_time"]) + timedelta(minutes=lower_tf)
            assert close_cutoff <= cutoff and candidate["_sequence"] < order["_sequence"]
            up = asof_bars(upper, up_known, cutoff, close_cutoff)
            low = asof_bars(lower, low_known, cutoff, close_cutoff)
            ups = [p for p in pivot_map[order["upper_tf"]] if p["event_sequence"] < order["_sequence"] and p["known_at"] <= cutoff]
            lows = [p for p in pivot_map[order["lower_tf"]] if p["event_sequence"] < order["_sequence"] and p["known_at"] <= cutoff]
            feature, pre = feature_row(order, candidate, up, ups, point)
            row = dict(arm=arm, setup_id=trade["setup_id"], direction=trade["direction"],
                       blind_id=blind_lookup.get((arm, trade["setup_id"]), ""), **feature,
                       outcome=trade["outcome"], net_r=float(trade["net_r"]),
                       net_cash=float(trade["net_cash"]), entry_at=trade["entry_at"],
                       exit_at=trade["exit_at"], month=trade["month"])
            features.append(row)
            checks["orders_matched"] += 1
            for field in SNAPSHOT_FIELDS:
                if field.endswith(("_at", "_time")) and order.get(field):
                    assert dt(order[field]) <= cutoff, (field, order[field], cutoff)
            checks["snapshot_time_cutoff_pass"] += 1
            blind = blind_lookup.get((arm, trade["setup_id"]))
            if not blind:
                continue
            snapshot = {k: order.get(k, "") for k in SNAPSHOT_FIELDS}
            for k, v in snapshot.items():
                if v and k.endswith(("_time", "_at")):
                    snapshot[k] = iso(dt(v))
            clipped_up = up[-300:]
            clipped_low = low[-300:]
            origin = dt(order["wave1_start_time"])
            packet = dict(blind_id=blind, arm=arm, direction=trade["direction"],
                          upper_tf=order["upper_tf"], lower_tf=order["lower_tf"],
                          order_at=iso(cutoff), candidate_at=iso(dt(candidate["event_at"])),
                          render_cutoff_at=iso(cutoff), signalbarclosed_at=iso(close_cutoff),
                          pre_cutoff_at=feature["pre_cutoff_at"],
                          order_sequence=order["_sequence"],
                          candidate_sequence=candidate["_sequence"],
                          snapshot=snapshot,
                          upper_bars=[{k: iso(v) for k, v in b.items()} for b in clipped_up],
                          lower_bars=[{k: iso(v) for k, v in b.items()} for b in clipped_low],
                          pre_pivots=[public_pivot(p) for p in pre],
                          upper_pivots=[public_pivot(p) for p in ups if p["time"] >= clipped_up[0]["time"]],
                          lower_pivots=[public_pivot(p) for p in lows if p["time"] >= clipped_low[0]["time"]],
                          window=dict(bar_limit=300, closed_at_cutoff=iso(close_cutoff),
                                      upper_origin_clipped=clipped_up[0]["time"] > origin,
                                      lower_origin_clipped=clipped_low[0]["time"] > origin,
                                      upper_total_known=len(up), lower_total_known=len(low)),
                          provenance=dict(run=str(run), event_csv_sha256=inputs[str(run / "events.csv")],
                                          sequence_basis="zero-based data rows, excluding CSV header",
                                          clock="source/broker time; UTC mapping unverified"))
            packets.append(packet)
            label_key.append(dict(blind_id=blind, **trade, order_at=iso(cutoff), order_sequence=order["_sequence"]))
    packets.sort(key=lambda p: p["blind_id"])
    label_key.sort(key=lambda p: p["blind_id"])
    features.sort(key=lambda p: (p["arm"], p["order_at"], p["setup_id"]))
    blind_path = args.out / "blind/packets.json"
    dump(blind_path, dict(cases=packets, metadata=dict(schema_version=1,
         window_bars=300, timestamp_clock="source/broker; UTC mapping unverified",
         pre_cutoff="upper break bar OPEN; matches Engine search knownBy",
         outcome_labels="not included")))
    # All outcome-linked data is kept out of blind/.
    write_csv(args.out / "labels/label_key.csv", label_key)
    write_csv(args.out / "labels/features_all.csv", features)
    dump(args.out / "labels/selection_audit.json", dict(seed=SEED, strata=strata_audit))
    public_features = [{k: v for k, v in row.items() if k not in {"outcome", "net_r", "net_cash", "exit_at"}}
                       for row in features]
    write_csv(args.out / "features_causal.csv", public_features)
    manifest = dict(schema_version=1, clock="source/broker, no UTC assertion", annual_trades=len(trades),
                    selected_packets=len(packets), random_seed=SEED,
                    selection="stratified win/loss direction/arm quotas; chronological midpoint spacing; seed shuffle",
                    observed_inputs=inputs, input_hashes_after={str(Path(p)): digest(Path(p)) for p in inputs},
                    packets_sha256=digest(blind_path),
                    frozen_bins={"range_preleg": [1, 2], "range_tr14": [2, 4],
                                 "signed_close_efficiency": [.3, .6],
                                 "pre_countertrend_agreement": [2/3, 1],
                                 "outer_break_margin": "strictly greater than half point"},
                    features_sha256=digest(args.out / "features_causal.csv"),
                    packet_origin_clipping_counts={k: sum(p["window"][k] for p in packets)
                        for k in ("upper_origin_clipped", "lower_origin_clipped")},
                    assertions=dict(checks),
                    limitations=["Generated-tick backtest source; no native screenshots or real-tick claims.",
                        "Balanced sample is for visual hypotheses, not natural annual win rate.",
                        "Bar CSV lacks global event sequence; closed_at is capped at lower trigger close.",
                        "Same-source-time H/L pivot order is unknown; raw flags preserved and normalized path reset."])
    assert manifest["observed_inputs"] == manifest["input_hashes_after"]
    dump(args.out / "manifest.json", manifest)
    print(json.dumps({"annual_trades": len(features), "blind_packets": len(packets),
                      "packet_sha256": manifest["packets_sha256"],
                      "assertions": dict(checks), "path": str(blind_path)}))


if __name__ == "__main__":
    main()
