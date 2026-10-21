from types import SimpleNamespace

import numpy as np
import pandas as pd
import pytest

from tools.entry_research.pf_review import metrics
from tools.entry_research.pf_review.intrabar import first_barrier, refine


def ledger():
    return pd.DataFrame({
        'candidate_id': ['a', 'b', 'c', 'd'], 'status': 'closed',
        'entry_time': [1704067200, 1704672000, 1735689600, 1736294400],
        'exit_time': [1704070800, 1704675600, 1735693200, 1736298000],
        'net_pnl_before_unknown_swap_usd': [20., -10., 15., -5.],
        'planned_risk_usd': [10., 10., 5., 5.], 'result_r': [2., -1., 3., -1.],
        'volume': .1, 'exit_conversion_quote_to_usd': .01,
        'overnight_source_day_crossing': [False, False, True, False],
        'lot_source_day_exposure': [0., 0., .1, 0.]})


def test_cash_pf_is_not_average_r_or_win_rate():
    frame = ledger()
    metrics.validate_trades(frame)
    summary = metrics.summarize(frame)
    assert summary['pf'] == pytest.approx(35/15)
    assert summary['mean_r'] == .75
    assert summary['win_rate'] == .5
    assert summary['pnl_usd'] == 20
    annual, monthly = metrics.period_tables(frame)
    assert [row['pnl_usd'] for row in annual] == [10., 10.]
    assert len(monthly) == 24 and sum(row['n_closed'] for row in monthly) == 4


def test_no_loss_pf_not_fabricated_and_empty_month_defined():
    frame = ledger().iloc[[0]]
    assert np.isnan(metrics.summarize(frame)['pf'])
    assert metrics.summarize(frame.iloc[:0])['n_closed'] == 0


@pytest.mark.parametrize('change', ['future', 'censored', 'duplicate', 'reverse', 'nan_cost'])
def test_invalid_observation_or_holdout_rejected(change):
    frame = ledger()
    if change == 'future':
        frame.loc[0, 'exit_time'] = metrics.LOCK
    elif change == 'censored':
        frame.loc[0, 'status'] = 'censored_time_gap'
    elif change == 'duplicate':
        frame.loc[0, 'candidate_id'] = 'b'
    elif change == 'reverse':
        frame.loc[0, 'exit_time'] = frame.entry_time.iloc[0]-60
    else:
        frame.loc[0, 'exit_conversion_quote_to_usd'] = np.nan
    with pytest.raises(ValueError):
        metrics.validate_trades(frame)


def test_no_trade_weeks_stay_in_bootstrap_population():
    frame = ledger()
    totals = metrics.weekly_totals(frame)
    assert len(totals) == 105
    assert totals['count'].eq(0).sum() == 101
    assert totals['count'].sum() == 4
    # Giving every original week weight 1 must reproduce cash PF and mean R.
    row = metrics.bootstrap(frame, 4, np.ones((10, 105), dtype=int))
    assert row['mean_r_ci_low'] == .75
    assert row['pf_ci_low'] == pytest.approx(35/15)


def test_circular_blocks_have_exact_population_and_are_reproducible():
    w1 = metrics.block_weights(105, 4, reps=100)
    w2 = metrics.block_weights(105, 4, reps=100)
    np.testing.assert_array_equal(w1, w2)
    assert (w1.sum(axis=1) == 105).all()
    assert (w1 >= 0).all()
    assert not np.array_equal(w1, metrics.block_weights(105, 8, reps=100))


def test_cost_zero_point_uses_lots_and_historical_conversion():
    frame = ledger()
    rows, zero = metrics.cost_sensitivity(frame, 100000, .01)
    # 0.1 lot * 100000 * .01 JPY * .01 USD/JPY = $1 per pip per trade.
    assert zero['extra_roundtrip_pips_to_zero'] == 5
    assert zero['extra_roundtrip_usd_per_lot_to_zero'] == 50
    assert rows[0]['pnl_usd'] == 20
    assert rows[4]['pnl_usd'] == 16
    assert zero['swap_cost_known'] is False
    before = frame.copy(deep=True)
    metrics.concentration(frame)
    pd.testing.assert_frame_equal(frame, before)


def path():
    start = 1704067200
    minute = pd.DataFrame({'time': np.arange(start, start+3600, 60),
                           'open': 100., 'high': 100.2, 'low': 99.8, 'close': 100., 'spread': 2.})
    minute.loc[10, 'high'] = 101.1
    minute.loc[40, 'low'] = 98.9
    hour = pd.DataFrame({'time': [start], 'open': 100., 'high': 101.1, 'low': 98.9, 'close': 100., 'spread': 2.})
    trade = SimpleNamespace(entry_time=start, exit_time_upper=start+3600,
                            exit_time_lower=start, stop_price=99., target_price=101.,
                            side='LONG', candidate_id='x')
    return trade, minute, hour


def test_h1_dual_hit_refined_by_chronological_minutes():
    trade, minute, hour = path()
    rows = refine(trade, minute, hour, .001, .01, 1.5)
    assert all(row['first'] == 'target_first' for row in rows)
    assert rows[0]['first_minute'] == trade.entry_time+600
    assert rows[0]['expected_m1'] == rows[0]['actual_m1'] == 60
    assert rows[0]['cashflow_recalculated'] is False
    trade.side, trade.stop_price, trade.target_price = 'SHORT', 101., 99.
    assert refine(trade, minute, hour, .001, .01, 1.5)[0]['first'] == 'stop_first'


def test_minute_order_ambiguity_and_open_priority():
    minute = pd.DataFrame({'time': [1704067200], 'open': [100.], 'high': [101.1], 'low': [98.9]})
    assert first_barrier(minute, 'LONG', 99., 101., [0.])[0] == 'ambiguous_same_minute'
    minute.loc[0, 'open'] = 98.9
    assert first_barrier(minute, 'LONG', 99., 101., [0.]) == ('stop_first', 1704067200, 'minute_open')


@pytest.mark.parametrize('change', ['missing', 'different_h1'])
def test_m1_gap_or_aggregate_disagreement_stays_unresolved(change):
    trade, minute, hour = path()
    if change == 'missing':
        minute = minute.drop(index=5)
    else:
        hour.loc[0, 'high'] = 102.
    assert all(row['first'] == 'unresolved_data' for row in refine(trade, minute, hour, .001, .01, 1.5))


def test_m1_future_guard():
    trade, minute, hour = path()
    minute.loc[59, 'time'] = metrics.LOCK
    with pytest.raises(ValueError, match='2026'):
        refine(trade, minute, hour, .001, .01, 1.5)
