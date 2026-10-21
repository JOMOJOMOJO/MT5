"""Audit all positive-PF conditions without changing any original account."""
import argparse
import hashlib
import importlib.metadata
import json
import subprocess
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd

from .diagnostics import (LOCK, stats, monthly, monthly_summary, attach_context,
                           loss_classes, context_diagnostics)
from .report import render

SOURCE = Path('reports/research/account_replay_20261017/validated')
OLD = Path('reports/research/multiasset_20261016/full_validated')
DATA = Path('reports/research/multiasset_20261016/data')
PLAN = Path('knowledge/experiments/2026-10-18-monthly-loss-diagnosis-plan.md')
KEYS = ['symbol', 'timeframe', 'method', 'side']


def sha(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024*1024), b''):
            result.update(chunk)
    return result.hexdigest()


def run(out):
    out = Path(out)
    if out.exists():
        raise FileExistsError('Existing output is preserved; use a new path')
    accounts = pd.read_parquet(SOURCE/'accounts.parquet')
    positives = accounts.loc[accounts.profit_factor.gt(1)].copy()
    cells = positives[KEYS].drop_duplicates().sort_values(KEYS)
    files = [SOURCE/'accounts.parquet', SOURCE/'manifest.json', DATA/'manifest.json', PLAN]
    for symbol in cells.symbol.unique():
        files += [OLD/f'{symbol}/H1/candidates.parquet', DATA/f'{symbol}/H1.parquet']
    for cell in cells.itertuples(index=False):
        folder = SOURCE/f'{cell.symbol}/{cell.timeframe}/{cell.method}_{cell.side}'
        files += [folder/f'execution_{name}.parquet' for name in ['trades', 'equity', 'events']]
    protected = {str(p.resolve()): sha(p) for p in files}
    old_manifest = json.loads((SOURCE/'manifest.json').read_text(encoding='utf-8'))
    for path, expected in old_manifest['source_hashes'].items():
        if sha(path) != expected:
            raise ValueError('Frozen original source changed')
    frames = {name: [] for name in ['condition_summary', 'monthly', 'loss_classes', 'context_slices',
                                   'fixed_ledger_monthly_removals', 'candidate_accounting']}
    unique_trades, equity_checks = [], []
    for cell in cells.itertuples(index=False):
        meta = {key: getattr(cell, key) for key in KEYS}
        folder = SOURCE/f'{cell.symbol}/{cell.timeframe}/{cell.method}_{cell.side}'
        trades, equity, events = [pd.read_parquet(folder/f'execution_{name}.parquet') for name in ['trades', 'equity', 'events']]
        candidates = pd.read_parquet(OLD/f'{cell.symbol}/{cell.timeframe}/candidates.parquet')
        bars = pd.read_parquet(DATA/f'{cell.symbol}/{cell.timeframe}.parquet', columns=['time'])
        if (bars.time >= LOCK).any() or (candidates.signal_time >= LOCK).any():
            raise ValueError('2026 prices or signals forbidden')
        dates = pd.to_datetime(bars.loc[bars.time.ge(1704067200), 'time'], unit='s', utc=True)
        available = sorted(dates.dt.strftime('%Y-%m').unique())
        scenarios = {}
        for scenario in ['stop_first_lower', 'target_first_upper']:
            detail = dict(meta, scenario=scenario)
            group = trades.loc[trades.scenario.eq(scenario)].copy().reset_index(drop=True)
            if not group.status.eq('closed').all():
                raise ValueError('Only uncensored selected accounts can be compared')
            source = accounts.loc[(accounts[KEYS] == pd.Series(meta)).all(axis=1) & accounts.scenario.eq(scenario)].iloc[0]
            if not source.account_path_complete:
                raise ValueError('Source account censored')
            values = stats(group)
            assert len(group) == source.n_closed
            assert np.isclose(values['pnl_usd'], source.net_pnl_before_unknown_swap_usd, rtol=0, atol=1e-8)
            assert np.isclose(values['pf'], source.profit_factor, rtol=0, atol=1e-10)
            months = monthly(group, equity.loc[equity.scenario.eq(scenario)], available)
            assert np.isclose(months.pnl_usd.sum(), values['pnl_usd'], rtol=0, atol=1e-8)
            assert np.isclose(months.equity_change_usd.sum(), values['pnl_usd'], rtol=0, atol=1e-8)
            frames['condition_summary'].append(dict(detail, **values, **monthly_summary(months),
                n_original_candidates=int(source.n_candidates), n_ambiguous=int(source.n_ambiguous),
                pnl_basis='existing_spread_slip_commission_assumptions_before_unknown_swap',
                actual_filtered_account_replayed=False))
            frames['monthly'] += [dict(detail, **row) for row in months.to_dict('records')]
            frames['loss_classes'] += [dict(detail, **row) for row in loss_classes(group)]
            context = attach_context(group, candidates)
            diagnostic, removal_months = context_diagnostics(context, available)
            frames['context_slices'] += [dict(detail, **row) for row in diagnostic]
            frames['fixed_ledger_monthly_removals'] += [dict(detail, **row) for row in removal_months]
            statuses = events.loc[events.scenario.eq(scenario), 'status'].value_counts()
            assert statuses.sum() == source.n_candidates
            frames['candidate_accounting'] += [dict(detail, status=status, n=int(n)) for status, n in statuses.items()]
            scenarios[scenario] = set(group.candidate_id)
            if scenario == 'stop_first_lower':
                unique_trades.append(group.assign(timeframe=cell.timeframe))
            equity_checks.append(dict(detail, summary_reconciled=True, realized_and_equity_totals_reconciled=True))
        assert scenarios['stop_first_lower'] == scenarios['target_first_upper']
        print(f'Checked {cell.symbol} {cell.method} {cell.side}', flush=True)
    frames = {name: pd.DataFrame(rows) for name, rows in frames.items()}
    union = pd.concat(unique_trades, ignore_index=True)
    assert not union.candidate_id.duplicated().any()
    duplicates = union.groupby(['symbol', 'side', 'entry_time']).agg(
        n_logic_entries=('candidate_id', 'size'), methods=('method', lambda x: '|'.join(sorted(x)))).reset_index()
    frames['duplicate_entry_times'] = duplicates.loc[duplicates.n_logic_entries.gt(1)]
    frames['family_counts'] = pd.DataFrame([dict(method=method, **stats(group)) for method, group in union.groupby('method')])
    frames['positive_source_scenarios'] = positives
    candidate_count = int(frames['condition_summary'].loc[frames['condition_summary'].scenario.eq('stop_first_lower'), 'n_original_candidates'].sum())
    counts = dict(positive_pf_scenarios=len(positives), positive_scenario_trade_sum=int(positives.n_closed.sum()),
        distinct_conditions=len(cells), distinct_logic_trades=len(union), distinct_symbol_side_entry_times=len(duplicates),
        cross_logic_duplicate_groups=len(frames['duplicate_entry_times']),
        distinct_original_candidates=candidate_count, losers_conservative=int((union.net_pnl_before_unknown_swap_usd < -1e-10).sum()),
        portfolio_simulated=False, independent_trade_count_known=False)
    if any(sha(path) != expected for path, expected in protected.items()):
        raise ValueError('Input changed during analysis')
    out.mkdir(parents=True)
    for name, frame in frames.items():
        frame.to_csv(out/f'{name}.csv', index=False, encoding='utf-8-sig')
        frame.to_parquet(out/f'{name}.parquet', index=False)
    with duckdb.connect(str(out/'monthly_review.duckdb')) as db:
        for name, frame in frames.items():
            db.register('frame', frame)
            db.execute(f'CREATE TABLE "{name}" AS SELECT * FROM frame')
            db.unregister('frame')
    manifest = dict(status='complete', source=str(SOURCE.resolve()), data_period='2024-2025',
        source_clock_verified=False, holdout_2026_used=False, results_selected_posthoc=True,
        parameter_search_performed=False, new_filters_applied=False, live_promotion=False,
        assumptions='same original account: swap unknown, commission0 assumed, bar spread proxy',
        primary_scenario='stop_first_lower', diagnostic_axes=['h1_alignment','h4_alignment','vol_bucket','cloud_position'],
        counts=counts, inputs_sha256=protected, inputs_unchanged=True,
        source_hashes={str(p.resolve()): sha(p) for p in Path(__file__).parent.rglob('*.py')},
        git_head=subprocess.check_output(['git','rev-parse','HEAD'], text=True).strip(),
        libraries={name: importlib.metadata.version(name) for name in ['numpy','pandas','pyarrow','duckdb','plotly']})
    (out/'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    (out/'qa.json').write_text(json.dumps(dict(status='PASS', counts=counts, checks=equity_checks,
        consumed_inputs_unchanged=len(protected), prior_engine_source_hashes_match=True), indent=2), encoding='utf-8')
    render(out, frames, manifest)
    (out/'output_hashes.json').write_text(json.dumps({p.name: sha(p) for p in out.iterdir() if p.is_file()}, indent=2), encoding='utf-8')
    print(json.dumps(counts, indent=2), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True)
    run(parser.parse_args().out)
