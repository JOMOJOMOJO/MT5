#!/usr/bin/env python3
"""Independent Step 15G development analysis.

March 2025 is development-only.  The script consumes the online first-touch
record; it never reconstructs barriers from future checkpoints.  Every model
transform and policy threshold is fitted inside its chronological training
fold.  Formal net expectancy remains unavailable while six-symbol commission
evidence is incomplete.
"""
from __future__ import annotations

import hashlib
import json
import math
from collections import Counter
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, brier_score_loss, precision_score, recall_score, roc_auc_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parents[2]
RUN = ROOT / "reports/backtest/runs/20260901_ts15g_economic_path_r3_202503"
STEP15F = ROOT / "reports/analysis/tick_shock/step15f"
OUT = ROOT / "reports/analysis/tick_shock/step15g"
SHARE = ROOT / "reports/share/tick_shock/step15g"
REF = ROOT / "reports/refactor/tick_shock"
SEED = 20260901
PRIMARY_RR = 1.2
PURGE_MS = 900_000
STEP15F_RUN = ROOT / "reports/backtest/runs/20260831_ts15f_tail_v1_persistent_context_r3_202503"


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest().upper()


def write(df: pd.DataFrame, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(path, index=False)


def behavior_comparison() -> None:
    specs = {
        "detector_identity": ("detector_features.csv", ["symbol", "direction", "candidate_time_msc", "confirmed_time_msc", "trigger_horizon_ms", "market_cluster_id"]),
        "episode_identity": ("medium_horizon_episode_summary.csv", ["symbol", "shock_direction", "anchor_msc", "market_cluster_id", "episode_status", "validation_status"]),
        "context_features": ("episode_context_features.csv", ["symbol", "shock_direction", "decision_seconds", "target_msc", "quote_msc", "status", "reason"]),
        "control_features": ("matched_control_features.csv", ["symbol", "anchor_msc", "pseudo_direction", "decision_seconds", "target_msc", "status", "reason"]),
    }
    rows = []
    for component, (name, columns) in specs.items():
        old, new = pd.read_csv(STEP15F_RUN / name, low_memory=False), pd.read_csv(RUN / name, low_memory=False)
        a = Counter(tuple("" if pd.isna(v) else str(v) for v in x) for x in old[columns].to_numpy())
        b = Counter(tuple("" if pd.isna(v) else str(v) for v in x) for x in new[columns].to_numpy())
        missing, extra = sum((a - b).values()), sum((b - a).values())
        rows.append(dict(component=component, step15f_rows=len(old), step15g_rows=len(new), missing=missing, extra=extra, mismatches=missing + extra, status="PASS" if a == b else "FAIL"))
    write(pd.DataFrame(rows), REF / "step15g_behavior_comparison.csv")

    def parse_set(path: Path) -> dict[str, str]:
        result = {}
        for line in path.read_text(encoding="utf-8-sig").splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                result[k] = v
        return result
    old = parse_set(STEP15F_RUN / "persistent_context_features.set")
    new = parse_set(RUN / "economic_path.set")
    ignored = {"InpRunId", "InpLogFolder", "InpSourceCommit", "InpEx5Hash", "InpSchemaVersion"}
    diff = [dict(parameter=k, step15f=old.get(k, ""), step15g=new.get(k, ""), status="FAIL") for k in sorted(set(old) | set(new)) if k not in ignored and old.get(k) != new.get(k)]
    write(pd.DataFrame(diff, columns=["parameter", "step15f", "step15g", "status"]), REF / "step15g_parameter_diff.csv")


def feature_map() -> tuple[list[str], dict[str, str]]:
    reg = pd.read_csv(STEP15F / "feature_registry.csv")
    ids = reg.feature_id.str.lower().tolist()
    return ids, dict(zip(reg.name, ids))


def class_name(c: str, r: str) -> str:
    if c == "INVALID_PATH" or r == "INVALID_PATH":
        return "INVALID"
    if c == "AMBIGUOUS_SAME_TICK" or r == "AMBIGUOUS_SAME_TICK":
        return "AMBIGUOUS"
    ct, rt = c == "TP_FIRST", r == "TP_FIRST"
    return "BOTH" if ct and rt else "CONT_ONLY" if ct else "REV_ONLY" if rt else "NEITHER"


def load_labels() -> tuple[pd.DataFrame, list[str]]:
    features, rename = feature_map()
    raw = pd.read_csv(RUN / "economic_first_touch.csv", low_memory=False)
    raw = raw[np.isclose(raw.requested_rr, PRIMARY_RR)].copy()
    keys = ["subject_id", "subject_type", "market_cluster_id", "symbol", "shock_direction", "decision_seconds", "horizon_seconds"]
    value_cols = ["result", "first_touch_msc", "gross_r", "stressed_r", "mfe", "mae", "time_to_mfe_ms", "time_to_mae_ms", "invalid_reason", "entry_quote_msc", "entry_processing_msc", "risk_distance", "break_even_additional_cost_r"]
    parts = []
    for action in ("CONTINUATION", "REVERSAL"):
        q = raw[raw.action.eq(action)][keys + value_cols].copy()
        q = q.rename(columns={c: f"{action.lower()}_{c}" for c in value_cols})
        parts.append(q)
    labels = parts[0].merge(parts[1], on=keys, how="outer", validate="one_to_one")
    labels["episode_class"] = [class_name(str(c), str(r)) for c, r in zip(labels.continuation_result, labels.reversal_result)]
    labels["y_cont"] = labels.continuation_result.eq("TP_FIRST").astype(int)
    labels["y_rev"] = labels.reversal_result.eq("TP_FIRST").astype(int)
    labels["anchor_msc"] = labels.subject_id.map(raw.drop_duplicates("subject_id").set_index("subject_id").anchor_msc)
    labels["server_day"] = pd.to_datetime(labels.anchor_msc, unit="ms", utc=True).dt.strftime("%Y-%m-%d")

    shock = pd.read_csv(RUN / "episode_context_features.csv", low_memory=False).rename(columns=rename)
    shock = shock.rename(columns={"episode_id": "subject_id", "status": "feature_status", "reason": "feature_reason"})
    shock_cols = ["subject_id", "decision_seconds", "feature_status", "feature_reason"] + features
    control = pd.read_csv(RUN / "matched_control_features.csv", low_memory=False)
    control = control.rename(columns={"control_id": "subject_id", "status": "feature_status", "reason": "feature_reason"})
    control_cols = ["subject_id", "decision_seconds", "feature_status", "feature_reason"] + features
    feat = pd.concat([shock[shock_cols], control[control_cols]], ignore_index=True)
    labels = labels.merge(feat, on=["subject_id", "decision_seconds"], how="left", validate="many_to_one")
    ep = pd.read_csv(RUN / "medium_horizon_episode_summary.csv", low_memory=False)
    ep = ep.rename(columns={"episode_id": "subject_id"})
    labels = labels.merge(ep[["subject_id", "episode_status", "validation_status"]], on="subject_id", how="left")
    valid_results = {"TP_FIRST", "SL_FIRST", "TIMEOUT"}
    labels["path_valid"] = labels.continuation_result.isin(valid_results) & labels.reversal_result.isin(valid_results)
    labels["primary_population"] = (
        labels.subject_type.eq("SHOCK") & labels.symbol.ne("GBPUSD") & labels.feature_status.eq("AVAILABLE") &
        labels.path_valid & labels.episode_status.eq("COMPLETE_900S") & labels.validation_status.eq("VALID")
    )
    labels["control_population"] = labels.subject_type.eq("MATCHED_CONTROL") & labels.symbol.ne("GBPUSD") & labels.feature_status.eq("AVAILABLE") & labels.path_valid
    labels = labels.replace([np.inf, -np.inf], np.nan)
    return labels, features


def assign_folds(labels: pd.DataFrame) -> pd.DataFrame:
    base = labels[labels.primary_population][["market_cluster_id", "anchor_msc"]].drop_duplicates("market_cluster_id").sort_values("anchor_msc")
    chunks = np.array_split(base.market_cluster_id.to_numpy(), 6)
    rows = []
    for fold in range(5):
        tests = set(chunks[fold + 1].tolist())
        start = int(base[base.market_cluster_id.isin(tests)].anchor_msc.min())
        rows.append((fold, tests, start - PURGE_MS))
    out = []
    for row in labels.itertuples(index=False):
        fold_value = -1
        for fold, tests, _ in rows:
            if row.market_cluster_id in tests:
                fold_value = fold
                break
        out.append(fold_value)
    labels["fold"] = out
    labels.attrs["fold_specs"] = rows
    return labels


def safe_auc(y: np.ndarray, p: np.ndarray) -> tuple[float, float]:
    if len(np.unique(y)) < 2:
        return math.nan, math.nan
    return roc_auc_score(y, p), average_precision_score(y, p)


def choose_threshold(p: np.ndarray, r: np.ndarray) -> float:
    best = (0.0, 0.5)
    for threshold in np.linspace(0.10, 0.90, 33):
        chosen = p >= threshold
        if chosen.sum() < 50:
            continue
        score = float(np.nanmean(r[chosen]))
        if score > best[0]:
            best = (score, float(threshold))
    return best[1]


def model_oof(labels: pd.DataFrame, features: list[str]) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    data = labels[labels.primary_population].copy()
    fold_specs = labels.attrs["fold_specs"]
    pred_rows, metric_rows, importance_rows = [], [], []
    for action, target, rcol in (("CONTINUATION", "y_cont", "continuation_stressed_r"), ("REVERSAL", "y_rev", "reversal_stressed_r")):
        for model_name in ("ELASTIC_NET_LOGIT", "SHALLOW_GB"):
            for fold, tests, cutoff in fold_specs:
                train = data[data.anchor_msc.lt(cutoff)]
                test = data[data.market_cluster_id.isin(tests)]
                if len(train) < 200 or len(test) == 0 or train[target].nunique() < 2:
                    continue
                if model_name == "ELASTIC_NET_LOGIT":
                    model = Pipeline([("impute", SimpleImputer(strategy="median")), ("scale", StandardScaler()), ("model", LogisticRegression(penalty="elasticnet", solver="saga", l1_ratio=.5, C=.2, class_weight="balanced", max_iter=3000, random_state=SEED))])
                else:
                    model = Pipeline([("impute", SimpleImputer(strategy="median")), ("model", GradientBoostingClassifier(n_estimators=80, learning_rate=.04, max_depth=2, min_samples_leaf=30, random_state=SEED))])
                model.fit(train[features], train[target])
                train_p = model.predict_proba(train[features])[:, 1]
                threshold = choose_threshold(train_p, train[rcol].to_numpy())
                p = model.predict_proba(test[features])[:, 1]
                selected = p >= threshold
                roc, pr = safe_auc(test[target].to_numpy(), p)
                metric_rows.append(dict(action=action, model=model_name, fold=fold, train_rows=len(train), test_rows=len(test), positives=int(test[target].sum()), base_rate=float(test[target].mean()), roc_auc=roc, pr_auc=pr, brier=brier_score_loss(test[target], p), threshold=threshold, selected=int(selected.sum()), selected_coverage=float(selected.mean()), precision=precision_score(test[target], selected, zero_division=0), recall=recall_score(test[target], selected, zero_division=0), selected_stress_expectancy=float(test.loc[selected, rcol].mean()) if selected.any() else math.nan))
                for i, (_, row) in enumerate(test.iterrows()):
                    pred_rows.append(dict(subject_id=row.subject_id, market_cluster_id=row.market_cluster_id, symbol=row.symbol, server_day=row.server_day, decision_seconds=row.decision_seconds, horizon_seconds=row.horizon_seconds, fold=fold, action=action, model=model_name, probability=p[i], threshold=threshold, selected=bool(selected[i]), label=int(row[target]), result=row[f"{action.lower()}_result"], spread_only_r=row[f"{action.lower()}_gross_r"], stressed_r=row[rcol]))
                fitted = model.named_steps["model"]
                values = fitted.coef_[0] if model_name == "ELASTIC_NET_LOGIT" else fitted.feature_importances_
                for name, value in zip(features, values):
                    importance_rows.append(dict(action=action, model=model_name, fold=fold, feature=name, importance=float(value), sign=int(np.sign(value))))
    return pd.DataFrame(pred_rows), pd.DataFrame(metric_rows), pd.DataFrame(importance_rows)


def bootstrap_ci(frame: pd.DataFrame, value: str, seed: int) -> tuple[float, float]:
    good = frame[["server_day", value]].dropna()
    days = good.server_day.unique()
    if len(days) < 2:
        return math.nan, math.nan
    groups = {d: good.loc[good.server_day.eq(d), value].to_numpy() for d in days}
    rng = np.random.default_rng(seed)
    means = []
    for _ in range(1000):
        sample = rng.choice(days, len(days), replace=True)
        means.append(float(np.concatenate([groups[x] for x in sample]).mean()))
    return tuple(np.quantile(means, [.025, .975]))


def policy_results(oof: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for (action, model), g in oof.groupby(["action", "model"]):
        x = g[g.selected]
        lo, hi = bootstrap_ci(x, "stressed_r", SEED + len(rows)) if len(x) else (math.nan, math.nan)
        folds = x.groupby("fold").stressed_r.mean() if len(x) else pd.Series(dtype=float)
        day_means = x.groupby("server_day").stressed_r.mean() if len(x) else pd.Series(dtype=float)
        p = stats.ttest_1samp(day_means, 0.0, alternative="greater").pvalue if len(day_means) > 1 else math.nan
        rows.append(dict(action=action, model=model, eligible_rows=len(g), selected_rows=len(x), coverage=len(x)/len(g) if len(g) else 0.0, spread_only_expectancy=float(x.spread_only_r.mean()) if len(x) else math.nan, stress_expectancy=float(x.stressed_r.mean()) if len(x) else math.nan, bootstrap_low=lo, bootstrap_high=hi, positive_folds=int((folds > 0).sum()), total_folds=len(folds), symbols=x.symbol.nunique(), days=x.server_day.nunique(), one_sided_p=p, formal_net_expectancy="UNAVAILABLE", cost_status="COST_MODEL_INCOMPLETE"))
    result = pd.DataFrame(rows).sort_values("one_sided_p", na_position="last").reset_index(drop=True)
    m = len(result)
    result["holm_alpha"] = [0.05 / (m - i) for i in range(m)]
    result["holm_pass"] = result.one_sided_p < result.holm_alpha
    result["candidate_gate"] = False
    result["candidate_reason"] = "FORMAL_COMMISSION_UNAVAILABLE"
    return result


def feature_contrast(labels: pd.DataFrame, features: list[str]) -> pd.DataFrame:
    rows = []
    p = labels[labels.primary_population]
    comparisons = (("CONT_SUCCESS_VS_FAIL", p.y_cont.eq(1), p.y_cont.eq(0)), ("REV_SUCCESS_VS_FAIL", p.y_rev.eq(1), p.y_rev.eq(0)), ("CONT_ONLY_VS_REV_ONLY", p.episode_class.eq("CONT_ONLY"), p.episode_class.eq("REV_ONLY")), ("SUCCESS_VS_NEITHER", p.episode_class.isin(["CONT_ONLY", "REV_ONLY"]), p.episode_class.eq("NEITHER")))
    for name, left, right in comparisons:
        for feature in features:
            a, b = p.loc[left, feature].dropna(), p.loc[right, feature].dropna()
            pooled = math.sqrt((a.var(ddof=1) + b.var(ddof=1)) / 2) if len(a) > 1 and len(b) > 1 else math.nan
            rows.append(dict(comparison=name, feature=feature, left_n=len(a), right_n=len(b), left_mean=a.mean(), right_mean=b.mean(), left_median=a.median(), right_median=b.median(), standardized_difference=(a.mean() - b.mean()) / pooled if pooled and pooled > 0 else math.nan, p_value=stats.mannwhitneyu(a, b).pvalue if len(a) and len(b) else math.nan))
    return pd.DataFrame(rows)


def descriptive_outputs(labels: pd.DataFrame, features: list[str], importance: pd.DataFrame) -> None:
    primary = labels[labels.primary_population]
    counts = primary.groupby(["decision_seconds", "horizon_seconds", "episode_class"], dropna=False).size().reset_index(name="rows")
    write(counts, OUT / "class_counts.csv")
    first = []
    for (decision, horizon, action), g in pd.concat([
        primary.assign(action="CONTINUATION", result=primary.continuation_result, hit_msc=primary.continuation_first_touch_msc, gross_r=primary.continuation_gross_r, stress_r=primary.continuation_stressed_r),
        primary.assign(action="REVERSAL", result=primary.reversal_result, hit_msc=primary.reversal_first_touch_msc, gross_r=primary.reversal_gross_r, stress_r=primary.reversal_stressed_r),
    ]).groupby(["decision_seconds", "horizon_seconds", "action"]):
        elapsed = (g.hit_msc - g.anchor_msc) / 1000.0
        first.append(dict(decision_seconds=decision, horizon_seconds=horizon, action=action, rows=len(g), tp=int(g.result.eq("TP_FIRST").sum()), sl=int(g.result.eq("SL_FIRST").sum()), timeout=int(g.result.eq("TIMEOUT").sum()), tp_rate=float(g.result.eq("TP_FIRST").mean()), median_touch_seconds=elapsed.median(), spread_only_expectancy=g.gross_r.mean(), stress_expectancy=g.stress_r.mean()))
    write(pd.DataFrame(first), OUT / "first_passage_summary.csv")
    write(feature_contrast(labels, features), OUT / "feature_comparison.csv")
    stable = importance.groupby(["action", "model", "feature"]).agg(mean_importance=("importance", "mean"), sd_importance=("importance", "std"), folds=("fold", "nunique"), positive_sign_folds=("sign", lambda x: int((x > 0).sum())), negative_sign_folds=("sign", lambda x: int((x < 0).sum()))).reset_index()
    write(stable, OUT / "importance_stability.csv")
    stability = []
    for action in ("CONTINUATION", "REVERSAL"):
        rcol = f"{action.lower()}_stressed_r"
        for symbol, g in primary.groupby("symbol"):
            stability.append(dict(test="SYMBOL", omitted=symbol, action=action, remaining_rows=len(primary) - len(g), remaining_expectancy=primary.loc[primary.symbol.ne(symbol), rcol].mean()))
        for day, g in primary.groupby("server_day"):
            stability.append(dict(test="DAY", omitted=day, action=action, remaining_rows=len(primary) - len(g), remaining_expectancy=primary.loc[primary.server_day.ne(day), rcol].mean()))
    write(pd.DataFrame(stability), OUT / "stability_results.csv")
    control = labels[labels.control_population]
    matched = []
    for source, g in (("SHOCK", primary), ("MATCHED_CONTROL", control)):
        for action in ("continuation", "reversal"):
            matched.append(dict(population=source, action=action.upper(), rows=len(g), tp=int(g[f"y_{'cont' if action=='continuation' else 'rev'}"].sum()), tp_rate=g[f"y_{'cont' if action=='continuation' else 'rev'}"].mean(), spread_only_expectancy=g[f"{action}_gross_r"].mean(), stress_expectancy=g[f"{action}_stressed_r"].mean()))
    write(pd.DataFrame(matched), OUT / "matched_control_results.csv")


def qa(labels: pd.DataFrame) -> pd.DataFrame:
    raw = pd.read_csv(RUN / "economic_first_touch.csv", low_memory=False)
    key = ["subject_id", "subject_type", "decision_seconds", "action", "requested_rr", "horizon_seconds"]
    entered = raw.entry_quote_msc.notna()
    checks = [
        ("duplicate_path_rows", int(raw.duplicated(key).sum()), 0),
        ("entry_not_strictly_after_signal", int((entered & raw.entry_quote_msc.le(raw.signal_quote_msc)).sum()), 0),
        ("entry_before_processing", int((entered & raw.entry_quote_msc.lt(raw.signal_processing_msc)).sum()), 0),
        ("rr_below_requested", int(((raw.realized_rr.notna()) & (raw.realized_rr + 1e-10 < raw.requested_rr)).sum()), 0),
        ("shock_subjects", int(raw.loc[raw.subject_type.eq("SHOCK"), "subject_id"].nunique()), 3151),
        ("orders", max(0, sum(1 for _ in (RUN / "trades.csv").open(encoding="utf-8-sig")) - 1), 0),
        ("feature_hash_count", raw.feature_spec_sha256.nunique(), 1),
        ("label_hash_count", raw.label_spec_sha256.nunique(), 1),
    ]
    return pd.DataFrame([dict(check=k, actual=a, expected=e, status="PASS" if a == e else "FAIL") for k, a, e in checks])


def compact(labels: pd.DataFrame, features: list[str], oof: pd.DataFrame, policy: pd.DataFrame) -> None:
    columns = ["subject_id", "subject_type", "symbol", "market_cluster_id", "shock_direction", "decision_seconds", "horizon_seconds", "anchor_msc", "server_day", "feature_status", "feature_reason", "primary_population", "control_population", "episode_class", "y_cont", "y_rev", "continuation_result", "reversal_result", "continuation_first_touch_msc", "reversal_first_touch_msc", "continuation_gross_r", "reversal_gross_r", "continuation_stressed_r", "reversal_stressed_r", "continuation_mfe", "continuation_mae", "reversal_mfe", "reversal_mae", "fold"] + features
    compact_df = labels[columns].copy()
    write(compact_df, SHARE / "step15g_episode_labels_compact.csv")
    write(compact_df[compact_df.primary_population & compact_df.y_cont.eq(1)], SHARE / "step15g_profitable_continuation_cases.csv")
    write(compact_df[compact_df.primary_population & compact_df.y_rev.eq(1)], SHARE / "step15g_profitable_reversal_cases.csv")
    write(compact_df[compact_df.primary_population & compact_df.episode_class.isin(["BOTH", "NEITHER"])], SHARE / "step15g_both_neither_cases.csv")
    write(pd.read_csv(OUT / "feature_comparison.csv"), SHARE / "step15g_feature_contrast.csv")
    write(pd.read_csv(OUT / "first_passage_summary.csv"), SHARE / "step15g_first_passage_summary.csv")
    write(oof, SHARE / "step15g_oof_predictions.csv")
    write(policy, SHARE / "step15g_policy_results.csv")
    registry = pd.DataFrame([dict(candidate_id="NONE", status="NO_ECONOMIC_PATH_HYPOTHESIS_FROZEN", reason="formal commission unavailable and preregistered promotion gate not satisfied", development_only=True)])
    write(registry, SHARE / "step15g_candidate_registry.csv")
    hashes = []
    for path in sorted(SHARE.glob("*.csv")):
        hashes.append(dict(path=path.relative_to(ROOT).as_posix(), bytes=path.stat().st_size, sha256=sha(path), under_50_mb=path.stat().st_size < 50_000_000))
    write(pd.DataFrame(hashes), SHARE / "step15g_share_hashes.csv")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    SHARE.mkdir(parents=True, exist_ok=True)
    behavior_comparison()
    labels, features = load_labels()
    labels = assign_folds(labels)
    oof, metrics, importance = model_oof(labels, features)
    policy = policy_results(oof)
    descriptive_outputs(labels, features, importance)
    write(metrics, OUT / "model_results.csv")
    write(oof, OUT / "oof_predictions.csv")
    write(policy, OUT / "policy_results.csv")
    write(importance, OUT / "model_feature_importance.csv")
    write(qa(labels), OUT / "final_qa.csv")
    compact(labels, features, oof, policy)
    summary = {
        "run": RUN.name,
        "primary_rows": int(labels.primary_population.sum()),
        "primary_subjects": int(labels.loc[labels.primary_population, "subject_id"].nunique()),
        "primary_market_clusters": int(labels.loc[labels.primary_population, "market_cluster_id"].nunique()),
        "class_counts": labels.loc[labels.primary_population, "episode_class"].value_counts().to_dict(),
        "oof_rows": len(oof),
        "candidates": 0,
        "cost_status": "COST_MODEL_INCOMPLETE",
        "formal_net_expectancy": "UNAVAILABLE",
        "status": "NO_ECONOMIC_PATH_HYPOTHESIS_FROZEN",
    }
    (OUT / "analysis_summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
