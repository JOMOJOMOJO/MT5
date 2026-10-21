import json
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from tools.entry_research.multiasset.data import normalize, audit, guarded_period
from tools.entry_research.multiasset.strategies import build_features, extract_candidates, complete_mask, METHODS
from tools.entry_research.multiasset.inference import random_controls, walk_forward

CONFIG = json.loads(Path('tools/entry_research/multiasset/config.json').read_text())


def bars(n=1000, step=300):
    rng = np.random.default_rng(7)
    close = 150+np.cumsum(rng.normal(0, .04, n))
    opened = np.r_[close[0], close[:-1]]
    return pd.DataFrame({'time': 1704067200+np.arange(n)*step,
                         'open': opened, 'high': np.maximum(opened, close)+.02,
                         'low': np.minimum(opened, close)-.02, 'close': close, 'spread': 15,
                         'close_time': 1704067200+(np.arange(n)+1)*step,
                         'available_time': 1704067200+(np.arange(n)+1)*step})


def test_future_changes_leave_all_detectors_unchanged():
    a = bars()
    b = a.copy()
    b.loc[750:, ['open', 'high', 'low', 'close']] += 100
    fa, fb = [build_features(x, 'M5', 'USDJPY', {}, CONFIG) for x in [a, b]]
    for name in METHODS:
        for side in ['LONG', 'SHORT']:
            pd.testing.assert_series_equal(METHODS[name].detect(fa)[side].iloc[:750], METHODS[name].detect(fb)[side].iloc[:750])
    pd.testing.assert_frame_equal(fa.iloc[:750], fb.iloc[:750])


def test_closed_higher_timeframe_only_and_stale_unknown():
    a, h = bars(), bars(84, 3600)
    h.available_time = h.close_time+120
    f = build_features(a, 'M5', 'USDJPY', {}, CONFIG, {'H1': h})
    selected = f[f.h1_available_time.notna()]
    assert (selected.h1_available_time <= selected.signal_time).all()
    assert f.loc[f.signal_time < h.available_time.iloc[0], 'h1_trend'].eq('unknown').all()


def test_method_specific_warmup_and_next_available_entry():
    a = bars(100)
    a.loc[80, 'available_time'] += 1
    f = build_features(a, 'M5', 'USDJPY', {}, CONFIG)
    assert f.loc[80, 'entry_index'] == 82
    assert f.loc[80, 'entry_time'] >= f.loc[80, 'signal_time']
    assert f.loc[50, 'signal_eligible']  # no unrelated cloud/HTF requirement
    c = extract_candidates(f, CONFIG['methods'], CONFIG)
    assert (c.signal_time == c.available_time).all()


def test_donchian_and_bollinger_explicit_fixture():
    df = pd.DataFrame({'close': [10, 12, 10, 8], 'dc_high': [11]*4, 'dc_low': [9]*4,
                       'bb_high': [11]*4, 'bb_low': [9]*4, 'contracted_previous': [False, True, False, True]})
    assert METHODS['donchian'].detect(df)['LONG'].tolist() == [False, True, False, False]
    assert METHODS['donchian'].detect(df)['SHORT'].tolist() == [False, False, False, True]
    assert METHODS['bollinger'].detect(df)['SHORT'].tolist() == [False, False, True, False]
    assert METHODS['atr_breakout'].detect(df)['LONG'].equals(METHODS['donchian'].detect(df)['LONG'])


def test_guard_and_geometry():
    cfg = dict(CONFIG, end='2027-01-01')
    with pytest.raises(ValueError): guarded_period(cfg)
    b = bars(10)
    b.loc[0, 'high'] = b.low.iloc[0]-1
    with pytest.raises(ValueError): normalize(b, 300, 1704067200, 1767225600)
    b = bars(10)
    b.loc[9, 'time'] = 1767225600
    with pytest.raises(ValueError): normalize(b, 300, 1704067200, 1767225600)


def test_completeness_is_not_entry_filter_and_baselines_match():
    f = build_features(bars(), 'M5', 'USDJPY', {}, CONFIG)
    f['comparison_eligible'] = complete_mask(f, 10, CONFIG)
    c = extract_candidates(f, CONFIG['methods'], CONFIG)
    c = c[c.comparison_eligible]
    cfg = dict(CONFIG, baseline_repeats=2)
    for kind in ['conditional', 'unconditional']:
        control, log = random_controls(f, c, kind, cfg)
        assert len(control) == len(c)*2
        assert (log.requested_n == log.sampled_n).all()
        assert not control.duplicated(['method', 'side', 'replicate', 'signal_index']).any()
        again, _ = random_controls(f, c.sample(frac=1, random_state=4), kind, cfg)
        pd.testing.assert_frame_equal(control, again)


def test_walk_forward_purges_actual_label_end_and_embargo():
    left = int(pd.Timestamp('2024-07-01', tz='UTC').timestamp())
    frame = pd.DataFrame({'signal_time': [left-200000, left-200000, left, left+100],
                          'exit_time': [left-180001, left-179999, left+3000, 1767225601],
                          'net_atr': [1., 100., 2., 100.], 'net_pips': [1., 100., 2., 100.],
                          'week': ['2024-06-24']*4})
    wf = walk_forward(frame, CONFIG)
    assert wf.iloc[0]['n'] == 1
    assert wf.iloc[1]['n'] == 1
    assert wf.iloc[0].purged_or_embargoed_train_n == 1


def test_audit_reports_absent_months():
    result, _, coverage = audit(bars(100), 300, CONFIG)
    assert result['months_with_data'] == 1 and len(result['months_missing']) == 23
    assert len(coverage) == 24
