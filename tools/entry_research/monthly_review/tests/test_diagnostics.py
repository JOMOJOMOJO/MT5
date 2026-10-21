import numpy as np
import pandas as pd
import pytest

from tools.entry_research.monthly_review.diagnostics import (
    monthly, monthly_summary, attach_context, context_diagnostics, loss_classes, stats)


def stamp(value):
    return int(pd.Timestamp(value, tz='UTC').timestamp())


def trades():
    return pd.DataFrame({'candidate_id':['x'], 'side':['LONG'],
        'entry_time':[stamp('2024-01-31 23:00')], 'exit_time':[stamp('2024-02-01 01:00')],
        'exit_reason':['target'], 'net_pnl_before_unknown_swap_usd':[10.],
        'result_r':[1.], 'ambiguous':[False], 'holding_bars':[2]})


def marks():
    return pd.DataFrame({'time':[stamp('2024-01-01'),stamp('2024-02-01'),stamp('2024-02-01 01:00')],
        'phase':['initial','bar_envelope','bar_envelope'], 'equity_close_usd':[10000.,10005.,10010.]})


def test_month_crossing_keeps_realized_and_mark_to_market_separate():
    result = monthly(trades(), marks(), ['2024-01','2024-02'])
    jan, feb = result.iloc[0], result.iloc[1]
    assert jan.pnl_usd == 0 and jan.equity_change_usd == 5
    assert feb.pnl_usd == 10 and feb.equity_change_usd == 5
    assert jan.open_at_month_boundary == 1 and feb.open_at_month_boundary == 0
    assert jan.n_entries == 1 and jan.n == 0
    assert not result.iloc[2].data_available
    assert np.isnan(result.iloc[2].pnl_usd)
    assert monthly_summary(result)['data_months'] == 2
    assert monthly_summary(result)['no_trade_months'] == 1


def test_boundary_gap_open_does_not_use_next_month_open_in_prior_equity():
    t = trades()
    t.loc[0, 'exit_time'] = stamp('2024-02-01')
    t.loc[0, 'exit_reason'] = 'target_gap_open'
    e = pd.DataFrame({'time':[stamp('2024-01-01'),stamp('2024-01-31 22:00'),stamp('2024-02-01')],
        'phase':['initial','bar_envelope','exit_at_open'], 'equity_close_usd':[10000.,10004.,10010.]})
    result = monthly(t, e, ['2024-01','2024-02'])
    assert result.iloc[0].equity_change_usd == 4
    assert result.iloc[1].equity_change_usd == 6
    assert result.iloc[0].open_mark_age_seconds == 7200


def test_next_month_entry_spread_is_not_charged_to_previous_month():
    # A prior bar closes at midnight; a new entry is appended at the same time.
    # Its immediate liquidation cost belongs to the new month.
    t = trades()
    t.loc[0, 'entry_time'] = stamp('2024-02-01')
    e = pd.DataFrame({'time':[stamp('2024-01-01'),stamp('2024-02-01'),stamp('2024-02-01'),stamp('2024-02-01 01:00')],
        'phase':['initial','bar_envelope','entry_liquidation','bar_envelope'],
        'equity_close_usd':[10000.,10000.,9998.,10010.]})
    result = monthly(t, e, ['2024-01','2024-02'])
    assert result.iloc[0].equity_change_usd == 0
    assert result.iloc[1].equity_change_usd == 10


def context():
    t = stamp('2024-01-31 23:00')
    return pd.DataFrame({'candidate_id':['x'], 'signal_time':[t], 'available_time':[t],
        'trend':['up'], 'h4_trend':['down'], 'h4_available_time':[t-3600],
        'vol_bucket':['unknown'], 'cloud_position':['above']})


def test_causal_context_and_unknown_preserved():
    result = attach_context(trades(), context())
    assert result.iloc[0].h1_alignment == 'aligned'
    assert result.iloc[0].h4_alignment == 'opposed'
    assert result.iloc[0].vol_bucket == 'unknown'
    c = context(); c.loc[0, 'h4_available_time'] += 7200
    with pytest.raises(ValueError, match='H4'):
        attach_context(trades(), c)


def test_ledger_exclusion_counts_removed_winners_and_empty_months():
    t = pd.concat([trades(), trades()], ignore_index=True)
    t.loc[1, 'candidate_id'] = 'y'
    t.loc[1, 'net_pnl_before_unknown_swap_usd'] = -20
    t.loc[1, 'result_r'] = -2
    c = pd.concat([context(), context()], ignore_index=True)
    c.loc[1, 'candidate_id'] = 'y'
    result = attach_context(t, c)
    rows, months = context_diagnostics(result, ['2024-01','2024-02'])
    row = rows[0]
    assert row['removed_winners'] == 1 and row['removed_losers'] == 1
    assert row['lost_winning_cash_usd'] == 10 and row['avoided_losing_cash_usd'] == 20
    assert row['fixed_ledger_pnl_change_usd'] == 10
    assert row['retained_trade_n'] == 0 and row['retained_no_trade_months'] == 2
    assert row['actual_filtered_account_replayed'] is False


def test_removal_monthly_entries_and_closes_are_separate():
    t = pd.concat([trades(), trades()], ignore_index=True)
    t.loc[1, 'candidate_id'] = 'y'
    c = pd.concat([context(), context()], ignore_index=True)
    c.loc[1, 'candidate_id'] = 'y'
    c.loc[1, 'vol_bucket'] = 'high'
    _, months = context_diagnostics(attach_context(t, c), ['2024-01','2024-02'])
    kept = [m for m in months if m['feature'] == 'vol_bucket' and m['bucket'] == 'high']
    assert [m['retained_entry_n'] for m in kept] == [1, 0]
    assert [m['retained_trade_n'] for m in kept] == [0, 1]


def test_loss_classes_do_not_count_ambiguous_stop_as_known_early_loss():
    t = pd.concat([trades()]*4, ignore_index=True)
    t['net_pnl_before_unknown_swap_usd'] = [-10.,-10.,-10.,10.]
    t['exit_reason'] = ['stop','stop_ambiguous','time_exit','target']
    t['ambiguous'] = [False,True,False,False]
    rows = {r['loss_class']: r for r in loss_classes(t)}
    assert rows['stop_within_first_2_bars']['n'] == 1
    assert rows['ambiguous_stop_loss']['n'] == 1
    assert rows['time_exit_loss']['n'] == 1
    assert stats(t)['losers'] == 3


def test_holdout_trade_is_rejected():
    t = trades(); t.loc[0,'entry_time'] = stamp('2026-01-01')
    with pytest.raises(ValueError, match='2026'):
        monthly(t, marks(), ['2024-01'])
