# Technical ML Discovery: analysis-only preregistration

Registered 2026-09-11 before new model fitting. This is another development
experiment on already studied data, not a new untouched OOS claim. No EA,
detector, source feature producer or existing evidence is changed.

## Frozen data and execution

- January–April: `reports/backtest/batches/tstech_real_202501_202506_20260910/`.
  11,230 episodes, 486 causal predictor columns. Verify collection SHA/QA first.
- Expanding outer folds: January -> February; January–February -> March;
  January–March -> April. No random splitting. Purge training episodes whose
  complete 930-second observation/entry+900-second label horizon reaches the
  boundary. Keep monthly-prefixed market clusters intact.
- May–June outcomes are not loaded unless the development gate below passes.
  They are a secondary previously observed holdout, never a pristine OOS.
- Freeze detector, same target-symbol real Bid/Ask labels, processing-time entry,
  one globally pending/open position, same-score ties NO TRADE, no alternate
  direction after discovering an invalid outcome. Include entry rejections in
  portfolio simulation. No retrospective top-N from the validation month.
- RR1 distances: 0.5, 0.75, 1.0, 1.5, 2.0 completed M5 ATR14; existing tick-rounded
  barriers, minimum 3 entry spreads, 900 seconds from entry. No new fine grid.
- Primary net R = recorded Bid/Ask gross R minus **0.2 pip round-trip additional
  cost** divided by risk pips. It is a stress assumption, not measured commission.
  Also report 0/0.1/0.2/0.5/1.0 pip; never subtract spread a second time.
- Preserve known January/April legacy-pool warning and February/March generated
  fallback evidence. Technical observer acceptance does not certify global runs.

## Bounded model experiment

Six families, three targets, two feature variants, five distances, three folds:
540 fold configurations, each with independent LONG/SHORT estimators.

- Families: Logistic (L2), ElasticNet Logistic, Random Forest, Extra Trees,
  shallow Decision Tree, LightGBM. For continuous net-R targets the first two
  use Ridge and ElasticNet **regressions**, not a mislabeled logistic regressor.
- Targets: `WIN` = net R > 0; `TP_FIRST` = status TP; `NET_R` = actual net R.
  Classifier probability is converted to expected R using positive/negative
  class mean net payoffs from training only, including TIME outcomes. Keep raw
  probability metrics separate from this deliberately simple payoff model.
- Features: `FULL486`; `SCALE_FREE` excludes absolute quote/indicator prices,
  ATR in price units and raw tick volume (38 exact columns,448 retained). Relative
  and existing causal interaction features remain. This reduces direct scale
  identification, but is NOT proof that symbol identity cannot be inferred.
  Log-return realized volatility is dimensionless and retained.
- No new features: existing486 already cover requested technical families and
  interactions. Further feature multiplication would enlarge search needlessly.
- Fixed capacity: tree depth4/minleaf60; forests96 trees/depth6/minleaf40 and
  sqrt feature subsampling; LightGBM80 trees/depth3/8leaves/minchild60/lr0.04,
  L1=1,L2=2; logistic C0.1, ElasticNet l1_ratio0.5; Ridge alpha10; ElasticNet
  alpha0.02,l1_ratio0.5. Standardization/imputation use training only.
- Seed20260911; estimator threads1; no hyperparameter search. Optional XGBoost
  is unavailable in current runtime and will not be installed. No neural net.

## Frequency calibration (independent pre-fit review amendment)

For each outer training prefix, use its first75% of **calendar duration** for
model fitting and final25% for chronological calibration. Purge fit labels at
the calibration boundary and remove any shared clusters. The outer prefix is
therefore fitting+calibration, not all rows used for parameter fitting. Freeze
the SAME model after calibration: no final refit that changes score scale.

For every fitted model pair use fixed EV cutoffs 0/0.05/0.1R; and targets
100/200/300/500/800 trades per calendar month via three past-only methods:

1. `PERCENTILE`: the training score quantile implied by target * training months
   / fitting episode count. Does not account for overlap; report resulting
   actual trades rather than pretending it guarantees the target.
2. `FREQUENCY`: choose among a fixed33-quantile training-score grid plus an
   all-signals cutoff the cutoff whose training **portfolio count**, divided by
   fitting months, is closest to target. No training profit is used to choose
   this cutoff. Apply unchanged to next month. At ties choose higher cutoff.

3. `TAIL_FREQUENCY`: same count-only grid rule on the held-back chronological
   calibration tail. Counts become monthly rates using each past period's
   weekdays/21.75. This is the honest calibration comparator.

The first two calibrations use predictions on fitting data: causal, but potentially
optimistic for nonlinear fitted models. Report train/evaluation score quantiles,
calibration count error, ties, saturation and observed count drift explicitly.
They do not use completed evaluation-month ranks. Frequency is a feasibility
constraint, not permission to force trades or assert positive EV below zero.

## Candidate gate and interpretation

- Require >=200 closed trades in **each** February/March/April, positive EV in
  each and pooled PF>1, positive pooled total after removing five best trades,
  positive pooled total excluding each individual symbol and calendar week,
  no symbol >60% or week >35% of positive grouped profits, and at least one
  neighboring threshold/target in the same method with >=200/month and positive
  EV in all three months. Estimator nonconvergence excludes adoption.
- Rank passing candidates by worst monthly EV then total R and stable ID.
  At most one frozen candidate goes to May/June; no holdout-driven reselection.
  If none passes, do NOT manufacture an EA or open May/June for rescue. Diagnose
  frequency-qualified candidates without calling them positive-edge candidates.
- All tested cells are disclosed. Model-family best results are selected on
  these same development folds and therefore have selection bias.
- Interpret fixed diagnostic best-frequency candidate: native importance,
  validation permutation (including grouped correlation caveats), training-bin
  validation outcomes, partial dependence, interaction ablation and native
  LightGBM TreeSHAP. Importance is not causality or evidence of profitable edge.
- Report symbol/side/session/month/week, cost, TP/SL/TIME, distance/spread,
  MFE/MAE/time-to-touch, one-R closed-trade DD; episode/cluster/day counts.
- Independent trade accounting/causality tests, deterministic rerun spot checks,
  input/source hashes, commands/environment and failure ledger are required.

## References

Expanding chronological evaluation: https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.TimeSeriesSplit.html

Permutation caveats: https://scikit-learn.org/stable/modules/permutation_importance.html

Native feature contributions: https://lightgbm.readthedocs.io/en/stable/Parameters.html
