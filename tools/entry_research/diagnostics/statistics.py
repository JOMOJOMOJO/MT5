"""Opportunity-denominator timing diagnostics and fixed-cohort descriptive paths."""
from __future__ import annotations

import numpy as np
import pandas as pd

from ..statistics import calendar_week_bootstrap, holm_adjust


def interval(values):
    values = np.asarray(values, float)
    finite = values[np.isfinite(values)]
    return tuple(np.quantile(finite, [.025, .975])) if len(finite) else (np.nan, np.nan)


def centered_p(values, estimate):
    values = np.asarray(values, float)
    if not len(values) or not np.isfinite(values).all() or not np.isfinite(estimate):
        return np.nan
    return (1 + np.count_nonzero(np.abs(values - estimate) >= abs(estimate))) / (len(values) + 1)


def timing_summary(strategy, controls, config):
    """Never silently substitute missing outcomes with zero; expire/no-order is explicit."""
    rng = np.random.default_rng(config['seed'])
    s = strategy.loc[strategy.common_pool].copy()
    c = controls.loc[controls.common_pool].copy()
    rows = []
    for (method, side), group in s.groupby(['method', 'side'], sort=True):
        base = group.loc[group.policy.eq('immediate')].set_index('origin_candidate_id')
        for policy, arm in group.groupby('policy', sort=True):
            control = c.loc[c.method.eq(method) & c.side.eq(side) & c.policy.eq(policy)]
            for endpoint in ['hold10', 'deadline50']:
                metric = 'opp_net_' + endpoint
                observed = arm.loc[arm[metric].notna()]
                ctl = control.loc[control[metric].notna()]
                estimate = observed[metric].mean()
                control_mean = ctl.groupby('replicate')[metric].mean().mean()
                boot = calendar_week_bootstrap(observed, ctl, rng, config['bootstrap_reps'], metric)
                row = dict(method=method, side=side, policy=policy, endpoint=endpoint,
                           n=len(arm), outcome_known_n=len(observed), missing_n=len(arm)-len(observed),
                           filled=int(arm.status.eq('filled').sum()),
                           expired=int(arm.status.eq('expired').sum()),
                           unexecutable=int(arm.status.eq('unexecutable').sum()),
                           fill_rate=arm.status.eq('filled').mean(),
                           conditional_net=arm['net_' + endpoint].mean(),
                           opportunity_net=estimate,
                           opportunity_gross=arm['opp_gross_' + endpoint].mean(),
                           baseline_opportunity_net=control_mean,
                           baseline_fill_rate=control.groupby('replicate').status.apply(lambda x: x.eq('filled').mean()).mean(),
                           baseline_missing_n=int(control[metric].isna().sum()),
                           delta_baseline=estimate-control_mean,
                           weeks=observed.week.nunique(),
                           mean_wait_bars=arm.loc[arm.status.eq('filled'), 'wait_bars'].mean())
                row['net_ci_low'], row['net_ci_high'] = interval(boot['strategy'])
                row['baseline_delta_ci_low'], row['baseline_delta_ci_high'] = interval(boot['difference'])
                row['baseline_p'] = centered_p(boot['difference'], row['delta_baseline'])
                pair = arm[['origin_candidate_id', 'week', metric]].join(base[[metric]], on='origin_candidate_id', rsuffix='_immediate')
                pair['difference'] = pair[metric] - pair[metric + '_immediate']
                pair = pair.dropna(subset=['difference'])
                row['paired_n'] = len(pair)
                row['delta_immediate'] = pair.difference.mean()
                # Same origin's difference is resampled as a whole by its original week.
                dummy = pair[['week', 'difference']].assign(replicate=0)
                paired_boot = calendar_week_bootstrap(pair, dummy, rng, config['bootstrap_reps'], 'difference')['strategy']
                row['immediate_delta_ci_low'], row['immediate_delta_ci_high'] = interval(paired_boot)
                row['immediate_p'] = centered_p(paired_boot, row['delta_immediate']) if policy != 'immediate' else np.nan
                # With complete opportunity observations this separates abstention
                # (fewer charges) from any improvement in directional movement.
                gross_metric = 'opp_gross_' + endpoint
                row['delta_gross_immediate'] = arm[gross_metric].mean() - base[gross_metric].mean()
                row['saved_cost_per_origin'] = (base[gross_metric].mean() - base[metric].mean()) - (arm[gross_metric].mean() - estimate)
                for year in [2024, 2025]:
                    sy = observed.loc[observed.year.eq(year)]
                    cy = ctl.loc[ctl.year.eq(year)]
                    row[f'n_{year}'] = len(sy)
                    row[f'net_{year}'] = sy[metric].mean()
                    row[f'delta_{year}'] = sy[metric].mean() - cy.groupby('replicate')[metric].mean().mean()
                rows.append(row)
    result = pd.DataFrame(rows)
    result['baseline_p_holm'] = holm_adjust(result.baseline_p, config['timing_baseline_holm_family'])
    alternate = result.policy.ne('immediate')
    result['immediate_p_holm'] = np.nan
    result.loc[alternate, 'immediate_p_holm'] = holm_adjust(result.loc[alternate, 'immediate_p'], config['timing_immediate_holm_family'])
    result['exploratory_only'] = True
    return result


def aggregate_curve_chunks(chunks, dataset):
    """Retain sums/counts per year and replicate without materializing 8m paths."""
    metrics = ['gross_pips', 'net_pips', 'gross_atr', 'net_atr', 'mfe_atr', 'mae_atr']
    pieces = []
    keys = ['method', 'side', 'year', 'replicate', 'horizon']
    for chunk in chunks:
        if 'replicate' not in chunk:
            chunk = chunk.assign(replicate=-1)
        counts = chunk.groupby(keys).size().rename('n')
        sums = chunk.groupby(keys)[metrics].sum().join(counts).reset_index()
        pieces.append(sums)
    result = pd.concat(pieces).groupby(keys, as_index=False)[metrics + ['n']].sum()
    result['dataset'] = dataset
    return result


def summarize_curves(aggregates):
    metrics = ['gross_pips', 'net_pips', 'gross_atr', 'net_atr', 'mfe_atr', 'mae_atr']
    totals = aggregates.groupby(['dataset', 'method', 'side', 'replicate', 'horizon'], as_index=False)[metrics + ['n']].sum()
    for metric in metrics:
        totals[metric] /= totals.n
    s = totals.loc[totals.dataset.eq('strategy')].drop(columns=['dataset', 'replicate'])
    c = totals.loc[totals.dataset.eq('baseline')].groupby(['method', 'side', 'horizon'])[metrics].mean().add_prefix('baseline_').reset_index()
    result = s.merge(c, on=['method', 'side', 'horizon'], validate='one_to_one')
    result['delta_net_pips'] = result.net_pips - result.baseline_net_pips
    result['descriptive_no_horizon_selection'] = True
    return result


def class_summary(classes):
    rows = []
    labels = sorted(set(classes.class_label) | {'immediate_adverse', 'favorable_then_reversal',
        'adverse_then_favorable', 'favorable_continuation', 'no_direction', 'ambiguous_order',
        'unclassified_other', 'unclassifiable_data'})
    for population, frame in [('all_origins', classes), ('common50', classes.loc[classes.common_pool])]:
        for keys in [[], ['method'], ['side'], ['method', 'side']]:
            groups = frame.groupby(keys, sort=True) if keys else [((), frame)]
            for key, group in groups:
                key = key if isinstance(key, tuple) else (key,)
                meta = dict(zip(keys, key))
                for label in labels:
                    n = int(group.class_label.eq(label).sum())
                    rows.append(dict(population=population, grouping='+'.join(keys) or 'all',
                                     **meta, class_label=label, n=n, denominator=len(group), ratio=n / len(group)))
    return pd.DataFrame(rows)


def summarize_barriers(strategy, controls):
    rows = []
    for (method, side, level), group in strategy.groupby(['method', 'side', 'level']):
        ctl = controls.loc[controls.method.eq(method) & controls.side.eq(side) & controls.level.eq(level)]
        row = dict(method=method, side=side, level=level, n=len(group))
        for outcome in ['tp_first', 'sl_first', 'ambiguous', 'neither']:
            row[outcome + '_n'] = int(group.outcome.eq(outcome).sum())
            row[outcome + '_rate'] = group.outcome.eq(outcome).mean()
        for col in ['net_lower_pips', 'net_upper_pips']:
            row[col] = group[col].mean()
            row['baseline_' + col] = ctl.groupby('replicate')[col].mean().mean()
        row['scenario'] = 'ideal_barrier_ordering_bounds_only_not_execution_bounds'
        rows.append(row)
    return pd.DataFrame(rows)
