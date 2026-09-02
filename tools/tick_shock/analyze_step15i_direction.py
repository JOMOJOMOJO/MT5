#!/usr/bin/env python3
"""Step 15I development-only high-movement and direction study.

The analysis consumes the already-recorded causal Step 15G decision features
and Bid/Ask first-touch outcomes.  It does not reconstruct tick paths or tune
the preregistered 30/70 percentiles against outcomes.
"""
from __future__ import annotations

import hashlib
import math
from bisect import bisect_right, insort
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats

ROOT = Path(__file__).resolve().parents[2]
RUN = ROOT / "reports/backtest/runs/20260901_ts15g_economic_path_r3_202503"
OUT = ROOT / "reports/analysis/tick_shock/step15i"
FEATURE_REGISTRY = ROOT / "reports/analysis/tick_shock/step15f/feature_registry.csv"
SEED = 20260902
DECISION_SECONDS = 60
HORIZON_SECONDS = 900
RR = 1.2
MIN_HISTORY = 100
VALID_RESULTS = {"TP_FIRST", "SL_FIRST", "TIMEOUT"}


def write(df: pd.DataFrame, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUT / name, index=False)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest().upper()


def load_population() -> tuple[pd.DataFrame, list[str]]:
    raw = pd.read_csv(RUN / "economic_first_touch.csv", low_memory=False)
    raw = raw[
        np.isclose(raw.requested_rr, RR)
        & raw.decision_seconds.eq(DECISION_SECONDS)
        & raw.horizon_seconds.eq(HORIZON_SECONDS)
        & raw.subject_type.eq("SHOCK")
    ].copy()
    keys = ["subject_id", "market_cluster_id", "symbol", "shock_direction", "decision_seconds", "horizon_seconds", "anchor_msc"]
    values = ["result", "first_touch_msc", "gross_r", "spread_only_r", "stressed_r", "mfe", "mae", "signal_quote_msc", "signal_processing_msc", "entry_quote_msc", "entry_processing_msc", "atr14_m5", "invalid_reason", "secondary_result"]
    sides = []
    for action in ("CONTINUATION", "REVERSAL"):
        side = raw.loc[raw.action.eq(action), keys + values].copy()
        side = side.rename(columns={c: f"{action.lower()}_{c}" for c in values})
        sides.append(side)
    paths = sides[0].merge(sides[1], on=keys, how="outer", validate="one_to_one")

    registry = pd.read_csv(FEATURE_REGISTRY)
    feature_names = registry.name.tolist()
    features = pd.read_csv(RUN / "episode_context_features.csv", low_memory=False)
    features = features[features.decision_seconds.eq(DECISION_SECONDS)].copy()
    features = features.rename(columns={"episode_id": "subject_id", "status": "feature_status", "reason": "feature_reason"})
    feature_cols = ["subject_id", "target_msc", "quote_msc", "processing_msc", "feature_status", "feature_reason"] + feature_names
    paths = paths.merge(features[feature_cols], on="subject_id", how="left", validate="one_to_one")

    episodes = pd.read_csv(RUN / "medium_horizon_episode_summary.csv", low_memory=False).rename(columns={"episode_id": "subject_id"})
    paths = paths.merge(episodes[["subject_id", "episode_status", "validation_status"]], on="subject_id", how="left", validate="one_to_one")
    paths = paths.replace([np.inf, -np.inf], np.nan)
    paths["server_time"] = pd.to_datetime(paths.anchor_msc, unit="ms", utc=True)
    paths["server_day"] = paths.server_time.dt.strftime("%Y-%m-%d")
    paths["server_hour"] = paths.server_time.dt.hour
    paths["day_of_week"] = paths.server_time.dt.day_name()
    paths["session"] = np.select(
        [paths.server_hour.between(13, 15), paths.server_hour.between(0, 7), paths.server_hour.between(8, 12), paths.server_hour.between(16, 20)],
        ["OVERLAP", "TOKYO", "LONDON", "NEW_YORK"],
        default="OTHER",
    )
    both_valid = paths.continuation_result.isin(VALID_RESULTS) & paths.reversal_result.isin(VALID_RESULTS)
    paths["analysis_eligible"] = (
        paths.symbol.ne("GBPUSD")
        & paths.feature_status.eq("AVAILABLE")
        & paths.episode_status.eq("COMPLETE_900S")
        & paths.validation_status.eq("VALID")
        & both_valid
    )
    paths["exclusion_reason"] = np.select(
        [paths.symbol.eq("GBPUSD"), paths.feature_status.ne("AVAILABLE"), ~paths.episode_status.eq("COMPLETE_900S"), ~paths.validation_status.eq("VALID"), ~both_valid],
        ["GBPUSD_GENERATED_FALLBACK", "FEATURE_UNAVAILABLE", "EPISODE_INCOMPLETE", "EPISODE_VALIDATION_INVALID", "PATH_INVALID"],
        default="",
    )
    return paths, feature_names


def direction_label(row: pd.Series) -> str:
    cont = row.continuation_result == "TP_FIRST"
    rev = row.reversal_result == "TP_FIRST"
    if cont and rev:
        ct, rt = row.continuation_first_touch_msc, row.reversal_first_touch_msc
        if pd.isna(ct) or pd.isna(rt) or int(ct) == int(rt):
            return "AMBIGUOUS_SAME_MSC"
        return "CONTINUATION" if int(ct) < int(rt) else "REVERSAL"
    if cont:
        return "CONTINUATION"
    if rev:
        return "REVERSAL"
    return "NEUTRAL_TIMEOUT"


def add_causal_filter(frame: pd.DataFrame) -> pd.DataFrame:
    out = frame.copy()
    for col in ["spread_atr_threshold", "tick_activity_threshold", "atr_threshold", "spread_atr_percentile", "tick_activity_percentile", "atr_percentile"]:
        out[col] = np.nan
    out["quantile_history_n"] = 0
    eligible = out[out.analysis_eligible].sort_values(["anchor_msc", "market_cluster_id", "subject_id"])
    for symbol, group in eligible.groupby("symbol", sort=False):
        histories = {"spread_atr_ratio": [], "tick_activity": [], "atr14_m5": []}
        for idx, row in group.iterrows():
            history_n = len(histories["spread_atr_ratio"])
            out.at[idx, "quantile_history_n"] = history_n
            if history_n >= MIN_HISTORY:
                specs = (("spread_atr_ratio", .30, "spread_atr"), ("tick_activity", .70, "tick_activity"), ("atr14_m5", .70, "atr"))
                for source, q, prefix in specs:
                    vals = histories[source]
                    if len(vals) < MIN_HISTORY or pd.isna(row[source]):
                        continue
                    out.at[idx, f"{prefix}_threshold"] = float(np.quantile(np.asarray(vals), q))
                    out.at[idx, f"{prefix}_percentile"] = bisect_right(vals, float(row[source])) / len(vals)
            for source, values in histories.items():
                if pd.notna(row[source]):
                    insort(values, float(row[source]))
    out["quantile_ready"] = out[["spread_atr_threshold", "tick_activity_threshold", "atr_threshold"]].notna().all(axis=1)
    out["low_spread_atr"] = out.quantile_ready & out.spread_atr_ratio.le(out.spread_atr_threshold)
    out["high_tick_activity"] = out.quantile_ready & out.tick_activity.ge(out.tick_activity_threshold)
    out["high_atr"] = out.quantile_ready & out.atr14_m5.ge(out.atr_threshold)
    out["high_movement_filter"] = out.low_spread_atr & out.high_tick_activity & out.high_atr
    out["direction_label"] = out.apply(direction_label, axis=1)
    out["directional_range_position"] = np.where(out.shock_direction.eq("LONG"), out.daily_range_position, 1.0 - out.daily_range_position)
    out["max_abs_move_atr"] = out[["continuation_mfe", "continuation_mae"]].max(axis=1) / out.atr14_m5
    out["max_abs_move_price"] = out[["continuation_mfe", "continuation_mae"]].max(axis=1)
    out["either_tp"] = out.direction_label.isin(["CONTINUATION", "REVERSAL"])
    out["selected_outcome_r"] = np.select(
        [out.direction_label.eq("CONTINUATION"), out.direction_label.eq("REVERSAL")],
        [out.continuation_stressed_r, out.reversal_stressed_r],
        default=np.maximum(out.continuation_stressed_r, out.reversal_stressed_r),
    )
    return out


def cluster_bootstrap_diff(frame: pd.DataFrame, value: str, flag: str, repetitions: int = 1000) -> tuple[float, float]:
    x = frame[["market_cluster_id", value, flag]].dropna()
    clusters = x.market_cluster_id.unique()
    if len(clusters) < 2 or x[flag].nunique() < 2:
        return math.nan, math.nan
    groups = {c: x[x.market_cluster_id.eq(c)] for c in clusters}
    rng = np.random.default_rng(SEED + len(value))
    diffs = []
    for _ in range(repetitions):
        sample = rng.choice(clusters, len(clusters), replace=True)
        boot = pd.concat([groups[c] for c in sample], ignore_index=True)
        a, b = boot.loc[boot[flag], value], boot.loc[~boot[flag], value]
        if len(a) and len(b):
            diffs.append(float(a.mean() - b.mean()))
    return tuple(np.quantile(diffs, [.025, .975])) if diffs else (math.nan, math.nan)


def standardized_difference(a: pd.Series, b: pd.Series) -> float:
    a, b = a.dropna(), b.dropna()
    if len(a) < 2 or len(b) < 2:
        return math.nan
    pooled = math.sqrt((a.var(ddof=1) + b.var(ddof=1)) / 2)
    return float((a.mean() - b.mean()) / pooled) if pooled > 0 else math.nan


def wilson(successes: int, total: int) -> tuple[float, float]:
    if total <= 0:
        return math.nan, math.nan
    z = 1.959963984540054
    p = successes / total
    denominator = 1 + z * z / total
    center = (p + z * z / (2 * total)) / denominator
    half = z * math.sqrt(p * (1 - p) / total + z * z / (4 * total * total)) / denominator
    return center - half, center + half


def summarize_high_movement(data: pd.DataFrame) -> None:
    ready = data[data.analysis_eligible & data.quantile_ready].copy()
    metrics = {
        "continuation_mfe_price": ready.continuation_mfe,
        "continuation_mae_price": ready.continuation_mae,
        "max_abs_move_price": ready.max_abs_move_price,
        "continuation_mfe_atr": ready.continuation_mfe / ready.atr14_m5,
        "continuation_mae_atr": ready.continuation_mae / ready.atr14_m5,
        "max_abs_move_atr": ready.max_abs_move_atr,
        "either_tp_rate": ready.either_tp.astype(float),
        "continuation_tp_rate": ready.continuation_result.eq("TP_FIRST").astype(float),
        "reversal_tp_rate": ready.reversal_result.eq("TP_FIRST").astype(float),
        "both_timeout_rate": (ready.continuation_result.eq("TIMEOUT") & ready.reversal_result.eq("TIMEOUT")).astype(float),
    }
    rows = []
    for metric, values in metrics.items():
        ready[metric] = values
        a, b = ready.loc[ready.high_movement_filter, metric], ready.loc[~ready.high_movement_filter, metric]
        lo, hi = cluster_bootstrap_diff(ready, metric, "high_movement_filter")
        rows.append(dict(
            metric=metric, selected_episodes=len(a), selected_clusters=ready.loc[ready.high_movement_filter, "market_cluster_id"].nunique(),
            other_episodes=len(b), other_clusters=ready.loc[~ready.high_movement_filter, "market_cluster_id"].nunique(),
            selected_mean=a.mean(), other_mean=b.mean(), selected_median=a.median(), other_median=b.median(),
            selected_q25=a.quantile(.25), selected_q75=a.quantile(.75), other_q25=b.quantile(.25), other_q75=b.quantile(.75),
            mean_difference=a.mean() - b.mean(), bootstrap_low=lo, bootstrap_high=hi,
            standardized_difference=standardized_difference(a, b),
            mann_whitney_p=stats.mannwhitneyu(a.dropna(), b.dropna()).pvalue if a.notna().any() and b.notna().any() else math.nan,
        ))
    write(pd.DataFrame(rows), "high_movement_validation.csv")


def feature_outputs(data: pd.DataFrame, feature_names: list[str]) -> None:
    selected = data[data.analysis_eligible & data.high_movement_filter].copy()
    numeric = [f for f in feature_names if f in selected and selected[f].notna().sum() >= 10]
    numeric += ["directional_range_position", "spread_atr_percentile", "tick_activity_percentile", "atr_percentile"]
    summary_rows, contrast_rows, bin_rows = [], [], []
    for feature in numeric:
        for label, group in selected.groupby("direction_label"):
            x = group[feature].dropna()
            summary_rows.append(dict(feature=feature, label=label, episodes=len(x), clusters=group.loc[x.index, "market_cluster_id"].nunique(), mean=x.mean(), median=x.median(), q10=x.quantile(.1), q25=x.quantile(.25), q75=x.quantile(.75), q90=x.quantile(.9)))
        cont = selected.loc[selected.direction_label.eq("CONTINUATION"), feature].dropna()
        rev = selected.loc[selected.direction_label.eq("REVERSAL"), feature].dropna()
        rho_frame = selected[selected.direction_label.isin(["CONTINUATION", "REVERSAL"])][[feature, "direction_label"]].dropna()
        rho = stats.spearmanr(rho_frame[feature], rho_frame.direction_label.eq("CONTINUATION").astype(int)).statistic if len(rho_frame) > 2 else math.nan
        contrast_rows.append(dict(feature=feature, continuation_n=len(cont), reversal_n=len(rev), continuation_mean=cont.mean(), reversal_mean=rev.mean(), continuation_median=cont.median(), reversal_median=rev.median(), standardized_difference=standardized_difference(cont, rev), rank_biserial=2 * stats.mannwhitneyu(cont, rev).statistic / (len(cont) * len(rev)) - 1 if len(cont) and len(rev) else math.nan, spearman_direction=rho, p_value=stats.mannwhitneyu(cont, rev).pvalue if len(cont) and len(rev) else math.nan))

        ready = selected[selected.quantile_history_n.ge(MIN_HISTORY)].copy()
        if feature in ("spread_atr_percentile", "tick_activity_percentile", "atr_percentile"):
            percentile = ready[feature]
        else:
            percentile = pd.Series(np.nan, index=ready.index)
            for symbol, group in data[data.analysis_eligible].sort_values("anchor_msc").groupby("symbol"):
                history: list[float] = []
                for idx, row in group.iterrows():
                    if idx in ready.index and len(history) >= MIN_HISTORY and pd.notna(row[feature]):
                        percentile.at[idx] = bisect_right(history, float(row[feature])) / len(history)
                    if pd.notna(row[feature]):
                        insort(history, float(row[feature]))
        ready["_bin"] = pd.cut(percentile, [-np.inf, .2, .4, .6, .8, np.inf], labels=["LOW", "MID_LOW", "MID", "MID_HIGH", "HIGH"])
        for label, group in ready.groupby("_bin", observed=False):
            counts = group.direction_label.value_counts()
            directional = counts.get("CONTINUATION", 0) + counts.get("REVERSAL", 0)
            cont_n = int(counts.get("CONTINUATION", 0))
            cont_lo, cont_hi = wilson(cont_n, len(group))
            dir_lo, dir_hi = wilson(cont_n, directional)
            bin_rows.append(dict(feature=feature, bin=str(label), episodes=len(group), clusters=group.market_cluster_id.nunique(), continuation=cont_n, reversal=counts.get("REVERSAL", 0), neutral_timeout=counts.get("NEUTRAL_TIMEOUT", 0), ambiguous=counts.get("AMBIGUOUS_SAME_MSC", 0), continuation_rate=cont_n / len(group) if len(group) else math.nan, continuation_rate_ci_low=cont_lo, continuation_rate_ci_high=cont_hi, reversal_rate=counts.get("REVERSAL", 0) / len(group) if len(group) else math.nan, neutral_rate=counts.get("NEUTRAL_TIMEOUT", 0) / len(group) if len(group) else math.nan, continuation_given_directional=cont_n / directional if directional else math.nan, continuation_given_directional_ci_low=dir_lo, continuation_given_directional_ci_high=dir_hi, continuation_mean_r=group.continuation_stressed_r.mean(), reversal_mean_r=group.reversal_stressed_r.mean(), support_gate=group.market_cluster_id.nunique() >= 20))
    write(pd.DataFrame(summary_rows), "feature_summary.csv")
    contrast = pd.DataFrame(contrast_rows)
    valid = contrast.p_value.notna()
    order = contrast.loc[valid, "p_value"].sort_values().index
    adjusted = pd.Series(np.nan, index=contrast.index)
    running = 0.0
    total = len(order)
    for rank, idx in enumerate(order):
        running = max(running, min(1.0, float(contrast.at[idx, "p_value"]) * (total - rank)))
        adjusted.at[idx] = running
    contrast["holm_adjusted_p"] = adjusted
    write(contrast.sort_values("standardized_difference", key=lambda s: s.abs(), ascending=False), "continuation_vs_reversal_feature_comparison.csv")
    write(pd.DataFrame(bin_rows), "feature_bin_comparison.csv")


def candidate_outputs(data: pd.DataFrame) -> None:
    x = data[data.analysis_eligible & data.high_movement_filter & ~data.direction_label.eq("AMBIGUOUS_SAME_MSC")].copy()
    past_range = np.where(x.directional_range_position.ge(.8), "CONTINUATION", np.where(x.directional_range_position.le(.2), "REVERSAL", "ABSTAIN"))
    candidates = {
        "M15_ALIGNMENT": np.where(x.shock_alignment_m15.eq(1), "CONTINUATION", np.where(x.shock_alignment_m15.eq(-1), "REVERSAL", "ABSTAIN")),
        "PRE_MOMENTUM_5M": np.where(x.shock_pre_momentum_5m.gt(0), "CONTINUATION", np.where(x.shock_pre_momentum_5m.lt(0), "REVERSAL", "ABSTAIN")),
        "DIRECTIONAL_RANGE_POSITION": past_range,
    }
    candidates["M15_AND_PRE_MOMENTUM"] = np.where(candidates["M15_ALIGNMENT"] == candidates["PRE_MOMENTUM_5M"], candidates["M15_ALIGNMENT"], "ABSTAIN")
    rows = []
    for name, prediction in candidates.items():
        q = x.assign(prediction=prediction)
        q = q[q.prediction.ne("ABSTAIN")]
        correct = q.prediction.eq(q.direction_label)
        cont_sel = q[q.prediction.eq("CONTINUATION")]
        rev_sel = q[q.prediction.eq("REVERSAL")]
        rows.append(dict(hypothesis=name, eligible_episodes=len(x), selected_episodes=len(q), selected_clusters=q.market_cluster_id.nunique(), coverage=len(q) / len(x) if len(x) else math.nan, directional_accuracy=correct.mean() if len(q) else math.nan, continuation_selected=len(cont_sel), continuation_precision=cont_sel.direction_label.eq("CONTINUATION").mean() if len(cont_sel) else math.nan, reversal_selected=len(rev_sel), reversal_precision=rev_sel.direction_label.eq("REVERSAL").mean() if len(rev_sel) else math.nan, neutral_rate=q.direction_label.eq("NEUTRAL_TIMEOUT").mean() if len(q) else math.nan, selected_action_r=np.where(q.prediction.eq("CONTINUATION"), q.continuation_stressed_r, q.reversal_stressed_r).mean() if len(q) else math.nan, support_gate=q.market_cluster_id.nunique() >= 20))
    write(pd.DataFrame(rows), "candidate_hypothesis_comparison.csv")


def population_outputs(data: pd.DataFrame) -> None:
    detector = pd.read_csv(RUN / "detector_features.csv", usecols=["event_id", "market_cluster_id"])
    detector_rows = len(detector)
    steps = [
        ("STATISTICAL_EVENTS", detector_rows, detector.market_cluster_id.nunique(), "formal Step 15G detector rows"),
        ("PERSISTENT_EPISODES", len(data), data.market_cluster_id.nunique(), "TAIL_V1_PERSISTENT episodes"),
        ("ANALYSIS_ELIGIBLE", int(data.analysis_eligible.sum()), data.loc[data.analysis_eligible, "market_cluster_id"].nunique(), "valid +60s RR1.2 900s paths and causal features; GBPUSD excluded"),
        ("CAUSAL_QUANTILE_READY", int((data.analysis_eligible & data.quantile_ready).sum()), data.loc[data.analysis_eligible & data.quantile_ready, "market_cluster_id"].nunique(), "100 strictly earlier same-symbol eligible episodes"),
        ("HIGH_MOVEMENT_FILTER", int(data.high_movement_filter.sum()), data.loc[data.high_movement_filter, "market_cluster_id"].nunique(), "low spread/ATR AND high activity AND high M5 ATR"),
    ]
    write(pd.DataFrame(steps, columns=["stage", "episode_or_row_count", "market_clusters", "definition"]), "population_funnel.csv")
    excluded = data.loc[~data.analysis_eligible, "exclusion_reason"].value_counts(dropna=False).rename_axis("reason").reset_index(name="episodes")
    not_ready = int((data.analysis_eligible & ~data.quantile_ready).sum())
    excluded = pd.concat([excluded, pd.DataFrame([{"reason": "INSUFFICIENT_CAUSAL_QUANTILE_HISTORY", "episodes": not_ready}])], ignore_index=True)
    write(excluded, "population_exclusions.csv")
    selected = data[data.high_movement_filter]
    dimensions = []
    for dim in ["symbol", "session", "server_day", "day_of_week", "shock_direction"]:
        for value, group in selected.groupby(dim, dropna=False):
            dimensions.append(dict(dimension=dim, value=value, episodes=len(group), market_clusters=group.market_cluster_id.nunique()))
    write(pd.DataFrame(dimensions), "high_movement_distribution.csv")
    labels = selected.groupby("direction_label").agg(episodes=("subject_id", "size"), market_clusters=("market_cluster_id", "nunique"), mean_selected_outcome_r=("selected_outcome_r", "mean")).reset_index()
    write(labels, "direction_label_counts.csv")


def compact_output(data: pd.DataFrame, feature_names: list[str]) -> None:
    cols = list(dict.fromkeys([
        "subject_id", "market_cluster_id", "symbol", "anchor_msc", "server_day", "server_hour", "session", "day_of_week", "shock_direction",
        "target_msc", "quote_msc", "processing_msc", "spread_atr_ratio", "tick_activity", "atr14_m5", "spread_atr_threshold", "tick_activity_threshold", "atr_threshold",
        "quantile_history_n", "quantile_ready", "low_spread_atr", "high_tick_activity", "high_atr", "high_movement_filter", "direction_label", "selected_outcome_r",
        "continuation_result", "reversal_result", "continuation_first_touch_msc", "reversal_first_touch_msc", "continuation_stressed_r", "reversal_stressed_r",
        "continuation_mfe", "continuation_mae", "max_abs_move_price", "max_abs_move_atr", "analysis_eligible", "exclusion_reason",
    ] + feature_names))
    compact = data[cols].rename(columns={"subject_id": "episode_id", "anchor_msc": "timestamp_msc"})
    write(compact, "episode_direction_dataset.csv")


def qa_outputs(data: pd.DataFrame) -> None:
    source_time_cols = [c for c in data.columns if c.endswith("_source_msc")]
    cluster_span = data[data.analysis_eligible].groupby("market_cluster_id").anchor_msc.agg(lambda x: x.max() - x.min())
    checks = [
        ("duplicate_episode", int(data.subject_id.duplicated().sum()), 0),
        ("duplicate_event_cluster_symbol_time", int(data.duplicated(["symbol", "shock_direction", "anchor_msc"]).sum()), 0),
        ("entry_before_signal_processing_cont", int((data.continuation_entry_quote_msc < data.continuation_signal_processing_msc).fillna(False).sum()), 0),
        ("entry_before_signal_processing_rev", int((data.reversal_entry_quote_msc < data.reversal_signal_processing_msc).fillna(False).sum()), 0),
        ("feature_quote_after_processing", int((data.quote_msc > data.processing_msc).fillna(False).sum()), 0),
        ("feature_clock_after_decision", int(sum((data[c] > data.processing_msc).fillna(False).sum() for c in source_time_cols)), 0),
        ("ambiguous_same_msc", int(data.direction_label.eq("AMBIGUOUS_SAME_MSC").sum()), 0),
        ("market_cluster_span_over_2000ms", int(cluster_span.gt(2000).sum()), 0),
        ("eligible_invalid_path_result", int((data.analysis_eligible & (~data.continuation_result.isin(VALID_RESULTS) | ~data.reversal_result.isin(VALID_RESULTS))).sum()), 0),
        ("orders", 0, 0),
    ]
    qa = pd.DataFrame(checks, columns=["check", "actual", "expected"])
    qa["status"] = np.where(qa.actual.eq(qa.expected), "PASS", "FAIL")
    write(qa, "qa_checks.csv")
    sources = [RUN / "economic_first_touch.csv", RUN / "episode_context_features.csv", RUN / "medium_horizon_episode_summary.csv", RUN / "detector_features.csv", FEATURE_REGISTRY, ROOT / "docs/research/tick_shock/15i_direction_prediction_preanalysis.md"]
    write(pd.DataFrame([{"path": p.relative_to(ROOT).as_posix(), "sha256": sha256(p)} for p in sources]), "source_hashes.csv")


def main() -> None:
    data, features = load_population()
    data = add_causal_filter(data)
    compact_output(data, features)
    population_outputs(data)
    summarize_high_movement(data)
    feature_outputs(data, features)
    candidate_outputs(data)
    qa_outputs(data)
    write(pd.DataFrame([{
        "trial_id": "TS15I-T01", "decision_seconds": DECISION_SECONDS, "horizon_seconds": HORIZON_SECONDS, "requested_rr": RR,
        "spread_atr_quantile": .30, "tick_activity_quantile": .70, "atr_quantile": .70, "minimum_prior_same_symbol_episodes": MIN_HISTORY,
        "development_window": "2025-03-01/2025-04-01", "status": "DEVELOPMENT_ONLY"
    }]), "trial_registry.csv")


if __name__ == "__main__":
    main()
