"""Frozen H10 environmental exploration with exhaustive, visible cells.

Every configured method/direction gets the same 122 categorical cells. Week
blocks are a dependence proxy, not proven independent observations. Filtering
the original matched controls does not re-match the selected environment.
"""
from __future__ import annotations

from hashlib import sha256
from itertools import product

import numpy as np
import pandas as pd

from ..statistics import calendar_week_bootstrap, holm_adjust


YEARS = (2024, 2025)
CATEGORIES = {
    "h1_alignment": ("aligned", "opposed", "other"),
    "m15_alignment": ("aligned", "opposed", "other"),
    "vol_bucket": ("low", "normal", "high"),
    "hour_block": ("source00_05", "source06_11", "source12_17", "source18_23"),
    "range_bucket": ("range_low", "range_high", "unknown"),
    "cloud_alignment": ("aligned", "opposed", "inside", "unknown"),
}
COMBINATIONS = tuple((dimension,) for dimension in CATEGORIES) + (
    ("h1_alignment", "m15_alignment"),
    ("h1_alignment", "vol_bucket"),
    ("m15_alignment", "range_bucket"),
    ("vol_bucket", "hour_block"),
    ("h1_alignment", "m15_alignment", "vol_bucket"),
    ("h1_alignment", "vol_bucket", "hour_block"),
)
CELLS_PER_METHOD_SIDE = sum(int(np.prod([len(CATEGORIES[d]) for d in dims])) for dims in COMBINATIONS)


def cell_templates() -> list[tuple[tuple[str, ...], tuple[str, ...]]]:
    """Full predefined categories, including categories absent from the data."""
    return [(dims, values) for dims in COMBINATIONS for values in product(*(CATEGORIES[d] for d in dims))]


def environment_features(frame: pd.DataFrame) -> pd.DataFrame:
    """Build only the six permitted categories from decision-time metadata."""
    required = ["candidate_id", "method", "side", "week", "year", "hour", "vol_bucket", "range_position",
                "cloud_position", "h1_trend", "m15_trend", "h1_stale", "m15_stale"]
    if missing := set(required) - set(frame):
        raise ValueError(f"candidate features missing columns: {sorted(missing)}")
    columns = required + (["replicate"] if "replicate" in frame else [])
    data = frame[columns].copy()
    if data.candidate_id.isna().any() or data.candidate_id.duplicated().any():
        raise ValueError("candidate_id must be present and unique")
    if data[["method", "side", "week", "year"]].isna().any().any():
        raise ValueError("method, side, week and year cannot be missing")
    if not data.side.isin(["LONG", "SHORT"]).all() or not data.year.isin(YEARS).all():
        raise ValueError("Only LONG/SHORT and development years 2024/2025 are allowed")
    if "eligible" in frame and not frame.eligible.eq(True).all():
        raise ValueError("Environment exploration requires the original common eligible cohort")
    if not data.vol_bucket.isin(CATEGORIES["vol_bucket"]).all():
        raise ValueError("vol_bucket must be low, normal or high; no implicit dropped category")
    hour = pd.to_numeric(data.hour, errors="coerce")
    if not (hour.notna() & hour.between(0, 23) & hour.eq(np.floor(hour))).all():
        raise ValueError("hour must be an integer source-clock hour in 0..23")
    data["hour_block"] = np.asarray(CATEGORIES["hour_block"])[hour.to_numpy(dtype=int) // 6]
    for tf in ("h1", "m15"):
        stale = data[f"{tf}_stale"]
        if not stale.dropna().isin([True, False]).all():
            raise ValueError(f"{tf}_stale must be boolean or missing")
        usable = stale.eq(False).fillna(False)
        trend = data[f"{tf}_trend"]
        aligned = (data.side.eq("LONG") & trend.eq("up")) | (data.side.eq("SHORT") & trend.eq("down"))
        opposed = (data.side.eq("LONG") & trend.eq("down")) | (data.side.eq("SHORT") & trend.eq("up"))
        data[f"{tf}_alignment"] = np.select([usable & aligned.fillna(False), usable & opposed.fillna(False)],
                                             ["aligned", "opposed"], default="other")
    position = pd.to_numeric(data.range_position, errors="coerce")
    data["range_bucket"] = np.select([np.isfinite(position) & position.le(.5), np.isfinite(position) & position.gt(.5)],
                                      ["range_low", "range_high"], default="unknown")
    cloud = data.cloud_position
    aligned = (data.side.eq("LONG") & cloud.eq("above")) | (data.side.eq("SHORT") & cloud.eq("below"))
    opposed = (data.side.eq("LONG") & cloud.eq("below")) | (data.side.eq("SHORT") & cloud.eq("above"))
    data["cloud_alignment"] = np.select([aligned.fillna(False), opposed.fillna(False), cloud.eq("inside").fillna(False)],
                                         ["aligned", "opposed", "inside"], default="unknown")
    data["week"] = data.week.astype(str)
    return data


def _attach(features: pd.DataFrame, outcomes: pd.DataFrame) -> pd.DataFrame:
    required = {"candidate_id", "gross_pips", "net_pips"}
    if missing := required - set(outcomes):
        raise ValueError(f"H10 outcomes missing columns: {sorted(missing)}")
    if outcomes.candidate_id.isna().any() or outcomes.candidate_id.duplicated().any():
        raise ValueError("H10 outcomes must have exactly one row per candidate_id")
    if "horizon" in outcomes and not outcomes.horizon.eq(10).all():
        raise ValueError("Only the frozen H10 outcome is accepted")
    if "complete" in outcomes and not outcomes.complete.eq(True).all():
        raise ValueError("Original common-cohort H10 outcomes must be complete")
    if set(features.candidate_id) != set(outcomes.candidate_id):
        raise ValueError("H10 outcomes must cover exactly the supplied candidate cohort")
    data = features.merge(outcomes[["candidate_id", "gross_pips", "net_pips"]], on="candidate_id", validate="one_to_one")
    for metric in ("gross_pips", "net_pips"):
        data[metric] = pd.to_numeric(data[metric], errors="coerce")
        if not np.isfinite(data[metric]).all():
            raise ValueError("H10 metrics must be finite; no missing outcomes may be silently dropped")
    return data.sort_values(["week", "candidate_id"]).reset_index(drop=True)


def _positive_int(config: dict, key: str, default: int) -> int:
    value = config.get(key, default)
    if isinstance(value, bool) or int(value) != value or value < 1:
        raise ValueError(f"{key} must be a positive integer")
    return int(value)


def _control_summary(frame: pd.DataFrame, replicates: range) -> dict:
    if frame.empty:
        return {"n_total": 0, "n_min": 0, "n_max": 0, "n_mean": 0., "weeks_min": 0, "weeks_max": 0,
                "represented_repeats": 0, "available": False, "mean_net_pips": np.nan}
    counts = frame.groupby("replicate").size().reindex(replicates, fill_value=0)
    weeks = frame.groupby("replicate").week.nunique().reindex(replicates, fill_value=0)
    means = frame.groupby("replicate").net_pips.mean().reindex(replicates)
    all_available = bool(counts.gt(0).all())
    return {"n_total": len(frame), "n_min": int(counts.min()), "n_max": int(counts.max()),
            "n_mean": float(counts.mean()), "weeks_min": int(weeks.min()), "weeks_max": int(weeks.max()),
            "represented_repeats": int(counts.gt(0).sum()), "available": all_available,
            "mean_net_pips": float(means.mean()) if all_available else np.nan}


def explore_environment(candidates: pd.DataFrame, controls: pd.DataFrame, strategy_h10: pd.DataFrame,
                        baseline_h10: pd.DataFrame, config: dict) -> pd.DataFrame:
    """Return the complete frozen family; no results-ranked cell selection.

    Flat config requires ``methods`` and accepts ``sides`` (default both),
    ``min_n``=200, ``min_weeks``=30, ``peryear_min_n``=75,
    ``peryear_weeks``=15, ``baseline_repeats``=10, ``bootstrap_reps``=20000,
    ``seed``=20261015 and ``cell_cap``=732. Sample gates apply to strategy and
    each control replicate. Bootstrap CIs and p values are withheld otherwise.
    """
    methods = list(config.get("methods", []))
    sides = list(config.get("sides", ["LONG", "SHORT"]))
    if not methods or len(set(methods)) != len(methods) or len(set(sides)) != len(sides) or not sides or not set(sides) <= {"LONG", "SHORT"}:
        raise ValueError("Freeze a unique methods list and valid sides before exploration")
    thresholds = {key: _positive_int(config, key, default) for key, default in
                  [("min_n", 200), ("min_weeks", 30), ("peryear_min_n", 75), ("peryear_weeks", 15)]}
    repeats = _positive_int(config, "baseline_repeats", 10)
    bootstrap_reps = _positive_int(config, "bootstrap_reps", 20000)
    cap = _positive_int(config, "cell_cap", 732)
    total = len(methods) * len(sides) * CELLS_PER_METHOD_SIDE
    if total > cap:
        raise ValueError(f"Frozen environment family has {total} cells, above cap={cap}")
    strategy = _attach(environment_features(candidates), strategy_h10)
    baseline = _attach(environment_features(controls), baseline_h10)
    if not set(strategy.method) <= set(methods) or not set(baseline.method) <= set(methods) or not set(strategy.side) <= set(sides) or not set(baseline.side) <= set(sides):
        raise ValueError("Data include method/side outside the frozen family")
    if "replicate" not in baseline or not baseline.replicate.isin(range(repeats)).all():
        raise ValueError("Control replicate IDs must be in the configured 0-based range")
    replicate_ids = range(repeats)
    rows = []
    for method, side in product(sorted(methods), sorted(sides)):
        s0 = strategy.loc[strategy.method.eq(method) & strategy.side.eq(side)]
        c0 = baseline.loc[baseline.method.eq(method) & baseline.side.eq(side)]
        # The original design matched exactly before environment conditioning.
        initial_counts = c0.groupby("replicate").size().reindex(replicate_ids, fill_value=0)
        if not initial_counts.eq(len(s0)).all():
            raise ValueError(f"Original baseline count differs from strategy for {method}/{side}")
        for dimensions, values in cell_templates():
            smask = np.ones(len(s0), dtype=bool)
            cmask = np.ones(len(c0), dtype=bool)
            for dimension, value in zip(dimensions, values, strict=True):
                smask &= s0[dimension].eq(value).to_numpy(dtype=bool)
                cmask &= c0[dimension].eq(value).to_numpy(dtype=bool)
            s, c = s0.loc[smask], c0.loc[cmask]
            condition = "&".join(f"{d}={v}" for d, v in zip(dimensions, values, strict=True))
            cell_id = f"{method}|{side}|{condition}"
            control = _control_summary(c, replicate_ids)
            row = {"cell_id": cell_id, "method": method, "side": side, "horizon": 10,
                   "dimension_count": len(dimensions), "dimensions": "+".join(dimensions), "condition": condition,
                   "n": len(s), "weeks": int(s.week.nunique()), "mean_gross_pips": float(s.gross_pips.mean()),
                   "mean_net_pips": float(s.net_pips.mean()), "baseline_mean_net_pips": control["mean_net_pips"],
                   "baseline_repeats": repeats, "baseline_estimator": "mean_of_replicate_conditional_means",
                   "environment_rematched": False, "calendar_block_proxy": True,
                   "bootstrap_unit": "aligned_source_clock_calendar_week", "bootstrap_reps": bootstrap_reps,
                   "cells_per_method_side": CELLS_PER_METHOD_SIDE, "total_cells": total, "cell_cap": cap,
                   "holm_family_size": total, "p_resolution": 1 / (bootstrap_reps + 1),
                   "minimum_holm_p": min(1., total / (bootstrap_reps + 1)),
                   "resolution_limited": total / (bootstrap_reps + 1) >= .05,
                   "net_ci_low": np.nan, "net_ci_high": np.nan, "delta_ci_low": np.nan, "delta_ci_high": np.nan,
                   "bootstrap_valid": 0, "p_delta_net_pips": np.nan, "p_delta_net_pips_holm": np.nan}
            row.update({f"baseline_{key}": value for key, value in control.items() if key != "mean_net_pips"})
            row.update({dimension: value for dimension, value in zip(dimensions, values, strict=True)})
            row["delta_net_pips"] = row["mean_net_pips"] - row["baseline_mean_net_pips"]
            reasons = []
            for key, value, minimum in [("n", row["n"], thresholds["min_n"]),
                                        ("weeks", row["weeks"], thresholds["min_weeks"]),
                                        ("baseline_n_min", control["n_min"], thresholds["min_n"]),
                                        ("baseline_weeks_min", control["weeks_min"], thresholds["min_weeks"])]:
                if value < minimum:
                    reasons.append(f"{key}<{minimum}")
            for year in YEARS:
                sy, cy = s.loc[s.year.eq(year)], c.loc[c.year.eq(year)]
                yc = _control_summary(cy, replicate_ids)
                row.update({f"n_{year}": len(sy), f"weeks_{year}": int(sy.week.nunique()),
                            f"mean_net_pips_{year}": float(sy.net_pips.mean()),
                            f"baseline_mean_net_pips_{year}": yc["mean_net_pips"],
                            f"delta_net_pips_{year}": float(sy.net_pips.mean()) - yc["mean_net_pips"],
                            f"baseline_n_min_{year}": yc["n_min"], f"baseline_n_max_{year}": yc["n_max"],
                            f"baseline_weeks_min_{year}": yc["weeks_min"],
                            f"baseline_represented_repeats_{year}": yc["represented_repeats"]})
                for key, value, minimum in [(f"n_{year}", len(sy), thresholds["peryear_min_n"]),
                                            (f"weeks_{year}", sy.week.nunique(), thresholds["peryear_weeks"]),
                                            (f"baseline_n_min_{year}", yc["n_min"], thresholds["peryear_min_n"]),
                                            (f"baseline_weeks_min_{year}", yc["weeks_min"], thresholds["peryear_weeks"])]:
                    if value < minimum:
                        reasons.append(f"{key}<{minimum}")
            row["annual_comparison_available"] = all(np.isfinite(row[f"delta_net_pips_{year}"]) for year in YEARS)
            row["annual_positive_both"] = all(row[f"mean_net_pips_{year}"] > 0 for year in YEARS)
            row["annual_delta_positive_both"] = row["annual_comparison_available"] and all(row[f"delta_net_pips_{year}"] > 0 for year in YEARS)
            row["sample_gates_pass"] = not reasons
            row["insufficient_sample"] = bool(reasons)
            row["sample_gate_reasons"] = ";".join(reasons)
            if not reasons:
                digest = sha256(f"{config.get('seed', 20261015)}|{cell_id}".encode()).digest()
                rng = np.random.default_rng(int.from_bytes(digest[:8], "little"))
                boot = calendar_week_bootstrap(s, c, rng, reps=bootstrap_reps, metric="net_pips")
                valid = np.isfinite(boot["strategy"]) & np.isfinite(boot["difference"])
                row["bootstrap_valid"] = int(valid.sum())
                if valid.any():
                    row["net_ci_low"], row["net_ci_high"] = np.quantile(boot["strategy"][valid], [.025, .975])
                    row["delta_ci_low"], row["delta_ci_high"] = np.quantile(boot["difference"][valid], [.025, .975])
                    centered = boot["difference"][valid] - row["delta_net_pips"]
                    row["p_delta_net_pips"] = (1 + np.count_nonzero(np.abs(centered) >= abs(row["delta_net_pips"]))) / (row["bootstrap_valid"] + 1)
            rows.append(row)
    result = pd.DataFrame(rows)
    result["p_delta_net_pips_holm"] = holm_adjust(result.p_delta_net_pips, family_size=total)
    result["exploratory_hypothesis"] = (result.sample_gates_pass & result.annual_positive_both
        & result.annual_delta_positive_both & result.mean_net_pips.gt(0) & result.delta_net_pips.gt(0)
        & result.net_ci_low.gt(0) & result.delta_ci_low.gt(0) & result.p_delta_net_pips_holm.lt(.05)
        & result.bootstrap_valid.eq(bootstrap_reps))
    result.attrs.update({"count": len(result), "cap": cap, "cells_per_method_side": CELLS_PER_METHOD_SIDE,
                         "family_size": total, "sample_thresholds": thresholds})
    return result
