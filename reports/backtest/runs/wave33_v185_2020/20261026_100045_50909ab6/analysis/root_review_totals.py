"""Independent stdlib check; does not import the frozen annual audit method."""
import csv
import hashlib
import json
import re
from collections import defaultdict
from datetime import datetime, timezone
from decimal import Decimal as D
from pathlib import Path

BATCH = Path(__file__).resolve().parents[1]


def main():
    review = []
    for arm in "ab":
        for policy in ("off", "on"):
            name = f"v185_{arm}_scale_{policy}"
            folder = BATCH / name
            assert (folder / "runtime_after.json").exists(), name
            raw = folder / "raw_deals.csv"
            with raw.open(encoding="utf-8-sig", newline="") as stream:
                deals = list(csv.DictReader(stream, delimiter=";"))
            assert len(deals) == len({r["deal_ticket"] for r in deals}), name
            groups = defaultdict(list)
            for row in deals:
                assert None not in row and None not in row.values(), name
                assert row["entry"] in ("DEAL_ENTRY_IN", "DEAL_ENTRY_OUT", "DEAL_ENTRY_OUT_BY"), name
                groups[row["position_id"]].append(row)
            positions = []
            for position_id, group in groups.items():
                entered = sum((D(r["volume"]) for r in group if r["entry"] == "DEAL_ENTRY_IN"), D(0))
                exited = sum((D(r["volume"]) for r in group if r["entry"] != "DEAL_ENTRY_IN"), D(0))
                assert entered > 0 and entered == exited, (name, position_id)
                cash = {k: sum((D(r[k]) for r in group), D(0)) for k in ("profit", "commission", "swap", "fee")}
                exits = [r for r in group if r["entry"] != "DEAL_ENTRY_IN"]
                last = max(exits, key=lambda r: (int(r["time_msc"]), int(r["deal_ticket"])))
                positions.append(dict(position_id=position_id, net=sum(cash.values()),
                                      last_exit=(int(last["time_msc"]), int(last["deal_ticket"]))))
            positions.sort(key=lambda p: p["last_exit"])
            net = sum((p["net"] for p in positions), D(0))
            profit = sum((p["net"] for p in positions if p["net"] > 0), D(0))
            loss = -sum((p["net"] for p in positions if p["net"] < 0), D(0))
            streak = longest = 0
            for p in positions:
                streak = streak + 1 if p["net"] < 0 else 0
                longest = max(longest, streak)
            content = (folder / "report.htm").read_bytes()
            text = content.decode("utf-16" if content[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8-sig")
            native = D(re.search(r"総損益:</td>\s*<td[^>]*><b>([^<]+)</b>", text).group(1).replace(" ", "").replace(",", ""))
            assert native == net, (name, native, net)
            review.append(dict(run_id=name, status="PASS", position_count=len(positions), raw_deal_count=len(deals),
                               wins=sum(p["net"] > 0 for p in positions), losses=sum(p["net"] < 0 for p in positions),
                               net=str(net), native_net=str(native), raw_minus_native_net=str(net-native),
                               position_pf=float(profit / loss), maximum_consecutive_losing_positions=longest,
                               raw_sha256=hashlib.sha256(raw.read_bytes()).hexdigest()))
    output = dict(status="PASS", reviewer="root independent stdlib totals",
                  reviewed_at_utc=datetime.now(timezone.utc).isoformat(),
                  method="All unique deals grouped by position; Decimal cash includes entry commission and all profit/commission/swap/fee. Native total net independently parsed. Streaks use final exit order; zero resets streak.",
                  runs=review)
    (BATCH / "root_final_totals.json").write_text(json.dumps(output, indent=2), encoding="utf-8")
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
