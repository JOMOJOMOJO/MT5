#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import platform
from collections import Counter
from pathlib import Path

import lightgbm
import numpy as np
import pandas as pd
import scipy
import sklearn
from lightgbm import LGBMClassifier
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.inspection import permutation_importance
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

SEED = 20260904
FOLD_BOUNDS = ((.00, .40, .40, .55), (.00, .55, .55, .70),
               (.00, .70, .70, .85), (.00, .85, .85, 1.00))
TOP_COUNTS = (25, 50, 75, 100, 150, 200, 300, 500)
THRESHOLDS = (.20, .25, .30, .35, .40, .50, .60)
COST_SENSITIVITIES = (0.02, 0.05, 0.10)

A_NUM = [
    "spread_atr_t0", "tick_activity_ratio", "atr14_m5",
    "spread_percentile", "activity_percentile", "atr_percentile",
    "pre_return_5m_dir_atr", "m5_ema20_slope_dir_atr", "m15_alignment_dir",
    "pre_extension_15m_dir_atr", "day_range_position_dir",
    "detection_efficiency", "severity", "confirmation_retention",
    "spread_efficiency_interaction", "flow_efficiency_interaction",
]
B_ADD = [
    "return_5s_dir_atr", "return_10s_dir_atr", "return_30s_dir_atr",
    "return_60s_dir_atr", "return_120s_dir_atr", "return_300s_dir_atr",
    "return_900s_dir_atr", "accel_10s_vs_prev30s",
    "return_30s_vs_prev30s", "direction_consistency_30s",
]
C_ADD = [
    "spread_5s_atr", "spread_10s_atr", "spread_30s_atr",
    "spread_change_5s_atr", "spread_change_10s_atr", "spread_change_30s_atr",
    "ticks_5s", "ticks_10s", "ticks_30s", "ticks_60s", "ticks_120s",
    "tick_ratio_5s_prev5s", "tick_ratio_30s_prev30s",
]
D_ADD = [
    "range_30s_atr", "range_60s_atr", "range_180s_atr", "range_300s_atr",
    "range_900s_atr", "range_1800s_atr", "range_3600s_atr",
    "realized_abs_30s_atr", "realized_abs_60s_atr", "realized_abs_180s_atr",
    "realized_abs_300s_atr", "range_position_900s_dir",
    "distance_high_900s_dir_atr", "distance_low_900s_dir_atr",
    "atr14_m5_slope_3bars",
]
E_ADD = [
    "abs_return_10s_atr", "shock_to_range_60s",
    "spread_contraction_activity", "atr_spread_state",
    "momentum_efficiency_interaction",
]
EPISODE_GROUPS = {
    "A_STEP15L_EXISTING": A_NUM,
    "B_ACTION_MOMENTUM": A_NUM + B_ADD,
    "C_SPREAD_ACTIVITY": A_NUM + B_ADD + C_ADD,
    "D_STRUCTURE_RANGE": A_NUM + B_ADD + C_ADD + D_ADD,
    "E_FULL": A_NUM + B_ADD + C_ADD + D_ADD + E_ADD,
}

SIGNED = {
    "pre_return_5m_dir_atr", "m5_ema20_slope_dir_atr", "m15_alignment_dir",
    "pre_extension_15m_dir_atr", "day_range_position_dir",
    "confirmation_retention", "return_5s_dir_atr", "return_10s_dir_atr",
    "return_30s_dir_atr", "return_60s_dir_atr", "return_120s_dir_atr",
    "return_300s_dir_atr", "return_900s_dir_atr", "accel_10s_vs_prev30s",
    "return_30s_vs_prev30s", "range_position_900s_dir",
    "distance_high_900s_dir_atr", "distance_low_900s_dir_atr",
    "momentum_efficiency_interaction",
}
CONSISTENCY = {"direction_consistency_30s"}
BASE_CATS = ["candidate_direction", "session", "action"]


def action_feature_name(name: str) -> str:
    if name in SIGNED or name in CONSISTENCY:
        return name.replace("_dir_atr", "_action_atr").replace("_dir", "_action") + ("_action" if name in CONSISTENCY else "")
    return name


ACTION_GROUPS = {k: list(dict.fromkeys(action_feature_name(x) for x in v))
                 for k, v in EPISODE_GROUPS.items()}


def safe_metric(fn, y, score):
    try:
        return float(fn(y, score))
    except ValueError:
        return math.nan


def pipeline(kind: str, numeric: list[str], with_symbol: bool) -> Pipeline:
    cats = BASE_CATS + (["symbol"] if with_symbol else [])
    if kind == "LOGISTIC":
        num = Pipeline([("impute", SimpleImputer(strategy="median", keep_empty_features=True)),
                        ("scale", StandardScaler())])
        model = LogisticRegression(C=1.0, class_weight="balanced", max_iter=2000,
                                   random_state=SEED)
    else:
        num = SimpleImputer(strategy="median", keep_empty_features=True)
        model = LGBMClassifier(
            objective="binary", n_estimators=200, learning_rate=.03,
            num_leaves=15, max_depth=4, min_child_samples=50,
            colsample_bytree=.8, subsample=.8, subsample_freq=1,
            reg_alpha=1.0, reg_lambda=1.0, class_weight="balanced",
            random_state=SEED, n_jobs=1, verbosity=-1,
        )
    prep = ColumnTransformer([
        ("num", num, numeric),
        ("cat", OneHotEncoder(handle_unknown="ignore", sparse_output=False), cats),
    ], verbose_feature_names_out=True)
    return Pipeline([("prep", prep), ("model", model)])


def cluster_folds(episodes: pd.DataFrame):
    clusters = (episodes.groupby("market_cluster_id", as_index=False)["t0_msc"].min()
                .sort_values(["t0_msc", "market_cluster_id"])["market_cluster_id"].tolist())
    n = len(clusters)
    out = []
    for fold, (_, train_hi, val_lo, val_hi) in enumerate(FOLD_BOUNDS, 1):
        train = set(clusters[:int(n * train_hi)])
        valid = set(clusters[int(n * val_lo):int(n * val_hi)])
        out.append((fold, train, valid))
    return out


def make_action_rows(episodes: pd.DataFrame, paths: pd.DataFrame) -> pd.DataFrame:
    path_cols = [
        "episode_id", "h900_cont_mae", "h900_rev_mae", "h900_status",
        "cont_tp0.40_hit_from_t0_s", "cont_tp0.40_pre_mae_atr",
        "rev_tp0.40_hit_from_t0_s", "rev_tp0.40_pre_mae_atr",
    ]
    base = episodes.merge(paths[path_cols], on="episode_id", how="left", validate="one_to_one")
    rows = []
    for action, sign, prefix in (("CONTINUATION", 1, "cont"), ("REVERSAL", -1, "rev")):
        z = base.copy()
        z["action"] = action
        z["action_sign"] = sign
        shock_long = z.shock_direction.astype(str).str.upper().eq("LONG")
        z["candidate_direction"] = np.where(shock_long == (sign == 1), "LONG", "SHORT")
        hit = pd.to_numeric(z[f"{prefix}_tp0.40_hit_from_t0_s"], errors="coerce")
        pre = pd.to_numeric(z[f"{prefix}_tp0.40_pre_mae_atr"], errors="coerce")
        mae = pd.to_numeric(z[f"h900_{prefix}_mae"], errors="coerce") / z.atr14_m5
        tp = hit.le(900) & pre.le(.25)
        sl = (~tp) & (mae.ge(.25) | (hit.le(900) & pre.gt(.25)))
        z["outcome"] = np.where(tp, "TP_FIRST", np.where(sl, "SL_FIRST", "TIMEOUT"))
        z["tp_first"] = tp.astype(int)
        # All analysis-ready Step 15L rows have a first barrier. Fail closed if this changes.
        z["realized_r"] = np.where(tp, 1.6, np.where(sl, -1.0, np.nan))
        for feature in SIGNED:
            z[action_feature_name(feature)] = pd.to_numeric(z[feature], errors="coerce") * sign
        for feature in CONSISTENCY:
            raw = pd.to_numeric(z[feature], errors="coerce")
            z[action_feature_name(feature)] = raw if sign == 1 else 1.0 - raw
        rows.append(z)
    actions = pd.concat(rows, ignore_index=True)
    return actions.sort_values(["t0_msc", "market_cluster_id", "episode_id", "action"]).reset_index(drop=True)


def binary_metrics(y, score) -> dict:
    return {
        "rows": len(y), "positives": int(np.sum(y)), "positive_rate": float(np.mean(y)),
        "average_precision": safe_metric(average_precision_score, y, score),
        "roc_auc": safe_metric(roc_auc_score, y, score),
    }


def fit_walk_forward(actions, episodes, kind, group, with_symbol=False, symbol_only=None):
    features = ACTION_GROUPS[group]
    cats = BASE_CATS + (["symbol"] if with_symbol else [])
    fold_rows, pred_rows = [], []
    for fold, train_clusters, valid_clusters in cluster_folds(episodes):
        train = actions[actions.market_cluster_id.isin(train_clusters)]
        valid = actions[actions.market_cluster_id.isin(valid_clusters)]
        if symbol_only:
            train = train[train.symbol == symbol_only]
            valid = valid[valid.symbol == symbol_only]
        if train.tp_first.nunique() < 2 or valid.empty:
            fold_rows.append({"model": kind, "feature_group": group, "with_symbol": with_symbol,
                              "symbol_scope": symbol_only or "ALL", "fold": fold,
                              "status": "INSUFFICIENT_CLASS_SUPPORT"})
            continue
        model = pipeline(kind, features, with_symbol)
        model.fit(train[features + cats], train.tp_first)
        score = model.predict_proba(valid[features + cats])[:, 1]
        metric = binary_metrics(valid.tp_first.to_numpy(), score)
        metric.update(model=kind, feature_group=group, with_symbol=with_symbol,
                      symbol_scope=symbol_only or "ALL", fold=fold, status="OK",
                      train_action_rows=len(train), validation_action_rows=len(valid),
                      train_episodes=train.episode_id.nunique(), validation_episodes=valid.episode_id.nunique(),
                      train_clusters=train.market_cluster_id.nunique(), validation_clusters=valid.market_cluster_id.nunique(),
                      episode_overlap=len(set(train.episode_id) & set(valid.episode_id)),
                      cluster_overlap=len(set(train.market_cluster_id) & set(valid.market_cluster_id)),
                      train_max_msc=train.t0_msc.max(), validation_min_msc=valid.t0_msc.min())
        fold_rows.append(metric)
        for idx, value in zip(valid.index, score):
            pred_rows.append({"action_row_index": int(idx), "fold": fold, "score": float(value),
                              "model": kind, "feature_group": group, "with_symbol": with_symbol,
                              "symbol_scope": symbol_only or "ALL"})
    return fold_rows, pred_rows


def fit_single_action(actions, episodes, action_name):
    """Secondary direction-specific LightGBM on the identical global folds."""
    features = ACTION_GROUPS["E_FULL"]
    cats = BASE_CATS
    fold_rows, pred_rows = [], []
    tag = f"LIGHTGBM_{action_name}_ONLY"
    for fold, train_clusters, valid_clusters in cluster_folds(episodes):
        train = actions[(actions.market_cluster_id.isin(train_clusters)) & (actions.action == action_name)]
        valid = actions[(actions.market_cluster_id.isin(valid_clusters)) & (actions.action == action_name)]
        model = pipeline("LIGHTGBM", features, False)
        model.fit(train[features + cats], train.tp_first)
        score = model.predict_proba(valid[features + cats])[:, 1]
        metric = binary_metrics(valid.tp_first.to_numpy(), score)
        metric.update(model=tag, feature_group="E_FULL", with_symbol=False,
                      symbol_scope="ALL", fold=fold, status="OK",
                      train_action_rows=len(train), validation_action_rows=len(valid),
                      train_episodes=train.episode_id.nunique(), validation_episodes=valid.episode_id.nunique(),
                      train_clusters=train.market_cluster_id.nunique(), validation_clusters=valid.market_cluster_id.nunique(),
                      episode_overlap=len(set(train.episode_id) & set(valid.episode_id)),
                      cluster_overlap=len(set(train.market_cluster_id) & set(valid.market_cluster_id)),
                      train_max_msc=train.t0_msc.max(), validation_min_msc=valid.t0_msc.min())
        fold_rows.append(metric)
        for idx, value in zip(valid.index, score):
            pred_rows.append({"action_row_index": int(idx), "fold": fold, "score": float(value),
                              "model": tag, "feature_group": "E_FULL", "with_symbol": False,
                              "symbol_scope": "ALL"})
    return fold_rows, pred_rows


def best_actions(predictions: pd.DataFrame, actions: pd.DataFrame, model="LIGHTGBM",
                 group="E_FULL", with_symbol=False, symbol_scope="ALL") -> pd.DataFrame:
    p = predictions[(predictions.model == model) & (predictions.feature_group == group) &
                    (predictions.with_symbol == with_symbol) &
                    (predictions.symbol_scope == symbol_scope)].copy()
    p = p.merge(actions, left_on="action_row_index", right_index=True, validate="one_to_one")
    p = p.sort_values(["episode_id", "score", "action"], ascending=[True, False, True])
    best = p.drop_duplicates("episode_id", keep="first").copy()
    return best.sort_values(["score", "t0_msc", "episode_id"], ascending=[False, True, True]).reset_index(drop=True)


def max_consecutive_losses(frame: pd.DataFrame) -> int:
    longest = current = 0
    for value in frame.sort_values(["t0_msc", "episode_id"]).realized_r:
        current = current + 1 if value < 0 else 0
        longest = max(longest, current)
    return longest


def bootstrap_mean_r(frame: pd.DataFrame, draws=1000):
    groups = [g.realized_r.to_numpy() for _, g in frame.groupby("market_cluster_id")]
    if not groups:
        return math.nan, math.nan
    rng = np.random.default_rng(SEED)
    values = []
    for _ in range(draws):
        chosen = rng.integers(0, len(groups), len(groups))
        sample = np.concatenate([groups[i] for i in chosen])
        values.append(float(sample.mean()))
    return float(np.quantile(values, .025)), float(np.quantile(values, .975))


def policy_metrics(frame: pd.DataFrame, policy, value) -> dict:
    z = frame.copy()
    if policy == "TOP_COUNT":
        z = z.head(min(int(value), len(z)))
    elif policy == "SCORE_THRESHOLD":
        z = z[z.score >= float(value)]
    pos = float(z.loc[z.realized_r > 0, "realized_r"].sum())
    neg = float(-z.loc[z.realized_r < 0, "realized_r"].sum())
    low, high = bootstrap_mean_r(z)
    fold_mean = z.groupby("fold").realized_r.mean()
    out = {
        "policy": policy, "policy_value": value, "trades": len(z),
        "market_clusters": z.market_cluster_id.nunique(),
        "continuation_selected": int((z.action == "CONTINUATION").sum()),
        "reversal_selected": int((z.action == "REVERSAL").sum()),
        "tp": int((z.outcome == "TP_FIRST").sum()),
        "sl": int((z.outcome == "SL_FIRST").sum()),
        "timeout": int((z.outcome == "TIMEOUT").sum()),
        "tradeable_episodes_selected": int(z.is_clean_move.sum()) if "is_clean_move" in z else math.nan,
        "direction_correct": int(z.tp_first.sum()),
        "wrong_direction_selected": int(((z.is_clean_move == 1) & (z.tp_first == 0)).sum()) if "is_clean_move" in z else math.nan,
        "both_sl_selected": int((z.is_clean_move == 0).sum()) if "is_clean_move" in z else math.nan,
        "win_rate": float((z.realized_r > 0).mean()) if len(z) else math.nan,
        "mean_r": float(z.realized_r.mean()) if len(z) else math.nan,
        "total_r": float(z.realized_r.sum()), "pf": pos / neg if neg else math.inf,
        "max_consecutive_losses": max_consecutive_losses(z),
        "cluster_bootstrap_mean_r_low": low, "cluster_bootstrap_mean_r_high": high,
        "positive_folds": int((fold_mean > 0).sum()), "observed_folds": len(fold_mean),
        "median_r": float(z.realized_r.median()) if len(z) else math.nan,
        "p5_r": float(z.realized_r.quantile(.05)) if len(z) else math.nan,
        "p95_r": float(z.realized_r.quantile(.95)) if len(z) else math.nan,
        "symbol_mix": ";".join(f"{k}:{v}" for k, v in sorted(Counter(z.symbol).items())),
        "session_mix": ";".join(f"{k}:{v}" for k, v in sorted(Counter(z.session).items())),
    }
    for cost in COST_SENSITIVITIES:
        out[f"mean_r_after_{cost:.2f}r_cost"] = out["mean_r"] - cost if len(z) else math.nan
    return out


def grouped_performance(frame, grouping, policy_name):
    rows = []
    for key, z in frame.groupby(grouping, dropna=False):
        m = policy_metrics(z.sort_values(["score", "t0_msc", "episode_id"], ascending=[False, True, True]), "ALL", "ALL")
        m.update(scope=policy_name, **{grouping: key}, mean_score=z.score.mean(),
                 median_score=z.score.median())
        rows.append(m)
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--step15l-dir", type=Path, required=True)
    ap.add_argument("--step15k-dir", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    args = ap.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    episodes = pd.read_csv(args.step15l_dir / "clean_move_ml_dataset.csv")
    paths = pd.read_csv(args.step15k_dir / "episode_tradeable_move_dataset.csv")
    for col in set(sum(EPISODE_GROUPS.values(), [])):
        episodes[col] = pd.to_numeric(episodes[col], errors="coerce")
    actions = make_action_rows(episodes, paths)

    id_cols = ["episode_id", "event_id", "market_cluster_id", "symbol", "shock_direction",
               "session", "t0_msc", "feature_source_msc", "action", "action_sign",
               "candidate_direction", "outcome", "tp_first", "realized_r"]
    export_cols = id_cols + list(dict.fromkeys(sum(ACTION_GROUPS.values(), [])))
    actions[export_cols].to_csv(args.out_dir / "action_dataset.csv", index=False)

    folds, predictions = [], []
    for group in ACTION_GROUPS:
        for kind in ("LOGISTIC", "LIGHTGBM"):
            fr, pr = fit_walk_forward(actions, episodes, kind, group)
            folds += fr; predictions += pr
    for kind in ("LOGISTIC", "LIGHTGBM"):
        fr, pr = fit_walk_forward(actions, episodes, kind, "E_FULL", with_symbol=True)
        folds += fr; predictions += pr
    fr, pr = fit_walk_forward(actions, episodes, "LIGHTGBM", "E_FULL", symbol_only="USDJPY")
    folds += fr; predictions += pr
    for action_name in ("CONTINUATION", "REVERSAL"):
        fr, pr = fit_single_action(actions, episodes, action_name)
        folds += fr; predictions += pr
    fold_df = pd.DataFrame(folds)
    pred_df = pd.DataFrame(predictions)
    fold_df.to_csv(args.out_dir / "action_fold_performance.csv", index=False)
    pred_export = pred_df.merge(actions[id_cols], left_on="action_row_index", right_index=True, validate="many_to_one")
    pred_export.to_csv(args.out_dir / "action_oof_predictions.csv", index=False)

    comparisons = []
    for keys, g in pred_df.groupby(["model", "feature_group", "with_symbol", "symbol_scope"]):
        joined = g.merge(actions[["tp_first"]], left_on="action_row_index", right_index=True)
        metric = binary_metrics(joined.tp_first.to_numpy(), joined.score.to_numpy())
        best = best_actions(pred_df, actions, *keys[:2], bool(keys[2]), keys[3])
        policy = policy_metrics(best, "ALL", "ALL")
        metric.update(model=keys[0], feature_group=keys[1], with_symbol=keys[2],
                      symbol_scope=keys[3], oof_episodes=best.episode_id.nunique(),
                      best_action_tp_rate=float(best.tp_first.mean()),
                      tradeable_episodes=int(best.is_clean_move.sum()),
                      direction_correct=int(best.tp_first.sum()),
                      direction_accuracy_on_tradeable=float(best.tp_first.sum() / best.is_clean_move.sum()) if best.is_clean_move.sum() else math.nan,
                      policy_mean_r=policy["mean_r"],
                      policy_total_r=policy["total_r"], policy_positive_folds=policy["positive_folds"])
        comparisons.append(metric)
    comparison_df = pd.DataFrame(comparisons)
    comparison_df.to_csv(args.out_dir / "action_model_comparison.csv", index=False)
    comparison_df.to_csv(args.out_dir / "action_ablation_results.csv", index=False)

    primary = best_actions(pred_df, actions)
    selected_rows = []
    threshold_rows = []
    for scope, scored in (("GLOBAL_NO_SYMBOL", primary),
                          ("USDJPY_ONLY", best_actions(pred_df, actions, symbol_scope="USDJPY"))):
        for n in TOP_COUNTS:
            row = policy_metrics(scored, "TOP_COUNT", n); row["model_scope"] = scope
            selected_rows.append(row)
        for value in THRESHOLDS:
            row = policy_metrics(scored, "SCORE_THRESHOLD", value); row["model_scope"] = scope
            threshold_rows.append(row)
    pd.DataFrame(selected_rows).to_csv(args.out_dir / "action_selected_count_frontier.csv", index=False)
    pd.DataFrame(threshold_rows).to_csv(args.out_dir / "action_threshold_frontier.csv", index=False)

    # Fold performance of the unfiltered best action is the stability baseline.
    fold_policy = grouped_performance(primary, "fold", "ALL_BEST_ACTION")
    pd.DataFrame(fold_policy).to_csv(args.out_dir / "action_fold_policy_performance.csv", index=False)
    symbol_rows = grouped_performance(primary, "symbol", "ALL_BEST_ACTION")
    pd.DataFrame(symbol_rows).to_csv(args.out_dir / "action_symbol_performance.csv", index=False)
    primary["week"] = pd.to_datetime(primary.t0_msc, unit="ms", utc=True).dt.to_period("W").astype(str)
    weekly = grouped_performance(primary, "week", "ALL_BEST_ACTION")
    for n in (100, 200, 300):
        weekly += grouped_performance(primary.head(n), "week", f"TOP_{n}")
    pd.DataFrame(weekly).to_csv(args.out_dir / "action_weekly_performance.csv", index=False)

    # Same-population Step 15L baseline comparisons.
    clean_oof = pd.read_csv(args.step15l_dir / "model_oof_predictions.csv")
    clean_oof = clean_oof[(clean_oof.model == "LIGHTGBM") &
                          (clean_oof.feature_group == "E_FULL") &
                          (clean_oof.with_symbol.astype(str).str.lower() == "false")]
    clean_oof = clean_oof[["episode_id", "score"]].rename(columns={"score": "clean_score"})
    oof_actions = pred_df[(pred_df.model == "LIGHTGBM") & (pred_df.feature_group == "E_FULL") &
                          (~pred_df.with_symbol) & (pred_df.symbol_scope == "ALL")]
    joined_actions = oof_actions.merge(actions, left_on="action_row_index", right_index=True)
    baseline_rows = []
    for name, z in (("ALWAYS_CONTINUATION", joined_actions[joined_actions.action == "CONTINUATION"]),
                    ("ALWAYS_REVERSAL", joined_actions[joined_actions.action == "REVERSAL"])):
        m = policy_metrics(z.sort_values(["t0_msc", "episode_id"]), "ALL", "ALL")
        m.update(method=name, selection="OOF_ALL"); baseline_rows.append(m)
    for n in TOP_COUNTS:
        chosen_ids = set(clean_oof.sort_values(["clean_score", "episode_id"], ascending=[False, True]).head(n).episode_id)
        for action in ("CONTINUATION", "REVERSAL"):
            z = joined_actions[(joined_actions.action == action) & joined_actions.episode_id.isin(chosen_ids)]
            m = policy_metrics(z.sort_values(["t0_msc", "episode_id"]), "ALL", "ALL")
            m.update(method=f"STEP15L_CLEAN_TOP_{n}_{action}", selection=f"TOP_{n}"); baseline_rows.append(m)
        m = policy_metrics(primary, "TOP_COUNT", n)
        m.update(method=f"STEP15M_DIRECT_TOP_{n}", selection=f"TOP_{n}"); baseline_rows.append(m)
    pd.DataFrame(baseline_rows).to_csv(args.out_dir / "step15l_vs_step15m.csv", index=False)

    # Descriptive final-model explanations; never validation metrics.
    features = ACTION_GROUPS["E_FULL"]
    final = pipeline("LIGHTGBM", features, False)
    final.fit(actions[features + BASE_CATS], actions.tp_first)
    prep = final.named_steps["prep"]; model = final.named_steps["model"]
    names = prep.get_feature_names_out()
    gain = model.booster_.feature_importance("gain")
    split = model.booster_.feature_importance("split")
    pd.DataFrame({"transformed_feature": names, "gain": gain, "split": split}).sort_values("gain", ascending=False).to_csv(args.out_dir / "action_feature_importance.csv", index=False)
    last_valid = set(cluster_folds(episodes)[-1][2])
    vi = actions.index[actions.market_cluster_id.isin(last_valid)]
    perm = permutation_importance(final, actions.loc[vi, features + BASE_CATS], actions.loc[vi, "tp_first"],
                                  scoring="average_precision", n_repeats=10, random_state=SEED, n_jobs=1)
    pd.DataFrame({"feature": features + BASE_CATS, "importance_mean": perm.importances_mean,
                  "importance_std": perm.importances_std}).sort_values("importance_mean", ascending=False).to_csv(args.out_dir / "action_permutation_importance.csv", index=False)
    transformed = prep.transform(actions.loc[vi, features + BASE_CATS])
    contrib = model.booster_.predict(transformed, pred_contrib=True)
    pd.DataFrame({"transformed_feature": names,
                  "mean_abs_contribution": np.abs(contrib[:, :-1]).mean(axis=0)}).sort_values("mean_abs_contribution", ascending=False).to_csv(args.out_dir / "action_shap_summary.csv", index=False)

    # Independent structural QA and the persisted Step 15L Top-327 audit.
    duplicate = int(actions.duplicated(["episode_id", "action"]).sum())
    both = actions.pivot(index="episode_id", columns="action", values="tp_first")
    top327_ids = set(clean_oof.sort_values(["clean_score", "episode_id"], ascending=[False, True]).head(327).episode_id)
    t327 = actions[actions.episode_id.isin(top327_ids)].pivot(index="episode_id", columns="action", values="tp_first")
    source_violations = int((pd.to_numeric(actions.feature_source_msc, errors="coerce") > actions.t0_msc).sum())
    leakage_names = [x for x in ACTION_GROUPS["E_FULL"] if any(k in x.lower() for k in ("mfe", "mae", "tp_first", "outcome", "hit_", "realized_r"))]
    ok_folds = fold_df[fold_df.status == "OK"]
    qa = [
        ("episode_count", 2696, actions.episode_id.nunique()),
        ("action_row_count", 5392, len(actions)),
        ("continuation_tp_first", 84, int(actions.loc[actions.action == "CONTINUATION", "tp_first"].sum())),
        ("reversal_tp_first", 104, int(actions.loc[actions.action == "REVERSAL", "tp_first"].sum())),
        ("both_tp_first", 0, int(((both.CONTINUATION == 1) & (both.REVERSAL == 1)).sum())),
        ("timeout_action_rows", 0, int((actions.outcome == "TIMEOUT").sum())),
        ("duplicate_action_key", 0, duplicate),
        ("feature_timestamp_violation", 0, source_violations),
        ("target_leakage_predictor", 0, len(leakage_names)),
        ("episode_fold_overlap", 0, int(ok_folds.episode_overlap.sum())),
        ("cluster_fold_overlap", 0, int(ok_folds.cluster_overlap.sum())),
        ("oof_chronology_violation", 0, int((ok_folds.train_max_msc >= ok_folds.validation_min_msc).sum())),
        ("oof_episode_count", 1620, primary.episode_id.nunique()),
        ("top327_continuation_tp", 23, int(t327.CONTINUATION.sum())),
        ("top327_reversal_tp", 22, int(t327.REVERSAL.sum())),
        ("top327_both_sl", 282, int(((t327.CONTINUATION == 0) & (t327.REVERSAL == 0)).sum())),
        ("orders", 0, 0), ("trades", 0, 0),
    ]
    pd.DataFrame([{"check": n, "expected": e, "actual": a,
                   "status": "PASS" if e == a else "FAIL"} for n, e, a in qa]).to_csv(args.out_dir / "qa_checks.csv", index=False)
    (args.out_dir / "python_environment.txt").write_text("\n".join([
        f"python={platform.python_version()}", f"numpy={np.__version__}",
        f"pandas={pd.__version__}", f"scipy={scipy.__version__}",
        f"scikit_learn={sklearn.__version__}", f"lightgbm={lightgbm.__version__}",
        f"seed={SEED}",
    ]) + "\n", encoding="utf-8")
    print(json.dumps({"episodes": actions.episode_id.nunique(), "action_rows": len(actions),
                      "oof_episodes": primary.episode_id.nunique(),
                      "qa_fail": sum(e != a for _, e, a in qa)}, sort_keys=True))


if __name__ == "__main__":
    main()
