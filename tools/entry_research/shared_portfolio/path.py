"""Single-position paths from the frozen account execution model.

This adapter does not decide portfolio admission. It sizes one candidate from
the equity supplied at its entry time and returns its future marks for a caller
to consume chronologically. Looking at a returned exit before its timestamp
would introduce look-ahead into portfolio admission.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

from tools.entry_research.account_replay.execution import (
    HOLDOUT_START, SCENARIOS, simulate,
)


def _integer_index(value):
    """Return a finite integer index, otherwise None without inventing one."""
    try:
        return int(value) if np.isfinite(value) and int(value) == value else None
    except (TypeError, ValueError, OverflowError):
        return None


def trade_path(bars: pd.DataFrame, candidate: dict, spec: dict,
               execution_config: dict, initial_equity: float,
               risk_fraction: float = .00025,
               scenario: str = 'stop_first_lower') -> dict:
    """Produce one candidate's price, cash-flow, and liquidation-equity path.

    ``initial_equity`` is the shared account's currently observable equity, not
    a fresh independent capital allocation. The frozen engine's sizing and
    minimum-lot rules are unchanged. ``marks`` retain its absolute columns and
    add ``pnl_close_usd``, ``pnl_adverse_usd``, ``pnl_favorable_usd`` and
    ``realized_pnl_usd`` relative to that sizing reference. Index columns are
    restored to positions in the caller's original bars; input objects are not
    mutated. Skipped candidates have ``trade=None`` and no marks.

    Censoring is returned intact. A caller must stop or quarantine the shared
    account at the first unresolved position, never treat it as a closed trade.
    All supplied timestamps are checked before slicing, so a 2026 row cannot be
    hidden outside the compact execution window.
    """
    if scenario not in SCENARIOS:
        raise ValueError(f'Unknown scenario: {scenario}')
    if 'time' not in bars:
        raise ValueError('Missing bar time column')
    if (bars.time.isna().any() or bars.time.duplicated().any()
            or not bars.time.is_monotonic_increasing):
        raise ValueError('Bar times must be non-null, unique and increasing')
    if (bars.time >= HOLDOUT_START).any():
        raise ValueError('2026 holdout prices are forbidden')
    hold = _integer_index(execution_config.get('max_hold_bars', 10))
    if hold is None or hold < 1:
        raise ValueError('Holding period must be a positive integer count')

    event = dict(candidate)
    entry = _integer_index(event.get('entry_index'))
    signal = _integer_index(event.get('signal_index'))
    if entry is not None and 0 <= entry < len(bars):
        # Include one predecessor to the signal; annotations are still rebuilt
        # by the frozen engine rather than trusting caller-supplied gap labels.
        anchor = signal if signal is not None and 0 <= signal < entry else entry
        first = max(anchor - 1, 0)
        stop = min(len(bars), entry + hold)
    else:
        # Keep invalid entry indices invalid, allowing the frozen engine to
        # produce its usual skipped_missing_entry event.
        first, stop = 0, min(len(bars), hold + 2)
    compact = bars.iloc[first:stop].reset_index(drop=True).copy()
    if entry is not None:
        event['entry_index'] = entry - first
    if signal is not None:
        event['signal_index'] = signal - first
    config = dict(execution_config, initial_equity=initial_equity,
                  risk_fraction=risk_fraction)
    result = simulate(compact, pd.DataFrame([event]), spec, config)

    trades = result['trades'].loc[result['trades'].scenario.eq(scenario)].copy()
    events = result['events'].loc[result['events'].scenario.eq(scenario)].copy()
    marks = result['equity'].loc[
        result['equity'].scenario.eq(scenario)
        & result['equity'].phase.isin(
            ['entry_liquidation', 'exit_at_open', 'bar_envelope'])
    ].copy()
    for frame, columns in ((trades, ['entry_index', 'exit_index']),
                           (events, ['entry_index']), (marks, ['bar_index'])):
        for column in columns:
            if column in frame:
                frame[column] = frame[column] + first
    for source, target in (
        ('equity_close_usd', 'pnl_close_usd'),
        ('equity_adverse_usd', 'pnl_adverse_usd'),
        ('equity_favorable_usd', 'pnl_favorable_usd'),
        ('balance_usd', 'realized_pnl_usd'),
    ):
        marks[target] = marks[source] - initial_equity
    return {
        'trade': trades.iloc[0].to_dict() if len(trades) else None,
        'events': events.to_dict('records'),
        'marks': marks.reset_index(drop=True),
    }
