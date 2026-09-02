#!/usr/bin/env python3
from __future__ import annotations
import csv,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];RUN=ROOT/'reports/backtest/runs/20260902_ts15h_detection_time_continuation_r1_202503';OUT=ROOT/'reports/analysis/tick_shock/step15h'
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1<<20),b''):h.update(b)
 return h.hexdigest().upper()
rows=[]
for p in sorted(RUN.iterdir()):
 if p.is_file():rows.append({'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p),'git_policy':'commit' if p.stat().st_size<50_000_000 else 'external_evidence_over_50mb'})
OUT.mkdir(parents=True,exist_ok=True)
with (OUT/'run_artifact_inventory.csv').open('w',encoding='utf-8',newline='') as h:w=csv.DictWriter(h,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
runs=[{'run_id':'20260902_ts15h_detection_time_continuation_r1_202503','status':'ACCEPTED','source_commit':'a12e72ade081a544fe02f417009fbf499503ca8b','reason':'formal preregistered March development run; causal QA pass'}, {'run_id':'NONE','status':'REJECTED','source_commit':'','reason':'no Step 15H run rejected'}]
with (OUT/'run_registry.csv').open('w',encoding='utf-8',newline='') as h:w=csv.DictWriter(h,fieldnames=runs[0]);w.writeheader();w.writerows(runs)
