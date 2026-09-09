"""Preserve only matching tester journal run block and runtime/quality evidence."""
from pathlib import Path
import argparse
import csv
import re

def main():
    p=argparse.ArgumentParser();p.add_argument('--run-dir',type=Path,required=True);p.add_argument('--run-id',required=True);a=p.parse_args()
    candidates=sorted((Path.home()/'AppData/Roaming/MetaQuotes/Tester').glob('*/Agent-*/logs/*.log'),key=lambda x:x.stat().st_mtime,reverse=True)
    block=None
    for log in candidates[:30]:
        lines=log.read_text(encoding='utf-16',errors='replace').splitlines()
        starts=[i for i,s in enumerate(lines) if f'InpRunId={a.run_id}' in s and not s.endswith(a.run_id+'_rerun')]
        if not starts:continue
        start=starts[-1];end=next((i for i in range(start+1,len(lines)) if 'InpRunId=' in lines[i]),len(lines));block=lines[max(0,start-70):end];break
    if block is None:raise SystemExit('Matching tester run journal missing')
    tokens=('InpRunId=','InpResearchPeriod=','InpDetectorVersion=','real ticks discarded','initialized research_only','deinitialized reason=','Test passed in','total ticks for all symbols','memory used','technical_discovery','technical_candidate','error','failed','Vantage','build ')
    selected=[s for s in block if any(x in s for x in tokens)]
    (a.run_dir/'tester_journal_excerpt.txt').write_text('\n'.join(selected)+'\n',encoding='utf-8')
    rows=[]
    for symbol in ('EURUSD','GBPUSD','USDJPY','AUDUSD','USDCAD','USDCHF'):
        warnings=[s for s in block if symbol in s and 'real ticks discarded' in s]
        rows.append(dict(symbol=symbol,discard_warnings=len(warnings),generated_minutes='NOT_OBSERVED' if not warnings else 'INTERVAL_UNAVAILABLE',commission='NOT_OBSERVED_ALL_SYMBOL_SCOPE',evidence='tester_journal_excerpt.txt'))
    with (a.run_dir/'tick_quality.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
    print('\n'.join(selected[-12:]))
if __name__=='__main__':main()
