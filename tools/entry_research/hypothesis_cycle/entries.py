"""Causal closed-bar entry changes for the 2026-10-19 fixed trial cycle.

The thresholds are declared trial values, not estimated optima. Entry feasibility
and expiry belong to the frozen execution engine; unsuccessful candidates remain
in the output population. No outcome columns participate in either detector.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

from ..multiasset.data import LOCK


def wilder_rsi(close: pd.Series, period: int = 2) -> pd.Series:
    """Wilder RSI, seeded with the mean of the first ``period`` price changes.

    The first value is at position ``period`` (needs period + 1 prices). Both
    smoothed changes zero maps to 50; only gains maps to 100; only losses to 0.
    Invalid prices are rejected rather than interpolated across missing data.
    """
    if isinstance(period, bool) or not isinstance(period, (int, np.integer)) or period < 1:
        raise ValueError('RSI period must be a positive integer')
    values = close.to_numpy(dtype=float)
    if not np.isfinite(values).all():
        raise ValueError('RSI requires finite observed closes')
    result = np.full(len(values), np.nan)
    if len(values) <= period:
        return pd.Series(result, index=close.index, name='rsi')
    changes = np.diff(values)
    gains, losses = np.maximum(changes, 0), np.maximum(-changes, 0)
    gain, loss = gains[:period].mean(), losses[:period].mean()

    def value():
        if gain == 0 and loss == 0:
            return 50.0
        if loss == 0:
            return 100.0
        return 100.0 * gain / (gain + loss)

    result[period] = value()
    for i in range(period + 1, len(values)):
        gain = (gain * (period - 1) + gains[i - 1]) / period
        loss = (loss * (period - 1) + losses[i - 1]) / period
        result[i] = value()
    return pd.Series(result, index=close.index, name='rsi')


def shallow_filter(candidates: pd.DataFrame, threshold: float = .25) -> pd.Series:
    """Retain breakout candidates whose signal close clears the boundary.

    Uses existing causal signal-row boundaries: previous-20-bar Donchian high/
    low for Donchian and ATR entries, displayed cloud edge for Ichimoku. Missing
    boundaries or nonpositive ATR fail the filter. Unknown methods raise rather
    than silently changing another strategy. The input frame is never modified.
    """
    if not np.isfinite(threshold) or threshold < 0:
        raise ValueError('Breakout threshold must be finite and nonnegative')
    supported = ['donchian', 'atr_breakout', 'ichimoku_cloud']
    if not candidates.method.isin(supported).all():
        raise ValueError('Shallow filter accepts breakout methods only')
    if not candidates.side.isin(['LONG', 'SHORT']).all():
        raise ValueError('Unknown candidate side')
    sign = np.where(candidates.side.eq('LONG'), 1., -1.)
    boundary = np.where(
        candidates.method.eq('ichimoku_cloud'),
        np.where(sign > 0, candidates.cloud_upper, candidates.cloud_lower),
        np.where(sign > 0, candidates.dc_high, candidates.dc_low))
    atr = candidates.atr14.to_numpy(dtype=float)
    close = candidates.close.to_numpy(dtype=float)
    valid = np.isfinite(atr) & (atr > 0) & np.isfinite(close) & np.isfinite(boundary)
    margin = np.full(len(candidates), np.nan)
    np.divide(sign * (close - boundary), atr, out=margin, where=valid)
    return pd.Series(valid & (margin >= threshold), index=candidates.index,
                     name='shallow_filter_pass')


def rsi_candidates(features: pd.DataFrame) -> pd.DataFrame:
    """RSI2 threshold recovery in the EMA200 direction, on one ordered series.

    LONG: close > EMA200 and previous RSI2 <= 5 < current RSI2.
    SHORT: close < EMA200 and previous RSI2 >= 95 > current RSI2.
    EMA uses adjust=False with 200 observed closes before its first value.
    Execution columns are inherited unchanged from frozen build_features.
    """
    df = features.copy()
    if df.symbol.nunique(dropna=False) > 1 or df.timeframe.nunique(dropna=False) > 1:
        raise ValueError('RSI detector requires one symbol and timeframe')
    if not df.signal_index.is_monotonic_increasing or df.signal_index.duplicated().any():
        raise ValueError('RSI detector requires ordered unique signal rows')
    if (df.time >= LOCK).any() or (df.signal_time >= LOCK).any():
        raise ValueError('2026 holdout forbidden')
    if (df.available_time > df.signal_time).any() or (df.close_time > df.signal_time).any():
        raise ValueError('Signal cannot precede closed-bar availability')
    df['rsi2'] = wilder_rsi(df.close, period=2)
    df['ema200'] = df.close.ewm(span=200, adjust=False, min_periods=200).mean()
    previous = df.rsi2.shift()
    masks = {
        'LONG': df.close.gt(df.ema200) & previous.le(5) & df.rsi2.gt(5),
        'SHORT': df.close.lt(df.ema200) & previous.ge(95) & df.rsi2.lt(95),
    }
    rows = []
    for side, mask in masks.items():
        selected = df[df.signal_eligible.fillna(False) & mask.fillna(False)].copy()
        selected['method'], selected['side'] = 'rsi2_pullback', side
        selected['candidate_id'] = [
            f'{symbol}_{tf}_rsi2_pullback_{side}_{int(time)}'
            for symbol, tf, time in zip(selected.symbol, selected.timeframe, selected.signal_time)]
        selected['consecutive_same_direction'] = selected.signal_index.diff().eq(1)
        rows.append(selected)
    return pd.concat(rows, ignore_index=True)
