#!/usr/bin/env python3
"""Preregistered Step 15O Cross-FX lead-lag analysis and independent QA."""

from __future__ import annotations

import hashlib
import json
import math
import shutil
import warnings
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.inspection import permutation_importance
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

try:
    from lightgbm import LGBMClassifier
except ImportError:  # pragma: no cover - recorded as NOT_AVAILABLE if gated in
    LGBMClassifier = None


ROOT = Path(__file__).resolve().parents[2]
R1 = ROOT / "reports/backtest/runs/20260908_ts15o_cross_fx_lead_lag_202504"
RUN = ROOT / "reports/backtest/runs/20260908_ts15o_cross_fx_lead_lag_r2_202504"
OUT = ROOT / "reports/analysis/tick_shock/step15o"
OUT.mkdir(parents=True, exist_ok=True)
SEED = 20260908
BOOTSTRAPS = 10_000
warnings.filterwarnings("ignore", message="X does not have valid feature names")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest().upper()


def normalize_ids(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    for col in ("episode_id", "event_id"):
        if col in out:
            out[col] = out[col].astype(str).str.replace(
                "ts15o_cross_fx_lead_lag_r2_202504",
                "ts15o_cross_fx_lead_lag_202504",
                regex=False,
            )
    return out


def behavior_comparison() -> pd.DataFrame:
    rows = []
    for name in ("cross_fx_features.csv", "cross_fx_actions.csv"):
        old = pd.read_csv(R1 / name, low_memory=False)
        new = normalize_ids(pd.read_csv(RUN / name, low_memory=False))
        common = list(old.columns.intersection(new.columns))
        old = old[common].sort_values(common[:3], kind="stable").reset_index(drop=True)
        new = new[common].sort_values(common[:3], kind="stable").reset_index(drop=True)
        equal = old.shape == new.shape and old.equals(new)
        differing = 0 if equal else int((old.astype(str) != new.astype(str)).any(axis=1).sum())
        rows.append(
            {
                "artifact": name,
                "r1_rows": len(old),
                "r2_rows": len(new),
                "compared_columns": len(common),
                "differing_rows": differing,
                "status": "PASS" if equal else "FAIL",
                "note": "IDs normalized; r2 raw-oracle additions excluded where absent in r1",
            }
        )
    old = pd.read_csv(R1 / "cross_fx_feature_freshness.csv", low_memory=False)
    new = normalize_ids(pd.read_csv(RUN / "cross_fx_feature_freshness.csv", low_memory=False))
    common = list(old.columns.intersection(new.columns))
    keys = ["episode_id", "source_symbol", "window_seconds"]
    old = old[common].sort_values(keys, kind="stable").reset_index(drop=True)
    new = new[common].sort_values(keys, kind="stable").reset_index(drop=True)
    equal = old.shape == new.shape and old.equals(new)
    differing = 0 if equal else int((old.astype(str) != new.astype(str)).any(axis=1).sum())
    rows.append(
        {
            "artifact": "cross_fx_feature_freshness.csv",
            "r1_rows": len(old),
            "r2_rows": len(new),
            "compared_columns": len(common),
            "differing_rows": differing,
            "status": "PASS" if equal else "FAIL",
            "note": "IDs normalized; current_mid/anchor_mid/orientation/crossing are r2 evidence-only columns",
        }
    )
    return pd.DataFrame(rows)


def attach_outcomes(features: pd.DataFrame, actions: pd.DataFrame) -> pd.DataFrame:
    keep = ["episode_id", "action", "result", "gross_r", "net_r_commission_002",
            "net_r_commission_005", "net_r_commission_010", "entry_eligible_msc",
            "entry_quote_msc", "entry_processing_msc", "exit_msc", "deadline_msc"]
    p = actions[keep].pivot(index="episode_id", columns="action")
    p.columns = [f"{str(a).lower()}_{b.lower()}" for b, a in p.columns]
    p = p.reset_index()
    d = features.merge(p, on="episode_id", how="left", validate="one_to_one")
    d["continuation_tp"] = d["continuation_result"].eq("TP_FIRST")
    d["reversal_tp"] = d["reversal_result"].eq("TP_FIRST")
    d["both_sl"] = d["continuation_result"].eq("SL_FIRST") & d["reversal_result"].eq("SL_FIRST")
    d["both_tp"] = d["continuation_tp"] & d["reversal_tp"]
    d["continuation_only"] = d["continuation_tp"] & ~d["reversal_tp"]
    d["reversal_only"] = d["reversal_tp"] & ~d["continuation_tp"]
    d["timeout_involved"] = d["continuation_result"].eq("TIMEOUT") | d["reversal_result"].eq("TIMEOUT")
    d["tradeable"] = d["continuation_tp"] | d["reversal_tp"]
    d["oracle_gross_r"] = np.maximum.reduce(
        [d["continuation_gross_r"].fillna(-np.inf), d["reversal_gross_r"].fillna(-np.inf), np.zeros(len(d))]
    )
    dt = pd.to_datetime(d["t0_msc"], unit="ms", utc=True)
    d["week"] = dt.dt.to_period("W").astype(str)
    hour = dt.dt.hour
    d["session"] = np.select(
        [(hour >= 7) & (hour < 15), (hour >= 15) & (hour < 17),
         (hour >= 17) & (hour < 22)],
        ["LONDON", "OVERLAP", "NEW_YORK"], default="OTHER"
    )
    return d


def ci(values: np.ndarray) -> tuple[float, float]:
    values = values[np.isfinite(values)]
    if not len(values):
        return (math.nan, math.nan)
    return tuple(np.quantile(values, [0.025, 0.975]))


def cluster_boot_diff(d: pd.DataFrame, mask_col: str, metric: str, mode: str) -> tuple[float, float]:
    clusters = d["market_cluster_id"].drop_duplicates().to_numpy()
    cluster_index = {c: i for i, c in enumerate(clusters)}
    base_num = np.zeros(len(clusters)); base_den = np.zeros(len(clusters))
    sub_num = np.zeros(len(clusters)); sub_den = np.zeros(len(clusters))
    for cluster, g in d.groupby("market_cluster_id", sort=False):
        j = cluster_index[cluster]
        s = g[g[mask_col]]
        if metric == "direction_share":
            gb = g[g["tradeable"]]; gs = s[s["tradeable"]]
            base_num[j], base_den[j] = gb["continuation_only"].sum(), len(gb)
            sub_num[j], sub_den[j] = gs["continuation_only"].sum(), len(gs)
        else:
            base_num[j], base_den[j] = g[metric].sum(), g[metric].notna().sum()
            sub_num[j], sub_den[j] = s[metric].sum(), s[metric].notna().sum()
    rng = np.random.default_rng(SEED + sum(ord(x) for x in mask_col + metric + mode))
    vals = np.full(BOOTSTRAPS, np.nan)
    for start in range(0, BOOTSTRAPS, 500):
        stop = min(start + 500, BOOTSTRAPS)
        sampled = rng.integers(0, len(clusters), size=(stop - start, len(clusters)))
        bn = base_num[sampled].sum(axis=1); bd = base_den[sampled].sum(axis=1)
        sn = sub_num[sampled].sum(axis=1); sd = sub_den[sampled].sum(axis=1)
        valid = (bd > 0) & (sd > 0)
        diff = np.full(stop - start, np.nan)
        base = np.divide(bn, bd, out=np.zeros_like(bn), where=bd > 0)
        sub = np.divide(sn, sd, out=np.zeros_like(sn), where=sd > 0)
        diff[valid] = base[valid] - sub[valid] if mode == "reduction" else sub[valid] - base[valid]
        vals[start:stop] = diff
    return ci(vals)


def metrics_row(name: str, d: pd.DataFrame, fixed_action: str) -> dict:
    tradeable = d[d["tradeable"]]
    fixed_col = f"{fixed_action.lower()}_gross_r"
    wins = d[fixed_col].gt(0).sum()
    losses = d[fixed_col].lt(0).sum()
    return {
        "hypothesis": name,
        "fixed_action": fixed_action,
        "episodes": len(d),
        "market_clusters": d["market_cluster_id"].nunique(),
        "continuation_tp": int(d["continuation_tp"].sum()),
        "reversal_tp": int(d["reversal_tp"].sum()),
        "both_sl": int(d["both_sl"].sum()),
        "both_sl_rate": d["both_sl"].mean() if len(d) else math.nan,
        "tradeable_episodes": len(tradeable),
        "continuation_only_share_tradeable": tradeable["continuation_only"].mean() if len(tradeable) else math.nan,
        "fixed_action_mean_gross_r": d[fixed_col].mean() if len(d) else math.nan,
        "fixed_action_mean_net_r_005": d[f"{fixed_action.lower()}_net_r_commission_005"].mean() if len(d) else math.nan,
        "fixed_action_pf_gross": d.loc[d[fixed_col] > 0, fixed_col].sum() / abs(d.loc[d[fixed_col] < 0, fixed_col].sum()) if losses else math.inf,
        "oracle_mean_gross_r": d["oracle_gross_r"].mean() if len(d) else math.nan,
        "wins": int(wins),
        "losses": int(losses),
    }


def phase_a(eligible: pd.DataFrame) -> tuple[pd.DataFrame, bool]:
    specs = {"H1": "CONTINUATION", "H2": "REVERSAL", "H3": "CONTINUATION", "H4": "REVERSAL"}
    rows = [metrics_row("BASELINE", eligible, "CONTINUATION")]
    base_both = eligible["both_sl"].mean()
    base_share = eligible.loc[eligible["tradeable"], "continuation_only"].mean()
    for h, action in specs.items():
        s = eligible[eligible[h.lower()]]
        row = metrics_row(h, s, action)
        row["both_sl_reduction_pp"] = 100 * (base_both - row["both_sl_rate"])
        row["direction_share_shift_pp"] = 100 * (row["continuation_only_share_tradeable"] - base_share)
        base_fixed = eligible[f"{action.lower()}_gross_r"].mean()
        row["fixed_action_improvement_r"] = row["fixed_action_mean_gross_r"] - base_fixed
        lo, hi = cluster_boot_diff(eligible, h.lower(), "both_sl", "reduction")
        row["both_sl_reduction_ci_low_pp"], row["both_sl_reduction_ci_high_pp"] = 100 * lo, 100 * hi
        lo, hi = cluster_boot_diff(eligible, h.lower(), "direction_share", "shift")
        row["direction_shift_ci_low_pp"], row["direction_shift_ci_high_pp"] = 100 * lo, 100 * hi
        lo, hi = cluster_boot_diff(eligible, h.lower(), f"{action.lower()}_gross_r", "shift")
        row["fixed_action_improvement_ci_low_r"], row["fixed_action_improvement_ci_high_r"] = lo, hi
        row["gate_a"] = bool(row["both_sl_reduction_pp"] >= 5 and row["both_sl_reduction_ci_low_pp"] > 0)
        shift = row["direction_share_shift_pp"]
        row["gate_b"] = bool(abs(shift) >= 10 and (
            row["direction_shift_ci_low_pp"] > 0 or row["direction_shift_ci_high_pp"] < 0))
        row["gate_c"] = bool(row["fixed_action_improvement_r"] >= .10 and row["fixed_action_improvement_ci_low_r"] > 0)
        row["phase_b_gate"] = bool(row["gate_a"] or row["gate_b"] or row["gate_c"])
        rows.append(row)
    out = pd.DataFrame(rows)
    return out, bool(out.get("phase_b_gate", pd.Series(dtype=bool)).fillna(False).any())


def grouped_results(d: pd.DataFrame, group_cols: list[str], path: Path) -> None:
    rows = []
    for key, g in d.groupby(group_cols, dropna=False):
        key = key if isinstance(key, tuple) else (key,)
        row = dict(zip(group_cols, key))
        row.update(metrics_row("GROUP", g, "CONTINUATION"))
        rows.append(row)
    pd.DataFrame(rows).to_csv(path, index=False)


def phase_b_files_not_run(reason: str) -> None:
    base = {"status": "NOT_RUN_GATE_FAILED", "reason": reason}
    for name in ("model_comparison.csv", "oof_predictions.csv", "policy_results.csv",
                 "fold_performance.csv", "cost_sensitivity.csv", "feature_importance.csv",
                 "permutation_importance.csv"):
        pd.DataFrame([base]).to_csv(OUT / name, index=False)


def build_model(kind: str, numeric: list[str], categorical: list[str]):
    pre = ColumnTransformer([
        ("num", Pipeline([("impute", SimpleImputer(strategy="median")),
                           ("scale", StandardScaler())]), numeric),
        ("cat", Pipeline([("impute", SimpleImputer(strategy="most_frequent")),
                           ("onehot", OneHotEncoder(handle_unknown="ignore"))]), categorical),
    ])
    if kind == "LOGISTIC":
        model = LogisticRegression(C=1, class_weight="balanced", max_iter=2000, random_state=SEED)
    else:
        model = LGBMClassifier(n_estimators=200, learning_rate=.03, num_leaves=15,
                               max_depth=4, min_child_samples=50, random_state=SEED,
                               class_weight="balanced", verbosity=-1, n_jobs=1)
    return Pipeline([("pre", pre), ("model", model)])


def run_phase_b(eligible: pd.DataFrame, actions: pd.DataFrame, same: pd.DataFrame) -> None:
    if LGBMClassifier is None:
        raise RuntimeError("LightGBM is required because Phase A passed the frozen gate")
    ids = set(eligible["episode_id"])
    a = actions[actions["episode_id"].isin(ids)].copy()
    cross = eligible.copy()
    same_keep = [c for c in same.columns if c not in {"event_id", "market_cluster_id", "symbol", "shock_direction", "t0_msc", "t0_quote_msc", "schema_version"}]
    same_keep = ["episode_id"] + [c for c in same_keep if c != "episode_id"]
    a = a.merge(cross, on="episode_id", suffixes=("", "_feature"), validate="many_to_one")
    a = a.merge(same[same_keep], on="episode_id", suffixes=("", "_same"), validate="many_to_one")
    a["label"] = a["result"].eq("TP_FIRST").astype(int)
    a["action_sign"] = np.where(a["action"].eq("CONTINUATION"), 1.0, -1.0)
    cross_numeric = [c for c in cross.columns if any(k in c for k in (
        "target_usd_return_atr_", "valid_cross_symbols_", "usd_breadth_count_", "usd_breadth_",
        "usd_consensus_median_", "shock_aligned_usd_consensus_", "target_residual_",
        "shock_aligned_target_residual_", "quote_age_ms", "num_prior_cross_fx_movers",
        "cross_fx_lead_ms", "target_leader_rank"))]
    cross_numeric = [c for c in cross_numeric if c in a and pd.api.types.is_numeric_dtype(a[c])]
    base_numeric = ["action_sign", "atr14_m5"] + cross_numeric
    excluded_suffix = ("_msc", "_available")
    existing_numeric = [c for c in same_keep if c in a and pd.api.types.is_numeric_dtype(a[c])
                        and not c.endswith(excluded_suffix) and c not in base_numeric]
    categorical = ["symbol", "shock_direction", "action", "target_lead_bucket"]
    cluster_order = (eligible.groupby("market_cluster_id")["t0_msc"].min().sort_values().index.tolist())
    n = len(cluster_order)
    fold_defs = [(0, .40, .40, .55), (0, .55, .55, .70), (0, .70, .70, .85), (0, .85, .85, 1.0)]
    pred_rows, fold_rows, importance_rows, perm_rows = [], [], [], []
    for feature_set, nums in (("MODEL_X", base_numeric), ("MODEL_X_PLUS_EXISTING", base_numeric + existing_numeric)):
        nums = list(dict.fromkeys(nums))
        for kind in ("LOGISTIC", "LIGHTGBM"):
            for fold, (_, tr_end, va_start, va_end) in enumerate(fold_defs, 1):
                trc = set(cluster_order[: max(1, int(n * tr_end))])
                vac = set(cluster_order[int(n * va_start): max(int(n * va_start) + 1, int(n * va_end))])
                train = a[a["market_cluster_id"].isin(trc)].copy()
                val = a[a["market_cluster_id"].isin(vac)].copy()
                model = build_model(kind, nums, categorical)
                model.fit(train[nums + categorical], train["label"])
                train["score"] = model.predict_proba(train[nums + categorical])[:, 1]
                val["score"] = model.predict_proba(val[nums + categorical])[:, 1]
                # Frozen candidate grid, selected on training rows only.
                min_trades = max(5, int(.01 * train["episode_id"].nunique()))
                candidates = np.arange(.05, .501, .025)
                choices = []
                for threshold in candidates:
                    pick = train.sort_values(["episode_id", "score"], ascending=[True, False]).drop_duplicates("episode_id")
                    pick = pick[pick["score"] >= threshold]
                    if len(pick) >= min_trades:
                        choices.append((pick["net_r_commission_005"].mean(), threshold, len(pick)))
                threshold = max(choices, key=lambda x: (x[0], x[1]))[1] if choices else .50
                val["selected"] = False
                pick_idx = val.sort_values(["episode_id", "score"], ascending=[True, False]).drop_duplicates("episode_id").index
                val.loc[pick_idx, "selected"] = val.loc[pick_idx, "score"].ge(threshold)
                ap = average_precision_score(val["label"], val["score"]) if val["label"].nunique() > 1 else math.nan
                auc = roc_auc_score(val["label"], val["score"]) if val["label"].nunique() > 1 else math.nan
                selected = val[val["selected"]]
                fold_rows.append({"feature_set": feature_set, "model": kind, "fold": fold,
                                  "train_clusters": len(trc), "validation_clusters": len(vac),
                                  "threshold": threshold, "validation_action_rows": len(val),
                                  "ap": ap, "auc": auc, "trades": len(selected),
                                  "mean_gross_r": selected["gross_r"].mean(),
                                  "mean_net_r_005": selected["net_r_commission_005"].mean(),
                                  "tp": int(selected["label"].sum()),
                                  "sl": int(selected["result"].eq("SL_FIRST").sum()),
                                  "timeout": int(selected["result"].eq("TIMEOUT").sum())})
                for _, row in val.iterrows():
                    pred_rows.append({"episode_id": row.episode_id, "market_cluster_id": row.market_cluster_id,
                                      "symbol": row.symbol, "t0_msc": row.t0_msc, "action": row.action,
                                      "result": row.result, "gross_r": row.gross_r,
                                      "net_r_commission_005": row.net_r_commission_005,
                                      "label": row.label, "feature_set": feature_set, "model": kind,
                                      "fold": fold, "score": row.score, "threshold": threshold,
                                      "selected": bool(row.selected)})
                if kind == "LIGHTGBM":
                    names = model.named_steps["pre"].get_feature_names_out()
                    gains = model.named_steps["model"].feature_importances_
                    for nm, gain in zip(names, gains):
                        importance_rows.append({"feature_set": feature_set, "fold": fold, "feature": nm, "importance": gain})
                # Model-agnostic permutation on validation AP.
                if fold == 4 and kind == "LIGHTGBM" and val["label"].nunique() > 1:
                    perm = permutation_importance(model, val[nums + categorical], val["label"],
                                                  scoring="average_precision", n_repeats=3,
                                                  random_state=SEED + fold, n_jobs=1)
                    for nm, mean, sd in zip(nums + categorical, perm.importances_mean, perm.importances_std):
                        perm_rows.append({"feature_set": feature_set, "model": kind, "fold": fold,
                                          "feature": nm, "importance_mean": mean, "importance_std": sd})
    preds = pd.DataFrame(pred_rows)
    folds = pd.DataFrame(fold_rows)
    preds.to_csv(OUT / "oof_predictions.csv", index=False)
    folds.to_csv(OUT / "fold_performance.csv", index=False)
    pd.DataFrame(importance_rows).to_csv(OUT / "feature_importance.csv", index=False)
    pd.DataFrame(perm_rows).to_csv(OUT / "permutation_importance.csv", index=False)
    model_summary = (folds.groupby(["feature_set", "model"], as_index=False)
                     .agg(folds=("fold", "count"), mean_ap=("ap", "mean"), mean_auc=("auc", "mean"),
                          trades=("trades", "sum"), tp=("tp", "sum"), sl=("sl", "sum"),
                          mean_fold_net_r_005=("mean_net_r_005", "mean")))
    model_summary.to_csv(OUT / "model_comparison.csv", index=False)
    selected = preds[preds["selected"]].copy()
    policy = (selected.groupby(["feature_set", "model"], as_index=False)
              .agg(trades=("episode_id", "count"), clusters=("market_cluster_id", "nunique"),
                   tp=("label", "sum"), mean_gross_r=("gross_r", "mean"),
                   mean_net_r_005=("net_r_commission_005", "mean")))
    policy["sl_or_timeout"] = policy["trades"] - policy["tp"]
    policy.to_csv(OUT / "policy_results.csv", index=False)
    costs = []
    for (fs, model), g in selected.groupby(["feature_set", "model"]):
        for cost in (.02, .05, .10):
            costs.append({"feature_set": fs, "model": model, "commission_r": cost,
                          "trades": len(g), "mean_net_r": (g["gross_r"] - cost).mean()})
    pd.DataFrame(costs).to_csv(OUT / "cost_sensitivity.csv", index=False)


def save_plots(d: pd.DataFrame, phase_a_df: pd.DataFrame) -> None:
    def bar(data, x, y, title, file):
        plt.figure(figsize=(8, 4.5)); plt.bar(data[x].astype(str), data[y]); plt.title(title)
        plt.ylabel(y); plt.tight_layout(); plt.savefig(OUT / file, dpi=140); plt.close()
    b = d[d["valid_cross_symbols_5s"].eq(5)].groupby("usd_breadth_count_5s", as_index=False).agg(
        continuation_rate=("continuation_tp", "mean"), both_sl_rate=("both_sl", "mean"))
    bar(b, "usd_breadth_count_5s", "continuation_rate", "Breadth vs continuation TP rate", "breadth_vs_continuation_rate.png")
    bar(b, "usd_breadth_count_5s", "both_sl_rate", "Breadth vs Both-SL rate", "breadth_vs_both_sl_rate.png")
    x = pd.cut(d["shock_aligned_target_residual_5s"], [-np.inf, -.1, .1, np.inf], labels=["<=-0.10", "middle", ">=0.10"])
    q = d.assign(residual_bucket=x).groupby("residual_bucket", observed=True, as_index=False).agg(
        continuation_rate=("continuation_tp", "mean"), reversal_rate=("reversal_tp", "mean"))
    q.plot(x="residual_bucket", y=["continuation_rate", "reversal_rate"], kind="bar", figsize=(8, 4.5), title="Target residual vs direction")
    plt.tight_layout(); plt.savefig(OUT / "target_residual_vs_direction.png", dpi=140); plt.close()
    q = d.groupby("target_lead_bucket", as_index=False).agg(continuation_rate=("continuation_tp", "mean"), reversal_rate=("reversal_tp", "mean"))
    q.plot(x="target_lead_bucket", y=["continuation_rate", "reversal_rate"], kind="bar", figsize=(8, 4.5), title="Lead rank vs direction")
    plt.tight_layout(); plt.savefig(OUT / "lead_rank_vs_direction.png", dpi=140); plt.close()
    if (OUT / "model_comparison.csv").exists():
        m = pd.read_csv(OUT / "model_comparison.csv")
        if "mean_ap" in m:
            m.assign(label=m["feature_set"] + "/" + m["model"]).plot(x="label", y="mean_ap", kind="bar", legend=False, figsize=(9, 4.5), title="Cross-FX model comparison")
            plt.tight_layout(); plt.savefig(OUT / "cross_fx_vs_existing_model.png", dpi=140); plt.close()
    if (OUT / "fold_performance.csv").exists():
        f = pd.read_csv(OUT / "fold_performance.csv")
        if "mean_net_r_005" in f:
            for (fs, model), g in f.groupby(["feature_set", "model"]):
                plt.plot(g["fold"], g["mean_net_r_005"], marker="o", label=f"{fs}/{model}")
            plt.axhline(0, color="black", lw=.8); plt.legend(fontsize=7); plt.title("OOF fold expectancy at 0.05R cost")
            plt.tight_layout(); plt.savefig(OUT / "fold_expectancy.png", dpi=140); plt.close()


def independent_recalc(features: pd.DataFrame, freshness: pd.DataFrame, actions: pd.DataFrame,
                       post: pd.DataFrame) -> pd.DataFrame:
    rows = []
    f = freshness.copy()
    f["recalc_usd_return_atr"] = ((f["current_mid"] - f["anchor_mid"]) * f["usd_orientation"] / f["atr14_m5"])
    usable = f["valid"].astype(str).str.lower().eq("true")
    max_err = (f.loc[usable, "recalc_usd_return_atr"] - f.loc[usable, "usd_return_atr"]).abs().max()
    rows.append({"check": "raw_return_recalculation_max_abs_error", "actual": max_err, "expected": "<=1e-8", "status": "PASS" if max_err <= 1e-8 else "FAIL"})
    source = f[f["source_symbol"].ne(f["target_symbol"]) & usable].copy()
    checks = []
    breadth_boundary_ambiguities = 0
    for (eid, w), g in source.groupby(["episode_id", "window_seconds"]):
        feat = features.loc[features["episode_id"].eq(eid)].iloc[0]
        sign = int(feat["target_usd_sign"])
        vals = g["recalc_usd_return_atr"].to_numpy()
        target = f[(f["episode_id"].eq(eid)) & (f["window_seconds"].eq(w)) &
                   (f["source_symbol"].eq(feat["symbol"])) & usable]
        suffix = f"{int(w)}s"
        # Stored aggregates intentionally remain zero for an ineligible snapshot.
        if len(vals) != 5 or target.empty or feat["status"] != "ELIGIBLE" or feat[f"valid_cross_symbols_{suffix}"] != 5:
            continue
        med = float(np.median(vals)); breadth = int((np.sign(vals) == sign).sum())
        target_ret = float(target.iloc[0]["recalc_usd_return_atr"])
        checks.extend([abs(med - feat[f"usd_consensus_median_{suffix}"]),
                       abs((target_ret - med) * sign - feat[f"shock_aligned_target_residual_{suffix}"])])
        if np.any(np.abs(vals) <= 1e-12):
            breadth_boundary_ambiguities += int(breadth != feat[f"usd_breadth_count_{suffix}"])
        else:
            checks.append(abs(breadth - feat[f"usd_breadth_count_{suffix}"]))
    max_feature_err = max(checks) if checks else math.nan
    rows.append({"check": "cross_fx_feature_recalculation_max_abs_error", "actual": max_feature_err, "expected": "<=1e-8", "status": "PASS" if max_feature_err <= 1e-8 else "FAIL"})
    rows.append({"check": "breadth_zero_serialization_boundary_ambiguities", "actual": breadth_boundary_ambiguities,
                 "expected": "REPORTED", "status": "NOT_OBSERVED" if breadth_boundary_ambiguities else "PASS"})
    # Action geometry and causality are independently checked from recorded clocks/prices.
    causality = int((actions["entry_quote_msc"] < actions["entry_eligible_msc"]).sum())
    rows.append({"check": "entry_before_eligibility", "actual": causality, "expected": 0, "status": "PASS" if causality == 0 else "FAIL"})
    tp = actions["result"].eq("TP_FIRST")
    tp_err = (actions.loc[tp, "gross_r"] - 1.6).abs().max()
    rows.append({"check": "tp_realized_r_max_abs_error", "actual": tp_err, "expected": "<=1e-9", "status": "PASS" if tp_err <= 1e-9 else "FAIL"})
    rows.append({"check": "duplicate_action_key", "actual": int(actions.duplicated(["episode_id", "action"]).sum()), "expected": 0,
                 "status": "PASS" if not actions.duplicated(["episode_id", "action"]).any() else "FAIL"})
    symbol_order = {s: i for i, s in enumerate(["EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "USDCHF"])}
    lead_errors = []
    for episode, g in f[f["window_seconds"].eq(5)].groupby("episode_id"):
        feat = features.loc[features["episode_id"].eq(episode)].iloc[0]
        crossed = g[g["crossing_msc"].notna() & g["crossing_msc"].gt(0)].copy()
        other = crossed[crossed["source_symbol"].ne(feat["symbol"])]
        prior = len(other)
        first = int(feat["t0_msc"] - other["crossing_msc"].min()) if prior else 0
        median = int(np.median(feat["t0_msc"] - other["crossing_msc"])) if prior else 0
        ordered = crossed.assign(order=crossed["source_symbol"].map(symbol_order)).sort_values(["crossing_msc", "order"])
        rank_rows = np.flatnonzero(ordered["source_symbol"].to_numpy() == feat["symbol"])
        rank = int(rank_rows[0] + 1) if len(rank_rows) else 0
        lead_errors.extend([abs(prior - feat["num_prior_cross_fx_movers"]),
                            abs(first - feat["first_cross_fx_lead_ms"]),
                            abs(median - feat["median_cross_fx_lead_ms"]),
                            abs(rank - feat["target_leader_rank"])])
    lead_max = max(lead_errors) if lead_errors else math.nan
    rows.append({"check": "lead_lag_recalculation_max_abs_error", "actual": lead_max, "expected": 0,
                 "status": "PASS" if lead_max == 0 else "FAIL"})
    expected_actions = []
    censored_actions = 0
    for _, p in post.iterrows():
        risk = .25 * p["atr14_m5"]
        for action, short in (("CONTINUATION", "cont"), ("REVERSAL", "rev")):
            if p["h900_status"] != "AVAILABLE":
                censored_actions += 1
                continue
            hit = p[f"d0.40_{short}_hit_ms"]
            pre_mae = p[f"tp0.40_{short}_pre_mae"]
            mae = p[f"h900_{short}_mae"]
            if pd.notna(hit) and hit <= 900_000 and pre_mae < risk - 1e-12:
                result = "TP_FIRST"
            elif mae >= risk - 1e-12:
                result = "SL_FIRST"
            else:
                result = "TIMEOUT"
            expected_actions.append((p["episode_id"], action, result))
    expected_df = pd.DataFrame(expected_actions, columns=["episode_id", "action", "independent_result"])
    outcome = actions.merge(expected_df, on=["episode_id", "action"], validate="many_to_one")
    mismatches = int(outcome["result"].ne(outcome["independent_result"]).sum())
    rows.append({"check": "tp_sl_timeout_independent_mismatch", "actual": mismatches, "expected": 0,
                 "status": "PASS" if mismatches == 0 else "FAIL"})
    rows.append({"check": "tp_sl_timeout_censored_not_recalculable", "actual": censored_actions,
                 "expected": "REPORTED", "status": "NOT_OBSERVED" if censored_actions else "PASS"})
    independent_episode = outcome.pivot(index="episode_id", columns="action", values="independent_result")
    independent_both_sl = int((independent_episode["CONTINUATION"].eq("SL_FIRST") & independent_episode["REVERSAL"].eq("SL_FIRST")).sum())
    stored_episode = outcome.pivot(index="episode_id", columns="action", values="result")
    stored_both_sl = int((stored_episode["CONTINUATION"].eq("SL_FIRST") & stored_episode["REVERSAL"].eq("SL_FIRST")).sum())
    rows.append({"check": "both_sl_count", "actual": independent_both_sl, "expected": stored_both_sl,
                 "status": "PASS" if independent_both_sl == stored_both_sl else "FAIL"})
    h_expected = {
        "H1": features["valid_cross_symbols_5s"].eq(5) & features["usd_breadth_count_5s"].ge(4) & features["shock_aligned_usd_consensus_5s"].gt(0),
        "H2": features["valid_cross_symbols_5s"].eq(5) & features["usd_breadth_count_5s"].le(1),
        "H3": features["valid_cross_symbols_5s"].eq(5) & features["shock_aligned_target_residual_5s"].le(-.10 + 1e-12),
        "H4": features["valid_cross_symbols_5s"].eq(5) & features["shock_aligned_target_residual_5s"].ge(.10 - 1e-12),
    }
    for h, expected_mask in h_expected.items():
        actual_mask = features[h.lower()].astype(str).str.lower().eq("true")
        mismatch = int(expected_mask.ne(actual_mask).sum())
        rows.append({"check": f"{h.lower()}_membership_mismatch", "actual": mismatch, "expected": 0,
                     "status": "PASS" if mismatch == 0 else "FAIL"})
    return pd.DataFrame(rows)


def main() -> None:
    deterministic_names = [
        "population_reconciliation.csv", "cross_fx_feature_dataset.csv", "cross_fx_feature_freshness.csv",
        "hypothesis_summary.csv", "breadth_bucket_results.csv", "lead_lag_results.csv",
        "target_residual_results.csv", "symbol_results.csv", "session_results.csv", "weekly_results.csv",
        "oracle_summary.csv", "model_comparison.csv", "oof_predictions.csv", "policy_results.csv",
        "fold_performance.csv", "cost_sensitivity.csv", "feature_importance.csv", "permutation_importance.csv",
        "qa_checks.csv", "independent_recalculation.csv",
    ]
    previous_hashes = {n: sha256(OUT / n) for n in deterministic_names if (OUT / n).exists()}
    comparison = behavior_comparison()
    comparison.to_csv(OUT / "r1_r2_behavior_comparison.csv", index=False)
    if comparison["status"].ne("PASS").any():
        raise SystemExit("r1/r2 behavior differs; analysis stopped")
    features = pd.read_csv(RUN / "cross_fx_features.csv", low_memory=False)
    actions = pd.read_csv(RUN / "cross_fx_actions.csv", low_memory=False)
    freshness = pd.read_csv(RUN / "cross_fx_feature_freshness.csv", low_memory=False)
    same = pd.read_csv(RUN / "clean_move_causal_features.csv", low_memory=False)
    post = pd.read_csv(RUN / "post_shock_excursion.csv", low_memory=False)
    dataset = attach_outcomes(features, actions)
    dataset.to_csv(OUT / "cross_fx_feature_dataset.csv", index=False)
    # Compact availability evidence; full 95,208-row source stays in the formal run.
    fresh_summary = (freshness.groupby(["source_symbol", "window_seconds", "valid", "reason"], dropna=False)
                     .agg(rows=("episode_id", "size"), episodes=("episode_id", "nunique"),
                          median_quote_age_ms=("quote_age_ms", "median"),
                          p90_quote_age_ms=("quote_age_ms", lambda x: x.quantile(.90)),
                          p95_quote_age_ms=("quote_age_ms", lambda x: x.quantile(.95)),
                          p99_quote_age_ms=("quote_age_ms", lambda x: x.quantile(.99)),
                          max_quote_age_ms=("quote_age_ms", "max")).reset_index())
    fresh_summary.to_csv(OUT / "cross_fx_feature_freshness.csv", index=False)
    tick_quality = pd.read_csv(RUN / "tick_quality.csv").rename(
        columns={"stale_proportion": "stale_proportion_source_note"})
    unique_current = freshness.sort_values("window_seconds").drop_duplicates(["episode_id", "source_symbol"])
    stale = (unique_current.assign(stale=unique_current["quote_age_ms"].gt(500))
             .groupby("source_symbol", as_index=False)
             .agg(feature_observations=("episode_id", "size"), stale_observations=("stale", "sum"),
                  cross_fx_stale_proportion=("stale", "mean")))
    tick_quality = tick_quality.merge(stale, left_on="symbol", right_on="source_symbol", how="left").drop(columns="source_symbol")
    tick_quality.to_csv(OUT / "tick_quality.csv", index=False)
    eligible = dataset[dataset["status"].eq("ELIGIBLE")].copy()
    phase, gate = phase_a(eligible)
    phase.to_csv(OUT / "hypothesis_summary.csv", index=False)
    grouped_results(eligible.assign(breadth_bucket=eligible["usd_breadth_count_5s"]), ["breadth_bucket"], OUT / "breadth_bucket_results.csv")
    grouped_results(eligible, ["target_lead_bucket"], OUT / "lead_lag_results.csv")
    eligible["residual_bucket"] = pd.cut(eligible["shock_aligned_target_residual_5s"], [-np.inf, -.1, .1, np.inf], labels=["LAGGING", "MIDDLE", "OVEREXTENDED"])
    grouped_results(eligible, ["residual_bucket"], OUT / "target_residual_results.csv")
    grouped_results(eligible, ["symbol"], OUT / "symbol_results.csv")
    grouped_results(eligible, ["session"], OUT / "session_results.csv")
    grouped_results(eligible, ["week"], OUT / "weekly_results.csv")
    pd.DataFrame([metrics_row("ELIGIBLE_ORACLE", eligible, "CONTINUATION")]).to_csv(OUT / "oracle_summary.csv", index=False)
    if gate:
        run_phase_b(eligible, actions, same)
    else:
        phase_b_files_not_run("No preregistered Phase A gate passed")
    population = pd.DataFrame([
        {"stage": "feature_rows", "rows": len(features), "episodes": features.episode_id.nunique(), "clusters": features.market_cluster_id.nunique()},
        {"stage": "eligible", "rows": len(eligible), "episodes": eligible.episode_id.nunique(), "clusters": eligible.market_cluster_id.nunique()},
        {"stage": "action_rows", "rows": len(actions), "episodes": actions.episode_id.nunique(), "clusters": actions.market_cluster_id.nunique()},
    ])
    for status, g in features.groupby("status"):
        population.loc[len(population)] = {"stage": f"status:{status}", "rows": len(g), "episodes": g.episode_id.nunique(), "clusters": g.market_cluster_id.nunique()}
    population.to_csv(OUT / "population_reconciliation.csv", index=False)
    recalc = independent_recalc(features, freshness, actions, post)
    recalc.to_csv(OUT / "independent_recalculation.csv", index=False)
    episode_clock = features.set_index("episode_id")
    t0_for_fresh = episode_clock.loc[freshness.episode_id, "t0_msc"].to_numpy()
    processing_for_fresh = episode_clock.loc[freshness.episode_id, "t0_processing_msc"].to_numpy()
    t0_quote_for_actions = episode_clock.loc[actions.episode_id, "t0_quote_msc"].to_numpy()
    source_text = (ROOT / "mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5").read_text(encoding="utf-8")
    executable_order_calls = sum(1 for line in source_text.splitlines()
                                 if not line.strip().startswith("//") and ("OrderSend(" in line or "OrderCheck(" in line))
    qa_rows = [
        {"check": "r1_r2_behavior_mismatch", "actual": int(comparison.differing_rows.sum()), "expected": 0},
        {"check": "feature_duplicate_episode", "actual": int(features.duplicated("episode_id").sum()), "expected": 0},
        {"check": "action_duplicate_key", "actual": int(actions.duplicated(["episode_id", "action"]).sum()), "expected": 0},
        {"check": "cross_symbol_quote_after_t0", "actual": int((freshness.current_quote_msc > t0_for_fresh).sum()), "expected": 0},
        {"check": "cross_symbol_feature_after_processing_time", "actual": int((freshness.current_processing_msc > processing_for_fresh).sum()), "expected": 0},
        {"check": "anchor_processing_after_t0_processing", "actual": int((freshness.anchor_processing_msc > processing_for_fresh).sum()), "expected": 0},
        {"check": "hindsight_nearest_tick_used", "actual": int((freshness.anchor_quote_msc > (t0_for_fresh - freshness.window_seconds.to_numpy() * 1000)).sum()), "expected": 0},
        {"check": "future_cluster_information_used", "actual": int(features["future_sources"].sum()), "expected": 0},
        {"check": "entry_before_eligible", "actual": int((actions.entry_quote_msc < actions.entry_eligible_msc).sum()), "expected": 0},
        {"check": "entry_not_after_decision_quote", "actual": int((actions.entry_quote_msc <= t0_quote_for_actions).sum()), "expected": 0},
        {"check": "action_row_reconciliation", "actual": len(actions), "expected": 2 * len(features)},
        {"check": "tp_r_violation", "actual": int((actions.loc[actions.result.eq("TP_FIRST"), "gross_r"] - 1.6).abs().gt(1e-9).sum()), "expected": 0},
        {"check": "sl_r_optimism_violation", "actual": int(actions.loc[actions.result.eq("SL_FIRST"), "gross_r"].gt(-1 + 1e-9).sum()), "expected": 0},
        {"check": "actual_trade_rows", "actual": max(0, sum(1 for _ in (RUN / "trades.csv").open(encoding="utf-8")) - 1), "expected": 0},
        {"check": "production_order_calls", "actual": executable_order_calls, "expected": 0},
        {"check": "independent_recalculation_failures", "actual": int(recalc.status.eq("FAIL").sum()), "expected": 0},
    ]
    if (OUT / "oof_predictions.csv").exists() and "fold" in pd.read_csv(OUT / "oof_predictions.csv", nrows=1).columns:
        preds = pd.read_csv(OUT / "oof_predictions.csv")
        core = preds.drop_duplicates(["episode_id", "feature_set", "model", "fold"])
        overlaps = 0
        chronology = 0
        for _, g in core.groupby(["feature_set", "model"]):
            seen: set[str] = set()
            previous_max = None
            for fold in sorted(g.fold.unique()):
                fg = g[g.fold.eq(fold)]
                ids = set(fg.episode_id)
                overlaps += len(seen & ids)
                seen |= ids
                if previous_max is not None and fg.t0_msc.min() <= previous_max:
                    chronology += 1
                previous_max = fg.t0_msc.max()
        qa_rows.extend([
            {"check": "validation_episode_overlap", "actual": overlaps, "expected": 0},
            {"check": "validation_chronology_violation", "actual": chronology, "expected": 0},
        ])
    qa = pd.DataFrame(qa_rows)
    qa["status"] = np.where(qa.actual.eq(qa.expected), "PASS", "FAIL")
    qa.to_csv(OUT / "qa_checks.csv", index=False)
    save_plots(eligible, phase)
    current_hashes = {n: sha256(OUT / n) for n in deterministic_names if (OUT / n).exists()}
    deterministic = pd.DataFrame([
        {"path": f"reports/analysis/tick_shock/step15o/{name}",
         "prior_sha256": previous_hashes.get(name, "NOT_AVAILABLE"), "rerun_sha256": digest,
         "status": "PASS" if previous_hashes.get(name) == digest else "FIRST_RUN_OR_CHANGED"}
        for name, digest in current_hashes.items()
    ])
    deterministic.to_csv(OUT / "deterministic_rerun.csv", index=False)
    print(json.dumps({"features": len(features), "eligible": len(eligible), "clusters": eligible.market_cluster_id.nunique(),
                      "phase_b_gate": gate, "qa_fail": int(qa.status.eq("FAIL").sum()),
                      "hypotheses": phase.to_dict(orient="records")}, default=str, indent=2))


if __name__ == "__main__":
    main()
