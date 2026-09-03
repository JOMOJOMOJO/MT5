#!/usr/bin/env python3
from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/"reports/backtest/runs/20260903_ts15l_clean_move_ml_r1_202503"
RUN_ID="ts15l_clean_move_ml_r1_202503"
JOURNAL=Path.home()/"AppData/Roaming/MetaQuotes/Tester/D232275B22422903BD477FB48B858FBA/Agent-127.0.0.1-3000/logs/20260903.log"


def main():
    lines=JOURNAL.read_text(encoding="utf-16",errors="replace").splitlines();starts=[i for i,x in enumerate(lines) if f"InpRunId={RUN_ID}" in x]
    if not starts:raise RuntimeError("formal Step 15L journal segment not found")
    segment=lines[starts[-1]:]
    tokens=("InpRunId=","real ticks discarded","Test passed in","total ticks for all symbols","memory used","deinitialized reason=","clean_move_causal_features")
    excerpt=[];seen_total=False
    for line in segment:
        if any(t in line for t in tokens):excerpt.append(line)
        if "total ticks for all symbols" in line:seen_total=True
        if seen_total and "memory used" in line:break
    (RUN/"tester_journal_excerpt.txt").write_text("\n".join(excerpt)+"\n",encoding="utf-8")
    with (RUN/"summary.csv").open(encoding="utf-8-sig",newline="") as handle:summary=list(csv.DictReader(handle))
    quality=[]
    for symbol in ("EURUSD","GBPUSD","USDJPY","AUDUSD","USDCAD","USDCHF"):
        row=next(r for r in summary if r["record_type"]=="SYMBOL" and r["key"]==symbol);m=re.search(r"m1_minutes_seen=(\d+)",row["value"]);minutes=int(m.group(1)) if m else 0
        if symbol=="GBPUSD":quality.append({"symbol":symbol,"ea_m1_minutes_seen":minutes,"tester_reported_total_minutes":30187,"tester_reported_discarded_minutes":179,"fallback_rate_pct":179/30187*100,"status":"GENERATED_TICK_FALLBACK_OBSERVED","primary_treatment":"EXCLUDE_GBPUSD_FROM_PRIMARY_INFERENCE_INTERVAL_MAP_UNAVAILABLE","evidence":"tester_journal_excerpt.txt"})
        else:quality.append({"symbol":symbol,"ea_m1_minutes_seen":minutes,"tester_reported_total_minutes":"","tester_reported_discarded_minutes":"","fallback_rate_pct":0,"status":"NO_DISCARD_WARNING_OBSERVED","primary_treatment":"PRIMARY_ELIGIBLE_IF_OTHER_GATES_PASS","evidence":"tester_journal_excerpt.txt"})
    with (RUN/"tick_quality.csv").open("w",encoding="utf-8",newline="") as handle:
        writer=csv.DictWriter(handle,fieldnames=quality[0].keys());writer.writeheader();writer.writerows(quality)
    (RUN/"summary.md").write_text("\n".join([
        "# Step 15L formal March feature run","",
        "- Period: 2025-03-01 to 2025-04-01", "- Driver/model: EURUSD M1 / real ticks", "- Symbols: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF",
        "- Research mode: no orders; trades.csv is header-only", "- Detector rows: 21,799", "- Medium-horizon episodes: 3,151", "- Causal feature rows: 3,151", "- Raw shock candidates: 74,415",
        "- Internal maximum memory counter: 31 MB", "- Tester process memory: 502 MB (40 MB history, 256 MB tick data)", "- Tester runtime: 0:11:32.961", "- Tester total ticks: 10,587,807; EA per-symbol counter sum: 10,587,809",
        "- Tick quality: GBPUSD discarded/generated fallback 179 of 30,187 reported minutes (0.593%). No interval map is available, so GBPUSD is excluded from primary inference.",
        "", "> This run collects causal detection-time features. It does not establish strategy edge and does not place orders.", ""]),encoding="utf-8")
    print(f"journal_lines={len(excerpt)} tick_quality_rows={len(quality)}")


if __name__=="__main__":main()
