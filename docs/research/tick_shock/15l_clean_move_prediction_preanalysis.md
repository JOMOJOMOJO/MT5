# Step 15L pre-analysis: clean-move prediction

## Scope and target

This is a March 2025 development-only signal-feasibility study. It does not change the production entry logic, detector thresholds, four strategy definitions, RR, stop grid, global watermark, commission, or order behavior.

The primary target is fixed before model fitting:

- `IS_CLEAN_MOVE = 1` when either continuation or reversal first reaches 0.40 ATR within 900 seconds while its pre-target MAE is at most 0.25 ATR;
- otherwise `IS_CLEAN_MOVE = 0`;
- only Step 15K `analysis_ready=TRUE` episodes are eligible;
- expected development counts are 188 positive and 2,508 negative over 2,696 episodes.

Secondary targets are clean continuation, clean reversal, and continuation versus reversal among clean episodes. A weak secondary result is reported as no directional signal; it is not tuned into a rule.

## Causality and eligibility

Every predictor must be available at or before the causal Step 15K `t0`. Every numeric feature carries a source timestamp or a documented past-only construction. Any `feature_timestamp > t0`, target-derived field, MFE/MAE, hit timestamp, horizon value, or post-t0 quote invalidates the row or feature. Market clusters, not rows, are split units.

GBPUSD remains visible in raw data but excluded from formal model evaluation because its generated-tick fallback interval map is unavailable. Models are evaluated on the same five-symbol formal population as Step 15K.

## Registered feature groups

### A: existing causal features

Severity, persistence/confirmation retention, detection efficiency, direction, session, spread/ATR, past-only spread percentile, tick activity and percentile, completed-M5 ATR and past-only ATR percentile, pre-5m directional return, M5 EMA20 directional slope, M15 alignment, prior-15m directional extension, day-range directional position, and the two registered causal interactions. Symbol is included only in the explicitly labelled `with_symbol` variant.

### B: price and momentum lags

Direction-aligned mid-price returns over 5, 10, 30, 60, 120, 300, and 900 seconds, normalized by the completed-M5 ATR frozen at t0. Acceleration features are 10-second return minus the immediately preceding 30-second return, current 30-second versus prior 30-second return, and short/medium directional consistency.

### C: spread and activity dynamics

Spread/ATR at t0 and at 5, 10, and 30 seconds before t0; changes from those anchors; tick counts in trailing 5, 10, 30, 60, and 120 seconds; recent/prior tick ratios; and past-only same-symbol ranks where sufficient history exists. Zero denominators are unavailable, not zero-valued signal.

### D: pre-shock compression and market structure

Trailing mid ranges over 30, 60, 180, 300, 900, 1,800, and 3,600 seconds normalized by t0 ATR; realized absolute price variation over 30/60/180/300 seconds; shock-to-prior-range ratios; distance to trailing highs/lows; and trailing-range position. All windows end at t0 and exclude later quotes.

### E: full

Groups A through D. No automatically generated polynomial feature expansion is permitted.

## Models and fixed settings

- Logistic regression: median imputation learned on train only, standard scaling, one-hot categoricals, `C=1`, L2, `class_weight=balanced`, `max_iter=2000`.
- Shallow decision tree: median imputation learned on train only, one-hot categoricals, `max_depth=3`, `min_samples_leaf=100`, `class_weight=balanced`.
- LightGBM: binary objective, 200 trees, learning rate 0.03, 15 leaves, max depth 4, min child samples 50, feature fraction 0.8, bagging fraction 0.8, bagging frequency 1, L1=1, L2=1, balanced class weights, one thread, seed 20260903.

No hyperparameter search, SMOTE, random split, AutoML leaderboard selection, or model selection on the final walk-forward fold is permitted. If LightGBM cannot be installed or executed, that model is reported unavailable rather than emulated.

## Validation

Clusters are ordered by their earliest t0. Four expanding walk-forward folds are fixed by cluster-order fractions:

1. train [0%,40%), validate [40%,55%);
2. train [0%,55%), validate [55%,70%);
3. train [0%,70%), validate [70%,85%);
4. train [0%,85%), validate [85%,100%].

Boundary clusters belong wholly to one side. Primary metrics are pooled out-of-fold average precision/PR-AUC, recall, precision, F2, selected episode count, and selected cluster count. ROC-AUC and accuracy are diagnostics only.

Leave-one-symbol-out removes from training every market cluster that also appears in the held-out symbol. `with_symbol` and `without_symbol` variants use otherwise identical features and folds.

## Registered frontiers

Scores are ranked only within out-of-fold predictions. Report top 100, 200, 300, 500, 800, and 1,000 episodes, and the minimum candidate count required for at least 95%, 90%, 80%, 70%, and 60% clean recall. Ties are resolved by score descending, t0 ascending, episode ID ascending. Each point reports clean captured, recall, precision, enrichment over the 6.97% baseline, market clusters, and symbol composition.

The frozen Step 15K hard filter, full-population model score, and hard-filter-plus-model score are compared. The hard filter is not forced into every model.

## Importance, calibration, and distillation

LightGBM gain/split importance, validation-only permutation importance, and LightGBM prediction contributions are descriptive. Calibration uses fixed decile score bins on validation predictions; no calibrator is fitted to and evaluated on the same rows.

EA distillation is feasible only if logistic regression or the shallow tree retains most of the nonlinear model's pooled walk-forward average precision and recall frontier without relying on symbol identity. No model is ported to MQL5 in this step.

## Decision boundary

March is repeatedly used development data. Model feasibility requires PR-AUC above the positive-rate baseline across time folds, material high-recall compression, and evidence outside USDJPY. It cannot establish production edge. `OOS_VALIDATION_REQUIRED` and `PRODUCTION_NOT_ELIGIBLE` remain mandatory. No threshold, symbol policy, direction policy, TP, MAE, or hold setting is frozen from this study.
