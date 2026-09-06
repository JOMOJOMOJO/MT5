#!/usr/bin/env python3
from __future__ import annotations
import csv,re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/"reports/backtest/runs/20260906_ts15n_delayed_decision_r2_202503"
RUN_ID="ts15n_delayed_decision_r2_202503"

def main():
    lines=[]
    for name in ("tester_journal_20260906.log","tester_journal_20260907.log"):
        lines.extend((RUN/name).read_text(encoding="utf-16",errors="replace").splitlines())
    start=next(i for i,x in enumerate(lines) if f"InpRunId={RUN_ID}" in x)
    tokens=("InpRunId=","real ticks discarded","initialized research_only","deinitialized reason=","Test passed in","total ticks for all symbols","generate ","memory used")
    excerpt=[]
    for line in lines[start:]:
        if any(t in line for t in tokens):excerpt.append(line)
        if "503 Mb memory used" in line:break
    (RUN/"tester_journal_excerpt.txt").write_text("\n".join(excerpt)+"\n",encoding="utf-8")
    with (RUN/"summary.csv").open(encoding="utf-8-sig",newline="") as h:summary=list(csv.DictReader(h))
    quality=[]
    for symbol in ("EURUSD","GBPUSD","USDJPY","AUDUSD","USDCAD","USDCHF"):
        row=next(r for r in summary if r["record_type"]=="SYMBOL" and r["key"]==symbol);m=re.search(r"m1_minutes_seen=(\d+)",row["value"]);minutes=int(m.group(1)) if m else 0
        if symbol=="GBPUSD":quality.append(dict(symbol=symbol,ea_m1_minutes_seen=minutes,tester_reported_total_minutes=30187,tester_reported_discarded_minutes=179,fallback_rate_pct=179/30187*100,status="GENERATED_TICK_FALLBACK_OBSERVED",primary_treatment="INCLUDED_WITH_DISCLOSED_LIMITATION_INTERVAL_MAP_UNAVAILABLE",evidence="tester_journal_excerpt.txt"))
        else:quality.append(dict(symbol=symbol,ea_m1_minutes_seen=minutes,tester_reported_total_minutes="",tester_reported_discarded_minutes="",fallback_rate_pct=0,status="NO_DISCARD_WARNING_OBSERVED",primary_treatment="PRIMARY_ELIGIBLE_IF_OTHER_GATES_PASS",evidence="tester_journal_excerpt.txt"))
    with (RUN/"tick_quality.csv").open("w",encoding="utf-8",newline="") as h:w=csv.DictWriter(h,fieldnames=quality[0]);w.writeheader();w.writerows(quality)
    checkpoints=sum(1 for _ in (RUN/"delayed_decision_checkpoints.csv").open(encoding="utf-8-sig"))-1
    actions=sum(1 for _ in (RUN/"delayed_decision_actions.csv").open(encoding="utf-8-sig"))-1
    (RUN/"summary.md").write_text("\n".join([
      "# Step 15N formal March delayed-decision run","",
      "- Period: 2025-03-01 to 2025-04-01","- Driver/model: EURUSD M1 / real ticks","- Symbols: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF",
      "- Mode: REALIZABLE_EA research-only; no orders; trades.csv is header-only","- Detector: frozen TAIL_V1_PERSISTENT","- Raw candidates: 74,415","- Statistical detector events: 21,799","- Medium-horizon episodes: 3,151",
      f"- Delayed checkpoint rows: {checkpoints:,}",f"- Delayed action rows: {actions:,}","- Pool capacity hits: 0","- Global order violations: 0","- Dropped ticks/cursor stalls: 0/0",
      "- Tester runtime: 0:19:12.691","- Tester memory: 503 MB (40 MB history, 256 MB tick data)","- Tester total ticks across symbols: 10,587,807","- Internal summary memory: average 31.331 MB, maximum 32 MB",
      "- Tick quality: GBPUSD real ticks discarded/generated fallback for 179 of 30,187 tester-reported minutes (0.593%); the EA counted 30,188 M1 minutes. The interval map is unavailable, so affected episodes cannot be isolated and the all-symbol analysis retains GBPUSD with this explicit limitation.","- All-tick CSV: disabled","- One-second CSV: disabled","",
      "> This is March development research evidence, not OOS evidence and not a production trading EA." ,""]),encoding="utf-8")

if __name__=="__main__":main()
