"""Read frozen ledgers, compare early winners/stops, preserve all source files."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
import numpy as np
import pandas as pd
import duckdb

from ..account_replay.calendar import annotate_bars, WEEKEND_POLICY
from .analysis import FEATURES, LOCK, labels, pre_entry_features, path_features, group_summary, comparisons
from .report import render

SOURCE=Path('reports/research/account_replay_20261017/validated')
OLD=Path('reports/research/multiasset_20261016/full_validated')
DATA=Path('reports/research/multiasset_20261016/data')
PLAN=Path('knowledge/experiments/2026-10-18-early-loss-plan.md')


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def run(out):
    out=Path(out)
    if out.exists():raise FileExistsError('Use new output; existing results are protected')
    accounts=pd.read_parquet(SOURCE/'accounts.parquet')
    cells=accounts.loc[accounts.profit_factor.gt(1),['symbol','timeframe','method','side']].drop_duplicates().sort_values(['symbol','method','side'])
    assert len(cells)==10 and cells.timeframe.eq('H1').all()
    manifest=json.loads((DATA/'manifest.json').read_text(encoding='utf-8'))
    original=json.loads((SOURCE/'manifest.json').read_text(encoding='utf-8'))
    for p,h in original['source_hashes'].items():assert sha(p)==h, p
    files=[PLAN,SOURCE/'accounts.parquet',SOURCE/'manifest.json',DATA/'manifest.json']
    for c in cells.itertuples(index=False):
        files += [SOURCE/c.symbol/'H1'/f'{c.method}_{c.side}'/'execution_trades.parquet',OLD/c.symbol/'H1'/'candidates.parquet',DATA/c.symbol/'H1.parquet']
    protected={str(p.resolve()):sha(p) for p in set(files)}
    details=[]
    for c in cells.itertuples(index=False):
        raw=pd.read_parquet(SOURCE/c.symbol/'H1'/f'{c.method}_{c.side}'/'execution_trades.parquet')
        t=raw.loc[raw.scenario.eq('stop_first_lower')].reset_index(drop=True)
        assert t.status.eq('closed').all()
        candidates=pd.read_parquet(OLD/c.symbol/'H1'/'candidates.parquet')
        b=annotate_bars(pd.read_parquet(DATA/c.symbol/'H1.parquet'),3600,WEEKEND_POLICY)
        spec=manifest['specs'][c.symbol]
        feat=pre_entry_features(t,candidates,spec)
        path=pd.DataFrame([path_features(row,feat.iloc[i],b,spec) for i,row in enumerate(t.itertuples(index=False))])
        d=pd.concat([t,feat,path],axis=1)
        d['label']=labels(t)
        d['cell']=f'{c.symbol}_{c.method}_{c.side}'
        dt=pd.to_datetime(d.entry_time,unit='s',utc=True)
        d['year']=dt.dt.year
        d['week']=(dt.dt.normalize()-pd.to_timedelta(dt.dt.dayofweek,unit='D')).dt.strftime('%Y-%m-%d')
        details.append(d)
    df=pd.concat(details,ignore_index=True)
    assert len(df)==2666 and df.label.eq('early_stop').sum()==752 and df.label.eq('early_win').sum()==696
    assert not df.candidate_id.duplicated().any()
    summary=[]
    for key in ['all','method','cell','year']:
        groups=[('all',df)] if key=='all' else df.groupby(key)
        for value,part in groups:summary.append(dict(scope=key,group=str(value),**group_summary(part)))
    dedup=df.sort_values(['symbol','side','entry_time','method']).drop_duplicates(['symbol','side','entry_time'])
    summary.append(dict(scope='sensitivity',group='unique_timestamp_alphabetical_method',**group_summary(dedup)))
    medians=[]
    metric_cols=FEATURES+['fill_stop_atr','quote_stop_distance_atr','quote_target_distance_atr','entry_spread_proxy_atr','stop_atr_pips']
    for scope in ['all','method','cell']:
        groups=[('all',df)] if scope=='all' else df.groupby(scope)
        for name,sub in groups:
            for lab in ['early_stop','early_win','late_stop','all_win']:
                part=sub.loc[sub.net_pnl_before_unknown_swap_usd.gt(1e-10)] if lab=='all_win' else sub.loc[sub.label.eq(lab)]
                for f in metric_cols:
                    x=part[f].dropna()
                    medians.append(dict(scope=scope,group=name,label=lab,feature=f,n=len(x),mean=x.mean(),median=x.median(),q25=x.quantile(.25),q75=x.quantile(.75)))
    contexts=[]
    for cell,sub in df.groupby('cell'):
        for feature in ['h1_alignment','h4_alignment','vol_bucket','cloud_position']:
            for bucket,part in sub.groupby(feature,dropna=False,observed=True):
                row=dict(cell=cell,feature=feature,bucket=str(bucket),**group_summary(part))
                for year in [2024,2025]:
                    for k,v in group_summary(part.loc[part.year.eq(year)]).items():row[f'{k}_{year}']=v
                contexts.append(row)
    paths=[]
    for key in ['all','method','cell']:
        groups=[('all',df)] if key=='all' else df.groupby(key)
        for value,part in groups:
            p=part.loc[part.label.eq('early_stop')]
            row=dict(scope=key,group=value,n_early_stop=len(p),
                     proxy_stop_inside_signal_range_n=int(p.proxy_stop_inside_signal_range.sum()),
                     no_neutral_stop_through_exit_n=int(p.neutral_stop_reached_through_exit.eq(False).sum()),
                     neutral_stop_valid_first2=int(p.neutral_stop_reached_first2.notna().sum()),
                     no_neutral_stop_first2_n=int(p.neutral_stop_reached_first2.eq(False).sum()))
            for h in [2,5,10]:
                x=p[f'bid_close_return_atr_h{h}'].dropna()
                row.update({f'valid_h{h}':len(x),f'missing_h{h}':len(p)-len(x),f'returned_to_bid_open_h{h}':int(x.ge(0).sum()),f'above_plus1_atr_h{h}':int(x.ge(1).sum()),f'mean_bid_close_atr_h{h}':x.mean(),f'median_bid_close_atr_h{h}':x.median()})
            paths.append(row)
    inference,rate_ci=comparisons(df)
    tables=dict(trade_diagnostics=df,group_counts=pd.DataFrame(summary),feature_comparisons=pd.DataFrame(medians),context_comparisons=pd.DataFrame(contexts),post_exit_paths=pd.DataFrame(paths),feature_block_intervals=inference)
    if any(sha(p)!=h for p,h in protected.items()):raise ValueError('Source input changed')
    out.mkdir(parents=True)
    for name,frame in tables.items():
        frame.to_csv(out/f'{name}.csv',index=False,encoding='utf-8-sig')
        frame.to_parquet(out/f'{name}.parquet',index=False)
    with duckdb.connect(str(out/'early_loss.duckdb')) as db:
        for name,frame in tables.items():
            db.register('frame',frame);db.execute(f'CREATE TABLE {name} AS SELECT * FROM frame');db.unregister('frame')
    final=dict(status='complete',holdout_2026_used=False,new_filters_applied=False,source_clock_verified=False,swaps_verified=False,
               selection='10 posthoc PF-positive conditions; conservative scenario',trade_n=len(df),unique_timestamps=len(dedup),early_loss_rate_difference_ci=rate_ci,
               bootstrap_seed=20261018,features_fixed=FEATURES,inputs_sha256=protected,inputs_unchanged=True,
               source_hashes={str(p.resolve()):sha(p) for p in Path(__file__).parent.rglob('*.py')},git_head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip())
    (out/'manifest.json').write_text(json.dumps(final,ensure_ascii=False,indent=2),encoding='utf-8')
    render(out,tables,final)
    (out/'output_hashes.json').write_text(json.dumps({p.name:sha(p) for p in out.iterdir() if p.is_file()},indent=2),encoding='utf-8')
    print(tables['group_counts'].to_string(index=False));print(inference.to_string(index=False));print(json.dumps(rate_ci))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--out',required=True)
    run(parser.parse_args().out)
