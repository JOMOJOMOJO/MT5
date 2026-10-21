"""Explicit source-clock closure policy; no bar creation or price imputation."""
import numpy as np
import pandas as pd

WEEKEND_POLICY = {'kind': 'source_clock_weekend_proxy', 'version': 1}
LOCK = 1767225600


def classify_interval(previous_open, next_open, step, policy=None):
    start, end = int(previous_open)+step, int(next_open)
    if end == start:
        return 'contiguous', 0, 'adjacent_bars'
    if end < start:
        raise ValueError('overlapping or unordered bars')
    missing = end-start
    if policy is not None and policy != WEEKEND_POLICY:
        raise ValueError('unsupported calendar policy')
    first, last = pd.Timestamp(start, unit='s'), pd.Timestamp(end, unit='s')
    if (policy == WEEKEND_POLICY and missing == 48*3600
            and first.weekday() == 5 and first == first.normalize()
            and last.weekday() == 0 and last == last.normalize()):
        return 'scheduled_closure', missing, 'exact_source_Sat00_Mon00_empirical_proxy_not_historical_broker_verified'
    holiday = ((first.month, first.day) in [(1, 1), (12, 25)]
               and first == first.normalize() and missing == 86400)
    return 'unknown_gap', missing, 'holiday_date_but_historical_session_unverified' if holiday else 'unexplained_missing_quote_interval'


def annotate_bars(bars, step, policy=None):
    if not isinstance(step, int) or step <= 0:
        raise ValueError('positive integer timeframe required')
    if bars.time.isna().any() or bars.time.duplicated().any() or not bars.time.is_monotonic_increasing:
        raise ValueError('ordered unique bar times required')
    if (bars.time >= LOCK).any():
        raise ValueError('2026 holdout forbidden')
    b = bars.reset_index(drop=True).copy()
    b['gap_before_status'] = 'contiguous'
    b['gap_before_seconds'] = 0
    b['gap_evidence'] = 'adjacent_bars'
    times = b.time.to_numpy()
    for idx in np.flatnonzero(np.diff(times) != step)+1:
        state, seconds, evidence = classify_interval(times[idx-1], times[idx], step, policy)
        b.loc[idx, ['gap_before_status','gap_before_seconds','gap_evidence']] = state, seconds, evidence
    return b
