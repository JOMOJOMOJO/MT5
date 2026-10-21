"""Refine ambiguous H1 bars using recorded M1 OHLC, never invent ticks."""
import numpy as np
import pandas as pd

from .metrics import LOCK


def first_barrier(minutes, side, stop, target, spread):
    sign = 1 if side == 'LONG' else -1
    for row, adjustment in zip(minutes.itertuples(), spread):
        adj = adjustment if sign < 0 else 0.
        op, high, low = row.open+adj, row.high+adj, row.low+adj
        if sign*(op-stop) <= 0:
            return 'stop_first', int(row.time), 'minute_open'
        if sign*(op-target) >= 0:
            return 'target_first', int(row.time), 'minute_open'
        hit_stop = low <= stop if sign > 0 else high >= stop
        hit_target = high >= target if sign > 0 else low <= target
        if hit_stop and hit_target:
            return 'ambiguous_same_minute', int(row.time), 'minute_OHLC'
        if hit_stop or hit_target:
            return ('stop_first' if hit_stop else 'target_first'), int(row.time), 'minute_OHLC'
    return 'no_hit', None, 'unresolved'


def refine(trade, minutes, hours, point, pip, fallback_pips):
    """Use the whole original holding path; refuse missing or mismatched bars."""
    if (minutes.time >= LOCK).any() or (hours.time >= LOCK).any():
        raise ValueError('2026 prices forbidden')
    start, end = int(trade.entry_time), int(trade.exit_time_upper)
    sub = minutes.loc[minutes.time.ge(start) & minutes.time.lt(end)].copy()
    expected = np.arange(start, end, 60)
    complete = np.array_equal(sub.time.to_numpy(), expected)
    hour_frame = hours.loc[hours.time.ge(start) & hours.time.lt(end)].copy()
    match = complete and len(hour_frame) == (end-start)//3600
    if match:
        aggregate = sub.groupby(sub.time//3600*3600).agg(
            open=('open', 'first'), high=('high', 'max'), low=('low', 'min'), close=('close', 'last'))
        match = (np.array_equal(aggregate.index.to_numpy(), hour_frame.time.to_numpy()) and
                 np.allclose(aggregate.to_numpy(), hour_frame[['open', 'high', 'low', 'close']].to_numpy(),
                             atol=1e-10, rtol=0))
    finite = np.isfinite(sub[['open', 'high', 'low', 'close']].to_numpy()).all()
    valid_prices = (finite and (sub[['open', 'high', 'low', 'close']] > 0).all().all()
                    and (sub.high >= sub[['open', 'close']].max(axis=1)).all()
                    and (sub.low <= sub[['open', 'close']].min(axis=1)).all()
                    and (sub.high >= sub.low).all())
    base = dict(candidate_id=trade.candidate_id, side=trade.side,
                entry_time=start, ambiguous_hour_start=int(trade.exit_time_lower),
                ambiguous_hour_end=end, expected_m1=len(expected), actual_m1=len(sub),
                complete_m1_path=bool(complete), h1_bid_ohlc_match=bool(match),
                valid_m1_ohlc=bool(valid_prices), tick_sequence_verified=False,
                cashflow_recalculated=False)
    rows = []
    for mode in ['fixed_H1_spread_proxy', 'M1_spread_proxy']:
        row = dict(base, quote_model=mode)
        if not (complete and match and valid_prices):
            row.update(first='unresolved_data', first_minute=None, observation='unresolved')
        else:
            if mode == 'fixed_H1_spread_proxy':
                source = hour_frame.set_index('time').spread.reindex(sub.time//3600*3600).to_numpy()
            else:
                source = sub.spread.to_numpy()
            spread = np.where(np.isfinite(source) & (source > 0), source*point, fallback_pips*pip)
            first, time, observation = first_barrier(sub, trade.side, trade.stop_price, trade.target_price, spread)
            row.update(first=first, first_minute=time, observation=observation,
                       spread_fallback_minutes=int((~(np.isfinite(source) & (source > 0))).sum()),
                       first_hit_in_ambiguous_hour=bool(time is not None and time >= trade.exit_time_lower))
        rows.append(row)
    return rows
