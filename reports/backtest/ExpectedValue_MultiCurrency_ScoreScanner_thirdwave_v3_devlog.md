# 2026-06-05 - ThirdWave v3 Entry Timing Branch

## Summary

- Added a separate ThirdWave v3 research mode based on prior Wave Audit and v2 findings.
- v3 keeps all-symbol, both-direction ThirdWave behavior but blocks late/chasing final entry positions.
- Existing Phase2 scanner and existing ThirdWave modes remain separate.

## Implementation

- New mode: `RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V3_ENTRY_TIMING`.
- Filters: invalid/range/unclear wave position, reclaim/breakdown chase, pullback-extreme chase, momentum exhaustion, late/chasing labels.
- Added v3 summary counters and v3 filter fields to ThirdWave diagnostics.

## Verification

- Compile evidence: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v3_compile.txt`.
- Short-period comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v3_short_period_summary.md`.
- Annual gate result: not passed.

## Decision

- No parameter optimization was performed.
- The short-period gate did not pass, so annual validation was intentionally skipped.
- v3 confirms that the existing ThirdWave detector is mostly trend-continuation/chasing, not an early third-wave-entry detector.
- This exact gate is too strict: it removes chasing labels but leaves only 3.7% of comparable trades and does not improve PF or average R.
- Next work should either rebuild lower-timeframe reversal detection for earlier entries or move to Regime Quality v2 for the continuation-style branch.
