import json
from pathlib import Path
import numpy as np
import pandas as pd
from pandas.testing import assert_frame_equal
from tools.entry_research.features import indicators, build_features, wilder_atr
from tools.entry_research.signals import REGISTRY, extract
from tools.entry_research.charts import snapshot_frames

CONFIG = json.loads((Path(__file__).parents[1] / 'configs/initial.json').read_text())

def bars(n=1300, step=300, start=1704067200):
    rng = np.random.default_rng(23)
    close = 140 + np.cumsum(rng.normal(0, .06, n))
    op = np.r_[close[0], close[:-1]]
    time = start + np.arange(n)*step
    return pd.DataFrame({'time':time,'close_time':time+step,'available_time':time+step,
        'source_available_at':time+step,'open':op,'high':np.maximum(op,close)+.03,
        'low':np.minimum(op,close)-.03,'close':close,'spread':15})

def test_prefix_invariance_indicators_and_all_signals():
    original = bars()
    a = indicators(original, CONFIG['indicators'])
    altered = original.copy()
    altered.loc[700:, ['open','high','low','close']] += 30
    b = indicators(altered, CONFIG['indicators'])
    assert_frame_equal(a.iloc[:700], b.iloc[:700])
    for detect in REGISTRY.values():
        for side in ('LONG','SHORT'):
            pd.testing.assert_series_equal(detect(a)[side].iloc[:700], detect(b)[side].iloc[:700])

def test_cloud_is_positive_shift_and_atr_seed():
    raw = bars(100)
    f = indicators(raw, CONFIG['indicators'])
    assert np.isnan(f.cloud_b.iloc[76])
    expected = (raw.high.iloc[:52].max()+raw.low.iloc[:52].min())/2
    assert f.cloud_b.iloc[77] == expected
    tr = np.maximum(raw.high-raw.low, np.maximum((raw.high-raw.close.shift()).abs().fillna(0),
                                                (raw.low-raw.close.shift()).abs().fillna(0)))
    atr = wilder_atr(raw)
    assert np.isclose(atr.iloc[13], tr.iloc[:14].mean())
    assert np.isclose(atr.iloc[14], (atr.iloc[13]*13+tr.iloc[14])/14)

def test_upper_timeframe_availability_and_late_entry():
    data = {tf: bars(1300, step) for tf,step in CONFIG['timeframes'].items()}
    i = 800
    data['M5'].loc[i, 'available_time'] += 2
    f, enriched = build_features(data, CONFIG)
    row = f.iloc[i]
    assert row.entry_time >= row.signal_time
    assert row.entry_index == i + 2
    assert row.h1_available_time <= row.signal_time
    assert row.h1_close_time <= row.signal_time
    assert row.m15_available_time <= row.signal_time
    snap = snapshot_frames(enriched, int(row.signal_time))
    assert all((v.close_time <= row.signal_time).all() and (v.available_time <= row.signal_time).all() for v in snap.values())
    assert not (snap['M5'].time == row.entry_time).any()

def test_known_signal_directions_and_frozen_kijun():
    df = pd.DataFrame({'close':[9.,11.,9.], 'open':[9.,9.,11.], 'low':[8.,9.,8.], 'high':[10.,12.,12.],
        'cloud_upper':[10.,10.,10.], 'cloud_lower':[10.,10.,10.], 'ema_fast':[9.,11.,9.],
        'ema_slow':[10.,10.,10.], 'kijun':[8.,10.,15.]})
    assert REGISTRY['ichimoku_cloud'](df)['LONG'].tolist() == [False,True,False]
    assert REGISTRY['ema_cross'](df)['SHORT'].tolist() == [False,False,True]
    bounce = pd.DataFrame({'close':[11.,12.], 'open':[11.,11.], 'low':[10.5,9.], 'high':[12.,13.], 'kijun':[10.,20.]})
    assert REGISTRY['kijun_bounce'](bounce)['LONG'].iloc[-1]

def test_gap_mask_and_holdout_events():
    data = {tf: bars(1300, step) for tf,step in CONFIG['timeframes'].items()}
    for col in ['time','close_time','available_time','source_available_at']:
        data['M5'].loc[850:, col] += 300
    f,_ = build_features(data, CONFIG)
    assert not f.loc[830,'eligible']
    assert f.loc[799,'eligible']
    events = extract(f, CONFIG['methods'])
    assert (events.loc[events.decision_eligible, 'entry_time'] >= events.loc[events.decision_eligible, 'signal_time']).all()
    assert (events.signal_time < CONFIG['end_exclusive']).all()

def test_candidates_exist_even_when_execution_window_unavailable():
    data = {tf: bars(1300, step) for tf,step in CONFIG['timeframes'].items()}
    f,_ = build_features(data, CONFIG)
    events = extract(f, CONFIG['methods'])
    f['decision_eligible'] = False
    f['eligible'] = False
    f['entry_time'] = -1
    retained = extract(f, CONFIG['methods'])
    assert retained.candidate_id.tolist() == events.candidate_id.tolist()
