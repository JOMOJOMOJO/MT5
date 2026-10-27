"""Causal H1/H4 context screen of frozen Wave33 runs. Never starts MT5.

All clocks are the source/broker clock, not asserted UTC. Completed aggregate
bars require every constituent M5 slot, and close/known timestamps <= fill.
This is an exploratory, entry-fixed description, not a filter backtest.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import statistics
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from pathlib import Path

DT = "%Y.%m.%d %H:%M:%S"
FIELDS = ("open", "high", "low", "close")


def parse(value):
    return datetime.strptime(value, DT) if value else None


def stamp(value):
    return value.strftime(DT) if value else ""


def number(value, default=0.0):
    return float(value) if value not in (None, "") else default


def safe_div(a, b):
    return a / b if b and a is not None else None


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        yield from csv.DictReader(stream, delimiter=";")


def write_csv(path, rows):
    if not rows:
        return
    keys = list(dict.fromkeys(k for row in rows for k in row))
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=keys)
        writer.writeheader()
        writer.writerows(rows)


def load_bars(path):
    bars = []
    for row in read_csv(path):
        bar = {"start": parse(row["bar_time"]), "end": parse(row["closed_at"]),
               "known": parse(row["known_at"]),
               **{key: float(row[key]) for key in FIELDS}}
        assert bar["end"] - bar["start"] == timedelta(minutes=5)
        assert bar["known"] >= bar["end"]
        assert not bars or bar["start"] > bars[-1]["start"]
        assert bar["low"] <= min(bar["open"], bar["close"])
        assert bar["high"] >= max(bar["open"], bar["close"])
        bars.append(bar)
    return bars


def aggregate(bars, hours):
    """Exact-grid complete bins only; absence is not forward-filled."""
    grouped = defaultdict(list)
    for bar in bars:
        start = bar["start"].replace(hour=bar["start"].hour // hours * hours,
                                     minute=0, second=0)
        grouped[start].append(bar)
    complete, rejected = [], []
    for start, members in sorted(grouped.items()):
        expected = [start + timedelta(minutes=5 * i) for i in range(12 * hours)]
        if [m["start"] for m in members] != expected:
            rejected.append({"bar_time": stamp(start), "present_m5": len(members),
                             "expected_m5": len(expected), "reason": "INCOMPLETE_GRID"})
            continue
        complete.append({"start": start, "end": start + timedelta(hours=hours),
                         "known": max(m["known"] for m in members),
                         "open": members[0]["open"], "close": members[-1]["close"],
                         "high": max(m["high"] for m in members),
                         "low": min(m["low"] for m in members)})
    return complete, rejected


def ema(values, period):
    result = [None] * len(values)
    if len(values) < period:
        return result
    result[period - 1] = statistics.mean(values[:period])
    alpha = 2 / (period + 1)
    for i in range(period, len(values)):
        result[i] = alpha * values[i] + (1 - alpha) * result[i - 1]
    return result


def trailing_extrema(bars, length):
    if len(bars) < length:
        return None, None
    return min(b["low"] for b in bars[-length:]), max(b["high"] for b in bars[-length:])


def bar_features(bars, prefix, fill, entry, risk, direction):
    result = {prefix + "_n_complete": len(bars)}
    if not bars:
        return result
    last = bars[-1]
    assert last["end"] <= fill and last["known"] <= fill
    result.update({prefix + "_last_bar_time": stamp(last["start"]),
                   prefix + "_last_closed_at": stamp(last["end"]),
                   prefix + "_last_known_at": stamp(last["known"]),
                   prefix + "_history_max_known_at": stamp(max(b["known"] for b in bars)),
                   prefix + "_age_hours": (fill - last["end"]).total_seconds() / 3600})
    result.update({prefix + "_last_" + key: last[key] for key in FIELDS})
    closes = [b["close"] for b in bars]
    tr = [max(b["high"] - b["low"],
              abs(b["high"] - bars[i - 1]["close"]) if i else 0,
              abs(b["low"] - bars[i - 1]["close"]) if i else 0)
          for i, b in enumerate(bars)]
    atr14 = statistics.mean(tr[-14:]) if len(tr) >= 14 else None
    atr50 = statistics.mean(tr[-50:]) if len(tr) >= 50 else None
    e20, e50 = ema(closes, 20), ema(closes, 50)
    result[prefix + "_atr14"] = atr14
    result[prefix + "_atr14_to_atr50"] = safe_div(atr14, atr50)
    result[prefix + "_ema20"] = e20[-1]
    result[prefix + "_ema50"] = e50[-1]
    result[prefix + "_ema20_minus50_atr"] = safe_div(
        e20[-1] - e50[-1] if e20[-1] is not None and e50[-1] is not None else None, atr14)
    result[prefix + "_ema20_alignment"] = (
        "WITH" if direction * (e20[-1] - e50[-1]) > 0 else "AGAINST"
    ) if e20[-1] is not None and e50[-1] is not None else "UNAVAILABLE"
    result[prefix + "_ema20_slope3_atr"] = safe_div(
        direction * (e20[-1] - e20[-4]) if len(e20) >= 23 else None, atr14)
    result[prefix + "_close_momentum3_atr"] = safe_div(
        direction * (closes[-1] - closes[-4]) if len(closes) >= 4 else None, atr14)
    result[prefix + "_close_to_ema20_atr"] = safe_div(
        direction * (entry - e20[-1]) if e20[-1] is not None else None, atr14)
    span = last["high"] - last["low"]
    result[prefix + "_body_signed"] = safe_div(direction * (last["close"] - last["open"]), span)
    result[prefix + "_upper_wick_ratio"] = safe_div(last["high"] - max(last["open"], last["close"]), span)
    result[prefix + "_lower_wick_ratio"] = safe_div(min(last["open"], last["close"]) - last["low"], span)
    result[prefix + "_entry_risk_atr"] = safe_div(risk, atr14)
    # Last completed bar high/low may already be behind entry; signed distance is retained.
    directional_edge = last["high"] if direction == 1 else last["low"]
    result[prefix + "_directional_last_edge_price"] = directional_edge
    result[prefix + "_directional_last_edge_r"] = direction * (directional_edge - entry) / risk
    result[prefix + "_directional_last_edge_atr"] = safe_div(direction * (directional_edge - entry), atr14)
    if len(closes) >= 13:
        moves = [abs(closes[i] - closes[i - 1]) for i in range(len(closes) - 12, len(closes))]
        result[prefix + "_er12"] = safe_div(abs(closes[-1] - closes[-13]), sum(moves))
        result[prefix + "_er12_abs_path"] = sum(moves)
        result[prefix + "_er12_net_move"] = abs(closes[-1] - closes[-13])
        result[prefix + "_er12_first_close_bar"] = stamp(bars[-13]["start"])
        result[prefix + "_er12_closes"] = "|".join(str(x) for x in closes[-13:])
    for length in (24, 48):
        lo, hi = trailing_extrema(bars, length)
        result[f"{prefix}_range{length}_position"] = safe_div(entry - lo, hi - lo) if lo is not None else None
        result[f"{prefix}_range{length}_directional_edge_r"] = (
            direction * ((hi if direction == 1 else lo) - entry) / risk if lo is not None else None)
    # Time span makes omitted session hours visible, rather than suggesting contiguous calendar hours.
    result[prefix + "_last24_bars_span_hours"] = (
        (last["end"] - bars[-24]["start"]).total_seconds() / 3600 if len(bars) >= 24 else None)
    return result


def prior_day_features(bars, fill, entry, risk, direction):
    days = defaultdict(list)
    for b in bars:
        if b["start"].date() < fill.date() and b["known"] <= fill:
            days[b["start"].date()].append(b)
    # A tiny year-end trailing record must not masquerade as a whole previous day.
    valid = [(day, members) for day, members in days.items() if len(members) >= 144
             and members[-1]["end"] - members[0]["start"] >= timedelta(hours=12)]
    if not valid:
        return {"prior_observed_day_available": False}
    day, members = max(valid, key=lambda x: x[0])
    hi, lo = max(b["high"] for b in members), min(b["low"] for b in members)
    return {"prior_observed_day_available": True, "prior_observed_day": str(day),
            "prior_observed_day_m5_count": len(members),
            "prior_observed_day_known_at": stamp(max(b["known"] for b in members)),
            "prior_observed_day_low": lo, "prior_observed_day_high": hi,
            "prior_observed_day_position": safe_div(entry - lo, hi - lo),
            "prior_observed_day_directional_edge_r": direction * ((hi if direction == 1 else lo) - entry) / risk}


def h1_pivot_features(pivots, fill, row, risk, direction):
    entry = number(row["entry_price"])
    start = parse(row["wave1_start_time"])
    peak = number(row["wave1_peak_price"])
    wave_span = abs(peak - number(row["wave1_start_price"]))
    known = [p for p in pivots if p["known"] <= fill]
    highs, lows = ([p for p in known if p["is_high"]], [p for p in known if not p["is_high"]])
    result = {"h1_known_pivot_count": len(known)}
    for label, members in (("high", highs), ("low", lows)):
        if members:
            last = members[-1]
            result.update({f"h1_last_pivot_{label}_price": last["price"],
                           f"h1_last_pivot_{label}_time": stamp(last["time"]),
                           f"h1_last_pivot_{label}_known_at": stamp(last["known"]),
                           f"h1_last_pivot_{label}_label": last["label"]})
    obstacles = [p for p in (highs if direction == 1 else lows) if direction * (p["price"] - entry) > 0]
    if obstacles:
        obstacle = min(obstacles, key=lambda p: direction * (p["price"] - entry))
        result.update({"h1_nearest_known_obstacle_price": obstacle["price"],
                       "h1_nearest_known_obstacle_r": direction * (obstacle["price"] - entry) / risk,
                       "h1_nearest_known_obstacle_time": stamp(obstacle["time"]),
                       "h1_nearest_known_obstacle_known_at": stamp(obstacle["known"])})
    # Structural retest: exclude same W1/move by requiring pivot's SOURCE time before W1 origin.
    prior = [p for p in (highs if direction == 1 else lows) if p["time"] < start]
    result["h1_prior_level_available"] = bool(prior)
    if prior:
        near = min(prior, key=lambda p: abs(p["price"] - peak))
        frac = safe_div(abs(near["price"] - peak), wave_span)
        result.update({"h1_prior_nearest_peak_level": near["price"],
                       "h1_prior_nearest_peak_time": stamp(near["time"]),
                       "h1_prior_nearest_peak_known_at": stamp(near["known"]),
                       "h1_prior_nearest_peak_gap_fraction": frac,
                       "h1_prior_nearest_peak_level_r": direction * (near["price"] - entry) / risk,
                       "h1_prior_level_retest5pct": frac <= .05 if frac is not None else None})
        # 1R target conflict is a diagnostic counterfactual for v190 (no fixed TP).
        result["h1_prior_retest_1r_target_conflict"] = (
            frac <= .05 and 0 < direction * (near["price"] - entry) / risk < 1) if frac is not None else None
        beyond = [p for p in prior if direction * (p["price"] - peak) >= -1e-9]
        if beyond:
            closest = min(beyond, key=lambda p: direction * (p["price"] - peak))
            result.update({"h1_prior_beyond_peak_level": closest["price"],
                           "h1_prior_beyond_peak_time": stamp(closest["time"]),
                           "h1_prior_beyond_peak_known_at": stamp(closest["known"]),
                           "h1_prior_beyond_peak_r": direction * (closest["price"] - entry) / risk,
                           "h1_prior_beyond_peak_gap_fraction": safe_div(direction * (closest["price"] - peak), wave_span)})
    # Existing H1 direction uses pivot structure. Keep UNKNOWN separate from RANGE if <2 each side.
    result["h1_structure_warm"] = len(highs) >= 2 and len(lows) >= 2
    result["h1_log_direction_cold_aware"] = row["h1_direction"] if result["h1_structure_warm"] else "UNAVAILABLE_WARMUP"
    return result


def condition(row, key, predicate):
    value = row.get(key)
    return None if value in (None, "", "UNAVAILABLE", "UNAVAILABLE_WARMUP") else bool(predicate(value))


THRESHOLDS = {
    "h1_ema_against": ("h1_ema20_alignment", lambda v: v == "AGAINST", "EMA20<EMA50 for LONG; inverse SHORT; 50 closed H1 warmup"),
    "h1_slope_against": ("h1_ema20_slope3_atr", lambda v: v < 0, "entry-direction EMA20 change over 3 closed H1 bars <0"),
    "h1_momentum_against": ("h1_close_momentum3_atr", lambda v: v < 0, "entry-direction H1 close change over 3 completed bars <0"),
    "h1_range_er12": ("h1_er12", lambda v: v <= .25, "ER12<=0.25; abs net close change /sum 12 abs close changes"),
    "h1_previous_body_against": ("h1_body_signed", lambda v: v < 0, "latest CLOSED H1 body points opposite entry"),
    "h1_large_rejection_wick": ("h1_entry_facing_wick_ratio", lambda v: v >= .5, "LONG upper wick/whole range>=0.5; SHORT lower wick inverse"),
    "h1_vol_expansion": ("h1_atr14_to_atr50", lambda v: v >= 1.5, "ATR14/ATR50>=1.5; both SMA true range"),
    "h1_stretched_from_ema20": ("h1_close_to_ema20_atr", lambda v: v >= 1, "entry >=1 H1 ATR14 beyond EMA20 in trade direction"),
    "h1_directional_outer_quartile24": ("h1_directional_position24", lambda v: v >= .75, "LONG last24 completed H1 position>=.75; SHORT<=.25"),
    "h1_directional_outer_quartile48": ("h1_directional_position48", lambda v: v >= .75, "LONG last48 completed H1 position>=.75; SHORT<=.25"),
    "h1_obstacle_inside1r": ("h1_nearest_known_obstacle_r", lambda v: v < 1, "nearest past known H1 swing high/low ahead lies within original 1R"),
    "h1_prior_level_retest5pct": ("h1_prior_level_retest5pct", bool, "H1 prior high/low source before W1 origin is within .05*W1span of W1peak"),
    "h1_prior_retest_1r_target_conflict": ("h1_prior_retest_1r_target_conflict", bool, "prior retest flag AND prior directional level distance from entry is (0,1R); v190 hypothetical"),
    "h1_log_structure_against": ("h1_log_direction_cold_aware", lambda v: v == "AGAINST_H1", "existing log H1 structure AGAINST, only >=2 known H1 highs AND lows"),
    "h1_log_structure_range": ("h1_log_direction_cold_aware", lambda v: v == "H1_RANGE", "existing log H1_RANGE, only >=2 known H1 highs AND lows"),
    "h4_ema_against": ("h4_ema20_alignment", lambda v: v == "AGAINST", "H4 EMA20/50 opposite entry; 50 full H4 warmup"),
    "h4_slope_against": ("h4_ema20_slope3_atr", lambda v: v < 0, "entry-direction H4 EMA20 change over3 full bars <0"),
    "prior_day_directional_outer_quartile": ("prior_day_directional_position", lambda v: v >= .75, "entry directional position >=.75 in prior observed trade-day range"),
}


def stats(rows):
    r = [x["realized_r"] for x in rows]
    cash = [x["net_cash"] for x in rows]
    wins, losses = sum(x > 0 for x in r), sum(x < 0 for x in r)
    positive = sum(x for x in cash if x > 0)
    negative = -sum(x for x in cash if x < 0)
    return {"n": len(rows), "entry_days": len({r["fill_at"][:10] for r in rows}),
            "wins": wins, "losses": losses, "flat": len(rows) - wins - losses,
            "loss_rate": losses / len(rows) if rows else None,
            "sum_r": sum(r), "mean_r": statistics.mean(r) if rows else None,
            "median_r": statistics.median(r) if rows else None,
            "net_cash": sum(cash), "pf_cash": positive / negative if negative else None,
            "win_r": sum(x for x in r if x > 0), "loss_r": sum(x for x in r if x < 0)}


def process_run(path, out):
    fills, exits, pivots = {}, {}, []
    for row in read_csv(path / "events.csv"):
        kind = row["event_type"]
        sid = row["setup_id"]
        if kind == "FILL":
            assert sid not in fills, f"duplicate FILL {sid}"
            fills[sid] = row
        elif kind == "EXIT":
            assert sid not in exits, f"duplicate final EXIT {sid}"
            exits[sid] = row
        elif kind == "PIVOT_CONFIRMED" and row["observed_pivot_tf"] == "PERIOD_H1":
            label = row["observed_pivot_label"]
            pivots.append({"time": parse(row["observed_pivot_time"]),
                           "known": max(parse(row["observed_pivot_known_at"]), parse(row["event_at"])),
                           "price": number(row["observed_pivot_price"]),
                           "label": label, "is_high": label in ("H", "HH", "LH")})
    bars = load_bars(path / "upper_bars.csv")
    h1, missing_h1 = aggregate(bars, 1)
    h4, missing_h4 = aggregate(bars, 4)
    write_csv(out / f"{path.name}_incomplete_h1.csv", missing_h1)
    write_csv(out / f"{path.name}_incomplete_h4.csv", missing_h4)
    rows = []
    prefix_invariance_checks = 0
    for sid, fill in sorted(fills.items(), key=lambda item: item[1]["fill_at"]):
        actual = parse(fill["fill_at"])
        exit_row = exits.get(sid)
        assert exit_row, f"open trade excluded? handle explicitly {sid}"
        direction = 1 if fill["direction"] == "LONG" else -1
        entry, original_sl = number(fill["entry_price"]), number(fill["sl_price"])
        risk = abs(entry - original_sl)
        assert risk > 0 and direction * (entry - original_sl) > 0
        row = {"run": path.name, "setup_id": sid, "symbol": fill["symbol"],
               "period": "JAN" if actual.month == 1 else "POST_JAN", "month": actual.strftime("%Y-%m"),
               "direction": fill["direction"], "fill_at": fill["fill_at"],
               "exit_at": exit_row["exit_at"], "entry_price": entry, "initial_sl": original_sl,
               "risk_price": risk, "realized_r": number(exit_row["realized_r"]),
               "net_cash": number(exit_row["execution_net_cash"]),
               "initial_risk_cash": number(exit_row["execution_initial_risk_money"]),
               "exit_reason": exit_row["exit_reason"], "h1_log_direction": fill["h1_direction"],
               "wave1_start_time": fill["wave1_start_time"], "wave1_start_price": number(fill["wave1_start_price"]),
               "wave1_peak_time": fill["wave1_peak_time"], "wave1_peak_price": number(fill["wave1_peak_price"])}
        for prefix, aggregated in (("h1", h1), ("h4", h4)):
            known_bars = [b for b in aggregated if b["end"] <= actual and b["known"] <= actual]
            row.update(bar_features(known_bars, prefix, actual, entry, risk, direction))
            # Rebuild from ONLY the source rows already available at this fill.
            # Future source extension cannot change historical aggregate membership.
            truncated, _ = aggregate([b for b in bars if b["end"] <= actual and b["known"] <= actual],
                                     1 if prefix == "h1" else 4)
            assert truncated == known_bars, f"future-prefix invariance failed {sid}/{prefix}"
            prefix_invariance_checks += 1
        row.update(prior_day_features(bars, actual, entry, risk, direction))
        row.update(h1_pivot_features(pivots, actual, fill, risk, direction))
        row["h1_entry_facing_wick_ratio"] = row.get("h1_upper_wick_ratio" if direction == 1 else "h1_lower_wick_ratio")
        for length in (24, 48):
            position = row.get(f"h1_range{length}_position")
            row[f"h1_directional_position{length}"] = position if direction == 1 else 1 - position if position is not None else None
        position = row.get("prior_observed_day_position")
        row["prior_day_directional_position"] = position if direction == 1 else 1 - position if position is not None else None
        for name, (key, predicate, _) in THRESHOLDS.items():
            row["flag_" + name] = condition(row, key, predicate)
        rows.append(row)
    write_csv(out / f"{path.name}_features.csv", rows)
    availability = {"run": path.name, "m5_rows": len(bars), "m5_start": stamp(bars[0]["start"]),
                    "m5_end": stamp(bars[-1]["end"]), "closed_trades": len(rows),
                    "complete_h1": len(h1), "incomplete_observed_h1": len(missing_h1),
                    "complete_h4": len(h4), "incomplete_observed_h4": len(missing_h4),
                    "h1_pivots": len(pivots), "causal_assertions": "PASS",
                    "future_source_prefix_invariance_checks": prefix_invariance_checks,
                    "missing_per_feature": {name: sum(r["flag_" + name] is None for r in rows) for name in THRESHOLDS},
                    "source_sha256": {p.name: digest(p) for p in (path / "events.csv", path / "upper_bars.csv", path / "config.csv")}}
    return rows, availability


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("reports/backtest/analysis/wave33_january_20261026"))
    args = parser.parse_args()
    out = args.root / "htf"
    out.mkdir(parents=True, exist_ok=True)
    all_rows, availability = [], []
    for run in ("gold_v180", "gold_v190", "usd_v180"):
        rows, audit = process_run(args.root / "source" / run, out)
        all_rows.extend(rows)
        availability.append(audit)
    write_csv(out / "features.csv", all_rows)
    groups = defaultdict(list)
    for row in all_rows:
        groups[(row["run"], row["period"])].append(row)
    baseline, summaries, cont = [], [], []
    for (run, period), rows in groups.items():
        baseline.append({"run": run, "period": period, **stats(rows)})
        for name, (key, _, definition) in THRESHOLDS.items():
            present = [r for r in rows if r["flag_" + name] is not None]
            for value in (True, False):
                chosen = [r for r in present if r["flag_" + name] == value]
                summaries.append({"run": run, "period": period, "feature": name, "flag": value,
                                  "available": len(present), "missing": len(rows) - len(present),
                                  **stats(chosen), "definition": definition})
        numeric_keys = [key for key in dict.fromkeys(k for r in rows for k in r)
                        if key.startswith(("h1_", "h4_", "prior_"))
                        and any(isinstance(r.get(key), (int, float)) and not isinstance(r.get(key), bool) for r in rows)]
        for key in numeric_keys:
            for outcome in ("WIN", "LOSS"):
                values = [r.get(key) for r in rows if (r["realized_r"] > 0 if outcome == "WIN" else r["realized_r"] < 0)
                          and isinstance(r.get(key), (int, float)) and not isinstance(r.get(key), bool)]
                cont.append({"run": run, "period": period, "feature": key, "outcome": outcome,
                             "n": len(values), "mean": statistics.mean(values) if values else None,
                             "median": statistics.median(values) if values else None})
    write_csv(out / "baseline.csv", baseline)
    write_csv(out / "threshold_summary.csv", summaries)
    write_csv(out / "continuous_summary.csv", cont)
    # Same fixed ER threshold, without choosing a better cut, is broken down by
    # month/side so pooling cannot conceal a sign reversal or side imbalance.
    er_strata = []
    for run in ("gold_v180", "gold_v190", "usd_v180"):
        run_rows = [r for r in all_rows if r["run"] == run]
        for month in sorted({r["month"] for r in run_rows}):
            for direction in ("ALL", "LONG", "SHORT"):
                subset = [r for r in run_rows if r["month"] == month
                          and (direction == "ALL" or r["direction"] == direction)]
                for flag in (True, False, None):
                    chosen = [r for r in subset if r["flag_h1_range_er12"] is flag]
                    er_strata.append({"run": run, "month": month, "direction": direction,
                                      "flag_h1_range_er12": flag, **stats(chosen)})
    write_csv(out / "er12_month_direction.csv", er_strata)
    (out / "availability.json").write_text(json.dumps(availability, ensure_ascii=False, indent=2), encoding="utf-8")
    (out / "threshold_inventory.json").write_text(json.dumps({name: {"source_feature": key, "definition": definition}
        for name, (key, _, definition) in THRESHOLDS.items()}, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = ["# Wave33 January causal higher-timeframe screen", "",
             "Frozen-entry exploratory description. No EA launch, optimization, or filter promotion.", "",
             "## Baselines (entry month)", "", "| Run | Period | Trades | Wins | Losses | Sum R | Net cash |",
             "|---|---|---:|---:|---:|---:|---:|"]
    for row in baseline:
        lines.append(f"| {row['run']} | {row['period']} | {row['n']} | {row['wins']} | {row['losses']} | {row['sum_r']:.3f} | {row['net_cash']:.2f} |")
    lines += ["", "## Fixed descriptive screens", "",
              "18 prespecified threshold flags; all are retained, including negative/null findings. Multiple comparisons and small counts make this hypothesis discovery only.",
              "No p-value or confidence claim is attached. Version runs share entries and are correlated, so they must not be pooled.", "",
              "| Run/period | Flag | True N (losses) | True mean R | False N (losses) | False mean R | Missing |",
              "|---|---|---:|---:|---:|---:|---:|"]
    for i in range(0, len(summaries), 2):
        a, b = summaries[i:i+2]
        def fmt(x):
            return "NA" if x is None else f"{x:.3f}"
        lines.append(f"| {a['run']}/{a['period']} | {a['feature']} | {a['n']} ({a['losses']}) | {fmt(a['mean_r'])} | {b['n']} ({b['losses']}) | {fmt(b['mean_r'])} | {a['missing']} |")
    lines += ["", "## Definitions and causal limits", "",
              "- All dates are source/broker clock. No UTC or market-session conversion is assumed.",
              "- H1 aggregates require exactly 12 grid-aligned M5 bars; H4 exactly 48. All member known_at and full-bin close must be <= actual fill_at. Incomplete bins are discarded and explicitly exported. Completely absent holiday/weekend bins are not invented.",
              "- Features use only eligible closed aggregate bars at each fill. H1/H4 EMA20/50 seed with period SMA and require full warmup. ATR14/50 are trailing SIMPLE mean true ranges (not Wilder smoothing). ER12 uses 13 closes /12 moves. Lookbacks count completed observed bars, so may span session gaps; last24 span is exported.",
              "- H1/H4 current forming candle never enters entry features. No pre-start history was fetched, so early January EMA50, H4 and range48 fields are unavailable; missing is not silently RANGE or safe.",
              "- Prior observed-day range uses the latest prior source date with >=144 M5 bars spanning >=12 hours. It is an observed range, not an asserted complete exchange session/day. Current-day completed bars do not enter that range.",
              "- H1 pivots use PIVOT_CONFIRMED and max(event_at,observed_pivot_known_at)<=fill. Structural prior-level candidates additionally require source pivot time < W1 origin, preventing the current W1 high/low itself from masquerading as historical resistance/support. Same H1 move is represented once, not duplicated with M15/M5 levels.",
              "- Retest5pct means absolute prior-level/W1peak difference <=5% of W1span. It is a prior high/low retest candidate, not a confirmed double top/bottom and not proof that a reversal was predictable. Known prior levels may already have been broken; no extra post-hoc survival filter is applied.",
              "- h1_prior_beyond_peak is nearest directional prior H1 level beyond the W1 endpoint. h1_nearest_known_obstacle includes all known H1 pivots ahead of entry and can include the current move; both definitions stay separate.",
              "- 1R-target-conflict is a diagnostic geometric test. v190 has no fixed TP, so this is hypothetical for that run. Price-distance R uses FILL entry and original SL, while realized R is the log's actual net-cash/initial-money-risk result.",
              "- Exits are grouped once per setup. Run gold_v180 and gold_v190 use different exit policies and stop on different January dates; comparison is not a controlled strategy A/B. USD post-January is February-March 27 only, not a full-year holdout.",
              "- No comparison modifies entries, cash, risk, sizing or subsequent candidates. A flag's mean R is a conditional description, not the balance/PF of a rerun that skips it.",
              "", "## Fixed ER12 threshold: month and direction checks", "",
              "| Run/month/side | ER<=.25 N / loss / sum R | ER>.25 N / loss / sum R |",
              "|---|---:|---:|"]
    for i in range(0, len(er_strata), 3):
        a, b, _ = er_strata[i:i+3]
        lines.append(f"| {a['run']}/{a['month']}/{a['direction']} | {a['n']} / {a['losses']} / {a['sum_r']:.3f} | {b['n']} / {b['losses']} / {b['sum_r']:.3f} |")
    lines += ["", "February USD reverses the aggregate low-ER association. Gold v180 SHORT also does not support blanket low-ER exclusion. These counterexamples are retained, not tuned away.",
              "", "## Threshold inventory", ""]
    for name, (_, _, definition) in THRESHOLDS.items():
        lines.append(f"- `{name}`: {definition}")
    (out / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({"out": str(out), "baseline": baseline, "causal_audit": "PASS",
                      "thresholds": len(THRESHOLDS)}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
