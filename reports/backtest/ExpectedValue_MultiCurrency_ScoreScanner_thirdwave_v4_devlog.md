# 2026-06-05 - ThirdWave v4 Early Reversal Branch

## Summary

- Added a separate ThirdWave v4 research mode based on Wave Audit, v2, and v3 findings.
- v4 keeps all-symbol, both-direction ThirdWave behavior but detects earlier lower-timeframe reversal signatures.
- Existing Phase2 scanner, existing ThirdWave, v2, and v3 modes remain separate.

## Implementation

- New mode: `RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V4_EARLY_REVERSAL`.
- Added early reversal signatures: `early_higher_low`, `early_lower_high`, `momentum_turn`, `candle_reversal`, and `micro_break`, with confirmed fractal reclaim/breakdown retained as a fallback reference.
- Added v4 summary counters and v4 reversal fields to ThirdWave diagnostics.
- Kept RewardR, SL/TP, spread guard, timeframe settings, risk sizing, and CTrade bridge unchanged.

## Verification

- Compile evidence: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v4_compile.txt`.
- Short-period comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v4_short_period_summary.md`.
- Annual gate result: not passed.

## Decision

- No parameter optimization was performed.
- The short-period gate did not pass, so annual validation was intentionally skipped.
- v4 should remain diagnostic evidence unless it restores enough trade count, improves label distribution, and improves FX-wide expectancy.
- Next work should follow the short-period evidence: continue early reversal only if it improves broad expectancy, otherwise move to Regime Quality v2 or treat ThirdWave as a continuation branch.
