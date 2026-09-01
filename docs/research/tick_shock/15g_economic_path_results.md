# Step 15G economically meaningful path results

## Scope and accepted run

This is a March 2025 development study, not selection validation or OOS. The accepted real-tick run is `reports/backtest/runs/20260901_ts15g_economic_path_r3_202503/`, executed from source commit `e9c2968660288c12af03dba770e519c8d012e010` with zero research orders.

r1 and r2 are rejected engineering runs. r1 invalidated causal paths when global-merge processing lag was high and duplicated end-of-data writes. r2 still re-armed completed subjects during cooldown. Both failures have production-path regression tests; neither run contributes labels or model results.

Step 15F detector, episode, context-feature and control-feature identities match exactly: 21,799 detector rows, 3,151 episodes, 6,302 shock feature rows and 12,508 control feature rows, with zero missing or extra identities. Frozen strategy parameter differences are zero.

## Path definition and integrity

At the +60s and +120s causal decision quotes, continuation and reversal are evaluated independently with actual Bid/Ask. Risk is the maximum of 0.25 completed-M5 ATR14, 4.0 entry spread, and broker StopsLevel distance. RR1.2 is primary; RR1.0/1.5/2.0 are diagnostics. The registered horizons are 300/600/900 seconds from the shock anchor.

The online recorder produced 430,224 path rows. It has zero duplicate keys, zero entry at/before the signal quote, zero entry before processing, zero RR violations and zero orders. The run produced 5,030 TP-first, 20,657 SL-first and 67,961 timeout rows; 336,576 paths are explicitly invalid because one or both decision snapshots were unavailable. Tick/grid CSV remains disabled.

GBPUSD has 179 generated-fallback minutes of 30,187 tester minutes. Because an interval map is unavailable, every GBPUSD episode is excluded from primary inference.

## Primary population and classes

The primary RR1.2 population contains 9,990 subject-decision-horizon rows from 2,228 shock episodes and 2,086 market clusters. These rows are not 9,990 independent trades.

| class | rows |
|---|---:|
| CONT_ONLY | 696 |
| REV_ONLY | 615 |
| BOTH | 0 |
| NEITHER | 8,679 |
| AMBIGUOUS | 0 |
| INVALID | excluded from primary |

Continuation TP frequency rises from 3.40% at +60s/300s to 11.16% at +60s/900s; reversal rises from 2.63% to 10.21%. This is not positive expectancy: every registered decision/action/horizon has negative C0 spread-only mean and a more negative C2 stress mean. Across all primary rows, continuation is -0.2527R C0 / -0.3395R C2 and reversal is -0.2598R C0 / -0.3464R C2.

## Feature and model findings

Successful paths are associated with lower F26 spread/ATR, higher F28 tick activity and larger raw ATR features F16-F18. The largest standardized differences are about one standard deviation. These are not frozen trading predicates. Raw ATR is price-unit and symbol dependent, and the associations partly describe the preregistered barrier geometry rather than a portable market state.

Elastic-net logistic and shallow gradient boosting were evaluated with five expanding chronological outer folds. Whole market clusters remain together; the purge and embargo are 900 seconds; imputation, scaling and threshold choice are training-only.

Mean OOF discrimination is materially above random (ROC-AUC approximately 0.78-0.82), but discrimination does not translate to economic value. Every aggregate OOF policy has negative C2 expectancy:

| action | model | selected | coverage | C0 expectancy R | C2 expectancy R | positive folds |
|---|---|---:|---:|---:|---:|---:|
| continuation | elastic net | 858 | 10.43% | -0.1935 | -0.2836 | 0/5 |
| continuation | shallow GB | 54 | 0.66% | +0.0579 | -0.0320 | 1/3 nonempty |
| reversal | elastic net | 1,698 | 20.64% | -0.2488 | -0.3386 | 0/5 |
| reversal | shallow GB | 42 | 0.51% | -0.1370 | -0.2268 | 0/2 nonempty |

The apparently positive continuation C0 point estimate has a C2 mean below zero and a day-block 95% interval spanning approximately -0.71R to +0.44R. All Holm tests fail. No candidate may be inferred from AUC alone.

## Matched controls and costs

The run recorded 5,884 control subjects, but all economic-control paths are invalid because every underlying Step 15F control decision row is excluded (`FEATURE_UNAVAILABLE`, `SHOCK_PURGE`, `STALE_OR_INVALID_QUOTE`, or `END_OF_DATA`). Consequently an economically comparable matched-control path population does not exist. Shock specificity is not established; it is not legitimate to treat the missing controls as zero-return controls.

C0 is available. C2 is a preregistered diagnostic (1.25x spread plus one tick at entry and exit). C1 and formal C2 net values are unavailable because actual six-symbol commission evidence is incomplete. The EURUSD tester observed zero commission, but that does not establish six-symbol live commission.

## Formal conclusion

- `ECONOMIC_PATH_LABELS_CHARACTERIZED_ON_DEVELOPMENT_DATA`
- `NO_ECONOMIC_PATH_HYPOTHESIS_FROZEN`
- `MATCHED_CONTROL_ECONOMIC_PATH_COMPARISON_UNAVAILABLE`
- `COST_MODEL_INCOMPLETE`
- `FORMAL_NET_EXPECTANCY_UNAVAILABLE`
- `EDGE_UNDETERMINED`
- `PRODUCTION_NOT_ELIGIBLE`

No selection validation, unused period, locked OOS, long OOS, parameter optimization, production conversion or live order work is authorized by Step 15G.
