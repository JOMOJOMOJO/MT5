"""Plot booked deal cash on the preserved MT5 source/broker clock.

Auxiliary artifact only. This does not modify the frozen annual audit method,
inputs, reports, or source ledgers, and does not reconstruct floating equity.
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
    args = parser.parse_args()
    batch = args.batch.resolve()
    output = batch / "analysis"
    audit = json.loads((output / "summary.json").read_text(encoding="utf-8-sig"))
    if audit["status"] != "PASS" or audit["scope"] != "FIXED_ANNUAL_2020":
        raise RuntimeError("A PASS annual audit is required before plotting")
    figure, axes = plt.subplots(2, 1, figsize=(12, 8), sharex=True, sharey=True)
    colors = {"off": "#7b8793", "on": "#007f9e"}
    exported = []
    evidence = {}
    epoch = datetime(1970, 1, 1)  # Nominal MT5-encoded clock; no timezone conversion.
    year_start, year_end = datetime(2020, 1, 1), datetime(2021, 1, 1)
    for axis, arm in zip(axes, ("a", "b")):
        for policy in ("off", "on"):
            name = f"v185_{arm}_scale_{policy}"
            raw_path = batch / name / "raw_deals.csv"
            with raw_path.open(encoding="utf-8-sig", newline="") as stream:
                deals = list(csv.DictReader(stream, delimiter=";"))
            deals.sort(key=lambda row: (int(row["time_msc"]), int(row["deal_ticket"])))
            balance = D("5000")
            times, values = [year_start], [float(balance)]
            for deal in deals:
                at = epoch + timedelta(milliseconds=int(deal["time_msc"]))
                cash = sum((D(deal[k]) for k in ("profit", "commission", "swap", "fee")), D(0))
                balance += cash
                times.append(at)
                values.append(float(balance))
                exported.append(dict(run=name, deal_ticket=deal["deal_ticket"], position_id=deal["position_id"],
                    time_msc=deal["time_msc"], source_clock=at.isoformat(sep=" ", timespec="milliseconds"),
                    entry=deal["entry"], profit=deal["profit"], commission=deal["commission"],
                    swap=deal["swap"], fee=deal["fee"], deal_cash=cash, balance=balance))
            expected = D("5000") + D(str(audit["runs"][name]["native"]["net"]))
            if abs(balance-expected) > D("0.011"):
                raise RuntimeError(f"Final balance does not reconcile: {name}")
            times.append(year_end)
            values.append(float(balance))
            axis.step(times, values, where="post", color=colors[policy], linewidth=1.45,
                      label=f"Scale-out {policy.upper()}  |  final {balance:,.2f} USD")
            evidence[name] = dict(raw_deals_sha256=sha(raw_path), deals=len(deals),
                                  final_balance=str(balance), native_final_balance=str(expected))
        axis.set_title("A  |  M15 / M5" if arm == "a" else "B  |  M5 / M1", loc="left", fontsize=12, weight="bold")
        axis.axhline(5000, color="#c3cad0", linestyle="--", linewidth=0.8)
        axis.set_ylabel("Booked balance (USD)")
        axis.grid(axis="y", color="#e8ebee", linewidth=0.8)
        axis.spines[["top", "right"]].set_visible(False)
        axis.legend(loc="lower left", frameon=False, fontsize=9)
    axes[-1].xaxis.set_major_locator(mdates.MonthLocator(interval=2))
    axes[-1].xaxis.set_major_formatter(mdates.DateFormatter("%b %Y"))
    axes[-1].set_xlim(year_start, year_end)
    axes[-1].set_xlabel("MT5 source / broker clock (no UTC or JST conversion)")
    figure.suptitle("2020 XAUUSD+  |  cash booked at each native deal", fontsize=15, weight="bold", y=0.98)
    figure.text(0.07, 0.015, "Initial balance: 5,000 USD per separate run. Partial exits are booked at their actual deal time.\nFloating P/L is excluded: this is not an equity curve.", fontsize=9, color="#56616b")
    figure.tight_layout(rect=(0.02, 0.065, 1, 0.95))
    image = output / "booked_balance_comparison.png"
    figure.savefig(image, dpi=160, facecolor="white")
    plt.close(figure)
    with (output / "balance_cashflows.csv").open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(exported[0]))
        writer.writeheader()
        writer.writerows(exported)
    manifest = dict(scope="AUXILIARY_BOOKED_BALANCE_NOT_EQUITY", initial_per_run=5000,
        clock="MT5 source/broker encoded nominal clock; no timezone conversion",
        method_sha256=sha(Path(__file__)), image_sha256=sha(image),
        annual_audit_summary_sha256=sha(output/"summary.json"),
        cashflow_csv_sha256=sha(output/"balance_cashflows.csv"), runs=evidence)
    (output / "balance_plot_manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    if Path(__file__).resolve() != (output/"plot_balance.py").resolve():
        shutil.copy2(Path(__file__), output/"plot_balance.py")
    print(json.dumps(dict(status="PASS", image=str(image), runs=evidence)))


if __name__ == "__main__":
    main()
