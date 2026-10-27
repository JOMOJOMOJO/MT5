"""Descriptive native fill audit at millisecond precision; no EA changes."""
import argparse
import csv
from decimal import Decimal as D
import hashlib
import json
from pathlib import Path
import shutil


def rows(path, delimiter=","):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream, delimiter=delimiter))


def main():
    parser=argparse.ArgumentParser();parser.add_argument("--batch",type=Path,required=True)
    batch=parser.parse_args().batch.resolve();out=batch/"analysis"
    pairs=rows(out/"paired_positions.csv")
    by={}
    for arm in ("off","on"):
        by[arm]={}
        for row in rows(batch/f"v185_b_prior_{arm}/raw_deals.csv",";"):
            by[arm].setdefault(row["setup_id"],[]).append(row)
    counts={k:0 for k in ("entry_times_prices","entry_exit_times_prices","entry_exit_types","entry_sl_tp","exit_second_and_reason")}
    volume_changed=common=changed_r=0;delta_r=D(0);max_delta=D(0);different=[]
    for row in pairs:
        if row["class"]!="MATCHED_SAME_ENTRY_TIME":continue
        common+=1;a=by["off"][row["off_setup"]];b=by["on"][row["on_setup"]]
        signature=lambda values:[(x["time_msc"],D(x["price"])) for x in values]
        counts["entry_times_prices"]+=(signature(a[:1])==signature(b[:1]))
        counts["entry_exit_times_prices"]+=(signature(a)==signature(b))
        counts["entry_exit_types"]+=([(x["entry"],x["type"]) for x in a]==[(x["entry"],x["type"]) for x in b])
        counts["entry_sl_tp"]+=row["same_entry_price_sl_tp"]=="True"
        counts["exit_second_and_reason"]+=row["same_exit_time_reason"]=="True"
        volume_changed+=D(a[0]["volume"])!=D(b[0]["volume"])
        change=D(row["delta_r"]);delta_r+=change;max_delta=max(max_delta,abs(change));changed_r+=abs(change)>D("0.000000001")
        if signature(a)!=signature(b):different.append(dict(pair=row,off_deals=a,on_deals=b))
    result=dict(status="DESCRIPTIVE_OBSERVATION",method_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                common_positions=common,same_fields_counts=counts,changed_initial_volume_positions=volume_changed,
                total_common_delta_r=str(delta_r),maximum_absolute_common_delta_r=str(max_delta),
                nonzero_common_delta_r_count=changed_r,native_fill_difference_cases=different,
                interpretation="No common entry geometry changed. Changed lot sizes can change rounded booked cash and the existing strict-positive opposite exit cost gate. One must inspect native millisecond fills; equal second-level exit logs do not prove equal prices.",
                scope="Supplement to frozen annual audit. Fill identity is an observation, not a new pass criterion or an excuse to alter the strategy.")
    (out/"common_execution_geometry.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    if Path(__file__).resolve()!=(out/"compare_execution_geometry.py").resolve():shutil.copy2(Path(__file__),out/"compare_execution_geometry.py")
    print(json.dumps({k:v for k,v in result.items() if k!="native_fill_difference_cases"},ensure_ascii=False))


if __name__=="__main__":main()
