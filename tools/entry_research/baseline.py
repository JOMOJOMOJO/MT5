"""Reproducible, exactly stratified controls for entry-candidate research.

Original event bars deliberately remain in the eligible pool. Removing them
would condition the null on *not* observing the signal. Replicates describe
Monte Carlo uncertainty; they are never extra independent candidate samples.
"""
from __future__ import annotations

import hashlib

import numpy as np
import pandas as pd

MATCH_COLUMNS = ["symbol", "year", "hour", "weekday", "vol_bucket"]


def matched_baseline(
    features: pd.DataFrame,
    candidates: pd.DataFrame,
    seed: int,
    repeats: int = 10,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Draw the same candidate count in every method/direction/stratum.

    Sampling is without replacement within each method/side/stratum/replicate,
    with independent replicates and explicit failure instead of relaxed matches.
    Only features whose ``eligible`` value is True can be sampled. Input order
    does not change the result. ``origin_candidate_id`` is a reproducible
    bookkeeping pairing, not a claim of independent paired observations.
    """
    if repeats < 1 or int(repeats) != repeats:
        raise ValueError("repeats must be a positive integer")
    feature_required = MATCH_COLUMNS + ["eligible", "signal_index", "entry_index"]
    candidate_required = MATCH_COLUMNS + ["candidate_id", "method", "side"]
    for label, frame, required in (
        ("features", features, feature_required),
        ("candidates", candidates, candidate_required),
    ):
        missing = sorted(set(required) - set(frame.columns))
        if missing:
            raise ValueError(f"{label} missing columns: {missing}")
    if candidates["candidate_id"].isna().any() or candidates["candidate_id"].duplicated().any():
        raise ValueError("candidate_id must be non-null and unique")
    if not candidates["side"].isin(["LONG", "SHORT"]).all():
        raise ValueError("side must be LONG or SHORT")
    pool = features.loc[features["eligible"].eq(True)].copy()
    if pool.duplicated(["symbol", "signal_index"]).any():
        raise ValueError("eligible features must be unique by symbol and signal_index")
    if pool[MATCH_COLUMNS].isna().any().any() or candidates[MATCH_COLUMNS + ["method", "side"]].isna().any().any():
        raise ValueError("matching columns cannot contain missing values")
    if candidates.empty:
        empty = features.iloc[:0].copy()
        for column in ["candidate_id", "origin_candidate_id", "method", "side", "replicate"]:
            empty[column] = pd.Series(dtype="int64" if column == "replicate" else "object")
        return empty, pd.DataFrame(columns=["method", "side", *MATCH_COLUMNS, "replicate", "requested_n", "pool_n", "sampled_n"])

    pool = pool.sort_values(MATCH_COLUMNS + ["signal_index"]).reset_index(drop=True)
    pools = {key: group for key, group in pool.groupby(MATCH_COLUMNS, observed=True, sort=True)}
    groups = candidates.sort_values(["method", "side", *MATCH_COLUMNS, "candidate_id"]).groupby(
        ["method", "side", *MATCH_COLUMNS], observed=True, sort=True
    )
    rng = np.random.default_rng(seed)
    sampled, audits = [], []
    for key, group in groups:
        method, side, *stratum = key
        key_pool = pools.get(tuple(stratum))
        count, available = len(group), 0 if key_pool is None else len(key_pool)
        if available < count:
            raise ValueError(f"Insufficient exact-match pool for {key}: requested={count}, available={available}")
        event_indices = set(group["signal_index"]) if "signal_index" in group else set()
        origins = group["candidate_id"].astype(str).to_numpy()
        for replicate in range(repeats):
            chosen = key_pool.iloc[rng.choice(available, size=count, replace=False)].copy()
            chosen["origin_candidate_id"] = origins
            chosen["method"] = method
            chosen["side"] = side
            chosen["replicate"] = replicate
            chosen["candidate_id"] = [
                "baseline_" + hashlib.sha256(f"{origin}|{replicate}|{symbol}|{index}".encode()).hexdigest()[:24]
                for origin, symbol, index in zip(origins, chosen["symbol"], chosen["signal_index"], strict=True)
            ]
            sampled.append(chosen)
            audits.append({
                "method": method, "side": side, **dict(zip(MATCH_COLUMNS, stratum, strict=True)),
                "replicate": replicate, "requested_n": count, "pool_n": available,
                "sampled_n": len(chosen), "sampled_distinct_n": chosen["signal_index"].nunique(),
                "strategy_event_bars_sampled_n": chosen["signal_index"].isin(event_indices).sum(),
                "candidate_bars_allowed": True, "replacement_within_stratum": False,
            })
    return pd.concat(sampled, ignore_index=True), pd.DataFrame(audits)
