#!/usr/bin/env python3
"""Append authoritative Step 15B rows and update manifest rollup metadata."""

from __future__ import annotations

import csv
import hashlib
import re
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
MANIFEST=ROOT/"docs/research/tick_shock/00_artifact_manifest.md"
INVENTORY=ROOT/"reports/research/tick_shock/step15b_changed_files.csv"


def owner(path: str) -> str:
    return subprocess.check_output(["git","-C",str(ROOT),"log","-1","--format=%H","--",path],text=True).strip()


def main() -> int:
    text=MANIFEST.read_text(encoding="utf-8-sig")
    head=subprocess.check_output(["git","-C",str(ROOT),"rev-parse","HEAD"],text=True).strip()
    branch=subprocess.check_output(["git","-C",str(ROOT),"branch","--show-current"],text=True).strip()
    replacements={
        r"- branch: `[^`]+`":f"- branch: `{branch}`",
        r"- status: `[^`]+`":"- status: `STEP15B_DEVELOPMENT_CONTROL_FUNNEL_COMPLETE`",
        r"- manifest_revision: `[^`]+`":"- manifest_revision: `15B`",
        r"- covered_steps: `[^`]+`":"- covered_steps: `01-15B`",
        r"- last_audited_commit: `[^`]+`":f"- last_audited_commit: `{head}`",
        r"- last_updated_at: `[^`]+`":"- last_updated_at: `2026-08-28T00:30:00+09:00`",
    }
    for pattern,value in replacements.items(): text=re.sub(pattern,value,text,count=1)
    existing_ids=set(re.findall(r"^\| (TS-[^ |]+) \|",text,flags=re.MULTILINE))
    existing_step15b=len([x for x in existing_ids if x.startswith("TS-S15B-")])
    if existing_step15b: raise SystemExit("Step 15B rows already present; refusing duplicate append")
    with INVENTORY.open(encoding="utf-8-sig",newline="") as h: items=list(csv.DictReader(h))
    updater="tools/tick_shock/update_step15b_manifest.py"
    if not any(r["path"]==updater for r in items):
        p=ROOT/updater;items.append({"path":updater,"classification":"step15b_source","bytes":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest().upper()})
    lines=[]
    for i,row in enumerate(sorted(items,key=lambda r:r["path"]),1):
        path=row["path"]; commit=owner(path)
        if len(commit)!=40: raise SystemExit(f"missing owning commit: {path}")
        kind="source" if row["classification"]=="step15b_source" else "generated evidence"
        lines.append(f"| TS-S15B-{i:03d} | 15B | `{path}` | {row['classification']} | matched control and strategy conversion funnel | {kind} | `{row['sha256']}` | yes | locked validation decision input | COMPLETE | Step 15B development only | {commit} |")
    before=len(re.findall(r"^\| TS-",text,flags=re.MULTILINE)); unique_before=len(set(re.findall(r"^\| TS-[^|]+\| [^|]+\| `([^`]+)`",text,flags=re.MULTILINE)))
    text=text.rstrip()+"\n\n"+"\n".join(lines)+"\n\n"
    paths=set(re.findall(r"^\| TS-[^|]+\| [^|]+\| `([^`]+)`",text,flags=re.MULTILINE))
    ids=re.findall(r"^\| (TS-[^ |]+) \|",text,flags=re.MULTILINE)
    text+=f"Step 15B appends {len(lines)} authoritative rows. The post-Step-15B rollup is {before+len(lines)} rows and {len(paths)} unique paths; artifact ID duplicates are {len(ids)-len(set(ids))}. Step 15A identities and strategy parameters remain unchanged; locked OOS is not authorized.\n"
    MANIFEST.write_text(text,encoding="utf-8")
    print(f"rows={before+len(lines)} paths={len(paths)} duplicates={len(ids)-len(set(ids))} prior_paths={unique_before}")
    return 0


if __name__=="__main__": raise SystemExit(main())
