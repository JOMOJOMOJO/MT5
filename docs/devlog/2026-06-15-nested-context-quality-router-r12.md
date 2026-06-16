# 2026-06-15 - Nested Context Quality Router RR 1.2 Cycle

## Summary

- Added independent `RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER` diagnostics branch.
- Added `ContextQualityRouterV2`: v1 plus a fixed weak-breakout body guard (`breakout_body_atr >= 0.20`).
- Added `ContextQualityRouterV3`: v2 plus a Friday 21:00+ server-time new-entry guard for Nested setups.
- All comparison runs used `InpRewardR=1.20`; this was a fixed diagnostic value, not an optimization sweep.
- Tested short windows first: 2025-02, 2025-08, 2025-10, 2026-Q1.
- Because v2 improved the short-period result, ran annual A/E/F checks for 2024, 2025, and 2026YTD.

## Evidence

- Summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_context_router_r12_summary.md`
- Comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_context_router_r12_comparison.csv`
- Trade rows: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_context_router_r12_trade_rows.csv`
- Block summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_context_router_r12_block_summary.csv`
- Annual summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_context_router_r12_annual_summary.md`
- Annual comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_context_router_r12_annual_comparison.csv`
- Compile logs:
  - `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_context_quality_router_compile.log`
  - `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_context_quality_router_v2_compile.log`
  - `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_context_quality_router_v3_compile.log`

## Result

- Short-period fixed RR 1.2 result:
  - Instant all: `PF 0.946`, `avg_R -0.014`, `net -71.14`.
  - Context Router v1: `PF 1.165`, `avg_R 0.094`, `net 93.19`.
  - Context Router v2: `PF 1.300`, `avg_R 0.154`, `net 123.93`.
- Annual check:
  - Instant all: `PF 0.951`, `avg_R -0.014`, `net -275.87`, `maxDD 12.16%`.
  - Context Router v2: `PF 0.867`, `avg_R -0.063`, `net -292.39`, `maxDD 7.54%`.
  - Context Router v3: `PF 0.932`, `avg_R -0.026`, `net -135.95`, `maxDD 5.81%`.

## Decision

- Context Quality routing improved the selected short windows but did not survive annual validation.
- The Friday guard removed a 2025 XAUUSD weekend gap outlier and reduced drawdown, but it did not create a positive annual edge.
- Do not promote v1/v2/v3 as a live or main research candidate.
- Further tuning of M15 candle/context thresholds is likely to overfit. The next useful research step is a better setup definition, not another router threshold.

## Guardrails

- Existing ThirdWave, v2, v3, v4, Phase2, score scanner, CTrade bridge, spread guard, risk sizing, and base SL/TP mechanics were not intentionally changed.
- The Friday guard is isolated to `RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER_V3`.

## Superseded Note

- 2026-06-16 cleanup removed the Friday guard from EA strategy logic. V3 is now treated as a deprecated V2 compatibility alias; the old Friday result remains only historical evidence that an operational cutoff can reduce drawdown without proving structural edge.
