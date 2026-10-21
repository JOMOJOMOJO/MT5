"""The portfolio path adapter must preserve the frozen single-position model."""
import numpy as np
import pandas as pd
import pytest

from tools.entry_research.account_replay.calendar import WEEKEND_POLICY
from tools.entry_research.account_replay.execution import simulate
from tools.entry_research.multiasset.tests.test_execution import fixture
from tools.entry_research.shared_portfolio.path import trade_path


def shifted_fixture(side='LONG', symbol='EURUSD'):
    bars, candidates, spec, config = fixture(symbol=symbol, side=side, count=35)
    candidates['signal_index'] = 9
    candidates['entry_index'] = 10
    candidates['signal_time'] = candidates['entry_time'] = bars.time.iloc[10]
    config.update(max_hold_bars=10, calendar_policy=WEEKEND_POLICY)
    return bars, candidates.iloc[0].to_dict(), spec, config


def assert_matches_full(bars, candidate, spec, config, equity=12000., risk=.00025,
                        scenario='stop_first_lower'):
    got = trade_path(bars, candidate, spec, config, equity, risk, scenario)
    full = simulate(bars, pd.DataFrame([candidate]), spec,
                    dict(config, initial_equity=equity, risk_fraction=risk))
    trades = full['trades'][full['trades'].scenario.eq(scenario)]
    if len(trades):
        pd.testing.assert_series_equal(pd.Series(got['trade']), trades.iloc[0],
                                       check_names=False)
    else:
        assert got['trade'] is None
    pd.testing.assert_frame_equal(pd.DataFrame(got['events']),
        full['events'][full['events'].scenario.eq(scenario)].reset_index(drop=True),
        check_dtype=False)
    expected_marks = full['equity'].loc[
        full['equity'].scenario.eq(scenario) & full['equity'].phase.ne('initial')
    ].reset_index(drop=True)
    pd.testing.assert_frame_equal(got['marks'][expected_marks.columns], expected_marks)
    for original, offset in [('equity_close_usd', 'pnl_close_usd'),
                             ('equity_adverse_usd', 'pnl_adverse_usd'),
                             ('equity_favorable_usd', 'pnl_favorable_usd'),
                             ('balance_usd', 'realized_pnl_usd')]:
        np.testing.assert_allclose(got['marks'][offset], expected_marks[original] - equity)
    return got


@pytest.mark.parametrize('scenario', ['stop_first_lower', 'target_first_upper'])
@pytest.mark.parametrize('side', ['LONG', 'SHORT'])
@pytest.mark.parametrize('symbol', ['EURUSD', 'USDJPY', 'USDCHF'])
def test_compact_path_exactly_matches_full_series(side, symbol, scenario):
    bars, candidate, spec, config = shifted_fixture(side, symbol)
    original_bars, original_candidate = bars.copy(deep=True), dict(candidate)
    result = assert_matches_full(bars, candidate, spec, config, scenario=scenario)
    assert result['trade']['entry_index'] == 10
    assert result['trade']['exit_index'] == 19
    assert result['trade']['holding_bars'] == 10
    pd.testing.assert_frame_equal(bars, original_bars)
    assert candidate == original_candidate


@pytest.mark.parametrize('scenario', ['stop_first_lower', 'target_first_upper'])
def test_ambiguous_trade_keeps_selected_scenario(scenario):
    bars, candidate, spec, config = shifted_fixture()
    bars.loc[10, ['high', 'low']] = [1.102, 1.098]
    result = assert_matches_full(bars, candidate, spec, config, scenario=scenario)
    trade = result['trade']
    assert trade['ambiguous'] and trade['holding_bars'] == 1
    assert (trade['net_pnl_usd'] < 0) == (scenario == 'stop_first_lower')


def test_current_equity_and_risk_drive_lot_floor():
    bars, candidate, spec, config = shifted_fixture()
    low = assert_matches_full(bars, candidate, spec, config, equity=10000.)
    high = assert_matches_full(bars, candidate, spec, config, equity=20000.)
    assert low['trade']['risk_budget_usd'] == 2.5
    assert high['trade']['risk_budget_usd'] == 5.
    assert high['trade']['volume'] > low['trade']['volume']
    tiny = assert_matches_full(bars, candidate, spec, config, equity=100.)
    assert tiny['trade'] is None and tiny['marks'].empty
    assert tiny['events'][0]['status'] == 'skipped_min_lot_risk'


@pytest.mark.parametrize('gap_kind', ['weekend', 'unknown'])
def test_calendar_gap_semantics_are_unchanged(gap_kind):
    bars, candidate, spec, config = shifted_fixture()
    start = int(pd.Timestamp('2024-01-05 22:50').timestamp())
    bars['time'] = start + np.arange(len(bars)) * 300
    bars.loc[14:, 'time'] += 172800 + (300 if gap_kind == 'unknown' else 0)
    candidate['signal_time'] = candidate['entry_time'] = bars.time.iloc[10]
    result = assert_matches_full(bars, candidate, spec, config)
    trade = result['trade']
    if gap_kind == 'weekend':
        assert trade['status'] == 'closed' and trade['closure_crossings'] == 1
        assert trade['holding_bars'] == 10
    else:
        assert trade['status'] == 'censored_time_gap'
        assert np.isnan(trade['net_pnl_usd'])
        assert trade['holding_bars'] == 4
        assert result['marks'].realized_pnl_usd.eq(0).all()


def test_gap_open_exit_has_frozen_timestamp_and_actual_fill():
    bars, candidate, spec, config = shifted_fixture()
    bars.loc[11, ['open', 'high', 'low', 'close']] = [1.098, 1.0985, 1.0975, 1.098]
    result = assert_matches_full(bars, candidate, spec, config)
    assert result['trade']['exit_time'] == bars.time.iloc[11]
    assert result['marks'].phase.iloc[-1] == 'exit_at_open'


@pytest.mark.parametrize('change', ['entry_signal_same_bar', 'signal_not_closed',
                                    'negative_entry', 'entry_out_of_range', 'late_entry'])
def test_ineligible_candidates_keep_frozen_dispositions(change):
    bars, candidate, spec, config = shifted_fixture()
    if change == 'entry_signal_same_bar':
        candidate['signal_index'] = candidate['entry_index']
    elif change == 'signal_not_closed':
        candidate['signal_time'] -= 1
    elif change == 'negative_entry':
        candidate['entry_index'] = -1
    elif change == 'entry_out_of_range':
        candidate['entry_index'] = len(bars)
    else:
        candidate['nominal_close_time'] = candidate['signal_time'] - 301
    result = assert_matches_full(bars, candidate, spec, config)
    assert result['trade'] is None and result['marks'].empty


def test_last_bar_never_forces_a_future_exit():
    bars, candidate, spec, config = shifted_fixture()
    bars = bars.iloc[:11].copy()
    result = assert_matches_full(bars, candidate, spec, config)
    assert result['trade']['status'] == 'censored_data_end'
    assert result['trade']['holding_bars'] == 1
    assert result['marks'].time.max() == bars.time.iloc[-1] + 300


def test_changes_after_closed_trade_do_not_change_its_path():
    bars, candidate, spec, config = shifted_fixture()
    bars.loc[10, 'high'] = 1.102
    before = trade_path(bars, candidate, spec, config, 10000.)
    bars.loc[11:, ['open', 'high', 'low', 'close']] *= 2
    after = trade_path(bars, candidate, spec, config, 10000.)
    pd.testing.assert_series_equal(pd.Series(before['trade']), pd.Series(after['trade']))
    pd.testing.assert_frame_equal(before['marks'], after['marks'])


def test_holdout_anywhere_in_supplied_bars_is_rejected():
    bars, candidate, spec, config = shifted_fixture()
    bars.loc[len(bars)-1, 'time'] = 1767225600
    with pytest.raises(ValueError, match='2026'):
        trade_path(bars, candidate, spec, config, 10000.)


def test_unknown_scenario_rejected():
    bars, candidate, spec, config = shifted_fixture()
    with pytest.raises(ValueError, match='scenario'):
        trade_path(bars, candidate, spec, config, 10000., scenario='optimistic')
