"""Independent cashflow, population, gap and preservation audit of account replay."""
import argparse
import json
from pathlib import Path
import numpy as np
import pandas as pd
from ..multiasset.data import sha,load_dataset
from .run import source_hashes


def verify(out):
    out=Path(out);m=json.loads((out/'manifest.json').read_text(encoding='utf-8'))
    assert m['status']=='completed' and not m['holdout_2026_used']
    cfg=m['config'];source=Path(m['source_run'])
    assert sha(source/'manifest.json')==m['source_run_manifest_sha256']
    assert sha(m['data_manifest'])==m['data_manifest_sha256']
    data=json.loads(Path(m['data_manifest']).read_text(encoding='utf-8'))
    protected=json.loads((out/'protected_before.json').read_text(encoding='utf-8'))
    assert all(sha(p)==digest for p,digest in protected.items())
    assert source_hashes()==m['source_hashes']
    a=pd.read_parquet(out/'accounts.parquet');checked=prefix=closures=0;stops=[]
    assert len(a)==432 and not a.account_pnl_promotion_eligible.any()
    assert a.all_in_net_pnl_usd.isna().all() and a.swap_cost_usd.isna().all()
    for (sym,tf),market in a.groupby(['symbol','timeframe']):
        b=load_dataset(data,sym,tf,cfg);times=b.time.to_numpy();step=cfg['timeframes'][tf]
        c=pd.read_parquet(source/sym/tf/'candidates.parquet').set_index('candidate_id')
        assert (b.time<1767225600).all() and (c.signal_time<1767225600).all()
        spec=data['specs'][sym];tick=spec['tick_size'];point=spec['point'];pip=spec['pip_size']
        for (method,side),group in market.groupby(['method','side']):
            cell=out/sym/tf/(method+'_'+side);original=source/sym/tf/(method+'_'+side)
            trades=pd.read_parquet(cell/'execution_trades.parquet');events=pd.read_parquet(cell/'execution_events.parquet')
            old=pd.read_parquet(original/'execution_trades.parquet')
            candidates=c[c.method.eq(method)&c.side.eq(side)]
            assert len(events)==len(candidates)*2
            for scenario,ledger in events.groupby('scenario'):
                assert set(ledger.candidate_id)==set(candidates.index)
                assert not ledger.candidate_id.duplicated().any()
            for scenario,sub in trades.groupby('scenario'):
                row=group[group.scenario.eq(scenario)].iloc[0];closed=sub[sub.status.eq('closed')]
                np.testing.assert_allclose(closed.net_pnl_usd.sum(),row.net_pnl_usd,atol=1e-7)
                assert int(row.n_closed)==len(closed)
                assert row.account_path_complete==sub.status.eq('closed').all()
                assert sub.all_in_net_pnl_usd.isna().all()
                positive=closed.net_pnl_usd.clip(lower=0).sum();negative=-closed.net_pnl_usd.clip(upper=0).sum()
                if negative:np.testing.assert_allclose(row.profit_factor,positive/negative,atol=1e-10)
                earlier=old[old.scenario.eq(scenario)&old.status.eq('closed')]
                shared=earlier.merge(closed,on='candidate_id',suffixes=('_old','_new'),validate='one_to_one')
                assert len(shared)==len(earlier)
                for col in ['entry_time','exit_time','volume','net_pnl_usd','result_r']:
                    np.testing.assert_allclose(shared[col+'_old'],shared[col+'_new'],rtol=1e-10,atol=1e-9)
                prefix+=len(shared)
                for t in sub[~sub.status.eq('closed')].to_dict('records'):
                    stops.append(dict(symbol=sym,timeframe=tf,method=method,side=side,scenario=scenario,
                        candidate_id=t['candidate_id'],status=t['status'],gap_start=t['censor_gap_start'],
                        gap_end=t['censor_gap_end'],evidence=t['censor_gap_evidence'],last_observed_time=t['last_observed_time']))
                # Every closed path must contain only adjacent bars or exact weekend closure.
                for t in closed.itertuples():
                    first,last=int(t.entry_index),int(t.exit_index)
                    assert 1<=t.holding_bars<=10 and t.holding_bars==last-first+1
                    expected=candidates.loc[t.candidate_id]
                    assert t.entry_time==expected.entry_time and t.atr14==expected.atr14
                    gaps=np.diff(times[first:last+1])-step;count=0
                    for index in np.flatnonzero(gaps):
                        assert gaps[index]==172800
                        start=pd.Timestamp(int(times[first+index]+step),unit='s')
                        end=pd.Timestamp(int(times[first+index+1]),unit='s')
                        assert start.weekday()==5 and start==start.normalize()
                        assert end.weekday()==0 and end==end.normalize()
                        count+=1
                    assert t.closure_crossings==count
                    closures+=count
                # Independent hand formula, sampled across each scenario's whole observed path.
                selected=closed.iloc[np.unique(np.linspace(0,len(closed)-1,min(10,len(closed))).astype(int))] if len(closed) else closed
                sign=1 if side=='LONG' else -1
                for t in selected.itertuples():
                    idx=int(t.exit_index);bar=b.iloc[idx]
                    spread=(bar.spread*point if bar.spread>0 else cfg['assumed_spread_pips'][sym]*pip)
                    if 'gap_open' in t.exit_reason:quote=bar.open+(spread if sign<0 else 0)
                    elif t.exit_reason=='time_exit':quote=bar.close+(spread if sign<0 else 0)
                    elif t.exit_reason.startswith('stop'):quote=t.stop_price
                    else:quote=t.target_price
                    x=(quote-sign*cfg['slippage_pips_per_side']*pip)/tick
                    fill=(np.ceil(x-1e-9) if sign<0 else np.floor(x+1e-9))*tick
                    mid=quote+sign*spread/2
                    conv=1. if sym.endswith('USD') else 1./mid
                    net=sign*(fill-t.entry_fill)*spec['contract_size']*t.volume*conv-cfg['commission_per_lot_roundtrip_usd']*t.volume
                    np.testing.assert_allclose([fill,net,net/t.planned_risk_usd],[t.exit_fill,t.net_pnl_usd,t.result_r],rtol=1e-9,atol=1e-8)
                    checked+=1
    result=dict(status='PASS',account_scenarios=len(a),independent_cashflows=checked,
                original_prefix_trades_identical=prefix,closed_trade_closure_crossings_verified=closures,
                protected_files_unchanged=len(protected),source_hashes_match=True,holdout_2026_used=False)
    qa=out/'qa';qa.mkdir(exist_ok=True)
    pd.DataFrame(stops).to_csv(qa/'remaining_stops.csv',index=False)
    (qa/'verification.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('out');print(json.dumps(verify(p.parse_args().out),indent=2))
