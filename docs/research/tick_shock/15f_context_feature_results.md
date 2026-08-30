# Step 15F causal context feature results

## Scope and formal result

This study uses only March 2025 development data. It does not use a locked OOS
period, choose RR/SL/TP, modify the frozen detector or issue an order.

Formal statuses are:

- `STEP15E_DIRECTION_AND_COVERAGE_AUDIT_PASSED`
- `CAUSAL_CONTEXT_FEATURES_CHARACTERIZED_ON_DEVELOPMENT_DATA`
- `NO_CONTEXT_CONDITIONED_PATTERN_SUPPORTED`
- `NO_CONTEXT_RULE_HYPOTHESIS_FROZEN`
- `CONTEXT_SIGNAL_NOT_SHOCK_SPECIFIC`
- `COST_MODEL_INCOMPLETE`
- `FORMAL_NET_EXPECTANCY_UNAVAILABLE`
- `EDGE_UNDETERMINED`
- `PRODUCTION_NOT_ELIGIBLE`

The accepted run is
`reports/backtest/runs/20260831_ts15f_tail_v1_persistent_context_r3_202503/`.
The earlier r2 run is explicitly rejected because post-run coverage QA found
F01 missing in every row. `TS15F-INTEGRITY-006` reproduced that production-path
defect before the validity-evaluation fix; the r3 source commit is
`26faf274b87b882745a9a62bfb521fea08d9bf7f`.

## Regression and population

Step 15E event, episode, path, strategy-funnel, response and market-cluster
identities all match with zero differences. Strategy/execution parameter
differences are zero, and the production order count is zero.

The population is 3,151 episodes minus 417 unmappable GBPUSD fallback episodes,
leaving 2,734 primary episodes. Decision/exit availability is causal:

| decision | exit | valid entry | valid exit | complete 36-feature rows |
|---:|---:|---:|---:|---:|
| 60s | 300s | 1,279 | 677 | 1,277 |
| 60s | 600s | 1,279 | 675 | 1,277 |
| 60s | 900s | 1,279 | 658 | 1,277 |
| 120s | 300s | 1,244 | 682 | 1,243 |
| 120s | 600s | 1,244 | 662 | 1,243 |
| 120s | 900s | 1,244 | 659 | 1,243 |

Every total reconciles. Remaining losses are stale/invalid decision or exit
quotes, not unexplained deletion. F07/F09 are available for 2,521 primary
decision rows and F36 for 2,522; all other retained features are available for
2,523 rows. Training-fold median imputation and missing indicators are fitted
inside each fold only.

## Unconditional executable response

Both actions have negative day-block confidence intervals at every registered
checkpoint/horizon. Representative spread-multiple means are:

| decision | exit | continuation | reversal |
|---:|---:|---:|---:|
| 60s | 300s | -0.978 | -1.018 |
| 60s | 600s | -1.015 | -0.979 |
| 60s | 900s | -1.089 | -0.908 |
| 120s | 300s | -1.059 | -0.934 |
| 120s | 600s | -0.722 | -1.270 |
| 120s | 900s | -0.844 | -1.149 |

Actual Bid/Ask is used independently for continuation and reversal. The 1.25x
spread stress worsens every unconditional action mean. `NO_TRADE` is exactly
zero.

## Walk-forward models

Five expanding chronological outer folds preserve whole episodes and market
clusters. Each fold applies a 15-minute purge and embargo. Median imputation,
missing indicators, scaling, quintile boundaries and finite hyperparameter
selection are training-only. The deterministic seed is 20260831.

The strongest development result is the context-only shallow gradient
boosting model at the +60s decision and 600s exit:

- OOF rows: 528
- chosen-action coverage: 4.55%
- mean: +0.062832 spread multiples
- 1.25x spread mean: +0.051843
- day-block 95% CI: [-0.024420, +0.154630]
- raw one-sided p: 0.094868
- Holm-adjusted p: 1.0
- fold means: -0.0915, +0.2024, +0.0665, +0.1841, 0.0000

It therefore fails the positive lower confidence bound, adjusted significance
and 5/5 same-sign requirements. The corresponding context-plus-shock model is
weaker: +0.025157, versus +0.062832 context-only. At +120s/600s the
context-plus-shock model improves its context-only point estimate, but its
95% lower bound is still negative and Holm p remains 1.0. Logistic OOF AUCs
range only around 0.51-0.62 and are not treated as economic evidence.

Leave-one-symbol-out for the strongest point estimate stays positive, and all
18 leave-one-day-out point estimates are positive. This does not override the
negative outer fold, negative confidence lower bound, multiplicity failure or
very low action coverage.

## Matched controls and shock specificity

The engine recorded 6,254 deterministic 15-minute control anchors (12,508
decision rows). After shock purge, stale/end-of-data exclusion and one-to-one
matching, 481 +60s and 390 +120s unique controls are used. Shock-minus-control
mean differences for continuation range from +0.0077 to +0.3383 spread
multiples, but every day-block 95% CI crosses zero. Reversal differences are
negative and likewise inconclusive.

The strongest model is context-only and adding shock structure does not
provide stable incremental value. The appropriate diagnostic is therefore
`CONTEXT_SIGNAL_NOT_SHOCK_SPECIFIC`, not evidence that the detector creates a
tradable conditional edge.

## Model interpretation and limitations

Coefficient, permutation-importance and fold-stability tables are saved. Some
features (notably trailing return and short realized volatility) rank highly in
individual model/fold combinations, but importance magnitude and sign are not
stable enough to define a simple rule. Univariate buckets and twelve
predeclared interactions do not satisfy the full candidate gate.

The tester reports generated-tick fallback for 179 of 30,187 GBPUSD minutes;
all 417 GBPUSD episodes remain excluded from primary inference. Server time is
not converted to UTC because a verified DST mapping is unavailable.
Commission and additional slippage are not established for all six symbols,
so positive spread-only point estimates are not formal net expectancy.

Step 15F stops here. No selection validation, locked OOS, long OOS, RR
optimization, production EA conversion or live order work is authorized.

