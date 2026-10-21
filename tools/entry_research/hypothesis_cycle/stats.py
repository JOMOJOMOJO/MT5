"""Fixed calendar admission, paired weekly uncertainty, and monthly gates.

Epoch timestamps retain the source-clock calendar convention. Parsing as UTC
does not establish that a broker's historical clock was UTC. Bootstrap samples
whole four-week circular blocks including zero-trade weeks; paired comparisons
use the same sampled week indices for both arms and the candidate denominator.
"""
from __future__ import annotations

from fractions import Fraction

import numpy as np
import pandas as pd


SEED = 20261019
REPS = 5000
BLOCK_WEEKS = 4


def _timestamp(value):
    if isinstance(value, (int, float, np.integer, np.floating)):
        return pd.to_datetime(value, unit='s', utc=True)
    value = pd.Timestamp(value)
    return value.tz_localize('UTC') if value.tz is None else value.tz_convert('UTC')


def _week_labels(seconds):
    dt = pd.to_datetime(seconds, unit='s', utc=True)
    return (dt.dt.normalize() - pd.to_timedelta(dt.dt.dayofweek, unit='D')).dt.strftime('%Y-%m-%d')


def common_week_calendar(start, end_exclusive) -> pd.Index:
    """Monday labels for every calendar week touched by [start, end)."""
    first, end = _timestamp(start), _timestamp(end_exclusive)
    if pd.isna(first) or pd.isna(end) or end <= first:
        raise ValueError('Calendar requires a nonempty ordered interval')
    last = end - pd.Timedelta(nanoseconds=1)
    first = first.normalize() - pd.Timedelta(days=first.dayofweek)
    last = last.normalize() - pd.Timedelta(days=last.dayofweek)
    return pd.Index(pd.date_range(first, last, freq='7D').strftime('%Y-%m-%d'), name='week')


def calendar_admission(candidates: pd.DataFrame) -> pd.Series:
    """Exclude source-calendar Dec 24 through Jan 2, inclusive, before entry.

    Check signal time and a positive scheduled entry time. Unresolved/expired
    entry markers are retained when the signal date is allowed; the execution
    engine remains responsible for feasibility. No price outcomes are read.
    """
    signal = pd.to_numeric(candidates.signal_time, errors='coerce')
    entry = pd.to_numeric(candidates.entry_time, errors='coerce')

    def paused(seconds):
        dates = pd.to_datetime(seconds, unit='s', utc=True, errors='coerce')
        return (dates.dt.month.eq(12) & dates.dt.day.ge(24)) | (dates.dt.month.eq(1) & dates.dt.day.le(2))

    allowed = signal.gt(0) & np.isfinite(signal) & ~paused(signal)
    allowed &= ~entry.gt(0) | (np.isfinite(entry) & ~paused(entry.where(entry.gt(0))))
    return allowed.fillna(False).astype(bool).rename('calendar_admitted')


def _validate_calendar(calendar):
    calendar = pd.Index(calendar, name='week')
    if not len(calendar) or calendar.has_duplicates or not calendar.is_monotonic_increasing:
        raise ValueError('Expected an ordered nonempty unique common week calendar')
    parsed = pd.to_datetime(calendar, utc=True, errors='raise')
    if not np.all(parsed.dayofweek == 0) or not np.all((parsed[1:] - parsed[:-1]) == pd.Timedelta(days=7)):
        raise ValueError('Common calendar must include every consecutive Monday')
    return calendar


def weekly_arrays(trades: pd.DataFrame, calendar) -> pd.DataFrame:
    """Sum R and closed-trade count by entry week, including inactive weeks."""
    calendar = _validate_calendar(calendar)
    out = pd.DataFrame({'sum_r': np.zeros(len(calendar)), 'n': np.zeros(len(calendar), dtype=int)}, index=calendar)
    if trades.empty:
        return out
    entry = trades.entry_time.to_numpy(dtype=float)
    result = trades.result_r.to_numpy(dtype=float)
    if not np.isfinite(entry).all() or (entry <= 0).any() or not np.isfinite(result).all():
        raise ValueError('Closed trades require finite positive entry times and finite R')
    labels = _week_labels(trades.entry_time)
    if not labels.isin(calendar).all():
        raise ValueError('Trade lies outside the declared common week calendar')
    grouped = pd.DataFrame({'week': labels.to_numpy(), 'result_r': result}).groupby('week').result_r.agg(['sum', 'size'])
    out.loc[grouped.index, 'sum_r'] = grouped['sum'].to_numpy()
    out.loc[grouped.index, 'n'] = grouped['size'].to_numpy()
    return out


def _candidate_counts(candidates, calendar):
    counts = np.zeros(len(calendar), dtype=int)
    if candidates.empty:
        return counts
    if 'candidate_id' in candidates and candidates.candidate_id.duplicated().any():
        raise ValueError('Original candidates must be unique')
    # No eventual fill is needed for the denominator. An expired candidate is
    # assigned its signal week when no positive entry timestamp exists.
    times = candidates.entry_time.where(candidates.entry_time.gt(0), candidates.signal_time)
    if not np.isfinite(times.to_numpy(dtype=float)).all() or times.le(0).any():
        raise ValueError('Candidate denominator requires an observed signal time')
    labels = _week_labels(times)
    if not labels.isin(calendar).all():
        raise ValueError('Candidate lies outside the declared common week calendar')
    grouped = labels.value_counts().reindex(calendar, fill_value=0)
    return grouped.to_numpy(dtype=int)


def _ratio_ci(numerator, denominator, *, reps=REPS, block_weeks=BLOCK_WEEKS, seed=SEED):
    if isinstance(reps, bool) or not isinstance(reps, (int, np.integer)) or reps < 1:
        raise ValueError('Bootstrap reps must be a positive integer')
    if isinstance(block_weeks, bool) or not isinstance(block_weeks, (int, np.integer)) or block_weeks < 1:
        raise ValueError('Block length must be a positive integer')
    numerator, denominator = np.asarray(numerator, dtype=float), np.asarray(denominator, dtype=float)
    n_weeks = len(numerator)
    total_n = int(denominator.sum())
    result = dict(estimate=np.nan, ci_low=np.nan, ci_high=np.nan, p_one_sided=1.,
                  n=total_n, weeks=n_weeks, bootstrap_valid_reps=0, bootstrap_reps=int(reps),
                  block_weeks=int(block_weeks), seed=int(seed))
    if total_n == 0:
        return result
    estimate = numerator.sum() / total_n
    rng = np.random.default_rng(seed)
    starts = rng.integers(0, n_weeks, size=(reps, int(np.ceil(n_weeks / block_weeks))))
    indices = ((starts[:, :, None] + np.arange(block_weeks)) % n_weeks).reshape(reps, -1)[:, :n_weeks]
    sampled_denominator = denominator[indices].sum(axis=1)
    valid = sampled_denominator > 0
    sampled_numerator = numerator[indices].sum(axis=1)
    samples = sampled_numerator[valid] / sampled_denominator[valid]
    if not len(samples):
        result['estimate'] = float(estimate)
        return result
    # Under H0 E[R]=0, recenter weekly R contributions by the observed ratio
    # times the same week's denominator. The one-sided alternative is positive.
    null_samples = samples - estimate
    result.update(estimate=float(estimate), ci_low=float(np.quantile(samples, .025)),
                  ci_high=float(np.quantile(samples, .975)),
                  p_one_sided=float((1 + np.count_nonzero(null_samples >= estimate)) / (1 + len(samples))),
                  bootstrap_valid_reps=int(valid.sum()))
    return result


def mean_r_ci(trades, calendar, *, reps=REPS, block_weeks=BLOCK_WEEKS, seed=SEED):
    """95% block percentile interval and centered positive-E[R] test."""
    values = weekly_arrays(trades, calendar)
    return _ratio_ci(values.sum_r, values.n, reps=reps, block_weeks=block_weeks, seed=seed)


def paired_r_difference_ci(original_trades, variant_trades, original_candidates, calendar,
                           *, reps=REPS, block_weeks=BLOCK_WEEKS, seed=SEED):
    """Variant minus original sum R, per original candidate, with paired weeks."""
    original = weekly_arrays(original_trades, calendar)
    variant = weekly_arrays(variant_trades, calendar)
    denominator = _candidate_counts(original_candidates, original.index)
    difference = variant.sum_r.to_numpy() - original.sum_r.to_numpy()
    return _ratio_ci(difference, denominator, reps=reps, block_weeks=block_weeks, seed=seed)


def holm_adjust(p_values, total_hypotheses=19) -> np.ndarray:
    """Holm correction with missing/unreported hypotheses counted as p=1."""
    values = np.asarray(p_values, dtype=float)
    if values.ndim != 1 or total_hypotheses < len(values):
        raise ValueError('Total hypotheses must cover the one-dimensional p-value family')
    if np.isinf(values).any() or ((values < 0) | (values > 1)).any():
        raise ValueError('P-values must be in [0,1], or NaN')
    full = np.ones(int(total_hypotheses))
    full[:len(values)] = np.nan_to_num(values, nan=1.)
    order = np.argsort(full, kind='stable')
    adjusted_sorted = np.minimum(1., np.maximum.accumulate(full[order] * np.arange(len(full), 0, -1)))
    adjusted = np.empty(len(full))
    adjusted[order] = adjusted_sorted
    return adjusted[:len(values)]


def monthly_gates(monthly, config=None):
    """Apply fixed activity/stability gates to available calendar months.

    Uses mark-to-market equity changes, not only closing-trade cash. Missing
    months are excluded from denominators and interrupt consecutive-loss runs.
    All available no-trade months remain in the median and fraction denominators.
    """
    cfg = config or {}
    defaults = dict(min_positive_month_fraction=2/3, max_consecutive_negative_months=3,
                    min_active_month_fraction=.8, min_median_entries_per_month=5)
    limits = {key: cfg.get(key, value) for key, value in defaults.items()}
    frame = monthly.sort_values('month').copy()
    if frame.month.duplicated().any():
        raise ValueError('Monthly gate requires one row per calendar month')
    available = frame.loc[frame.data_available.fillna(False)]
    if len(available) and (not np.isfinite(available.equity_change_usd.to_numpy(dtype=float)).all()
                           or not np.isfinite(available.n_entries.to_numpy(dtype=float)).all()
                           or available.n_entries.lt(0).any()):
        raise ValueError('Available months require finite equity and nonnegative entry counts')
    n = len(available)
    positive = int(available.equity_change_usd.gt(1e-10).sum())
    active = int(available.n_entries.gt(0).sum())
    median = float(available.n_entries.median()) if n else np.nan
    longest = current = 0
    previous = None
    for row in frame.itertuples():
        month = pd.Period(row.month, freq='M')
        if previous is not None and month.ordinal != previous.ordinal + 1:
            current = 0
        current = current + 1 if row.data_available and np.isfinite(row.equity_change_usd) and row.equity_change_usd < -1e-10 else 0
        longest = max(longest, current)
        previous = month

    def fraction_pass(count, threshold):
        rational = Fraction(str(threshold)).limit_denominator(1000000)
        return bool(n > 0 and count * rational.denominator >= n * rational.numerator)

    gates = dict(positive_month_gate=fraction_pass(positive, limits['min_positive_month_fraction']),
                 loss_streak_gate=bool(n > 0 and longest <= limits['max_consecutive_negative_months']),
                 active_month_gate=fraction_pass(active, limits['min_active_month_fraction']),
                 monthly_entry_gate=bool(n > 0 and median >= limits['min_median_entries_per_month']))
    return dict(available_months=n, positive_months=positive, active_months=active,
                positive_month_fraction=positive/n if n else np.nan,
                active_month_fraction=active/n if n else np.nan,
                median_entries_per_month=median, max_consecutive_negative_months=longest,
                monthly_gate=all(gates.values()), **gates)
