"""Record Python tests and deterministic rerun; never rerun the formal MT5 search."""
import argparse
import hashlib
from pathlib import Path
import subprocess
import sys
import csv


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--run',type=Path,required=True)
    p.add_argument('--analysis',type=Path,required=True)
    p.add_argument('--rerun',type=Path,required=True)
    a=p.parse_args()
    if a.rerun.exists():
        raise SystemExit('Refusing to overwrite deterministic replay output')
    a.rerun.mkdir(parents=True)
    commands=[
        ('python_tests.log',[sys.executable,'tools/tick_shock/test_technical_discovery.py']),
        ('analysis.log',[sys.executable,'tools/tick_shock/analyze_technical_discovery.py',
            '--features',str(a.run/'features.csv'),'--outcomes',str(a.run/'outcomes.csv'),'--output',str(a.rerun)]),
        ('independent_recalculation.log',[sys.executable,'tools/tick_shock/technical_discovery_independent_recalculation.py',
            '--features',str(a.run/'features.csv'),'--outcomes',str(a.run/'outcomes.csv'),'--output',str(a.rerun)])]
    for log,cmd in commands:
        print('Running '+' '.join(cmd),flush=True)
        with (a.rerun/log).open('w',encoding='utf-8') as f:
            result=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,text=True)
        if result.returncode:
            raise SystemExit(f'Failed {log}: {result.returncode}')
    files=sorted([x for x in a.rerun.iterdir() if x.suffix in ('.csv','.json','.mqh')])
    rows=[]
    for new in files:
        old=a.analysis/new.name
        h=lambda path:hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else 'MISSING'
        before,after=h(old),h(new)
        rows.append(dict(path=new.name,primary_sha256=before,replay_sha256=after,
                         status='PASS' if before==after else 'FAIL'))
    with (a.analysis/'deterministic_replay.csv').open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
    print(f'Replayed artifacts {len(rows)}; differences {sum(r["status"]=="FAIL" for r in rows)}',flush=True)
    if any(r['status']=='FAIL' for r in rows):raise SystemExit(1)


if __name__=='__main__':main()
