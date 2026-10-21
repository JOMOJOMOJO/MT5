"""Only past/closed data here. Outcome computation lives in evaluation.py."""
from __future__ import annotations

import numpy as np
import pandas as pd


def wilder_atr(bars: pd.DataFrame, period: int = 14) -> pd.Series:
    prev = bars.close.shift()
    tr = pd.concat([bars.high - bars.low, (bars.high - prev).abs(),
                    (bars.low - prev).abs()], axis=1).max(axis=1).to_numpy()
    out = np.full(len(tr), np.nan)
    if len(tr) >= period:
        out[period - 1] = np.mean(tr[:period])
        for i in range(period, len(tr)):
            out[i] = (out[i-1] * (period-1) + tr[i]) / period
    return pd.Series(out, index=bars.index)


def indicators(bars: pd.DataFrame, params: dict) -> pd.DataFrame:
    df = bars.copy().reset_index(drop=True)
    def mid(n):
        return (df.high.rolling(n).max() + df.low.rolling(n).min()) / 2
    df['tenkan'] = mid(params['tenkan'])
    df['kijun'] = mid(params['kijun'])
    df['cloud_a'] = ((df.tenkan + df.kijun) / 2).shift(params['displacement'])
    df['cloud_b'] = mid(params['senkou_b']).shift(params['displacement'])
    df['cloud_upper'] = df[['cloud_a', 'cloud_b']].max(axis=1, skipna=False)
    df['cloud_lower'] = df[['cloud_a', 'cloud_b']].min(axis=1, skipna=False)
    for key in ('fast', 'slow'):
        n = params['ema_' + key]
        df['ema_' + key] = df.close.ewm(span=n, adjust=False, min_periods=n).mean()
    df['atr14'] = wilder_atr(df, params['atr'])
    df['relative_vol'] = df.atr14 / df.atr14.shift().rolling(params['vol_lookback']).median()
    df['vol_bucket'] = pd.cut(df.relative_vol, [-np.inf, .8, 1.2, np.inf],
                              labels=['low', 'normal', 'high']).astype('string')
    df['recent_move_atr'] = (df.close - df.close.shift(12)) / df.atr14
    hi, lo = df.high.shift().rolling(20).max(), df.low.shift().rolling(20).min()
    df['range_position'] = (df.close - lo) / (hi - lo).replace(0, np.nan)
    df['cloud_position'] = np.select([df.close > df.cloud_upper, df.close < df.cloud_lower],
                                     ['above', 'below'], default='inside')
    df.loc[df.cloud_upper.isna(), 'cloud_position'] = 'unknown'
    df['trend'] = np.select([df.ema_fast > df.ema_slow, df.ema_fast < df.ema_slow],
                            ['up', 'down'], default='flat')
    df.loc[df.ema_slow.isna(), 'trend'] = 'unknown'
    return df


def build_features(bars: dict[str, pd.DataFrame], config: dict) -> tuple[pd.DataFrame, dict]:
    enriched = {tf: indicators(b, config['indicators']) for tf, b in bars.items()}
    df = enriched[config['entry_timeframe']].copy()
    df['signal_index'] = np.arange(len(df))
    df['nominal_close_time'] = df.close_time
    # Collector availability is retained: a late first tick cannot be filled at a past open.
    df['signal_time'] = df.available_time
    t = pd.to_datetime(df.signal_time, unit='s')  # source clock, NOT an inferred UTC conversion
    df['year'], df['hour'], df['weekday'] = t.dt.year, t.dt.hour, t.dt.dayofweek
    df['signal_hour'], df['signal_weekday'] = df.hour, df.weekday
    df['week'] = (t.dt.normalize() - pd.to_timedelta(t.dt.dayofweek, unit='D')).dt.strftime('%Y-%m-%d')
    df['month'] = t.dt.strftime('%Y-%m')
    df['symbol'] = config['symbol']
    df['session'] = 'unknown_server_offset'
    df['clock_basis'] = config['clock_basis']
    if config['clock_basis'] == 'utc':
        utc = pd.to_datetime(df.signal_time, unit='s', utc=True)
        labels = []
        for zone, name in [('Asia/Tokyo', 'tokyo'), ('Europe/London', 'london'), ('America/New_York', 'new_york')]:
            hr = utc.dt.tz_convert(zone).dt.hour
            active = hr.between(9 if name == 'tokyo' else 8, 16)
            labels.append(np.where(active, name, ''))
        df['session'] = ['+'.join(filter(None, x)) or 'off_session' for x in zip(*labels)]
    for tf in ('M15', 'H1'):
        right = enriched[tf][['available_time', 'close_time', 'trend']].copy()
        right = right.sort_values(['available_time', 'close_time']).drop_duplicates('available_time', keep='last')
        right = right.rename(columns={c: tf.lower() + '_' + c for c in right})
        df = pd.merge_asof(df.sort_values('signal_time'), right,
                           left_on='signal_time', right_on=tf.lower() + '_available_time', direction='backward')
        df[tf.lower() + '_age_seconds'] = df.signal_time - df[tf.lower() + '_close_time']
        df[tf.lower() + '_stale'] = df[tf.lower() + '_age_seconds'] > 2 * config['timeframes'][tf]
    df = df.sort_values('signal_index').reset_index(drop=True)
    times = df.time.to_numpy()
    entry = np.searchsorted(times, df.signal_time.to_numpy(), side='left')
    entry = np.maximum(entry, df.signal_index.to_numpy() + 1)
    df['entry_index'] = entry
    safe = np.minimum(entry, len(df)-1)
    df['entry_time'] = np.where(entry < len(df), times[safe], -1)
    df['entry_delay_seconds'] = df.entry_time - df.nominal_close_time
    # Match controls by executable proxy time; delays can cross an hour/day boundary.
    entry_clock = pd.to_datetime(df.entry_time, unit='s')
    df['year'], df['hour'], df['weekday'] = entry_clock.dt.year, entry_clock.dt.hour, entry_clock.dt.dayofweek
    df['week'] = (entry_clock.dt.normalize() - pd.to_timedelta(entry_clock.dt.dayofweek, unit='D')).dt.strftime('%Y-%m-%d')
    df['month'] = entry_clock.dt.strftime('%Y-%m')
    start = int(pd.Timestamp(config['start']).timestamp())
    end = int(pd.Timestamp(config['end']).timestamp())
    df['signal_eligible'] = ((df.time >= start) & (df.signal_time >= start) & (df.signal_time < end)
        & df.vol_bucket.notna() & (df.atr14 > 0)
        & df.cloud_upper.notna() & df.ema_slow.notna()
        & df.h1_trend.isin(['up','down','flat']) & df.m15_trend.isin(['up','down','flat']))
    df['decision_eligible'] = (df.signal_eligible & (df.entry_time >= df.signal_time) & (df.entry_time < end)
        & (df.entry_delay_seconds <= config['max_entry_delay_seconds']))
    # Completeness is an evaluation mask, never a trading feature or strategy filter.
    h = max(config['horizons'])
    last = entry + h - 1
    safe_last = np.minimum(last, len(df)-1)
    contiguous = (times[safe_last] - times[safe]) == (h-1) * config['timeframe_seconds']
    df['eligible'] = (df.decision_eligible & (last < len(df)) & contiguous
                      & (times[safe_last] + config['timeframe_seconds'] <= end))
    return df, enriched
