"""Reproducible, immutable-output audit of selected saved account results."""
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import platform
import subprocess
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd

from . import metrics
from .intrabar import refine
from .report import render

SOURCE = Path('reports/research/account_replay_20261017/validated')
DATA = Path('reports/research/multiasset_20261016/data')
PREVIOUS = Path('reports/research/multiasset_20261016/full_validated/primary.parquet')
PLAN = Path('knowledge/experiments/2026-10-17-positive-pf-followup-plan.md')
SCENARIOS = ['stop_first_lower', 'target_first_upper']


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024*1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def run(out):
    out = Path(out)
    if out.exists():
        raise FileExistsError('Use a new output directory; prior evidence is immutable')
    inputs = [SOURCE/'accounts.parquet', SOURCE/'manifest.json', DATA/'manifest.json',
              DATA/'USDJPY/H1.parquet', DATA/'USDJPY/M1.parquet', PREVIOUS, PLAN]
    for side in ['LONG', 'SHORT']:
        folder = SOURCE/f'USDJPY/H1/atr_breakout_{side}'
        inputs += [folder/'execution_trades.parquet', folder/'execution_events.parquet']
    source_manifest = json.loads((SOURCE/'manifest.json').read_text(encoding='utf-8'))
    # Verify the code that produced the source results, without changing it.
    for path, expected in source_manifest['source_hashes'].items():
        if sha(path) != expected:
            raise ValueError(f'Frozen replay code changed: {path}')
    before = {str(p.resolve()): sha(p) for p in inputs}
    data_manifest = json.loads((DATA/'manifest.json').read_text(encoding='utf-8'))
    for dataset in data_manifest['datasets']:
        if dataset['symbol'] == 'USDJPY' and dataset['timeframe'] in ['M1', 'H1']:
            if sha(dataset['path']) != dataset['sha256']:
                raise ValueError('Price data hash mismatch')
    accounts = pd.read_parquet(SOURCE/'accounts.parquet')
    positive = accounts.loc[accounts.profit_factor.gt(1)].copy()
    keys = ['symbol', 'timeframe', 'method', 'side']
    pairs = accounts.merge(positive[keys].drop_duplicates(), on=keys, validate='many_to_one')
    chosen = accounts.loc[accounts.symbol.eq('USDJPY') & accounts.timeframe.eq('H1')
                          & accounts.method.eq('atr_breakout')].copy()
    if len(chosen) != 4 or not chosen.account_path_complete.all() or not chosen.requested_period_available.all():
        raise ValueError('Selected accounts must cover the requested period and be uncensored')
    minutes, hours = [pd.read_parquet(DATA/f'USDJPY/{tf}.parquet') for tf in ['M1', 'H1']]
    if any((frame.time >= metrics.LOCK).any() for frame in [minutes, hours]):
        raise ValueError('2026 data forbidden')
    spec = data_manifest['specs']['USDJPY']
    tables = {key: [] for key in ['summary', 'annual', 'monthly', 'bootstrap', 'cost_sensitivity',
                                  'break_even', 'concentration', 'intrabar', 'event_accounting', 'realized_equity']}
    weights = {block: metrics.block_weights(105, block) for block in [1, 4, 8]}
    checked = []
    for side in ['LONG', 'SHORT']:
        folder = SOURCE/f'USDJPY/H1/atr_breakout_{side}'
        trades, events = [pd.read_parquet(folder/f'execution_{kind}.parquet') for kind in ['trades', 'events']]
        for scenario in SCENARIOS:
            group = trades.loc[trades.scenario.eq(scenario)].copy().reset_index(drop=True)
            metrics.validate_trades(group)
            meta = dict(symbol='USDJPY', timeframe='H1', method='atr_breakout', side=side, scenario=scenario)
            original = chosen.loc[chosen.side.eq(side) & chosen.scenario.eq(scenario)].iloc[0]
            stats = metrics.summarize(group)
            assert stats['n_closed'] == original.n_closed
            assert np.isclose(stats['pf'], original.profit_factor, rtol=0, atol=1e-10)
            assert np.isclose(stats['pnl_usd'], original.net_pnl_before_unknown_swap_usd, rtol=0, atol=1e-8)
            assert np.isclose(stats['mean_r'], original.mean_result_r, rtol=0, atol=1e-10)
            e = events.loc[events.scenario.eq(scenario)]
            assert len(e) == original.n_candidates and e.candidate_id.nunique() == len(e)
            assert e.status.eq('executed').sum() == len(group)
            tables['event_accounting'] += [dict(meta, status=status, n=n) for status, n in e.status.value_counts().items()]
            annual, monthly = metrics.period_tables(group)
            costs, breakeven = metrics.cost_sensitivity(group, spec['contract_size'], spec['pip_size'])
            tables['summary'].append(dict(meta, **stats, n_candidates=len(e),
                n_ambiguous=int(group.ambiguous.sum()), max_drawdown_close_pct=original.max_drawdown_close_pct,
                account_path_complete=True, all_in_net_pnl_usd=np.nan, swap_cost_known=False,
                n_2024=annual[0]['n_closed'], n_2025=annual[1]['n_closed'],
                both_years_positive=all(row['pnl_usd'] > 0 for row in annual)))
            for name, rows in [('annual', annual), ('monthly', monthly), ('cost_sensitivity', costs),
                               ('break_even', [breakeven]), ('concentration', metrics.concentration(group))]:
                tables[name] += [dict(meta, **row) for row in rows]
            tables['bootstrap'] += [dict(meta, **metrics.bootstrap(group, block, weights[block])) for block in [1, 4, 8]]
            ordered = group.sort_values(['exit_time', 'candidate_id'])
            for time, cash in zip(ordered.exit_time, ordered.net_pnl_before_unknown_swap_usd.cumsum()):
                tables['realized_equity'].append(dict(meta, exit_time=int(time), cumulative_pnl_usd=cash))
            if scenario == SCENARIOS[0]:
                for trade in group.loc[group.ambiguous].itertuples():
                    tables['intrabar'] += refine(trade, minutes, hours, spec['point'], spec['pip_size'], 1.5)
            checked.append(dict(meta, source_summary_reconciled=True, all_candidates_accounted=True))
            print(f'Checked {side} {scenario}: n={len(group)}, PF={stats["pf"]:.6f}', flush=True)
    tables = {name: pd.DataFrame(rows) for name, rows in tables.items()}
    tables['positive_inventory'], tables['scenario_pairs'] = positive, pairs
    previous = pd.read_parquet(PREVIOUS)
    tables['previous_event_statistics'] = previous.loc[previous.symbol.eq('USDJPY')
        & previous.timeframe.eq('H1') & previous.method.eq('atr_breakout')].copy()
    after = {path: sha(path) for path in before}
    if before != after:
        raise ValueError('Source changed during audit')
    out.mkdir(parents=True)
    for name, frame in tables.items():
        frame.to_csv(out/f'{name}.csv', index=False, encoding='utf-8-sig')
        frame.to_parquet(out/f'{name}.parquet', index=False)
    with duckdb.connect(str(out/'review.duckdb')) as db:
        for name, frame in tables.items():
            db.register('frame', frame)
            db.execute(f'CREATE TABLE "{name}" AS SELECT * FROM frame')
            db.unregister('frame')
    manifest = dict(status='complete', source=str(SOURCE.resolve()), period=['2024-01-01', '2026-01-01'],
        inputs_sha256=before, inputs_unchanged=True, source_code_hashes_verified=True,
        source_hashes={str(p.resolve()): sha(p) for p in Path(__file__).parent.rglob('*.py')},
        git_head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
        git_worktree_clean_required=False, code_identity='SHA256 of all new Python source files',
        python=platform.python_version(), libraries={p: importlib.metadata.version(p) for p in ['numpy', 'pandas', 'pyarrow', 'duckdb', 'plotly']},
        seed=metrics.SEED, bootstrap_reps=metrics.REPS, primary_block_weeks=4, block_sensitivity=[1, 8],
        all_account_scenarios=len(accounts), positive_pf_scenarios=len(positive),
        selected_after_observing_results=True, confirmatory=False, holdout_2026_used=False,
        new_signals_or_account_simulation=False, known_swap=False, live_promotion=False,
        source_clock='unverified_source_calendar_not_verified_geographic_timezone',
        cashflow_stress='fixed_saved_fills_and_lots_no_trigger_or_size_recalculation')
    (out/'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding='utf-8')
    (out/'qa.json').write_text(json.dumps(dict(status='PASS', checks=checked,
        protected_inputs=len(before), protected_hashes_unchanged=True,
        prices_match_original_manifest=True, holdout_2026_used=False), indent=2), encoding='utf-8')
    render(out, tables, manifest)
    outputs = {str(p.relative_to(out)): sha(p) for p in out.iterdir() if p.is_file()}
    (out/'output_hashes.json').write_text(json.dumps(outputs, indent=2), encoding='utf-8')
    print(f'Complete: {out.resolve()}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True)
    run(parser.parse_args().out)
