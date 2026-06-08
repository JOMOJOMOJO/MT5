# 2026-06-08 - Nested N-Wave Breakout Quality Router

## Summary

- Added independent research mode `RESEARCH_STRATEGY_NESTED_NWAVE_BREAKOUT_QUALITY_ROUTER`.
- Router classifies M15 neckline breaks into `strong_breakout`, `weak_breakout`, `dirty_breakout`, or `unclear`.
- `strong_breakout` uses instant entry, `weak_breakout` requires retest confirmation, and `dirty_breakout` is skipped.
- Existing instant Nested, Retest Confirmation, ThirdWave v2/v3/v4, Phase2, score scanner, SL/TP, RewardR, timeframe, spread guard, risk sizing, and CTrade bridge were left unchanged.

## Verification

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_breakout_quality_router_compile.log`
- Compile result: `0 errors, 0 warnings`
- Short-period BT only:
  - `2025-02`
  - `2025-08`
  - `2025-10`
  - `2026-Q1`

## Evidence

- Summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_breakout_quality_router_summary.md`
- Comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_breakout_quality_router_comparison.csv`
- Breakout quality summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_breakout_quality_router_breakout_quality_summary.csv`
- Diagnostics: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_breakout_quality_router_breakout_quality_diagnostics.csv`
