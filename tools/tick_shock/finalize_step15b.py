#!/usr/bin/env python3
"""Build final Step 15B test, compile, path, and SHA evidence."""

from __future__ import annotations

import csv
import hashlib
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
BASE="9df6825b"


def read(path: Path) -> list[dict[str,str]]:
    with path.open(encoding="utf-8-sig",newline="") as h: return list(csv.DictReader(h))


def write(path: Path,fields:list[str],rows:list[dict[str,object]]) -> None:
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open("w",encoding="utf-8",newline="") as h:
        w=csv.DictWriter(h,fieldnames=fields);w.writeheader();w.writerows(rows)


def main() -> int:
    registry=read(ROOT/"tests/tick_shock/spec/test_cases.csv")
    sources=[ROOT/"reports/tests/tick_shock/step14r_final/results.csv",
             ROOT/"reports/tests/tick_shock/step15a_green/step15a_green_results.csv",
             ROOT/"reports/tests/tick_shock/step15b_green/step15b_green_results.csv"]
    observed={}
    for source in sources:
        for row in read(source): observed[row["test_id"]]={**row,"source":source.relative_to(ROOT).as_posix()}
    results=[]
    for case in registry:
        o=observed.get(case["test_id"],{})
        results.append({"test_id":case["test_id"],"requirement_id":case["requirement_id"],"test_layer":case["test_layer"],
                        "status":o.get("status","SKIP"),"expected":o.get("expected",""),"actual":o.get("actual","NOT_OBSERVED"),
                        "evidence_path":o.get("evidence_path",o.get("source",""))})
    write(ROOT/"reports/tests/tick_shock/step15b_final_results.csv",list(results[0]),results)

    compile_rows=[]
    logs=sorted((ROOT/"reports/compile/tick_shock").glob("step15b_ExpectedValue_TickShock_*Harness.log"))+[ROOT/"reports/compile/tick_shock/step15b_research_ea.log"]
    for log in logs:
        text=log.read_text(encoding="utf-16",errors="ignore")
        compile_rows.append({"target":log.stem.replace("step15b_",""),"log_path":log.relative_to(ROOT).as_posix(),
                             "errors":0 if "0 errors" in text else 1,"warnings":0 if "0 warnings" in text else 1,
                             "status":"PASS" if "0 errors, 0 warnings" in text else "FAIL"})
    write(ROOT/"reports/compile/tick_shock/step15b_compile_results.csv",list(compile_rows[0]),compile_rows)

    committed=subprocess.check_output(["git","-C",str(ROOT),"diff","--name-only",f"{BASE}..HEAD"],text=True).splitlines()
    status=subprocess.check_output(["git","-C",str(ROOT),"status","--porcelain"],text=True).splitlines()
    untracked=[line[3:] for line in status if line.startswith("?? ")]
    # Every committed path since the clean Step 15A base belongs to Step 15B,
    # including generic production paths whose names do not contain "15b".
    # Untracked selection remains narrow so refreshed historical compile logs
    # cannot leak into the Step 15B inventory.
    relevant=list(committed)+[p for p in untracked if ("15b" in p.lower() or "20260827_ts15b" in p)]
    relevant.extend(["docs/research/tick_shock/00_artifact_manifest.md","reports/qa/tick_shock/step15b_final_qa.md",
                     "reports/qa/tick_shock/step15b_final_qa_findings.csv","reports/tests/tick_shock/step15b_final_results.csv",
                     "reports/compile/tick_shock/step15b_compile_results.csv","tools/tick_shock/finalize_step15b.py"])
    self_referential={"docs/research/tick_shock/00_artifact_manifest.md",
                      "reports/research/tick_shock/step15b_changed_files.csv",
                      "reports/research/tick_shock/step15b_output_hashes.csv"}
    paths=sorted(set(relevant)-self_referential)
    inventory=[]
    for rel in paths:
        path=ROOT/rel
        if not path.is_file(): continue
        inventory.append({"path":rel.replace("\\","/"),"classification":"step15b_source" if path.suffix.lower() in {".mq5",".mqh",".py",".ps1"} else "step15b_evidence",
                          "bytes":path.stat().st_size,"sha256":hashlib.sha256(path.read_bytes()).hexdigest().upper()})
    write(ROOT/"reports/research/tick_shock/step15b_changed_files.csv",list(inventory[0]),inventory)
    write(ROOT/"reports/research/tick_shock/step15b_output_hashes.csv",list(inventory[0]),inventory)
    counts={s:sum(r["status"]==s for r in results) for s in ("PASS","FAIL","XFAIL","XPASS","SKIP","BLOCKED")}
    print(" ".join(f"{k}={v}" for k,v in counts.items()),f"compile={len(compile_rows)} files={len(inventory)}")
    return 0


if __name__=="__main__": raise SystemExit(main())
