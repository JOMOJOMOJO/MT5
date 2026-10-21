"""Run every fixed capital/mode/cost/order profile without parameter search."""
import argparse
import importlib.metadata
import json
from pathlib import Path
import subprocess

import duckdb
import numpy as np
import pandas as pd

from ..account_replay.calendar import WEEKEND_POLICY
from ..account_replay.execution import SCENARIOS
from ..four_pattern_monthly import CELLS
from ..multiasset.data import sha
from .engine import simulate_shared
from .analysis import summarize

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
PRIOR = ROOT / 'reports/research/hypothesis_cycle_20261019/validated'
DATA = ROOT / 'reports/research/multiasset_20261016/data'
EXECUTION = ROOT / 'reports/research/account_replay_20261017/validated/manifest.json'


def save(frame, path, name):
    path.mkdir(parents=True, exist_ok=True)
    if (path / f'{name}.parquet').exists():
        pd.testing.assert_frame_equal(frame, pd.read_parquet(path / f'{name}.parquet'), check_exact=True)
        return
    frame.to_parquet(path / f'{name}.parquet', index=False)
    frame.to_csv(path / f'{name}.csv', index=False, encoding='utf-8-sig')


def load_inputs():
    metadata = json.loads((DATA / 'manifest.json').read_text())
    execution = json.loads(EXECUTION.read_text())['config']
    config = json.loads((HERE / 'config.json').read_text())
    config['cell_order'] = CELLS
    config['end_exclusive_epoch'] = int(pd.Timestamp(config['end_exclusive']).timestamp())
    execution.update(timeframe_seconds=3600, max_entry_delay_seconds=3600,
                     calendar_policy=WEEKEND_POLICY, end_exclusive=config['end_exclusive_epoch'])
    candidates = []
    paths = [EXECUTION, DATA / 'manifest.json', PRIOR / 'manifest.json',
             ROOT / 'knowledge/experiments/2026-10-19-shared-portfolio-plan.md']
    for cell in CELLS:
        path = PRIOR / 'candidates' / f'{cell}.parquet'
        f = pd.read_parquet(path)
        f['cell_id'] = cell
        candidates.append(f)
        paths.append(path)
    candidates = pd.concat(candidates, ignore_index=True)
    bars, specs = {}, {}
    for symbol in candidates.symbol.unique():
        path = DATA / symbol / 'H1.parquet'
        bars[symbol] = pd.read_parquet(path)
        paths.append(path)
        specs[symbol] = dict(metadata['specs'][symbol], trade_tick_size=metadata['specs'][symbol]['tick_size'])
    paths += list((ROOT / 'tools/entry_research/account_replay').glob('*.py'))
    paths += [ROOT / 'tools/entry_research/hypothesis_cycle/stats.py',
              ROOT / 'tools/entry_research/monthly_review/diagnostics.py',
              ROOT / 'mql/Experts/USDJPY_M1_M5_3WaveIn3Wave_Long.mq5',
              ROOT / 'mql/Experts/usdjpy_20260402_round_continuation_long.mq5']
    prior_manifest = json.loads((PRIOR / 'manifest.json').read_text())
    for path, expected in prior_manifest['protected_hashes'].items():
        if sha(path) != expected:
            raise ValueError(f'Frozen source changed: {path}')
    protected = {str(p.resolve()): sha(p) for p in paths}
    return bars, candidates, specs, execution, config, protected


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--resume', action='store_true', help='Resume an incomplete run; validate cached input and ledgers')
    args = parser.parse_args()
    out = args.out.resolve()
    if out.exists() and (not args.resume or (out/'manifest.json').exists()):
        raise FileExistsError('Output exists; use a new immutable directory')
    bars, candidates, specs, execution, config, protected = load_inputs()
    out.mkdir(parents=True, exist_ok=args.resume)
    if (out/'config.json').exists():
        assert json.loads((out/'config.json').read_text()) == config
    else:
        (out / 'config.json').write_text(json.dumps(config, indent=2), encoding='utf-8')
    save(candidates, out, 'original_candidates')
    summary_rows, monthly_frames, yearly_frames, event_frames, trade_frames = [], [], [], [], []
    equity_by_profile = {}
    period_starts = {'common': config['common_start'], 'mixed_reference': config['reference_start']}
    for period, start_string in period_starts.items():
        start, end = int(pd.Timestamp(start_string).timestamp()), config['end_exclusive_epoch']
        for mode in ['hedging', 'block_opposite']:
            for cost, slip in [('base', .2), ('stress', .7)]:
                ex = dict(execution, slippage_pips_per_side=slip)
                for scenario in SCENARIOS:
                    profile = f'{period}_{mode}_{cost}_{scenario}'
                    directory = out / 'profiles' / profile
                    cached = args.resume and all((directory/f'{name}.parquet').exists() for name in ['trades','events','equity'])
                    if cached:
                        result = {name: pd.read_parquet(directory/f'{name}.parquet') for name in ['trades','events','equity']}
                        complete = (result['trades'].status.eq('closed').all() and result['equity'].iloc[-1].n_open == 0
                                    and result['equity'].iloc[-1].time == end)
                        result.update(complete=bool(complete), censor_reason='' if complete else 'restored_incomplete_path', censor_time=None)
                    else:
                        result = simulate_shared(bars, candidates, specs, ex, config, start=start,
                                                 end=end, mode=mode, scenario=scenario)
                    summary, monthly, yearly = summarize(result['trades'], result['equity'], result['events'],
                        start, end, config['initial_equity'], result['complete'])
                    meta = dict(profile=profile, period=period, mode=mode, cost=cost, scenario=scenario)
                    summary.update(meta, censor_reason=result['censor_reason'], censor_time=result['censor_time'],
                        assumed_leverage=config['assumed_leverage'], historical_margin_verified=False,
                        all_costs_verified=False, holdout_2026_used=False, independent_oos=False)
                    for currency in ['USD', 'JPY', 'CHF', 'AUD']:
                        summary[f'peak_abs_exposure_{currency}_usd'] = result['equity'][f'exposure_{currency}_usd'].abs().max()
                    summary_rows.append(summary)
                    for name in ['trades', 'events', 'equity']:
                        save(result[name], directory, name)
                    for name, f, target in [('monthly', monthly, monthly_frames), ('yearly', yearly, yearly_frames),
                                           ('events', result['events'], event_frames), ('trades', result['trades'], trade_frames)]:
                        f = f.copy()
                        for key, value in meta.items():
                            f[key] = value
                        target.append(f)
                    equity_by_profile[profile] = result['equity']
                    print(f'{len(summary_rows)}/16 {profile}: n={summary["n_closed"]} PF={summary["profit_factor"]:.4f} complete={result["complete"]}', flush=True)
    from .reference import independent_reference
    references, reference_months = [], []
    for period, start_string in period_starts.items():
        for cost, slip in [('base', .2), ('stress', .7)]:
            r = independent_reference(bars, candidates, specs, dict(execution, slippage_pips_per_side=slip),
                config, int(pd.Timestamp(start_string).timestamp()), config['end_exclusive_epoch'])
            for cell, result in r['accounts'].items():
                for name, frame in result.items():
                    save(frame, out / 'independent_reference' / period / cost / cell, name)
            for frame, target in [(r['summary'], references), (r['monthly'], reference_months)]:
                f = frame.copy()
                f['period'], f['cost'] = period, cost
                target.append(f)
            print(f'Reference {period}/{cost} complete', flush=True)
    tables = dict(summary=pd.DataFrame(summary_rows), monthly=pd.concat(monthly_frames, ignore_index=True),
                  yearly=pd.concat(yearly_frames, ignore_index=True), events=pd.concat(event_frames, ignore_index=True),
                  trades=pd.concat(trade_frames, ignore_index=True), independent_summary=pd.concat(references, ignore_index=True),
                  independent_monthly=pd.concat(reference_months, ignore_index=True))
    database = duckdb.connect(str(out / 'research.duckdb'))
    for name, frame in tables.items():
        save(frame, out, name)
        database.register('frame_data', frame)
        database.execute(f'CREATE TABLE {name} AS SELECT * FROM frame_data')
        database.unregister('frame_data')
    database.close()
    from .report import render
    render(out, tables, equity_by_profile, config)
    if any(sha(path) != expected for path, expected in protected.items()):
        raise ValueError('Protected artifacts changed during replay')
    manifest = dict(status='complete', config=config, execution=execution, protected_hashes=protected,
        protected_unchanged=True, holdout_2026_used=False, independent_oos=False, weights_optimized=False,
        selection_after_prior_results=True, number_profiles=len(summary_rows),
        git_head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        dependencies={p: importlib.metadata.version(p) for p in ['numpy', 'pandas', 'pyarrow', 'duckdb', 'plotly']},
        source_hashes={str(p.relative_to(ROOT)): sha(p) for p in HERE.rglob('*') if p.is_file()
                       and p.suffix in ['.py', '.md', '.json'] and '__pycache__' not in str(p)},
        output_hashes={str(p.relative_to(out)): sha(p) for p in out.rglob('*') if p.is_file()})
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding='utf-8')
    print(tables['summary'][['profile', 'n_closed', 'profit_factor', 'net_pnl_before_unknown_swap_usd',
        'monthly_positive', 'available_months', 'max_drawdown_close_pct']].to_string(index=False), flush=True)


if __name__ == '__main__':
    main()
