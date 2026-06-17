# 2026-06-17 - Relaxed FX-only Entry Conditions

## Summary

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Task: test a relaxed FX-only nested entry candidate branch for 2025.
- Scope: FX-only symbols, 2025 full year, both directions, no Friday stop, no pair exclusion, no RewardR/SL/TP/risk/spread guard change, no optimization.

## Changes

- Added `RESEARCH_STRATEGY_NESTED_RELAXED_FX_ENTRY_CANDIDATES`.
- Added a runner scenario set: `RelaxedConditionFactorial`.
- Added analysis script: `scripts/analyze_relaxed_fx_only_2025_condition_factorial.py`.
- Kept H1 counter N-wave, H1 counter wave ATR size, H4 fib zone, and true BOS level as diagnostics instead of relaxed-mode hard gates.
- Kept these relaxed-mode hard gates:
  - H4 MA bias
  - H1 pullback / return via previous extreme break
  - M15 recent high/low close BOS

## Verification

- Compile log: [`reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_compile.log`](../../reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_compile.log)
- Compile result: `0 errors, 0 warnings`
- Backtest run: `fxrelax2025_A_relaxed_condition_candidates`
- Backtest scope: `USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD`, 2025-01-01 to 2025-12-31

## Evidence

- Summary: [`reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_summary.md`](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_summary.md)
- Comparison: [`reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_comparison.csv`](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_comparison.csv)
- Trades: [`reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_trades.csv`](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_trades.csv)
- LONG failure summary: [`reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_long_failure_summary.md`](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_long_failure_summary.md)
- MT5 report: [`reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fxrelax2025_A_relaxed_condition_candidates_report.html`](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fxrelax2025_A_relaxed_condition_candidates_report.html)

## Result

- Current Broad FX-only: `63` trades, PF `0.737`, avg_R `-0.190`, net `-603.67`.
- Relaxed base: `28` trades, PF `0.792`, avg_R `-0.146`, net `-206.85`.
- Relaxed + room_to_1r: `24` trades, PF `0.815`, avg_R `-0.128`, net `-156.45`.
- Relaxed + room_to_2r: `17` trades, PF `1.091`, avg_R `0.056`, net `49.82`.
- Relaxed + room_to_2r + round/major obstacle clear: `8` trades, PF `1.206`, avg_R `0.121`, net `50.94`.

## Decision

- `room_to_2r` still filters in the right direction, but it leaves too few trades for a robust fixed-BT candidate.
- The relaxed base branch does not fix FX-only expectancy. Both LONG and SHORT remain weak in the base set.
- The best-looking result is not promotable because it has only `8` trades and is concentrated in `EURUSD` and `USDJPY`.
- No annual BT should be run from this branch yet.
