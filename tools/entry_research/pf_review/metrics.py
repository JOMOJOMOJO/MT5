"""Fixed-ledger statistics; no strategy, sizing, or fill recalculation."""
from __future__ import annotations

import numpy as np
import pandas as pd

START = 1704067200
LOCK = 1767225600
SEED = 20261017
REPS = 20000


def validate_trades(trades):
    if trades.empty or not trades.status.eq('closed').all():
        raise ValueError('A nonempty fully closed ledger is required')
    for column in ['entry_time', 'exit_time']:
        values = trades[column].to_numpy(dtype=float)
        if not np.isfinite(values).all() or (values < START).any():
            raise ValueError('Only 2024-2025 development trades are allowed')
        # An exit boundary at 2026-01-01 uses the final 2025 bar only.
        if (values >= LOCK).any():
            raise ValueError('2026 trade timestamps are forbidden in this audit')
    if (trades.exit_time < trades.entry_time).any():
        raise ValueError('Exit precedes entry')
    if trades.candidate_id.duplicated().any():
        raise ValueError('One scenario, no repeated candidate IDs')
    for column in ['net_pnl_before_unknown_swap_usd', 'result_r', 'planned_risk_usd',
                   'volume', 'exit_conversion_quote_to_usd']:
        if not np.isfinite(trades[column].to_numpy(dtype=float)).all():
            raise ValueError(f'Nonfinite {column}')
    if (trades[['volume', 'planned_risk_usd', 'exit_conversion_quote_to_usd']] <= 0).any().any():
        raise ValueError('Positive volume, risk and conversion required')


def summarize(trades, pnl=None):
    values = np.asarray(trades.net_pnl_before_unknown_swap_usd if pnl is None else pnl, dtype=float)
    if len(values) != len(trades) or not np.isfinite(values).all():
        raise ValueError('PnL must be finite and aligned to the ledger')
    gain, loss = values[values > 0].sum(), -values[values < 0].sum()
    return dict(n_closed=len(values), pnl_usd=values.sum(), gross_winning_cash_usd=gain,
                gross_losing_cash_usd=loss, pf=gain/loss if loss > 0 else np.nan,
                pf_status='defined' if loss > 0 else 'no_losses',
                mean_r=np.mean(values/trades.planned_risk_usd.to_numpy()) if len(values) else np.nan,
                mean_pnl_usd=values.mean() if len(values) else np.nan,
                win_rate=(values > 0).mean() if len(values) else np.nan)


def period_tables(trades):
    dt = pd.to_datetime(trades.exit_time, unit='s', utc=True)
    annual, monthly = [], []
    for year in [2024, 2025]:
        annual.append(dict(year=year, **summarize(trades.loc[dt.dt.year.eq(year)])))
    for month in pd.period_range('2024-01', '2025-12', freq='M').astype(str):
        monthly.append(dict(month=month, **summarize(trades.loc[dt.dt.strftime('%Y-%m').eq(month)])))
    return annual, monthly


def block_weights(n_weeks, block_length, reps=REPS, seed=SEED):
    """Circular moving blocks; every replicate has exactly n_weeks labels."""
    if not 1 <= block_length <= n_weeks or reps < 1:
        raise ValueError('Invalid block or replicate count')
    rng = np.random.default_rng(seed + block_length)
    starts = rng.integers(n_weeks, size=(reps, (n_weeks+block_length-1)//block_length))
    indices = ((starts[:, :, None] + np.arange(block_length)) % n_weeks).reshape(reps, -1)[:, :n_weeks]
    weights = np.zeros((reps, n_weeks), dtype=np.int16)
    np.add.at(weights, (np.arange(reps)[:, None], indices), 1)
    return weights


def weekly_totals(trades):
    weeks = pd.date_range('2024-01-01', '2025-12-29', freq='W-MON', tz='UTC')
    dt = pd.to_datetime(trades.entry_time, unit='s', utc=True)
    labels = dt.dt.normalize() - pd.to_timedelta(dt.dt.dayofweek, unit='D')
    pnl = trades.net_pnl_before_unknown_swap_usd.to_numpy()
    frame = pd.DataFrame({'week': labels.to_numpy(), 'count': 1,
                          'r': trades.result_r.to_numpy(), 'pnl': pnl,
                          'gain': np.maximum(pnl, 0), 'loss': np.maximum(-pnl, 0)})
    grouped = frame.groupby('week').sum().reindex(weeks, fill_value=0)
    if grouped['count'].sum() != len(trades):
        raise ValueError('Calendar does not cover all trades')
    return grouped


def bootstrap(trades, block_length, weights=None):
    totals = weekly_totals(trades)
    weights = block_weights(len(totals), block_length) if weights is None else weights
    sampled = weights @ totals[['count', 'r', 'pnl', 'gain', 'loss']].to_numpy()
    count, r_sum, cash, gain, loss = sampled.T
    with np.errstate(divide='ignore', invalid='ignore'):
        mean_r, mean_cash, pf = r_sum/count, cash/count, gain/loss
    row = dict(block_weeks=block_length, bootstrap_reps=len(weights),
               calendar_weeks=len(totals), active_entry_weeks=int(totals['count'].gt(0).sum()),
               n_closed=len(trades), inference='exploratory_fixed_ledger_unadjusted_CI')
    for name, distribution in [('mean_r', mean_r), ('mean_pnl_usd', mean_cash), ('pf', pf)]:
        valid = distribution[np.isfinite(distribution)]
        row[name+'_valid_reps'] = len(valid)
        row[name+'_ci_low'], row[name+'_ci_high'] = np.quantile(valid, [.025, .975]) if len(valid) else [np.nan, np.nan]
    point = trades.result_r.mean()
    valid = mean_r[np.isfinite(mean_r)]
    # Approximate one-sided null using the centered bootstrap distribution.
    p = (1+np.count_nonzero(valid-point >= point))/(len(valid)+1) if len(valid) else np.nan
    row.update(mean_r=point, centered_one_sided_p=p,
               account_family_bonferroni_432=min(1., p*432),
               all_prior_searches_corrected=False, live_promotion=False)
    return row


def cost_sensitivity(trades, contract_size, pip_size):
    if not np.isfinite([contract_size, pip_size]).all() or min(contract_size, pip_size) <= 0:
        raise ValueError('Positive contract size and pip required')
    base = trades.net_pnl_before_unknown_swap_usd.to_numpy()
    usd_per_pip = (trades.volume * contract_size * pip_size * trades.exit_conversion_quote_to_usd).to_numpy()
    rows = []
    for mode, levels, exposure in [
        ('extra_roundtrip_pips', [0., .1, .25, .5, 1.], usd_per_pip),
        ('extra_roundtrip_usd_per_lot', [0., 3., 5., 7.], trades.volume.to_numpy()),
    ]:
        for level in levels:
            rows.append(dict(cost_axis=mode, extra_cost=level,
                             total_added_usd=float((level*exposure).sum()),
                             **summarize(trades, base-level*exposure)))
    breakeven = dict(extra_roundtrip_pips_to_zero=base.sum()/usd_per_pip.sum(),
                     extra_roundtrip_usd_per_lot_to_zero=base.sum()/trades.volume.sum(),
                     sum_lots=trades.volume.sum(), sum_usd_per_pip=usd_per_pip.sum(),
                     n_source_day_crossing=int(trades.overnight_source_day_crossing.sum()),
                     lot_source_day_exposure=trades.lot_source_day_exposure.sum(),
                     swap_cost_known=False, frozen_cashflow_stress_only=True)
    return rows, breakeven


def concentration(trades):
    pnl = trades.net_pnl_before_unknown_swap_usd
    months = pd.to_datetime(trades.exit_time, unit='s', utc=True).dt.strftime('%Y-%m')
    best = pnl.groupby(months).sum().idxmax()
    rows = [dict(sensitivity='remove_best_exit_month', removed_month=best,
                 removed_n=int(months.eq(best).sum()), **summarize(trades.loc[months.ne(best)]))]
    for n in [3, 5]:
        remove = pnl.loc[pnl.gt(0)].nlargest(n).index
        rows.append(dict(sensitivity=f'remove_top_{n}_winners', removed_month='',
                         removed_n=len(remove), **summarize(trades.drop(index=remove))))
    return rows
