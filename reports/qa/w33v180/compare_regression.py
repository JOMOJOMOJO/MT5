"""Compare frozen v1.71 native runs with v1.80 both-feature-OFF runs."""
import argparse
import csv
import json
from pathlib import Path


def rows(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream, delimiter=";"))


def compare(baseline, batch):
    result = {"status":"PASS", "scope":"Frozen v1.71 EX5 versus v1.80 both flags OFF; original fields only", "arms":{}}
    for arm in "ab":
        details = {}
        for kind in ("events", "upper_bars", "lower_bars", "opposite_ticks"):
            old, new = rows(baseline/arm/f"{kind}.csv"), rows(batch/f"v180_{arm}_base/{kind}.csv")
            differences = []
            for i, (left, right) in enumerate(zip(old,new)):
                diff = {k:{"v171":v,"v180":right.get(k)} for k,v in left.items() if v != right.get(k)}
                if diff and len(differences)<10:
                    differences.append({"row":i+2,"differences":diff})
            passed = len(old)==len(new) and not differences
            details[kind] = dict(v171_rows=len(old), v180_rows=len(new), compared_original_columns=len(old[0]) if old else 0, equal=passed, first_mismatches=differences)
            if not passed:
                result["status"]="FAIL"
        cfg = {r["parameter"]:r["value"] for r in rows(batch/f"v180_{arm}_base/config.csv")}
        details["both_features_disabled"] = cfg["cancel_connected_opposite"]==cfg["extend_tp_to_wave1"]=="false"
        if not details["both_features_disabled"]:
            result["status"]="FAIL"
        result["arms"][arm.upper()]=details
    return result


if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--baseline",type=Path,required=True);p.add_argument("--batch",type=Path,required=True);p.add_argument("--out",type=Path,required=True);a=p.parse_args()
    r=compare(a.baseline,a.batch)
    a.out.write_text(json.dumps(r,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(r));raise SystemExit(r["status"]!="PASS")
