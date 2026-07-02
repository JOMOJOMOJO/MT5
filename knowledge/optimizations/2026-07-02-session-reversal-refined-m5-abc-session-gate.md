# Session Reversal Refined M5 ABC Optimization Note

## Hypothesis

The previous nested third-wave implementation failed because M5 invalidation was too generic. This test tried to refine it into a clearer M15 wave2 context plus M5 opposite ABC/123 invalidation and first retest.

## Evidence

- Summary: `reports/backtest/runs/20260702_session_reversal_refined_m5_abc_session_gate/summary.md`
- Comparison: `reports/backtest/runs/20260702_session_reversal_refined_m5_abc_session_gate/full2025_comparison.csv`
- M15 wave breakdown: `reports/backtest/runs/20260702_session_reversal_refined_m5_abc_session_gate/m15_wave_breakdown.csv`
- M5 ABC breakdown: `reports/backtest/runs/20260702_session_reversal_refined_m5_abc_session_gate/m5_corrective_abc_breakdown.csv`
- MFE threshold breakdown: `reports/backtest/runs/20260702_session_reversal_refined_m5_abc_session_gate/mfe_threshold_breakdown.csv`

## Findings

- Removing session first120 did not fix expectancy: 324 trades, PF 0.59, avg_R -0.1564.
- Refined M5 ABC close-break invalidation required did not work: 18 trades, PF 0.58, avg_R -0.1701.
- Post-break acceptance and first retest were too sparse: 10 trades, PF 0.88.
- M15 wave2 required-light was the most useful filter: 50 trades, PF 1.34, avg_R +0.1099, MFE>=1R 40.0%.
- The M15 wave2 finding is not promotable because 50 trades is below the 200-trade gate.
- Baseline MFE>=1R was 24.5%; M15-light raised it to 40.0%, so the direction of improvement is entry quality rather than exit management.

## Rejected Repairs

- Do not promote Tokyo/London/Clean small-sample rows.
- Do not repair with symbol exclusion, direction-only logic, weekday stops, or threshold tuning.
- Do not tighten M5 invalidation further as the next default move; it already collapses trade count and does not improve PF.

## Next Experiment

Broaden M15 wave2 context while preserving MFE lift. Candidate directions:

- Relax M15 wave2 from required-light to a two-tier acceptance bucket.
- Keep M15 wave2 context but allow multiple M5 entry patterns after it.
- Diagnose whether M15 wave2 under-38.2 and 38.2-61.8 buckets need separate handling.
