# 2026-07-01 Session Reversal Timeframe Matrix Partial 16

## Task

Stop the long-running 72-row MT5 batch and analyze the first 16 attempted rows
for `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`.

## Execution

The batch was stopped during row 17 after rows 1-16 were attempted. No residual
`terminal64.exe`, `metatester64.exe`, `backtest.ps1`, or matrix batch process
was left running.

## Findings

- The first 16 rows do not contain a 2025 shallow-gate candidate.
- Most London rows produced zero trades because the HTF permission gate rejected
  entries.
- The only tradeful rows were:
  - `london_first120__h1_m15_m5_top_notopp__no_be`
  - `london_first120__h1_m15_m5_top_notopp__be_1_1r`
- These two rows produced 46 trades each, but both were negative:
  - no-BE: PF 0.68, avg_R -0.173, net -189.23
  - 1.1R BE: PF 0.70, avg_R -0.160, net -176.14
- Break-even at 1.1R slightly improved net and avg_R but did not reduce full SL
  count, so it does not solve the strategy weakness.
- The previously promising London first120 result was not reproduced in this
  partial matrix evidence.

## Artifact Issue

`all_first120__current__no_be` created a usable EA summary in the MT5 Common
Files folder, but the batch runner marked it `completed_missing_artifacts`
because the expected summary filename did not match the EA output filename.
Rows 15-16 also lacked usable collected artifacts.

This should be fixed before continuing the remaining long batch.

## Evidence

- `reports/backtest/runs/20260628_session_reversal_pullback_timeframe_matrix/batch_status.csv`
- `reports/backtest/runs/20260628_session_reversal_pullback_timeframe_matrix/partial_16_analysis.md`
- `reports/backtest/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_london_first120__h1_m15_m5_top_notopp__no_be_2025_report.html`
- `reports/backtest/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_london_first120__h1_m15_m5_top_notopp__be_1_1r_2025_report.html`

## Decision

Do not promote any candidate from this partial evidence. Continue only after the
artifact collection mismatch is corrected.
