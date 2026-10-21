"""Integration fixtures for original populations, actual cost replay and MTM."""
import numpy as np
import pandas as pd
import pytest

from tools.entry_research.hypothesis_cycle.run import (
    collect_months, random_candidates, simulate_cell)


CYCLE = {'seed': 20261019, 'base_slippage_pips_per_side': .2,
         'stress_slippage_pips_per_side': .7}


def fixture(start='2024-01-31 22:00'):
    times = int(pd.Timestamp(start, tz='UTC').timestamp()) + np.arange(8) * 3600
    bars = pd.DataFrame({'time': times, 'open': 1.1, 'high': 1.1004,
                         'low': 1.0996, 'close': 1.1, 'spread': 20})
    candidates = pd.DataFrame({'candidate_id': ['a'], 'method': ['donchian'],
        'side': ['LONG'], 'symbol': ['EURUSD'], 'signal_index': [0],
        'signal_time': [times[1]], 'nominal_close_time': [times[1]],
        'entry_index': [1], 'entry_time': [times[1]], 'atr14': [.001]})
    spec = {'symbol': 'EURUSD', 'point': .00001, 'pip_size': .0001, 'tick_size': .00001,
            'contract_size': 100000, 'volume_min': .01, 'volume_step': .01, 'volume_max': 100}
    config = {'max_hold_bars': 2, 'initial_equity': 10000, 'risk_fraction': .001,
              'tp_atr': 1., 'sl_atr': 1., 'commission_per_lot_roundtrip_usd': 0}
    cell = {'cell_id': 'fixture', 'method': 'donchian', 'side': 'LONG',
            'candidates': candidates, 'filter_pass': pd.Series(True, index=candidates.index)}
    return cell, bars, spec, config


def test_all_candidates_have_dispositions_including_filters_calendar_and_expiry():
    cell, bars, spec, config = fixture('2024-12-23 20:00')
    original = cell['candidates'].iloc[0].to_dict()
    rows = []
    for cid, entry in [('a', 1), ('filtered', 2), ('holiday', 4), ('expired', 3), ('missing', 7)]:
        row = dict(original, candidate_id=cid, entry_index=entry, signal_index=entry-1,
                   entry_time=int(bars.time.iloc[entry]), signal_time=int(bars.time.iloc[entry]),
                   nominal_close_time=int(bars.time.iloc[entry]))
        if cid == 'expired':
            row['nominal_close_time'] -= 7200
        if cid == 'missing':
            row.update(entry_index=999, entry_time=-1, signal_time=int(bars.time.iloc[1]))
        rows.append(row)
    cell['candidates'] = pd.DataFrame(rows)
    cell['filter_pass'] = pd.Series([True, False, True, True, True])
    result = simulate_cell(cell, bars, spec, config, CYCLE, 'base', True)
    expected = {'a': 'executed', 'filtered': 'excluded_shallow_breakout',
                'holiday': 'excluded_calendar_pause', 'expired': 'skipped_entry_expired',
                'missing': 'skipped_missing_entry'}
    for _, d in result['dispositions'].groupby('scenario'):
        assert d.set_index('candidate_id').status.to_dict() == expected
        assert len(d) == len(cell['candidates'])
    assert result['summary'].n_candidates.eq(3).all()


def test_cost_stress_replays_actual_entry_exit_and_cash_instead_of_subtracting_estimate():
    cell, bars, spec, config = fixture()
    base = simulate_cell(cell, bars, spec, config, CYCLE, 'base', True)
    stress = simulate_cell(cell, bars, spec, config, CYCLE, 'stress', True)
    b, s = base['trades'], stress['trades']
    assert base['summary'].account_path_complete.all() and stress['summary'].account_path_complete.all()
    assert b.exit_reason.eq('time_exit').all() and s.exit_reason.eq('time_exit').all()
    assert b.volume.tolist() == pytest.approx([.09, .09])
    np.testing.assert_allclose(s.entry_fill - b.entry_fill, .00005, atol=1e-10)
    np.testing.assert_allclose(s.exit_fill - b.exit_fill, -.00005, atol=1e-10)
    np.testing.assert_allclose(s.net_pnl_before_unknown_swap_usd - b.net_pnl_before_unknown_swap_usd, -.90, atol=1e-8)
    assert s.planned_risk_usd.gt(b.planned_risk_usd).all()


def test_monthly_mtm_reconciles_cross_month_trade_without_moving_cash_exit():
    cell, bars, spec, config = fixture()
    result = simulate_cell(cell, bars, spec, config, CYCLE, 'base', True)
    months = collect_months(result, ['2024-01', '2024-02'], {'cell_id': 'fixture'}, 10000)
    for scenario, m in months.groupby('scenario'):
        available = m.loc[m.data_available].set_index('month')
        pnl = result['summary'].set_index('scenario').loc[scenario, 'net_pnl_before_unknown_swap_usd']
        assert available.loc['2024-01', 'pnl_usd'] == 0
        assert available.loc['2024-02', 'pnl_usd'] == pytest.approx(pnl)
        assert available.loc['2024-01', 'equity_change_usd'] == pytest.approx(pnl)
        assert available.loc['2024-02', 'equity_change_usd'] == pytest.approx(0)
        assert available.equity_change_usd.sum() == pytest.approx(pnl)
        assert available.n_entries.tolist() == [1, 0]
        assert m.loc[~m.data_available, 'equity_change_usd'].isna().all()


def test_censored_monthly_series_is_not_emitted_and_zero_entry_account_is_valid():
    cell, bars, spec, config = fixture()
    missing = bars.drop(index=2).reset_index(drop=True)
    result = simulate_cell(cell, missing, spec, config, CYCLE, 'base', True)
    assert not result['summary'].account_path_complete.any()
    assert collect_months(result, ['2024-01', '2024-02'], {}, 10000).empty
    cell['filter_pass'] = pd.Series(False, index=cell['candidates'].index)
    empty = simulate_cell(cell, bars, spec, config, CYCLE, 'base', True)
    m = collect_months(empty, ['2024-01', '2024-02'], {}, 10000)
    assert empty['summary'].account_path_complete.all()
    assert m.loc[m.data_available, 'equity_change_usd'].eq(0).all()
    assert empty['dispositions'].status.eq('excluded_shallow_breakout').all()


def test_random_controls_preserve_strata_without_conditioning_on_future_outcomes():
    times = int(pd.Timestamp('2024-03-04', tz='UTC').timestamp()) + np.arange(16) * 3600
    f = pd.DataFrame({'signal_index': np.arange(16), 'signal_time': times,
                      'entry_time': times + 3600, 'signal_eligible': True,
                      'decision_eligible': True, 'month': '2024-03',
                      'hour': [0] * 8 + [1] * 8, 'weekday': 0,
                      'vol_bucket': 'normal', 'future_return': np.arange(16)})
    c = f.iloc[[0, 1, 8, 9]].copy()
    cell = {'cell_id': 'control_fixture', 'method': 'rsi2_pullback', 'side': 'SHORT',
            'candidates': c, 'filter_pass': pd.Series(True, index=c.index)}
    a = random_candidates(cell, f, CYCLE, 'conditional', 0)
    changed = f.copy()
    changed['future_return'] = -changed.future_return
    b = random_candidates(cell, changed, CYCLE, 'conditional', 0)
    assert len(a) == len(c) and not a.signal_index.duplicated().any()
    assert a.groupby('hour').size().to_dict() == c.groupby('hour').size().to_dict()
    assert a.signal_index.tolist() == b.signal_index.tolist()
    assert a.side.eq('SHORT').all()
