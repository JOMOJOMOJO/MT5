#!/usr/bin/env python3
"""Reconcile and analyze the preregistered Step 15F March development run.

The script deliberately treats March as development data.  All transforms,
imputation, scaling, model fitting and bucket boundaries used for predictions
are fitted inside each chronological outer fold.  No production MQL formula is
used as an expected-value oracle here.
"""
from __future__ import annotations

import csv
import hashlib
import json
import math
import platform
import re
import sys
import warnings
from collections import Counter
from pathlib import Path

import numpy as np
import pandas as pd
import scipy
import sklearn
from scipy import stats
from sklearn.compose import TransformedTargetRegressor
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.impute import SimpleImputer
from sklearn.inspection import permutation_importance
from sklearn.linear_model import ElasticNet, LogisticRegression
from sklearn.metrics import log_loss, mean_squared_error, roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.exceptions import ConvergenceWarning

warnings.filterwarnings("ignore", category=FutureWarning, module="sklearn")
warnings.filterwarnings("ignore", category=ConvergenceWarning)


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "reports/backtest/runs/20260830_ts15e_tail_v1_persistent_medium_horizon_202503"
RUN = ROOT / "reports/backtest/runs/20260831_ts15f_tail_v1_persistent_context_r3_202503"
OUT = ROOT / "reports/analysis/tick_shock/step15f"
REF = ROOT / "reports/refactor/tick_shock"
SEED = 20260831
DECISIONS = (60, 120)
HORIZONS = (300, 600, 900)
ACTIONS = ("CONTINUATION", "REVERSAL")
RUN_BASE = "ts15e_medium_horizon_202503"
RUN_NEW = "ts15f_context_r3_202503"


def write(df: pd.DataFrame, name: str) -> Path:
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(path, index=False)
    return path


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest().upper()


def parse_set(path: Path) -> dict[str, str]:
    out = {}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            out[key] = value
    return out


def normalize_value(value: object) -> str:
    text = "" if pd.isna(value) else str(value)
    return text.replace(RUN_BASE, "<RUN>").replace(RUN_NEW, "<RUN>")


def multiset_frame(path: Path, columns: list[str]) -> Counter:
    df = pd.read_csv(path, low_memory=False)
    return Counter(tuple(normalize_value(v) for v in row) for row in df[columns].to_numpy())


def behavior_comparison() -> pd.DataFrame:
    specs = {
        "detector_event_identity": ("detector_features.csv", ["symbol", "direction", "candidate_time_msc", "confirmed_time_msc", "trigger_horizon_ms", "market_cluster_id"]),
        "episode_identity": ("medium_horizon_episode_summary.csv", ["symbol", "shock_direction", "anchor_msc", "market_cluster_id", "episode_status", "validation_status"]),
        "path_identity": ("path_class_labels.csv", ["symbol", "shock_direction", "market_cluster_id", "primary_path_class", "path_status"]),
        "strategy_funnel": ("strategy_funnel.csv", []),
        "medium_horizon_response": ("medium_horizon_response.csv", []),
    }
    rows = []
    for component, (name, columns) in specs.items():
        old_df = pd.read_csv(BASE / name, low_memory=False)
        new_df = pd.read_csv(RUN / name, low_memory=False)
        if not columns:
            excluded = {"run_id", "event_id", "episode_id", "anchor_event_id"}
            columns = [c for c in old_df.columns if c not in excluded]
        old = Counter(tuple(normalize_value(v) for v in row) for row in old_df[columns].to_numpy())
        new = Counter(tuple(normalize_value(v) for v in row) for row in new_df[columns].to_numpy())
        missing = sum((old - new).values())
        extra = sum((new - old).values())
        rows.append(dict(component=component, baseline_rows=len(old_df), step15f_rows=len(new_df), missing_rows=missing, extra_rows=extra, mismatches=missing + extra, status="PASS" if old == new else "FAIL"))
    old = pd.read_csv(BASE / "detector_features.csv", low_memory=False)
    new = pd.read_csv(RUN / "detector_features.csv", low_memory=False)
    rows.append(dict(component="market_clusters", baseline_rows=old.market_cluster_id.nunique(), step15f_rows=new.market_cluster_id.nunique(), missing_rows=0, extra_rows=0, mismatches=abs(old.market_cluster_id.nunique() - new.market_cluster_id.nunique()), status="PASS" if old.market_cluster_id.nunique() == new.market_cluster_id.nunique() else "FAIL"))
    result = pd.DataFrame(rows)
    REF.mkdir(parents=True, exist_ok=True)
    result.to_csv(REF / "step15f_behavior_comparison.csv", index=False)
    old_set = parse_set(BASE / "persistent_medium_horizon.set")
    new_set = parse_set(RUN / "persistent_context_features.set")
    ignored = {"InpRunId", "InpLogFolder", "InpSourceCommit", "InpEx5Hash", "InpSchemaVersion"}
    differences = []
    for key in sorted(set(old_set) | set(new_set)):
        if key not in ignored and old_set.get(key) != new_set.get(key):
            differences.append(dict(parameter=key, baseline=old_set.get(key, ""), step15f=new_set.get(key, ""), status="FAIL"))
    pd.DataFrame(differences, columns=["parameter", "baseline", "step15f", "status"]).to_csv(REF / "step15f_parameter_diff.csv", index=False)
    return result


def journal_and_tick_quality() -> None:
    journal = Path.home() / "AppData/Roaming/MetaQuotes/Tester/D232275B22422903BD477FB48B858FBA/Agent-127.0.0.1-3000/logs/20260830.log"
    text = journal.read_text(encoding="utf-16", errors="replace")
    lines = text.splitlines()
    starts = [i for i, line in enumerate(lines) if f"InpRunId={RUN_NEW}" in line]
    if not starts:
        raise RuntimeError("formal Step15F journal segment not found")
    start = starts[-1]
    passed = False
    end = len(lines) - 1
    for i in range(start, len(lines)):
        if "Test passed in" in lines[i]:
            passed = True
        if passed and "memory used" in lines[i]:
            end = i
            break
    selected = lines[start : end + 1]
    tokens = ("InpRunId=", "real ticks discarded", "tick prices mismatch", "tick volumes not matched", "last prices absent", "Test passed in", "total ticks for all symbols", "memory used", "deinitialized reason=")
    excerpt = [line for line in selected if any(token in line for token in tokens)]
    (RUN / "tester_journal_excerpt.txt").write_text("\n".join(excerpt) + "\n", encoding="utf-8")
    ep = pd.read_csv(RUN / "medium_horizon_episode_summary.csv", low_memory=False)
    summary = pd.read_csv(RUN / "summary.csv", low_memory=False)
    rows = []
    for symbol in ("EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "USDCHF"):
        row = summary[(summary.record_type == "SYMBOL") & (summary.key == symbol)].iloc[0]
        match = re.search(r"m1_minutes_seen=(\d+)", str(row.value))
        minutes = int(match.group(1)) if match else 0
        if symbol == "GBPUSD":
            rows.append(dict(symbol=symbol, ea_m1_minutes_seen=minutes, tester_reported_total_minutes=30187, tester_reported_discarded_minutes=179, tester_reported_fallback_rate_pct=179 / 30187 * 100, status="GENERATED_TICK_FALLBACK_OBSERVED", primary_treatment=f"ALL_{int((ep.symbol == symbol).sum())}_GBPUSD_EPISODES_EXCLUDED_INTERVAL_MAP_UNAVAILABLE", evidence="formal Step15F tester journal"))
        else:
            rows.append(dict(symbol=symbol, ea_m1_minutes_seen=minutes, tester_reported_total_minutes="", tester_reported_discarded_minutes="", tester_reported_fallback_rate_pct=0.0, status="NO_DISCARD_WARNING_OBSERVED", primary_treatment="PRIMARY_ELIGIBLE_IF_OTHER_GATES_PASS", evidence="formal Step15F tester journal"))
    pd.DataFrame(rows).to_csv(RUN / "tick_quality.csv", index=False)


def outward_quotes(bid: pd.Series, ask: pd.Series, factor: float) -> tuple[pd.Series, pd.Series]:
    mid = (bid + ask) / 2.0
    half = (ask - bid) * factor / 2.0
    return mid - half, mid + half


def build_dataset() -> tuple[pd.DataFrame, pd.DataFrame, list[str], list[str]]:
    registry = pd.read_csv(OUT / "feature_registry.csv")
    names = registry["name"].tolist()
    ids = [x.lower() for x in registry["feature_id"].tolist()]
    context = [fid for fid in ids if fid not in {"f30", "f31", "f32", "f33", "f34", "f35"}]
    all_features = ids
    feat = pd.read_csv(RUN / "episode_context_features.csv", low_memory=False)
    rename = dict(zip(names, ids))
    feat = feat.rename(columns=rename)
    ep = pd.read_csv(RUN / "medium_horizon_episode_summary.csv", low_memory=False)
    ep["server_day"] = pd.to_datetime(ep.anchor_msc, unit="ms", utc=True).dt.strftime("%Y-%m-%d")
    resp = pd.read_csv(RUN / "medium_horizon_response.csv", low_memory=False)
    entry = resp[resp.checkpoint_seconds.isin(DECISIONS)][["episode_id", "checkpoint_seconds", "availability", "bid", "ask", "quote_msc", "processing_msc", "primary_inference"]].rename(columns={"checkpoint_seconds": "decision_seconds", "availability": "entry_availability", "bid": "entry_bid", "ask": "entry_ask", "quote_msc": "entry_quote_msc", "processing_msc": "entry_processing_msc"})
    df = feat.merge(ep[["episode_id", "anchor_msc", "episode_status", "validation_status", "server_day", "pre_vol_status"]], on="episode_id", how="left").merge(entry, on=["episode_id", "decision_seconds"], how="left")
    df["primary_population"] = df.symbol.ne("GBPUSD") & df.episode_status.eq("COMPLETE_900S") & df.validation_status.eq("VALID") & df.entry_availability.eq("AVAILABLE") & df.primary_inference.eq("ELIGIBLE")
    df["server_hour"] = pd.to_datetime(df.target_msc, unit="ms", utc=True).dt.hour
    df["weekday"] = pd.to_datetime(df.target_msc, unit="ms", utc=True).dt.weekday
    df["direction_sign"] = np.where(df.shock_direction.eq("LONG"), 1.0, -1.0)
    for horizon in HORIZONS:
        ex = resp[resp.checkpoint_seconds.eq(horizon)][["episode_id", "availability", "bid", "ask", "quote_msc", "mfe", "mae", "time_to_mfe_ms", "time_to_mae_ms", "primary_inference"]].rename(columns={c: f"h{horizon}_{c}" for c in ["availability", "bid", "ask", "quote_msc", "mfe", "mae", "time_to_mfe_ms", "time_to_mae_ms", "primary_inference"]})
        df = df.merge(ex, on="episode_id", how="left")
        long = df.shock_direction.eq("LONG")
        df[f"h{horizon}_continuation"] = np.where(long, df[f"h{horizon}_bid"] - df.entry_ask, df.entry_bid - df[f"h{horizon}_ask"])
        df[f"h{horizon}_reversal"] = np.where(long, df.entry_bid - df[f"h{horizon}_ask"], df[f"h{horizon}_bid"] - df.entry_ask)
        entry_bid_125, entry_ask_125 = outward_quotes(df.entry_bid, df.entry_ask, 1.25)
        exit_bid_125, exit_ask_125 = outward_quotes(df[f"h{horizon}_bid"], df[f"h{horizon}_ask"], 1.25)
        df[f"h{horizon}_continuation_125x"] = np.where(long, exit_bid_125 - entry_ask_125, entry_bid_125 - exit_ask_125)
        df[f"h{horizon}_reversal_125x"] = np.where(long, entry_bid_125 - exit_ask_125, exit_bid_125 - entry_ask_125)
        spread = (df.entry_ask - df.entry_bid).replace(0, np.nan)
        for action in ("continuation", "reversal"):
            df[f"h{horizon}_{action}_spread_multiple"] = df[f"h{horizon}_{action}"] / spread
            df[f"h{horizon}_{action}_125x_spread_multiple"] = df[f"h{horizon}_{action}_125x"] / spread
        df[f"h{horizon}_outcome_available"] = df[f"h{horizon}_availability"].eq("AVAILABLE") & df[f"h{horizon}_primary_inference"].eq("ELIGIBLE") & (df[f"h{horizon}_quote_msc"] > df.entry_quote_msc)
    df = df.replace([np.inf, -np.inf], np.nan)
    controls = pd.read_csv(RUN / "matched_control_features.csv", low_memory=False)
    controls["server_hour"] = pd.to_datetime(controls.target_msc, unit="ms", utc=True).dt.hour
    controls["weekday"] = pd.to_datetime(controls.target_msc, unit="ms", utc=True).dt.weekday
    controls = controls.replace([np.inf, -np.inf], np.nan)
    return df, controls, context, all_features


def make_folds(df: pd.DataFrame) -> pd.DataFrame:
    base = df[["episode_id", "market_cluster_id", "anchor_msc", "server_day"]].drop_duplicates("episode_id").sort_values(["anchor_msc", "market_cluster_id"])
    clusters = base.groupby("market_cluster_id", as_index=False).anchor_msc.min().sort_values("anchor_msc")
    chunks = np.array_split(clusters.market_cluster_id.to_numpy(), 6)
    rows = []
    for fold in range(5):
        test_clusters = set(chunks[fold + 1].tolist())
        test_start = int(clusters[clusters.market_cluster_id.isin(test_clusters)].anchor_msc.min())
        train_cutoff = test_start - 15 * 60 * 1000
        for row in base.itertuples(index=False):
            role = "TEST" if row.market_cluster_id in test_clusters else ("TRAIN" if row.anchor_msc < train_cutoff else "PURGED_OR_EMBARGOED")
            rows.append(dict(fold=fold, episode_id=row.episode_id, market_cluster_id=row.market_cluster_id, anchor_msc=row.anchor_msc, server_day=row.server_day, role=role, train_cutoff_msc=train_cutoff, purge_ms=900000, embargo_ms=900000))
    return pd.DataFrame(rows)


def day_ci(df: pd.DataFrame, col: str, seed: int) -> tuple[float, float]:
    x = df[["server_day", col]].dropna()
    days = x.server_day.unique()
    if len(days) < 2:
        return np.nan, np.nan
    rng = np.random.default_rng(seed)
    groups = {day: x.loc[x.server_day.eq(day), col].to_numpy() for day in days}
    means = []
    for _ in range(2000):
        draw = rng.choice(days, len(days), replace=True)
        means.append(np.concatenate([groups[d] for d in draw]).mean())
    return tuple(np.quantile(means, [0.025, 0.975]))


def coverage_outputs(df: pd.DataFrame, features: list[str]) -> None:
    rows = []
    for decision in DECISIONS:
        g = df[df.decision_seconds.eq(decision)]
        for feature in features:
            rows.append(dict(decision_seconds=decision, feature_id=feature.upper(), rows=len(g), available=int(g[feature].notna().sum()), missing=int(g[feature].isna().sum()), missing_rate=float(g[feature].isna().mean()), primary_available=int(g.loc[g.primary_population, feature].notna().sum()), primary_rows=int(g.primary_population.sum())))
    write(pd.DataFrame(rows), "feature_coverage.csv")
    dist = []
    for decision in DECISIONS:
        g = df[df.decision_seconds.eq(decision) & df.primary_population]
        for feature in features:
            x = g[feature].dropna()
            dist.append(dict(decision_seconds=decision, feature_id=feature.upper(), n=len(x), mean=x.mean(), std=x.std(), minimum=x.min(), q05=x.quantile(.05), q25=x.quantile(.25), median=x.median(), q75=x.quantile(.75), q95=x.quantile(.95), maximum=x.max()))
    write(pd.DataFrame(dist), "feature_distributions.csv")
    corr = []
    for decision in DECISIONS:
        c = df[df.decision_seconds.eq(decision) & df.primary_population][features].corr(min_periods=50)
        for i, a in enumerate(features):
            for b in features[i + 1 :]:
                corr.append(dict(decision_seconds=decision, feature_a=a.upper(), feature_b=b.upper(), correlation=c.loc[a, b], absolute_correlation=abs(c.loc[a, b]) if pd.notna(c.loc[a, b]) else np.nan))
    write(pd.DataFrame(corr), "feature_correlations.csv")


def model_pipeline(family: str, params: dict) -> Pipeline:
    steps = [("imputer", SimpleImputer(strategy="median", add_indicator=True, keep_empty_features=True)), ("scaler", StandardScaler())]
    if family == "ELASTIC_NET_REGRESSION":
        steps.append(("model", ElasticNet(alpha=params["alpha"], l1_ratio=params["l1_ratio"], max_iter=5000, random_state=SEED)))
    elif family == "ELASTIC_NET_LOGISTIC":
        steps.append(("model", LogisticRegression(C=params["C"], l1_ratio=params["l1_ratio"], solver="saga", max_iter=500, tol=1e-3, random_state=SEED)))
    else:
        steps = [("imputer", SimpleImputer(strategy="median", add_indicator=True, keep_empty_features=True)), ("model", GradientBoostingRegressor(max_depth=params["max_depth"], n_estimators=params["n_estimators"], learning_rate=params["learning_rate"], random_state=SEED, loss="huber"))]
    return Pipeline(steps)


GRIDS = {
    "ELASTIC_NET_REGRESSION": [{"alpha": a, "l1_ratio": l} for a in (0.001, 0.01, 0.1) for l in (0.1, 0.5, 0.9)],
    "ELASTIC_NET_LOGISTIC": [{"C": c, "l1_ratio": l} for c in (0.1, 1.0, 10.0) for l in (0.1, 0.5, 0.9)],
    "SHALLOW_GRADIENT_BOOSTING": [{"max_depth": d, "n_estimators": n, "learning_rate": lr} for d in (1, 2) for n in (50, 100) for lr in (0.03, 0.1)],
}


def inner_split(train: pd.DataFrame) -> tuple[np.ndarray, np.ndarray]:
    ordered = train.sort_values("anchor_msc")
    clusters = ordered[["market_cluster_id", "anchor_msc"]].drop_duplicates("market_cluster_id").sort_values("anchor_msc")
    cut = max(1, int(len(clusters) * 0.8))
    valid_clusters = set(clusters.iloc[cut:].market_cluster_id.tolist())
    if not valid_clusters:
        valid_clusters = {clusters.iloc[-1].market_cluster_id}
    valid_start = int(clusters[clusters.market_cluster_id.isin(valid_clusters)].anchor_msc.min())
    train_clusters = set(clusters[clusters.anchor_msc < valid_start - 900000].market_cluster_id.tolist())
    return train.market_cluster_id.isin(train_clusters).to_numpy(), train.market_cluster_id.isin(valid_clusters).to_numpy()


def run_models(df: pd.DataFrame, folds: pd.DataFrame, context_features: list[str], all_features: list[str]) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    predictions = []
    coefficients = []
    importance = []
    selected = []
    feature_sets = {"CONTEXT_ONLY": context_features, "CONTEXT_PLUS_SHOCK": all_features}
    for decision in DECISIONS:
        for horizon in HORIZONS:
            base = df[df.decision_seconds.eq(decision) & df.primary_population & df[f"h{horizon}_outcome_available"]].copy()
            for fold in range(5):
                role = folds[folds.fold.eq(fold)][["episode_id", "role"]]
                work = base.merge(role, on="episode_id", how="inner")
                train = work[work.role.eq("TRAIN")]
                test = work[work.role.eq("TEST")]
                if len(train) < 100 or len(test) < 20:
                    continue
                inner_train, inner_valid = inner_split(train)
                for feature_set, features in feature_sets.items():
                    x_train = train[features]
                    x_test = test[features]
                    for action in ACTIONS:
                        target = f"h{horizon}_{action.lower()}_spread_multiple"
                        y_train = train[target].to_numpy()
                        y_test = test[target].to_numpy()
                        for family in GRIDS:
                            best = None
                            for params in GRIDS[family]:
                                pipe = model_pipeline(family, params)
                                if family == "ELASTIC_NET_LOGISTIC":
                                    y_binary = (y_train > 0).astype(int)
                                    if len(np.unique(y_binary[inner_train])) < 2 or len(np.unique(y_binary[inner_valid])) < 2:
                                        continue
                                    pipe.fit(x_train.iloc[inner_train], y_binary[inner_train])
                                    pred = pipe.predict_proba(x_train.iloc[inner_valid])[:, 1]
                                    score = log_loss(y_binary[inner_valid], pred, labels=[0, 1])
                                else:
                                    pipe.fit(x_train.iloc[inner_train], y_train[inner_train])
                                    pred = pipe.predict(x_train.iloc[inner_valid])
                                    score = mean_squared_error(y_train[inner_valid], pred)
                                if best is None or score < best[0]:
                                    best = (score, params)
                            if best is None:
                                continue
                            pipe = model_pipeline(family, best[1])
                            fit_y = (y_train > 0).astype(int) if family == "ELASTIC_NET_LOGISTIC" else y_train
                            pipe.fit(x_train, fit_y)
                            pred = pipe.predict_proba(x_test)[:, 1] if family == "ELASTIC_NET_LOGISTIC" else pipe.predict(x_test)
                            selected.append(dict(decision_seconds=decision, horizon_seconds=horizon, fold=fold, feature_set=feature_set, action=action, model_family=family, inner_score=best[0], parameters=json.dumps(best[1], sort_keys=True), train_rows=len(train), test_rows=len(test)))
                            for ix, row in enumerate(test.itertuples()):
                                predictions.append(dict(episode_id=row.episode_id, market_cluster_id=row.market_cluster_id, server_day=row.server_day, symbol=row.symbol, fold=fold, decision_seconds=decision, horizon_seconds=horizon, feature_set=feature_set, action=action, model_family=family, prediction=pred[ix], actual=y_test[ix], actual_125x=getattr(row, f"h{horizon}_{action.lower()}_125x_spread_multiple")))
                            model = pipe.named_steps["model"]
                            if hasattr(model, "coef_"):
                                raw = np.asarray(model.coef_).reshape(-1)
                                for ix, value in enumerate(raw[: len(features)]):
                                    coefficients.append(dict(decision_seconds=decision, horizon_seconds=horizon, fold=fold, feature_set=feature_set, action=action, model_family=family, feature_id=features[ix].upper(), coefficient=value))
                            if family != "ELASTIC_NET_LOGISTIC":
                                pi = permutation_importance(pipe, x_test, y_test, n_repeats=3, random_state=SEED + fold, scoring="neg_mean_squared_error")
                                for ix, feature in enumerate(features):
                                    importance.append(dict(decision_seconds=decision, horizon_seconds=horizon, fold=fold, feature_set=feature_set, action=action, model_family=family, feature_id=feature.upper(), importance_mean=pi.importances_mean[ix], importance_std=pi.importances_std[ix]))
    return pd.DataFrame(predictions), pd.DataFrame(selected), pd.DataFrame(coefficients), pd.DataFrame(importance)


def summarize_models(pred: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    rows = []
    calibration = []
    chosen = []
    group = ["decision_seconds", "horizon_seconds", "feature_set", "model_family"]
    for keys, g in pred.groupby(group):
        decision, horizon, feature_set, family = keys
        if family == "ELASTIC_NET_LOGISTIC":
            for action, a in g.groupby("action"):
                y = (a.actual > 0).astype(int)
                auc = roc_auc_score(y, a.prediction) if y.nunique() > 1 else np.nan
                rows.append(dict(decision_seconds=decision, horizon_seconds=horizon, feature_set=feature_set, model_family=family, action=action, rows=len(a), coverage=np.nan, chosen_mean=np.nan, chosen_125x_mean=np.nan, positive_fraction=y.mean(), rmse=np.nan, auc=auc, ci_low=np.nan, ci_high=np.nan))
                bins = pd.qcut(a.prediction.rank(method="first"), 5, labels=False)
                for b, q in a.assign(bin=bins).groupby("bin"):
                    calibration.append(dict(decision_seconds=decision, horizon_seconds=horizon, feature_set=feature_set, model_family=family, action=action, bin=int(b), rows=len(q), predicted_probability=q.prediction.mean(), observed_positive=(q.actual > 0).mean()))
            continue
        wide = g.pivot_table(index=["episode_id", "market_cluster_id", "server_day", "symbol", "fold"], columns="action", values=["prediction", "actual", "actual_125x"]).reset_index()
        pc = wide[("prediction", "CONTINUATION")]
        pr = wide[("prediction", "REVERSAL")]
        action = np.where((pc <= 0) & (pr <= 0), "NO_TRADE", np.where(pc >= pr, "CONTINUATION", "REVERSAL"))
        actual = np.where(action == "CONTINUATION", wide[("actual", "CONTINUATION")], np.where(action == "REVERSAL", wide[("actual", "REVERSAL")], 0.0))
        stress = np.where(action == "CONTINUATION", wide[("actual_125x", "CONTINUATION")], np.where(action == "REVERSAL", wide[("actual_125x", "REVERSAL")], 0.0))
        flat = pd.DataFrame({"episode_id": wide[("episode_id", "")], "market_cluster_id": wide[("market_cluster_id", "")], "server_day": wide[("server_day", "")], "symbol": wide[("symbol", "")], "fold": wide[("fold", "")], "chosen_action": action, "chosen_actual": actual, "chosen_actual_125x": stress})
        flat["decision_seconds"] = decision; flat["horizon_seconds"] = horizon; flat["feature_set"] = feature_set; flat["model_family"] = family
        chosen.append(flat)
        lo, hi = day_ci(flat, "chosen_actual", SEED + int(decision) + int(horizon))
        rows.append(dict(decision_seconds=decision, horizon_seconds=horizon, feature_set=feature_set, model_family=family, action="CHOSEN", rows=len(flat), coverage=(flat.chosen_action != "NO_TRADE").mean(), chosen_mean=flat.chosen_actual.mean(), chosen_125x_mean=flat.chosen_actual_125x.mean(), positive_fraction=(flat.chosen_actual > 0).mean(), rmse=np.sqrt(np.mean((g.prediction - g.actual) ** 2)), auc=np.nan, ci_low=lo, ci_high=hi))
    return pd.DataFrame(rows), pd.DataFrame(calibration), pd.concat(chosen, ignore_index=True) if chosen else pd.DataFrame()


def univariate_and_interactions(df: pd.DataFrame, folds: pd.DataFrame, features: list[str]) -> tuple[pd.DataFrame, pd.DataFrame]:
    univariate = []
    interaction = []
    for decision in DECISIONS:
        for horizon in HORIZONS:
            base = df[df.decision_seconds.eq(decision) & df.primary_population & df[f"h{horizon}_outcome_available"]].copy()
            base["i01"] = base.f08
            base["i02"] = base.f09
            base["i03"] = base.f01 * base.f30
            base["i04"] = base.f06 * base.f34
            base["i05"] = base.f13 * base.f35
            base["i06"] = base.f24 * base.f30
            base["i07"] = base.f26 * decision
            base["i08"] = base.f36
            base["i09"] = (base.server_hour // 4) * base.f24
            base["i10"] = base.f23 * base.f33
            base["i11"] = base.f28 / (1.0 + base.f27)
            base["i12"] = (2.0 * base.f15 - 1.0) * base.direction_sign
            for fold in range(5):
                work = base.merge(folds[folds.fold.eq(fold)][["episode_id", "role"]], on="episode_id", how="inner")
                train = work[work.role.eq("TRAIN")]; test = work[work.role.eq("TEST")]
                for action in ACTIONS:
                    target = f"h{horizon}_{action.lower()}_spread_multiple"
                    for feature in features:
                        values = train[feature].dropna()
                        if values.nunique() < 5:
                            continue
                        edges = np.unique(values.quantile([0, .2, .4, .6, .8, 1]).to_numpy())
                        if len(edges) < 3:
                            continue
                        edges[0] = -np.inf; edges[-1] = np.inf
                        buckets = pd.cut(test[feature], edges, labels=False, include_lowest=True)
                        for bucket, g in test.assign(bucket=buckets).dropna(subset=["bucket"]).groupby("bucket"):
                            lo, hi = day_ci(g, target, SEED + fold)
                            univariate.append(dict(decision_seconds=decision, horizon_seconds=horizon, fold=fold, action=action, feature_id=feature.upper(), bucket=int(bucket), lower_edge=edges[int(bucket)], upper_edge=edges[int(bucket)+1], episodes=len(g), market_clusters=g.market_cluster_id.nunique(), mean=g[target].mean(), positive_fraction=(g[target] > 0).mean(), mfe=g[f"h{horizon}_mfe"].mean(), mae=g[f"h{horizon}_mae"].mean(), ci_low=lo, ci_high=hi, max_symbol_share=g.symbol.value_counts(normalize=True).max()))
                    for name in [f"i{i:02d}" for i in range(1, 13)]:
                        z = test[[name, target]].dropna()
                        rho = z[name].corr(z[target]) if len(z) >= 20 else np.nan
                        interaction.append(dict(decision_seconds=decision, horizon_seconds=horizon, fold=fold, action=action, interaction_id=name.upper(), episodes=len(z), correlation=rho, mean_target=z[target].mean()))
    return pd.DataFrame(univariate), pd.DataFrame(interaction)


def matched_controls(df: pd.DataFrame, controls: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    matches = []
    summary = []
    used: set[str] = set()
    covariates = ["f05", "f11", "f21", "f24", "f25"]
    eligible_controls = controls[controls.symbol.ne("GBPUSD") & ~controls.reason.isin(["SHOCK_PURGE", "STALE_OR_INVALID_QUOTE", "END_OF_DATA"])].copy()
    shocks = df[df.primary_population].sort_values(["target_msc", "episode_id"])
    for shock in shocks.itertuples(index=False):
        pool = eligible_controls[(eligible_controls.symbol == shock.symbol) & (eligible_controls.decision_seconds == shock.decision_seconds) & (eligible_controls.server_hour == shock.server_hour) & (eligible_controls.weekday == shock.weekday) & ~eligible_controls.control_id.isin(used)].copy()
        if pool.empty:
            continue
        distance = np.zeros(len(pool)); valid = np.zeros(len(pool), dtype=int)
        for feature in covariates:
            sv = getattr(shock, feature)
            pv = pd.to_numeric(pool[feature], errors="coerce")
            scale = np.nanmedian(np.abs(pv - np.nanmedian(pv))) * 1.4826
            if pd.notna(sv) and np.isfinite(scale) and scale > 0:
                ok = pv.notna().to_numpy(); distance[ok] += ((pv.to_numpy()[ok] - sv) / scale) ** 2; valid[ok] += 1
        distance[valid < 3] = np.inf
        if not np.isfinite(distance).any():
            continue
        ix = int(np.argmin(distance)); control = pool.iloc[ix]; used.add(str(control.control_id))
        for horizon in HORIZONS:
            for action in ACTIONS:
                shock_value = getattr(shock, f"h{horizon}_{action.lower()}_spread_multiple")
                control_raw = control[f"h{horizon}_{action.lower()}"]
                control_spread = float(control.entry_ask - control.entry_bid)
                control_value = control_raw / control_spread if pd.notna(control_raw) and control_spread > 0 else np.nan
                matches.append(dict(episode_id=shock.episode_id, control_id=control.control_id, symbol=shock.symbol, server_day=shock.server_day, decision_seconds=shock.decision_seconds, horizon_seconds=horizon, action=action, distance=float(math.sqrt(distance[ix])), matched_covariates=int(valid[ix]), shock_return=shock_value, control_return=control_value, difference=shock_value-control_value if pd.notna(control_value) else np.nan))
    m = pd.DataFrame(matches)
    if not m.empty:
        for keys, g in m.groupby(["decision_seconds", "horizon_seconds", "action"]):
            lo,hi=day_ci(g,"difference",SEED+int(keys[0])+int(keys[1]))
            summary.append(dict(decision_seconds=keys[0], horizon_seconds=keys[1], action=keys[2], matched_pairs=g.difference.notna().sum(), unique_episodes=g.episode_id.nunique(), unique_controls=g.control_id.nunique(), shock_mean=g.shock_return.mean(), control_mean=g.control_return.mean(), difference_mean=g.difference.mean(), difference_ci_low=lo, difference_ci_high=hi, status="DEVELOPMENT_MATCHED_DIAGNOSTIC"))
    return m, pd.DataFrame(summary)


def baseline_results(df: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for decision in DECISIONS:
        for horizon in HORIZONS:
            g = df[df.decision_seconds.eq(decision) & df.primary_population & df[f"h{horizon}_outcome_available"]]
            for action in ACTIONS:
                col = f"h{horizon}_{action.lower()}_spread_multiple"
                stress = f"h{horizon}_{action.lower()}_125x_spread_multiple"
                lo, hi = day_ci(g, col, SEED + decision + horizon)
                rows.append(dict(decision_seconds=decision, horizon_seconds=horizon, action=action, episodes=len(g), market_clusters=g.market_cluster_id.nunique(), server_days=g.server_day.nunique(), mean=g[col].mean(), median=g[col].median(), positive_fraction=(g[col] > 0).mean(), ci_low=lo, ci_high=hi, spread_125x_mean=g[stress].mean(), formal_net_status="UNAVAILABLE_COMMISSION_SLIPPAGE_INCOMPLETE"))
            rows.append(dict(decision_seconds=decision, horizon_seconds=horizon, action="NO_TRADE", episodes=len(g), market_clusters=g.market_cluster_id.nunique(), server_days=g.server_day.nunique(), mean=0.0, median=0.0, positive_fraction=0.0, ci_low=0.0, ci_high=0.0, spread_125x_mean=0.0, formal_net_status="NOT_APPLICABLE"))
    return pd.DataFrame(rows)


def sensitivity(chosen: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    loso = []
    lodo = []
    if chosen.empty:
        return pd.DataFrame(), pd.DataFrame()
    keys = ["decision_seconds", "horizon_seconds", "feature_set", "model_family"]
    for group, g in chosen.groupby(keys):
        for symbol in sorted(g.symbol.unique()):
            x = g[g.symbol.ne(symbol)]
            loso.append(dict(decision_seconds=group[0], horizon_seconds=group[1], feature_set=group[2], model_family=group[3], omitted_symbol=symbol, episodes=len(x), mean=x.chosen_actual.mean(), sign_positive=bool(x.chosen_actual.mean() > 0)))
        for day in sorted(g.server_day.unique()):
            x = g[g.server_day.ne(day)]
            lodo.append(dict(decision_seconds=group[0], horizon_seconds=group[1], feature_set=group[2], model_family=group[3], omitted_server_day=day, episodes=len(x), mean=x.chosen_actual.mean(), sign_positive=bool(x.chosen_actual.mean() > 0)))
    return pd.DataFrame(loso), pd.DataFrame(lodo)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    comparison = behavior_comparison()
    if int(comparison.mismatches.sum()) != 0:
        raise SystemExit("Step15E behavior mismatch; analysis stopped")
    journal_and_tick_quality()
    df, controls, context_features, all_features = build_dataset()
    coverage_outputs(df, all_features)
    folds = make_folds(df[df.primary_population])
    write(folds, "fold_assignment.csv")
    base = baseline_results(df)
    write(base, "continuation_reversal_results.csv")
    pred, selected, coef, importance = run_models(df, folds, context_features, all_features)
    write(pred, "oof_predictions.csv")
    write(selected, "model_selection.csv")
    write(coef, "model_coefficients.csv")
    write(importance, "permutation_importance.csv")
    model, calibration, chosen = summarize_models(pred)
    write(model, "model_comparison.csv")
    write(calibration, "calibration.csv")
    write(chosen, "chosen_action_oof.csv")
    stability = importance.groupby(["decision_seconds", "horizon_seconds", "feature_set", "action", "model_family", "feature_id"], as_index=False).agg(folds=("fold", "nunique"), mean_importance=("importance_mean", "mean"), positive_folds=("importance_mean", lambda x: int((x > 0).sum())), importance_std_across_folds=("importance_mean", "std")) if not importance.empty else pd.DataFrame()
    write(stability, "importance_stability.csv")
    univariate, interactions = univariate_and_interactions(df, folds, all_features)
    write(univariate, "univariate_bucket_results.csv")
    write(interactions, "interaction_results.csv")
    matches, match_summary = matched_controls(df, controls)
    write(matches, "matched_control_pairs.csv")
    write(match_summary, "matched_control_results.csv")
    loso, lodo = sensitivity(chosen)
    write(loso, "leave_one_symbol_out.csv")
    write(lodo, "leave_one_day_out.csv")
    incremental = model.pivot_table(index=["decision_seconds", "horizon_seconds", "model_family", "action"], columns="feature_set", values=["chosen_mean", "chosen_125x_mean", "coverage", "auc"]).reset_index()
    if not incremental.empty:
        for metric in ("chosen_mean", "chosen_125x_mean", "coverage", "auc"):
            if (metric, "CONTEXT_PLUS_SHOCK") in incremental and (metric, "CONTEXT_ONLY") in incremental:
                incremental[(metric, "incremental")] = incremental[(metric, "CONTEXT_PLUS_SHOCK")] - incremental[(metric, "CONTEXT_ONLY")]
        incremental.columns = ["_".join([str(x) for x in col if str(x)]) if isinstance(col, tuple) else col for col in incremental.columns]
    write(incremental, "context_vs_shock_added.csv")
    tests = []
    for row in model[model.action.eq("CHOSEN")].itertuples(index=False):
        values = chosen[(chosen.decision_seconds == row.decision_seconds) & (chosen.horizon_seconds == row.horizon_seconds) & (chosen.feature_set == row.feature_set) & (chosen.model_family == row.model_family)].chosen_actual
        p = stats.ttest_1samp(values, 0, alternative="greater").pvalue if len(values) > 1 else 1.0
        tests.append(dict(decision_seconds=row.decision_seconds, horizon_seconds=row.horizon_seconds, feature_set=row.feature_set, model_family=row.model_family, mean=row.chosen_mean, p_raw=p))
    mt = pd.DataFrame(tests)
    if not mt.empty:
        order = np.argsort(mt.p_raw.to_numpy()); adjusted = np.ones(len(mt)); running = 0.0
        for rank, ix in enumerate(order):
            running = max(running, (len(mt) - rank) * mt.iloc[ix].p_raw); adjusted[ix] = min(1.0, running)
        mt["p_holm"] = adjusted; mt["method"] = "HOLM_FWER_PRIMARY_0.05"
    write(mt, "multiple_testing_results.csv")
    cost = model[model.action.eq("CHOSEN")][["decision_seconds", "horizon_seconds", "feature_set", "model_family", "rows", "coverage", "chosen_mean", "chosen_125x_mean", "ci_low", "ci_high"]].copy()
    cost["commission_status"] = "INCOMPLETE_NOT_IMPUTED_ZERO"; cost["formal_net"] = np.nan
    write(cost, "cost_sensitivity.csv")
    candidate_columns = ["candidate_id", "direction", "decision_seconds", "horizon_seconds", "predicates", "cost_ceiling", "episodes", "market_blocks", "mean", "ci_low", "p_holm", "positive_folds", "loso_all_positive", "spread_125x_mean", "context_incremental", "status"]
    candidates = pd.DataFrame(columns=candidate_columns)
    write(candidates, "candidate_registry.csv")
    funnel = []
    for decision in DECISIONS:
        g = df[df.decision_seconds.eq(decision)]
        primary = g[g.symbol.ne("GBPUSD")]
        for horizon in HORIZONS:
            funnel.append(dict(decision_seconds=decision, horizon_seconds=horizon, total_episodes=g.episode_id.nunique(), fallback_excluded=int(g.symbol.eq("GBPUSD").sum()), primary_population=primary.episode_id.nunique(), valid_entry=int(primary.primary_population.sum()), valid_exit=int((primary.primary_population & primary[f"h{horizon}_outcome_available"]).sum()), partial_feature_rows=int((primary.primary_population & primary[all_features].isna().any(axis=1)).sum()), complete_feature_rows=int((primary.primary_population & primary[all_features].notna().all(axis=1)).sum()), reconciled=bool(g.episode_id.nunique() == int(g.symbol.eq("GBPUSD").sum()) + primary.episode_id.nunique())))
    write(pd.DataFrame(funnel), "primary_population_funnel.csv")
    control_status = pd.DataFrame([dict(total_control_anchors=controls.control_id.nunique(), control_rows=len(controls), valid_or_partial_rows=int((~controls.reason.isin(["SHOCK_PURGE", "STALE_OR_INVALID_QUOTE", "END_OF_DATA"])).sum()), shock_purge_rows=int(controls.reason.eq("SHOCK_PURGE").sum()), stale_rows=int(controls.reason.eq("STALE_OR_INVALID_QUOTE").sum()), end_of_data_rows=int(controls.reason.eq("END_OF_DATA").sum()), matched_unique_controls=matches.control_id.nunique() if not matches.empty else 0)])
    write(control_status, "control_funnel.csv")
    registry = pd.read_csv(OUT / "feature_registry.csv")
    trial = pd.read_csv(OUT / "trial_registry.csv").iloc[0]
    metadata = dict(python=sys.version.split()[0], platform=platform.platform(), pandas=pd.__version__, numpy=np.__version__, scipy=scipy.__version__, sklearn=sklearn.__version__, seed=SEED, feature_spec_sha256=str(registry.spec_hash.iloc[0]), feature_registry_file_sha256=sha256(OUT / "feature_registry.csv"), model_family_sha256=str(trial.model_family_hash), trial_registry_file_sha256=sha256(OUT / "trial_registry.csv"), run_id=RUN_NEW, source_commit="26faf274b87b882745a9a62bfb521fea08d9bf7f", development_only=True, candidate_count=0, behavior_mismatches=int(comparison.mismatches.sum()), parameter_differences=sum(1 for _ in csv.DictReader((REF / "step15f_parameter_diff.csv").open(encoding="utf-8"))), production_orders=max(0, sum(1 for _ in (RUN / "trades.csv").open(encoding="utf-8-sig")) - 1), status=["CAUSAL_CONTEXT_FEATURES_CHARACTERIZED_ON_DEVELOPMENT_DATA", "NO_CONTEXT_RULE_HYPOTHESIS_FROZEN", "COST_MODEL_INCOMPLETE", "FORMAL_NET_EXPECTANCY_UNAVAILABLE", "EDGE_UNDETERMINED", "PRODUCTION_NOT_ELIGIBLE"])
    (OUT / "analysis_summary.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(json.dumps({"rows": len(df), "primary_rows": int(df.primary_population.sum()), "controls": int(controls.control_id.nunique()), "oof_predictions": len(pred), "candidates": 0, "behavior_mismatches": int(comparison.mismatches.sum())}))


if __name__ == "__main__":
    main()
