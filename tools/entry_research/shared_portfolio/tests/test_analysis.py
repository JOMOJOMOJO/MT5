import numpy as np
import pandas as pd
import pytest

from tools.entry_research.shared_portfolio.analysis import summarize


def epoch(value):
    return int(pd.Timestamp(value, tz='UTC').timestamp())


def mark(time, value, phase='bar_close', *, balance=None, n=0, adverse=None, favorable=None):
    return dict(time=epoch(time), phase=phase, balance_usd=value if balance is None else balance,
                equity_close_usd=value, equity_adverse_usd=value if adverse is None else adverse,
                equity_favorable_usd=value if favorable is None else favorable,
                n_open=n, planned_open_risk_usd=10*n, margin_used_usd=100*n,
                gross_exposure_usd=1000*n)


def trade(entry, exit, pnl, reason='time_exit', status='closed'):
    return dict(entry_time=epoch(entry), exit_time=epoch(exit),
                net_pnl_before_unknown_swap_usd=pnl, result_r=pnl/10,
                exit_reason=reason, status=status, cell_id='test')


def summarize_fixture(trades, equity, end='2024-04-01', complete=True):
    return summarize(pd.DataFrame(trades), pd.DataFrame(equity), pd.DataFrame(),
                     '2024-01-01', end, 10000., complete)


def test_month_boundary_mark_uses_bar_close_before_new_entry_cost():
    ledger = [trade('2024-01-31 23:00', '2024-02-02', 10),
              trade('2024-02-01', '2024-02-02', -5)]
    equity = [mark('2024-01-01', 10000, 'initial'),
              mark('2024-02-01', 10020, balance=10000, n=1),
              mark('2024-02-01', 10017, 'post_entry', balance=10000, n=2),
              mark('2024-02-02', 10005), mark('2024-03-01', 10005),
              mark('2024-04-01', 10005)]
    summary, monthly, yearly = summarize_fixture(ledger, equity)
    assert monthly.equity_change_usd.tolist() == [20., -15., 0.]
    assert monthly.n_entries.tolist() == [1, 1, 0]
    assert monthly.realized_pnl_usd.tolist() == [0, 5, 0]
    assert monthly.n_open_at_boundary.tolist() == [1, 0, 0]
    assert summary['profit_factor'] == 2.
    assert summary['monthly_positive'] == summary['monthly_negative'] == summary['monthly_flat'] == 1
    assert summary['max_simultaneous_positions'] == 2
    assert yearly.equity_change_usd.sum() == 5.
    assert summary['bootstrap_reps'] == 5000 and summary['bootstrap_block_weeks'] == 4


def test_exit_at_month_boundary_close_and_gap_open_have_distinct_cash_months():
    ledger = [trade('2024-01-31 22:00', '2024-02-01', 20),
              trade('2024-01-31 23:00', '2024-02-01', -5, reason='stop_gap_open')]
    equity = [mark('2024-01-01', 10000, 'initial'),
              mark('2024-02-01', 10020, balance=10020, n=1),
              mark('2024-02-01', 10015, 'gap_open'), mark('2024-03-01', 10015)]
    _, monthly, _ = summarize_fixture(ledger, equity, end='2024-03-01')
    assert monthly.realized_pnl_usd.tolist() == [20., -5.]
    assert monthly.equity_change_usd.tolist() == [20., -5.]


def test_final_exact_boundary_close_is_included_and_cash_reconciles():
    ledger = [trade('2024-03-31 23:00', '2024-04-01', 10)]
    equity = [mark('2024-01-01', 10000, 'initial'), mark('2024-04-01', 10010)]
    summary, monthly, _ = summarize_fixture(ledger, equity)
    assert monthly.realized_pnl_usd.tolist() == [0, 0, 10]
    assert monthly.equity_change_usd.sum() == 10.
    assert summary['net_return_pct'] == pytest.approx(.1)


def test_intrabar_drawdown_is_explicit_conservative_extrema_envelope():
    ledger = [trade('2024-01-02', '2024-01-03', -10)]
    equity = [mark('2024-01-01', 10000, 'initial'),
              mark('2024-01-02 01:00', 10005, balance=10000, n=1, adverse=9900, favorable=10100),
              mark('2024-01-03', 9990)]
    summary, _, _ = summarize_fixture(ledger, equity)
    assert summary['max_drawdown_adverse_envelope_usd'] == 200.
    assert summary['max_drawdown_adverse_envelope_pct'] == pytest.approx(200/10100*100)
    assert summary['max_drawdown_close_usd'] == 15.
    assert summary['intrabar_extrema_chronology_unknown']


def test_incomplete_path_has_prefix_label_no_zero_filled_tail_or_interval():
    ledger = [trade('2024-01-02', '2024-01-03', -10),
              trade('2024-01-04', '2024-01-05', np.nan, status='censored_unknown_gap')]
    equity = [mark('2024-01-01', 10000, 'initial'),
              mark('2024-01-05', 9985, balance=9990, n=1)]
    summary, monthly, yearly = summarize_fixture(ledger, equity, complete=False)
    assert summary['analysis_scope'] == 'observed_prefix'
    assert summary['closed_stats_are_prefix'] and summary['n_closed'] == 1
    assert monthly.empty and yearly.empty
    assert np.isnan(summary['mean_r_ci_low'])
    assert 'monthly_positive' not in summary


def test_zero_trades_preserve_all_no_entry_months():
    summary, monthly, yearly = summarize_fixture([], [mark('2024-01-01', 10000, 'initial')])
    assert monthly.month.tolist() == ['2024-01', '2024-02', '2024-03']
    assert monthly.n_entries.tolist() == [0, 0, 0]
    assert summary['monthly_flat'] == 3 and summary['no_entry_months'] == 3
    assert summary['active_months'] == 0 and summary['n_closed'] == 0
    assert np.isnan(summary['profit_factor']) and np.isnan(summary['mean_r_ci_low'])
    assert yearly.equity_change_usd.sum() == 0.


def test_reject_cash_mismatch_and_incomplete_account_disguised_as_complete():
    ledger = [trade('2024-01-02', '2024-01-03', -10)]
    with pytest.raises(ValueError, match='reconcile'):
        summarize_fixture(ledger, [mark('2024-01-01', 10000, 'initial'), mark('2024-01-03', 9991)])
    with pytest.raises(ValueError, match='unresolved'):
        summarize_fixture(ledger, [mark('2024-01-01', 10000, 'initial'),
                                    mark('2024-01-03', 9990, n=1)])


def test_no_trade_month_breaks_negative_streak_and_year_totals_follow_mtm():
    ledger = [trade('2024-01-02', '2024-01-03', -10),
              trade('2024-02-02', '2024-02-03', -10),
              trade('2024-04-02', '2024-04-03', -10)]
    equity = [mark('2024-01-01', 10000, 'initial'), mark('2024-01-03', 9990),
              mark('2024-02-03', 9980), mark('2024-04-03', 9970)]
    summary, monthly, yearly = summarize_fixture(ledger, equity, end='2025-02-01')
    assert summary['longest_negative_months'] == 2
    assert len(monthly) == 13
    assert yearly.equity_change_usd.tolist() == [-30., 0.]
    assert summary['net_pnl_2024_usd'] == -30.
    assert summary['net_pnl_2025_usd'] == 0.


def test_bootstrap_deterministic_with_common_calendar_inactive_weeks():
    ledger = [trade('2024-01-02', '2024-01-03', 10),
              trade('2024-03-05', '2024-03-06', -5)]
    equity = [mark('2024-01-01', 10000, 'initial'), mark('2024-01-03', 10010),
              mark('2024-03-06', 10005)]
    first = summarize_fixture(ledger, equity)[0]
    second = summarize_fixture(ledger, equity)[0]
    assert first['mean_result_r'] == .25
    assert first['mean_r_ci_low'] == second['mean_r_ci_low']
    assert first['mean_r_ci_high'] == second['mean_r_ci_high']
    assert first['bootstrap_calendar_weeks'] == 13
    assert first['multiple_comparison_adjustment'] == 'none_descriptive_fixed_portfolio_profiles'


def test_partial_initial_month_does_not_create_earlier_unavailable_months():
    summary, monthly, _ = summarize(pd.DataFrame(),
        pd.DataFrame([mark('2024-08-15', 10000, 'initial')]), pd.DataFrame(),
        '2024-08-15', '2024-10-01', 10000., True)
    assert monthly.month.tolist() == ['2024-08', '2024-09']
    assert summary['available_months'] == 2
