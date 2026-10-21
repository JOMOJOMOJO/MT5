"""Ideal symmetric-barrier scenarios on the original, unchanged H50 cohort.

The lower/upper columns bound ONLY unresolved OHLC touch ordering under ideal
barrier-price fills. They are not bounds on executable returns: gap overshoot,
liquidity, latency and price-dependent slippage are deliberately not modeled.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

from ..evaluation import evaluate


SCENARIO = "ideal_barrier_no_gap_slippage_guarantee"
BOUNDS_BASIS = "same_bar_order_only_not_execution_or_gap_bounds"
BASE_COLUMNS = ["candidate_id", "method", "side", "week", "year", "level", "outcome",
                "first_hit_bar", "gross_lower_pips", "gross_upper_pips", "net_lower_pips",
                "net_upper_pips", "cost_pips", "scenario", "bounds_basis", "gap_overshoot_ignored"]


def barrier_scenarios(bars: pd.DataFrame, candidates: pd.DataFrame, config: dict) -> pd.DataFrame:
    """One row per eligible origin and frozen symmetric ATR level at H50.

    A TP/SL first touch receives its ideal signed barrier amount. Ambiguous
    same-bar touch receives SL-first/TP-first scenario endpoints. A complete
    horizon without either touch uses its terminal close. Censored outcomes
    stay NaN rather than becoming losses, wins or zero-return observations.
    """
    if "eligible" not in candidates:
        raise ValueError("Original eligible cohort flag is required")
    if config.get('end_exclusive',1767225600) > 1767225600 or (bars.time >= 1767225600).any():
        raise ValueError('2026 holdout is locked')
    selected = candidates.loc[candidates.eligible.eq(True)].copy()
    levels = tuple(float(x) for x in config.get("barrier_levels", [.5, 1., 1.5]))
    if not levels or any(not np.isfinite(x) or x <= 0 for x in levels) or len(set(levels)) != len(levels):
        raise ValueError("barrier_levels must be distinct positive finite ATR values")
    cost = config.get("cost", {})
    if cost.get("mode", "assumed") != "assumed":
        raise ValueError("Ideal barrier scenarios require the frozen assumed cost model")
    local = dict(config, horizons=[50], levels=list(levels), emit_paths=True)
    if selected.empty:
        result = pd.DataFrame(columns=BASE_COLUMNS + (["replicate"] if "replicate" in selected else []))
    else:
        outcomes, _, barriers = evaluate(bars, selected, local)
        result = barriers.loc[barriers.tp_atr.eq(barriers.sl_atr)].copy()
        result = result.rename(columns={"tp_atr": "level"}).drop(columns=["sl_atr"])
        event_columns = [c for c in ["candidate_id", "week", "year", "replicate", "symbol", "atr14"] if c in selected]
        result = result.merge(selected[event_columns], on="candidate_id", how="left", validate="many_to_one")
        result = result.merge(outcomes[["candidate_id", "gross_pips", "total_cost_pips", "complete"]],
                              on="candidate_id", how="left", validate="many_to_one")
        pip = float(config.get("pip_size", .01))
        ideal = result.level * result.atr14 / pip
        low = np.full(len(result), np.nan)
        high = np.full(len(result), np.nan)
        tp = result.outcome.eq("tp_first").to_numpy()
        sl = result.outcome.eq("sl_first").to_numpy()
        ambiguous = result.outcome.eq("ambiguous").to_numpy()
        neither = result.outcome.eq("neither").to_numpy() & result.complete.eq(True).to_numpy()
        low[tp] = high[tp] = ideal.loc[tp]
        low[sl] = high[sl] = -ideal.loc[sl]
        low[ambiguous], high[ambiguous] = -ideal.loc[ambiguous], ideal.loc[ambiguous]
        low[neither] = high[neither] = result.loc[neither, "gross_pips"]
        result["gross_lower_pips"], result["gross_upper_pips"] = low, high
        result["cost_pips"] = result.total_cost_pips
        result["net_lower_pips"] = low - result.cost_pips
        result["net_upper_pips"] = high - result.cost_pips
        result["scenario"] = SCENARIO
        result["bounds_basis"] = BOUNDS_BASIS
        result["gap_overshoot_ignored"] = True
        result = result.drop(columns=["gross_pips", "total_cost_pips"])
    result.attrs["barrier_metadata"] = {
        "scenario": SCENARIO, "bounds_basis": BOUNDS_BASIS, "horizon": 50,
        "levels": list(levels), "cohort": "original_eligible_H50_candidates_only",
        "frozen_atr": "original_signal_atr14", "unresolved_order": "SL_first_to_TP_first",
        "untouched_endpoint": "H50_terminal_bid_close", "gap_overshoot_ignored": True,
        "not_executable_profit_bounds": True,
    }
    return result
