"""Read-only intake QA. Never fit models or summarize holdout returns."""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import re
import subprocess
from pathlib import Path
import numpy as np
import pandas as pd


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def keyvalues(text):
    return dict(item.split('=', 1) for item in text.split(';') if '=' in item)


def text_file(path):
    with path.open('rb') as f:
        encoding = 'utf-16' if f.read(2) in (b'\xff\xfe', b'\xfe\xff') else 'utf-8-sig'
    return path.read_text(encoding=encoding, errors='replace')


def dump(rows, path):
    pd.DataFrame(rows).to_csv(path, index=False, lineterminator='\n')


def audit(args):
    root, out = Path(args.input), Path(args.output)
    if out.exists():
        raise ValueError('Fresh output required; will not overwrite existing evidence')
    out.mkdir(parents=True)
    runid = root.name
    prefix = f'ExpectedValue_MultiCurrency_TickShockResearch_{runid}_'
    paths = [root/'technical_features.csv', root/'technical_outcomes.csv',
             root/(prefix+'summary.csv'), root/(prefix+'summary.csv.runmeta'),
             root/(prefix+'medium_horizon_episode_summary.csv')]
    hashes = [dict(path=str(p), bytes=p.stat().st_size, sha256=sha(p)) for p in paths]
    dump(hashes, out/'input_hashes.csv')
    summary = pd.read_csv(paths[2])
    integrity = keyvalues(summary.loc[summary.record_type.eq('INTEGRITY'), 'value'].iloc[0])
    # Keep only operational counters, not legacy profit/strategy result columns.
    dump([dict(key=k, value=v) for k, v in integrity.items()], out/'run_integrity.csv')
    f = pd.read_csv(paths[0])
    o = pd.read_csv(paths[1], usecols=['episode_id','symbol','market_cluster_id','t0_msc',
        'signal_processing_msc','direction','distance_index','entry_msc','exit_msc',
        'entry_eligible_msc','source_quote_msc','entry_bid','entry_ask','entry_price',
        'entry_spread','distance','pip_size','tick_size','sl','tp','status'])
    mh = pd.read_csv(paths[4], usecols=lambda c: c in ['episode_id','symbol','t0_msc','market_cluster_id'])
    checks=[]
    def check(name, value, expected=0, scope='TECHNICAL_CSV'):
        ok = value == expected
        checks.append(dict(check=name, actual=str(value), expected=str(expected),
                           status='PASS' if ok else 'FAIL', scope=scope))
    check('run_validation', integrity.get('validation'), 'VALIDATED', 'RUN')
    check('event_pool_exhaustions', int(integrity.get('event_pool_exhaustions','-1')), scope='LEGACY_SCENARIO_POOL')
    for key in ('pending_capacity_hits','dropped_ticks','cursor_stalls'):
        check(key, int(integrity.get(key,'-1')), scope='GLOBAL_TICKS')
    check('duplicate_feature_episode', int(f.episode_id.duplicated().sum()))
    check('duplicate_outcome_key', int(o.duplicated(['episode_id','direction','distance_index']).sum()))
    check('outcome_without_feature', len(set(o.episode_id)-set(f.episode_id)))
    check('feature_without_outcome', len(set(f.episode_id)-set(o.episode_id)))
    check('episodes_not_twelve_outcomes', int(o.groupby('episode_id').size().ne(12).sum()))
    check('invalid_direction', int((~o.direction.isin([1,-1])).sum()))
    check('invalid_distance_index', int((~o.distance_index.isin(range(6))).sum()))
    check('future_feature_count', int(f.feature_future_count.sum()))
    check('feature_source_after_t0', int((f.feature_max_close_msc>f.t0_msc).sum()))
    check('feature_quote_after_t0', int((f.t0_quote_msc>f.t0_msc).sum()))
    check('recognition_before_event', int((f.t0_processing_msc<f.t0_msc).sum()))
    keys=o.merge(f[['episode_id','symbol','market_cluster_id','t0_msc','t0_processing_msc','t0_quote_msc']],on='episode_id',suffixes=('_o','_f'),validate='many_to_one')
    for key in ('symbol','market_cluster_id','t0_msc'):
        check('joined_'+key+'_mismatch',int(keys[key+'_o'].ne(keys[key+'_f']).sum()))
    check('joined_processing_mismatch',int(keys.signal_processing_msc.ne(keys.t0_processing_msc).sum()))
    check('joined_source_quote_mismatch',int(keys.source_quote_msc.ne(keys.t0_quote_msc).sum()))
    entered=o[o.entry_msc.gt(0)].copy()
    valid=o[o.status.isin(['TP','SL','TIME','TIMEOUT'])].copy()
    check('entry_before_processing',int((entered.entry_msc<entered.signal_processing_msc).sum()))
    check('entry_before_eligible',int((entered.entry_msc<entered.entry_eligible_msc).sum()))
    check('entry_not_after_t0',int((entered.entry_msc<=entered.t0_msc).sum()))
    check('entry_not_after_source_quote',int((entered.entry_msc<=entered.source_quote_msc).sum()))
    check('exit_before_entry',int((valid.exit_msc<valid.entry_msc).sum()))
    tol=np.maximum(valid.tick_size.to_numpy()*1e-5,1e-10)
    side=np.where(valid.direction.eq(1),valid.entry_ask,valid.entry_bid)
    check('entry_side_mismatch',int((np.abs(valid.entry_price-side)>tol).sum()))
    check('nonpositive_risk',int((valid.distance<=0).sum()))
    check('asymmetric_geometry',int((np.abs(np.abs(valid.tp-valid.entry_price)-np.abs(valid.sl-valid.entry_price))>tol).sum()))
    check('stop_distance_mismatch',int((np.abs(np.abs(valid.sl-valid.entry_price)-valid.distance)>tol).sum()))
    check('cost_distance_guard',int((valid.distance+tol<3*valid.entry_spread).sum()))
    check('technical_episode_missing_from_medium_horizon',len(set(f.episode_id)-set(mh.episode_id)))
    check('medium_horizon_episode_missing_from_technical',len(set(mh.episode_id)-set(f.episode_id)))
    f['month']=pd.to_datetime(f.t0_msc,unit='ms').dt.strftime('%Y-%m')
    f['day']=pd.to_datetime(f.t0_msc,unit='ms').dt.strftime('%Y-%m-%d')
    f['split']=np.where(f.t0_msc<pd.Timestamp('2025-05-01').value//1000000,'TRAIN','HELD_OUT')
    cluster_cross=f.groupby('market_cluster_id')['split'].nunique()
    # Crossing clusters must be purged in a later split, not divided into train/test.
    crossing_ids=cluster_cross.index[cluster_cross.gt(1)]
    dump(f[f.market_cluster_id.isin(crossing_ids)][['episode_id','market_cluster_id','t0_msc','split']],out/'boundary_clusters.csv')
    population=[]
    for (month,symbol),g in f.groupby(['month','symbol']):
        population.append(dict(month=month,symbol=symbol,episodes=len(g),market_clusters=g.market_cluster_id.nunique(),
            first_encoded_time=str(pd.to_datetime(g.t0_msc.min(),unit='ms')),
            last_encoded_time=str(pd.to_datetime(g.t0_msc.max(),unit='ms'))))
    dump(population,out/'monthly_symbol_population.csv')
    monthly=f.groupby('month').agg(episodes=('episode_id','size'),market_clusters=('market_cluster_id','nunique')).reset_index()
    monthly.to_csv(out/'monthly_population.csv',index=False,lineterminator='\n')
    safe=[]
    for logfile in args.journal:
        lines=text_file(Path(logfile)).splitlines()
        for line in lines:
            if ('technical_discovery episodes=' in line or
                'technical_candidate signals=' in line or
                ('testing of Experts' in line and 'TechnicalCandidate' in line) or
                ('ticks' in line and 'generated' in line and 'test passed' in line)):
                safe.append(dict(source=str(logfile),line=line))
    # End summaries from target finish; do not treat any historical run as target.
    ends=[x for x in safe if '2025.06.27 23:56:59' in x['line']]
    tech=[x for x in ends if 'technical_discovery episodes=' in x['line']]
    if len(tech)==1:
        counters=dict(re.findall(r'(episodes|censored|capacity|feature_invalid)=(\d+)',tech[0]['line']))
        check('journal_episode_reconciliation',len(f),int(counters['episodes']))
        check('technical_pool_capacity_hits',int(counters['capacity']),scope='TECHNICAL_POOL')
        check('technical_feature_invalid',int(counters['feature_invalid']),scope='TECHNICAL_POOL')
    else:
        checks.append(dict(check='target_technical_end_journal',actual=len(tech),expected=1,status='NOT_OBSERVED',scope='JOURNAL'))
    dump(ends,out/'journal_end_evidence.csv')
    dump(checks,out/'qa_checks.csv')
    meta=text_file(paths[3]).splitlines()[1]
    # Only share execution provenance fields; never account IDs or credentials.
    metadata=dict(item.split('=',1) for item in meta.split('|') if '=' in item)
    selected={k:metadata.get(k) for k in ['period','model','broker_server','terminal_build','source_commit','ex5_hash','schema']}
    result=dict(phase='INTAKE_ONLY_NO_MODEL_OR_HOLDOUT_PROFIT_EVALUATION',
        verdict='BLOCKED_RUN_INTEGRITY' if integrity.get('validation')!='VALIDATED' else 'QA_REVIEW_REQUIRED',
        episodes=len(f),outcome_rows=len(o),feature_columns=len(f.columns)-3-13,
        market_clusters=int(f.market_cluster_id.nunique()),
        first_encoded_time=str(pd.to_datetime(f.t0_msc.min(),unit='ms')),
        last_encoded_time=str(pd.to_datetime(f.t0_msc.max(),unit='ms')),
        train_episodes=int(f['split'].eq('TRAIN').sum()),holdout_episodes=int(f['split'].eq('HELD_OUT').sum()),
        censored_outcomes=int(o.status.eq('CENSORED').sum()),
        censored_episodes=int(o.loc[o.status.eq('CENSORED'),'episode_id'].nunique()),
        medium_horizon_episodes=len(mh),cross_boundary_clusters=len(crossing_ids),
        checks=pd.Series([x['status'] for x in checks]).value_counts().to_dict(),
        integrity=integrity,metadata=selected,
        pandas=pd.__version__,numpy=np.__version__,script_sha256=sha(__file__))
    # Hash after reading to detect concurrent changes without rewriting any input.
    result['input_hashes_unchanged']=all(sha(x['path'])==x['sha256'] for x in hashes)
    if not result['input_hashes_unchanged']:raise ValueError('Inputs changed during audit')
    (out/'intake_summary.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps(result,indent=2,ensure_ascii=False))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--input',required=True);p.add_argument('--output',required=True)
    p.add_argument('--journal',action='append',default=[])
    audit(p.parse_args())
