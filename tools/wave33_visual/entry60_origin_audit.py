"""Post-hoc engineering audit of the fixed blue W1 origin semantics.

Reads no outcomes. This audit was motivated by blind images, after the original
five feature definitions were fixed. It must not be presented as preregistered
strategy evidence and does not propose or implement an entry exclusion.
"""
from __future__ import annotations

import argparse
from collections import Counter
import csv
import json
from pathlib import Path

from entry60_data import asof_bars, digest, dt, dump, iso, load_bars, load_events, read, write_csv


def link_outcomes(args):
    from entry60_compare import metrics, strata, validate_freeze
    assert args.blind_frozen and args.blind_frozen.is_file()
    freeze = json.loads(args.blind_frozen.read_text(encoding="utf-8-sig"))
    validate_freeze(args.blind_frozen, [Path(p) for p in freeze["annotation_hashes"]])
    out = args.out / "outcomes"
    assert not (out / "manifest.json").exists(), "Refusing to overwrite origin outcome link"
    origins_path = args.out / "origins_all.csv"
    features_path = args.data / "labels/features_all.csv"
    originals = list(read(origins_path, ","))
    # First outcome access in this post-hoc diagnostic; frozen reviews verified.
    features = list(read(features_path, ","))
    lookup = {(r["arm"], r["setup_id"]): r for r in features}
    assert len(originals) == len(lookup) == 440
    rows = []
    for origin in originals:
        feature = lookup[(origin["arm"], origin["setup_id"])]
        interior = origin["strict_interior_origin_breach"] == "True"
        row = dict(origin, outcome=feature["outcome"], net_r=float(feature["net_r"]),
                   net_cash=float(feature["net_cash"]), month=feature["month"],
                   half="H1" if int(feature["month"][-2:]) <= 6 else "H2",
                   breach_group="STRICT_INTERIOR_BREACH" if interior else "NO_STRICT_INTERIOR_BREACH")
        rows.append(row)
    groups, timing = [], []
    for stratum, subset in strata(rows):
        for label in ("STRICT_INTERIOR_BREACH", "NO_STRICT_INTERIOR_BREACH"):
            groups.append(dict(stratum=stratum, group=label,
                               **metrics([r for r in subset if r["breach_group"] == label]),
                               status="POSTHOC_ENGINEERING_DIAGNOSTIC_NOT_FILTER_VALIDATION"))
        for location in ("BEFORE_BREAK_OPEN", "ON_BREAK_BAR", "AFTER_BREAK_BAR", "NONE"):
            timing.append(dict(stratum=stratum, first_breach_location=location,
                               **metrics([r for r in subset if r["first_interior_breach_location"] == location]),
                               status="POSTHOC_ENGINEERING_DIAGNOSTIC_NOT_FILTER_VALIDATION"))
    write_csv(out / "origin_outcomes_all.csv", rows)
    write_csv(out / "origin_group_metrics.csv", groups)
    write_csv(out / "origin_timing_metrics.csv", timing)
    write_csv(out / "selected60_origin_outcomes.csv", [r for r in rows if r["blind_id"]])
    write_csv(out / "visual_anchor_cases.csv", [r for r in rows if r["blind_id"] in ("V030", "V036", "V041", "V054")])
    inputs = {str(p): digest(p) for p in (origins_path, features_path, args.blind_frozen)}
    manifest = dict(n=len(rows), inputs=inputs,
                    input_hashes_after={p: digest(Path(p)) for p in inputs},
                    result_labels_read=True, primary_five_features_unchanged=True,
                    status="POSTHOC_ENGINEERING_DIAGNOSTIC_NOT_PREREGISTERED_NOT_OOS",
                    threshold="same prelabel halfpoint origin test; no new fitted thresholds",
                    inference="Observed exit-dependent R only; no exclusion implemented or recommended by this audit alone",
                    outputs={p.name: digest(p) for p in out.iterdir() if p.suffix == ".csv"})
    assert manifest["inputs"] == manifest["input_hashes_after"]
    dump(out / "manifest.json", manifest)
    print(json.dumps([r for r in groups if r["stratum"] in ("ALL", "ARM:A", "ARM:B")]))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch", type=Path, default=Path("reports/backtest/runs/wave33_v180_2020/20261023_164915_831ff154"))
    parser.add_argument("--data", type=Path, default=Path("reports/qa/w33entry60/data"))
    parser.add_argument("--out", type=Path, default=Path("reports/qa/w33entry60/analysis/origin_audit"))
    parser.add_argument("--link-outcomes", action="store_true")
    parser.add_argument("--blind-frozen", type=Path)
    args = parser.parse_args()
    if args.link_outcomes:
        link_outcomes(args)
        return
    assert not (args.out / "manifest.json").exists(), "Refusing to overwrite a frozen audit"
    # This file has no outcome/exit/cash columns; the label directory is not read.
    source = args.data / "features_causal.csv"
    trades = list(read(source, ","))
    assert len(trades) == 440
    assert not any(k in trades[0] for k in ("outcome", "net_r", "net_cash", "exit_at"))
    inputs = {str(source): digest(source)}
    rows = []
    for arm in ("A", "B"):
        run = args.batch / f"v180_{arm.lower()}_both"
        for name in ("events.csv", "upper_bars.csv", "config.csv"):
            inputs[str(run / name)] = digest(run / name)
        config = {r["parameter"]: r["value"] for r in read(run / "config.csv")}
        point = float(config["point"])
        wanted = {r["setup_id"] for r in trades if r["arm"] == arm}
        orders, _, _ = load_events(run / "events.csv", wanted)
        bars = load_bars(run / "upper_bars.csv")
        times = [b["known_at"] for b in bars]
        bytime = {b["time"]: b for b in bars}
        for trade in (r for r in trades if r["arm"] == arm):
            order = orders[trade["setup_id"]]
            origin, peak = dt(order["wave1_start_time"]), dt(order["wave1_peak_time"])
            cut = dt(order["event_at"])
            signalclose = dt(trade["order_at"])
            # The causal feature builder already logged ORDER and trigger times;
            # derive the same tighter close cap directly from the ORDER snapshot.
            from datetime import timedelta
            minutes = int(order["lower_tf"].removeprefix("PERIOD_M"))
            signalclose = dt(order["trigger_bar_time"]) + timedelta(minutes=minutes)
            known = asof_bars(bars, times, cut, signalclose)
            sign = 1 if order["direction"] == "LONG" else -1
            origin_price, peak_price = float(order["wave1_start_price"]), float(order["wave1_peak_price"])
            breakopen = dt(order["upper_break_bar_time"])
            originbar, peakbar = bytime.get(origin), bytime.get(peak)
            origin_side, peak_side = ("low", "high") if sign > 0 else ("high", "low")
            origin_source_exists = originbar is not None
            peak_source_exists = peakbar is not None
            origin_matches = origin_source_exists and abs(originbar[origin_side]-origin_price) <= point*.5
            peak_matches = peak_source_exists and abs(peakbar[peak_side]-peak_price) <= point*.5
            interior = [b for b in known if origin < b["time"] < peak]
            peakbars = [b for b in known if b["time"] == peak]
            broken = lambda b: sign * (b[origin_side]-origin_price) < -point*.5
            breaches = [b for b in interior if broken(b)]
            peak_breaches = [b for b in peakbars if broken(b)]
            first = breaches[0] if breaches else None
            first_location = ("NONE" if first is None else
                              "BEFORE_BREAK_OPEN" if first["time"] < breakopen else
                              "ON_BREAK_BAR" if first["time"] == breakopen else "AFTER_BREAK_BAR")
            most = min(interior, key=lambda b: sign*b[origin_side]) if interior else None
            row = dict(arm=arm, setup_id=trade["setup_id"], blind_id=trade["blind_id"],
                       direction=order["direction"], upper_tf=order["upper_tf"],
                       order_at=iso(cut), order_sequence=order["_sequence"],
                       upper_break_bar_open=iso(breakopen),
                       wave1_start_time=iso(origin), wave1_start_price=origin_price,
                       wave1_start_known_at=iso(dt(order["wave1_start_known_at"])),
                       wave1_peak_time=iso(peak), wave1_peak_price=peak_price,
                       wave1_peak_known_at=iso(dt(order["wave1_peak_known_at"])),
                       wave1_revision=int(order["wave1_revision"]),
                       origin_source_bar_exists=origin_source_exists,
                       origin_matches_source_extreme=origin_matches,
                       peak_source_bar_exists=peak_source_exists,
                       peak_matches_source_extreme=peak_matches,
                       strict_interior_bar_count=len(interior),
                       strict_interior_origin_breach=bool(breaches),
                       strict_interior_breach_count=len(breaches),
                       peak_bar_origin_breach=bool(peak_breaches),
                       peak_bar_only_breach=bool(peak_breaches) and not bool(breaches),
                       peak_bar_intrabar_order="UNKNOWN" if peak_breaches else "NOT_APPLICABLE",
                       first_interior_breach_location=first_location,
                       first_interior_breach_time=iso(first["time"]) if first else "",
                       first_interior_breach_known_at=iso(first["known_at"]) if first else "",
                       first_interior_breach_price=first[origin_side] if first else "",
                       first_interior_breach_known_by_break_open=first["known_at"] <= breakopen if first else "",
                       interior_most_adverse_time=iso(most["time"]) if most else "",
                       interior_most_adverse_price=most[origin_side] if most else "",
                       interior_most_adverse_beyond_origin_points=max(0, -sign*(most[origin_side]-origin_price)/point) if most else "",
                       bars_known_at_cutoff=iso(cut), bars_closed_at_cutoff=iso(signalclose),
                       classification="POSTHOC_ENGINEERING_SEMANTICS_NOT_ENTRY_FILTER")
            rows.append(row)
    rows.sort(key=lambda r: (r["arm"], r["order_at"], r["setup_id"]))
    summaries = []
    for arm in ("ALL", "A", "B"):
        for direction in ("ALL", "LONG", "SHORT"):
            subset = [r for r in rows if (arm == "ALL" or r["arm"] == arm)
                      and (direction == "ALL" or r["direction"] == direction)]
            summaries.append(dict(arm=arm, direction=direction, n=len(subset),
                                  strict_interior_breach=sum(r["strict_interior_origin_breach"] for r in subset),
                                  peak_bar_only_breach=sum(r["peak_bar_only_breach"] for r in subset),
                                  origin_source_mismatch=sum(not r["origin_matches_source_extreme"] for r in subset),
                                  peak_source_mismatch=sum(not r["peak_matches_source_extreme"] for r in subset),
                                  first_before_break=sum(r["first_interior_breach_location"] == "BEFORE_BREAK_OPEN" for r in subset),
                                  first_on_break=sum(r["first_interior_breach_location"] == "ON_BREAK_BAR" for r in subset),
                                  first_after_break=sum(r["first_interior_breach_location"] == "AFTER_BREAK_BAR" for r in subset)))
    write_csv(args.out / "origins_all.csv", rows)
    write_csv(args.out / "origin_breaches.csv", [r for r in rows if r["strict_interior_origin_breach"] or r["peak_bar_only_breach"]])
    write_csv(args.out / "summary_no_outcomes.csv", summaries)
    manifest = dict(n=len(rows), inputs=inputs,
                    input_hashes_after={p: digest(Path(p)) for p in inputs},
                    result_labels_read=False, changed_original_five_features=False,
                    source_reason="Blind visual reviewers noticed later source extremes beyond blue W1 origins.",
                    status="POSTHOC_ENGINEERING_DIAGNOSTIC; no profit filter or EA adoption",
                    strict_interior="origin source time < bar source time < fixed peak source time",
                    peak_bar="Separate only; OHLC cannot establish whether origin or peak extreme occurred first",
                    threshold="strictly more than half symbol point beyond origin",
                    outputs={p.name: digest(p) for p in args.out.iterdir() if p.suffix == ".csv"})
    assert manifest["inputs"] == manifest["input_hashes_after"]
    dump(args.out / "manifest.json", manifest)
    print(json.dumps(summaries[0]))


if __name__ == "__main__":
    main()
