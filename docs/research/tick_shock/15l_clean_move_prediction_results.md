# Step 15L Clean Move Prediction results

## Outcome

The March development sample contains a reproducible clean-move prediction signal, but it is not production evidence. The strongest registered nonlinear model (LightGBM, full features, no symbol) achieved pooled walk-forward average precision 0.2213 against an OOF clean rate of 0.03086. All four chronological validation folds remained above their own base rate. At 90% OOF recall it reduced 1,620 validation episodes to 327 candidates, capturing 45 of 50 clean cases (precision 0.1376, 4.46x enrichment).

This does **not** freeze a trading rule. March 2025 has already been reused for development, the OOF pool contains only 50 clean positives, the first 40% of clusters is training-only, and 156 of all 188 clean episodes are USDJPY. A genuinely unused OOS interval is required.

Verdicts:

- `CLEAN_MOVE_PREDICTION_SIGNAL_FOUND`
- `HIGH_RECALL_COMPRESSION_FOUND`
- `LIGHTGBM_OUTPERFORMS_LINEAR_BASELINE`
- `LAG_FEATURES_DO_NOT_ADD_SIGNAL`
- `CROSS_SYMBOL_SIGNAL_FOUND` (limited to symbols with positives and not a production claim)
- `SYMBOL_IDENTITY_DOMINATES` is not supported by the with/without-symbol model comparison, although the target population itself is highly USDJPY-concentrated
- `DIRECTIONAL_SIGNAL_NOT_FOUND`
- `EA_DISTILLATION_NOT_YET_FEASIBLE`
- `OOS_VALIDATION_REQUIRED`
- `PRODUCTION_NOT_ELIGIBLE`

## Data and target

- Analysis-ready episodes: 2,696
- Clean move: 188 (6.97%); non-clean: 2,508
- Clean continuation: 84; clean reversal: 104; both: 0
- Symbol counts: USDJPY 1,006/156 clean, EURUSD 248/22, USDCAD 631/10, AUDUSD 500/0, USDCHF 311/0
- GBPUSD: excluded from primary population because its formal March feed reported 179 generated-fallback minutes out of 30,187 and no interval map exists
- Geometry: TP 0.40 ATR, hold at most 900 seconds, pre-TP MAE at most 0.25 ATR
- Predictors: 59 numeric features in the full group, plus shock direction and session; symbol only in the explicit ablation
- New MQL predictors: 38 causal lag/market-state values backed by a 901-sample one-second in-memory ring

The formal feature run produced 3,151 causal feature rows and 3,151 medium-horizon episodes. The 2,696-row modeling population is the Step 15K analysis-ready population joined one-to-one to those snapshots.

## Validation design

No random split or SMOTE was used. Market clusters were ordered by first t0 and split as expanding windows: train 0-40% / validate 40-55%, then 0-55/55-70, 0-70/70-85, and 0-85/85-100. A market cluster cannot occur on both sides of a fold. Pooled OOF therefore covers 1,620 episodes and 50 positives; it deliberately does not score the initial training-only 40%.

| Model, full features, no symbol | AP | Recall @0.5 | Precision @0.5 | F2 | Selected |
|---|---:|---:|---:|---:|---:|
| Logistic | 0.1528 | 0.52 | 0.1340 | 0.3299 | 194 |
| Shallow tree | 0.2053 | 0.70 | 0.2108 | 0.4781 | 166 |
| LightGBM | 0.2213 | 0.44 | 0.2316 | 0.3729 | 95 |

The fixed 0.5 threshold is descriptive. The registered primary comparison is ranking quality and the recall/candidate frontier.

LightGBM fold AP/base-rate pairs were 0.2165/0.0392, 0.3748/0.0249, 0.1481/0.0149, and 0.2667/0.0443. This is directionally persistent, but still a small development sample.

## Recall and candidate-count frontier

### Walk-forward OOF (valid performance evidence within March development)

| Selection | Selected episodes | Clusters | Clean captured | Recall | Precision | Enrichment |
|---|---:|---:|---:|---:|---:|---:|
| Top 100 | 100 | 100 | 23/50 | 46% | 23.0% | 7.45x |
| Top 200 | 200 | 199 | 35/50 | 70% | 17.5% | 5.67x |
| Top 300 | 300 | 296 | 42/50 | 84% | 14.0% | 4.54x |
| Top 500 | 500 | 480 | 48/50 | 96% | 9.6% | 3.11x |
| Top 800 | 800 | 756 | 50/50 | 100% | 6.25% | 2.03x |
| Top 1,000 | 1,000 | 946 | 50/50 | 100% | 5.0% | 1.62x |

For target recall 95/90/80/70/60%, the first attainable OOF candidate counts were respectively 498, 327, 269, 194, and 170. At 90% recall the symbol mix was USDJPY 281, EURUSD 36, AUDUSD 5, USDCAD 3, USDCHF 2. Thus compression remains strongly USDJPY-weighted.

### Full-population refit diagnostic (not validation)

To answer how far all 188 positives can be compressed, the fixed model was also refit and scored on all 2,696 rows. This is intentionally labeled `DEVELOPMENT_REFIT_DIAGNOSTIC`: top 100/200/300/500 captured 91/157/185/188 clean episodes; 90% recall required 229 candidates and 80% required 190. These optimistic figures must never be cited as OOS performance.

## Feature results and ablation

The largest univariate separations were ATR14 M5, tick counts over 10-120 seconds, ATR/spread state, spread percentile, and lagged spread/ATR. Cluster bootstrap intervals and quantile clean rates are in the persisted tables.

For LightGBM, AP by group A/B/C/D/E was 0.2013, 0.1904, 0.2106, 0.2295, and 0.2213. Price lags alone reduced AP relative to the existing-feature baseline; the improvement appeared only after liquidity/activity and market-structure information were combined. The full interaction group did not improve on group D. Accordingly, the evidence does not support the broad claim that lag features as a block add stable signal.

Permutation importance on the final validation window was led by `spread_5s_atr`, `spread_30s_atr`, `spread_atr_t0`, `spread_10s_atr`, `return_5s_dir_atr`, `return_900s_dir_atr`, prior 15-minute extension, and realized 30-second movement. Gain importance similarly emphasized current and lagged spread. This is predictive association, not causality.

## Hard filter comparison

In the original full Step 15K population, the frozen high-movement hard filter selected 185 and captured 38 clean episodes (20.54% precision), with 34 of those 38 from USDJPY. Within the OOF rows, only 93 hard-filter selections and 10 clean captures are present. Selecting the top 93 LightGBM scores captured 21 clean cases (22.58% precision), while hard-filter AND top-score selected 25 and captured 8. Treating high movement as a feature/ranking input therefore preserved more recall than retaining it as a mandatory gate.

## Symbol and direction diagnostics

Adding symbol identity reduced full LightGBM AP from 0.2213 to 0.2012. Leave-one-symbol-out AP was 0.2758 on USDJPY (base 0.1551), 0.2709 on EURUSD (base 0.0887), and 0.2627 on USDCAD (base 0.01585). AUDUSD and USDCHF contain no positives, so prediction performance is not estimable for them. This is evidence of some cross-symbol ranking signal where positives exist, not evidence of six-symbol robustness.

Among clean episodes, continuation-vs-reversal pooled OOF results were weak: logistic AP 0.4699 and ROC-AUC 0.5160; LightGBM AP 0.4418 and ROC-AUC 0.4752, against a continuation rate of 0.4690. No direct-action expectancy or direction rule is promoted.

KMeans produced high-clean-rate exploratory groups (for example k=5 cluster 3: 124/646, 19.2%), but those groups remain USDJPY-heavy and were not converted to a rule.

## Calibration and portability

The score is a useful ranking score but is not calibrated probability: the highest OOF decile averaged score 0.566 with observed clean rate 0.167. No Platt or isotonic calibration was fitted because there is no additional untouched calibration interval.

The LightGBM descriptive fit uses 200 trees, maximum depth 4, and 59 numeric predictors plus two categorical inputs. Direct MQL tree export is possible in principle but not justified now. The shallow tree has comparable AP with higher recall at 0.5, yet no distilled model has been tested against LightGBM predictions. External Python/API/network inference is not proposed.

## Integrity and QA

- Research EA and Step 15L feature harness: compile 0 errors / 0 warnings
- Feature harness: 8 PASS / 0 FAIL through the production feature module
- Existing MQL production-path regression rerun: 403 MATCH / 11 SKIP; all 16 compile logs 0 errors / 0 warnings
- Existing Python registry rerun: 361 PASS / 0 FAIL / 9 SKIP
- Step 15L model QA: 10 PASS / 0 FAIL
- Independent reconciliation: 23 PASS / 0 FAIL
- Deterministic analysis rerun: 29 output files compared, SHA changes 0
- Feature timestamp violations: 0
- Target-leakage feature names: 0
- Train/validation cluster overlap: 0
- Leave-one-symbol-out cluster overlap: 0
- Duplicate episode IDs: 0
- Orders/trades: 0; `trades.csv` is header-only
- Behavior comparison with the Step 15K formal run: detector rows 21,799, medium-horizon rows 3,151, completed rows 3,103, and 114 legacy columns all matched; unintended differences 0
- Formal run: 10,587,807 tester ticks, 0:11:32.961, 502 MB tester memory; internal maximum counter 31 MB

The retained SKIPs are terminal-only observations from the existing suite and are not counted as PASS. The two-tick difference between tester total ticks (10,587,807) and the EA per-symbol counter sum (10,587,809) is disclosed and remains a provenance/counting observation; it does not alter episode identity or the zero-difference behavior comparison.

## Reproduction and evidence

- Formal run: `reports/backtest/runs/20260903_ts15l_clean_move_ml_r1_202503/`
- Analysis: `reports/analysis/tick_shock/step15l/`
- Preregistration: `docs/research/tick_shock/15l_clean_move_prediction_preanalysis.md`
- Feature catalog: `docs/research/tick_shock/15l_feature_catalog.md`
- Pipeline: `tools/tick_shock/analyze_step15l_clean_move.py`
- Independent oracle: `tools/tick_shock/step15l_independent_oracle.py`
- Environment lock: `reports/analysis/tick_shock/step15l/requirements_step15l.txt`

No AutoML/PyCaret comparison was run: the fixed logistic/tree/LightGBM set already answers signal existence, while adding model families on the repeatedly used March sample would increase researcher degrees of freedom. No strategy threshold, TP/SL, hold, symbol policy, or production trading logic was frozen or changed.
