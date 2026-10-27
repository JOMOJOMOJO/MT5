"""Frozen-entry, uncapped favorable excursion diagnostic; never runs MT5.

Price R uses original fill and original initial SL. All OHLC are BID proxies,
including SHORT adverse/favorable marks; no actual executable PnL is inferred.
Lower/upper bounds describe unknown intrabar ordering in this OHLC proxy only.
"""
from __future__ import annotations

import argparse
import bisect
import csv
import hashlib
import json
import math
import statistics
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path

DT = "%Y.%m.%d %H:%M:%S"
THRESHOLDS = (1, 2, 3, 5, 10, 20, 50)
EPS = 1e-9  # Only absorb binary floating-point error at an exact R threshold.
RUN = "v185_b_scale_off"


def ms(value: str) -> int:
    return int(datetime.strptime(value, DT).replace(tzinfo=timezone.utc).timestamp() * 1000)


def stamp(value: int | None) -> str:
    return "" if value is None else datetime.fromtimestamp(value / 1000, timezone.utc).strftime("%Y.%m.%d %H:%M:%S.%f")[:-3]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


@dataclass(frozen=True)
class Bar:
    start: int
    end: int
    open: float
    high: float
    low: float
    close: float


def read_bars(path: Path) -> list[Bar]:
    result = []
    with path.open(encoding="utf-8-sig", newline="") as stream:
        for row in csv.DictReader(stream, delimiter=";"):
            if not row["bar_time"].startswith("2020."):
                continue
            b = Bar(ms(row["bar_time"]), ms(row["closed_at"]), *(float(row[k]) for k in ("open", "high", "low", "close")))
            assert b.end - b.start == 60000
            assert b.low <= min(b.open, b.close) <= max(b.open, b.close) <= b.high
            assert not result or b.start > result[-1].start, "duplicate/unordered source bars"
            result.append(b)
    assert result
    return result


def touch(b: Bar, direction: str, sl: float) -> bool:
    return b.low <= sl if direction == "LONG" else b.high >= sl


def gap_stop(b: Bar, direction: str, sl: float) -> bool:
    return b.open <= sl if direction == "LONG" else b.open >= sl


def excursion(b: Bar, direction: str, entry: float, risk: float) -> float:
    return max(0.0, (b.high - entry) / risk if direction == "LONG" else (entry - b.low) / risk)


def one_bound(bars: list[Bar], entry_ms: int, entry: float, sl: float,
              direction: str, cutoff_ms: int, upper: bool, starts: list[int] | None = None) -> dict:
    """First original-SL touch, or requested cutoff, under one OHLC bound.

    Upper may ignore a partial entry-bar touch because it could predate fill.
    Neither bound uses a subsequent bar after an unambiguous stop bar. Lower
    excludes SL-bar extrema and both partially observed boundary-bar extrema.
    A gap through SL at a post-entry bar open stops before any favorable mark.
    """
    risk = abs(entry - sl)
    assert risk > 0 and direction in ("LONG", "SHORT")
    assert (entry > sl) if direction == "LONG" else (entry < sl)
    start_times = starts if starts is not None else [b.start for b in bars]
    idx = max(0, bisect.bisect_right(start_times, entry_ms) - 1)
    peak_r, peak_i, peak_bar = 0.0, None, None
    reaches = {str(r): "" for r in THRESHOLDS}
    checked = included = 0
    entry_partial = ignored_entry_touch = False
    stop_i = None
    reason = "WINDOW_END" if cutoff_ms <= bars[-1].end else "DATA_END_CENSORED"
    end_ms = min(cutoff_ms, bars[-1].end)
    max_gap = 0
    previous = None
    for i in range(idx, len(bars)):
        b = bars[i]
        if b.end <= entry_ms:
            continue
        if b.start >= cutoff_ms:
            break
        if previous is not None:
            max_gap = max(max_gap, b.start - previous - 60000)
        previous = b.start
        checked += 1
        partial_entry = b.start < entry_ms
        partial_end = b.end > cutoff_ms
        entry_partial |= partial_entry
        stopped = touch(b, direction, sl)
        opened_through = b.start >= entry_ms and gap_stop(b, direction, sl)
        uncertain_entry_stop = stopped and partial_entry
        if opened_through:
            reason, end_ms, stop_i = "SL_GAP_OPEN", b.start, i
            break
        eligible = upper or (not partial_entry and not partial_end and not stopped)
        if eligible:
            included += 1
            r = excursion(b, direction, entry, risk)
            if r > peak_r:
                peak_r, peak_i, peak_bar = r, i, b.start
            for threshold in THRESHOLDS:
                if r + EPS >= threshold and not reaches[str(threshold)]:
                    reaches[str(threshold)] = stamp(b.start)
        if stopped:
            if upper and uncertain_entry_stop:
                ignored_entry_touch = True
                continue
            reason, end_ms, stop_i = "SL_TOUCH_BAR", min(b.end, cutoff_ms), i
            break
    assert peak_i is None or peak_i <= (stop_i if stop_i is not None else len(bars) - 1)
    if not upper and peak_i is not None:
        p = bars[peak_i]
        assert p.start >= entry_ms and p.end <= cutoff_ms and not touch(p, direction, sl)
    if reason == "SL_GAP_OPEN":
        assert peak_i is None or peak_i < stop_i
    # Independent eligibility audit: find first independently qualifying stop.
    independently_first = None
    for i in range(idx, len(bars)):
        b = bars[i]
        if b.end <= entry_ms:
            continue
        if b.start >= cutoff_ms:
            break
        independent_hit = b.low <= sl if direction == "LONG" else b.high >= sl
        if independent_hit and not (upper and b.start < entry_ms):
            independently_first = i
            break
    assert stop_i == independently_first
    return {
        "max_r": peak_r, "peak_bar_time": stamp(peak_bar), "end_reason": reason,
        "end_at": stamp(end_ms), "elapsed_minutes": max(0, end_ms - entry_ms) / 60000,
        "checked_bars": checked, "included_bars": included,
        "entry_partial": entry_partial, "ignored_possible_preentry_stop": ignored_entry_touch,
        "largest_missing_interval_minutes": max_gap / 60000,
        "stop_bar_time": stamp(bars[stop_i].start) if stop_i is not None else "",
        "reaches": reaches,
    }


def bounds(bars: list[Bar], entry_ms: int, entry: float, sl: float, direction: str, cutoff_ms: int,
           starts: list[int] | None = None, native_sl_ms: int | None = None) -> dict:
    starts = starts if starts is not None else [b.start for b in bars]
    effective_cutoff = min(cutoff_ms, native_sl_ms) if native_sl_ms is not None else cutoff_ms
    low = one_bound(bars, entry_ms, entry, sl, direction, effective_cutoff, False, starts)
    high = one_bound(bars, entry_ms, entry, sl, direction, effective_cutoff, True, starts)
    for detail in (low, high):
        detail["known_native_sl_at"] = stamp(native_sl_ms)
        if native_sl_ms is not None and native_sl_ms <= cutoff_ms and detail["end_at"] == stamp(native_sl_ms):
            detail["end_reason"] = "KNOWN_NATIVE_SL"
        if native_sl_ms is not None:
            assert detail["elapsed_minutes"] <= (native_sl_ms - entry_ms) / 60000 + EPS
    assert low["max_r"] <= high["max_r"] + 1e-9
    return {"lower": low, "upper": high}


def self_test() -> dict:
    minute = 60000
    def b(i, o, h, l, c):
        return Bar(i * minute, (i + 1) * minute, o, h, l, c)
    count = 0
    # Future huge extrema after stop must never contaminate bounds.
    bars = [b(0, 100, 103, 99, 102), b(1, 102, 108, 94, 96), b(2, 96, 200, 1, 100)]
    x = bounds(bars, 0, 100, 95, "LONG", 3 * minute)
    assert abs(x["lower"]["max_r"] - .6) < 1e-9
    assert abs(x["upper"]["max_r"] - 1.6) < 1e-9
    assert x["lower"]["end_reason"] == "SL_TOUCH_BAR"; count += 1
    mirrored = [b(i, 200-v.open, 200-v.low, 200-v.high, 200-v.close) for i, v in enumerate(bars)]
    y = bounds(mirrored, 0, 100, 105, "SHORT", 3 * minute)
    assert x["lower"]["max_r"] == y["lower"]["max_r"]
    assert x["upper"]["max_r"] == y["upper"]["max_r"]; count += 1
    x = bounds([b(0, 100, 101, 99, 100), b(1, 94, 160, 90, 150)], 0, 100, 95, "LONG", 2*minute)
    assert abs(x["upper"]["max_r"] - .2) < 1e-9
    assert x["upper"]["end_reason"] == "SL_GAP_OPEN"; count += 1
    x = bounds([b(0, 100, 110, 99, 101), b(1, 101, 120, 100, 110)], 30000, 100, 95, "LONG", 90000)
    assert x["lower"]["max_r"] == 0 and x["upper"]["max_r"] == 4; count += 1
    x = bounds([b(0, 100, 110, 94, 101), b(1, 101, 120, 100, 110), b(2, 110, 115, 94, 100)], 30000, 100, 95, "LONG", 180000)
    assert x["lower"]["max_r"] == 0 and x["upper"]["max_r"] == 4
    assert x["upper"]["ignored_possible_preentry_stop"]; count += 1
    x = bounds([b(0, 100, 120, 99, 110)], 0, 100, 95, "LONG", 120000)
    assert x["lower"]["end_reason"] == "DATA_END_CENSORED" and x["lower"]["max_r"] == 4; count += 1
    x = bounds([b(0, 100, 120, 99, 110)], 0, 100, 95, "LONG", 30000)
    assert x["lower"]["max_r"] == 0 and x["upper"]["max_r"] == 4; count += 1
    # SHORT open gap must also stop before favorable intrabar low.
    x = bounds([b(0, 100, 101, 99, 100), b(1, 106, 110, 20, 30)], 0, 100, 105, "SHORT", 120000)
    assert abs(x["upper"]["max_r"] - .2) < 1e-9 and x["upper"]["end_reason"] == "SL_GAP_OPEN"; count += 1
    # Observed native SHORT Ask-SL may fire with no BID-SL touch. Never count a
    # later rebound simply because the proxy never crossed the original level.
    native_bars = [b(0,100,102,99,101),b(1,101,104,98,102),b(2,102,103,10,20)]
    x = bounds(native_bars,0,100,105,"SHORT",180000,native_sl_ms=90000)
    assert x["lower"]["max_r"] == .2 and x["upper"]["max_r"] == .4
    assert all(x[k]["end_reason"]=="KNOWN_NATIVE_SL" for k in ("lower","upper")); count += 1
    native_mirror = [b(i,200-v.open,200-v.low,200-v.high,200-v.close) for i,v in enumerate(native_bars)]
    y = bounds(native_mirror,0,100,95,"LONG",180000,native_sl_ms=90000)
    assert x["lower"]["max_r"] == y["lower"]["max_r"] and x["upper"]["max_r"] == y["upper"]["max_r"]; count += 1
    return {"status": "PASS", "synthetic_scenarios": count}


def load_positions(path: Path, raw_path: Path) -> list[dict]:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        result = [dict(r) for r in csv.DictReader(stream) if r["run"] == RUN]
    by_id = {r["position_id"]: r for r in result}
    assert len(by_id) == len(result) == 334
    with raw_path.open(encoding="utf-8-sig", newline="") as stream:
        for raw in csv.DictReader(stream, delimiter=";"):
            p = by_id.get(raw["position_id"])
            if p is None:
                continue
            t = int(raw["time_msc"])
            if raw["entry"] == "DEAL_ENTRY_IN":
                assert "entry_msc" not in p, "multiple entry deals unexpected"
                assert abs(float(raw["price"]) - float(p["entry_price"])) < 1e-8
                p["entry_msc"] = t
            elif raw["entry"] == "DEAL_ENTRY_OUT":
                p["actual_exit_msc"] = max(t, p.get("actual_exit_msc", t))
    for p in result:
        assert "entry_msc" in p and "actual_exit_msc" in p
        assert abs(p["entry_msc"] - ms(p["entry_at"])) < 1000
    return result


def quantile(values: list[float], q: float) -> float:
    a = sorted(values)
    p = (len(a) - 1) * q
    lo, hi = math.floor(p), math.ceil(p)
    return a[lo] + (a[hi] - a[lo]) * (p - lo)


def aggregate(rows: list[dict]) -> dict:
    result = {"count": len(rows)}
    for horizon in ("1h", "4h", "24h", "uncapped"):
        h = {}
        for bound in ("lower", "upper"):
            values = [float(r[f"{horizon}_{bound}_max_r"]) for r in rows]
            h[bound] = {"median": statistics.median(values), "p75": quantile(values, .75),
                        "p90": quantile(values, .90), "p95": quantile(values, .95), "maximum": max(values),
                        "reach_counts": {str(t): sum(v + EPS >= t for v in values) for t in THRESHOLDS}}
        result[horizon] = h
    result["uncapped_end_reasons_lower"] = dict(Counter(r["uncapped_lower_end_reason"] for r in rows))
    return result


def write_csv(path: Path, rows: list[dict]) -> None:
    if not rows:
        return
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader(); writer.writerows(rows)


def execute(args) -> dict:
    tests = self_test()
    args.out.mkdir(parents=True, exist_ok=False)
    bars = read_bars(args.bars)
    starts = [b.start for b in bars]
    positions = load_positions(args.positions, args.raw_deals)
    opposite = json.loads(args.opposite_sources.read_text(encoding="utf-8-sig"))["by_setup"] if args.opposite_sources else {}
    rows = []
    for p in positions:
        row = {k: p[k] for k in ("run", "setup_id", "position_id", "direction", "entry_at", "exit_at", "entry_price", "initial_sl", "net_cash", "net_r", "exit_reason")}
        row.update(entry_exact_at=stamp(p["entry_msc"]), actual_exit_exact_at=stamp(p["actual_exit_msc"]),
                   initial_price_risk=abs(float(p["entry_price"]) - float(p["initial_sl"])),
                   quarter=p["entry_at"][:4] + "Q" + str((int(p["entry_at"][5:7])-1)//3+1))
        native_sl_ms = p["actual_exit_msc"] if p["exit_reason"] == "DEAL_REASON_SL" else None
        row["known_native_sl_at"] = stamp(native_sl_ms)
        windows = [("1h",60), ("4h",240), ("24h",1440), ("uncapped", None), ("before_actual_exit", "actual")]
        op = opposite.get(p["setup_id"])
        row["first_opposite_known_at"] = op["known_at"] if op else ""
        row["first_opposite_sequence"] = op.get("sequence", "") if op else ""
        if op:
            windows.append(("before_opposite", "opposite"))
        for label, minutes in windows:
            cutoff = p["actual_exit_msc"] if minutes == "actual" else (ms(op["known_at"]) if minutes == "opposite" else (bars[-1].end + 1 if minutes is None else p["entry_msc"] + minutes*60000))
            assert cutoff >= p["entry_msc"]
            observed = bounds(bars, p["entry_msc"], float(p["entry_price"]), float(p["initial_sl"]), p["direction"], cutoff, starts, native_sl_ms)
            for bound, detail in observed.items():
                for key, value in detail.items():
                    if key == "reaches":
                        for threshold, at in value.items():
                            row[f"{label}_{bound}_reach_{threshold}r_bar"] = at
                    else:
                        row[f"{label}_{bound}_{key}"] = value
        row["max_r_extension_beyond_actual_exit_lower"] = max(0, row["uncapped_lower_max_r"] - row["before_actual_exit_upper_max_r"])
        row["max_r_extension_beyond_actual_exit_upper"] = max(0, row["uncapped_upper_max_r"] - row["before_actual_exit_lower_max_r"])
        for bound in ("lower", "upper"):
            peak_label = row[f"uncapped_{bound}_peak_bar_time"]
            row[f"uncapped_{bound}_peak_bar_after_actual_exit"] = bool(peak_label and ms(peak_label[:19]) >= p["actual_exit_msc"])
        assert row["uncapped_lower_max_r"] <= row["uncapped_upper_max_r"] + 1e-9
        for bound in ("lower", "upper"):
            assert all(row[f"{a}_{bound}_max_r"] <= row[f"{b}_{bound}_max_r"] + EPS for a,b in (("1h","4h"),("4h","24h"),("24h","uncapped")))
        if native_sl_ms is not None:
            assert row["uncapped_upper_max_r"] <= row["before_actual_exit_upper_max_r"] + EPS
        rows.append(row)
    groups = []
    for kind in ("direction", "quarter", "actual_outcome"):
        buckets = defaultdict(list)
        for r in rows:
            value = ("WIN" if float(r["net_cash"]) > 0 else "LOSS" if float(r["net_cash"]) < 0 else "FLAT") if kind == "actual_outcome" else r[kind]
            buckets[value].append(r)
        for name, sample in buckets.items():
            groups.append({"group_type": kind, "group": name, **aggregate(sample)})
    gaps = [int((b.start-a.end)/60000) for a,b in zip(bars,bars[1:]) if b.start>a.end]
    summary = {"status": "PASS", "method": "BID_OHLC_PROXY_INITIAL_SL_NATIVE_SL_CAPPED_UNCAPPED_NO_COST_NO_OPPOSITE_EXIT",
               "run": RUN, "entry_population": "all original 334 filled positions; no entry reselection",
               "bounds_scope": "OHLC intrabar uncertainty only, NOT ASK/spread/execution bounds",
               "native_sl_barrier": "Observed original native DEAL_REASON_SL exit is an absolute path cutoff even if BID proxy never touches (e.g. SHORT Ask-triggered SL); no later rebound is counted",
               "opposite_wave_exit": "ignored in this offline structural-headroom diagnostic only; EA unchanged; not a tradable EA result",
               "realized_pnl": "not calculated; original realized net_cash/net_r retained for grouping only",
               "clock": "source/broker clock labels; epoch arithmetic is label arithmetic, not verified UTC mapping",
               "tests": tests, "invariants": "per-bound first eligible SL index independently recomputed for every window; bound ordering, eligible extrema and gap exclusion asserted",
               "source_hashes": {str(p):sha(p) for p in (args.positions,args.bars,args.raw_deals, *([args.opposite_sources] if args.opposite_sources else []))},
               "method_sha256": sha(Path(__file__)),
               "frozen_plan_sha256": sha(args.out.parent/"PLAN.md") if (args.out.parent/"PLAN.md").exists() else None,
               "threshold_numerical_epsilon_r": EPS,
               "coverage": {"bar_count":len(bars),"first_bar":stamp(bars[0].start),"last_bar_close":stamp(bars[-1].end),"gaps_count":len(gaps),"max_gap_minutes":max(gaps, default=0),"gaps_over_60_minutes":sum(g>60 for g in gaps),"entry_partial_count":sum(r["uncapped_lower_entry_partial"] for r in rows),"entry_partial_possible_sl_count":sum(r["uncapped_upper_ignored_possible_preentry_stop"] for r in rows)},
               "aggregate":aggregate(rows), "groups":groups}
    write_csv(args.out/"positions_excursion.csv",rows)
    (args.out/"summary.json").write_text(json.dumps(summary,indent=2,ensure_ascii=False),encoding="utf-8")
    group_rows=[]
    for g in groups:
        for horizon in ("1h","4h","24h","uncapped"):
            for bound in ("lower","upper"):
                values=g[horizon][bound]
                group_rows.append({"group_type":g["group_type"],"group":g["group"],"count":g["count"],"window":horizon,"bound":bound,**{k:v for k,v in values.items() if k!="reach_counts"},**{f"reach_{k}r":v for k,v in values["reach_counts"].items()}})
    write_csv(args.out/"groups.csv",group_rows)
    write_csv(args.out/"source_gaps.csv", [{"previous_bar_closed_at":stamp(a.end),"next_bar_opened_at":stamp(b.start),"missing_minutes":(b.start-a.end)/60000} for a,b in zip(bars,bars[1:]) if b.start>a.end])
    return {"status":"PASS","positions":len(rows),"out":str(args.out)}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test",action="store_true")
    parser.add_argument("--positions",type=Path)
    parser.add_argument("--bars",type=Path)
    parser.add_argument("--raw-deals",type=Path)
    parser.add_argument("--out",type=Path)
    parser.add_argument("--opposite-sources",type=Path)
    args=parser.parse_args()
    if args.self_test:
        print(json.dumps(self_test())); return
    for key in ("positions","bars","raw_deals","out"):
        if getattr(args,key) is None: parser.error(f"--{key.replace('_','-')} required")
    print(json.dumps(execute(args),ensure_ascii=False))


if __name__=="__main__": main()
