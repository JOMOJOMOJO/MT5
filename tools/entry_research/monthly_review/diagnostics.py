"""No parameter search: fixed descriptive buckets and saved-ledger accounting."""
import numpy as np
import pandas as pd

LOCK = 1767225600
MONTHS = pd.period_range('2024-01', '2025-12', freq='M').astype(str).tolist()


def stats(frame):
    cash = frame.net_pnl_before_unknown_swap_usd.to_numpy(dtype=float)
    positive, negative = cash[cash > 1e-10], cash[cash < -1e-10]
    gain, loss = float(positive.sum()), float(-negative.sum())
    return dict(n=len(frame), winners=len(positive), losers=len(negative),
                flat=len(cash)-len(positive)-len(negative), pnl_usd=float(cash.sum()),
                winning_cash_usd=gain, losing_cash_usd=loss,
                pf=gain/loss if loss > 0 else np.nan,
                mean_r=float(frame.result_r.mean()) if len(frame) else np.nan)


def month_labels(seconds):
    return pd.to_datetime(seconds, unit='s', utc=True).dt.strftime('%Y-%m')


def monthly(trades, equity, available, initial=10000.):
    """Realized timestamps and boundary close marks are separate conventions."""
    if (trades.entry_time >= LOCK).any() or (trades.exit_time >= LOCK).any():
        raise ValueError('2026 trades forbidden')
    realized_month = month_labels(trades.exit_time)
    entry_month = month_labels(trades.entry_time)
    rows, previous_equity = [], initial
    for month in MONTHS:
        if month not in available:
            rows.append(dict(month=month, data_available=False))
            continue
        end = int((pd.Timestamp(month, tz='UTC')+pd.offsets.MonthBegin(1)).timestamp())
        # A close mark at midnight represents the completed bar. A gap-open
        # mark at that same instant belongs to the following month.
        # Entry liquidation at the next month's midnight must also be excluded:
        # it already contains that new entry's spread/slippage.
        observed = equity.loc[equity.time.lt(end) | (equity.time.eq(end) & equity.phase.eq('bar_envelope'))]
        if observed.empty:
            raise ValueError('Missing initial equity evidence')
        mark = observed.sort_values('time', kind='stable').iloc[-1]
        eq = float(mark.equity_close_usd)
        at_open = trades.exit_reason.astype(str).str.endswith('_gap_open')
        open_mask = trades.entry_time.lt(end) & (trades.exit_time.gt(end) | (trades.exit_time.eq(end) & at_open))
        sub = trades.loc[realized_month.eq(month)]
        rows.append(dict(month=month, data_available=True, **stats(sub),
                         n_entries=int(entry_month.eq(month).sum()),
                         equity_end_usd=eq, equity_change_usd=eq-previous_equity,
                         equity_return_pct=100*(eq/previous_equity-1),
                         last_equity_mark_time=int(mark.time),
                         open_at_month_boundary=int(open_mask.sum()),
                         open_mark_age_seconds=end-int(mark.time) if open_mask.any() else 0))
        previous_equity = eq
    return pd.DataFrame(rows)


def longest_negative(values):
    current = longest = 0
    for value in values:
        current = current+1 if np.isfinite(value) and value < -1e-10 else 0
        longest = max(longest, current)
    return longest


def monthly_summary(frame):
    available = frame.loc[frame.data_available]
    row = dict(data_months=len(available), mean_trades_per_available_month=available.n.mean(),
               min_monthly_trades=available.n.min(), max_monthly_trades=available.n.max(),
               no_trade_months=int(available.n_entries.eq(0).sum()),
               no_closed_trade_months=int(available.n.eq(0).sum()))
    for column, label in [('pnl_usd', 'realized'), ('equity_change_usd', 'equity')]:
        values = available[column]
        row.update({label+'_positive_months': int(values.gt(1e-10).sum()),
                    label+'_negative_months': int(values.lt(-1e-10).sum()),
                    label+'_flat_months': int(values.abs().le(1e-10).sum()),
                    label+'_worst_month_usd': values.min(),
                    label+'_median_month_usd': values.median(),
                    label+'_longest_negative_months': longest_negative(frame[column].to_numpy())})
    return row


def attach_context(trades, candidates):
    columns = ['candidate_id', 'signal_time', 'available_time', 'trend', 'h4_trend',
               'h4_available_time', 'vol_bucket', 'cloud_position']
    context = candidates[columns].copy()
    if context.candidate_id.duplicated().any():
        raise ValueError('Candidate IDs must be unique')
    result = trades.merge(context, on='candidate_id', how='left', validate='one_to_one')
    if result.signal_time.isna().any() or (result.signal_time > result.entry_time).any():
        raise ValueError('Missing or future decision context')
    if (result.available_time > result.signal_time).any() or (result.signal_time >= LOCK).any():
        raise ValueError('Unconfirmed or holdout signal')
    known_h4 = result.h4_trend.isin(['up', 'down', 'flat'])
    if result.loc[known_h4, 'h4_available_time'].isna().any() or (result.loc[known_h4, 'h4_available_time'] > result.loc[known_h4, 'signal_time']).any():
        raise ValueError('Future/unavailable H4 context')
    desired = np.where(result.side.eq('LONG'), 'up', 'down')
    for source, target in [('trend', 'h1_alignment'), ('h4_trend', 'h4_alignment')]:
        value = result[source].fillna('unknown').to_numpy()
        result[target] = np.where(np.isin(value, ['up', 'down']),
                                  np.where(value == desired, 'aligned', 'opposed'),
                                  np.where(value == 'flat', 'flat', 'unknown'))
    result['vol_bucket'] = result.vol_bucket.astype('string').fillna('unknown')
    result['cloud_position'] = result.cloud_position.astype('string').fillna('unknown')
    result['exit_month'] = month_labels(result.exit_time)
    dt = pd.to_datetime(result.entry_time, unit='s', utc=True)
    result['entry_year'] = dt.dt.year
    result['entry_week'] = (dt.dt.normalize()-pd.to_timedelta(dt.dt.dayofweek, unit='D')).dt.strftime('%Y-%m-%d')
    return result


def loss_classes(trades):
    result = trades.copy()
    losing = result.net_pnl_before_unknown_swap_usd.lt(-1e-10)
    label = np.full(len(result), 'non_losing', dtype=object)
    label[losing] = 'other_loss'
    label[losing & result.exit_reason.eq('time_exit')] = 'time_exit_loss'
    stopped = losing & result.exit_reason.str.startswith('stop') & ~result.ambiguous
    label[stopped & result.holding_bars.le(2)] = 'stop_within_first_2_bars'
    label[stopped & result.holding_bars.gt(2)] = 'stop_after_first_2_bars'
    label[losing & result.ambiguous] = 'ambiguous_stop_loss'
    result['loss_class'] = label
    rows = []
    for name, sub in result.groupby('loss_class'):
        rows.append(dict(loss_class=name, **stats(sub), median_holding_bars=sub.holding_bars.median()))
    return rows


def context_diagnostics(trades, available):
    """Removing saved trades is algebra only, not a filtered trading strategy."""
    rows, months = [], []
    all_month = trades.groupby('exit_month').net_pnl_before_unknown_swap_usd.sum().reindex(available, fill_value=0)
    for feature in ['h1_alignment', 'h4_alignment', 'vol_bucket', 'cloud_position']:
        for bucket, sub in trades.groupby(feature, observed=True, dropna=False):
            left = trades.loc[~trades.index.isin(sub.index)]
            metrics = stats(sub)
            by_year = {year: stats(sub.loc[sub.entry_year.eq(year)]) for year in [2024, 2025]}
            weeks = sub.entry_week.nunique()
            retained_month = left.groupby('exit_month').net_pnl_before_unknown_swap_usd.sum().reindex(available, fill_value=0)
            retained_n = left.groupby('exit_month').size().reindex(available, fill_value=0)
            retained_entry_n = left.groupby(month_labels(left.entry_time)).size().reindex(available, fill_value=0)
            row = dict(feature=feature, bucket=str(bucket), **metrics,
                active_entry_weeks=weeks, fraction_of_all_trades=len(sub)/len(trades),
                removed_winners=metrics['winners'], removed_losers=metrics['losers'],
                lost_winning_cash_usd=metrics['winning_cash_usd'], avoided_losing_cash_usd=metrics['losing_cash_usd'],
                fixed_ledger_pnl_change_usd=-metrics['pnl_usd'],
                retained_trade_n=len(left), retained_trade_fraction=len(left)/len(trades),
                retained_mean_monthly_n=retained_n.mean(), retained_min_monthly_n=retained_n.min(),
                retained_no_trade_months=int(retained_entry_n.eq(0).sum()),
                retained_no_closed_trade_months=int(retained_n.eq(0).sum()),
                fixed_ledger_improved_months=int((retained_month-all_month).gt(1e-10).sum()),
                fixed_ledger_worsened_months=int((retained_month-all_month).lt(-1e-10).sum()),
                retained_positive_months=int(retained_month.gt(1e-10).sum()),
                actual_filtered_account_replayed=False, selected_filter=False)
            for year, values in by_year.items():
                row[f'n_{year}'], row[f'pnl_{year}_usd'] = values['n'], values['pnl_usd']
            row['sample_attention_flag'] = bool(len(sub) >= 100 and weeks >= 30 and
                all(v['n'] >= 30 and v['pnl_usd'] < 0 for v in by_year.values()))
            rows.append(row)
            for month in available:
                months.append(dict(feature=feature, bucket=str(bucket), month=month,
                    original_realized_pnl_usd=float(all_month.loc[month]),
                    retained_fixed_ledger_pnl_usd=float(retained_month.loc[month]),
                    retained_trade_n=int(retained_n.loc[month]),
                    retained_entry_n=int(retained_entry_n.loc[month]), actual_filtered_account_replayed=False))
    return rows, months
