"""Causal event evaluation, independent of candidate extraction.

Prices are bid OHLC proxies. A horizon of one is the entry bar's close,
not the following bar. ATR is frozen at the signal. Excursions and barrier
levels are gross bid-price quantities; net returns use the stated cost model.
Incomplete windows have no imputed return or barrier result.
"""
from __future__ import annotations

from typing import Any

import numpy as np
import pandas as pd


IDENTITY = ["candidate_id", "method", "side", "signal_time", "entry_time"]
OUTCOME_COLUMNS = IDENTITY + [
    "horizon", "complete", "censor_reason", "entry_delay_seconds", "exit_time", "entry_price",
    "exit_price", "atr14", "gross_pips", "net_pips", "gross_atr", "net_atr",
    "mfe_pips", "mae_pips", "mfe_atr", "mae_atr", "spread_cost_pips",
    "commission_cost_pips", "slippage_cost_pips", "total_cost_pips", "cost_source",
]
TOUCH_COLUMNS = IDENTITY + [
    "horizon", "move", "level", "reached", "first_hit_bar", "hit_time_lower",
    "hit_time_upper", "censored", "censor_reason",
]
BARRIER_COLUMNS = IDENTITY + [
    "horizon", "tp_atr", "sl_atr", "outcome", "tp_first_hit_bar",
    "sl_first_hit_bar", "first_hit_bar", "hit_time_lower", "hit_time_upper",
    "censored", "censor_reason",
]


def _positive_config(config: dict, name: str, default: float) -> float:
    value = float(config.get(name, default))
    if not np.isfinite(value) or value <= 0:
        raise ValueError(f"{name} must be finite and positive")
    return value


def _costs(bars: pd.DataFrame, entries: np.ndarray, exits: np.ndarray,
           sides: np.ndarray, config: dict) -> tuple[np.ndarray, float, float, np.ndarray]:
    cost = config.get("cost", {})
    mode = cost.get("mode", "assumed")
    if mode not in {"assumed", "bar_proxy"}:
        raise ValueError("cost.mode must be assumed or bar_proxy")
    spread = float(cost.get("spread_pips", 1.5))
    commission = float(cost.get("commission_pips_roundtrip", 0.0))
    slippage = 2 * float(cost.get("slippage_pips_per_side", 0.2))
    if any(not np.isfinite(x) or x < 0 for x in (spread, commission, slippage)):
        raise ValueError("assumed spread, commission and slippage must be nonnegative")
    result = np.full(len(entries), spread)
    source = np.full(len(entries), "assumed", dtype=object)
    if mode == "bar_proxy":
        source[:] = "assumed_fallback_missing_or_nonpositive_bar_spread"
        if "spread" in bars:
            values = pd.to_numeric(bars["spread"], errors="coerce").to_numpy(float)
            # Bid bars: a long pays ask at entry; a short buys ask at exit.
            idx = np.where(sides == "LONG", entries, exits)
            safe = np.clip(idx, 0, max(len(bars) - 1, 0))
            observed = values[safe] if len(values) else np.full(len(idx), np.nan)
            good = (idx >= 0) & (idx < len(values)) & np.isfinite(observed) & (observed > 0)
            result[good] = observed[good] * _positive_config(config, "point", 0.001) / _positive_config(config, "pip_size", 0.01)
            source[good] = "historical_bar_spread_proxy_plus_assumed_commission_slippage"
    return result, commission, slippage, source


def evaluate(bars: pd.DataFrame, candidates: pd.DataFrame, config: dict
             ) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Return per-horizon outcomes, individual touches and TP/SL pair ordering.

    Time columns are seconds in the explicitly documented source clock. A
    completed h-bar window must have contiguous bars, start after the signal
    was available and finish by end_exclusive. Entry delay from nominal close
    is recorded, not silently treated as a fill at that close. first_hit_bar is
    one-based from entry. Intrabar time is an interval; a gap-open touch has
    identical lower/upper timestamps. Same-bar TP and SL remain ambiguous
    unless that bar's open already crosses exactly one boundary.
    """
    horizons = tuple(int(h) for h in config.get("horizons", [1, 3, 5, 10, 20, 50]))
    levels = tuple(float(x) for x in config.get("levels", [.25, .5, .75, 1., 1.5]))
    if not horizons or any(h < 1 for h in horizons) or len(set(horizons)) != len(horizons):
        raise ValueError("horizons must be distinct positive integers")
    if not levels or any(not np.isfinite(x) or x <= 0 for x in levels) or len(set(levels)) != len(levels):
        raise ValueError("levels must be distinct finite positive values")
    pip = _positive_config(config, "pip_size", .01)
    step = int(_positive_config(config, "timeframe_seconds", 300))
    end = config.get("end_exclusive", np.iinfo(np.int64).max)
    emit_paths = bool(config.get("emit_paths", True))
    if candidates.empty:
        return (pd.DataFrame(columns=OUTCOME_COLUMNS), pd.DataFrame(columns=TOUCH_COLUMNS),
                pd.DataFrame(columns=BARRIER_COLUMNS))
    required = set(IDENTITY + ["signal_index", "entry_index", "atr14", "nominal_close_time"])
    if required - set(candidates.columns):
        raise ValueError(f"Missing candidate columns: {sorted(required - set(candidates.columns))}")
    if set(candidates["side"]) - {"LONG", "SHORT"}:
        raise ValueError("side must be LONG or SHORT")
    if candidates["candidate_id"].duplicated().any():
        raise ValueError("candidate_id must be unique")
    if set(["time", "open", "high", "low", "close"]) - set(bars):
        raise ValueError("bars require time/open/high/low/close")
    bt = bars["time"].to_numpy(np.int64)
    if len(bt) > 1 and np.any(np.diff(bt) <= 0):
        raise ValueError("bars must have unique strictly increasing times")
    n, length = len(candidates), len(bars)
    entries = candidates["entry_index"].to_numpy(np.int64)
    atr = candidates["atr14"].to_numpy(float)
    sides = candidates["side"].to_numpy()
    sign = np.where(sides == "LONG", 1., -1.)
    identity = {key: candidates[key].to_numpy() for key in IDENTITY}
    valid_entry = (entries >= 0) & (entries < length)
    safe_entries = np.clip(entries, 0, max(length - 1, 0))
    entry_price = bars["open"].to_numpy(float)[safe_entries] if length else np.full(n, np.nan)
    max_h = max(horizons)
    indices = entries[:, None] + np.arange(max_h)[None, :]
    present = (indices >= 0) & (indices < length)
    safe_indices = np.clip(indices, 0, max(length - 1, 0))
    arrays = {}
    for name in ("time", "open", "high", "low", "close"):
        source = bars[name].to_numpy(float)
        arrays[name] = np.where(present, source[safe_indices], np.nan) if length else np.full(indices.shape, np.nan)
    expected_times = identity["entry_time"][:, None] + np.arange(max_h)[None, :] * step
    contiguous = np.isfinite(arrays["time"]) & (arrays["time"] == expected_times)
    finite = np.logical_and.reduce([np.isfinite(arrays[x]) for x in ("open", "high", "low", "close")])
    geometry = ((arrays["high"] >= np.maximum(arrays["open"], arrays["close"])) &
                (arrays["low"] <= np.minimum(arrays["open"], arrays["close"])) &
                (arrays["high"] >= arrays["low"]))
    nominal = candidates["nominal_close_time"].to_numpy(np.int64)
    base_reason = np.full(n, "", dtype=object)
    base_reason[~np.isfinite(atr) | (atr <= 0)] = "invalid_atr"
    base_reason[(identity["entry_time"] - nominal) > config.get("max_entry_delay_seconds", np.inf)] = "entry_delay_exceeded"
    base_reason[entries <= candidates["signal_index"].to_numpy(np.int64)] = "entry_not_after_signal_bar"
    base_reason[identity["signal_time"] > identity["entry_time"]] = "entry_before_signal_available"
    base_reason[~valid_entry] = "entry_unavailable"
    favorable = np.where(sign[:, None] > 0, arrays["high"] - entry_price[:, None], entry_price[:, None] - arrays["low"])
    adverse = np.where(sign[:, None] > 0, entry_price[:, None] - arrays["low"], arrays["high"] - entry_price[:, None])
    open_move = sign[:, None] * (arrays["open"] - entry_price[:, None])
    # Precompute all first passage indices once, for every requested horizon.
    never = max_h + 1
    hit_f: dict[float, np.ndarray] = {}
    hit_a: dict[float, np.ndarray] = {}
    bar_numbers = np.arange(1, max_h + 1)[None, :]
    for level in levels if emit_paths else ():
        target = level * atr[:, None]
        hit_f[level] = np.min(np.where(favorable >= target, bar_numbers, never), axis=1)
        hit_a[level] = np.min(np.where(adverse >= target, bar_numbers, never), axis=1)
    out_frames, touch_frames, barrier_frames = [], [], []
    row_numbers = np.arange(n)

    def hit_details(first: np.ndarray, reached: np.ndarray, level: float, direction: int
                    ) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
        hit_idx = np.clip(first - 1, 0, max_h - 1)
        at_open = direction * open_move[row_numbers, hit_idx] >= level * atr
        lower = np.where(reached, arrays["time"][row_numbers, hit_idx], np.nan)
        upper = np.where(reached, lower + np.where(at_open, 0, step), np.nan)
        return lower, upper, at_open

    for h in horizons:
        reason = base_reason.copy()
        for mask, label in [
            (~present[:, :h].all(axis=1), "insufficient_future_bars"),
            (~contiguous[:, :h].all(axis=1), "time_gap"),
            (~finite[:, :h].all(axis=1) | ~geometry[:, :h].all(axis=1), "invalid_ohlc"),
            (arrays["time"][:, h - 1] + step > end, "development_boundary"),
        ]:
            reason[(reason == "") & mask] = label
        complete = reason == ""
        exit_price = arrays["close"][:, h - 1]
        gross = sign * (exit_price - entry_price)
        spread, commission, slip, cost_source = _costs(bars, entries, entries + h - 1, sides, config)
        total_cost = spread + commission + slip
        mfe = np.max(favorable[:, :h], axis=1)
        mae = np.max(adverse[:, :h], axis=1)
        clean = lambda x: np.where(complete, x, np.nan)
        safe_atr = np.where(atr > 0, atr, np.nan)
        out_frames.append(pd.DataFrame({
            **identity, "horizon": h, "complete": complete, "censor_reason": reason,
            "entry_delay_seconds": identity["entry_time"] - nominal,
            "exit_time": clean(arrays["time"][:, h - 1] + step),
            "entry_price": np.where(valid_entry, entry_price, np.nan),
            "exit_price": clean(exit_price), "atr14": atr,
            "gross_pips": clean(gross / pip), "net_pips": clean(gross / pip - total_cost),
            "gross_atr": clean(gross / safe_atr),
            "net_atr": clean((gross - total_cost * pip) / safe_atr),
            "mfe_pips": clean(mfe / pip), "mae_pips": clean(mae / pip),
            "mfe_atr": clean(mfe / safe_atr), "mae_atr": clean(mae / safe_atr),
            "spread_cost_pips": spread, "commission_cost_pips": commission,
            "slippage_cost_pips": slip, "total_cost_pips": total_cost,
            "cost_source": cost_source,
        }))
        if not emit_paths:
            continue
        for move, table, direction in (("favorable", hit_f, 1), ("adverse", hit_a, -1)):
            for level in levels:
                first = table[level]
                reached = (first <= h) & complete
                lower, upper, _ = hit_details(first, reached, level, direction)
                reached_nullable = pd.array(reached, dtype="boolean")
                reached_nullable[~complete] = pd.NA
                touch_frames.append(pd.DataFrame({
                    **identity, "horizon": h, "move": move, "level": level,
                    "reached": reached_nullable, "first_hit_bar": np.where(reached, first, np.nan),
                    "hit_time_lower": lower, "hit_time_upper": upper,
                    "censored": ~complete, "censor_reason": reason,
                }))
        for tp in levels:
            for sl in levels:
                f, a = hit_f[tp], hit_a[sl]
                f_hit, a_hit = (f <= h) & complete, (a <= h) & complete
                both = f_hit & a_hit
                ambiguous = both & (f == a)
                first = np.minimum(f, a)
                f_lower, f_upper, f_open = hit_details(f, f_hit, tp, 1)
                a_lower, a_upper, a_open = hit_details(a, a_hit, sl, -1)
                tp_first = (f_hit & (~a_hit | (f < a))) | (ambiguous & f_open)
                sl_first = (a_hit & (~f_hit | (a < f))) | (ambiguous & a_open)
                ambiguous &= ~f_open & ~a_open
                status = np.full(n, "neither", dtype=object)
                status[tp_first] = "tp_first"
                status[sl_first] = "sl_first"
                status[ambiguous] = "ambiguous"
                status[~complete] = "censored"
                any_hit = (f_hit | a_hit) & complete
                # For ambiguity either first-hit interval is the same candle.
                lower = np.where(tp_first | ambiguous, f_lower, a_lower)
                upper = np.where(tp_first | ambiguous, f_upper, a_upper)
                barrier_frames.append(pd.DataFrame({
                    **identity, "horizon": h, "tp_atr": tp, "sl_atr": sl,
                    "outcome": status, "tp_first_hit_bar": np.where(f_hit, f, np.nan),
                    "sl_first_hit_bar": np.where(a_hit, a, np.nan),
                    "first_hit_bar": np.where(any_hit, first, np.nan),
                    "hit_time_lower": lower, "hit_time_upper": upper,
                    "censored": ~complete, "censor_reason": reason,
                }))
    return (pd.concat(out_frames, ignore_index=True),
            pd.concat(touch_frames, ignore_index=True) if touch_frames else pd.DataFrame(columns=TOUCH_COLUMNS),
            pd.concat(barrier_frames, ignore_index=True) if barrier_frames else pd.DataFrame(columns=BARRIER_COLUMNS))


def resolve_tick_first_touch(ticks: pd.DataFrame, entry_price: float, side: str,
                             atr: float, tp_atr: float, sl_atr: float, *,
                             coverage_complete: bool = False,
                             time_column: str = "time", price_column: str = "bid"
                             ) -> dict[str, Any]:
    """Resolve gross first passage only for an explicitly complete tick window.

    The caller must clip ticks to its entry/evaluation interval and verify the
    coverage, ordering and quote provenance. Missing coverage is never inferred
    from first/last tick timestamps. Equal timestamps with opposing hits are
    still ambiguous unless the source supplied a finer ordered time column.
    This hook does not model orders, latency, quote spread or fill certainty.
    """
    if not coverage_complete:
        return {"outcome": "unknown", "reason": "tick_coverage_not_verified", "hit_time": None}
    if side not in {"LONG", "SHORT"} or not np.isfinite(entry_price):
        raise ValueError("Valid side and finite entry_price required")
    if any(not np.isfinite(x) or x <= 0 for x in (atr, tp_atr, sl_atr)):
        raise ValueError("ATR and thresholds must be positive")
    if ticks.empty or time_column not in ticks or price_column not in ticks:
        return {"outcome": "unknown", "reason": "missing_ticks_or_columns", "hit_time": None}
    times = ticks[time_column].to_numpy()
    prices = pd.to_numeric(ticks[price_column], errors="coerce").to_numpy(float)
    if pd.isna(times).any() or not np.isfinite(prices).all() or np.any(times[1:] < times[:-1]):
        return {"outcome": "unknown", "reason": "invalid_or_unordered_ticks", "hit_time": None}
    move = (1 if side == "LONG" else -1) * (prices - entry_price)
    tp = np.flatnonzero(move >= tp_atr * atr)
    sl = np.flatnonzero(move <= -sl_atr * atr)
    if not len(tp) and not len(sl):
        return {"outcome": "neither", "reason": "complete_tick_window", "hit_time": None}
    tp_time = times[tp[0]] if len(tp) else None
    sl_time = times[sl[0]] if len(sl) else None
    if tp_time is not None and sl_time is not None and tp_time == sl_time:
        return {"outcome": "ambiguous", "reason": "opposing_hits_same_timestamp", "hit_time": tp_time.item() if hasattr(tp_time, "item") else tp_time}
    first_tp = tp_time is not None and (sl_time is None or tp_time < sl_time)
    at = tp_time if first_tp else sl_time
    return {"outcome": "tp_first" if first_tp else "sl_first", "reason": "complete_tick_window",
            "hit_time": at.item() if hasattr(at, "item") else at}
