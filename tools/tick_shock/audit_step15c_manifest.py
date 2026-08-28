#!/usr/bin/env python3
"""Audit manifest artifact IDs and latest-path SHA-256 values."""
from __future__ import annotations
import csv,hashlib,re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
MANIFEST=ROOT/"docs/research/tick_shock/00_artifact_manifest.md"
OUT=ROOT/"reports/qa/tick_shock/step15c_manifest_audit.csv"

def main()->int:
    ids=[];latest={}
    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|"):continue
        cells=[cell.strip() for cell in line.strip("|").split("|")]
        if len(cells)<7 or cells[0] in {"artifact ID","---"}:continue
        ids.append(cells[0]);latest[cells[2].strip("`")]=cells[6].strip("`")
    rows=[]
    for rel,digest in latest.items():
        path=ROOT/rel
        if digest in {"SELF","SELF_EXCLUDED","","N/A"} or not re.fullmatch(r"[0-9A-Fa-f]{64}",digest):continue
        actual=hashlib.sha256(path.read_bytes()).hexdigest().upper() if path.is_file() else "MISSING"
        rows.append({"path":rel,"manifest_sha256":digest.upper(),"actual_sha256":actual,
                     "status":"PASS" if actual==digest.upper() else "FAIL"})
    OUT.parent.mkdir(parents=True,exist_ok=True)
    with OUT.open("w",encoding="utf-8",newline="") as h:
        w=csv.DictWriter(h,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
    duplicates=len(ids)-len(set(ids));mismatches=sum(row["status"]=="FAIL" for row in rows)
    print(f"ids={len(ids)} id_duplicates={duplicates} latest_paths={len(latest)} sha_mismatches={mismatches}")
    return 1 if duplicates or mismatches else 0

if __name__=="__main__":raise SystemExit(main())
