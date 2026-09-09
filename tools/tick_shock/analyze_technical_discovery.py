#!/usr/bin/env python3
"""One frozen technical-feature run -> bounded development strategy discovery.

The feature CSV is the only predictor source. Real executable path outcomes are
labels, never predictors. All reported portfolios resolve one global open or
pending position in signal-processing order. Development fitting and purged
forward diagnostics are labelled separately; this tool makes no OOS claim.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import platform
from pathlib import Path

import lightgbm
import numpy as np
import pandas as pd
import sklearn
from lightgbm import LGBMRegressor
from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeRegressor

SEED = 20260909
COSTS = (0.0, 0.1, 0.2, 0.5, 1.0)
PRIMARY_COST = 0.2
THRESHOLDS = (-0.1, 0.0, 0.05, 0.1, 0.2, 0.3)
TARGET_COUNTS = (200, 300, 500, 800, 1000)
METHODS = ("SHALLOW_TREE", "ELASTICNET_LOGISTIC", "LIGHTGBM")
EXECUTED = {"TP", "SL", "TIME", "TIMEOUT"}
META = {"episode_id", "event_id", "market_cluster_id", "symbol", "t0_msc",
        "t0_processing_msc", "t0_quote_msc", "feature_max_close_msc",
        "feature_future_count", "feature_available_count", "run_id", "event_shock_direction",
        "atr14_m1", "atr14_m5"}


def csv(path: Path) -> pd.DataFrame:
    prefix = path.read_bytes()[:4]
    encoding = "utf-16" if prefix[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8-sig"
    return pd.read_csv(path, encoding=encoding, sep=None, engine="python")


def dump_csv(rows, path: Path) -> None:
    frame = rows if isinstance(rows, pd.DataFrame) else pd.DataFrame(rows)
    frame.to_csv(path, index=False, float_format="%.14g", lineterminator="\n")


def clean_json(value):
    if isinstance(value, dict):
        return {str(k): clean_json(v) for k, v in value.items()}
    if isinstance(value, (list, tuple, np.ndarray)):
        return [clean_json(v) for v in value]
    if isinstance(value, (np.integer,)):
        return int(value)
    if isinstance(value, (float, np.floating)):
        return float(value) if math.isfinite(value) else None
    if isinstance(value, np.bool_):
        return bool(value)
    return value


def write_json(value, path: Path) -> None:
    path.write_text(json.dumps(clean_json(value), indent=2, sort_keys=True) + "\n", encoding="utf-8")


def profit_stats(frame: pd.DataFrame, cost: float = PRIMARY_COST) -> dict:
    if not len(frame):
        return dict(trades=0, win_rate=math.nan, expectancy_r=math.nan,
                    total_r=0.0, expectancy_pips=math.nan, pf=math.nan,
                    maxdd_r=0.0, long=0, short=0, tp=0, sl=0, timeout=0,
                    gross_expectancy_r=math.nan, total_pips=0.0,
                    max_day_profit_share=math.nan, top5_removed_total_r=0.0,
                    positive_segments=0, min_segment_trades=0)
    net = frame.gross_r.to_numpy(float) - cost / (frame.distance / frame.pip_size).to_numpy(float)
    pips = frame.gross_pips.to_numpy(float) - cost
    equity = np.r_[0.0, np.cumsum(net)]
    positive, negative = net[net > 0].sum(), -net[net < 0].sum()
    days = (frame.t0_msc.astype("int64") // 86400000).to_numpy()
    daily = pd.DataFrame({"day": days, "r": net}).groupby("day").r.sum()
    segments = pd.DataFrame({"s": frame.calendar_segment.to_numpy(), "r": net}).groupby("s").r.agg(["sum", "count"])
    segments = segments.reindex(range(4), fill_value=0)
    return dict(trades=len(frame), win_rate=float(np.mean(net > 0)),
                expectancy_r=float(np.mean(net)), total_r=float(np.sum(net)),
                expectancy_pips=float(np.mean(pips)), total_pips=float(np.sum(pips)),
                pf=float(positive / negative) if negative else (math.inf if positive else math.nan),
                maxdd_r=float(np.max(np.maximum.accumulate(equity) - equity)),
                long=int((frame.direction == 1).sum()), short=int((frame.direction == -1).sum()),
                tp=int((frame.status == "TP").sum()), sl=int((frame.status == "SL").sum()),
                timeout=int(frame.status.isin(["TIME", "TIMEOUT"]).sum()),
                gross_expectancy_r=float(frame.gross_r.mean()),
                max_day_profit_share=float(daily.clip(lower=0).max() / daily.clip(lower=0).sum()) if daily.clip(lower=0).sum() else math.nan,
                top5_removed_total_r=float(net.sum() - np.sort(net)[-5:].sum()),
                positive_segments=int((segments["sum"] > 0).sum()),
                min_segment_trades=int(segments["count"].min()))


def portfolio(actions: pd.DataFrame, threshold: float) -> tuple[pd.DataFrame, dict]:
    """Reserve at recognized signal, release at real rejection/final exit.

    Direction must already have been selected solely from model scores; do not
    fall back to the other direction after discovering the outcome status.
    """
    chosen = actions[actions.score >= threshold].sort_values(
        ["signal_processing_msc", "t0_msc", "episode_id"], kind="stable")
    busy_until = -1
    records, overlap, rejected = [], 0, 0
    for row in chosen.itertuples():
        if row.signal_processing_msc <= busy_until:
            overlap += 1
            continue
        if row.status not in EXECUTED:
            rejected += 1
            if row.status == "NO_ENTRY":
                busy_until = max(busy_until, row.signal_processing_msc, row.t0_msc+30000)
            elif row.status == "CENSORED":
                # Unknown end-of-path cannot release an entered position early.
                busy_until = max(busy_until, row.entry_msc+900000)
            elif math.isfinite(row.entry_msc) and row.entry_msc > 0:
                busy_until = max(busy_until, row.entry_msc)
            continue
        if not (row.entry_msc >= row.signal_processing_msc and row.exit_msc >= row.entry_msc):
            raise ValueError("Causality invariant violated before portfolio selection")
        records.append(row.Index)
        busy_until = row.exit_msc
    frame = actions.loc[records].copy()
    return frame, {"threshold_signals": len(chosen), "overlap_skips": overlap,
                   "entry_rejections": rejected}


def feature_matrix(frame: pd.DataFrame) -> tuple[pd.DataFrame, list[dict]]:
    features = [x for x in frame.columns if x not in META]
    forbidden = [x for x in features if any(z in x.lower() for z in ("future", "outcome", "exit_", "entry_", "mfe", "mae", "tp_touch", "sl_touch"))]
    if forbidden:
        raise ValueError(f"Outcome-like predictor names rejected: {forbidden}")
    x = frame[features].apply(pd.to_numeric, errors="coerce").replace([np.inf, -np.inf], np.nan)
    # The production feature producer supplies causal technical interactions.
    # Do not invent additional transformations here that would lack EA parity.
    catalog = [{"feature_index": i, "feature": name, "available": int(x[name].notna().sum()),
                "missing": int(x[name].isna().sum()), "unique": int(x[name].nunique()),
                "source": "formal_feature_csv", "causal_only": True}
               for i, name in enumerate(x.columns)]
    return x, catalog


class Model:
    def __init__(self, method: str):
        self.method = method

    def fit(self, x: np.ndarray, y: np.ndarray):
        self.median = np.array([np.median(v[np.isfinite(v)]) if np.isfinite(v).any() else 0.0 for v in x.T])
        x = np.where(np.isfinite(x), x, self.median)
        if self.method == "SHALLOW_TREE":
            self.estimator = DecisionTreeRegressor(max_depth=3, min_samples_leaf=100, random_state=SEED)
        elif self.method == "LIGHTGBM":
            self.estimator = LGBMRegressor(n_estimators=60, learning_rate=0.04,
                max_depth=3, num_leaves=8, min_child_samples=100, reg_alpha=1.0,
                reg_lambda=2.0, colsample_bytree=1.0, deterministic=True,
                force_col_wise=True, n_jobs=1, verbosity=-1, random_state=SEED)
        else:
            self.mean, self.scale = x.mean(axis=0), x.std(axis=0)
            self.scale[self.scale < 1e-12] = 1.0
            self.win_mean = float(y[y > 0].mean()) if (y > 0).any() else 0.0
            self.loss_mean = float(y[y <= 0].mean()) if (y <= 0).any() else 0.0
            if len(np.unique(y > 0)) < 2:
                self.constant = float(y.mean())
                self.estimator = None
                return self
            self.estimator = LogisticRegression(C=0.1, l1_ratio=0.5, solver="saga",
                max_iter=4000, tol=1e-4, random_state=SEED)
            self.estimator.fit((x-self.mean)/self.scale, y > 0)
            return self
        self.estimator.fit(x, y)
        return self

    def predict(self, x: np.ndarray) -> np.ndarray:
        x = np.where(np.isfinite(x), x, self.median)
        if self.method == "ELASTICNET_LOGISTIC":
            if self.estimator is None:
                return np.full(len(x), self.constant)
            p = self.estimator.predict_proba((x-self.mean)/self.scale)[:, 1]
            return p*self.win_mean+(1-p)*self.loss_mean
        if self.method == "LIGHTGBM":
            return self.estimator.booster_.predict(x)
        return self.estimator.predict(x)

    def export(self) -> dict:
        value = {"method": self.method, "median": self.median.tolist()}
        if self.method == "SHALLOW_TREE":
            t = self.estimator.tree_
            value.update(left=t.children_left.tolist(), right=t.children_right.tolist(),
                         feature=t.feature.tolist(), threshold=t.threshold.tolist(),
                         value=t.value[:, 0, 0].tolist(), compare="float32_input_le")
        elif self.method == "LIGHTGBM":
            value["trees"] = [t["tree_structure"] for t in self.estimator.booster_.dump_model()["tree_info"]]
        elif self.estimator is None:
            value["constant"] = self.constant
        else:
            value.update(mean=self.mean.tolist(), scale=self.scale.tolist(),
                         coefficient=self.estimator.coef_[0].tolist(),
                         intercept=float(self.estimator.intercept_[0]),
                         win_mean=self.win_mean, loss_mean=self.loss_mean)
        return value


def choose_actions(outcomes: pd.DataFrame, episodes: pd.DataFrame,
                   long_score: np.ndarray, short_score: np.ndarray) -> pd.DataFrame:
    # Exact tie => NO TRADE (the common equal-score leaf must not imply LONG).
    direction = np.where(long_score > short_score, 1, np.where(short_score > long_score, -1, 0))
    score = np.maximum(long_score, short_score)
    choices = pd.DataFrame({"episode_id": episodes.episode_id, "direction": direction,
                            "score": score, "long_score": long_score, "short_score": short_score})
    result = choices[choices.direction != 0].merge(outcomes, on=["episode_id", "direction"], validate="one_to_one")
    return result


def passes_gate(stats: dict) -> bool:
    return bool(stats["trades"] >= 200 and stats["expectancy_r"] > 0 and stats["pf"] > 1
                and stats["max_day_profit_share"] < .35 and stats["top5_removed_total_r"] > 0
                and stats["positive_segments"] >= 3 and stats["min_segment_trades"] >= 20)


def summarize_paths(outcomes: pd.DataFrame, output: Path) -> None:
    valid = outcomes[outcomes.status.isin(EXECUTED)]
    rows = []
    for (distance, direction), group in valid.groupby(["distance_index", "direction"]):
        row = {"distance_index": distance, "distance_atr": group.distance_atr.iloc[0],
               "direction": direction, **profit_stats(group, 0.0)}
        for name in ("distance", "entry_spread", "tp_touch_seconds", "sl_touch_seconds",
                     "mfe_60", "mae_60", "mfe_300", "mae_300", "mfe_900", "mae_900"):
            values = group[name].replace([np.inf, -np.inf], np.nan).dropna()
            if "touch" in name:
                values = values[values >= 0]
            for quantile in (.1, .5, .9):
                row[f"{name}_p{int(quantile*100)}"] = values.quantile(quantile) if len(values) else math.nan
        ratio = group.distance/group.entry_spread
        row["distance_spread_p10"], row["distance_spread_p50"] = ratio.quantile(.1), ratio.median()
        rows.append(row)
    dump_csv(rows, output/"path_geometry_diagnostics.csv")
    dump_csv(outcomes.groupby(["distance_index", "direction", "status"]).size().rename("rows").reset_index(), output/"outcome_funnel.csv")


def univariate(x: pd.DataFrame, episodes: pd.DataFrame, outcomes: pd.DataFrame, output: Path):
    bins, correlations = [], []
    for (geometry, direction), group in outcomes[outcomes.status.isin(EXECUTED)].groupby(["distance_index", "direction"]):
        group = group.set_index("episode_id")
        idx = episodes.index[episodes.episode_id.isin(group.index)]
        target = group.loc[episodes.loc[idx, "episode_id"]].gross_r.to_numpy(copy=True)
        target -= PRIMARY_COST/(group.loc[episodes.loc[idx, "episode_id"]].distance/group.loc[episodes.loc[idx, "episode_id"]].pip_size).to_numpy()
        for feature in x:
            values = x.loc[idx, feature]
            if values.nunique() < 2:
                continue
            correlation = pd.Series(values.to_numpy()).corr(pd.Series(target), method="spearman")
            correlations.append(dict(distance_index=geometry, direction=direction, feature=feature, spearman_net_r=correlation, rows=len(idx)))
            try:
                codes, edges = pd.qcut(values, 5, duplicates="drop", retbins=True, labels=False)
            except ValueError:
                continue
            for bucket in sorted(codes.dropna().unique()):
                subset = target[codes.to_numpy() == bucket]
                bins.append(dict(distance_index=geometry, direction=direction, feature=feature,
                                 bin=int(bucket), lower=edges[int(bucket)], upper=edges[int(bucket)+1],
                                 rows=len(subset), net_expectancy_r=float(subset.mean()),
                                 win_rate=float(np.mean(subset > 0)), scope="DEVELOPMENT_EXPLORATORY_NOT_DEPLOYABLE_RULE"))
    dump_csv(bins, output/"feature_bins.csv")
    dump_csv(correlations, output/"feature_target_correlations.csv")
    corr = x.corr(method="spearman").to_numpy()
    pairs = [(x.columns[i], x.columns[j], corr[i, j]) for i in range(len(x.columns))
             for j in range(i) if np.isfinite(corr[i, j]) and abs(corr[i, j]) >= .9]
    dump_csv(pd.DataFrame(pairs, columns=["feature_a", "feature_b", "spearman"]), output/"feature_redundancy.csv")


def forward_splits(episodes: pd.DataFrame, outcomes: pd.DataFrame):
    clusters = episodes.groupby("market_cluster_id").t0_msc.min().sort_values(kind="stable")
    for number, (lo, hi) in enumerate(((.4, .55), (.55, .7), (.7, .85), (.85, 1.0)), 1):
        train_clusters = set(clusters.index[:int(len(clusters)*lo)])
        valid_clusters = set(clusters.index[int(len(clusters)*lo):int(len(clusters)*hi)])
        validation = episodes.index[episodes.market_cluster_id.isin(valid_clusters)].to_numpy()
        if not len(validation):
            continue
        first_signal = episodes.loc[validation, "t0_processing_msc"].min()
        # Any episode whose 15-minute label may reach validation is purged.
        latest_exit = outcomes.groupby("episode_id").exit_msc.max()
        fit = episodes.index[episodes.market_cluster_id.isin(train_clusters)
             & (episodes.episode_id.map(latest_exit).fillna(np.inf) < first_signal)
             & (episodes.t0_msc + 900000 < first_signal)].to_numpy()
        yield number, fit, validation


def fit_pair(method, x, episodes, outcomes, train_index):
    pair = {}
    for direction in (1, -1):
        labels = outcomes[(outcomes.direction == direction) & outcomes.status.isin(EXECUTED)].set_index("episode_id")
        idx = np.array([i for i in train_index if episodes.at[i, "episode_id"] in labels.index])
        if len(idx) < 200:
            return None
        matched = labels.loc[episodes.loc[idx, "episode_id"]]
        y = matched.gross_r.to_numpy(float) - PRIMARY_COST/(matched.distance/matched.pip_size).to_numpy(float)
        pair[direction] = Model(method).fit(x[idx], y)
    return pair


def importances(pair, feature_names, geometry, method, output_rows):
    for direction, model in pair.items():
        if method == "LIGHTGBM":
            values = model.estimator.booster_.feature_importance(importance_type="gain")
        elif method == "SHALLOW_TREE":
            values = model.estimator.feature_importances_
        elif model.estimator is not None:
            values = np.abs(model.estimator.coef_[0])
        else:
            values = np.zeros(len(feature_names))
        for feature, value in zip(feature_names, values):
            output_rows.append(dict(distance_index=geometry, method=method, direction=direction,
                                   feature=feature, importance=float(value), scope="DEVELOPMENT_FIT"))


def candidate_thresholds(scores: np.ndarray):
    thresholds = {f"absolute_{t:g}": t for t in THRESHOLDS}
    finite = scores[np.isfinite(scores)]
    for count in TARGET_COUNTS:
        if len(finite) >= count:
            thresholds[f"train_quantile_target_{count}"] = float(np.sort(finite)[-count])
    return thresholds


def mql_export(spec: dict) -> str:
    """Inference consumes the exact producer feature order; no indicator copy."""
    lines = ["// Generated from frozen development model; do not hand-edit.",
             "#ifndef TECHNICAL_DISCOVERY_MODEL_MQH", "#define TECHNICAL_DISCOVERY_MODEL_MQH",
             f"#define TD_MODEL_FEATURE_COUNT {len(spec['features'])}",
             f"#define TD_MODEL_DISTANCE_INDEX {spec['distance_index']}",
             f"#define TD_MODEL_DISTANCE_ATR {spec['distance_atr']:.17g}",
             f"#define TD_MODEL_THRESHOLD {spec['threshold']:.17g}"]
    def arr(name, values, kind="double"):
        values = [str(int(v)) if kind == "int" else format(float(v), ".17g") for v in values]
        lines.append(f"const {kind} {name}[{len(values)}]={{"+",".join(values)+"};")
    for side, name in (("long", "Long"), ("short", "Short")):
        model = spec["models"][side]
        arr(f"TD{name}Median", model["median"])
        if model["method"] == "SHALLOW_TREE":
            for field in ("left", "right", "feature", "threshold", "value"):
                arr(f"TD{name}{field.title()}", model[field], "int" if field in ("left", "right", "feature") else "double")
            lines += [f"double TDScore{name}(const double &raw[])", "{", "   int node=0;",
                      f"   while(TD{name}Left[node]>=0)", "   {", f"      int f=TD{name}Feature[node];",
                      f"      double v=(MathIsValidNumber(raw[f])&&raw[f]!=EMPTY_VALUE)?raw[f]:TD{name}Median[f];",
                      "      v=(double)(float)v; // sklearn tree input conversion",
                      f"      node=(v<=TD{name}Threshold[node])?TD{name}Left[node]:TD{name}Right[node];", "   }",
                      f"   return TD{name}Value[node];", "}"]
        elif model["method"] == "LIGHTGBM":
            def expr(tree):
                if "leaf_value" in tree:
                    return format(tree["leaf_value"], ".17g")
                if tree["decision_type"] != "<=":
                    raise ValueError("Unsupported categorical model split")
                return "(v["+str(tree["split_feature"])+"]<="+format(tree["threshold"], ".17g")+"?"+expr(tree["left_child"])+":"+expr(tree["right_child"])+")"
            lines += [f"double TDScore{name}(const double &raw[])", "{", "   double v[TD_MODEL_FEATURE_COUNT];",
                      f"   for(int i=0;i<TD_MODEL_FEATURE_COUNT;i++) v[i]=(MathIsValidNumber(raw[i])&&raw[i]!=EMPTY_VALUE)?raw[i]:TD{name}Median[i];",
                      "   double score=0.0;"]
            for tree in model["trees"]:
                lines.append("   score+="+expr(tree)+";")
            lines += ["   return score;", "}"]
        elif "constant" in model:
            lines += [f"double TDScore{name}(const double &raw[]) {{ return {model['constant']:.17g}; }}"]
        else:
            for field in ("mean", "scale", "coefficient"):
                arr(f"TD{name}{field.title()}", model[field])
            lines += [f"double TDScore{name}(const double &raw[])", "{", f"   double z={model['intercept']:.17g};",
                      "   for(int i=0;i<TD_MODEL_FEATURE_COUNT;i++)", "   {",
                      f"      double v=(MathIsValidNumber(raw[i])&&raw[i]!=EMPTY_VALUE)?raw[i]:TD{name}Median[i];",
                      f"      z+=(v-TD{name}Mean[i])/TD{name}Scale[i]*TD{name}Coefficient[i];", "   }",
                      "   double p=(z>=0.0)?1.0/(1.0+MathExp(-z)):MathExp(z)/(1.0+MathExp(z));",
                      f"   return p*{model['win_mean']:.17g}+(1.0-p)*{model['loss_mean']:.17g};", "}"]
    lines += ["int TDModelDecision(const double &raw[],double &long_score,double &short_score)", "{",
              "   if(ArraySize(raw)!=TD_MODEL_FEATURE_COUNT) return 0;",
              "   long_score=TDScoreLong(raw); short_score=TDScoreShort(raw);",
              "   if(MathMax(long_score,short_score)<TD_MODEL_THRESHOLD || long_score==short_score) return 0;",
              "   return (long_score>short_score)?1:-1;", "}", "#endif", ""]
    return "\n".join(lines)


def run(args):
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    f, o = csv(Path(args.features)), csv(Path(args.outcomes))
    f = f.sort_values(["t0_msc", "episode_id"], kind="stable").reset_index(drop=True)
    for name in ("direction", "distance_index", "t0_msc", "signal_processing_msc"):
        o[name] = pd.to_numeric(o[name], errors="raise")
    o["status"] = o.status.str.upper()
    if f.episode_id.duplicated().any() or o.duplicated(["episode_id", "direction", "distance_index"]).any():
        raise ValueError("Duplicate episode/outcome key")
    if f.feature_future_count.sum() or (f.feature_max_close_msc > f.t0_msc).any():
        raise ValueError("Future feature input")
    if not set(o.episode_id).issubset(set(f.episode_id)):
        raise ValueError("Outcome episode absent from feature matrix")
    month_start = pd.Timestamp(args.period_start).timestamp()*1000
    month_end = pd.Timestamp(args.period_end).timestamp()*1000
    f["calendar_segment"] = np.minimum(3, ((f.t0_msc-month_start)*4/(month_end-month_start)).astype(int))
    o = o.merge(f[["episode_id", "calendar_segment"]], on="episode_id", validate="many_to_one")
    x_frame, catalog = feature_matrix(f.drop(columns="calendar_segment"))
    x = x_frame.to_numpy(float)
    dump_csv(catalog, output/"feature_catalog.csv")
    summarize_paths(o, output)
    if not args.skip_univariate:
        univariate(x_frame, f, o, output)
    print(f"episodes={len(f)} features={len(catalog)} outcomes={len(o)}", flush=True)
    frontiers, costs, fold_rows, importance_rows, cache = [], [], [], [], {}
    for geometry, group in o.groupby("distance_index", sort=True):
        for method in METHODS:
            pair = fit_pair(method, x, f, group, np.arange(len(f)))
            if pair is None:
                print(f"geometry={geometry} {method} insufficient executable labels", flush=True)
                continue
            long_score, short_score = pair[1].predict(x), pair[-1].predict(x)
            actions = choose_actions(group, f, long_score, short_score)
            model_key = f"g{int(geometry)}_{method}"
            cache[model_key] = (pair, actions, group)
            importances(pair, x_frame.columns, geometry, method, importance_rows)
            thresholds = candidate_thresholds(actions.score.to_numpy())
            for threshold_name, threshold in thresholds.items():
                trades, selection = portfolio(actions, threshold)
                stats = profit_stats(trades)
                candidate_id = f"{model_key}_{threshold_name}"
                row = dict(candidate_id=candidate_id, model_key=model_key,
                           method=method, distance_index=int(geometry),
                           distance_atr=float(group.distance_atr.iloc[0]),
                           scope="DEVELOPMENT_FITTED_SAME_MONTH", threshold_name=threshold_name,
                           threshold=threshold, primary_extra_cost_pips=PRIMARY_COST,
                           **selection, **stats)
                row["individual_gate"] = passes_gate(stats)
                frontiers.append(row)
                for cost in COSTS:
                    costs.append(dict(candidate_id=candidate_id, extra_cost_pips=cost,
                                      commission_status="NOT_OBSERVED", **profit_stats(trades, cost)))
            # Strict forward folds: feature imputation/model fit/threshold fitting
            # use past training only, grouped by cross-market cluster and purged.
            for fold, train, valid in forward_splits(f, group):
                fold_pair = fit_pair(method, x, f, group, train)
                if fold_pair is None:
                    fold_rows.append(dict(model_key=model_key, fold=fold, status="INSUFFICIENT_TRAIN_LABELS", train_episodes=len(train), valid_episodes=len(valid)))
                    continue
                vl, vs = fold_pair[1].predict(x[valid]), fold_pair[-1].predict(x[valid])
                fold_actions = choose_actions(group, f.loc[valid].reset_index(drop=True), vl, vs)
                train_scores = np.maximum(fold_pair[1].predict(x[train]), fold_pair[-1].predict(x[train]))
                fold_thresholds = {f"absolute_{v:g}": v for v in THRESHOLDS}
                # Fixed quantile fractions, not full-development score cutoffs.
                for target in TARGET_COUNTS:
                    fraction = min(1.0, target/len(f))
                    fold_thresholds[f"train_fraction_{target}_per_month"] = float(np.quantile(train_scores, 1-fraction))
                for label, threshold in fold_thresholds.items():
                    trades, skips = portfolio(fold_actions, threshold)
                    fold_rows.append(dict(model_key=model_key, fold=fold, status="EXECUTED",
                                          scope="PURGED_FORWARD_DIAGNOSTIC", threshold_name=label,
                                          threshold=threshold, train_episodes=len(train), valid_episodes=len(valid),
                                          **skips, **profit_stats(trades)))
            print(f"geometry={geometry} method={method} complete", flush=True)
    frontier = pd.DataFrame(frontiers)
    if not len(frontier):
        raise ValueError("No model fitted: insufficient complete executable labels")
    frontier["neighbor_positive_count"] = 0
    for key, indices in frontier.groupby("model_key").groups.items():
        ordered = frontier.loc[indices].drop_duplicates("threshold").sort_values("threshold")
        for i, (idx, row) in enumerate(ordered.iterrows()):
            neighbors = ordered.iloc[max(0, i-1):i+2]
            count = int(((neighbors.trades >= 200) & (neighbors.expectancy_r > 0) & (neighbors.pf > 1)).sum()) - int(row.trades >= 200 and row.expectancy_r > 0 and row.pf > 1)
            frontier.loc[(frontier.model_key == key) & (frontier.threshold == row.threshold), "neighbor_positive_count"] = count
    frontier["candidate_gate"] = frontier.individual_gate & (frontier.neighbor_positive_count >= 1)
    dump_csv(frontier, output/"development_frontier.csv")
    dump_csv(costs, output/"cost_sensitivity.csv")
    dump_csv(fold_rows, output/"purged_forward_diagnostics.csv")
    dump_csv(importance_rows, output/"feature_importance.csv")
    frequency = []
    for minimum in (200, 300, 500, 800, 1000):
        eligible = frontier[frontier.trades >= minimum]
        if len(eligible):
            best = eligible.sort_values(["expectancy_r", "total_r"], ascending=False).iloc[0].to_dict()
            frequency.append(dict(minimum_trades=minimum, status="EVALUATED", **best))
        else:
            frequency.append(dict(minimum_trades=minimum, status="NO_THRESHOLD_HAS_THIS_FREQUENCY"))
    dump_csv(frequency, output/"frequency_frontier.csv")
    feasible = frontier[frontier.candidate_gate].copy()
    selected = None
    if len(feasible):
        feasible["complexity"] = feasible.method.map({"SHALLOW_TREE": 0, "ELASTICNET_LOGISTIC": 1, "LIGHTGBM": 2})
        # Prefer an interpretable simple model, then the broadest positive region.
        selected = feasible.sort_values(["complexity", "neighbor_positive_count", "total_r", "trades"],
                                       ascending=[True, False, False, False]).iloc[0]
        pair, actions, group = cache[selected.model_key]
        trades, _ = portfolio(actions, selected.threshold)
        spec = dict(candidate_id=selected.candidate_id, method=selected.method,
                    distance_index=int(selected.distance_index), distance_atr=float(selected.distance_atr),
                    threshold=float(selected.threshold), features=x_frame.columns.tolist(),
                    rr=1.0, hold_seconds=900, primary_extra_cost_pips=PRIMARY_COST,
                    commission_status="NOT_OBSERVED", scope="DEVELOPMENT_CANDIDATE_NOT_OOS_VALIDATED",
                    signal_clock="t0_processing_msc", tie_action="NO_TRADE",
                    feature_source_sha256=hashlib.sha256(Path(args.features).read_bytes()).hexdigest(),
                    models={"long": pair[1].export(), "short": pair[-1].export()})
        write_json(spec, output/"candidate_model.json")
        (output/"TechnicalDiscoveryModel.generated.mqh").write_text(mql_export(spec), encoding="utf-8")
        dump_csv(actions, output/"candidate_all_signals.csv")
        trades["net_r"] = trades.gross_r-PRIMARY_COST/(trades.distance/trades.pip_size)
        trades["net_pips"] = trades.gross_pips-PRIMARY_COST
        dump_csv(trades, output/"candidate_portfolio_trades.csv")
        for column, name in (("symbol", "symbol"), ("calendar_segment", "segment")):
            dump_csv([{column: key, **profit_stats(z)} for key, z in trades.groupby(column)], output/f"candidate_{name}_results.csv")
        trades["day"] = pd.to_datetime(trades.t0_msc, unit="ms").dt.strftime("%Y-%m-%d")
        dump_csv([{"day": key, **profit_stats(z)} for key, z in trades.groupby("day")], output/"candidate_daily_results.csv")
        equity = trades[["episode_id", "entry_msc", "exit_msc", "net_r"]].copy()
        equity["equity_r"] = equity.net_r.cumsum()
        equity["drawdown_r"] = np.maximum.accumulate(np.r_[0.0, equity.equity_r.to_numpy()])[1:]-equity.equity_r
        dump_csv(equity, output/"candidate_equity_curve.csv")
        clusters = trades.groupby("market_cluster_id").net_r.agg(["sum", "count"])
        rng = np.random.default_rng(SEED)
        means = []
        for _ in range(5000):
            draw = rng.integers(0, len(clusters), len(clusters))
            selected_clusters = clusters.iloc[draw]
            means.append(selected_clusters["sum"].sum()/selected_clusters["count"].sum())
        dump_csv([dict(candidate_id=selected.candidate_id, market_clusters=len(clusters),
                       resamples=5000, seed=SEED, net_expectancy_r=float(trades.net_r.mean()),
                       ci95_low=float(np.quantile(means, .025)), ci95_high=float(np.quantile(means, .975)),
                       interpretation="DESCRIPTIVE_AFTER_MODEL_SELECTION_NOT_SELECTION_ADJUSTED")], output/"candidate_cluster_bootstrap.csv")
    summary = dict(period_start=args.period_start, period_end=args.period_end,
                   scope="DEVELOPMENT_ONLY", episodes=len(f), features=len(catalog),
                   market_clusters=int(f.market_cluster_id.nunique()), outcome_rows=len(o),
                   method_geometry_count=len(cache), threshold_candidates=len(frontier),
                   above_200_positive_candidates=int(((frontier.trades >= 200) & (frontier.expectancy_r > 0)).sum()),
                   gate_candidates=len(feasible), candidate=selected.to_dict() if selected is not None else None,
                   best_at_least_200=frequency[0],
                   verdict="DEVELOPMENT_EA_CANDIDATE_FOUND" if selected is not None else "NO_QUALIFYING_DEVELOPMENT_CANDIDATE",
                   commission="NOT_OBSERVED", primary_extra_cost_pips=PRIMARY_COST,
                   versions=dict(python=platform.python_version(), numpy=np.__version__, pandas=pd.__version__,
                                 sklearn=sklearn.__version__, lightgbm=lightgbm.__version__),
                   fixed_seed=SEED, feature_sha256=hashlib.sha256(Path(args.features).read_bytes()).hexdigest(),
                   outcome_sha256=hashlib.sha256(Path(args.outcomes).read_bytes()).hexdigest())
    write_json(summary, output/"analysis_summary.json")
    print(json.dumps(clean_json(summary), indent=2), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--features", required=True)
    parser.add_argument("--outcomes", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--period-start", default="2025-04-01")
    parser.add_argument("--period-end", default="2025-05-01")
    parser.add_argument("--skip-univariate", action="store_true", help="Unit/synthetic smoke only; formal run uses all diagnostics")
    run(parser.parse_args())
