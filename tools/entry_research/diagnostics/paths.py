"""Fixed path diagnostics for existing entries; never extract or retime signals.

The entry-bar open and candidate ATR are frozen for every horizon. Classes are
descriptions of a completed gross bid-price path, not executable exit rules.
"""
from __future__ import annotations

from collections.abc import Iterator

import numpy as np
import pandas as pd


HOLDOUT_START = 1767225600
DEFAULT_CLASSIFICATION = {
    "threshold_atr": .5,
    "immediate_bars": 3,
    "terminal_adverse_atr": .25,
    "continuation_terminal_atr": .5,
    "continuation_floor_atr": .25,
    "continuation_last_bars": 10,
    "continuation_min_closes": 8,
    "horizon": 50,
}
METADATA = ["candidate_id", "origin_candidate_id", "method", "side", "week", "year",
            "replicate", "signal_index", "entry_index", "signal_time", "entry_time"]
CURVE_COLUMNS = ["candidate_id", "origin_candidate_id", "horizon", "gross_pips", "net_pips",
                 "gross_atr", "net_atr", "mfe_atr", "mae_atr", "common_pool"]


def _settings(config: dict) -> dict:
    base = dict(config.get("base_config", {}))
    base.update({key: value for key, value in config.items() if key not in {"base_config", "classification"}})
    settings = {**DEFAULT_CLASSIFICATION, **{key: base[key] for key in DEFAULT_CLASSIFICATION if key in base},
                **config.get("classification", {})}
    for key in ("threshold_atr", "terminal_adverse_atr", "continuation_terminal_atr", "continuation_floor_atr"):
        settings[key] = float(settings[key])
        if not np.isfinite(settings[key]) or settings[key] <= 0:
            raise ValueError(f"{key} must be finite and positive")
    for key in ("horizon", "immediate_bars", "continuation_last_bars", "continuation_min_closes"):
        value = float(settings[key])
        if not np.isfinite(value) or value != int(value) or value < 1:
            raise ValueError(f"{key} must be a positive integer")
        settings[key] = int(value)
    if not (settings["continuation_min_closes"] <= settings["continuation_last_bars"] <= settings["horizon"]):
        raise ValueError("continuation_min_closes <= continuation_last_bars <= horizon required")
    if settings["immediate_bars"] > settings["horizon"]:
        raise ValueError("immediate_bars cannot exceed horizon")
    settings["pip_size"] = float(base.get("pip_size", .01))
    settings["timeframe_seconds"] = int(base.get("timeframe_seconds", 300))
    settings["max_entry_delay_seconds"] = float(base.get("max_entry_delay_seconds", 300))
    end = base.get("end_exclusive")
    if end is None:
        end = int(pd.Timestamp(base.get("end", "2026-01-01")).timestamp())
    settings["end_exclusive"] = int(end)
    if settings["end_exclusive"] > HOLDOUT_START:
        raise ValueError("2026 holdout is locked")
    if not np.isfinite(settings["pip_size"]) or settings["pip_size"] <= 0 or settings["timeframe_seconds"] <= 0:
        raise ValueError("pip_size and timeframe_seconds must be positive")
    cost = base.get("cost", {})
    if cost.get("mode", "assumed") != "assumed":
        raise ValueError("Path diagnostics require the original fixed assumed cost")
    costs = [float(cost.get("spread_pips", 1.5)), float(cost.get("commission_pips_roundtrip", 0.0)),
             2 * float(cost.get("slippage_pips_per_side", .2))]
    if any(not np.isfinite(value) or value < 0 for value in costs):
        raise ValueError("Costs must be finite and nonnegative")
    settings["total_cost_pips"] = sum(costs)
    return settings


def _validate(bars: pd.DataFrame, candidates: pd.DataFrame) -> None:
    required_bars = {"time", "open", "high", "low", "close"}
    required_candidates = {"candidate_id", "side", "signal_index", "entry_index", "entry_time",
                           "signal_time", "nominal_close_time", "atr14", "eligible"}
    if required_bars - set(bars):
        raise ValueError(f"Missing bar columns: {sorted(required_bars - set(bars))}")
    if required_candidates - set(candidates):
        raise ValueError(f"Missing candidate columns: {sorted(required_candidates - set(candidates))}")
    if not bars.time.is_monotonic_increasing or bars.time.duplicated().any():
        raise ValueError("Bar times must be strictly increasing and unique")
    if (bars.time >= HOLDOUT_START).any():
        raise ValueError("2026 holdout price rows are forbidden")
    if candidates.candidate_id.isna().any() or candidates.candidate_id.duplicated().any():
        raise ValueError("candidate_id must be present and unique")
    if set(candidates.side) - {"LONG", "SHORT"}:
        raise ValueError("side must be LONG or SHORT")
    if candidates.eligible.isna().any() or not candidates.eligible.isin([True, False]).all():
        raise ValueError("Original eligible flag must be boolean and nonmissing")
    for column in ("signal_index", "entry_index", "entry_time", "signal_time", "nominal_close_time"):
        values = pd.to_numeric(candidates[column], errors="raise").to_numpy(float)
        if not np.isfinite(values).all() or np.any(values != np.floor(values)):
            raise ValueError(f"{column} must contain finite integer values")


def _identity(candidates: pd.DataFrame) -> pd.DataFrame:
    result = candidates[[key for key in METADATA if key in candidates]].copy().reset_index(drop=True)
    if "origin_candidate_id" not in result:
        result.insert(1, "origin_candidate_id", result.candidate_id)
    return result


def _windows(bars: pd.DataFrame, candidates: pd.DataFrame, settings: dict) -> dict:
    """Bounded vector windows, shared by classification and trajectory export."""
    n, count, horizon = len(candidates), len(bars), settings["horizon"]
    entries = candidates.entry_index.to_numpy(np.int64)
    signals = candidates.signal_index.to_numpy(np.int64)
    atr = candidates.atr14.to_numpy(float)
    step, end = settings["timeframe_seconds"], settings["end_exclusive"]
    offsets = np.arange(horizon)
    indices = entries[:, None] + offsets
    present = (indices >= 0) & (indices < count)
    safe = np.clip(indices, 0, max(0, count - 1))
    arrays = {key: np.where(present, bars[key].to_numpy(float)[safe], np.nan)
              if count else np.full((n, horizon), np.nan)
              for key in ("time", "open", "high", "low", "close")}
    reason = np.full(n, "", dtype=object)
    def invalidate(mask, message):
        reason[(reason == "") & mask] = message
    entry_time = candidates.entry_time.to_numpy(np.int64)
    signal_time = candidates.signal_time.to_numpy(np.int64)
    nominal = candidates.nominal_close_time.to_numpy(np.int64)
    invalidate(~np.isfinite(atr) | (atr <= 0), "invalid_atr")
    invalidate((signals < 0) | (signals >= count), "signal_index_unavailable")
    invalidate((entries < 0) | (entries >= count), "entry_index_unavailable")
    invalidate(entries <= signals, "entry_not_after_signal_bar")
    invalidate(entry_time < signal_time, "entry_before_signal_available")
    invalidate(signal_time < nominal, "decision_before_nominal_close")
    invalidate(entry_time - nominal > settings["max_entry_delay_seconds"], "entry_delay_exceeded")
    invalidate((entry_time >= end) | (signal_time >= end), "development_boundary")
    if count:
        signal_safe = np.clip(signals, 0, count - 1)
        invalidate(nominal != bars.time.to_numpy(np.int64)[signal_safe] + step, "signal_bar_time_mismatch")
        availability = "available_time" if "available_time" in bars else "source_available_at"
        if availability in bars:
            invalidate(signal_time < bars[availability].to_numpy(np.int64)[signal_safe], "signal_before_source_available")
    invalidate(~present.all(axis=1), "insufficient_future_bars")
    expected = entry_time[:, None] + offsets * step
    invalidate(~(arrays["time"] == expected).all(axis=1), "time_gap_or_entry_mismatch")
    finite = np.logical_and.reduce([np.isfinite(arrays[key]) for key in ("open", "high", "low", "close")])
    geometry = ((arrays["high"] >= np.maximum(arrays["open"], arrays["close"])) &
                (arrays["low"] <= np.minimum(arrays["open"], arrays["close"])) &
                (arrays["high"] >= arrays["low"]))
    invalidate(~(finite & geometry).all(axis=1), "invalid_ohlc")
    invalidate(arrays["time"][:, -1] + step > end, "development_boundary")
    complete = reason == ""
    entry_price = arrays["open"][:, 0]
    sign = np.where(candidates.side.to_numpy() == "LONG", 1., -1.)[:, None]
    denominator = np.where(np.isfinite(atr) & (atr > 0), atr, np.nan)[:, None]
    favorable = np.where(sign > 0, arrays["high"] - entry_price[:, None], entry_price[:, None] - arrays["low"])
    adverse = np.where(sign > 0, entry_price[:, None] - arrays["low"], arrays["high"] - entry_price[:, None])
    gross = sign * (arrays["close"] - entry_price[:, None])
    return {"complete": complete, "censor_reason": reason, "entry_price": entry_price, "atr": atr,
            "favorable_atr": favorable / denominator, "adverse_atr": adverse / denominator,
            "close_atr": gross / denominator,
            "open_atr": sign * (arrays["open"] - entry_price[:, None]) / denominator,
            "gross_pips": gross / settings["pip_size"],
            "net_atr": (gross - settings["total_cost_pips"] * settings["pip_size"]) / denominator}


def classify_paths(bars: pd.DataFrame, candidates: pd.DataFrame, config: dict) -> pd.DataFrame:
    """One row per existing candidate, preserving IDs and any baseline replicate.

    ``config`` accepts either merged settings or ``base_config`` plus a
    ``classification`` mapping. Hit-bar numbers are one-based from original
    entry. Missing/invalid complete windows receive ``unclassifiable_data``;
    incomplete metrics are NaN, never imputed classifications.
    """
    settings = _settings(config)
    _validate(bars, candidates)
    frames = []
    for begin in range(0, len(candidates), 4096):
        chunk = candidates.iloc[begin:begin + 4096]
        w = _windows(bars, chunk, settings)
        horizon, threshold = settings["horizon"], settings["threshold_atr"]
        numbers = np.arange(1, horizon + 1)[None, :]
        first_f = np.where(w["favorable_atr"] >= threshold, numbers, horizon + 1).min(axis=1)
        first_a = np.where(w["adverse_atr"] >= threshold, numbers, horizon + 1).min(axis=1)
        f_hit, a_hit = first_f <= horizon, first_a <= horizon
        both = f_hit & a_hit
        same = both & (first_f == first_a)
        same_open = w["open_atr"][np.arange(len(chunk)), np.minimum(first_f - 1, horizon - 1)]
        f_open, a_open = same_open >= threshold, same_open <= -threshold
        open_resolved = same & (f_open ^ a_open)
        ambiguous = same & ~open_resolved
        favorable_first = both & ((first_f < first_a) | (same & f_open & ~a_open))
        adverse_first = both & ((first_a < first_f) | (same & a_open & ~f_open))
        terminal = w["close_atr"][:, -1]
        last_n = settings["continuation_last_bars"]
        tail_count = (w["close_atr"][:, -last_n:] >= settings["continuation_floor_atr"]).sum(axis=1)
        labels = np.full(len(chunk), "unclassified_other", dtype=object)
        labels[~f_hit & ~a_hit] = "no_direction"
        labels[a_hit & ~f_hit & (first_a <= settings["immediate_bars"]) &
               (terminal <= -settings["terminal_adverse_atr"])] = "immediate_adverse"
        labels[f_hit & ~a_hit & (terminal >= settings["continuation_terminal_atr"]) &
               (tail_count >= settings["continuation_min_closes"])] = "favorable_continuation"
        labels[favorable_first] = "favorable_then_reversal"
        labels[adverse_first] = "adverse_then_favorable"
        labels[ambiguous] = "ambiguous_order"
        labels[~w["complete"]] = "unclassifiable_data"
        order = np.full(len(chunk), "one_or_no_threshold_hit", dtype=object)
        order[both & ~same] = "different_bars"
        order[open_resolved] = "same_bar_open_resolved"
        order[ambiguous] = "same_bar_unknown"
        order[~w["complete"]] = "unclassifiable_data"
        result = _identity(chunk)
        clean = lambda values: np.where(w["complete"], values, np.nan)
        result["class_label"] = labels
        result["complete"] = w["complete"]
        result["censor_reason"] = w["censor_reason"]
        result["common_pool"] = chunk.eligible.to_numpy(bool) & w["complete"]
        result["original_eligible"] = chunk.eligible.to_numpy(bool)
        result["order_resolution"] = order
        result["first_favorable_bar"] = clean(np.where(f_hit, first_f, np.nan))
        result["first_adverse_bar"] = clean(np.where(a_hit, first_a, np.nan))
        result["entry_price"] = w["entry_price"]
        result["atr14"] = w["atr"]
        result["mfe_atr"] = clean(np.maximum(w["favorable_atr"].max(axis=1), 0))
        result["mae_atr"] = clean(np.maximum(w["adverse_atr"].max(axis=1), 0))
        result["terminal_atr"] = clean(terminal)
        result["terminal_gross_pips"] = clean(w["gross_pips"][:, -1])
        result["terminal_net_pips"] = clean(w["gross_pips"][:, -1] - settings["total_cost_pips"])
        early_index = settings["immediate_bars"] - 1
        result["early_gross_pips"] = clean(w["gross_pips"][:, early_index])
        result["early_net_pips"] = clean(w["gross_pips"][:, early_index] - settings["total_cost_pips"])
        result["tail_closes_above_floor"] = clean(tail_count)
        result["total_cost_pips"] = settings["total_cost_pips"]
        result["classification_horizon"] = horizon
        frames.append(result)
    if frames:
        return pd.concat(frames, ignore_index=True)
    return pd.DataFrame(columns=list(_identity(candidates).columns) + ["class_label", "complete", "censor_reason",
                         "common_pool", "original_eligible", "first_favorable_bar", "first_adverse_bar",
                         "mfe_atr", "mae_atr", "terminal_atr"])


def iter_path_curves(bars: pd.DataFrame, candidates: pd.DataFrame, config: dict,
                     chunk_size: int = 2048) -> Iterator[pd.DataFrame]:
    """Stream h=1..H paths for the ORIGINAL common cohort, bounded by chunk_size.

    Every included event has exactly H rows and complete contiguous H-bar data.
    Cohort membership never changes by horizon. Use this iterator for all ten
    baseline replicates to avoid materializing millions of rows in memory.
    """
    settings = _settings(config)
    _validate(bars, candidates)
    if not isinstance(chunk_size, int) or chunk_size <= 0:
        raise ValueError("chunk_size must be a positive integer")
    pool = candidates.loc[candidates.eligible.astype(bool)]
    horizon = settings["horizon"]
    for begin in range(0, len(pool), chunk_size):
        chunk = pool.iloc[begin:begin + chunk_size]
        w = _windows(bars, chunk, settings)
        complete = w["complete"]
        if not complete.any():
            continue
        identity = _identity(chunk.loc[complete])
        result = identity.iloc[np.repeat(np.arange(len(identity)), horizon)].reset_index(drop=True)
        result["horizon"] = np.tile(np.arange(1, horizon + 1), len(identity))
        result["gross_pips"] = w["gross_pips"][complete].ravel()
        result["net_pips"] = result.gross_pips - settings["total_cost_pips"]
        result["gross_atr"] = w["close_atr"][complete].ravel()
        result["net_atr"] = w["net_atr"][complete].ravel()
        result["mfe_atr"] = np.maximum.accumulate(np.maximum(w["favorable_atr"][complete], 0), axis=1).ravel()
        result["mae_atr"] = np.maximum.accumulate(np.maximum(w["adverse_atr"][complete], 0), axis=1).ravel()
        result["common_pool"] = True
        yield result


def path_curve(bars: pd.DataFrame, candidates: pd.DataFrame, config: dict) -> pd.DataFrame:
    """Materialized convenience wrapper around :func:`iter_path_curves`."""
    frames = list(iter_path_curves(bars, candidates, config))
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame(columns=CURVE_COLUMNS)
