"""Independent artifact audit; never alter research results."""
import argparse
import json
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd

from .data import sha, load_dataset
from .run import source_manifest


def verify(out, require_completed=True):
    out = Path(out)
    manifest = json.loads((out/'manifest.json').read_text(encoding='utf-8'))
    if require_completed:
        assert manifest['status'] == 'completed'
    cfg = manifest['config']
    data = json.loads(Path(manifest['data_manifest']).read_text(encoding='utf-8'))
    assert sha(manifest['data_manifest']) == manifest['data_manifest_sha256']
    protected = json.loads((out/'protected_before.json').read_text(encoding='utf-8'))
    assert all(sha(p) == value for p, value in protected.items())
    primary = pd.read_parquet(out/'primary.parquet')
    assert not primary.duplicated(['symbol','timeframe','method','side']).any()
    rng = np.random.default_rng(cfg['seed'])
    checks, n_outcomes = [], 0
    for (symbol, tf), group in primary.groupby(['symbol','timeframe']):
        b = load_dataset(data, symbol, tf, cfg)
        f = pd.read_parquet(out/symbol/tf/'features.parquet')
        c = pd.read_parquet(out/symbol/tf/'candidates.parquet')
        assert (b.time < 1767225600).all() and (c.signal_time < 1767225600).all()
        step, spec = cfg['timeframes'][tf], data['specs'][symbol]
        for row in group.to_dict('records'):
            cell = out/symbol/tf/(row['method']+'_'+row['side'])
            events = c[c.method.eq(row['method']) & c.side.eq(row['side'])]
            outcomes = pd.read_parquet(cell/'outcomes.parquet')
            assert len(events) == row['n_candidates']
            assert len(outcomes) == len(events)*len(cfg['horizons'])
            assert len(outcomes[outcomes.horizon.eq(10) & outcomes.complete]) == row['n']
            assert outcomes.candidate_id.nunique() == len(events)
            assert outcomes.loc[~outcomes.complete, 'net_atr'].isna().all()
            complete = outcomes[outcomes.complete]
            if len(complete):
                selected = complete.iloc[rng.choice(len(complete), min(20,len(complete)), replace=False)]
                for record in selected.to_dict('records'):
                    entry = int(record['entry_index'])
                    segment = b.iloc[entry:entry+int(record['horizon'])]
                    assert len(segment) == record['horizon']
                    assert np.array_equal(segment.time, np.arange(len(segment))*step+record['entry_time'])
                    sign = 1 if record['side'] == 'LONG' else -1
                    pip = spec['pip_size']
                    gross = sign*(segment.close.iloc[-1]-segment.open.iloc[0])/pip
                    spread = segment.spread.iloc[0 if sign == 1 else -1]
                    cost = (spread*spec['point']/pip if spread > 0 else cfg['assumed_spread_pips'][symbol])+2*cfg['slippage_pips_per_side']
                    np.testing.assert_allclose([record['gross_pips'],record['net_pips']], [gross,gross-cost],rtol=1e-10,atol=1e-10)
                    fav = segment.high.max()-segment.open.iloc[0] if sign == 1 else segment.open.iloc[0]-segment.low.min()
                    adv = segment.open.iloc[0]-segment.low.min() if sign == 1 else segment.high.max()-segment.open.iloc[0]
                    np.testing.assert_allclose([record['mfe_atr'],record['mae_atr']], [fav/record['atr14'],adv/record['atr14']],rtol=1e-10,atol=1e-10)
                    n_outcomes += 1
            for kind in ['unconditional','conditional']:
                draws = pd.read_parquet(cell/(kind+'_draws.parquet'))
                control = pd.read_parquet(cell/(kind+'_outcomes.parquet'))
                assert len(draws) == row['n']*cfg['baseline_repeats'] == len(control)
                assert control.complete.all()
                assert not draws.duplicated(['replicate','signal_index']).any()
                if len(draws):
                    assert f.loc[draws.signal_index, 'comparison_eligible'].all()
                    keys = ['year']+(['hour','weekday','vol_bucket'] if kind == 'conditional' else [])
                    observed = events[events.comparison_eligible].groupby(keys, observed=True).size().sort_index()
                    for rep, sample in draws.groupby('replicate'):
                        pd.testing.assert_series_equal(sample.groupby(keys, observed=True).size().sort_index(), observed, check_names=False)
                log = pd.read_parquet(cell/(kind+'_matching_audit.parquet'))
                if len(log):
                    assert (log.requested_n == log.sampled_n).all()
            ledger = pd.read_parquet(cell/'execution_events.parquet')
            assert len(ledger) == 2*len(events)
            checks.append(dict(symbol=symbol,timeframe=tf,method=row['method'],side=row['side'],status='PASS'))
    if require_completed:
        with duckdb.connect(str(out/'research.duckdb'), read_only=True) as db:
            assert db.execute('SELECT count(*) FROM "primary"').fetchone()[0] == len(primary)
    result = {'status':'PASS','cells':len(checks),'independently_recomputed_outcomes':n_outcomes,
              'protected_files_unchanged':len(protected),'input_hashes_verified':True,
              'same_current_source_hashes':manifest['source_hashes']==source_manifest(),
              'completed_required':require_completed,'holdout_2026_used':False}
    qa = out/'qa'
    qa.mkdir(exist_ok=True)
    pd.DataFrame(checks).to_csv(qa/'artifact_audit.csv', index=False)
    (qa/'artifact_audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    return result


if __name__ == '__main__':
    p=argparse.ArgumentParser()
    p.add_argument('run')
    p.add_argument('--allow-incomplete', action='store_true')
    a=p.parse_args()
    print(json.dumps(verify(a.run, not a.allow_incomplete), indent=2))
