"""Shared-account accounting; calendar-month performance includes open P/L.

The intrabar drawdown is a conservative OHLC envelope, not a recovered tick
path. Source epoch timestamps keep the research data's existing clock basis.
The block interval is descriptive after selection of the four saved patterns;
it is not an independent out-of-sample test or a new strategy-selection gate.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

from tools.entry_research.hypothesis_cycle.stats import common_week_calendar, mean_r_ci


TOL = 1e-8
MONTHLY_COLUMNS = [
    'month', 'data_available', 'n_entries', 'n_closed', 'realized_pnl_usd',
    'profit_factor', 'mean_result_r', 'equity_start_usd', 'equity_end_usd',
    'equity_change_usd', 'equity_return_pct', 'last_equity_mark_time',
    'n_open_at_boundary', 'open_mark_age_seconds',
]
YEARLY_COLUMNS = [
    'year', 'available_months', 'n_entries', 'n_closed', 'realized_pnl_usd',
    'equity_start_usd', 'equity_end_usd', 'equity_change_usd', 'equity_return_pct',
    'positive_months', 'negative_months', 'flat_months',
]


def _timestamp(value):
    if isinstance(value, (int, float, np.integer, np.floating)):
        value = pd.to_datetime(value, unit='s', utc=True)
    else:
        value = pd.Timestamp(value)
        value = value.tz_localize('UTC') if value.tz is None else value.tz_convert('UTC')
    return value


def _cash_metrics(trades):
    cash = trades.net_pnl_before_unknown_swap_usd.to_numpy(dtype=float)
    gains, losses = float(cash[cash > TOL].sum()), float(-cash[cash < -TOL].sum())
    return dict(
        n_closed=len(trades), winners=int((cash > TOL).sum()),
        losers=int((cash < -TOL).sum()), flat=int((np.abs(cash) <= TOL).sum()),
        net_pnl_before_unknown_swap_usd=float(cash.sum()),
        gross_profit_usd=gains, gross_loss_usd=losses,
        profit_factor=gains / losses if losses > 0 else (np.inf if gains > 0 else np.nan),
        mean_result_r=float(trades.result_r.mean()) if len(trades) else np.nan,
        median_result_r=float(trades.result_r.median()) if len(trades) else np.nan,
        win_rate=float((cash > TOL).mean()) if len(cash) else np.nan,
    )


def _longest_negative(values):
    longest = current = 0
    for value in values:
        current = current + 1 if value < -TOL else 0
        longest = max(longest, current)
    return longest


def _exit_months(closed):
    """A close at midnight belongs to its just-completed source bar.

Gap-open exits and an explicit non-bar-close exit_phase belong to the new
month. The frozen exit_reason naming convention is used when exit_phase is
absent. These assignments affect realized cash only; equity uses saved marks.
    """
    dates = pd.to_datetime(closed.exit_time, unit='s', utc=True)
    if 'exit_phase' in closed:
        at_close = closed.exit_phase.eq('bar_close')
    elif 'exit_reason' in closed:
        at_close = ~closed.exit_reason.astype(str).str.endswith('_gap_open')
    else:
        at_close = pd.Series(True, index=closed.index)
    adjusted = dates - pd.to_timedelta(at_close.astype(int), unit='ns')
    return adjusted.dt.strftime('%Y-%m')


def summarize(trades, equity, events, start, end_exclusive, initial_equity, complete):
    """Return (summary, monthly, yearly) for one shared account scenario.

Incomplete paths return prefix-only summary statistics and *empty* calendar
tables. No unobserved tail or unavailable month is represented as a zero.
Complete paths include every calendar month touched by [start, end_exclusive).
An exact boundary bar_close is included in the preceding month; entries and
gap-open marks at that timestamp are excluded from that month's equity mark.
    """
    start, end = _timestamp(start), _timestamp(end_exclusive)
    if pd.isna(start) or pd.isna(end) or end <= start:
        raise ValueError('Expected a nonempty ordered interval')
    if not np.isfinite(initial_equity) or initial_equity <= 0:
        raise ValueError('Initial equity must be finite and positive')
    start_s, end_s = start.timestamp(), end.timestamp()
    frame = equity.copy().sort_values('time', kind='stable').reset_index(drop=True)
    required = ['time', 'phase', 'balance_usd', 'equity_close_usd',
                'equity_adverse_usd', 'equity_favorable_usd', 'n_open',
                'planned_open_risk_usd', 'margin_used_usd', 'gross_exposure_usd']
    missing = set(required) - set(frame)
    if frame.empty or missing:
        raise ValueError(f'Nonempty equity evidence required; missing={sorted(missing)}')
    numbers = frame[[x for x in required if x != 'phase']].to_numpy(dtype=float)
    if not np.isfinite(numbers).all():
        raise ValueError('Equity evidence must be finite')
    if frame.time.lt(start_s).any() or frame.time.gt(end_s).any():
        raise ValueError('Equity mark outside declared interval')
    if not (frame.iloc[0].phase == 'initial' and frame.iloc[0].time == start_s
            and np.isclose(frame.iloc[0].equity_close_usd, initial_equity, atol=TOL, rtol=0)
            and np.isclose(frame.iloc[0].balance_usd, initial_equity, atol=TOL, rtol=0)):
        raise ValueError('Initial equity evidence must match the declared account start')
    if (frame.equity_adverse_usd > frame.equity_close_usd + TOL).any() or (
            frame.equity_close_usd > frame.equity_favorable_usd + TOL).any():
        raise ValueError('Equity close must lie inside the intrabar envelope')
    if frame[['n_open', 'planned_open_risk_usd', 'margin_used_usd', 'gross_exposure_usd']].lt(-TOL).any().any():
        raise ValueError('Position counts and exposures must be nonnegative')

    ledger = trades.copy()
    for name in ['status', 'entry_time', 'exit_time', 'result_r', 'net_pnl_before_unknown_swap_usd']:
        if name not in ledger:
            if not ledger.empty:
                raise ValueError(f'Trades missing required column {name}')
            ledger[name] = pd.Series(dtype='object' if name == 'status' else 'float64')
    if not ledger.empty and (not np.isfinite(ledger.entry_time.to_numpy(dtype=float)).all()
                             or ledger.entry_time.lt(start_s).any() or ledger.entry_time.ge(end_s).any()):
        raise ValueError('Trade entry outside declared interval')
    closed = ledger.loc[ledger.status.eq('closed')].copy()
    if len(closed):
        if not np.isfinite(closed[['exit_time', 'result_r', 'net_pnl_before_unknown_swap_usd']].to_numpy(dtype=float)).all():
            raise ValueError('Closed trades require finite times, R, and cash')
        if closed.exit_time.lt(closed.entry_time).any() or closed.exit_time.gt(end_s).any():
            raise ValueError('Closed trade exit outside declared interval')
    if complete and (len(closed) != len(ledger) or frame.iloc[-1].n_open != 0):
        raise ValueError('Complete account must have no unresolved positions')

    close = frame.equity_close_usd.to_numpy(dtype=float)
    favorable = frame.equity_favorable_usd.to_numpy(dtype=float)
    adverse = frame.equity_adverse_usd.to_numpy(dtype=float)
    peaks = np.maximum.accumulate(np.maximum(close, initial_equity))
    envelope_peaks = np.maximum.accumulate(np.maximum(favorable, initial_equity))
    # Current favorable may precede current adverse. OHLC cannot identify that
    # order across one or multiple simultaneous positions: this is an upper
    # envelope for drawdown, explicitly not a measured chronological equity DD.
    close_dd, envelope_dd = peaks - close, envelope_peaks - adverse
    cash = _cash_metrics(closed)
    summary = dict(
        **cash, account_path_complete=bool(complete),
        analysis_scope='full_window' if complete else 'observed_prefix',
        closed_stats_are_prefix=not bool(complete), n_opened=len(ledger),
        start_time=int(start_s), end_exclusive=int(end_s),
        last_observed_time=int(frame.iloc[-1].time),
        initial_equity_usd=float(initial_equity), final_balance_usd=float(frame.iloc[-1].balance_usd),
        final_equity_usd=float(close[-1]), equity_change_usd=float(close[-1] - initial_equity),
        net_return_pct=float(100 * (close[-1] / initial_equity - 1)),
        max_drawdown_close_usd=float(close_dd.max()),
        max_drawdown_close_pct=float((100 * close_dd / peaks).max()),
        max_drawdown_adverse_envelope_usd=float(envelope_dd.max()),
        max_drawdown_adverse_envelope_pct=float((100 * envelope_dd / envelope_peaks).max()),
        intrabar_drawdown_is_conservative_envelope=True,
        intrabar_extrema_chronology_unknown=True,
        max_simultaneous_positions=int(frame.n_open.max()),
        peak_planned_open_risk_usd=float(frame.planned_open_risk_usd.max()),
        peak_margin_used_usd=float(frame.margin_used_usd.max()),
        peak_gross_exposure_usd=float(frame.gross_exposure_usd.max()),
        mean_r_ci_low=np.nan, mean_r_ci_high=np.nan,
        bootstrap_scope='full_calendar_exploratory' if complete else 'not_inferred_for_censored_path',
        bootstrap_reps=5000, bootstrap_block_weeks=4, bootstrap_seed=20261019,
        independent_oos=False, multiple_comparison_adjustment='none_descriptive_fixed_portfolio_profiles',
    )
    if len(events):
        if 'status' not in events:
            raise ValueError('Events require status')
        for status, count in events.status.astype(str).value_counts().items():
            summary['event_' + status] = int(count)
    if not complete:
        return summary, pd.DataFrame(columns=MONTHLY_COLUMNS), pd.DataFrame(columns=YEARLY_COLUMNS)

    cash_total = cash['net_pnl_before_unknown_swap_usd']
    if not np.isclose(frame.iloc[-1].balance_usd - initial_equity, cash_total, atol=1e-6, rtol=1e-10):
        raise ValueError('Closed-trade cash does not reconcile to final account balance')
    if not np.isclose(close[-1], frame.iloc[-1].balance_usd, atol=1e-6, rtol=1e-10):
        raise ValueError('Flat final account equity does not reconcile to balance')
    periods = pd.period_range(start.tz_localize(None).to_period('M'),
                              (end - pd.Timedelta(nanoseconds=1)).tz_localize(None).to_period('M'), freq='M')
    entry_months = pd.to_datetime(ledger.entry_time, unit='s', utc=True).dt.strftime('%Y-%m')
    exit_months = _exit_months(closed)
    rows, previous_equity = [], float(initial_equity)
    for period in periods:
        month = str(period)
        # Use the next period's start rather than end_time + 1ns: some pandas
        # versions expose period.end_time at microsecond resolution.
        boundary = min((period + 1).start_time.tz_localize('UTC'), end).timestamp()
        eligible = frame.loc[frame.time.lt(boundary) | (frame.time.eq(boundary) & frame.phase.eq('bar_close'))]
        if eligible.empty:
            raise ValueError('Missing initial or month-boundary equity evidence')
        mark = eligible.iloc[-1]
        subset = closed.loc[exit_months.eq(month)]
        metrics = _cash_metrics(subset)
        current = float(mark.equity_close_usd)
        rows.append(dict(
            month=month, data_available=True, n_entries=int(entry_months.eq(month).sum()),
            n_closed=len(subset), realized_pnl_usd=metrics['net_pnl_before_unknown_swap_usd'],
            profit_factor=metrics['profit_factor'], mean_result_r=metrics['mean_result_r'],
            equity_start_usd=previous_equity, equity_end_usd=current,
            equity_change_usd=current-previous_equity,
            equity_return_pct=100 * (current/previous_equity-1) if previous_equity > 0 else np.nan,
            last_equity_mark_time=int(mark.time), n_open_at_boundary=int(mark.n_open),
            open_mark_age_seconds=int(boundary-mark.time) if mark.n_open else 0,
        ))
        previous_equity = current
    monthly = pd.DataFrame(rows, columns=MONTHLY_COLUMNS)
    if not np.isclose(monthly.equity_change_usd.sum(), cash_total, atol=1e-6, rtol=1e-10):
        raise ValueError('Monthly equity does not reconcile to final closed-trade cash')
    if not np.isclose(monthly.realized_pnl_usd.sum(), cash_total, atol=1e-6, rtol=1e-10):
        raise ValueError('Monthly realized cash does not reconcile to closed-trade cash')

    yearly_rows = []
    for year, subset in monthly.groupby(monthly.month.str[:4], sort=True):
        first, last = subset.iloc[0], subset.iloc[-1]
        yearly_rows.append(dict(
            year=int(year), available_months=len(subset), n_entries=int(subset.n_entries.sum()),
            n_closed=int(subset.n_closed.sum()), realized_pnl_usd=float(subset.realized_pnl_usd.sum()),
            equity_start_usd=float(first.equity_start_usd), equity_end_usd=float(last.equity_end_usd),
            equity_change_usd=float(subset.equity_change_usd.sum()),
            equity_return_pct=100 * (last.equity_end_usd/first.equity_start_usd-1)
                if first.equity_start_usd > 0 else np.nan,
            positive_months=int(subset.equity_change_usd.gt(TOL).sum()),
            negative_months=int(subset.equity_change_usd.lt(-TOL).sum()),
            flat_months=int(subset.equity_change_usd.abs().le(TOL).sum()),
        ))
    yearly = pd.DataFrame(yearly_rows, columns=YEARLY_COLUMNS)
    summary.update(
        available_months=len(monthly), monthly_positive=int(monthly.equity_change_usd.gt(TOL).sum()),
        monthly_negative=int(monthly.equity_change_usd.lt(-TOL).sum()),
        monthly_flat=int(monthly.equity_change_usd.abs().le(TOL).sum()),
        longest_negative_months=_longest_negative(monthly.equity_change_usd),
        median_entries_per_month=float(monthly.n_entries.median()),
        mean_entries_per_month=float(monthly.n_entries.mean()),
        active_months=int(monthly.n_entries.gt(0).sum()),
        no_entry_months=int(monthly.n_entries.eq(0).sum()),
        positive_month_fraction=float(monthly.equity_change_usd.gt(TOL).mean()),
        worst_month_usd=float(monthly.equity_change_usd.min()),
        worst_month_return_pct=float(monthly.equity_return_pct.min()),
    )
    for row in yearly.itertuples():
        summary[f'net_pnl_{row.year}_usd'] = row.equity_change_usd
    ci = mean_r_ci(closed, common_week_calendar(start, end), reps=5000, block_weeks=4, seed=20261019)
    summary.update(mean_r_ci_low=ci['ci_low'], mean_r_ci_high=ci['ci_high'],
                   mean_r_p_one_sided_exploratory=ci['p_one_sided'],
                   bootstrap_calendar_weeks=ci['weeks'], bootstrap_valid_reps=ci['bootstrap_valid_reps'])
    return summary, monthly, yearly
