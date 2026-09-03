#!/usr/bin/env python3
"""Build Step 15L hash inventory and append idempotent manifest rows."""
from __future__ import annotations

import csv
import hashlib
import re
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
MANIFEST=ROOT/"docs/research/tick_shock/00_artifact_manifest.md"
OUT=ROOT/"reports/analysis/tick_shock/step15l"


def sha(path:Path)->str:
    h=hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda:handle.read(1024*1024),b""):h.update(block)
    return h.hexdigest().upper()


def tracked()->set[str]:
    result=subprocess.run(["git","ls-files"],cwd=ROOT,check=True,capture_output=True,text=True)
    return {x.replace("\\","/") for x in result.stdout.splitlines()}


def owner(path:str,known:set[str])->str:
    if path not in known:return "SELF"
    result=subprocess.run(["git","log","-1","--format=%H","--",path],cwd=ROOT,capture_output=True,text=True)
    return result.stdout.strip() or "SELF"


def artifacts()->list[Path]:
    paths:set[Path]=set()
    patterns=[
        "docs/research/tick_shock/15l_*","docs/devlog/2026-09-03-tickshock-step15l-*",
        "reports/analysis/tick_shock/step15l/*","reports/analysis/tick_shock/step15l_behavior_comparison.csv",
        "reports/backtest/runs/20260903_ts15l_clean_move_ml_r1_202503/*",
        "reports/tests/tick_shock/step15l_*","reports/tests/tick_shock/configs/step15l_*",
        "reports/tests/tick_shock/tester/step15l_*","reports/compile/tick_shock/step15l_*",
        "tools/tick_shock/*step15l*",
    ]
    for pattern in patterns:paths.update(x for x in ROOT.glob(pattern) if x.is_file())
    for rel in (
        "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5",
        "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.ex5",
        "mql/Include/TickShock/TickShockCleanMoveFeatures.mqh",
        "mql/Experts/tests/ExpectedValue_TickShock_CleanMoveFeatureHarness.mq5",
        "mql/Experts/tests/ExpectedValue_TickShock_CleanMoveFeatureHarness.ex5",
        "mql/Experts/tests/ExpectedValue_TickShock_EconomicPathHarness.ex5",
        "reports/tests/tick_shock/step15g_green/python_tests.log",
        "docs/research/tick_shock/00_artifact_manifest.md",
    ):
        if (ROOT/rel).is_file():paths.add(ROOT/rel)
    # Carry a current row for pre-existing local/generated paths whose latest
    # manifest SHA became stale during the regression rerun.
    if MANIFEST.is_file():
        latest={}
        for line in MANIFEST.read_text(encoding="utf-8-sig").splitlines():
            if line.startswith("| TS-"):
                cells=[x.strip() for x in line.strip().strip("|").split("|")]
                if len(cells)>=7:latest[cells[2].strip("`")]=cells[6].strip("`")
        for rel,expected in latest.items():
            path=ROOT/rel
            if path.is_file() and path!=MANIFEST and expected!="SELF" and sha(path)!=expected:paths.add(path)
    return sorted(paths,key=lambda p:p.relative_to(ROOT).as_posix())


def inventory(paths:list[Path],known:set[str])->None:
    target=OUT/"source_and_output_hashes.csv";rows=[]
    for path in paths:
        if path in (target,MANIFEST):continue
        rel=path.relative_to(ROOT).as_posix();rows.append({"path":rel,"bytes":path.stat().st_size,"sha256":sha(path),"owning_commit":owner(rel,known)})
    with target.open("w",encoding="utf-8",newline="") as handle:
        writer=csv.DictWriter(handle,fieldnames=("path","bytes","sha256","owning_commit"));writer.writeheader();writer.writerows(rows)


def update(paths:list[Path],known:set[str])->None:
    text=MANIFEST.read_text(encoding="utf-8-sig")
    text=re.sub(r"- branch: `[^`]+`","- branch: `research/tickshock/2026-09-03-step15l-clean-move-prediction`",text,count=1)
    text=re.sub(r"- status: `[^`]+`","- status: `STEP15L_DEVELOPMENT_PREDICTION_SIGNAL_FOUND_OOS_REQUIRED_PRODUCTION_NOT_ELIGIBLE`",text,count=1)
    text=re.sub(r"- manifest_revision: `[^`]+`","- manifest_revision: `15L`",text,count=1)
    text=re.sub(r"- covered_steps: `[^`]+`","- covered_steps: `01-15L`",text,count=1)
    text=re.sub(r"- last_audited_commit: `[^`]+`","- last_audited_commit: `SELF`",text,count=1)
    text=re.sub(r"- last_updated_at: `[^`]+`","- last_updated_at: `2026-09-03T19:15:00+09:00`",text,count=1)
    text=re.sub(r"\n\nStep 15L appends .*?resolved by the commit that introduces the Step 15L bundle\.\n","\n",text,flags=re.S)
    text=re.sub(r"\n\| TS-S15L-\d{4} \|.*?(?=\n\| TS-|\Z)","",text,flags=re.S)
    rows=[]
    for index,path in enumerate(paths,1):
        rel=path.relative_to(ROOT).as_posix();kind="source" if rel.startswith(("mql/","tools/")) else "document" if rel.startswith(("docs/","reports/tests/tick_shock/step15l_validation")) else "generated evidence"
        source="source" if kind=="source" else "generated evidence"
        commit_target="yes" if rel in known or not rel.endswith((".ex5",".log")) else "no"
        status="COMPLETE" if commit_target=="yes" else "LOCAL_GENERATED"
        rows.append(f"| TS-S15L-{index:04d} | 15L | `{rel}` | {kind} | Step 15L clean-move prediction and causal feature evidence | {source} | `{'SELF' if path==MANIFEST else sha(path)}` | {commit_target} | OOS design | {status} | March development only | {owner(rel,known) if path!=MANIFEST else 'SELF'} |")
    base_ids=re.findall(r"^\| (TS-[^| ]+) \|",text,flags=re.M);base_paths={line.strip().strip("|").split("|")[2].strip().strip("`") for line in text.splitlines() if line.startswith("| TS-")}
    new_paths={p.relative_to(ROOT).as_posix() for p in paths}
    note=f"\n\nStep 15L appends {len(rows)} current source, harness, formal-run, model-analysis, plot, and QA rows. The rollup contains {len(base_ids)+len(rows)} artifact rows and {len(base_paths|new_paths)} unique paths; artifact ID duplicates are zero. Rows carrying `SELF` are resolved by the commit that introduces the Step 15L bundle.\n"
    MANIFEST.write_text(text.rstrip()+note+"\n"+"\n".join(rows)+"\n",encoding="utf-8")


def validate()->None:
    text=MANIFEST.read_text(encoding="utf-8");ids=re.findall(r"^\| (TS-[^| ]+) \|",text,flags=re.M)
    if len(ids)!=len(set(ids)):raise RuntimeError("duplicate artifact ID")
    latest={}
    for line in text.splitlines():
        if line.startswith("| TS-"):
            cells=[x.strip() for x in line.strip().strip("|").split("|")]
            if len(cells)>=7:latest[cells[2].strip("`")]=cells[6].strip("`")
    mismatch=[]
    for rel,expected in latest.items():
        path=ROOT/rel
        if path.is_file() and path!=MANIFEST and expected!="SELF" and sha(path)!=expected:mismatch.append(rel)
    if mismatch:raise RuntimeError(f"latest SHA mismatch: {mismatch[:10]}")
    print(f"step15l_rows={sum(x.startswith('TS-S15L-') for x in ids)} total_rows={len(ids)} unique_paths={len(latest)} duplicate_ids=0 latest_sha_mismatches=0")


def main():
    known=tracked();paths=artifacts();inventory(paths,known);paths=artifacts();update(paths,known);validate()


if __name__=="__main__":main()
