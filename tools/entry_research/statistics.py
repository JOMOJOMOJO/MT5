"""Descriptive summaries and calendar-week clustered research inference.

The matched random replicates are averaged, never counted as independent
observations. Strategy and controls share the same resampled calendar weeks.
Inference is exploratory: six initial method/direction tests at horizon 10 are
the prespecified family, and all other horizons are descriptive.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

METRICS = ["gross_pips", "net_pips", "gross_atr", "net_atr", "mfe_pips", "mae_pips", "mfe_atr", "mae_atr"]


def holm_adjust(p_values, family_size: int | None = None) -> np.ndarray:
    """Holm FWER correction, reserving unavailable hypotheses as p=1.

    NaN input positions remain NaN; they still count in the hypothesis family.
    ``family_size`` can reserve additional prespecified but unobserved tests.
    """
    p = np.asarray(p_values, dtype=float)
    if p.ndim != 1 or np.any((p[np.isfinite(p)] < 0) | (p[np.isfinite(p)] > 1)) or np.isinf(p).any():
        raise ValueError("p values must be a one-dimensional array in [0, 1] or NaN")
    family = len(p) if family_size is None else family_size
    if family < len(p) or int(family) != family:
        raise ValueError("family_size must be an integer at least len(p_values)")
    result = np.full(len(p), np.nan)
    available = np.flatnonzero(np.isfinite(p))
    order = available[np.argsort(p[available], kind="stable")]
    if len(order):
        result[order] = np.minimum(1.0, np.maximum.accumulate(p[order] * (family - np.arange(len(order)))))
    return result


def _with_metadata(outcomes: pd.DataFrame, events: pd.DataFrame) -> pd.DataFrame:
    required = {"candidate_id", "horizon", "complete", *METRICS}
    if missing := required - set(outcomes):
        raise ValueError(f"outcomes missing columns: {sorted(missing)}")
    if events["candidate_id"].isna().any() or events["candidate_id"].duplicated().any():
        raise ValueError("event candidate_id must be non-null and unique")
    if outcomes.duplicated(["candidate_id", "horizon"]).any():
        raise ValueError("outcomes must be unique by candidate_id and horizon")
    if not outcomes["candidate_id"].isin(events["candidate_id"]).all():
        raise ValueError("outcomes contain candidate IDs absent from their event table")
    # Event metadata is authoritative, even when the evaluator includes it too.
    columns = [c for c in ["candidate_id", "method", "side", "week", "entry_time", "entry_index", "symbol", "replicate"] if c in events]
    data = outcomes.drop(columns=[c for c in columns if c != "candidate_id" and c in outcomes]).merge(
        events[columns], on="candidate_id", how="left", validate="many_to_one"
    )
    if "week" not in data:
        if "entry_time" not in data:
            raise ValueError("events require week or entry_time for calendar-week clustering")
        # Retain the source clock. A naive broker timestamp is not declared UTC.
        times = pd.to_datetime(data["entry_time"], unit="s") if pd.api.types.is_numeric_dtype(data["entry_time"]) else pd.to_datetime(data["entry_time"])
        if isinstance(times.dtype, pd.DatetimeTZDtype):
            times = times.dt.tz_localize(None)
        data["week"] = times.dt.to_period("W-SUN").dt.start_time.dt.strftime("%Y-%m-%d")
    if data["week"].isna().any():
        raise ValueError("calendar week cannot be missing")
    data["week"] = data["week"].astype(str)
    complete = data["complete"].eq(True)
    numeric = data[METRICS].apply(pd.to_numeric, errors="coerce")
    if not np.isfinite(numeric.loc[complete].to_numpy(dtype=float)).all():
        raise ValueError("complete outcomes contain missing/non-finite metrics")
    data[METRICS] = numeric
    return data


def calendar_week_bootstrap(
    strategy: pd.DataFrame,
    controls: pd.DataFrame,
    rng: np.random.Generator,
    reps: int = 1000,
    metric: str = "net_pips",
    multiplicities: np.ndarray | None = None,
) -> dict:
    """Return week-cluster bootstrap distributions for a single stratum.

    Frames contain complete outcomes only. For each draw, the same week
    multiplicities weight strategy and every control replicate. Each control
    replicate uses its own summed numerator/denominator before their means are
    averaged. ``multiplicities`` is exposed for exact, hand-checkable tests.
    """
    if reps < 1:
        raise ValueError("reps must be positive")
    if "replicate" not in controls:
        raise ValueError("controls require replicate")
    weeks = sorted(set(strategy["week"].astype(str)) | set(controls["week"].astype(str)))
    if not weeks:
        return {"strategy": np.full(reps, np.nan), "baseline": np.full(reps, np.nan), "difference": np.full(reps, np.nan), "weeks": 0}
    s = strategy.assign(week=strategy["week"].astype(str)).groupby("week")[metric].agg(["sum", "count"]).reindex(weeks, fill_value=0)
    c = controls.assign(week=controls["week"].astype(str)).groupby(["week", "replicate"])[metric].agg(["sum", "count"])
    replicates = sorted(controls["replicate"].unique())
    c_sum = c["sum"].unstack("replicate").reindex(index=weeks, columns=replicates).fillna(0).to_numpy(dtype=float) if replicates else np.zeros((len(weeks), 0))
    c_count = c["count"].unstack("replicate").reindex(index=weeks, columns=replicates).fillna(0).to_numpy(dtype=float) if replicates else np.zeros((len(weeks), 0))
    if multiplicities is None:
        weights = rng.multinomial(len(weeks), np.full(len(weeks), 1.0 / len(weeks)), size=reps)
    else:
        weights = np.asarray(multiplicities)
        if weights.ndim != 2 or weights.shape[1] != len(weeks) or np.any(weights < 0) or not np.equal(weights, np.floor(weights)).all() or not np.equal(weights.sum(axis=1), len(weeks)).all():
            raise ValueError("multiplicities must be nonnegative integer week counts summing to number of weeks")
    sn, sd = weights @ s["sum"].to_numpy(dtype=float), weights @ s["count"].to_numpy(dtype=float)
    with np.errstate(divide="ignore", invalid="ignore"):
        boot_strategy = sn / sd
        replicate_means = (weights @ c_sum) / (weights @ c_count)
    # A missing replicate is not silently discarded: keep the draw undefined.
    boot_baseline = replicate_means.mean(axis=1) if replicates else np.full(len(weights), np.nan)
    return {"strategy": boot_strategy, "baseline": boot_baseline, "difference": boot_strategy - boot_baseline, "weeks": len(weeks)}


def _interval(values: np.ndarray) -> tuple[float, float, int]:
    valid = values[np.isfinite(values)]
    if not len(valid):
        return np.nan, np.nan, 0
    low, high = np.quantile(valid, [0.025, 0.975])
    return float(low), float(high), len(valid)


def _nonoverlap(data: pd.DataFrame, horizon: int) -> pd.DataFrame:
    if "entry_index" not in data or data.empty:
        return data.iloc[:0]
    chosen = []
    # Independent symbols may run concurrently. Within a symbol retain the
    # earliest event then skip every event sharing its observation interval.
    for _, group in data.groupby("symbol", sort=True) if "symbol" in data else [(None, data)]:
        next_index = -np.inf
        for idx, entry in group.sort_values(["entry_index", "candidate_id"])["entry_index"].items():
            if entry >= next_index:
                chosen.append(idx)
                next_index = entry + horizon
    return data.loc[chosen]


def summarize(
    outcomes: pd.DataFrame,
    candidates: pd.DataFrame,
    control_outcomes: pd.DataFrame,
    controls: pd.DataFrame,
    seed: int,
    bootstrap_reps: int = 1000,
) -> pd.DataFrame:
    """Summarize each method/direction/horizon without pseudoreplication.

    Percentile 95% intervals use source-clock Monday calendar weeks. They
    preserve within-week dependence and are not evidence of independence
    between adjacent weeks. Horizon-10 centered-bootstrap two-sided p values
    are Holm-corrected over at least the six prespecified initial tests.
    """
    if bootstrap_reps < 1 or int(bootstrap_reps) != bootstrap_reps:
        raise ValueError("bootstrap_reps must be a positive integer")
    s_all, c_all = _with_metadata(outcomes, candidates), _with_metadata(control_outcomes, controls)
    if "replicate" not in c_all:
        raise ValueError("control events require replicate")
    rng = np.random.default_rng(seed)
    rows = []
    methods = sorted(candidates["method"].unique())
    horizons = sorted(outcomes["horizon"].unique())
    for method in methods:
        for side in ["LONG", "SHORT"]:
            events = candidates.loc[candidates["method"].eq(method) & candidates["side"].eq(side)]
            for horizon in horizons:
                ss = s_all.loc[s_all["method"].eq(method) & s_all["side"].eq(side) & s_all["horizon"].eq(horizon)]
                cc = c_all.loc[c_all["method"].eq(method) & c_all["side"].eq(side) & c_all["horizon"].eq(horizon)]
                s, c = ss.loc[ss["complete"].eq(True)], cc.loc[cc["complete"].eq(True)]
                row = {
                    "method": method, "side": side, "horizon": int(horizon),
                    "n_candidates": len(events), "n_complete": len(s), "n_incomplete": len(ss) - len(s),
                    "n_outcomes_missing": len(events) - len(ss),
                    "n_baseline_complete_total": len(c), "baseline_repeats": int(cc["replicate"].nunique()),
                    "n_strategy_weeks": int(s["week"].nunique()),
                    "thin_sample": len(s) < 100 or s["week"].nunique() < 20,
                    "ci_estimable": s["week"].nunique() >= 2 and c["week"].nunique() >= 2,
                    "inference": "prespecified_h10" if horizon == 10 else "descriptive_only",
                    "bootstrap_reps": bootstrap_reps,
                    "bootstrap_unit": "aligned_source_clock_calendar_week",
                    "p_delta_net_pips": np.nan, "p_delta_net_pips_holm": np.nan,
                }
                for metric in METRICS:
                    mean = float(s[metric].mean())
                    base = float(c.groupby("replicate")[metric].mean().mean())
                    row[f"mean_{metric}"] = mean
                    row[f"median_{metric}"] = float(s[metric].median())
                    row[f"baseline_mean_{metric}"] = base
                    row[f"delta_{metric}"] = mean - base
                nonoverlap = _nonoverlap(s, int(horizon))
                row["n_nonoverlap"] = len(nonoverlap)
                row["n_overlapping"] = len(s) - len(nonoverlap)
                row["nonoverlap_mean_net_pips"] = float(nonoverlap["net_pips"].mean())
                row["baseline_replicate_mean_net_pips_sd"] = float(c.groupby("replicate")["net_pips"].mean().std(ddof=1))
                row["n_consecutive_direction"] = int(events.sort_values(["symbol", "entry_index"]).groupby("symbol")["entry_index"].diff().eq(1).sum()) if {"symbol", "entry_index"} <= set(events) else np.nan
                week_count = len(set(s["week"]) | set(c["week"]))
                weights = rng.multinomial(week_count, np.full(week_count, 1.0 / week_count), size=bootstrap_reps) if week_count else None
                for metric in ["net_pips", "net_atr"]:
                    boot = calendar_week_bootstrap(s, c, rng, bootstrap_reps, metric, weights)
                    row["n_calendar_weeks"] = boot["weeks"]
                    for distribution, prefix in [("strategy", f"mean_{metric}"), ("difference", f"delta_{metric}")]:
                        low, high, valid = _interval(boot[distribution])
                        if not row["ci_estimable"]:
                            low, high = np.nan, np.nan
                        row[f"{prefix}_ci_low"], row[f"{prefix}_ci_high"] = low, high
                        row[f"{prefix}_bootstrap_valid"] = valid
                    if metric == "net_pips" and horizon == 10 and s["week"].nunique() >= 2:
                        valid = boot["difference"][np.isfinite(boot["difference"])]
                        observed = row["delta_net_pips"]
                        if len(valid) and np.isfinite(observed):
                            row["p_delta_net_pips"] = (1 + np.count_nonzero(np.abs(valid - observed) >= abs(observed))) / (len(valid) + 1)
                rows.append(row)
    result = pd.DataFrame(rows)
    if len(result):
        primary = result["horizon"].eq(10)
        family_size = max(6, len(methods) * 2)
        result.loc[primary, "p_delta_net_pips_holm"] = holm_adjust(result.loc[primary, "p_delta_net_pips"], family_size)
        result["holm_family_size"] = family_size
        result["holm_reject_005"] = result["p_delta_net_pips_holm"].lt(0.05)
    return result
