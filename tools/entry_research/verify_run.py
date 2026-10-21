"""Independent artifact checks and numerical reproducibility comparison.

Run from repository root:
python -m tools.entry_research.verify_run --run ... --compare ... --out ...json
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
import pandas as pd


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(run: Path, compare: Path | None = None):
    checks = {}
    meta = json.loads((run/'manifest.json').read_text(encoding='utf-8'))
    cfg = json.loads((run/'config.json').read_text(encoding='utf-8'))
    assert json.loads((run/'status.json').read_text())['stage'] == 'complete'
    for name, expected in meta['result_sha256'].items():
        assert digest(run/name) == expected, name
    checks['result_csv_hashes'] = len(meta['result_sha256'])
    dataset = Path(meta['data_dir'])
    assert digest(dataset/'dataset_manifest.json') == meta['dataset_manifest_sha256']
    dm = json.loads((dataset/'dataset_manifest.json').read_text(encoding='utf-8'))
    for name, expected in dm['outputs_sha256'].items():
        assert digest(dataset/name) == expected, name
    for source in dm.get('sources',[]):
        assert digest(Path(source['path'])) == source['sha256'], source['path']
    checks['dataset_and_original_hashes'] = 'pass'
    f = pd.read_parquet(run/'features.parquet')
    c = pd.read_parquet(run/'candidates.parquet')
    b = pd.read_parquet(run/'controls.parquet')
    assert (f.time < cfg['end_exclusive']).all()
    assert (c.signal_time < cfg['end_exclusive']).all()
    assert (b.entry_time < cfg['end_exclusive']).all()
    for tf in ('h1','m15'):
        usable = f.loc[f[tf+'_available_time'].notna()]
        assert (usable[tf+'_available_time'] <= usable.signal_time).all()
        assert (usable[tf+'_close_time'] <= usable.signal_time).all()
    executable = c.loc[c.decision_eligible]
    assert (executable.entry_time >= executable.signal_time).all()
    assert (executable.entry_index > executable.signal_index).all()
    assert (executable.entry_delay_seconds <= cfg['max_entry_delay_seconds']).all()
    checks.update({'raw_candidates':len(c),'common_candidates':int(c.eligible.sum()),
                   'baseline_rows':len(b),'holdout_and_time_contract':'pass'})
    audit = pd.read_csv(run/'baseline_match_audit.csv')
    assert (audit.requested_n == audit.sampled_n).all()
    assert (audit.sampled_n == audit.sampled_distinct_n).all()
    assert (audit.sampled_n <= audit.pool_n).all()
    keys = ['symbol','year','hour','weekday','vol_bucket','method','side']
    target = c.loc[c.eligible].groupby(keys, observed=True).size().sort_index()
    for _,rep in b.groupby('replicate'):
        pd.testing.assert_series_equal(target,rep.groupby(keys,observed=True).size().sort_index())
    checks['matched_baseline_strata'] = len(audit)
    chart_checks = []
    for path in sorted((run/'charts').glob('*.audit.json')):
        a = json.loads(path.read_text())
        assert not a['future_candles_included']
        for tf,values in a['timeframes'].items():
            assert values['max_close_time'] <= a['decision_time']
            assert values['max_available_time'] <= a['decision_time']
        chart_checks.append(path.name)
    checks['chart_time_audits'] = chart_checks
    rates = pd.read_csv(run/'barrier_rates.csv')
    assert np.array_equal(rates.n.to_numpy(),rates[['tp_first_n','sl_first_n','ambiguous_n','neither_n','censored_n']].sum(axis=1).to_numpy())
    assert (rates.tp_first_rate <= rates.tp_first_upper_bound).all()
    checks['barrier_partition'] = 'pass'
    if compare:
        assert json.loads((compare/'status.json').read_text())['stage']=='complete'
        assert json.loads((compare/'config.json').read_text()) == cfg
        comparisons = []
        for path in sorted(run.glob('*.csv')):
            other=compare/path.name
            assert other.exists(), other
            pd.testing.assert_frame_equal(pd.read_csv(path),pd.read_csv(other),check_exact=False,atol=1e-12,rtol=1e-12)
            comparisons.append({'file':path.name,'exact_sha256_equal':digest(path)==digest(other),'numeric_tolerance':1e-12})
        for name in ('features.parquet','candidates.parquet','controls.parquet','summary.parquet'):
            pd.testing.assert_frame_equal(pd.read_parquet(run/name),pd.read_parquet(compare/name),check_exact=True)
        checks['reproducibility']={'csv':comparisons,'exact_parquet_tables':['features','candidates','controls','summary']}
    return {'status':'PASS','run':str(run),'compare':str(compare) if compare else None,'checks':checks}


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--run',required=True,type=Path)
    parser.add_argument('--compare',type=Path)
    parser.add_argument('--out',required=True,type=Path)
    args=parser.parse_args()
    result=verify(args.run,args.compare)
    args.out.parent.mkdir(parents=True,exist_ok=True)
    with args.out.open('x',encoding='utf-8') as file:
        json.dump(result,file,indent=2,ensure_ascii=False)
    print(json.dumps(result,ensure_ascii=False))
