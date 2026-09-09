"""Formal discovery provenance checks, separate from model selection."""
import argparse
import hashlib
import json
from pathlib import Path
import pandas as pd


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--run', type=Path, required=True)
    p.add_argument('--baseline', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    a.output.mkdir(parents=True, exist_ok=True)
    rows = []
    def check(name, actual, expected=0):
        rows.append(dict(check=name, actual=actual, expected=expected,
                         status='PASS' if actual == expected else 'FAIL'))
    f = pd.read_csv(a.run/'features.csv')
    o = pd.read_csv(a.run/'outcomes.csv')
    e = pd.read_csv(a.run/'medium_horizon_episode_summary.csv')
    baseline = pd.read_csv(a.baseline/'medium_horizon_episode_summary.csv')
    keys = ['symbol', 'anchor_msc', 'shock_direction']
    check('frozen_episode_keys', set(map(tuple,e[keys].values)) == set(map(tuple,baseline[keys].values)), True)
    stable = ['market_cluster_id','anchor_processing_msc','anchor_bid','anchor_ask','repeat_count','last_shock_msc']
    merged = e.merge(baseline, on=keys, suffixes=('_new','_old'), validate='one_to_one')
    for name in stable:
        check('frozen_'+name, int((merged[name+'_new'] != merged[name+'_old']).sum()))
    check('feature_episode_membership', set(f.episode_id) == set(e.episode_id), True)
    ef = f.merge(e, on='episode_id', suffixes=('_feature','_episode'), validate='one_to_one')
    check('cluster_provenance', int((ef.market_cluster_id_feature != ef.market_cluster_id_episode).sum()))
    check('episode_t0_provenance', int((ef.t0_msc != ef.anchor_msc).sum()))
    check('episode_processing_provenance', int((ef.t0_processing_msc != ef.anchor_processing_msc).sum()))
    for name in ['drops','capacity_losses','future_reads','backdates']:
        check('episode_'+name, int(e[name].sum()))
    check('twelve_rows_per_episode', int((o.groupby('episode_id').size() != 12).sum()))
    check('actual_order_records', len(pd.read_csv(a.run/'trades.csv')))
    hashes = []
    for line in (a.run/'source_hashes.txt').read_text(encoding='utf-8-sig').splitlines():
        if '  ' not in line:
            continue
        expected, path = line.split('  ',1)
        source = Path(path)
        actual = hashlib.sha256(source.read_bytes()).hexdigest().upper() if source.exists() else 'MISSING'
        hashes.append(dict(path=path, recorded_sha256=expected, current_sha256=actual,
                           status='PASS' if actual == expected else 'FAIL'))
    check('formal_dependency_hash_mismatch', sum(x['status']=='FAIL' for x in hashes))
    valid = o[o.status.isin(['TP','SL','TIME'])]
    diagnostics = dict(episodes=len(f), market_clusters=int(f.market_cluster_id.nunique()),
        raw_outcome_rows=len(o), completed_direction_geometry_rows=len(valid),
        hold_max_seconds=float(((valid.exit_msc-valid.entry_msc)/1000).max()),
        hold_over_901_seconds=int(((valid.exit_msc-valid.entry_msc)>901000).sum()),
        processing_delay_max_ms=int((f.t0_processing_msc-f.t0_msc).max()),
        processing_delay_median_ms=float((f.t0_processing_msc-f.t0_msc).median()),
        quote_age_max_ms=int((f.t0_msc-f.t0_quote_msc).max()),
        note='900s closes on first available executable quote; gaps are reported, not capped or interpolated')
    pd.DataFrame(rows).to_csv(a.output/'provenance_qa.csv', index=False)
    pd.DataFrame(hashes).to_csv(a.output/'formal_source_hash_audit.csv', index=False)
    (a.output/'execution_diagnostics.json').write_text(json.dumps(diagnostics,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(checks=len(rows),failures=sum(r['status']=='FAIL' for r in rows),**diagnostics),indent=2))
    if any(r['status']=='FAIL' for r in rows):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
