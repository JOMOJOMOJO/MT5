# 2026-06-17 - Fixed Condition BT Validation

## Summary

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Task: convert promising Condition Factorial post-processing subsets into fixed MT5 research modes and validate them on the short four-period window.
- Scope: short BT only. Annual BT was not run.
- Constraints held: no Friday stop, no symbol exclusion, no direction-only escape, no RewardR/SL/TP/risk/spread/timeframe changes.

## Implementation

Added fixed research modes:

- `RESEARCH_STRATEGY_NESTED_FIXED_ROOM2R`
- `RESEARCH_STRATEGY_NESTED_FIXED_H4MA_ROOM2R`
- `RESEARCH_STRATEGY_NESTED_FIXED_H4MA_M15CLOSE_ROOM2R`
- `RESEARCH_STRATEGY_NESTED_FIXED_H4FIB_ROOM2R`
- `RESEARCH_STRATEGY_NESTED_FIXED_H4MA_H4FIB_M15CLOSE_ROOM2R`

Each mode starts from the Condition Factorial broad candidate family and applies one fixed condition set inside MT5 execution, instead of selecting trades later in Python.

## Verification

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_compile.log`
- Compile result: `0 errors, 0 warnings`
- Periods tested:
  - `2025-02`
  - `2025-08`
  - `2025-10`
  - `2026-Q1`
- Annual BT: not run.

## Evidence

- Summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_bt_summary.md`
- Comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_bt_comparison.csv`
- Trades: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_bt_trades.csv`
- Fractal audit: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_bt_fractal_audit.csv`
- By period: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_bt_by_period.csv`
- By symbol: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_bt_by_symbol.csv`
- By direction: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_bt_by_direction.csv`
- Analyzer: `scripts/analyze_fixed_condition_bt.py`

## Result

- Broad ConditionFactorial candidates: `47` trades, PF `1.171`, avg_R `0.137`, net `239.56`.
- Fixed `Room2R`: `24` trades, PF `1.625`, avg_R `0.37`, net `403.59`.
- Fixed `H4MA + Room2R`: `15` trades, PF `2.184`, avg_R `0.598`, net `412.59`, but below the 20-trade short-gate minimum.
- Fixed `H4MA + M15Close + Room2R`: `3` trades, avg_R `2.006`, net `295.86`, diagnostic only due to sparse count.
- Fixed `H4MA + H4Fib + M15Close + Room2R`: `0` trades.

## Decision

- Python post-processing and MT5 fixed execution aligned for `cond_room_to_2r`.
- `Room2R` is the only fixed set that passes the short candidate gate for next annual validation.
- It is not yet a universal hard gate: SHORT net and XAUUSD net still carry much of the result, while LONG remains weak.
- The next valid step is annual BT for `RESEARCH_STRATEGY_NESTED_FIXED_ROOM2R`, not tighter condition stacking.
