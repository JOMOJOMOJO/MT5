# 2026-06-17 - Nested Condition Factorial Analysis

## Summary

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Added diagnostic-only research mode: `RESEARCH_STRATEGY_NESTED_CONDITION_FACTORIAL_CANDIDATES`
- Purpose: generate broad Nested / Structural BOS-style candidates and evaluate which `cond_*` flags improve expectancy or reduce trade count.
- Scope: short-window diagnostic only, no parameter optimization, no symbol exclusion, no direction-only promotion, no Friday/time filter.

## Implementation

- Added broad candidate mode using:
  - H4 MA or Dow bias
  - H1 previous extreme break or counter N-wave
  - M15 previous extreme BOS or true BOS close
- Added condition flags to nested signal/trade diagnostics:
  - `cond_h4_bias_ma`
  - `cond_h4_dow_bias`
  - `cond_h4_fib_382_618`
  - `cond_h1_prev_extreme_break`
  - `cond_h1_counter_nwave`
  - `cond_h1_counter_wave_atr`
  - `cond_true_bos_level`
  - `cond_m15_prev_extreme_bos`
  - `cond_m15_close_bos`
  - `cond_room_to_1r`
  - `cond_room_to_2r`
  - `cond_sl_atr_ok`
- Added runner scenario: `ConditionFactorial`.
- Added analyzer: `scripts/analyze_condition_factorial.py`.

## Verification

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_compile.log`
- Compile result: `0 errors, 0 warnings`
- Short BT periods:
  - `2025-02`
  - `2025-08`
  - `2025-10`
  - `2026-Q1`

## Evidence

- Summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_summary.md`
- Candidates: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_candidates.csv`
- All combinations: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_all_combinations.csv`
- Single effects: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_single_effects.csv`
- Top combinations: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_top_combinations.csv`

## Result

- Broad candidates/trades: `47`
- Aggregate PF: `1.171`
- Aggregate avg_R: `0.137`
- Aggregate net: `239.56`
- Distribution:
  - Periods: `2025-02:5`, `2025-08:12`, `2025-10:5`, `2026-Q1:25`
  - Symbols: all seven configured symbols appeared
  - Directions: `LONG:20`, `SHORT:27`

## Findings

- `cond_room_to_2r` was the strongest min-trades-20 diagnostic combination:
  - `24` trades
  - PF `1.624`
  - avg_R `0.37`
  - net `401.55`
- Strongest single-condition expectancy deltas:
  - `cond_m15_close_bos`
  - `cond_room_to_1r`
  - `cond_h4_bias_ma`
  - `cond_h4_fib_382_618`
  - `cond_room_to_2r`
- Largest trade-count reducers:
  - `cond_h4_fib_382_618`
  - `cond_m15_close_bos`
  - `cond_room_to_2r`
- Weak or harmful single filters in this sample:
  - `cond_h1_counter_wave_atr`
  - `cond_h4_dow_bias`
  - `cond_m15_prev_extreme_bos`
  - `cond_h1_counter_nwave`

## Decision

- No fixed condition set cleanly passed the short diagnostic gate for annual MT5 validation.
- `cond_room_to_2r` should remain a diagnostic label or future hypothesis, not an immediate hard gate.
- The best diagnostic set still has weak balance:
  - FX net positive but modest
  - XAUUSD contributes heavily
  - LONG net remains slightly negative
  - SHORT carries most of the profit
- Next work should inspect why room-to-target helps and why H1 N-wave strictness does not, before adding another hard-gated mode.
