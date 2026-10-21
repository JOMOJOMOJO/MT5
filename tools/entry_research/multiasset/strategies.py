"""Closed-bar features and pluggable candidates, never outcome-dependent."""
import numpy as np
import pandas as pd

from ..features import indicators
from ..signals import ichimoku_cloud, kijun_bounce, ema_cross
from .signals import donchian, bollinger, atr_breakout
from .data import stamp, LOCK

METHODS = {x.__name__.split('.')[-1]: x for x in
           [ichimoku_cloud, kijun_bounce, ema_cross, donchian, bollinger, atr_breakout]}


def build_features(bars, timeframe, symbol, spec, config, auxiliary=None):
    if stamp(config['end']) > LOCK or (bars.time >= LOCK).any():
        raise ValueError('holdout guard')
    step = config['timeframes'][timeframe]
    df = indicators(bars, config['indicators'])
    period = config['donchian_period']
    df['dc_high'] = df.high.shift().rolling(period).max()
    df['dc_low'] = df.low.shift().rolling(period).min()
    mean = df.close.rolling(config['bollinger_period']).mean()
    std = df.close.rolling(config['bollinger_period']).std(ddof=0)
    df['bb_high'] = mean + config['bollinger_std'] * std
    df['bb_low'] = mean - config['bollinger_std'] * std
    df['contracted_previous'] = df.relative_vol.shift() <= config['contraction_max']
    df['signal_index'] = np.arange(len(df))
    df['nominal_close_time'] = df.close_time
    df['signal_time'] = df.available_time
    df['symbol'], df['timeframe'] = symbol, timeframe
    times = df.time.to_numpy()
    idx = np.maximum(np.searchsorted(times, df.signal_time, side='left'), np.arange(len(df)) + 1)
    df['entry_index'] = idx
    df['entry_time'] = np.where(idx < len(df), times[np.minimum(idx, len(df)-1)], -1)
    df['entry_delay_seconds'] = df.entry_time - df.nominal_close_time
    dt = pd.to_datetime(df.entry_time, unit='s', utc=True)
    df['year'], df['hour'], df['weekday'] = dt.dt.year, dt.dt.hour, dt.dt.dayofweek
    df['week'] = (dt.dt.normalize()-pd.to_timedelta(dt.dt.dayofweek, unit='D')).dt.strftime('%Y-%m-%d')
    df['month'] = dt.dt.strftime('%Y-%m')
    df['session'] = 'unknown_clock_mapping'
    df['vol_bucket'] = df.vol_bucket.fillna('unknown')
    df['signal_eligible'] = ((df.time >= stamp(config['start'])) & (df.signal_time < stamp(config['end'])) & (df.atr14 > 0))
    df['decision_eligible'] = df.signal_eligible & (df.entry_time >= df.signal_time) & (df.entry_time < stamp(config['end'])) & (df.entry_delay_seconds <= step)
    for tf in ['M15', 'H1', 'H4']:
        key = tf.lower() + '_trend'
        df[key] = 'unknown'
        if auxiliary is None or tf not in auxiliary or config['timeframes'][tf] <= step:
            continue
        other = auxiliary[tf]
        if (other.time >= LOCK).any():
            raise ValueError('auxiliary holdout guard')
        right = indicators(other, config['indicators'])[['available_time', 'close_time', 'trend']]
        right = right.sort_values(['available_time', 'close_time']).drop_duplicates('available_time', keep='last')
        right = right.rename(columns={x: tf.lower() + '_' + x for x in right})
        df = pd.merge_asof(df.drop(columns=key).sort_values('signal_time'), right,
                           left_on='signal_time', right_on=tf.lower()+'_available_time', direction='backward')
        stale = df.signal_time - df[tf.lower()+'_close_time'] > 2*config['timeframes'][tf]
        df.loc[stale, key] = 'unknown'
        df[key] = df[key].fillna('unknown')
    return df.sort_values('signal_index').reset_index(drop=True)


def complete_mask(features, horizon, config):
    """Observation mask only; never used by extract_candidates or execution."""
    entry = features.entry_index.to_numpy()
    last = entry + horizon - 1
    times = features.time.to_numpy()
    safe = np.clip(last, 0, len(features)-1)
    step = config['timeframes'][features.timeframe.iloc[0]]
    jumps = np.r_[0, np.cumsum(np.diff(times) != step)]
    continuous = jumps[safe] == jumps[np.clip(entry, 0, len(features)-1)]
    return (features.decision_eligible & (last < len(features))
            & continuous
            & (times[safe] == features.entry_time + (horizon-1)*step)
            & (times[safe] + step <= stamp(config['end'])))


def extract_candidates(features, methods, config):
    rows = []
    for method in methods:
        for side, mask in METHODS[method].detect(features).items():
            selected = features[features.signal_eligible & mask.fillna(False)].copy()
            selected['method'], selected['side'] = method, side
            selected['candidate_id'] = [f'{s}_{tf}_{method}_{side}_{int(t)}' for s, tf, t in zip(selected.symbol, selected.timeframe, selected.signal_time)]
            selected['consecutive_same_direction'] = selected.signal_index.diff().eq(1)
            rows.append(selected)
    return pd.concat(rows, ignore_index=True)
