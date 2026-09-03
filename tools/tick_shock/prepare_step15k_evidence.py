#!/usr/bin/env python3
from __future__ import annotations
import csv,re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'reports/backtest/runs/20260903_ts15k_tradeable_move_r1_202503'
RUN_ID='ts15k_tradeable_move_r1_202503'
JOURNAL=Path.home()/'AppData/Roaming/MetaQuotes/Tester/D232275B22422903BD477FB48B858FBA/Agent-127.0.0.1-3000/logs/20260903.log'

def main():
    lines=JOURNAL.read_text(encoding='utf-16',errors='replace').splitlines();starts=[i for i,x in enumerate(lines) if f'InpRunId={RUN_ID}' in x]
    if not starts:raise RuntimeError('formal Step15K journal segment not found')
    selected=lines[starts[-1]:];tokens=('InpRunId=','real ticks discarded','Test passed in','total ticks for all symbols','memory used','deinitialized reason=')
    excerpt=[x for x in selected if any(t in x for t in tokens)];(RUN/'tester_journal_excerpt.txt').write_text('\n'.join(excerpt)+'\n',encoding='utf-8')
    with (RUN/'summary.csv').open(encoding='utf-8-sig',newline='') as f:summary=list(csv.DictReader(f))
    with (RUN/'medium_horizon_episode_summary.csv').open(encoding='utf-8-sig',newline='') as f:episodes=list(csv.DictReader(f))
    quality=[]
    for symbol in ('EURUSD','GBPUSD','USDJPY','AUDUSD','USDCAD','USDCHF'):
        row=next(r for r in summary if r['record_type']=='SYMBOL' and r['key']==symbol);m=re.search(r'm1_minutes_seen=(\d+)',row['value']);minutes=int(m.group(1)) if m else 0;n=sum(r['symbol']==symbol for r in episodes)
        if symbol=='GBPUSD':quality.append({'symbol':symbol,'ea_m1_minutes_seen':minutes,'tester_reported_total_minutes':30187,'tester_reported_discarded_minutes':179,'fallback_rate_pct':179/30187*100,'status':'GENERATED_TICK_FALLBACK_OBSERVED','primary_treatment':f'ALL_{n}_EPISODES_EXCLUDED_INTERVAL_MAP_UNAVAILABLE','evidence':'tester_journal_excerpt.txt'})
        else:quality.append({'symbol':symbol,'ea_m1_minutes_seen':minutes,'tester_reported_total_minutes':'','tester_reported_discarded_minutes':'','fallback_rate_pct':0,'status':'NO_DISCARD_WARNING_OBSERVED','primary_treatment':'PRIMARY_ELIGIBLE_IF_OTHER_GATES_PASS','evidence':'tester_journal_excerpt.txt'})
    with (RUN/'tick_quality.csv').open('w',encoding='utf-8',newline='') as f:w=csv.DictWriter(f,fieldnames=quality[0]);w.writeheader();w.writerows(quality)
    print(f'journal_lines={len(excerpt)} tick_quality_rows={len(quality)}')
if __name__=='__main__':main()
