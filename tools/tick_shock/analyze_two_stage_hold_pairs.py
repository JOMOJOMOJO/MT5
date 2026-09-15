"""Post-hoc matched-entry diagnosis, no refit and no MT5 execution."""
from pathlib import Path
import hashlib
import json
import numpy as np
import pandas as pd

ROOT=Path(__file__).resolve().parents[2]
BATCH=ROOT/'reports/backtest/batches/two_stage_hold_comparison_20260914'
OUT=ROOT/'reports/analysis/tick_shock/two_stage_hold_pairs_20260914'


def stats(t):
    x=t.net_profit.to_numpy();r=t.net_r.to_numpy()
    positive=x[x>0].sum();negative=-x[x<0].sum()
    return dict(n=len(t),net_usd=float(x.sum()),mean_r=float(r.mean()) if len(t) else None,
        wins=int((x>0).sum()),losses=int((x<0).sum()),flat=int((x==0).sum()),
        pf=float(positive/negative) if negative else None,
        top5_removed_usd=float(x.sum()-np.sort(x)[-5:].sum()))


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    inputs=[]
    def read(h,name):
        path=BATCH/f'hold_{h}'/name
        inputs.append(dict(path=path.relative_to(ROOT).as_posix(),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        return pd.read_csv(path)
    a=read(300,'candidate_trades.csv');b=read(14400,'candidate_trades.csv')
    sa=read(300,'candidate_signals.csv');sb=read(14400,'candidate_signals.csv')
    keys=['symbol','signal_msc','direction']
    for t in (a,b):
        assert not t.duplicated(keys).any()
        t['day']=t.signal_msc//86400000
        t['month']=pd.to_datetime(t.signal_msc,unit='ms').dt.month
    signals=sa.merge(sb,on=['symbol','t0_msc'],suffixes=('_5','_240'),validate='one_to_one',how='outer',indicator=True)
    qa=[dict(check='all_signal_rows_match',passed=bool(signals['_merge'].eq('both').all()))]
    for field in ('direction','long_score','short_score','stage1_score','processing_msc'):
        qa.append(dict(check='signal_'+field,passed=bool(np.allclose(signals[field+'_5'],signals[field+'_240'],atol=1e-12,rtol=0))))
    p=a.merge(b,on=keys,suffixes=('_5','_240'),validate='one_to_one')
    p['same_fill']=p.entry_msc_5.eq(p.entry_msc_240)&np.isclose(p.entry_price_5,p.entry_price_240,atol=1e-12,rtol=0)&np.isclose(p.filled_volume_5,p.filled_volume_240,atol=1e-12,rtol=0)
    p['delta_usd']=p.net_profit_240-p.net_profit_5
    p['delta_r']=p.net_r_240-p.net_r_5
    p['transition']=np.where(p.net_profit_5>0,'WIN',np.where(p.net_profit_5<0,'LOSS','FLAT'))+'->'+np.where(p.net_profit_240>0,'WIN',np.where(p.net_profit_240<0,'LOSS','FLAT'))
    p['month']=p.month_5;p['day']=p.day_5
    p.to_csv(OUT/'matched_entries.csv',index=False)
    exact=p[p.same_fill].copy()
    ai=pd.MultiIndex.from_frame(a[keys]);bi=pd.MultiIndex.from_frame(b[keys])
    common_a=a[ai.isin(bi)];common_b=b[bi.isin(ai)]
    only_a=a[~ai.isin(bi)];only_b=b[~bi.isin(ai)]
    groups=[]
    for name,t in [('all_5min',a),('all_4hour',b),('common_5min',common_a),('common_4hour',common_b),('only_5min',only_a),('only_4hour',only_b)]:
        groups.append(dict(group=name,**stats(t)))
    pd.DataFrame(groups).to_csv(OUT/'population_decomposition.csv',index=False)
    transitions=exact.groupby('transition').agg(n=('delta_r','size'),five_usd=('net_profit_5','sum'),four_usd=('net_profit_240','sum'),delta_usd=('delta_usd','sum')).reset_index()
    transitions.to_csv(OUT/'win_loss_transitions.csv',index=False)
    breakdown=[]
    for col in ('month','symbol','direction'):
        for key,g in exact.groupby(col):
            breakdown.append(dict(dimension=col,bucket=key,n=len(g),five_usd=g.net_profit_5.sum(),four_usd=g.net_profit_240.sum(),mean_delta_r=g.delta_r.mean(),improved=int(g.delta_r.gt(0).sum())))
    pd.DataFrame(breakdown).to_csv(OUT/'paired_breakdowns.csv',index=False)
    # Deterministic calendar-day cluster bootstrap of matched trade mean improvement.
    # Post-hoc diagnostic only, not a new selection gate or independent OOS claim.
    day=exact.groupby('day').agg(total=('delta_r','sum'),n=('delta_r','size'))
    rng=np.random.default_rng(20260914)
    ids=rng.integers(0,len(day),size=(10000,len(day)))
    draws=day.total.to_numpy()[ids].sum(axis=1)/day.n.to_numpy()[ids].sum(axis=1)
    interval=np.quantile(draws,[.025,.975]).tolist()
    # 5/10/15-minute research labels are separate counterfactual entries. Record
    # clock/price mismatch explicitly, rather than treating them as actual trades.
    o=read(14400,'fixed_time_outcomes.csv')
    horizons=[]
    for h in (300,600,900):
        z=b.merge(o[o.horizon_seconds.eq(h)],on=['episode_id','symbol','direction'],suffixes=('_actual','_shadow'),validate='one_to_one')
        for month,g in [('all',z)]+list(z.groupby('month')):
            valid=g[g.status.eq('TIME')]
            horizons.append(dict(horizon=h,month=month,n=len(valid),mean_shadow_gross_r=valid.gross_r_shadow.mean(),
                positive=int(valid.gross_r_shadow.gt(0).sum()),same_entry_clock=int(valid.entry_msc_actual.eq(valid.entry_msc_shadow).sum()),
                note='shadow Bid/Ask entry, not necessarily actual fill; no commission'))
    pd.DataFrame(horizons).to_csv(OUT/'four_hour_population_short_horizons.csv',index=False)
    delta=float(b.net_profit.sum()-a.net_profit.sum())
    decomposition=float(p.delta_usd.sum()+only_b.net_profit.sum()-only_a.net_profit.sum())
    qa.append(dict(check='population_delta_reconciles',passed=bool(np.isclose(delta,decomposition,atol=1e-8))))
    result=dict(signal_rows=len(signals),groups=groups,common=len(p),exact_fill_pairs=len(exact),
        improved=int(exact.delta_r.gt(0).sum()),worsened=int(exact.delta_r.lt(0).sum()),
        mean_paired_delta_r=float(exact.delta_r.mean()),day_cluster_count=len(day),paired_delta_r_ci95=interval,
        total_result_difference_usd=delta,common_entry_change_usd=float(p.delta_usd.sum()),
        population_change_usd=float(only_b.net_profit.sum()-only_a.net_profit.sum()),
        late_four_hour_trades=int(b.hold_seconds.gt(14460).sum()),maximum_hold_seconds=float(b.hold_seconds.max()),
        transitions=transitions.to_dict('records'),qa_failures=sum(not q['passed'] for q in qa),
        warning='Post-hoc comparison of observed July/August; shared entries are a selected subset. No path or opposite-direction 4h counterfactual is inferred.')
    (OUT/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    pd.DataFrame(qa).to_csv(OUT/'qa.csv',index=False)
    pd.DataFrame(inputs).to_csv(OUT/'input_hashes.csv',index=False)
    print(json.dumps(result,indent=2));assert result['qa_failures']==0


if __name__=='__main__':main()
