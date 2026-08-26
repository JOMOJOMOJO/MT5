#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
from pathlib import Path


def main() -> None:
    parser=argparse.ArgumentParser();parser.add_argument("--phase",required=True);args=parser.parse_args()
    root=Path(__file__).resolve().parents[2]
    paths=[root / "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5"]
    paths += sorted((root / "mql/Include/TickShock").glob("*.mqh"))
    paths += [root / "mql/Include/TickShockStateMachine.mqh",root / "mql/Include/TickShockResearchExecution.mqh"]
    paths += sorted((root / "mql/Experts/tests").glob("ExpectedValue_TickShock_*Harness.mq5"))
    paths += sorted((root / "mql/Experts/tests").glob("TickShockStep*TestSupport.mqh"))
    paths += sorted((root / "tests/tick_shock/fixtures").glob("TS15A-*"))
    paths += sorted((root / "tests/tick_shock/expected").glob("TS15A-*"))
    rows=[]
    for path in paths:
        if not path.exists(): continue
        rel=path.relative_to(root).as_posix()
        classification="production" if rel.startswith("mql/Include/") or rel=="mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5" else ("test_source" if rel.startswith("mql/Experts/tests/") else ("fixture" if "/fixtures/" in rel else "expected"))
        rows.append({"phase":args.phase,"path":rel,"classification":classification,"sha256":hashlib.sha256(path.read_bytes()).hexdigest().upper()})
    out=root / "reports/qa/tick_shock" / f"step15a_{args.phase}_hashes.csv";out.parent.mkdir(parents=True,exist_ok=True)
    with out.open("w",encoding="utf-8",newline="") as handle:
        writer=csv.DictWriter(handle,fieldnames=rows[0].keys());writer.writeheader();writer.writerows(rows)
    print(out)


if __name__=="__main__": main()
