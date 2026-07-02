# Session Reversal Nested Third-Wave Launch Diagnostic

## Task

Move `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` closer to the transcript concept:

- H1 context wave.
- M15 wave1/wave2 candidate.
- M5 corrective 123 that is invalidated.
- Entry after break/retest into the intended M15 third wave.
- Keep M5 failure exit and diagnose MFE/time-exit behavior.

## Changes

- Added `InpUseNestedThirdWaveLaunch` and `InpNestedThirdWaveMode`.
- Added diagnostic, score, and required modes.
- Added M15 wave1/wave2, M5 corrective wave, M5 invalidation, post-break acceptance, context fib room, M15 wave2 fib, and 75SMA/Granville CSV fields.
- Kept baseline behavior when nested mode is off.
- Added scripts:
  - `scripts/generate-session-reversal-nested-launch-cycles.py`
  - `scripts/analyze-session-reversal-nested-launch-cycles.py`

## Validation

- Compile: `reports/backtest/runs/20260702_session_reversal_nested_thirdwave_launch/compile.log`
  - Result: 0 errors, 0 warnings.
- Report folder: `reports/backtest/runs/20260702_session_reversal_nested_thirdwave_launch/`
- Timeframe configuration:
  - H1: `16385`
  - M15: `15`
  - M5: `5`
- Executed trade rows confirmed `selected_candidate_timeframe=PERIOD_M5`.

## Results

- Q1 quick check:
  - baseline/diagnostic/score: 107 trades, PF 0.46, avg_R -0.2217.
  - required M5 invalidation: 33 trades, PF 0.31, avg_R -0.2647.
  - required fib room: 47 trades, PF 0.24, avg_R -0.3130.
- 2025 all-symbols:
  - baseline: 318 trades, PF 0.59, avg_R -0.1582.
  - score and score+fib-room: unchanged from baseline.
  - required M5 invalidation: 90 trades, PF 0.49, avg_R -0.2073.
  - required fib room: 185 trades, PF 0.61, avg_R -0.1415.

## Decision

No operating candidate.

Nested diagnostics did expose small positive buckets, especially M15 wave1+wave2 and M15 wave2 fib 38.2-61.8, but those buckets were too small to promote. The portfolio-level all-symbols results remain negative, and time exits still dominate. Do not run 3-year fixed BT or OOS until a 2025 full-year candidate passes the basic gate.
