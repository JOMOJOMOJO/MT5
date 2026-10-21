"""Replay frozen candidates with a versioned execution repair, never optimize."""
import argparse
import importlib.metadata
import json
from pathlib import Path
import subprocess
import pandas as pd
import duckdb
from .calendar import WEEKEND_POLICY
from .execution import simulate
from ..multiasset.data import sha,load_dataset,stamp
from ..multiasset.run import save,protect_snapshot


def source_hashes():
    files=list(Path(__file__).parent.rglob('*.py'))
    files+=[Path('tools/entry_research/multiasset')/n for n in ['execution.py','data.py','run.py']]
    return {str(p.resolve()):sha(p) for p in files}


def run(source,out):
    source,out=Path(source).resolve(),Path(out).resolve()
    if out.exists():raise FileExistsError('New immutable output directory required')
    old=json.loads((source/'manifest.json').read_text(encoding='utf-8'));cfg=old['config']
    assert old['status']=='completed' and cfg['end']=='2026-01-01'
    data_path=Path(old['data_manifest']);assert sha(data_path)==old['data_manifest_sha256']
    data=json.loads(data_path.read_text(encoding='utf-8'))
    protected=protect_snapshot()
    for p in source.rglob('*'):
        if p.is_file():protected[str(p)]=sha(p)
    for rec in data['datasets']:
        if rec.get('status')=='available':
            assert sha(rec['path'])==rec['sha256'];protected[rec['path']]=rec['sha256']
    for p in Path('tools/entry_research/multiasset').rglob('*'):
        if p.is_file() and p.suffix in ['.py','.json','.md']:protected[str(p.resolve())]=sha(p)
    out.mkdir(parents=True)
    (out/'protected_before.json').write_text(json.dumps(protected,indent=2),encoding='utf-8')
    hashes=source_hashes()
    manifest=dict(status='running',source_run=str(source),source_run_manifest_sha256=sha(source/'manifest.json'),
        data_manifest=str(data_path),data_manifest_sha256=sha(data_path),
        config=cfg,calendar_policy=WEEKEND_POLICY,source_hashes=hashes,
        source_candidates_unchanged=True,holdout_2026_used=False,
        git_head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        dependencies={x:importlib.metadata.version(x) for x in ['numpy','pandas','pyarrow','duckdb','pytest']},
        purpose='execution_repair_not_parameter_search',all_costs_verified=False)
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    records=[]
    for symbol in cfg['symbols']:
        for tf in cfg['entry_timeframes']:
            b=load_dataset(data,symbol,tf,cfg)
            c=pd.read_parquet(source/symbol/tf/'candidates.parquet')
            spec=dict(data['specs'][symbol]);spec['trade_tick_size']=spec['tick_size']
            data_record=next(r for r in data['datasets'] if r.get('symbol')==symbol and r.get('timeframe')==tf)
            conf=dict(cfg,timeframe_seconds=cfg['timeframes'][tf],end_exclusive=stamp(cfg['end']),
                      max_entry_delay_seconds=cfg['timeframes'][tf],
                      assumed_spread_pips=cfg['assumed_spread_pips'][symbol],calendar_policy=WEEKEND_POLICY)
            for method in cfg['methods']:
                for side in ['LONG','SHORT']:
                    events=c[c.method.eq(method)&c.side.eq(side)].copy()
                    cell=out/symbol/tf/(method+'_'+side)
                    result=simulate(b,events,spec,conf)
                    for name,table in result.items():save(table,cell,'execution_'+name,csv=name=='summary')
                    records.extend(result['summary'].assign(timeframe=tf,
                        data_months=data_record['months_with_data'],
                        requested_period_available=data_record['months_with_data']==24).to_dict('records'))
            print(symbol,tf,'completed',len(records),'account scenarios',flush=True)
    accounts=pd.DataFrame(records);save(accounts,out,'accounts')
    old_accounts=pd.read_parquet(source/'accounts.parquet')
    keys=['symbol','timeframe','method','side','scenario']
    comp=old_accounts.merge(accounts,on=keys,suffixes=('_old','_new'),validate='one_to_one')
    save(comp,out,'comparison')
    with duckdb.connect(str(out/'accounts.duckdb')) as db:
        for name,table in [('accounts',accounts),('comparison',comp)]:
            db.register('frame',table);db.execute(f'CREATE TABLE {name} AS SELECT * FROM frame');db.unregister('frame')
        for name in ['trades','events','equity']:
            pattern=(out/'*/*/*'/('execution_'+name+'.parquet')).as_posix().replace("'","''")
            db.execute(f"CREATE VIEW {name} AS SELECT * FROM read_parquet('{pattern}',union_by_name=true)")
    assert all(sha(p)==value for p,value in protected.items()),'Protected source changed'
    assert hashes==source_hashes(),'Code changed during run'
    manifest.update(status='completed',protected_files_unchanged=len(protected),source_unchanged_during_run=True,
                    output_hashes={p.name:sha(p) for p in out.glob('*.parquet')})
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    return out


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',required=True);p.add_argument('--out',required=True)
    a=p.parse_args();print(run(a.source,a.out))
