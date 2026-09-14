"""Independent selected-trade accounting; no production model/statistics imports.

Reads only development evidence after Python freeze. Never selects a new model.
"""
import hashlib
import json
from pathlib import Path
import numpy as np
import pandas as pd

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/analysis/tick_shock/two_stage_ml_20260913'
BATCH=ROOT/'reports/backtest/batches/two_stage_development_20260913'


def metrics(t,cost=.2):
    net=t.gross_r.to_numpy()-cost*t.pip_size.to_numpy()/t.distance.to_numpy()
    equity=np.r_[0,np.cumsum(net)]
    gain=net[net>0].sum();loss=-net[net<0].sum()
    return dict(trades=len(t),total_r=float(net.sum()),
        expectancy_r=float(net.mean()) if len(net) else np.nan,
        pf=float(gain/loss) if loss else np.nan,
        maxdd_r=float((np.maximum.accumulate(equity)-equity).max()),
        win_rate=float((net>0).mean()) if len(net) else np.nan,
        top5_removed_total_r=float(net.sum()-np.sort(net)[-5:].sum()))


def main():
    freeze=json.loads((OUT/'python_freeze.json').read_text())
    checks=[]
    def check(name,okay,detail=''):
        checks.append(dict(check=name,status='PASS' if okay else 'FAIL',detail=str(detail)))
    for name,expected in freeze['files'].items():
        check('freeze_hash:'+name,hashlib.sha256((OUT/name).read_bytes()).hexdigest()==expected)
    t=pd.read_csv(OUT/'selected_development_trades.csv')
    t=t.sort_values(['signal_processing_msc','t0_msc','episode_id'],kind='stable')
    selection=json.loads((OUT/'selection.json').read_text())
    check('development_only',t.month.isin(range(202502,202507)).all())
    check('unique_episode',not t.episode_id.duplicated().any())
    check('realized_time_exit',t.status.eq('TIME').all())
    check('entry_after_recognition',t.entry_msc.ge(t.signal_processing_msc).all())
    check('time_exit_not_early',t.exit_msc.ge(t.entry_msc+1000*t.horizon_seconds).all())
    check('single_position',bool(np.all(t.signal_processing_msc.to_numpy()[1:]>t.exit_msc.to_numpy()[:-1])))
    labels=[]
    for month in range(202501,202507):
        o=pd.read_csv(BATCH/str(month)/'fixed_time_outcomes.csv')
        o['episode_id']=str(month)+':'+o.episode_id.astype(str)
        labels.append(o)
    labels=pd.concat(labels,ignore_index=True)
    keys=['episode_id','direction','horizon_seconds']
    matched=t.merge(labels,on=keys,suffixes=('','_source'),validate='one_to_one',how='left',indicator=True)
    check('all_trades_have_source_label',matched['_merge'].eq('both').all())
    for field in ('entry_msc','exit_msc','gross_r','gross_pips','pip_size'):
        check('source_label:'+field,np.allclose(matched[field],matched[field+'_source'],rtol=0,atol=1e-12))
    for field,value in metrics(t).items():
        expected=selection[field]
        check('pooled:'+field,bool(np.isclose(value,expected,atol=1e-8,rtol=0,equal_nan=True)),f'{value} vs {expected}')
    monthly=pd.read_csv(OUT/'selected_development_monthly.csv').set_index('month')
    for month in range(202502,202507):
        for field,value in metrics(t[t.month.eq(month)]).items():
            check(f'month:{month}:{field}',bool(np.isclose(value,monthly.loc[month,field],atol=1e-8,rtol=0,equal_nan=True)))
    rows=[]
    for column in ('month','symbol','direction'):
        for key,group in t.groupby(column,sort=True):
            rows.append(dict(dimension=column,bucket=str(key),**metrics(group)))
    for cost in (0,.1,.2,.5,1.):
        rows.append(dict(dimension='assumed_extra_cost_pips',bucket=str(cost),**metrics(t,cost)))
    lag=(t.exit_msc-t.entry_msc)/1000-t.horizon_seconds
    for name,mask in (('all',np.ones(len(t),dtype=bool)),('overdue_gt_60s',lag>60),('overdue_le_60s',lag<=60)):
        rows.append(dict(dimension='time_exit_lag_diagnostic_not_selection',bucket=name,**metrics(t[mask])))
    pd.DataFrame(rows).to_csv(OUT/'independent_breakdowns.csv',index=False)
    pd.DataFrame(checks).to_csv(OUT/'independent_recalculation.csv',index=False)
    result=dict(checks=len(checks),failures=sum(r['status']=='FAIL' for r in checks),
        holdout_read=False,maximum_exit_lag_seconds=float(lag.max()),
        commission='NOT_OBSERVED: 0.2 pip assumption, actual Bid/Ask spread already embedded')
    (OUT/'independent_recalculation.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result));assert result['failures']==0


if __name__=='__main__':main()
