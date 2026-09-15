# Tick-Shock Technical ML Discovery: analysis results

Verdict: `NO_DEVELOPMENT_CANDIDATE_PASSED`. This is analysis only; **no EA was created**. No May/June outcomes were read by this experiment/report. The diagnostic policy below is selected on these same development folds and is not an unbiased OOS result.

## Data and bounded experiment

January--April: 11,230 episodes, 486 full features / 448 scale-reduced features. Outer evaluation: 9,602 February--April episodes. Six families × three targets × two feature variants × five RR1 geometries × three folds = 540 configurations; 3,240 three-month policies. No random split or monthly retrospective top-N.

The first 75% of each outer training prefix fits model parameters; its final 25% is a chronological calibration tail. Complete label horizons and market clusters are purged. The calibrated model is not refitted, preventing post-calibration score-scale changes. PERCENTILE/FREQUENCY use fitted-data scores; TAIL_FREQUENCY uses the held-back past tail. All cutoffs are fixed before each outer month.

Calibration rates approximate exposure using whole server weekdays divided by 21.75; partial-boundary weekdays introduce rounding. The reported calibration maximum is the maximum over sampled 33-quantile thresholds, not a mathematical capacity bound: portfolio counts need not be monotonic in the threshold.

Bid/Ask spread is already in quote-side gross outcomes. Primary net R subtracts an additional **hypothetical 0.2 pip round-trip cost**, not measured commission; spread is not subtracted twice. No live execution is validated.

## Development-selected family comparison

For each family, select the frequency-qualified policy with highest worst monthly EV; if none qualifies, display its diagnostic best and mark it unqualified. This is multiple-comparison-biased development selection, not six fixed OOS strategies.

| family | target | variant | geometry | policy | min_month_trades | trades | worst_month_ev | expectancy_r | positive_months | best_is_frequency_qualified |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ELASTICNET | NET_R | SCALE_FREE | 3 | ABS_0.1 | 252 | 936 | -0.01859 | -0.01136 | 0 | True |
| EXTRA_TREES | NET_R | SCALE_FREE | 5 | PERCENTILE_300 | 218 | 1032 | -0.00471 | -0.00199 | 1 | True |
| LIGHTGBM | NET_R | FULL486 | 4 | PERCENTILE_300 | 205 | 1027 | -0.02594 | -0.01505 | 1 | True |
| LOGISTIC | NET_R | FULL486 | 4 | PERCENTILE_200 | 253 | 1103 | -0.02907 | -0.01527 | 0 | True |
| RANDOM_FOREST | WIN | FULL486 | 5 | TAIL_FREQUENCY_300 | 227 | 1145 | -0.01668 | -0.00992 | 0 | True |
| SHALLOW_TREE | WIN | SCALE_FREE | 4 | TAIL_FREQUENCY_300 | 217 | 936 | -0.04917 | -0.04339 | 0 | True |

## Diagnostic policy and walk-forward accounting

Configuration: `EXTRA_TREES / NET_R / SCALE_FREE / g5 / PERCENTILE_300`. Gate passing candidates: 0; basic gate: 0; frequency-qualified policies: 1996.

| month | threshold | trades | win_rate | expectancy_r | pf | maxdd_r | tp | sl | timeout | timeout_rate |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 202502 | 0.00280 | 218 | 0.49541 | -0.00100 | 0.99592 | 8.23547 | 25 | 25 | 168 | 0.77064 |
| 202503 | -0.00576 | 437 | 0.49428 | -0.00471 | 0.98161 | 11.87806 | 65 | 47 | 325 | 0.74371 |
| 202504 | -0.01076 | 377 | 0.51989 | 0.00059 | 1.00241 | 10.82393 | 32 | 54 | 291 | 0.77188 |

Pooled diagnostic: 1032 trades, net EV -0.001992 R, PF 0.992007, total -2.055905 R, closed-trade max DD 18.817316 R. This is unit-risk accounting, not a money-equity or simultaneous-position claim.

## Required supporting analyses

All paths below are under `reports/analysis/tick_shock/technical_ml_discovery_20260911/`.

- `frequency_expectancy_frontier.csv`: all 100/200/300/500/800 target rates and absolute-threshold cells, actual monthly counts, EV and calibration error. Targets do not guarantee actual frequency.
- `target_comparison.csv`, `prediction_quality.csv`: WIN, TP-first and continuous net-R comparisons; probability quality is separate from realized portfolio profit.
- `raw_scale_exclusion_paired.csv`, `raw_scale_exclusion_summary.csv`: full/scale-free contrasts for the **same** family, target, geometry, month and policy. Remaining normalized features may still identify symbols.
- `geometry_path_normalized.csv`, `path_geometry_diagnostics.csv`, `outcome_funnel.csv`, `geometry_model_comparison.csv`: MFE/MAE, first-touch timing, spread ratios and geometry/state counts. The original excursion columns are price units; the new normalized table divides by frozen ATR. Full-path finite touch times are not TP-first labels; the normalized timing table restricts to the actual TP/SL exit type. Path statistics pool action rows, not independent trades.
- `unconditional_baselines.csv`, `diagnostic_vs_unconditional_baselines.csv`: always LONG, SHORT, continuation and reversal with identical geometry, cost and global portfolio rules. These have different counts; no oracle chooses a profitable direction.
- `diagnostic_symbol.csv`, `diagnostic_side.csv`, `diagnostic_session.csv`, `diagnostic_week.csv`: dependence and removal diagnostics. Session bins use broker server hours: Tokyo [00,09), London [08,17), New York [13,22); multiple sessions = OVERLAP. No unsupported UTC/DST conversion.
- `diagnostic_cost_sensitivity.csv`, `diagnostic_top5_robustness.csv`, `diagnostic_threshold_stability.csv`, `diagnostic_score_distributions.csv`: cost, concentration and threshold stability.
- `diagnostic_bootstrap.csv`: 2,500 resamples each of market-cluster and server-day blocks. These are **not selection-bias-adjusted** confidence intervals and cannot promote a development-selected model to OOS. Days may remain serially dependent.
- `interpretation_*` artifacts are supplied by the separately reviewed interpretation runner. Importance and partial dependence are associations, not causal trading rules.

## Integrity, limitations and next gate

Independent QA: 74 PASS / 0 FAIL. Checks include quote-side price accounting, CSV EV/PF/DD reconciliation, independent pending-position replay, duplicate/clock checks, purged fit/calibration/evaluation boundaries, complete prediction indexes, and before/after input/protected-source hashes. This proves the stated offline accounting checks, not live fill or data-feed completeness.

Retain the inherited January/April legacy-pool warning and February/March generated-tick fallback limitations; accepting technical-observer records does not convert those whole runs into globally valid real-tick evidence. These months have already been explored repeatedly; extensive feature/model/geometry comparisons increase overfitting risk.

Only a preregistered gate-passing candidate may be frozen for a conditional May/June assessment. If the gate fails, do not inspect May/June to rescue a policy and do not force an EA. Previously observed May/June would be a secondary holdout, not pristine OOS. The user requested analysis first; this report does not authorize or perform EA implementation.
