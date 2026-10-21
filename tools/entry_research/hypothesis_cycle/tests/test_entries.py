import json
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from tools.entry_research.hypothesis_cycle.entries import (
    rsi_candidates, shallow_filter, wilder_rsi)
from tools.entry_research.multiasset.strategies import build_features


CONFIG = json.loads(Path('tools/entry_research/multiasset/config.json').read_text())


def features(closes):
    close = np.asarray(closes, dtype=float)
    opened = np.r_[close[0], close[:-1]]
    times = 1704067200 + np.arange(len(close)) * 3600
    bars = pd.DataFrame({
        'time': times, 'open': opened, 'high': np.maximum(close, opened) + .1,
        'low': np.minimum(close, opened) - .1, 'close': close, 'spread': 10,
        'close_time': times + 3600, 'available_time': times + 3600})
    return build_features(bars, 'H1', 'USDJPY', {}, CONFIG)


def long_prices():
    return np.r_[np.arange(100., 300.), [298, 297, 296, 295, 294, 295], [296] * 5]


def test_wilder_seed_recursion_and_zero_cases():
    actual = wilder_rsi(pd.Series([10., 12., 11., 13., 12.], index=list('abcde')))
    assert actual.iloc[:2].isna().all()
    # Seed gain=1, loss=.5; next gain=1.5, loss=.25; then .75/.625.
    assert actual.iloc[2:].to_list() == pytest.approx([100 / 1.5, 150 / 1.75, 75 / 1.375])
    assert actual.index.tolist() == list('abcde')
    assert wilder_rsi(pd.Series([1., 1., 1., 1.])).iloc[2:].eq(50).all()
    assert wilder_rsi(pd.Series([1., 2., 3., 4.])).iloc[2:].eq(100).all()
    assert wilder_rsi(pd.Series([4., 3., 2., 1.])).iloc[2:].eq(0).all()
    assert wilder_rsi(pd.Series([1., 2.])).isna().all()
    with pytest.raises(ValueError):
        wilder_rsi(pd.Series([1., np.nan, 2.]))


def test_long_short_cross_and_all_feature_columns_preserved():
    for closes, side in [(long_prices(), 'LONG'), (500 - long_prices(), 'SHORT')]:
        f = features(closes)
        original = f.copy(deep=True)
        c = rsi_candidates(f)
        assert c.side.tolist() == [side]
        assert c.signal_index.tolist() == [205]
        assert c.entry_index.tolist() == [206]
        assert c.candidate_id.iloc[0] == f'USDJPY_H1_rsi2_pullback_{side}_{int(f.signal_time.iloc[205])}'
        assert set(f.columns).issubset(c.columns)
        pd.testing.assert_series_equal(c.iloc[0][f.columns], f.iloc[205], check_names=False)
        pd.testing.assert_frame_equal(f, original)


def test_warmup_prevents_early_threshold_recovery_entries():
    short = features(np.r_[np.arange(100., 150.), [148, 147, 146, 145, 144, 145]])
    assert rsi_candidates(short).empty


def test_exact_five_and_ninety_five_require_subsequent_recovery():
    prices = np.r_[np.arange(100., 300.), [298, 297, 296, 295, 294.75, 295.75, 296]]
    # Four unit declines then a quarter decline produce RSI exactly 5.
    for closes, side, boundary in [(prices, 'LONG', 5.), (500 - prices, 'SHORT', 95.)]:
        f = features(closes)
        assert wilder_rsi(f.close).iloc[204] == boundary
        c = rsi_candidates(f)
        assert c.signal_index.tolist() == [205]
        assert c.side.tolist() == [side]


def test_future_prices_do_not_change_past_signals():
    rng = np.random.default_rng(29)
    values = np.r_[long_prices(), 296 + np.cumsum(rng.normal(0, 1, 200))]
    changed = values.copy()
    changed[300:] += 100
    ca, cb = rsi_candidates(features(values)), rsi_candidates(features(changed))
    pd.testing.assert_frame_equal(ca[ca.signal_index < 300].reset_index(drop=True),
                                  cb[cb.signal_index < 300].reset_index(drop=True))


def test_execution_ineligible_candidate_is_retained_without_future_filter():
    f = features(long_prices())
    f.loc[205, ['decision_eligible', 'entry_time', 'entry_index', 'entry_delay_seconds']] = [False, -1, 10000, 99999]
    c = rsi_candidates(f)
    assert len(c) == 1 and not c.decision_eligible.iloc[0]
    assert c.entry_time.iloc[0] == -1 and c.entry_delay_seconds.iloc[0] == 99999
    f.loc[205, 'signal_eligible'] = False
    assert rsi_candidates(f).empty


def test_unknown_future_availability_and_unordered_series_rejected():
    f = features(long_prices())
    f.loc[205, 'available_time'] = f.signal_time.iloc[205] + 1
    with pytest.raises(ValueError, match='availability'):
        rsi_candidates(f)
    f = features(long_prices())
    f.loc[205, 'signal_time'] = 1767225600
    with pytest.raises(ValueError, match='2026'):
        rsi_candidates(f)
    with pytest.raises(ValueError, match='ordered'):
        rsi_candidates(features(long_prices()).iloc[::-1])


def test_shallow_filter_direction_boundaries_and_invalid_inputs():
    c = pd.DataFrame({
        'method': ['donchian', 'atr_breakout', 'ichimoku_cloud', 'ichimoku_cloud', 'donchian', 'donchian'],
        'side': ['LONG', 'SHORT', 'LONG', 'SHORT', 'LONG', 'LONG'],
        'close': [11., 9., 11., 9.01, 11., 11.], 'atr14': [4., 4., 4., 4., 0., 4.],
        'dc_high': [10., 999., 999., 999., 10., np.nan], 'dc_low': [999., 10., 999., 999., 10., 10.],
        'cloud_upper': [999., 999., 10., 999., 999., 999.],
        'cloud_lower': [999., 999., 999., 10., 999., 999.]}, index=[10, 20, 30, 40, 50, 60])
    original = c.copy(deep=True)
    result = shallow_filter(c)
    assert result.tolist() == [True, True, True, False, False, False]
    assert result.index.tolist() == c.index.tolist()
    pd.testing.assert_frame_equal(c, original)
    c.loc[10, 'method'] = 'bollinger'
    with pytest.raises(ValueError, match='breakout'):
        shallow_filter(c)
