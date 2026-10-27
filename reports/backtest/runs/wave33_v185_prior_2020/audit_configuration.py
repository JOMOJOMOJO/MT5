"""Additional strict observed-config parity check; no strategy decisions.

Complements the frozen analyzer's all-deal baseline equality and cash/risk
checks. The baseline and the new OFF config must match in every value except
the run tag and its intentional input hash.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import shutil


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def config(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return {r["parameter"]:r["value"] for r in csv.DictReader(stream, delimiter=";")}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--batch",type=Path,required=True)
    batch=parser.parse_args().batch.resolve()
    repo=next(p for p in batch.parents if (p/"tools/wave33_visual").is_dir())
    source=repo/"reports/backtest/runs/wave33_v185_2020/20261026_100045_50909ab6/v185_b_scale_off/config.csv"
    current=batch/"v185_b_prior_off/config.csv"
    a,b=config(source),config(current)
    changes={k:[a.get(k),b.get(k)] for k in a.keys()|b.keys() if a.get(k)!=b.get(k)}
    unexpected={k:v for k,v in changes.items() if k not in {"resolved_run_tag","input_hash"}}
    fields=("symbol","upper_tf","lower_tf","point","tick_size","account_currency","symbol_currency_profit",
            "symbol_calc_mode","volume_min","volume_step","contract_size","stops_level","freeze_level",
            "risk_percent","reward_r","scale_out","terminal_build")
    result=dict(status="PASS" if not unexpected else "FAIL",method_sha256=sha(Path(__file__)),
                observed_parameters=len(a),unchanged_parameter_count=len(a)-len(changes),
                allowed_metadata_changes=changes,unexpected_changes=unexpected,
                economic_and_execution_fields={k:dict(reference=a.get(k),fresh_off=b.get(k),equal=a.get(k)==b.get(k)) for k in fields},
                reference_config_sha256=sha(source),fresh_config_sha256=sha(current),
                scope="Every observed config value compared; not limited to the selected economic fields shown. No result-based rule adjustment.")
    out=batch/"analysis";out.mkdir(exist_ok=True)
    (out/"strict_config_reproduction.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    if Path(__file__).resolve()!=(out/"audit_configuration.py").resolve():
        shutil.copy2(Path(__file__),out/"audit_configuration.py")
    print(json.dumps(result,ensure_ascii=False))
    return bool(unexpected)


if __name__=="__main__":
    raise SystemExit(main())
