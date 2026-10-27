"""Auxiliary plot of booked cash; not part of the frozen decision method.

Source ledgers remain read-only. Floating equity and timezone conversion are
deliberately absent. The complete deal cash is exported beside the image.
"""
from __future__ import annotations

import argparse
import csv
from datetime import datetime, timedelta
from decimal import Decimal as D
import hashlib
import json
from pathlib import Path
import shutil

import matplotlib
matplotlib.use("Agg")
import matplotlib.dates as mdates
import matplotlib.pyplot as plt


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch", type=Path, required=True)
    batch = parser.parse_args().batch.resolve()
    output = batch/"analysis"
    audit = json.loads((output/"summary.json").read_text(encoding="utf-8-sig"))
    if audit["status"] != "PASS" or audit["scope"] != "FIXED_KNOWN_2020_PRIOR_LEVEL_COMPARISON":
        raise RuntimeError("A PASS full-year audit is required")
    figure, axis = plt.subplots(figsize=(12, 5.5))
    exported, evidence = [], {}
    epoch = datetime(1970,1,1)
    year_start, year_end = datetime(2020,1,1), datetime(2021,1,1)
    for policy, color in (("off", "#778592"), ("on", "#007f9e")):
        name = "v185_b_prior_"+policy
        source = batch/name/"raw_deals.csv"
        with source.open(encoding="utf-8-sig", newline="") as stream:
            deals = list(csv.DictReader(stream, delimiter=";"))
        deals.sort(key=lambda row: (int(row["time_msc"]),int(row["deal_ticket"])))
        balance = D(5000)
        times, values = [year_start], [float(balance)]
        for deal in deals:
            at = epoch+timedelta(milliseconds=int(deal["time_msc"]))
            cash = sum((D(deal[k]) for k in ("profit", "commission", "swap", "fee")),D(0))
            balance += cash
            times.append(at); values.append(float(balance))
            exported.append(dict(run=name, deal_ticket=deal["deal_ticket"], position_id=deal["position_id"],
                time_msc=deal["time_msc"], source_clock=at.isoformat(sep=" ",timespec="milliseconds"),
                entry=deal["entry"], profit=deal["profit"], commission=deal["commission"],
                swap=deal["swap"], fee=deal["fee"], deal_cash=cash, balance=balance))
        expected = D(5000)+D(str(audit["runs"][name]["native"]["net"]))
        if abs(balance-expected)>D("0.011"):
            raise RuntimeError("Final booked balance mismatch: "+name)
        times.append(year_end); values.append(float(balance))
        axis.step(times,values,where="post",color=color,linewidth=1.55,
                  label=f"Prior-level filter {policy.upper()}  |  final {balance:,.2f} USD")
        evidence[name]=dict(raw_deals_sha256=sha(source),deals=len(deals),final_balance=str(balance),native_final_balance=str(expected))
    axis.axhline(5000,color="#c3cad0",linestyle="--",linewidth=.8)
    axis.set_ylabel("Booked balance (USD)")
    axis.grid(axis="y",color="#e8ebee",linewidth=.8)
    axis.spines[["top","right"]].set_visible(False)
    axis.legend(loc="lower left",frameon=False,fontsize=10)
    axis.xaxis.set_major_locator(mdates.MonthLocator(interval=2))
    axis.xaxis.set_major_formatter(mdates.DateFormatter("%b %Y"))
    axis.set_xlim(year_start,year_end)
    axis.set_xlabel("MT5 source / broker clock (no UTC or JST conversion)")
    axis.set_title("2020 XAUUSD+  |  M5 / M1  |  scale-out OFF",loc="left",fontsize=15,weight="bold",pad=14)
    figure.text(.08,.02,"Separate 5,000 USD runs. Actual native deal cash includes commission, swap and fee.\nBooked balance excludes floating P/L; generated ticks, known 2020 period.",fontsize=9,color="#56616b")
    figure.tight_layout(rect=(.02,.09,1,1))
    image=output/"booked_balance_comparison.png"
    figure.savefig(image,dpi=160,facecolor="white");plt.close(figure)
    with (output/"balance_cashflows.csv").open("w",encoding="utf-8-sig",newline="") as stream:
        writer=csv.DictWriter(stream,fieldnames=list(exported[0]));writer.writeheader();writer.writerows(exported)
    manifest=dict(scope="AUXILIARY_BOOKED_BALANCE_NOT_EQUITY",initial_per_run=5000,
                  clock="Nominal MT5 source/broker clock; no timezone conversion",
                  method_sha256=sha(Path(__file__)),image_sha256=sha(image),
                  annual_audit_summary_sha256=sha(output/"summary.json"),cashflow_csv_sha256=sha(output/"balance_cashflows.csv"),runs=evidence)
    (output/"balance_plot_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    if Path(__file__).resolve()!=(output/"plot_balance.py").resolve():
        shutil.copy2(Path(__file__),output/"plot_balance.py")
    print(json.dumps(dict(status="PASS",image=str(image),runs=evidence)))


if __name__=="__main__":
    main()
