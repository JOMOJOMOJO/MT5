# Two-stage development checkpoint — 2026-09-14

**DIAGNOSTIC_NOT_ADOPTED. No profitable adoption candidate passed the preregistered gates.**
July/August have not been read. This is not a completed holdout or live-readiness report.

## Completed work

- January–June 2025, six symbols, 15,119 feature episodes, 486 causal features;
  normalized variant retains 448. Frozen shock detector was not changed.
- Six model families × two feature sets × three fixed-time horizons × five
  expanding forward folds: 180 fits of three estimators each.
- Stage 1 predicts best-side net R; Stage 2 predicts LONG and SHORT net R.
  Gates and frequency policies were fixed before model fitting.
- Independent accounting: 59 checks, zero failures.
- Full 180-fit deterministic replay: 9,360 comparisons, zero failures.
- Actual MT5 model parity: all 15,119 development vectors PASS, including
  Stage 1 score, both directional scores, threshold and final decision.
- Candidate EA and parity harness compile: 0 errors / 0 warnings.

## Frozen diagnostic candidate

ElasticNet, SCALE_FREE448, 5-minute exit, Stage 1 training 25th-percentile gate,
FREQUENCY_500 training-only calibration. This is the predeclared diagnostic
selection, not the best hindsight cell and not an adopted profitable strategy.

| Forward month | Trades | Net expectancy R | PF |
|---|---:|---:|---:|
| February | 517 | -0.07226 | 0.8041 |
| March | 1,114 | -0.09160 | 0.7409 |
| April | 691 | -0.09068 | 0.7544 |
| May | 439 | -0.07065 | 0.8078 |
| June | 235 | -0.00091 | 0.9971 |
| Total | 2,996 | -0.07787 | 0.7827 |

Total -233.2846 R; win rate 46.53%; max drawdown 264.655 R;
LONG 1,094 / SHORT 1,902. Removing the five best trades leaves -261.4442 R.
Gross expectancy is also negative (-0.04452 R), before the extra cost assumption.
Thus this candidate's failure is not explained solely by the extra 0.2 pip cost.

## Units and limitations

Spread is already in executable Bid/Ask labels. Extra 0.2 pip round trip is an
assumption, **not observed commission**. Actual tester commission is pending.
R denotes one completed M5 ATR14, not a protective stop or guaranteed loss cap.
Primary exits are fixed time, with no TP or SL; maximum observed excess delay
in selected development trades is 1,903.126 seconds. No retrospective exclusion
was made. The diagnostic EA sizes at 10 USD per ATR, capped at 0.25% equity per
ATR; this does not cap actual loss at those amounts.

The January wiring smoke uses the January–June fitted model. It is an integration
test, not forward performance evidence. July/August require final source/binary/
preset freeze and commit after this smoke passes; neither has been launched.

## Evidence and unfinished work

Analysis: `reports/analysis/tick_shock/two_stage_ml_20260913/`:
`walk_forward.csv`, `candidate_frontier.csv`, `selection.json`,
`selected_development_monthly.csv`, `selected_development_trades.csv`,
`independent_recalculation.csv`, `independent_breakdowns.csv`,
`deterministic_rerun.csv`, `python_freeze.json`, `frozen_model.json`.

MQL parity: `reports/tests/tick_shock/two_stage_model_parity_20260914/results.csv`.
Compile: `reports/compile/tick_shock/two_stage_candidate.log` and
`reports/compile/tick_shock/two_stage_model_parity.log`.
EA: `mql/Experts/ExpectedValue_TickShockTwoStageCandidate.mq5` (tester-only).

Still pending: smoke reconciliation, interpretation/ablation reporting,
final freeze commit, July/August tester runs, actual deal reconciliation,
final independent QA and complete reproducibility package.
