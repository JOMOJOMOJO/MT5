# Session Reversal Nested Third-Wave Launch Optimization Note

## Hypothesis

The previous transcript implementation failed because it detected generic M5 retests, not the specific "M15 wave2 ending by M5 corrective 123 invalidation" structure. This test added that structure as diagnostics, score, and required gates.

## Evidence

- Main report: `reports/backtest/runs/20260702_session_reversal_nested_thirdwave_launch/summary.md`
- Comparison: `reports/backtest/runs/20260702_session_reversal_nested_thirdwave_launch/full2025_comparison.csv`
- M15 breakdown: `reports/backtest/runs/20260702_session_reversal_nested_thirdwave_launch/m15_wave_breakdown.csv`
- M5 invalidation breakdown: `reports/backtest/runs/20260702_session_reversal_nested_thirdwave_launch/m5_corrective_invalidation_breakdown.csv`

## Findings

- M5 corrective invalidation is not enough as a hard gate. It cut all-symbols 2025 trades from 318 to 90 and worsened PF to 0.49.
- M15 wave1+wave2 is the most interesting diagnostic bucket, but only 21 score-mode trades in 2025.
- M15 wave2 fib 38.2-61.8 is strong but too sparse: 9 score-mode trades.
- H1 context fib deep 61.8-78.6 is positive but too sparse: 26 trades.
- 75SMA/Granville diagnostics did not create a scalable gate.
- Average MFE near 0.60R shows the entry often does not launch strongly enough for a 1.3R fixed TP.

## Decision

Reject this implementation as an operating candidate.

Do not repair it through symbol exclusion, direction-only logic, weekday stops, SMA-period tuning, or fib-threshold tuning. The next useful research direction is more precise timing around M15 wave2 completion and M5 invalidation/retest acceptance, not more coarse score stacking.
