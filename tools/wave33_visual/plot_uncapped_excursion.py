"""Independent CSV audit and plots for the uncapped price-path diagnostic.

Does not import its producer, alter EA code, launch MT5, or estimate tradable PnL.
"""
from __future__ import annotations

import argparse
import bisect
import csv
import hashlib
import json
import math
import statistics
from datetime import datetime, timedelta
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import numpy as np


HORIZONS = ("1h", "4h", "24h", "uncapped")
THRESHOLDS = (1, 2, 3, 5, 10, 20, 50)
COLORS = ("#89929b", "#c17616", "#2979b9", "#15805a")


def read_csv(path: Path, delimiter: str = ",") -> list[dict]:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream, delimiter=delimiter))


def dt(text: str) -> datetime:
    return datetime.strptime(text, "%Y.%m.%d %H:%M:%S.%f" if "." in text[19:] else "%Y.%m.%d %H:%M:%S")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def percentile(values: list[float], q: float) -> float:
    ordered = sorted(values)
    location = (len(ordered) - 1) * q
    fraction, index = math.modf(location)
    index = int(index)
    return ordered[index] * (1-fraction) + ordered[min(index+1, len(ordered)-1)] * fraction


def independent_audit(rows: list[dict], summary: dict) -> dict:
    checks = []
    epsilon=float(summary.get("threshold_numerical_epsilon_r",0))
    def check(label: str, condition: bool):
        checks.append(dict(check=label, passed=bool(condition)))
    check("population_334", len(rows) == summary["aggregate"]["count"] == 334)
    check("unique_setup_and_position", len({r["setup_id"] for r in rows}) == len(rows) == len({r["position_id"] for r in rows}))
    for horizon in HORIZONS:
        for bound in ("lower", "upper"):
            values = [float(r[f"{horizon}_{bound}_max_r"]) for r in rows]
            expected = summary["aggregate"][horizon][bound]
            independent = dict(median=statistics.median(values), maximum=max(values),
                               p75=percentile(values, .75), p90=percentile(values, .9), p95=percentile(values, .95))
            for name, value in independent.items():
                check(f"{horizon}_{bound}_{name}", math.isclose(value, expected[name], abs_tol=1e-9))
            for threshold in THRESHOLDS:
                count = sum(x+epsilon >= threshold for x in values)
                check(f"{horizon}_{bound}_reach_{threshold}", count == expected["reach_counts"][str(threshold)])
                # Audit saved first-hit presence separately from the aggregated maxima.
                present = sum(bool(r[f"{horizon}_{bound}_reach_{threshold}r_bar"]) for r in rows)
                check(f"{horizon}_{bound}_first_hit_{threshold}", present == count)
    for row in rows:
        for horizon in HORIZONS:
            check(f"{row['position_id']}_{horizon}_bound_order", 0 <= float(row[f"{horizon}_lower_max_r"]) <= float(row[f"{horizon}_upper_max_r"]) + 1e-9)
        for bound in ("lower", "upper"):
            values = [float(row[f"{horizon}_{bound}_max_r"]) for horizon in HORIZONS]
            check(f"{row['position_id']}_{bound}_horizon_order", all(a <= b+1e-9 for a,b in zip(values,values[1:])))
        if row.get("known_native_sl_at"):
            native_end=dt(row["known_native_sl_at"])
            for horizon in HORIZONS:
                for bound in ("lower","upper"):
                    check(f"{row['position_id']}_{horizon}_{bound}_native_sl_cutoff",dt(row[f"{horizon}_{bound}_end_at"])<=native_end)
                    peak=row.get(f"{horizon}_{bound}_peak_bar_time")
                    check(f"{row['position_id']}_{horizon}_{bound}_peak_before_native_sl",not peak or dt(peak)<native_end)
    check("190_observed_native_sl_barriers",sum(bool(r.get("known_native_sl_at")) for r in rows)==190)
    for group in summary["groups"]:
        if group["group_type"] == "actual_outcome":
            sample = [r for r in rows if ("WIN" if float(r["net_cash"]) > 0 else "LOSS" if float(r["net_cash"]) < 0 else "FLAT") == group["group"]]
        else:
            sample = [r for r in rows if r[group["group_type"]] == group["group"]]
        check(f"group_{group['group_type']}_{group['group']}_count", len(sample) == group["count"])
        for horizon in HORIZONS:
            for bound in ("lower", "upper"):
                values = [float(r[f"{horizon}_{bound}_max_r"]) for r in sample]
                for threshold in THRESHOLDS:
                    check(f"group_{group['group_type']}_{group['group']}_{horizon}_{bound}_{threshold}", sum(x+epsilon >= threshold for x in values) == group[horizon][bound]["reach_counts"][str(threshold)])
    failures = [x for x in checks if not x["passed"]]
    return dict(status="PASS" if not failures else "FAIL", checks=len(checks), failures=failures,
                threshold_epsilon_r=epsilon,note="Independent CSV reaggregation only; no imported producer and no tick-execution claim.")


def reach_figure(rows: list[dict], out: Path):
    count = len(rows)
    maximum = max(float(r["uncapped_upper_max_r"]) for r in rows)
    xmax = max(10, math.ceil(maximum))
    fig, axes = plt.subplots(1, 2, figsize=(13.5, 6.2), sharey=True, gridspec_kw={"width_ratios":[1, 1.2]})
    for ax, grid in zip(axes, (np.linspace(0, 10, 1601), np.geomspace(1, xmax, 2001))):
        for horizon, color in zip(HORIZONS, COLORS):
            lower = np.array([float(r[f"{horizon}_lower_max_r"]) for r in rows])
            upper = np.array([float(r[f"{horizon}_upper_max_r"]) for r in rows])
            yl = np.array([(lower >= x).sum() * 100 / count for x in grid])
            yu = np.array([(upper >= x).sum() * 100 / count for x in grid])
            label = "Until initial SL / data end" if horizon == "uncapped" else horizon
            ax.plot(grid, yl, color=color, linewidth=1.8, label=label)
            ax.plot(grid, yu, color=color, linewidth=1.0, linestyle="--", alpha=.8)
            ax.fill_between(grid, yl, yu, color=color, alpha=.10)
        ax.grid(alpha=.22)
        ax.set_ylim(0, 101)
        ax.set_xlabel("Favorable movement / original price risk (R)")
    axes[0].set_xlim(0, 10)
    axes[0].set_ylabel("Share of all original entries reaching R (%)")
    axes[0].set_title("Main distribution: 0 to 10R")
    axes[1].set_xscale("log")
    axes[1].set_xlim(1, xmax)
    axes[1].set_title(f"Full observed tail: maximum {maximum:.2f}R (log R axis)")
    ticks = sorted({x for x in (1,2,3,5,10,20,50,100,200,500,1000,xmax) if 1<=x<=xmax})
    axes[1].set_xticks(ticks, [str(x) for x in ticks])
    axes[0].legend(loc="upper right", framealpha=.92, fontsize=9)
    fig.suptitle(f"XAUUSD+ 2020 | M5/M1 | {count} original fills | TP removed for price-path diagnosis", fontsize=13)
    fig.text(.055,.025,"Solid / dashed: OHLC-order lower / upper estimates. Bid proxy; no Ask, trading costs, opposite-W1 exit or executable PnL.\nSource/broker clock. Original SL is fixed. Missing data and year-end can censor paths.", fontsize=9, color="#434b53")
    fig.tight_layout(rect=(0,.095,1,.94))
    fig.savefig(out/"reach_distribution.png", dpi=155, facecolor="white")
    plt.close(fig)


def path_figures(rows: list[dict], bars_path: Path, source_positions_path: Path, opposite: dict, out: Path):
    source_positions = {r["setup_id"]:r for r in read_csv(source_positions_path) if r["run"] == "v185_b_scale_off"}
    bars = read_csv(bars_path,";")
    starts = [dt(r["bar_time"]) for r in bars]
    cases = sorted(rows, key=lambda r:(-float(r["uncapped_lower_max_r"]),r["entry_at"]))[:3]
    metadata = []
    for rank, row in enumerate(cases, 1):
        entry = float(row["entry_price"])
        risk = float(row["initial_price_risk"])
        sign = 1 if row["direction"] == "LONG" else -1
        start = dt(row["entry_exact_at"])
        end = dt(row["uncapped_upper_end_at"])
        lo = max(0,bisect.bisect_right(starts,start)-1)
        hi = bisect.bisect_left(starts,end)
        sample = bars[lo:hi]
        # The final SL bar is shown for context; favorable extrema there belong only to the upper estimate.
        times = [dt(r["bar_time"]) for r in sample]
        close = [sign*(float(r["close"])-entry)/risk for r in sample]
        low = [min(sign*(float(r["low"])-entry)/risk,sign*(float(r["high"])-entry)/risk) for r in sample]
        high = [max(sign*(float(r["low"])-entry)/risk,sign*(float(r["high"])-entry)/risk) for r in sample]
        planned_tp_r = sign*(float(source_positions[row["setup_id"]]["planned_tp"])-entry)/risk
        source = opposite.get("by_setup",{}).get(row["setup_id"],{})
        first_opposite = dt(source["known_at"]) if source.get("known_at") else None
        actual = dt(row["actual_exit_exact_at"])
        fig, axes = plt.subplots(1,2,figsize=(15,6.4),gridspec_kw={"width_ratios":[1.3,1]})
        zoom_end=min(end,start+timedelta(hours=24))
        for ax, panel_end, title in zip(axes,(end,zoom_end),("Entire observed path", "First 24 hours (separate R scale)")):
            visible=[i for i,t in enumerate(times) if t<=panel_end]
            vt=[times[i] for i in visible]
            ax.fill_between(vt,[low[i] for i in visible],[high[i] for i in visible],color="#277db1",alpha=.18,label="M1 high/low range")
            ax.plot(vt,[close[i] for i in visible],color="#1d668f",linewidth=.9,label="M1 reference close")
            ax.axhline(-1,color="#bc3838",linewidth=1.4,label="Original SL (-1R)")
            ax.axhline(0,color="#52606d",linewidth=.9)
            ax.axhline(planned_tp_r,color="#15805a",linestyle="--",linewidth=1.2,label=f"Original TP ({planned_tp_r:.2f}R)")
            if start <= actual <= panel_end:
                ax.axvline(actual,color="#c17616",linewidth=1.3,linestyle="--",label="Actual exit")
            if first_opposite and start<=first_opposite<=panel_end:
                ax.axvline(first_opposite,color="#8454a2",linewidth=1.4,linestyle=":",label="Opposite W1 first known")
            ax.set_xlim(start,panel_end)
            ax.set_ylabel("Price movement / original risk (R)")
            ax.set_xlabel("Source/broker clock")
            ax.set_title(title,fontsize=10)
            ax.grid(alpha=.22)
            ax.xaxis.set_major_formatter(mdates.ConciseDateFormatter(ax.xaxis.get_major_locator()))
        ax=axes[0]
        peak = dt(row["uncapped_lower_peak_bar_time"]) if row.get("uncapped_lower_peak_bar_time") else None
        if peak:
            peak_r = float(row["uncapped_lower_max_r"])
            ax.scatter([peak],[peak_r],s=42,color="#15805a",zorder=5)
            label_right=(peak-start)/(end-start)<.65
            ax.annotate(f"{peak_r:.2f}R lower estimate",(peak,peak_r),xytext=(10 if label_right else -10,-22),textcoords="offset points",ha="left" if label_right else "right",fontsize=10,color="#11603f")
        fig.suptitle(f"Tail example {rank} | {row['direction']} | entry {row['entry_exact_at']} | lower {float(row['uncapped_lower_max_r']):.2f}R / upper {float(row['uncapped_upper_max_r']):.2f}R",fontsize=12)
        axes[1].legend(loc="upper left",fontsize=8.5,framealpha=.92)
        fig.text(.07,.02,"Illustrative tail case selected by largest lower MFE; not representative performance. TP and opposite-profit exits ignored in path.\nBid OHLC proxy only; Ask, spread, costs, fill ordering and executable profit are not reconstructed.",fontsize=9,color="#434b53")
        fig.subplots_adjust(left=.075,right=.985,bottom=.19,top=.80,wspace=.23)
        filename=f"tail_case_{rank:02d}.png"
        fig.savefig(out/filename,dpi=155,facecolor="white")
        plt.close(fig)
        metadata.append(dict(rank=rank,setup_id=row["setup_id"],figure=filename,entry=row["entry_exact_at"],direction=row["direction"],
                             lower_mfe_r=float(row["uncapped_lower_max_r"]),upper_mfe_r=float(row["uncapped_upper_max_r"]),
                             original_tp_r=planned_tp_r,actual_exit=row["actual_exit_exact_at"],first_opposite_known_at=source.get("known_at",""),
                             first_opposite_within_path=bool(first_opposite and start<=first_opposite<=end),source_bar_count=len(sample)))
    return metadata


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--analysis",type=Path,required=True)
    parser.add_argument("--bars",type=Path,required=True)
    parser.add_argument("--positions",type=Path,required=True)
    args=parser.parse_args()
    data=args.analysis/"data"
    csv_path=data/"positions_excursion.csv"
    summary_path=data/"summary.json"
    rows=read_csv(csv_path)
    summary=json.loads(summary_path.read_text(encoding="utf-8-sig"))
    opposite=json.loads((args.analysis/"opposite_sources.json").read_text(encoding="utf-8-sig"))
    out=args.analysis/"figures"
    out.mkdir(parents=True,exist_ok=True)
    audit=independent_audit(rows,summary)
    if audit["status"]!="PASS":
        raise AssertionError(audit)
    reach_figure(rows,out)
    cases=path_figures(rows,args.bars,args.positions,opposite,out)
    audit.update(cases=cases,source_hashes={str(p):digest(p) for p in [csv_path,summary_path,args.bars,args.positions,args.analysis/"opposite_sources.json",Path(__file__)]})
    (out/"independent_plot_audit.json").write_text(json.dumps(audit,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    print(json.dumps(dict(status=audit["status"],checks=audit["checks"],figures=4,cases=cases),ensure_ascii=False))


if __name__=="__main__":
    main()
