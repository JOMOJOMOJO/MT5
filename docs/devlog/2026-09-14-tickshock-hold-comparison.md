# User-requested hold comparison

Compare 300 seconds versus 14,400 seconds using the same frozen two-stage model,
six symbols, EURUSD M1 driver, real-tick Model 4, July 1–September 1, 2025.
Two continuous July–August runs, sequentially, with fresh RunIds and no tuning
between them. User requested launch only; analysis will follow their completion notice.

Added `InpTechnicalHoldSeconds`, defaulting to the previous model hold (300).
Only actual candidate time exit changes. No TP/SL, model, entry threshold, position
limit or sizing changes. Tester-only guard preserved. Four hours is an exit
sensitivity experiment, not a model trained to predict four-hour returns.
Research fixed-time sidecar labels remain 5/10/15 minutes; for this comparison
use actual `candidate_trades.csv`, not the sidecar, for four-hour realized results.
Longer holding can reduce entry counts through the single-position constraint.

Runner: `tools/tick_shock/run_two_stage_hold_comparison.ps1`.
Evidence: `reports/backtest/batches/two_stage_hold_comparison_20260914/`.
Failure stops the batch; no implicit overwrite, resume or terminal termination.
