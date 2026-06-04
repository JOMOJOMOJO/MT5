# 2026-06-04 - ThirdWave v2 Audit-Filtered Branch

## Summary

- Added a separate ThirdWave v2 research mode based on prior Wave Audit findings.
- v2 keeps all-symbol, both-direction ThirdWave behavior but blocks three audit-derived structural weaknesses.
- Existing Phase2 scanner and existing ThirdWave modes remain separate.

## Implementation

- New mode: `RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V2_AUDIT_FILTERED`.
- Filters: deep/broken pullback, old higher-timeframe trend, and reclaim/breakdown chase distance above 1.5 ATR.
- Added v2 summary counters and v2 filter fields to ThirdWave diagnostics.

## Verification

- Compile evidence: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v2_compile.txt`.
- Short-period comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v2_short_period_summary.md`.
- Annual gate result: not passed.

## Decision

- No parameter optimization was performed.
- Annual validation should only be treated as complete if the short-period gate passes and year-level artifacts are generated.
