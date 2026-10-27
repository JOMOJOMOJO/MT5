"""Independent vector extrema check of the uncapped reference path only."""
import csv
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import numpy as np


def label_ms(s):
    return int(datetime.strptime(s, '%Y.%m.%d %H:%M:%S').replace(tzinfo=timezone.utc).timestamp()*1000)


def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    base=Path('reports/backtest/analysis/wave33_uncapped_20261026')
    source=Path('reports/backtest/runs/wave33_v185_2020/20261026_100045_50909ab6')
    with (source/'v185_b_scale_off/lower_bars.csv').open(encoding='utf-8-sig',newline='') as f:
        b=[x for x in csv.DictReader(f,delimiter=';') if x['bar_time'].startswith('2020.')]
    times=np.array([label_ms(x['bar_time']) for x in b],dtype=np.int64)
    op,hi,lo=[np.array([float(x[k]) for x in b]) for k in ['open','high','low']]
    with (base/'data/positions_excursion.csv').open(encoding='utf-8-sig',newline='') as f:
        rows=list(csv.DictReader(f))
    with (source/'v185_b_scale_off/raw_deals.csv').open(encoding='utf-8-sig',newline='') as f:
        raw=list(csv.DictReader(f,delimiter=';'))
    fills={x['position_id']:int(x['time_msc']) for x in raw if x['entry']=='DEAL_ENTRY_IN'}
    exits={x['position_id']:int(x['time_msc']) for x in raw if x['entry']=='DEAL_ENTRY_OUT'}
    assert len(rows)==len({x['setup_id'] for x in rows})==334
    native_sl=0
    differences=[]
    for row in rows:
        entry,stop=float(row['entry_price']),float(row['initial_sl'])
        t=fills[row['position_id']]
        i=int(np.searchsorted(times,t))
        assert times[i]==t, 'actual population must have exact minute-open fills'
        islong=row['direction']=='LONG'
        adverse=lo if islong else hi
        hits=np.flatnonzero(adverse[i:]<=stop if islong else adverse[i:]>=stop)
        j=i+int(hits[0]) if hits.size else len(times)
        lower_end=j
        gap=j<len(times) and (op[j]<=stop if islong else op[j]>=stop)
        upper_end=j if gap else min(j+1,len(times))
        if row['exit_reason']=='DEAL_REASON_SL':
            native_sl+=1
            cut=exits[row['position_id']]
            lower_end=min(lower_end,int(np.searchsorted(times+60000,cut,side='right')))
            upper_end=min(upper_end,int(np.searchsorted(times,cut,side='left')))
        for name,end in [('lower',lower_end),('upper',upper_end)]:
            favorable=(hi[i:end]-entry) if islong else (entry-lo[i:end])
            value=max(0.0,float(favorable.max())/abs(entry-stop)) if favorable.size else 0.0
            saved=float(row[f'uncapped_{name}_max_r'])
            if abs(value-saved)>1e-8:
                differences.append({'setup_id':row['setup_id'],'bound':name,'independent':value,'saved':saved})
    assert native_sl==190
    assert not differences,differences
    summary=json.loads((base/'data/summary.json').read_text(encoding='utf-8'))
    assert summary['method_sha256']==digest(Path('tools/wave33_visual/uncapped_excursion.py'))
    assert summary['frozen_plan_sha256']==digest(base/'PLAN.md')
    deployment=json.loads(Path('reports/backtest/runs/wave33_v185_prior_2020/deployment.json').read_text(encoding='utf-8-sig'))
    assert digest(Path('mql/Experts/Wave33ChopDiagnostic.mq5'))==deployment['source_sha256']
    assert digest(Path('mql/Experts/Wave33ChopDiagnostic.ex5'))==deployment['binary_sha256']
    for name,value in deployment['header_sha256'].items():
        assert digest(Path('mql/Include')/name)==value
    result=dict(status='PASS',positions=334,independent_uncapped_extrema=668,
        native_sl_barriers=190,differences=differences,unchanged_ea_and_headers=19,
        scope='REFERENCE_OHLC_EXTREMA_NOT_EXECUTABLE_PNL',
        method_sha256=digest(Path(__file__)),plan_sha256=digest(base/'PLAN.md'),
        data_sha256=digest(base/'data/positions_excursion.csv'))
    (base/'root_independent_audit.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result))


if __name__=='__main__':
    main()
