"""One fixed ER12 <= .25 saved-entry comparison. Never launches MT5.

Independent exact-grid H1 reconstruction, strictly as of ORDER, not FILL.
Keeping saved fills/exits/cash means this is a screen, NOT an executable rerun.
All clocks stay in the broker/source clock. Version runs must not be pooled.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import random
import statistics
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "reports/backtest/analysis/wave33_january_20261026"
DEFAULT_OUT = ROOT / "reports/backtest/analysis/wave33_h1_er_compare_20261027/offline"
DT = "%Y.%m.%d %H:%M:%S"
LOOKBACK = 12
THRESHOLD = .25
SEED = 331227
BOOTSTRAPS = 10000
RUNS = ("gold_v180", "gold_v190", "usd_v180")


def parse(value):
    return datetime.strptime(value, DT)


def stamp(value):
    return value.strftime(DT)


def read(path, delimiter=","):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream, delimiter=delimiter))


def write(path, rows):
    if not rows:
        return
    fields = list(dict.fromkeys(key for row in rows for key in row))
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def independent_h1(source_rows):
    groups = defaultdict(list)
    previous = None
    for row in source_rows:
        start = parse(row["bar_time"])
        close = parse(row["closed_at"])
        known = parse(row["known_at"])
        assert previous is None or start > previous, "M5 duplicate/non-monotone source"
        assert close == start + timedelta(minutes=5)
        assert known >= close
        assert start.minute % 5 == 0 and start.second == 0
        previous = start
        groups[start.replace(minute=0, second=0)].append(
            dict(start=start, close_at=close, known=known, price=float(row["close"])))
    complete, rejected = [], []
    for start, members in sorted(groups.items()):
        expected = [start + timedelta(minutes=5 * i) for i in range(12)]
        if [m["start"] for m in members] != expected:
            rejected.append(dict(start=stamp(start), present=len(members), expected=12))
            continue
        complete.append(dict(start=start, close_at=start + timedelta(hours=1),
                             known=max(m["known"] for m in members), price=members[-1]["price"]))
    return complete, rejected


def er_at(bars, cutoff):
    eligible = [b for b in bars if b["close_at"] <= cutoff and b["known"] <= cutoff]
    if len(eligible) < LOOKBACK + 1:
        return dict(er=None, status="UNAVAILABLE_WARMUP", observed_h1=len(eligible))
    window = eligible[-(LOOKBACK + 1):]
    prices = [b["price"] for b in window]
    path = math.fsum(abs(b - a) for a, b in zip(prices, prices[1:]))
    net = abs(prices[-1] - prices[0])
    assert 0 <= net <= path + 1e-8
    er = net / path if path else None
    gaps = [(b["close_at"] - a["close_at"]).total_seconds() / 3600
            for a, b in zip(window, window[1:])]
    assert er is None or -1e-12 <= er <= 1 + 1e-12
    return dict(er=er, status="OK" if path else "UNAVAILABLE_ZERO_PATH",
                observed_h1=len(eligible), net_move=net, absolute_path=path,
                first_h1_start=stamp(window[0]["start"]), last_h1_start=stamp(window[-1]["start"]),
                last_closed_at=stamp(window[-1]["close_at"]),
                max_known_at=stamp(max(b["known"] for b in window)),
                span_close_to_close_hours=(window[-1]["close_at"] - window[0]["close_at"]).total_seconds()/3600,
                gap_count_gt1h=sum(gap > 1 for gap in gaps), max_gap_hours=max(gaps),
                closes="|".join(format(price, ".10g") for price in prices))


def stats(rows):
    rr = [r["net_r"] for r in rows]
    cash = [r["net_cash"] for r in rows]
    rpos, rneg = math.fsum(x for x in rr if x > 0), -math.fsum(x for x in rr if x < 0)
    cpos, cneg = math.fsum(x for x in cash if x > 0), -math.fsum(x for x in cash if x < 0)
    ordered = sorted(rows, key=lambda r: (r["exit_at"], r["order_at"], r["setup_id"]))
    run = loss_streak = 0
    equity = high = dd = 0.
    for row in ordered:
        run = run + 1 if row["net_r"] < 0 else 0
        loss_streak = max(loss_streak, run)
        equity += row["net_r"]
        high = max(high, equity)
        dd = max(dd, high - equity)
    return dict(n=len(rows), wins=sum(r > 0 for r in rr), losses=sum(r < 0 for r in rr),
                flat=sum(r == 0 for r in rr), entry_days=len({r["order_day"] for r in rows}),
                net_r=math.fsum(rr), mean_r_per_executed=statistics.mean(rr) if rr else None,
                pf_r=rpos/rneg if rneg else None, net_saved_cash=math.fsum(cash),
                pf_saved_cash=cpos/cneg if cneg else None,
                gross_win_r=rpos, gross_loss_r=rneg, max_loss_streak_exit_order=loss_streak,
                additive_exit_order_max_drawdown_r=dd)


def exposure(rows):
    events = []
    for row in rows:
        entry, end = parse(row["fill_at"]), parse(row["exit_at"])
        assert end >= entry
        events.extend(((entry, 1), (end, -1)))
    # Close before open at same second; timestamps only have seconds.
    events.sort(key=lambda item: (item[0], item[1]))
    level = peak = 0
    for _, delta in events:
        level += delta
        peak = max(peak, level)
    assert level == 0
    return dict(max_concurrent_original_1r_slots=peak,
                total_original_1r_slot_hours=math.fsum(
                    (parse(r["exit_at"])-parse(r["fill_at"])).total_seconds()/3600 for r in rows))


def percentile(values, q):
    s = sorted(values)
    pos = (len(s)-1)*q
    lo, hi = math.floor(pos), math.ceil(pos)
    return s[lo]+(s[hi]-s[lo])*(pos-lo)


def robustness(rows):
    days = defaultdict(list)
    for row in rows:
        days[row["order_day"]].append(row)
    entries = [(day, len(group), -math.fsum(r["net_r"] for r in group if r["skip"]))
               for day, group in sorted(days.items())]
    rng = random.Random(SEED)
    means, totals = [], []
    for _ in range(BOOTSTRAPS):
        sample = rng.choices(entries, k=len(entries))
        delta = math.fsum(d[2] for d in sample)
        totals.append(delta)
        means.append(delta / sum(d[1] for d in sample))
    total_delta = math.fsum(d[2] for d in entries)
    loo = [dict(omitted_day=day, omitted_original_entries=n, omitted_delta_r=delta,
                remaining_delta_r=total_delta-delta,
                remaining_delta_r_per_original_entry=(total_delta-delta)/(len(rows)-n)
                if len(rows)>n else None) for day, n, delta in entries]
    return dict(entry_day_clusters=len(entries), bootstrap_replicates=BOOTSTRAPS, seed=SEED,
                paired_delta_r_per_original_entry_95pct=[percentile(means,.025), percentile(means,.975)],
                paired_delta_total_r_resampled_days_95pct=[percentile(totals,.025), percentile(totals,.975)],
                bootstrap_fraction_delta_positive=sum(x>0 for x in means)/len(means),
                leave_one_day_out_delta_r_min=min(x["remaining_delta_r"] for x in loo),
                leave_one_day_out_delta_r_max=max(x["remaining_delta_r"] for x in loo),
                leave_one_day_out_sign_positive_count=sum(x["remaining_delta_r"]>0 for x in loo),
                largest_day_abs_delta_r=max(abs(x[2]) for x in entries)), loo


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    out = args.out
    out.mkdir(parents=True, exist_ok=True)
    old = {(r["run"],r["setup_id"]):r for r in read(SOURCE/"htf/features.csv")}
    frozen = {(r["run"],r["setup_id"]):r for r in read(SOURCE/"trades.csv")}
    manifest = json.loads((SOURCE/"source_manifest.json").read_text(encoding="utf-8"))
    all_rows, audit, drift, baselines = [], [], [], []
    for run in RUNS:
        path = SOURCE/"source"/run
        for name in ("events", "upper_bars", "config"):
            expected = manifest[run]["files"][name]["sha256"]
            assert sha(path/f"{name}.csv") == expected, "Frozen source changed"
        events = read(path/"events.csv", ";")
        config = {r["parameter"]:r["value"] for r in read(path/"config.csv", ";")}
        by_kind = defaultdict(dict)
        for event in events:
            if event["event_type"] not in ("FILL","EXIT","ORDER"):
                continue
            kind, sid = event["event_type"],event["setup_id"]
            assert sid not in by_kind[kind], f"Multiple {kind} need separate ledger treatment"
            by_kind[kind][sid] = event
        assert set(by_kind["FILL"]) == set(by_kind["EXIT"])
        m5 = read(path/"upper_bars.csv", ";")
        h1, incomplete = independent_h1(m5)
        prefix_checks = 0
        write(out/f"{run}_incomplete_h1.csv", incomplete)
        for sid, fill in by_kind["FILL"].items():
            exit_row, order = by_kind["EXIT"][sid], by_kind["ORDER"][sid]
            assert fill["order_sent_at"] == order["order_sent_at"]
            order_at, fill_at = parse(order["order_sent_at"]),parse(fill["fill_at"])
            assert order_at <= fill_at
            assert parse(order["event_at"]) == order_at
            assert parse(fill["signal_known_at"]) <= order_at
            entry, initial_sl = float(fill["entry_price"]),float(fill["sl_price"])
            net_r, net_cash = float(exit_row["realized_r"]),float(exit_row["execution_net_cash"])
            money_risk = float(exit_row["execution_initial_risk_money"])
            assert money_risk > 0 and abs(net_r-net_cash/money_risk)<1e-8
            prior = frozen[(run,sid)]
            assert abs(net_r-float(prior["net_r"]))<1e-10
            assert abs(initial_sl-float(prior["initial_sl"]))<1e-10
            current = er_at(h1,order_at)
            at_fill = er_at(h1,fill_at)
            available_m5 = [b for b in m5 if parse(b["closed_at"])<=order_at
                            and parse(b["known_at"])<=order_at]
            prefix_h1,_ = independent_h1(available_m5)
            assert er_at(prefix_h1,order_at) == current, "Future-prefix result drift"
            prefix_checks += 1
            saved = old[(run,sid)]
            saved_er = float(saved["h1_er12"]) if saved.get("h1_er12") else None
            assert saved_er is None and at_fill["er"] is None or saved_er is not None and at_fill["er"] is not None and abs(saved_er-at_fill["er"])<1e-12
            old_skip = saved_er is not None and saved_er <= THRESHOLD
            skip = current["er"] is not None and current["er"] <= THRESHOLD
            if current["er"] != at_fill["er"] or old_skip != skip:
                drift.append(dict(run=run,setup_id=sid,order_at=stamp(order_at),fill_at=stamp(fill_at),
                                  er_at_order=current["er"],er_at_fill=at_fill["er"],old_skip=old_skip,new_skip=skip))
            record = dict(run=run,setup_id=sid,version=config["ea_version"],symbol=config["symbol"],
                          month=order_at.strftime("%Y-%m"),order_day=order_at.strftime("%Y-%m-%d"),
                          order_at=stamp(order_at),fill_at=stamp(fill_at),exit_at=exit_row["exit_at"],
                          direction=fill["direction"],entry=entry,initial_sl=initial_sl,
                          original_price_risk=abs(entry-initial_sl),original_money_risk=money_risk,
                          net_r=net_r,net_cash=net_cash,exit_reason=exit_row["exit_reason"],
                          skip=skip,filter_status="SKIP_LOW_ER" if skip else "ALLOW" if current["er"] is not None else "ALLOW_MISSING",
                          b_frozen_result_r=0 if skip else net_r,
                          b_frozen_saved_cash=0 if skip else net_cash,
                          delta_r=-net_r if skip else 0,
                          **{f"h1_{k}":v for k,v in current.items()})
            all_rows.append(record)
        audit.append(dict(run=run,source_m5=len(m5),complete_h1=len(h1),incomplete_observed_h1=len(incomplete),
                          closed_entries=len(by_kind["FILL"]),first_order=min(r["order_sent_at"] for r in by_kind["ORDER"].values()),
                          last_source_event=events[-1]["event_at"],prefix_invariance_checks=prefix_checks,
                          source_sha256={name:sha(path/f"{name}.csv") for name in ("config","events","upper_bars")}))
    all_rows.sort(key=lambda r:(r["run"],r["order_at"],r["setup_id"]))
    assert len(all_rows)==len(frozen)==len(old)==131
    write(out/"all_entries_order_time.csv",all_rows)
    write(out/"order_fill_feature_drift.csv",drift or [dict(status="NO_DRIFT",compared_entries=len(all_rows))])
    summary,directions,loo_rows,day_rows=[],[],[],[]
    for run in RUNS:
        for month in sorted({r["month"] for r in all_rows if r["run"]==run}):
            group=[r for r in all_rows if r["run"]==run and r["month"]==month]
            executed=[r for r in group if not r["skip"]]
            skipped=[r for r in group if r["skip"]]
            a,b,removed=stats(group),stats(executed),stats(skipped)
            rob,loo=robustness(group)
            delta=b["net_r"]-a["net_r"]
            assert abs(delta+removed["net_r"])<1e-9
            rec=dict(run=run,month=month,original_entry_count=len(group),missing_allowed=sum(r["h1_er"] is None for r in group),
                     baseline=a,filter_on=b,removed=removed,delta_net_r=delta,
                     baseline_r_per_original_entry=a["net_r"]/len(group),
                     filter_on_r_per_original_entry=b["net_r"]/len(group),
                     delta_r_per_original_entry=delta/len(group),
                     trade_retention_fraction=len(executed)/len(group),
                     removed_win_fraction=removed["wins"]/a["wins"] if a["wins"] else None,
                     removed_loss_fraction=removed["losses"]/a["losses"] if a["losses"] else None,
                     baseline_exposure_proxy=exposure(group),filter_exposure_proxy=exposure(executed),
                     uncertainty=rob)
            summary.append(rec)
            for direction in ("LONG","SHORT"):
                g=[r for r in group if r["direction"]==direction]
                keep=[r for r in g if not r["skip"]]
                remove=[r for r in g if r["skip"]]
                directions.append(dict(run=run,month=month,direction=direction,
                                       **{f"baseline_{k}":v for k,v in stats(g).items()},
                                       **{f"on_{k}":v for k,v in stats(keep).items()},
                                       **{f"removed_{k}":v for k,v in stats(remove).items()},
                                       delta_r=-math.fsum(r["net_r"] for r in remove)))
            loo_rows.extend(dict(run=run,month=month,**r) for r in loo)
            for day in sorted({r["order_day"] for r in group}):
                day_group=[r for r in group if r["order_day"]==day]
                day_rows.append(dict(run=run,month=month,day=day,original_entries=len(day_group),
                                     skipped=sum(r["skip"] for r in day_group),
                                     baseline_r=math.fsum(r["net_r"] for r in day_group),
                                     on_r=math.fsum(r["b_frozen_result_r"] for r in day_group),
                                     delta_r=math.fsum(r["delta_r"] for r in day_group)))
    write(out/"direction_comparison.csv",directions)
    write(out/"entry_day_comparison.csv",day_rows)
    write(out/"leave_one_entry_day_out.csv",loo_rows)
    write(out/"summary.csv",[dict(run=r["run"],month=r["month"],original_entry_count=r["original_entry_count"],
                                 missing_allowed=r["missing_allowed"],delta_net_r=r["delta_net_r"],
                                 delta_r_per_original_entry=r["delta_r_per_original_entry"],
                                 **{f"off_{k}":v for k,v in r["baseline"].items()},
                                 **{f"on_{k}":v for k,v in r["filter_on"].items()},
                                 **{f"removed_{k}":v for k,v in r["removed"].items()}) for r in summary])
    payload=dict(protocol=dict(lookback=LOOKBACK,threshold=THRESHOLD,skip_inclusive=True,missing="ALLOW_WITH_STATUS",
                              as_of="ORDER order_sent_at; constituents closed_at AND known_at <= cutoff",
                              definition="abs(C[-1]-C[-13])/sum(abs(diff(last13closedH1closes)))",
                              cash="saved native cash/initial cash risk, zero for screened trades; no equity/resizing replay",
                              source_clock="broker/source; UTC offset unknown",comparison="fixed saved-entry screen; not native A/B"),
                 audit=audit,order_fill_feature_drift_count=len(drift),summaries=summary,
                 native_gate="DO_NOT_LAUNCH: USD February effect reverses; gold1.80 January remains negative; selected exploratory sample not pristine OOS")
    (out/"summary.json").write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    lines=["# H1 ER12 fixed saved-entry screen", "", "ER12 <= 0.25 only; no threshold/period grid, EA changes, or MT5 launch.","",
           "ORDER-time features independently reconstructed from frozen M5 bars. Missing history or zero path allows the original entry with explicit missing status. Native saved outcome R always uses original risk, never trailed SL.","",
           "| Run / entry month | OFF n / net R / PF cash | ON n / net R / PF cash | Skipped win / loss / flat | Delta R | Missing allowed |",
           "|---|---:|---:|---:|---:|---:|"]
    for r in summary:
        a,b,s=r["baseline"],r["filter_on"],r["removed"]
        lines.append(f"| {r['run']} / {r['month']} | {a['n']} / {a['net_r']:.3f} / {a['pf_saved_cash']:.3f} | {b['n']} / {b['net_r']:.3f} / {b['pf_saved_cash']:.3f} | {s['wins']} / {s['losses']} / {s['flat']} | {r['delta_net_r']:+.3f} | {r['missing_allowed']} |")
    lines += ["", "## Honest accounting and limits", "",
              "- The denominator of per-original-entry R remains the OFF count: skipped trades contribute zero. Executed-trade averages are also exported but not used as the sole improvement claim.",
              "- Versions share trades and exit differently. Each version/month remains a separate cell. No pooled net R or claimed 131 independent opportunities.",
              "- ON removes saved trades only. It cannot discover replacement candidates, changed lane availability, opposite-wave exits influenced by screening, new fills, changed lot sizes, or equity compounding. Saved-cash PF is conditional accounting, not native filtered-EA PF.",
              "- The original-money-risk denominator is verified against native net cash for all 131 entries. Ledger records allow one FILL and EXIT per setup; duplicates or unclosed positions fail rather than silently disappear.",
              "- H1 bars require every scheduled five-minute grid slot. ER uses 13 completed observed H1 closes / 12 differences; it is not automatically 12 elapsed wall-clock hours. Window gaps/spans are exported. Missing complete bins are not forward-filled.",
              "- Entry-day paired bootstrap (10,000, fixed seed) and leave-one-entry-day-out retain within-day correlation. They do not solve temporal dependence, regime shift, multiple prior exploratory screens, or the tiny number of day clusters. Bootstrap fractions are descriptive, not confirmatory p-values.",
              "- Exposure proxies count every frozen open position as one original-R slot throughout holding. They do not revalue current trailed risk, correlation, margin, minimum lot, currency conversion, or live portfolio survival. Cash totals are not an equal-risk sizing simulation.",
              "- Gold January stops before month-end. USD March is censored at March27. USD February/March were already inspected in the prior broad analysis and are temporal checks, not untouched out of sample.",
              "", "## Gate", "", payload["native_gate"], "",
              f"ORDER vs previous FILL ER drift: {len(drift)} / {len(all_rows)} entries. Full source-prefix invariance and old-FILL-feature parity passed.",
              "", "See summary.json for day-cluster intervals and exposure proxies, direction_comparison.csv for side concentration, all_entries_order_time.csv for every removed winner/loss and missing case."]
    (out/"README.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
    print(json.dumps(dict(out=str(out),entries=len(all_rows),drift=len(drift),summary=[dict(run=r["run"],month=r["month"],n=r["baseline"]["n"],kept=r["filter_on"]["n"],off=r["baseline"]["net_r"],on=r["filter_on"]["net_r"],delta=r["delta_net_r"]) for r in summary]),ensure_ascii=False,indent=2))


if __name__ == "__main__":
    main()
