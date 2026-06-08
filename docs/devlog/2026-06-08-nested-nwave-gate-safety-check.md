# 2026-06-08 - Nested N-Wave Gate Safety Check

## Summary

- Strategy: `RESEARCH_STRATEGY_NESTED_NWAVE_NECKLINE_BREAK`
- Task: validate whether the prior failure decomposition supports safe v2 gate candidates.
- Scope: diagnostic analysis only. No EA logic, order bridge, SL/TP, RewardR, timeframe, spread guard, risk sizing, CTrade bridge, or parameters were changed.

## Added

- Script:
  - `scripts/analyze_nested_nwave_gate_safety.py`
- Reports:
  - `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_gate_safety_summary.md`
  - `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_gate_safety_matrix.csv`
  - `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_directional_close_strength.csv`
  - `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_retest_quality.csv`
  - `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_true_clean_candidate_v0.csv`
- Updated:
  - `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_v2_gate_candidates.md`

## Verification

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_gate_safety_compile.log`
- Compile result: `0 errors, 0 warnings`
- No annual backtests were run.
- No EA code was changed.

## Findings

- `breakout_close_strength` was already direction-normalized.
  - LONG scores high when the close is near the bar high.
  - SHORT scores high when the close is near the bar low.
- The fixed `breakout_close_strength_directional >= 0.60` gate is not safe in this sample.
  - It removed all 2025-10 winning Nested trades.
- The prior 2026-Q1 diagnosis still holds: failure is mainly M15 neckline quality and false-break behavior.
- A simple false-break hindsight exclusion had the best diagnostic effect, but it is not live-safe.
- `true_clean_candidate_v0` produced no candidates with the strict proposed conditions, confirming that the current clean label is too loose and that the proposed hard gates are too restrictive as-is.

## Decision

Do not start Nested v2 with a hard close-strength gate. If Nested v2 is attempted, it should be a small retest-confirmation diagnostic branch rather than another same-bar neckline-break entry with static quality filters.

RewardR, SL, and timeframe tuning remain secondary until neckline/retest quality is solved.
