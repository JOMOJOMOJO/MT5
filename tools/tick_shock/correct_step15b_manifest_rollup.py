#!/usr/bin/env python3
"""Correct the Step 15B manifest inventory after generic-path audit."""

from __future__ import annotations

import csv
import hashlib
import re
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
MANIFEST=ROOT/"docs/research/tick_shock/00_artifact_manifest.md"
INVENTORY=ROOT/"reports/research/tick_shock/step15b_changed_files.csv"
SELF="tools/tick_shock/correct_step15b_manifest_rollup.py"
SELF_REFERENTIAL={"reports/research/tick_shock/step15b_changed_files.csv","reports/research/tick_shock/step15b_output_hashes.csv"}


def owner(path: str) -> str:
    return subprocess.check_output(["git","-C",str(ROOT),"log","-1","--format=%H","--",path],text=True).strip()


def main() -> int:
    text=MANIFEST.read_text(encoding="utf-8-sig")
    # Hash inventories cannot contain their own stable digest. Remove the two
    # initial rows instead of pretending a self-referential SHA can validate.
    text="\n".join(line for line in text.splitlines() if not any(f"`{p}`" in line for p in SELF_REFERENTIAL))+"\n"
    text=re.sub(r"Step 15B appends 268 authoritative rows\.[^\n]*\n","Step 15B initial path-name-filtered rollup was superseded by the audited generic-path correction below.\n",text)
    with INVENTORY.open(encoding="utf-8-sig",newline="") as h: items=list(csv.DictReader(h))
    p=ROOT/SELF;items.append({"path":SELF,"classification":"step15b_source","bytes":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest().upper()})
    lines=[]
    for i,row in enumerate(sorted(items,key=lambda r:r["path"]),1):
        commit=owner(row["path"])
        if len(commit)!=40: raise SystemExit(f"missing owning commit: {row['path']}")
        kind="source" if row["classification"]=="step15b_source" else "generated evidence"
        lines.append(f"| TS-S15B-C{i:03d} | 15B | `{row['path']}` | {row['classification']} | audited complete Step 15B dependency/evidence rollup | {kind} | `{row['sha256']}` | yes | locked validation decision input | COMPLETE | generic paths included; self-hash files excluded | {commit} |")
    head=subprocess.check_output(["git","-C",str(ROOT),"rev-parse","HEAD"],text=True).strip()
    text=re.sub(r"- last_audited_commit: `[^`]+`",f"- last_audited_commit: `{head}`",text,count=1)
    text=text.rstrip()+"\n\n"+"\n".join(lines)+"\n\n"
    ids=re.findall(r"^\| (TS-[^ |]+) \|",text,flags=re.MULTILINE)
    paths=re.findall(r"^\| TS-[^|]+\| [^|]+\| `([^`]+)`",text,flags=re.MULTILINE)
    text+=f"Step 15B corrected rollup adds {len(lines)} latest rows after removing two self-referential hash-inventory rows. Final rollup: {len(ids)} rows, {len(set(paths))} unique paths, artifact ID duplicates {len(ids)-len(set(ids))}.\n"
    MANIFEST.write_text(text,encoding="utf-8")
    print(f"rows={len(ids)} paths={len(set(paths))} duplicates={len(ids)-len(set(ids))}")
    return 0


if __name__=="__main__": raise SystemExit(main())
