# Session Reversal Refined M5 ABC And Session Gate Diagnostic

## Task

Refine `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` after the failed nested third-wave launch test.

The goal was to test whether better definitions of M15 wave2 completion and M5 opposite ABC/123 invalidation could improve entry quality, MFE, and full-year expectancy without symbol exclusion, direction-only repair, weekday stops, or small threshold optimization.

## Changes

- Added `InpSessionGateMode` with existing first120, no-session diagnostic, active-label-only, and late-structure modes.
- Added refined M15 wave context modes and diagnostics.
- Added refined M5 corrective ABC/123 detection, close-break invalidation, post-break acceptance, and first-retest diagnostics.
- Added MFE threshold columns for 0.5R, 0.8R, 1.0R, 1.3R, and 1.5R.
- Added coarse exit mode labels and structure target fields for future comparison.
- Added generation and analysis scripts:
  - `scripts/generate-session-reversal-refined-m5-abc-cycles.py`
  - `scripts/analyze-session-reversal-refined-m5-abc-cycles.py`

## Validation

- Compile log: `reports/backtest/runs/20260702_session_reversal_refined_m5_abc_session_gate/compile.log`
- Report folder: `reports/backtest/runs/20260702_session_reversal_refined_m5_abc_session_gate/`
- `0 errors, 0 warnings`.
- Generated presets use H1=`16385`, M15=`15`, M5=`5`.
- Generated tester ini files use `Enabled=0` and `AllowLiveTrading=0`.
- All collected trade rows show `selected_candidate_timeframe=PERIOD_M5`.

## Result

- 2025 baseline all-symbols: 318 trades, PF 0.59, avg_R -0.1582, avg_MFE 0.597R.
- No-session baseline: 324 trades, PF 0.59, avg_R -0.1564. Session gate was not the main cause.
- M5 ABC invalidation required: 18 trades, PF 0.58, avg_R -0.1701. The hard gate failed.
- M15 wave2 required-light + M5 ABC score: 50 trades, PF 1.34, avg_R +0.1099, avg_MFE 0.781R. Useful but too sparse.

## Decision

No operating candidate.

The useful signal is M15 wave2 context, not the current M5 ABC invalidation hard gate. The next experiment should preserve the M15 wave2 MFE lift while increasing trade count, instead of tightening M5 invalidation further.
