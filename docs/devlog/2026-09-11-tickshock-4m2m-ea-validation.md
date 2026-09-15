# TickShock 4m training / 2m locked candidate test

User requested January-April analysis, an EA encoding the learned features, and
May-June MT5 testing. Existing deleted TechnicalFeatures/TechnicalStudy files and
unrelated step15g changes were preserved. No collection rerun or live chart order.

## Protocol and current artifacts

- [Preregistration](../research/tick_shock/technical_4m2m_real_preregistration.md)
- [Training interpretation](../research/tick_shock/technical_4m2m_learning_results.md)
- [Model freeze](../../reports/analysis/tick_shock/technical_4m2m_real/freeze_record.json)
- [All selection cells](../../reports/analysis/tick_shock/technical_4m2m_real/selection_frontier.csv)
- [Final run state](../../reports/backtest/batches/tstech_4m2m_validation_r2_20260911/status.json)

Training data: 11,230 episodes, 486 features. January-February -> March and
January-March -> April purged temporal validation. All 108 cells are retained.
No candidate passed every frequency/stability gate. The preregistered diagnostic
fallback selected g5_ELASTICNET_LOGISTIC_0.1, then refit January-April without
changing its threshold. Its refitted frequency collapsed to 199 trades over four
months; this is an explicit objective failure, not concealed by the inner-fold counts.

## Engineering failure and corrective rerun

The collection source archive predates the candidate snapshot callback. A private
copy plus the existing order adapter compiled and passed standalone model parity,
but the missing TSTDArm -> TSTCOnSnapshot call prevented candidate decisions.
Monitoring caught zero candidate output. The task-owned worker was stopped and
the task-owned terminal was asked to close normally. The invalid first run is
retained, not reused as a performance result:
[invalid attempt](../../reports/backtest/batches/tstech_4m2m_validation_20260911/INVALID_WIRING.md).

The already-existing callback from Git HEAD was added only to the private copy.
No fitting, weight, threshold, exit, or direction-rule change followed holdout
replay. The r2 batch adds an actual training-day integration smoke before the two
holdout months. Original deleted files remain untouched.

Reusable lesson: model inference parity alone does not prove an EA's signal
path is connected. Require nonzero production snapshots reconciled to model
decision rows before starting a long validation run.

## Data qualification

Model4 was used, but tester journal records 1,306 discarded USDCHF minutes in
February and 8,559 symbol-minutes across six symbols in March. January/April
legacy scenario-pool warnings remain marked globally invalid; only separate
Technical collection checks passed. All limitations remain visible. No outcome-
dependent data exclusion was applied.

This is a tester-only diagnostic candidate, not a production promotion. Final
P/L, commission, timing and model parity are to be read from the r2 reconciliation
and final results, not inferred from the fitted training totals.

## Completed outcome

- May: 46 trades, -6.92 USD, -0.017285R/trade, money PF 0.9403.
- June: 25 trades, -13.20 USD, -0.057366R/trade, money PF 0.7550.
- All 3,889 held-out snapshots matched feature values/model decisions; 52 selected
  causal/accounting checks passed. Observed commission, fee and swap were zero.
- May had one Python-only trade: actual candidate reported NO_ENTRY_TIMEOUT.
- Maximum actual hold 906.491 seconds: strict 900-second containment is NOT met.
  It is a separately recorded limitation, not a passing timing test.
- Both month frequency and aggregate positive expectancy objectives failed.
  No retuning or substitute model was selected from the holdout results.

[Final results](../research/tick_shock/technical_4m2m_validation_results.md)
and [limitations](../../reports/backtest/batches/tstech_4m2m_validation_r2_20260911/limitations.csv)
are the current handoff, rather than the invalid first attempt.
