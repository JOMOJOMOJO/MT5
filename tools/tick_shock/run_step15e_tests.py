#!/usr/bin/env python3
"""Record Step 15E RED when the preregistered production API is absent."""
from __future__ import annotations
import argparse,csv
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--phase',choices=('red','green'),required=True);a=ap.parse_args()
    with (ROOT/'tests/tick_shock/spec/test_cases.csv').open(encoding='utf-8-sig',newline='') as h: cases=[r for r in csv.DictReader(h) if r['test_id'].startswith('TS15E-')]
    module=ROOT/'mql/Include/TickShock/TickShockMediumHorizonResponse.mqh'
    out=ROOT/f'reports/tests/tick_shock/step15e_{a.phase}';out.mkdir(parents=True,exist_ok=True)
    rows=[]
    for c in cases:
        with (ROOT/c['expected_path']).open(encoding='utf-8-sig',newline='') as h:e=next(csv.DictReader(h))
        if a.phase=='red' and not module.exists(): status='XFAIL';actual='PRODUCTION_MEDIUM_HORIZON_API_ABSENT';diff=f"expected {e['field']}={e['expected_value']}; production module absent"
        else: status='BLOCKED';actual='MQL_HARNESS_REQUIRED';diff='green phase requires compiled production-path harness'
        rows.append({'test_id':c['test_id'],'requirement_id':c['requirement_id'],'defect_id':c['defect_id'],'test_layer':c['test_layer'],'status':status,'expected':f"{e['field']}={e['expected_value']}",'actual':actual,'difference':diff,'evidence_path':str(out.relative_to(ROOT)/'step15e_red_results.csv').replace('\\','/')})
    result=out/f'step15e_{a.phase}_results.csv';fields=('test_id','requirement_id','defect_id','test_layer','status','expected','actual','difference','evidence_path')
    with result.open('w',encoding='utf-8',newline='') as h:w=csv.DictWriter(h,fieldnames=fields);w.writeheader();w.writerows(rows)
    report=out/f'step15e_{a.phase}_report.md';counts={s:sum(r['status']==s for r in rows) for s in ('PASS','FAIL','XFAIL','XPASS','SKIP','BLOCKED')}
    report.write_text('# Step 15E pre-fix RED report\n\nThe 28 preregistered medium-horizon contracts were evaluated before production implementation.\n\n'+ '\n'.join(f'- {k}: {v}' for k,v in counts.items())+'\n\nExpected values come only from frozen CSV oracles. The observed RED is the missing production module/API; no strategy result was inspected.\n',encoding='utf-8')
    print(counts)

if __name__=='__main__':main()
