"""Independent raw-deal cash audit; no import of the annual parser or EA state."""
import argparse
import csv
import hashlib
import json
import re
from collections import defaultdict
from decimal import Decimal as D
from pathlib import Path


def audit(folder):
    raw = folder / "raw_deals.csv"
    with raw.open(encoding="utf-8-sig", newline="") as stream:
        rows = list(csv.DictReader(stream, delimiter=";"))
    assert len(rows) == len({r["deal_ticket"] for r in rows})
    groups = defaultdict(list)
    for row in rows:
        assert None not in row and None not in row.values()
        assert row["entry"] in ("DEAL_ENTRY_IN", "DEAL_ENTRY_OUT", "DEAL_ENTRY_OUT_BY")
        groups[row["position_id"]].append(row)
    positions = []
    for position_id, deals in groups.items():
        ins = [r for r in deals if r["entry"] == "DEAL_ENTRY_IN"]
        outs = [r for r in deals if r["entry"] != "DEAL_ENTRY_IN"]
        entered = sum((D(r["volume"]) for r in ins), D(0))
        exited = sum((D(r["volume"]) for r in outs), D(0))
        assert entered > 0 and entered == exited
        cash = sum((sum((D(r[k]) for k in ("profit", "commission", "swap", "fee")), D(0)) for r in deals), D(0))
        last = max(outs, key=lambda r: (int(r["time_msc"]), int(r["deal_ticket"])))
        positions.append(dict(position_id=position_id, cash=cash, order=(int(last["time_msc"]), int(last["deal_ticket"]))))
    positions.sort(key=lambda p: p["order"])
    net = sum((p["cash"] for p in positions), D(0))
    winning = sum((p["cash"] for p in positions if p["cash"] > 0), D(0))
    losing = -sum((p["cash"] for p in positions if p["cash"] < 0), D(0))
    streak = longest = 0
    for p in positions:
        streak = streak + 1 if p["cash"] < 0 else 0
        longest = max(longest, streak)
    report = (folder / "report.htm").read_bytes()
    text = report.decode("utf-16" if report[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8-sig")
    native = D(re.search(r"総損益:</td>\s*<td[^>]*><b>([^<]+)</b>", text).group(1).replace(" ", "").replace(",", ""))
    assert native == net
    return dict(run=folder.name, status="PASS", positions=len(positions), deals=len(rows), net=str(net), native_net=str(native),
                pf=str(winning / losing) if losing else None, wins=sum(p["cash"] > 0 for p in positions),
                losses=sum(p["cash"] < 0 for p in positions), max_loss_streak=longest,
                raw_sha256=hashlib.sha256(raw.read_bytes()).hexdigest())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch", type=Path, required=True)
    args = parser.parse_args()
    names = ("v185_b_prior_off", "v185_b_prior_on")
    results = [audit(args.batch / name) for name in names]
    summary = dict(status="PASS", scope="INDEPENDENT_ALL_DEALS_GROUPED_BY_POSITION_INCLUDING_ENTRY_COSTS", runs=results)
    (args.batch / "analysis/root_independent_totals.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
