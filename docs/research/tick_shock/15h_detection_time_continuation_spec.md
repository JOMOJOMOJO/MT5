# Step 15H frozen detection-time continuation specification

## Clocks and causal order

`candidate_msc <= confirmed_msc <= processed_msc <= t0_msc`. `t0_msc` is the first production-path processing clock at which the persistent confirmation and all snapshot inputs are usable. For delay `d`, `eligible_msc=max(t0_msc+d, processed_msc)` and entry is the first same-symbol real quote strictly after the signal quote and at/after eligibility. `entry_quote_msc <= t0_msc` is forbidden. Horizon is `t0_msc + horizon_seconds*1000`; entry latency never extends it.

Same-millisecond ticks are ordered by production sequence/cursor and the last processed quote at t0 is snapshotted. Appending future ticks must not alter an existing snapshot. Candidate-to-confirmation values and pre-shock windows are separate. No unconfirmed bar, future pivot, final cluster breadth, later MFE/MAE, outcome, or entry-time spread/risk may enter a feature.

## Population

Detector `TAIL_V1_PERSISTENT`, March 2025, six monitored symbols, primary excludes every GBPUSD row and every fallback/stale/warmup/incomplete/end-censored row. The causal representative is the first eligible persistent confirmation in each episode; future severity and final breadth do not choose it. Feature rejection and outcome unavailability are distinct statuses.

## Immediate continuation counterfactual

- Direction: confirmed shock direction only; one decision at t0.
- Long Ask entry/Bid exit; Short Bid entry/Ask exit.
- Risk: `max(0.25*completed M5 ATR14, 4*entry spread, broker StopsLevel distance)` using existing outward rounding.
- RR: 1.2 only. TP is target-limit; SL gaps fill at the first tradable side quote; same-ms ambiguity is conservatively SL-first while secondary status preserves ambiguity.
- Primary horizon 900 s from t0; 300/600 s diagnostics.
- Delay 0 primary; 100/250 ms stress.
- C0 uses actual Bid/Ask. C2 uses 1.25x spread plus one tick at entry and exit exactly once. C2 is not formal net because six-symbol commission/slippage evidence is incomplete.

## Feature registry

The versioned registry is `reports/analysis/tick_shock/step15h/feature_registry.csv`. It freezes ten main effects plus two interactions. Every feature stores value, source timestamp, availability and missing reason. Directional values are normalized to shock direction; price distances are ATR ratios. Metadata and quality flags are not model features.

Feature sets: `LIQUIDITY_ONLY={H01,H02}`, `PRE_CONTEXT={H01..H07}`, `DETECTION_SHAPE={H01,H02,H08,H09,H10}`, `COMBINED={H01..H12}`.

## Labels, models, and selection

Primary label is `C2_R > 0`; continuous C2 R is the utility. TP_FIRST, SL_FIRST, TIMEOUT with signed R, MFE/MAE and hit clocks remain evaluation diagnostics only.

Eight model families are frozen: four feature sets times regularized logistic regression and decision tree depth <=2. Logistic `C={0.1,1,10}`; tree candidates `(depth,min_leaf)={(1,100),(2,100),(2,200)}`. Probability/action thresholds are `{0.35,0.45,0.50,0.55,0.65}`. Inner training selects by policy value with ties resolved by fewer features, higher threshold, then lexical trial ID. No model, feature, hyperparameter or threshold may be added after outcomes are inspected.

Policies on the same eligible set are `NO_TRADE`, `UNFILTERED_CONTINUATION`, `LIQUIDITY_ONLY`, `PRE_CONTEXT`, `DETECTION_SHAPE`, and `COMBINED`. Rejected rows retain counterfactual R but actual policy R is zero. Primary value is `sum(selected*R)/N_eligible`, not selected conditional mean.

## Validation and candidate gate

Five expanding chronological folds, market-cluster grouping, 900,250 ms purge/embargo, fold-local imputation/scaling/model/threshold. Paired day/market-cluster block bootstrap uses 2,000 repetitions and seed 1502; Holm family is the eight model families. Empty or undersupported folds fail support. LOSO and leave-one-day/cluster diagnostics cannot rescue a failed primary.

The strongest permissible status is `DETECTION_TIME_CONTINUATION_FILTER_HYPOTHESIS_FROZEN_FOR_FUTURE_VALIDATION`. It requires the preregistered support, positive primary C2 mean and adjusted lower bound, positive opportunity value, improvement over unfiltered and liquidity-only, five-fold stability, concentration and missingness checks, delay/neighbor-threshold stability, causal/provenance regression, and zero orders. Otherwise report `NO_DETECTION_TIME_CONTINUATION_FILTER_SUPPORTED` and `NO_CONTINUATION_FILTER_HYPOTHESIS_FROZEN` or `INCONCLUSIVE_SAMPLE_SIZE`. Always retain `COST_MODEL_INCOMPLETE`, `FORMAL_NET_EXPECTANCY_UNAVAILABLE`, `EDGE_UNDETERMINED`, `PRODUCTION_NOT_ELIGIBLE`.
