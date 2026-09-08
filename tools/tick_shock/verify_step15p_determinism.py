#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import pandas as pd


def normalized_hash(path: Path) -> tuple[str, int]:
    if not path.exists():path=path.with_suffix(path.suffix+".gz")
    frame = pd.read_csv(path, low_memory=False)
    frame = frame.drop(columns=[c for c in ("episode_id", "event_id") if c in frame])
    sort = [c for c in ("symbol", "t0_msc", "offset_index", "tp_index", "sl_index") if c in frame]
    frame = frame.sort_values(sort).reset_index(drop=True)
    payload = frame.to_csv(index=False, lineterminator="\n").encode()
    return hashlib.sha256(payload).hexdigest().upper(), len(frame)


def main() -> None:
    parser=argparse.ArgumentParser();parser.add_argument("primary",type=Path);parser.add_argument("rerun",type=Path);parser.add_argument("output",type=Path);args=parser.parse_args()
    a,na=normalized_hash(args.primary/"symmetric_oco_scenarios.csv");b,nb=normalized_hash(args.rerun/"symmetric_oco_scenarios.csv")
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text("artifact,primary_rows,rerun_rows,primary_normalized_sha256,rerun_normalized_sha256,status\n"+f"symmetric_oco_scenarios,{na},{nb},{a},{b},{'PASS' if a==b and na==nb else 'FAIL'}\n",encoding="utf-8")
    if a!=b or na!=nb:raise SystemExit("deterministic rerun mismatch")


if __name__ == "__main__":main()
