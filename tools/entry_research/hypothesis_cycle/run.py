"""Bounded, preregistered 19-cell exploration; never opens the 2026 holdout."""
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path
import subprocess

import duckdb
import numpy as np
import pandas as pd

from ..account_replay.execution import simulate, SCENARIOS
from ..account_replay.calendar import WEEKEND_POLICY
from ..multiasset.data import LOCK, sha, stamp
from ..multiasset.strategies import build_features
from ..monthly_review.diagnostics import monthly, monthly_summary
from .entries import shallow_filter, rsi_candidates
from .stats import (calendar_admission, common_week_calendar, mean_r_ci,
                    paired_r_difference_ci, monthly_gates, holm_adjust)

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'reports/research/account_replay_20261017/validated'
OLD = ROOT / 'reports/research/multiasset_20261016/full_validated'
DATA = ROOT / 'reports/research/multiasset_20261016/data'
HERE = Path(__file__).resolve().parent
A_CELLS = [('USDJPY', 'donchian', 'LONG'), ('USDJPY', 'donchian', 'SHORT'),
           ('USDJPY', 'atr_breakout', 'LONG'), ('USDJPY', 'atr_breakout', 'SHORT'),
           ('USDCHF', 'donchian', 'SHORT'), ('USDCHF', 'atr_breakout', 'SHORT'),
           ('AUDUSD', 'ichimoku_cloud', 'SHORT')]
LOWER = 'stop_first_lower'


def save_table(frame, directory, name):
    directory.mkdir(parents=True, exist_ok=True)
    frame.to_parquet(directory / f'{name}.parquet', index=False)
    frame.to_csv(directory / f'{name}.csv', index=False, encoding='utf-8-sig')


def identity(symbol, method, side, variant):
    return f'{symbol}_{method}_{side}_{variant}'


def protected_inputs(data_manifest, source_manifest):
    paths = [DATA / 'manifest.json', SOURCE / 'manifest.json', OLD / 'manifest.json',
             ROOT / 'knowledge/experiments/2026-10-19-hypothesis-cycle-plan.md']
    for symbol in data_manifest['specs']:
        paths += [DATA / symbol / f'{tf}.parquet' for tf in ['H1', 'H4']]
        paths += [OLD / symbol / 'H1/candidates.parquet']
    # Include frozen execution and feature/statistics implementations, as well
    # as unrelated dirty EA files. Their existing contents must not be changed.
    paths += list((ROOT / 'tools/entry_research/account_replay').glob('*.py'))
    paths += list((ROOT / 'tools/entry_research/multiasset').glob('*.py'))
    paths += [ROOT / 'tools/entry_research/features.py',
              ROOT / 'tools/entry_research/monthly_review/diagnostics.py',
              ROOT / 'mql/Experts/USDJPY_M1_M5_3WaveIn3Wave_Long.mq5',
              ROOT / 'mql/Experts/usdjpy_20260402_round_continuation_long.mq5']
    for path, expected in source_manifest.get('source_hashes', {}).items():
        p = Path(path)
        if not p.exists() or sha(p) != expected:
            raise ValueError(f'Frozen source changed: {p}')
        paths.append(p)
    return {str(p.resolve()): sha(p) for p in sorted(set(paths))}


def prepare(data_manifest, original_config):
    bars, features, originals, available, calendars = {}, {}, {}, {}, {}
    for symbol, spec in data_manifest['specs'].items():
        b = pd.read_parquet(DATA / symbol / 'H1.parquet')
        h4 = pd.read_parquet(DATA / symbol / 'H4.parquet')
        if (b.time >= LOCK).any() or (h4.time >= LOCK).any():
            raise ValueError('Holdout found in source prices')
        f = build_features(b, 'H1', symbol, spec, original_config, {'H4': h4})
        # Last 2025 bar closing in 2026 is not a development decision.
        features[symbol] = f.loc[f.signal_time.lt(LOCK)].copy()
        bars[symbol] = b
        originals[symbol] = pd.read_parquet(OLD / symbol / 'H1/candidates.parquet')
        if (originals[symbol].signal_time >= LOCK).any():
            raise ValueError('Holdout candidate')
        dev = b.loc[b.time.ge(stamp('2024-01-01'))]
        available[symbol] = sorted(pd.to_datetime(dev.time, unit='s', utc=True).dt.strftime('%Y-%m').unique())
        calendars[symbol] = common_week_calendar(int(dev.time.min()), min(LOCK, int(dev.time.max()) + 3600))
    cells = []
    for symbol, method, side in A_CELLS:
        original = originals[symbol]
        c = original.loc[original.method.eq(method) & original.side.eq(side)].copy()
        for variant in ['original', 'margin025']:
            cells.append(dict(cell_id=identity(symbol, method, side, variant), symbol=symbol,
                method=method, side=side, variant=variant, family='A',
                candidates=c.copy(), filter_pass=(shallow_filter(c) if variant == 'margin025'
                                                   else pd.Series(True, index=c.index))))
    for symbol in original_config['symbols']:
        new = rsi_candidates(features[symbol])
        for side in ['LONG', 'SHORT']:
            c = new.loc[new.side.eq(side)].copy()
            cells.append(dict(cell_id=identity(symbol, 'rsi2_pullback', side, 'rsi2'),
                symbol=symbol, method='rsi2_pullback', side=side, variant='rsi2', family='B',
                candidates=c, filter_pass=pd.Series(True, index=c.index)))
    return bars, features, cells, available, calendars


def simulate_cell(cell, b, spec, config, cycle, cost, pause):
    candidates = cell['candidates']
    allow = calendar_admission(candidates) if pause else pd.Series(True, index=candidates.index)
    passed = cell['filter_pass'] & allow
    cfg = dict(config, timeframe_seconds=3600, max_entry_delay_seconds=3600,
               end_exclusive=LOCK, calendar_policy=WEEKEND_POLICY,
               slippage_pips_per_side=cycle[f'{cost}_slippage_pips_per_side'],
               method=cell['method'], side=cell['side'])
    result = simulate(b, candidates.loc[passed], dict(spec, trade_tick_size=spec['tick_size']), cfg)
    disposition = candidates[['candidate_id', 'signal_time', 'entry_time']].copy()
    disposition['filter_pass'] = cell['filter_pass']
    disposition['calendar_pass'] = allow
    disposition['admitted'] = passed
    ledgers = []
    for scenario in SCENARIOS:
        events = result['events'].loc[result['events'].scenario.eq(scenario)]
        d = disposition.merge(events[['candidate_id', 'status']], on='candidate_id', how='left', validate='one_to_one')
        d['status'] = np.where(~d.filter_pass, 'excluded_shallow_breakout',
                               np.where(~d.calendar_pass, 'excluded_calendar_pause', d.status))
        if d.status.isna().any():
            raise ValueError('Original candidate lost from disposition')
        d['scenario'] = scenario
        ledgers.append(d)
    result['dispositions'] = pd.concat(ledgers, ignore_index=True)
    return result


def safe_trades(frame):
    result = frame.copy()
    for column in ['net_pnl_before_unknown_swap_usd', 'exit_time', 'entry_time', 'result_r']:
        if column not in result:
            result[column] = pd.Series(dtype=float)
    if 'exit_reason' not in result:
        result['exit_reason'] = pd.Series(dtype=str)
    return result


def with_meta(frame, meta):
    out = frame.copy()
    for key, value in meta.items():
        out[key] = value
    return out


def collect_months(result, available, meta, initial):
    months = []
    for s in result['summary'].to_dict('records'):
        # A stopped account does not produce a completed monthly return series.
        if not s['account_path_complete']:
            continue
        scenario = s['scenario']
        t = safe_trades(result['trades'].loc[result['trades'].scenario.eq(scenario)])
        e = result['equity'].loc[result['equity'].scenario.eq(scenario)]
        m = monthly(t, e, available, initial)
        expected = s['net_pnl_before_unknown_swap_usd']
        if not np.isclose(m.equity_change_usd.sum(), expected, atol=1e-7):
            raise ValueError('Monthly equity changes do not reconcile')
        months.append(with_meta(m, dict(meta, scenario=scenario)))
    return pd.concat(months, ignore_index=True) if months else pd.DataFrame()


def summarize_gate(cell, results, months, calendars, cycle):
    cid, symbol = cell['cell_id'], cell['symbol']
    result = results[(cid, 'base', True)]
    base = result['summary'].set_index('scenario').loc[LOWER]
    stress = results[(cid, 'stress', True)]['summary'].set_index('scenario').loc[LOWER]
    row = {k: cell[k] for k in ['cell_id', 'symbol', 'method', 'side', 'variant', 'family']}
    row.update(n_original_candidates=len(cell['candidates']),
               n_admitted_candidates=int(base.n_candidates), n_trades=int(base.n_closed),
               complete=bool(base.account_path_complete), pf=base.profit_factor,
               net_usd=base.net_pnl_before_unknown_swap_usd,
               mean_r=base.mean_result_r, max_dd_pct=base.max_drawdown_adverse_envelope_pct,
               stress_complete=bool(stress.account_path_complete), stress_pf=stress.profit_factor,
               stress_net_usd=stress.net_pnl_before_unknown_swap_usd,
               independent_oos=False, live_ready=False)
    for name in ['equity_positive_months', 'data_months', 'equity_longest_negative_months',
                 'median_monthly_entries', 'net_2024_usd', 'net_2025_usd',
                 'paired_r_per_original', 'paired_ci_low', 'paired_ci_high']:
        row[name] = np.nan
    m = months.loc[months.cell_id.eq(cid) & months.cost.eq('base') & months.pause & months.scenario.eq(LOWER)]
    complete = bool(base.account_path_complete)
    if complete:
        row.update(monthly_summary(m))
        gates = monthly_gates(m, cycle)
        row.update(gates)
        for year in ['2024', '2025']:
            row[f'net_{year}_usd'] = m.loc[m.month.str.startswith(year), 'equity_change_usd'].sum(min_count=1)
        row['median_monthly_entries'] = m.loc[m.data_available, 'n_entries'].median()
        row['active_month_fraction'] = m.loc[m.data_available, 'n_entries'].gt(0).mean()
        row['gate_monthly'] = gates['monthly_gate']
        t = result['trades'].loc[result['trades'].scenario.eq(LOWER)]
        boot = dict(reps=cycle['bootstrap_reps'], block_weeks=cycle['block_weeks'], seed=cycle['seed'])
        ci = mean_r_ci(t, calendars[symbol], **boot)
        row.update(mean_r_ci_low=ci['ci_low'], mean_r_ci_high=ci['ci_high'], p_one_sided=ci['p_one_sided'])
        if cell['family'] == 'A':
            original_id = identity(symbol, cell['method'], cell['side'], 'original')
            original = results[(original_id, 'base', True)]
            if original['summary'].set_index('scenario').loc[LOWER, 'account_path_complete']:
                original_t = original['trades'].loc[original['trades'].scenario.eq(LOWER)]
                paired = paired_r_difference_ci(original_t, t, cell['candidates'], calendars[symbol], **boot)
                row.update(paired_r_per_original=paired['estimate'], paired_ci_low=paired['ci_low'], paired_ci_high=paired['ci_high'])
    else:
        row.update(gate_monthly=False, p_one_sided=np.nan, mean_r_ci_low=np.nan, mean_r_ci_high=np.nan)
    row['gate_profit'] = bool(complete and row['net_usd'] > 0 and row['pf'] > 1
                              and row.get('net_2024_usd', np.nan) > 0 and row.get('net_2025_usd', np.nan) > 0)
    row['gate_stress'] = bool(row['stress_complete'] and row['stress_net_usd'] > 0)
    row['survives_gates_1_to_3'] = bool(row['gate_profit'] and row['gate_monthly'] and row['gate_stress'])
    return row


def compare_a(cells, results):
    rows = []
    for cell in cells:
        if cell['variant'] != 'margin025':
            continue
        original = identity(cell['symbol'], cell['method'], cell['side'], 'original')
        for cost in ['base', 'stress']:
            for scenario in SCENARIOS:
                t0 = safe_trades(results[(original, cost, True)]['trades'])
                t1 = safe_trades(results[(cell['cell_id'], cost, True)]['trades'])
                t0 = t0.loc[t0.scenario.eq(scenario) & t0.status.eq('closed')].set_index('candidate_id')
                t1 = t1.loc[t1.scenario.eq(scenario) & t1.status.eq('closed')].set_index('candidate_id')
                removed = t0.loc[~t0.index.isin(t1.index)]
                added = t1.loc[~t1.index.isin(t0.index)]
                rows.append(dict(cell_id=cell['cell_id'], cost=cost, scenario=scenario,
                    original_complete=bool(results[(original, cost, True)]['summary'].set_index('scenario').loc[scenario, 'account_path_complete']),
                    variant_complete=bool(results[(cell['cell_id'], cost, True)]['summary'].set_index('scenario').loc[scenario, 'account_path_complete']),
                    n_original_candidates=len(cell['candidates']), original_trades=len(t0), variant_trades=len(t1),
                    retained_original_trades=len(t0.index.intersection(t1.index)),
                    removed_winners=int(removed.net_pnl_before_unknown_swap_usd.gt(0).sum()),
                    removed_losers=int(removed.net_pnl_before_unknown_swap_usd.lt(0).sum()), new_trades=len(added),
                    removed_winning_cash_usd=removed.net_pnl_before_unknown_swap_usd.clip(lower=0).sum(),
                    avoided_losing_cash_usd=-removed.net_pnl_before_unknown_swap_usd.clip(upper=0).sum(),
                    original_cash_usd=t0.net_pnl_before_unknown_swap_usd.sum(),
                    variant_cash_usd=t1.net_pnl_before_unknown_swap_usd.sum(),
                    cash_difference_usd=t1.net_pnl_before_unknown_swap_usd.sum()-t0.net_pnl_before_unknown_swap_usd.sum(),
                    r_difference_per_original=(t1.result_r.sum()-t0.result_r.sum()) / len(cell['candidates'])))
    return pd.DataFrame(rows)


def random_candidates(cell, features, cycle, kind, repeat):
    """Match ex-ante strata only; never inspect future path completeness."""
    original = cell['candidates']
    selected = original.loc[cell['filter_pass'] & calendar_admission(original)].copy()
    pool = features.loc[features.signal_eligible & features.decision_eligible & calendar_admission(features)].copy()
    columns = ['month'] + (['hour', 'weekday', 'vol_bucket'] if kind == 'conditional' else [])
    digest = hashlib.sha256(f'{cell["cell_id"]}/{kind}/{repeat}'.encode()).hexdigest()
    rng = np.random.default_rng(cycle['seed'] + int(digest[:8], 16))
    chunks = []
    for key, group in selected.groupby(columns, dropna=False, observed=True):
        key = key if isinstance(key, tuple) else (key,)
        eligible = pd.Series(True, index=pool.index)
        for column, value in zip(columns, key):
            eligible &= pool[column].eq(value) if pd.notna(value) else pool[column].isna()
        p = pool.loc[eligible]
        if len(p) < len(group):
            raise ValueError(f'Insufficient matching stratum {key}: {len(p)} < {len(group)}')
        chunks.append(p.loc[rng.choice(p.index, len(group), replace=False)].copy())
    c = pd.concat(chunks, ignore_index=True) if chunks else pool.iloc[:0].copy()
    c['method'], c['side'] = cell['method'], cell['side']
    c['candidate_id'] = [f'random_{kind}_{repeat}_{i}_{int(t)}' for i, t in enumerate(c.signal_time)]
    return c


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    if out.exists():
        raise FileExistsError('Outputs are immutable; use a new directory')
    cycle = json.loads((HERE / 'config.json').read_text())
    source_manifest = json.loads((SOURCE / 'manifest.json').read_text())
    data_manifest = json.loads((DATA / 'manifest.json').read_text())
    config = source_manifest['config']
    protected = protected_inputs(data_manifest, source_manifest)
    bars, features, cells, available, calendars = prepare(data_manifest, config)
    if sum(c['variant'] != 'original' for c in cells) != cycle['hypotheses']:
        raise ValueError('Unregistered hypothesis count')
    out.mkdir(parents=True)
    (out / 'config.json').write_text(json.dumps(cycle, indent=2), encoding='utf-8')
    results, summary_frames, month_frames, disposition_frames = {}, [], [], []
    for i, cell in enumerate(cells):
        cid, symbol = cell['cell_id'], cell['symbol']
        candidate_evidence = cell['candidates'].copy()
        candidate_evidence['filter_pass'] = cell['filter_pass']
        candidate_evidence['calendar_pass'] = calendar_admission(candidate_evidence)
        save_table(candidate_evidence, out / 'candidates', cid)
        modes = [('base', True), ('stress', True)]
        if cell['variant'] != 'original':
            modes.append(('base', False))
        for cost, pause in modes:
            meta = {k: cell[k] for k in ['cell_id', 'family', 'variant']}
            meta.update(cost=cost, pause=pause)
            r = simulate_cell(cell, bars[symbol], data_manifest['specs'][symbol], config, cycle, cost, pause)
            results[(cid, cost, pause)] = r
            directory = out / 'accounts' / cid / f'{cost}_{"pause" if pause else "raw"}'
            for name, frame in r.items():
                save_table(frame, directory, name)
            summary_frames.append(with_meta(r['summary'], meta))
            disposition_frames.append(with_meta(r['dispositions'], meta))
            m = collect_months(r, available[symbol], meta, config['initial_equity'])
            if len(m):
                month_frames.append(m)
        print(f'{i+1}/{len(cells)} {cid}', flush=True)
    summaries = pd.concat(summary_frames, ignore_index=True)
    months = (pd.concat(month_frames, ignore_index=True) if month_frames else
              pd.DataFrame(columns=['cell_id', 'family', 'variant', 'cost', 'pause', 'scenario',
                                    'month', 'data_available', 'equity_change_usd', 'n_entries']))
    rows = []
    for cell in cells:
        if cell['variant'] == 'original':
            continue
        rows.append(summarize_gate(cell, results, months, calendars, cycle))
    verdict = pd.DataFrame(rows)
    verdict['holm_p'] = holm_adjust(verdict.p_one_sided.to_numpy(), total_hypotheses=cycle['hypotheses'])
    verdict['gate_statistics'] = verdict.mean_r_ci_low.gt(0) & verdict.holm_p.le(.05)
    verdict.loc[verdict.family.eq('A'), 'gate_statistics'] &= verdict.loc[verdict.family.eq('A'), 'paired_ci_low'].gt(0)
    verdict['provisional_research_pass'] = verdict.survives_gates_1_to_3 & verdict.gate_statistics
    verdict['failure_reasons'] = verdict.apply(lambda r: ';'.join(
        name for name, key in [('profit_or_year', 'gate_profit'), ('monthly_or_frequency', 'gate_monthly'),
                              ('cost_stress', 'gate_stress'), ('uncertainty', 'gate_statistics')] if not r[key]), axis=1)
    # Conditional next gate: the absence of random runs is an explicit stopping
    # decision, not a broken or silently skipped stage.
    controls = []
    for cell in cells:
        gate = verdict.loc[verdict.cell_id.eq(cell['cell_id'])]
        if gate.empty or not gate.survives_gates_1_to_3.iloc[0]:
            continue
        for kind in ['unconditional', 'conditional']:
            for repeat in range(cycle['baseline_repeats']):
                meta = dict(cell_id=cell['cell_id'], control=kind, repeat=repeat)
                try:
                    candidates = random_candidates(cell, features[cell['symbol']], cycle, kind, repeat)
                except ValueError as exc:
                    controls.append(dict(meta, status='matching_unavailable', detail=str(exc)))
                    continue
                control = dict(cell, candidates=candidates, filter_pass=pd.Series(True, index=candidates.index))
                r = simulate_cell(control, bars[cell['symbol']], data_manifest['specs'][cell['symbol']], config, cycle, 'base', True)
                directory = out / 'controls' / cell['cell_id'] / f'{kind}_{repeat}'
                save_table(candidates, directory, 'candidates')
                for name, frame in r.items():
                    save_table(frame, directory, name)
                low = r['summary'].set_index('scenario').loc[LOWER]
                controls.append(dict(meta, status='complete' if low.account_path_complete else 'censored',
                    candidates=len(candidates), trades=int(low.n_closed), mean_r=low.mean_result_r,
                    difference_mean_r=float(gate.mean_r.iloc[0])-low.mean_result_r,
                    net_usd=low.net_pnl_before_unknown_swap_usd))
    control_table = pd.DataFrame(controls) if controls else pd.DataFrame(columns=['cell_id', 'control', 'repeat', 'status', 'mean_r'])
    verdict['control_status'] = 'not_run_failed_gates_1_to_3'
    for cid in verdict.loc[verdict.survives_gates_1_to_3, 'cell_id']:
        c = control_table.loc[control_table.cell_id.eq(cid)]
        ok = len(c) == 2 * cycle['baseline_repeats'] and c.status.eq('complete').all()
        for kind in ['unconditional', 'conditional']:
            sub = c.loc[c.control.eq(kind)]
            ok &= len(sub) == cycle['baseline_repeats'] and sub.get('difference_mean_r', pd.Series(dtype=float)).mean() > 0
        verdict.loc[verdict.cell_id.eq(cid), 'control_status'] = 'positive_mean_difference' if ok else 'unavailable_or_no_difference'
    verdict['advance_to_independent_validation'] = verdict.provisional_research_pass & verdict.control_status.eq('positive_mean_difference')
    year = months.loc[months.data_available.astype(bool)].copy()
    year['year'] = year.month.str[:4]
    yearly = year.groupby(['cell_id', 'cost', 'pause', 'scenario', 'year'], as_index=False).agg(
        net_usd=('equity_change_usd', 'sum'), entries=('n_entries', 'sum'), months=('month', 'size'))
    tables = dict(accounts=summaries, monthly=months, yearly=yearly, verdict=verdict,
                  original_dispositions=pd.concat(disposition_frames, ignore_index=True),
                  paired_comparison=compare_a(cells, results), random_controls=control_table)
    db = duckdb.connect(str(out / 'research.duckdb'))
    for name, frame in tables.items():
        save_table(frame, out, name)
        db.register('current_table', frame)
        db.execute(f'CREATE TABLE {name} AS SELECT * FROM current_table')
        db.unregister('current_table')
    db.close()
    if any(sha(path) != expected for path, expected in protected.items()):
        raise ValueError('Protected evidence changed during run')
    from .report import render
    render(out, tables, cycle)
    code = {str(p.relative_to(ROOT)): sha(p) for p in HERE.rglob('*')
            if p.is_file() and '__pycache__' not in str(p) and p.suffix in ['.py', '.json', '.md']}
    manifest = dict(status='completed', cycle=cycle, execution_config=config, calendar=WEEKEND_POLICY,
        protected_hashes=protected, protected_unchanged=True, source_hashes=code,
        git_head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        dependencies={p: importlib.metadata.version(p) for p in ['numpy', 'pandas', 'pyarrow', 'duckdb', 'plotly']},
        n_hypotheses=len(verdict), n_account_scenarios=len(summaries), holdout_2026_used=False,
        independent_oos=False, all_costs_verified=False,
        quality_limits=['source_clock_unverified', 'spread_bar_proxy', 'commission_assumed_zero',
                        'swap_unknown', 'historical_specs_unverified', 'OHLC_order_unknown', 'not_portfolio'],
        output_hashes={str(p.relative_to(out)): sha(p) for p in out.rglob('*') if p.is_file()})
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding='utf-8')
    print(verdict[['cell_id', 'n_trades', 'pf', 'net_usd', 'failure_reasons']].to_string(index=False), flush=True)
    print(f'Complete: {out}', flush=True)


if __name__ == '__main__':
    main()
