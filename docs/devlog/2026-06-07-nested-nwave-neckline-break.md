# 2026-06-07 - Nested N-Wave Neckline Break

## Summary

- Added a separate `RESEARCH_STRATEGY_NESTED_NWAVE_NECKLINE_BREAK` branch.
- Implemented H4 impulse/pullback zone, H1 counter-trend N-wave, and M15 neckline break detection.
- Kept existing ThirdWave and score scanner modes intact.
- Ran short-period validation only; annual validation is gated by short-period evidence.

## Evidence

- Short summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_neckline_break_short_period_summary.md`
- Comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_neckline_break_comparison.csv`
- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_compile.log`

## Result

- Compile: `0 errors, 0 warnings`.
- Nested best/all did not clear the short-period gate.
- 2025-10 was strong, but 2025-02 was negative and 2026-Q1 failed materially.
- Annual BT was not run because the evidence was period-specific and not robust enough.

## Decision

- Keep the branch as a research asset, not a promoted candidate.
- The simple H4 pullback zone + H1 counter-trend N-wave + M15 neckline break definition is not sufficient as implemented.
- The next useful diagnostic would be neckline quality and 2026-Q1 failure decomposition, not RewardR or symbol/direction narrowing.
