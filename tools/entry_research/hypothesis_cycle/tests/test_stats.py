import numpy as np
import pandas as pd
import pytest

from tools.entry_research.hypothesis_cycle.stats import (
    calendar_admission, common_week_calendar, holm_adjust, mean_r_ci,
    monthly_gates, paired_r_difference_ci, weekly_arrays)


def epoch(value):
    return int(pd.Timestamp(value, tz='UTC').timestamp())


def trades(times, values):
    return pd.DataFrame({'entry_time': [epoch(x) for x in times], 'result_r': values})


def test_calendar_pause_inclusive_on_signal_and_known_entry():
    c = pd.DataFrame({
        'signal_time': [epoch(x) for x in ['2024-12-23 23:00', '2024-12-23 23:00', '2024-12-24',
                                         '2025-01-02 23:00', '2025-01-03', '2025-02-01']],
        'entry_time': [epoch('2024-12-23 23:01'), epoch('2024-12-24'), epoch('2025-01-03'),
                       epoch('2025-01-03'), epoch('2025-01-03 01:00'), -1]})
    assert calendar_admission(c).tolist() == [True, False, False, False, True, True]


def test_calendar_and_weekly_arrays_keep_missing_weeks():
    calendar = common_week_calendar('2024-01-03', '2024-01-29')
    assert calendar.tolist() == ['2024-01-01', '2024-01-08', '2024-01-15', '2024-01-22']
    t = trades(['2024-01-05', '2024-01-06', '2024-01-20'], [2., -1., 3.])
    actual = weekly_arrays(t, calendar)
    assert actual.sum_r.tolist() == [1., 0., 3., 0.]
    assert actual.n.tolist() == [2, 0, 1, 0]
    with pytest.raises(ValueError, match='every consecutive'):
        weekly_arrays(t, calendar[[0, 2]])


def test_paired_bootstrap_uses_same_weeks_and_original_candidate_denominator():
    calendar = common_week_calendar('2024-01-01', '2024-03-25')
    times = calendar.to_list()
    base = trades(times, [(-1.) ** i * 10 for i in range(len(times))])
    variant = base.copy()
    variant.result_r += 1.
    candidates = pd.DataFrame({'candidate_id': range(2 * len(times)),
        'entry_time': np.repeat(base.entry_time.to_numpy(), 2),
        'signal_time': np.repeat(base.entry_time.to_numpy() - 3600, 2)})
    result = paired_r_difference_ci(base, variant, candidates, calendar)
    assert result['estimate'] == .5
    assert result['ci_low'] == .5 == result['ci_high']
    assert result['n'] == 2 * len(times)
    assert result['p_one_sided'] == 1 / 5001
    assert result == paired_r_difference_ci(base, variant, candidates, calendar)


def test_mean_ci_negative_direction_and_zero_trades():
    calendar = common_week_calendar('2024-01-01', '2024-03-25')
    negative = trades(calendar.tolist(), [-1.] * len(calendar))
    result = mean_r_ci(negative, calendar)
    assert result['estimate'] == result['ci_low'] == result['ci_high'] == -1.
    assert result['p_one_sided'] == 1.
    empty = mean_r_ci(pd.DataFrame(), calendar)
    assert empty['n'] == 0 and empty['p_one_sided'] == 1.
    assert np.isnan(empty['ci_low'])


def test_expired_candidates_stay_in_paired_denominator():
    calendar = common_week_calendar('2024-01-01', '2024-02-26')
    t = trades(['2024-01-05'], [1.])
    c = pd.DataFrame({'entry_time': [epoch('2024-01-05'), -1],
                      'signal_time': [epoch('2024-01-05'), epoch('2024-01-20')]})
    result = paired_r_difference_ci(pd.DataFrame(), t, c, calendar)
    assert result['n'] == 2 and result['estimate'] == .5


def test_holm_keeps_all_nineteen_comparisons_and_missing_counts_as_one():
    actual = holm_adjust([.001, .01, np.nan], total_hypotheses=19)
    assert actual == pytest.approx([.019, .18, 1.])
    assert holm_adjust([.01, .001, np.nan], total_hypotheses=19) == pytest.approx([.18, .019, 1.])


def month_frame():
    return pd.DataFrame({'month': pd.period_range('2024-01', periods=7, freq='M').astype(str),
                         'data_available': [False] + [True] * 6,
                         'equity_change_usd': [np.nan, 1, 1, -1, 1, 1, -1],
                         'n_entries': [np.nan, 5, 5, 5, 5, 5, 5]})


def test_monthly_gate_accepts_exact_two_thirds_and_excludes_unavailable():
    frame = month_frame()
    result = monthly_gates(frame)
    assert result['available_months'] == 6 and result['positive_months'] == 4
    assert result['positive_month_fraction'] == 2/3
    assert result['monthly_gate']
    frame.loc[1, 'equity_change_usd'] = -1
    assert not monthly_gates(frame)['positive_month_gate']


def test_no_trade_months_count_and_unavailable_month_breaks_loss_streak():
    frame = month_frame()
    frame.loc[2:3, 'n_entries'] = 0
    result = monthly_gates(frame)
    assert result['active_months'] == 4 and not result['active_month_gate']
    frame['equity_change_usd'] = -1.
    frame.loc[3, 'data_available'] = False
    frame.loc[3, 'equity_change_usd'] = np.nan
    result = monthly_gates(frame)
    assert result['max_consecutive_negative_months'] == 3
    frame['data_available'] = False
    assert not monthly_gates(frame)['monthly_gate']
