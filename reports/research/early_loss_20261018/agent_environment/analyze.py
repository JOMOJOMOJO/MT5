from pathlib import Path
import json
import numpy as np
import pandas as pd
from tools.entry_research.monthly_review.diagnostics import attach_context

BASE=Path('reports/research/account_replay_20261017/validated')
OLD=Path('reports/research/multiasset_20261016/full_validated')
OUT=Path(__file__).parent
KEY=['symbol','timeframe','method','side']
a=pd.read_parquet(BASE/'accounts.parquet')
cells=a.loc[a.profit_factor.gt(1),KEY].drop_duplicates()
frames=[]
for cell in cells.itertuples(index=False):
    p=BASE/f'{cell.symbol}/{cell.timeframe}/{cell.method}_{cell.side}'
    trades=pd.read_parquet(p/'execution_trades.parquet')
    trades=trades.loc[trades.scenario.eq('stop_first_lower')].copy()
    candidate=pd.read_parquet(OLD/f'{cell.symbol}/{cell.timeframe}/candidates.parquet')
    joined=attach_context(trades,candidate)
    joined['cell']=f'{cell.symbol}_{cell.method}_{cell.side}'
    joined['timeframe']=cell.timeframe
    frames.append(joined)
d=pd.concat(frames,ignore_index=True)
assert len(d)==2666
loss=d.net_pnl_before_unknown_swap_usd.lt(-1e-10)
d['early']=loss & d.exit_reason.str.startswith('stop') & ~d.ambiguous & d.holding_bars.le(2)
d['late_sl']=loss & d.exit_reason.str.startswith('stop') & ~d.ambiguous & d.holding_bars.gt(2)
d['win']=d.net_pnl_before_unknown_swap_usd.gt(1e-10)
d['loss']=loss
d['ambiguous_loss']=loss & d.ambiguous
assert d.early.sum()==752
assert pd.to_datetime(d.entry_time,unit='s',utc=True).dt.year.max()<=2025

def summarize(g):
    n=len(g)
    return dict(n=n,early=int(g.early.sum()),late_sl=int(g.late_sl.sum()),wins=int(g.win.sum()),losses=int(g.loss.sum()),ambiguous_loss=int(g.ambiguous_loss.sum()),early_rate=g.early.mean(),win_rate=g.win.mean(),early_among_losses=g.early.sum()/g.loss.sum() if g.loss.sum() else np.nan,mean_r=g.result_r.mean(),pnl=g.net_pnl_before_unknown_swap_usd.sum(),weeks=g.entry_week.nunique())

rows=[]
for keys in [['method'],['symbol'],['cell'],['cell','entry_year']]:
    for values,g in d.groupby(keys,observed=True):
        if not isinstance(values,tuple): values=(values,)
        rows.append(dict(scope='|'.join(keys),**dict(zip(keys,values)),**summarize(g)))
pd.DataFrame(rows).to_csv(OUT/'group_summary.csv',index=False)
rows=[]
for scope,keys in [('pooled',[]),('family',['method']),('cell',['cell']),('cell_year',['cell','entry_year'])]:
    grouped=d.groupby(keys,observed=True) if keys else [((),d)]
    for values,g in grouped:
        if not isinstance(values,tuple): values=(values,)
        meta=dict(zip(keys,values))
        for feature in ['h1_alignment','h4_alignment','vol_bucket','cloud_position']:
            for bucket,sub in g.groupby(feature,observed=True,dropna=False):
                rest=g.loc[~g.index.isin(sub.index)]
                rows.append(dict(scope=scope,**meta,feature=feature,bucket=str(bucket),**summarize(sub),rest_n=len(rest),rest_early_rate=rest.early.mean(),early_diff_pp=100*(sub.early.mean()-rest.early.mean()),rest_win_rate=rest.win.mean(),win_diff_pp=100*(sub.win.mean()-rest.win.mean())))
s=pd.DataFrame(rows)
s.to_csv(OUT/'feature_slices.csv',index=False)
d.to_parquet(OUT/'joined_trades.parquet',index=False)
flags=[]
for row in s.loc[s.scope.eq('cell') & s.n.ge(40) & s.rest_n.ge(40)].itertuples(index=False):
    years=s.loc[s.scope.eq('cell_year') & s.cell.eq(row.cell) & s.feature.eq(row.feature) & s.bucket.eq(row.bucket)]
    if len(years)!=2: continue
    flags.append(dict(cell=row.cell,feature=row.feature,bucket=row.bucket,n=row.n,early=row.early,wins=row.wins,losses=row.losses,early_rate=row.early_rate,rest_n=row.rest_n,rest_early_rate=row.rest_early_rate,diff_pp=row.early_diff_pp,win_rate=row.win_rate,rest_win_rate=row.rest_win_rate,year2024_n=int(years.loc[years.entry_year.eq(2024),'n'].iloc[0]),year2025_n=int(years.loc[years.entry_year.eq(2025),'n'].iloc[0]),year2024_diff=float(years.loc[years.entry_year.eq(2024),'early_diff_pp'].iloc[0]),year2025_diff=float(years.loc[years.entry_year.eq(2025),'early_diff_pp'].iloc[0])))
f=pd.DataFrame(flags).sort_values('diff_pp',ascending=False)
f.to_csv(OUT/'within_cell_comparisons.csv',index=False)
print(pd.DataFrame(rows).loc[lambda x:x.scope.eq('pooled'),['feature','bucket','n','early','wins','early_rate','rest_early_rate','early_diff_pp']].to_string(index=False))
print('\nFAMILIES\n'+pd.read_csv(OUT/'group_summary.csv').loc[lambda x:x.scope.eq('method')].to_string(index=False))
print('\nWITHIN CELL\n'+f.to_string(index=False))
(OUT/'qa.json').write_text(json.dumps(dict(status='PASS',n=len(d),early=int(d.early.sum()),losses=int(d.loss.sum()),year_max=int(d.entry_year.max()),new_filters_applied=False,source_unchanged_by_script=True),indent=2))
