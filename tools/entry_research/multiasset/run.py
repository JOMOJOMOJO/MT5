"""Immutable Phase 3 runs; event outcomes are separate from account ledgers."""
from __future__ import annotations
import argparse
import importlib.metadata
import json
from pathlib import Path
import subprocess

import duckdb
import numpy as np
import pandas as pd

from ..evaluation import evaluate
from .data import sha, load_dataset, stamp
from .strategies import build_features, extract_candidates, complete_mask
from .inference import random_controls, calendar_weights, infer_cell, adjust_family, walk_forward
from .execution import simulate


def save(frame, directory, name, csv=True):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    if len(frame.columns) == 0:
        frame = pd.DataFrame({'status': pd.Series(dtype=str)})
    frame.to_parquet(directory / (name+'.parquet'), index=False)
    if csv:
        frame.to_csv(directory / (name+'.csv'), index=False)


def source_manifest():
    paths = list(Path('tools/entry_research/multiasset').rglob('*.py')) + [Path('tools/entry_research/multiasset/config.json')]
    paths += [Path('tools/entry_research') / n for n in ['evaluation.py', 'features.py', 'statistics.py']]
    paths += list(Path('tools/entry_research/signals').glob('*.py'))
    return {str(p): sha(p) for p in paths}


def protect_snapshot():
    paths = list(Path('tools/entry_research').glob('*.py'))
    for d in ['signals', 'configs', 'diagnostics']:
        paths += [x for x in (Path('tools/entry_research') / d).rglob('*') if x.is_file() and x.suffix in ['.py', '.json']]
    paths += list(Path('reports/research/entry_candidates/data_20261014').glob('*'))
    paths += [Path('mql/Experts') / x for x in ['USDJPY_M1_M5_3WaveIn3Wave_Long.mq5', 'usdjpy_20260402_round_continuation_long.mq5']]
    for root in ['validated_20261014', 'diagnostics_validated_20261015']:
        paths += [x for x in (Path('reports/research/entry_candidates') / root).glob('*') if x.is_file()]
    return {str(p): sha(p) for p in paths if p.is_file()}


def enriched_outcomes(outcomes, events):
    columns = ['candidate_id', 'year', 'month', 'week', 'hour', 'weekday', 'vol_bucket', 'h1_trend', 'm15_trend', 'h4_trend', 'cloud_position', 'range_position', 'entry_index']
    columns += [x for x in ['replicate', 'baseline_kind'] if x in events]
    return outcomes.merge(events[columns], on='candidate_id', validate='many_to_one')


def evaluate_chunks(bars, events, cfg):
    o, b = [], []
    for i in range(0, len(events), 10000):
        outcome, _, barrier = evaluate(bars, events.iloc[i:i+10000], cfg)
        o.append(outcome)
        b.append(barrier)
    if not o:
        outcome, _, barrier = evaluate(bars, events, cfg)
        return outcome, barrier
    return pd.concat(o, ignore_index=True), pd.concat(b, ignore_index=True)


def run(data_dir, out, config, pilot=False):
    out = Path(out)
    if out.exists():
        raise FileExistsError('Run directory is immutable; choose a new --out')
    out.mkdir(parents=True)
    protected = protect_snapshot()
    (out/'protected_before.json').write_text(json.dumps(protected, indent=2), encoding='utf-8')
    data_path = Path(data_dir)/'manifest.json'
    data = json.loads(data_path.read_text(encoding='utf-8'))
    manifest = {'config': config, 'data_manifest': str(data_path.resolve()), 'data_manifest_sha256': sha(data_path),
                'source_hashes': source_manifest(), 'git_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                'git_dirty': True, 'seed': config['seed'], 'pilot': pilot, 'independent_oos': False,
                'dependencies': {p: importlib.metadata.version(p) for p in ['numpy', 'pandas', 'pyarrow', 'duckdb', 'plotly', 'MetaTrader5', 'pytest']},
                'status': 'running', 'broker': data['broker'], 'server': data['server'], 'holdout_2026_used': False}
    (out/'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    (out/'config.json').write_text(json.dumps(config, indent=2), encoding='utf-8')
    weeks, weights = calendar_weights(config)
    primary, descriptive, annual, monthly, wf_rows, environment, accounts, inventory, barriers_summary = [], [], [], [], [], [], [], [], []
    targets = ['USDJPY', 'EURUSD'] if pilot else config['symbols']
    tfs = ['M5', 'M15'] if pilot else config['entry_timeframes']
    for symbol in targets:
        auxiliary = {tf: load_dataset(data, symbol, tf, config) for tf in ['M15', 'H1', 'H4']}
        auxiliary = {tf: df for tf, df in auxiliary.items() if df is not None}
        for tf in tfs:
            bars = load_dataset(data, symbol, tf, config)
            if bars is None:
                inventory.append({'symbol': symbol, 'timeframe': tf, 'status': 'unavailable'})
                continue
            spec = data['specs'][symbol].copy()
            spec['trade_tick_size'] = spec['tick_size']
            f = build_features(bars, tf, symbol, spec, config, auxiliary)
            f['comparison_eligible'] = complete_mask(f, config['primary_horizon'], config)
            candidates = extract_candidates(f, config['methods'], config)
            market = out/symbol/tf
            save(f, market, 'features', csv=False)
            save(candidates, market, 'candidates', csv=False)
            record = next(x for x in data['datasets'] if x['symbol'] == symbol and x.get('timeframe') == tf)
            inventory.append({'symbol': symbol, 'timeframe': tf, 'status': 'available', 'n_bars': len(bars),
                              'n_candidates': len(candidates), 'months': record['months_with_data'], 'data_complete_months': record['months_with_data'] == 24})
            cfg = dict(config, timeframe_seconds=config['timeframes'][tf], end_exclusive=stamp(config['end']),
                       max_entry_delay_seconds=config['timeframes'][tf], pip_size=spec['pip_size'], point=spec['point'],
                       cost={'mode': 'bar_proxy', 'spread_pips': config['assumed_spread_pips'][symbol],
                             'commission_pips_roundtrip': 0, 'slippage_pips_per_side': config['slippage_pips_per_side']})
            for method in config['methods']:
                for side in ['LONG', 'SHORT']:
                    ids = {'symbol': symbol, 'timeframe': tf, 'method': method, 'side': side}
                    cell = market / (method+'_'+side)
                    events = candidates[candidates.method.eq(method) & candidates.side.eq(side)].copy()
                    outcomes, barrier = evaluate_chunks(bars, events, cfg)
                    joined = enriched_outcomes(outcomes, events)
                    save(joined, cell, 'outcomes', csv=False)
                    save(barrier, cell, 'barriers', csv=False)
                    observed = events[events.comparison_eligible].copy()
                    primary_s = joined[joined.horizon.eq(10) & joined.complete].copy()
                    assert set(primary_s.candidate_id) == set(observed.candidate_id)
                    controls_list = []
                    for kind in ['unconditional', 'conditional']:
                        controls, log = random_controls(f, observed, kind, config)
                        control_outcomes, control_barrier = evaluate_chunks(bars, controls, dict(cfg, horizons=[10]))
                        controls_o = enriched_outcomes(control_outcomes, controls)
                        assert controls_o.complete.all()
                        controls_list.append(controls_o)
                        cols = ['candidate_id', 'origin_candidate_id', 'signal_index', 'entry_index', 'signal_time', 'entry_time', 'atr14', 'year', 'hour', 'weekday', 'vol_bucket', 'replicate', 'baseline_kind']
                        save(controls[cols], cell, kind+'_draws', csv=False)
                        save(controls_o, cell, kind+'_outcomes', csv=False)
                        save(log, cell, kind+'_matching_audit')
                        if len(control_barrier):
                            counts = control_barrier.groupby(['horizon', 'outcome'], dropna=False).size().reset_index(name='n')
                            for rec in counts.to_dict('records'):
                                barriers_summary.append(dict(ids, population=kind, **rec))
                    primary_c = pd.concat(controls_list, ignore_index=True)
                    row = dict(ids, **infer_cell(primary_s, primary_c, weeks, weights, config))
                    row['n_candidates'], row['n_decision_eligible'] = len(events), int(events.decision_eligible.sum())
                    row['data_complete_months'] = record['months_with_data'] == 24
                    row['mean_gross_pips'], row['mean_net_pips'] = primary_s.gross_pips.mean(), primary_s.net_pips.mean()
                    row['mean_cost_pips'] = primary_s.total_cost_pips.mean()
                    next_free, nonoverlap = -1, []
                    for idx, event in primary_s.sort_values('entry_index').iterrows():
                        if event.entry_index >= next_free:
                            nonoverlap.append(idx)
                            next_free = event.entry_index+10
                    row['n_nonoverlap'] = len(nonoverlap)
                    row['nonoverlap_net_atr'] = primary_s.loc[nonoverlap].net_atr.mean()
                    row['n_consecutive_same_direction'] = int(events.consecutive_same_direction.sum())
                    primary.append(row)
                    for horizon, sub in joined.groupby('horizon'):
                        sub = sub[sub.complete]
                        r = dict(ids, horizon=int(horizon), n_candidates=len(events), n_complete=len(sub), n_censored=len(events)-len(sub))
                        for metric in ['gross_pips', 'net_pips', 'gross_atr', 'net_atr', 'mfe_pips', 'mae_pips', 'mfe_atr', 'mae_atr']:
                            r['mean_'+metric], r['median_'+metric] = sub[metric].mean(), sub[metric].median()
                        descriptive.append(r)
                    for freq, dest in [('year', annual), ('month', monthly)]:
                        for value, sub in primary_s.groupby(freq):
                            dest.append(dict(ids, **{freq: value}, n=len(sub), weeks=sub.week.nunique(), mean_gross_pips=sub.gross_pips.mean(), mean_net_pips=sub.net_pips.mean(), mean_net_atr=sub.net_atr.mean()))
                    w = walk_forward(primary_s, config).assign(**ids)
                    wf_rows.extend(w.to_dict('records'))
                    for field in ['h1_trend', 'm15_trend', 'h4_trend', 'vol_bucket', 'cloud_position']:
                        for value, sub in primary_s.groupby(field, observed=True):
                            environment.append(dict(ids, condition=field, value=value, n=len(sub), weeks=sub.week.nunique(), mean_net_atr=sub.net_atr.mean(), descriptive_only=True))
                    if len(barrier):
                        counts = barrier.groupby(['horizon', 'outcome'], dropna=False).size().reset_index(name='n')
                        barriers_summary += [dict(ids, population='strategy', **r) for r in counts.to_dict('records')]
                    simulation = simulate(bars, events, spec, dict(cfg, assumed_spread_pips=config['assumed_spread_pips'][symbol]))
                    for name, table in simulation.items():
                        save(table, cell, 'execution_'+name, csv=name != 'equity')
                    accounts.extend(simulation['summary'].assign(**ids).to_dict('records'))
                    print(symbol, tf, method, side, 'candidates', len(events), flush=True)
    primary_df = adjust_family(pd.DataFrame(primary), config)
    # A missing requested period blocks adoption even if partial-period estimates look favorable.
    primary_df['exploratory_hypothesis_pass'] &= primary_df.data_complete_months
    frames = {'primary': primary_df, 'summary': pd.DataFrame(descriptive), 'annual': pd.DataFrame(annual),
              'monthly': pd.DataFrame(monthly), 'walk_forward': pd.DataFrame(wf_rows), 'environment': pd.DataFrame(environment),
              'accounts': pd.DataFrame(accounts), 'inventory': pd.DataFrame(inventory), 'barrier_counts': pd.DataFrame(barriers_summary)}
    for name, frame in frames.items():
        save(frame, out, name)
    db = duckdb.connect(str(out/'research.duckdb'))
    for name, frame in frames.items():
        db.register('frame', frame)
        db.execute(f'CREATE TABLE "{name}" AS SELECT * FROM frame')
    for name, pattern in [('event_outcomes', '*/*/*/outcomes.parquet'),
                          ('candidates', '*/*/candidates.parquet'),
                          ('unconditional_controls', '*/*/*/unconditional_outcomes.parquet'),
                          ('conditional_controls', '*/*/*/conditional_outcomes.parquet'),
                          ('execution_trades', '*/*/*/execution_trades.parquet')]:
        location = (out.resolve()/pattern).as_posix().replace("'", "''")
        db.execute(f"CREATE VIEW {name} AS SELECT * FROM read_parquet('{location}', union_by_name=true)")
    db.close()
    changed = [p for p, value in protected.items() if sha(p) != value]
    if changed:
        raise RuntimeError(f'Protected files changed: {changed}')
    manifest['status'], manifest['protected_files_unchanged'] = 'completed', len(protected)
    manifest['output_hashes'] = {p.name: sha(p) for p in out.glob('*.parquet')}
    manifest['source_unchanged_during_run'] = manifest['source_hashes'] == source_manifest()
    (out/'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    from .report import render
    render(out)
    return out


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--data', default='reports/research/multiasset_20261016/data')
    parser.add_argument('--out', required=True)
    parser.add_argument('--config', default=str(Path(__file__).with_name('config.json')))
    parser.add_argument('--pilot', action='store_true')
    args = parser.parse_args()
    run(args.data, args.out, json.loads(Path(args.config).read_text(encoding='utf-8')), args.pilot)
