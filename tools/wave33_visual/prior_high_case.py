"""Reconstruct the supplied April 3 case strictly before its ORDER event.

One-case context explanation; no entry filter, proximity tuning or future bars.
"""
from pathlib import Path
import csv
import hashlib
import json
import os
from datetime import datetime, timedelta

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from matplotlib.patches import Rectangle

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "reports/qa/w33context_20261025"
COMMON = Path(os.environ["APPDATA"]) / "MetaQuotes/Terminal/Common/Files"
# Completed run; separate from the user's currently paused/appending test.
TAG = "wave33_chop_v181_1685577600_71895031"


def rows(path):
    with path.open(encoding="utf-8-sig", newline="") as f:
        yield from csv.DictReader(f, delimiter=";")


def dt(s):
    return datetime.strptime(s, "%Y.%m.%d %H:%M:%S")


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    if (OUT / "case.json").exists():
        raise SystemExit("Case already frozen; refusing overwrite.")
    source = {k: COMMON / f"{TAG}_{k}.csv" for k in ("events", "upper_bars", "config")}
    hashes = {str(p): sha(p) for p in source.values()}
    known = []
    for sequence, r in enumerate(rows(source["events"])):
        if r["event_type"] == "ORDER" and r.get("wave1_peak_time") == "2024.04.03 06:15:00" and r.get("direction") == "LONG":
            order, order_sequence = r, sequence
            break
        if r["event_type"] == "PIVOT_CONFIRMED":
            known.append(dict(sequence=sequence, time=r["observed_pivot_time"], known_at=r["observed_pivot_known_at"],
                price=float(r["observed_pivot_price"]), tf=r["observed_pivot_tf"], label=r["observed_pivot_label"]))
    else:
        raise AssertionError("Original case not found")
    candidates = [p for p in known if p["tf"] in ("PERIOD_M15", "PERIOD_H1")
                  and p["label"] in ("H", "HH", "LH") and p["time"] < order["wave1_start_time"]
                  and p["known_at"] <= order["event_at"] and p["price"] >= float(order["wave1_peak_price"])]
    # Explanation only: the closest PRE-W1 known high beyond the fixed W1 peak.
    prior_price = min(p["price"] for p in candidates)
    prior = [p for p in candidates if p["price"] == prior_price]
    cutoff = dt(order["event_at"])
    bars = [r for r in rows(source["upper_bars"]) if "2024.04.02 23:30:00" <= r["bar_time"]
            and dt(r["closed_at"]) <= cutoff and dt(r["known_at"]) <= cutoff]
    assert bars and all(dt(r["closed_at"]) <= cutoff for r in bars)
    risk = abs(float(order["entry_price"]) - float(order["sl_price"]))
    price = lambda name: float(order[name])
    summary = dict(entry_at=order["event_at"], order_sequence=order_sequence, prior_high=prior_price,
        prior_sources=prior, wave1_peak=price("wave1_peak_price"), peak_gap=prior_price-price("wave1_peak_price"),
        peak_gap_over_wave1_range=(prior_price-price("wave1_peak_price"))/(price("wave1_peak_price")-price("wave1_start_price")),
        room_to_prior_high_r=(prior_price-price("entry_price"))/risk,
        current_nearest_obstacle=price("nearest_obstacle_price"), current_obstacle_source=order["nearest_obstacle_source"],
        h1_direction=order["h1_direction"], entry_price=price("entry_price"), sl=price("sl_price"), tp=price("tp_price"),
        planned_rr=(price("tp_price")-price("entry_price"))/risk,
        intervening_low=price("wave1_start_price"), neckline_broken_at_entry=False,
        classification="PRIOR_HIGH_RETEST_CANDIDATE; not confirmed double top",
        same_price_m15_h1_is_one_market_move=True)
    # Verify the trough between the first high and second high using known bars.
    trough_bars = [r for r in bars if min(p["time"] for p in prior) < r["bar_time"] < order["wave1_peak_time"]]
    assert min(float(r["low"]) for r in trough_bars) == summary["intervening_low"]
    since_second_top = [r for r in bars if r["bar_time"] >= order["wave1_peak_time"]]
    assert all(float(r["low"]) > summary["intervening_low"] for r in since_second_top)
    config = {r["parameter"]: r["value"] for r in rows(source["config"])}
    config = {k: config.get(k) for k in ("ea_version", "symbol", "upper_tf", "lower_tf", "obstacle_mode", "reward_r", "minimum_wave1_room_r")}
    event_fields = "event_at setup_id wave1_start_time wave1_start_price wave1_peak_time wave1_peak_price wave1_peak_known_at entry_price sl_price tp_price nearest_obstacle_price nearest_obstacle_source obstacle_distance_r h1_direction".split()
    evidence = dict(summary=summary, order={k: order[k] for k in event_fields}, config=config,
                    bars=bars, source_sha256=hashes, future_bars_used=False,
                    limitation="Single historical case; no optimized proximity cutoff and no profitability claim")
    assert all(sha(Path(p)) == h for p, h in hashes.items())
    (OUT / "case.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding="utf-8")
    plt.rcParams["font.family"] = ["Yu Gothic", "Meiryo", "DejaVu Sans"]
    fig, ax = plt.subplots(figsize=(13.5, 6.2), dpi=140)
    for b in bars:
        x = mdates.date2num(dt(b["bar_time"]))
        o,h,l,c = [float(b[k]) for k in ("open", "high", "low", "close")]
        color = "#258e7a" if c >= o else "#c46b63"
        ax.vlines(x, l, h, color=color, lw=.8)
        ax.add_patch(Rectangle((x-5/1440, min(o,c)), 10/1440, max(abs(c-o),.025), color=color, alpha=.85))
    start, peak, entry = [mdates.date2num(dt(order[k])) for k in ("wave1_start_time", "wave1_peak_time", "event_at")]
    high_known = mdates.date2num(min(dt(p["known_at"]) for p in prior))
    first = next((p for p in prior if p["tf"] == "PERIOD_M15"), min(prior, key=lambda p:p["time"]))
    ax.scatter(mdates.date2num(dt(first["time"])), prior_price, color="#7c4fa0", zorder=6)
    ax.plot([high_known, entry], [prior_price]*2, color="#7c4fa0", ls="--", lw=1.5)
    ax.text(high_known+3/1440, prior_price+.15, "以前の高値 2288.35\nM15で02:00、H1で04:00から既知", color="#7c4fa0", fontsize=10)
    ax.plot([start,peak], [price("wave1_start_price"),price("wave1_peak_price")], color="#1685b5", lw=2)
    ax.scatter([start,peak], [price("wave1_start_price"),price("wave1_peak_price")], color="#1685b5", zorder=6)
    ax.annotate("①高値 2287.99\n以前の高値との差 0.36", (peak,price("wave1_peak_price")), xytext=(12,26),
                textcoords="offset points", fontsize=10, color="#1685b5", arrowprops=dict(arrowstyle="-",color="#1685b5"))
    ax.plot([start, entry], [price("wave1_start_price")]*2, color="#888888", ls=":", lw=1)
    ax.text(start+3/1440, price("wave1_start_price")-.5, "間の安値 2276.72：エントリー時点では未突破", fontsize=9, color="#666666")
    ax.scatter(entry,price("entry_price"),marker="^",s=75,color="#267442",zorder=6)
    ax.annotate("07:05 買い 2286.14\n以前の高値まで0.67R", (entry,price("entry_price")),xytext=(-168,-38),
                textcoords="offset points",fontsize=10,color="#267442",arrowprops=dict(arrowstyle="-",color="#267442"))
    plan_end=entry+35/1440
    ax.plot([entry,plan_end], [price("tp_price")]*2,color="#267442",ls="--",lw=1)
    ax.text(entry,price("tp_price")+.15,f'予定TP {price("tp_price"):.2f}：以前の高値より上',fontsize=10,color="#267442",ha="right")
    ax.axvline(entry,color="#999999",lw=.8)
    ax.set_xlim(mdates.date2num(dt(bars[0]["bar_time"]))-15/1440, plan_end+15/1440)
    ax.set_ylim(2275.5,2291.1)
    ax.xaxis.set_major_locator(mdates.HourLocator(interval=1))
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%H:%M"))
    ax.set_title("2024/04/03 07:05時点で知り得た情報：①は維持し、以前の高値との位置を別評価",fontsize=13)
    ax.set_ylabel("XAUUSD+ / M15")
    ax.grid(alpha=.18)
    fig.text(.01,.01,"エントリー後の足は未使用。①位置の確定は07:00。時刻は原本ログのブローカー時刻。予定TPは当時の注文計画。",fontsize=9,color="#666666")
    fig.tight_layout(rect=(0,.04,1,1))
    fig.savefig(OUT / "before_entry.png")
    plt.close(fig)
    print(json.dumps(summary,ensure_ascii=False))


if __name__ == "__main__":
    main()
