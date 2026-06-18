# 2026-06-18 - Sweep/Reclaim/Retest Entry Triggers

## Summary

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Added research mode: `RESEARCH_STRATEGY_NESTED_SWEEP_RECLAIM_RETEST`
- Purpose: replace fixed condition tinkering with alternative FX-only entry trigger families:
  - `sweep_reclaim`
  - `bos_retest`
  - `first_pullback_after_reclaim`
  - combined trigger mode

## Constraints

- 2025 full-year FX-only only: `USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD`
- No Friday stop.
- No XAUUSD-only, FX-only enum filter, pair exclusion, or direction-only promotion gate.
- No RewardR, SL/TP, risk, CTrade, spread guard, or timeframe changes.
- No parameter optimization.

## Implementation

- Added `InpNestedSweepTriggerMode` for fixed diagnostic branches:
  - `NESTED_SWEEP_TRIGGER_ALL`
  - `NESTED_SWEEP_TRIGGER_SWEEP_RECLAIM_ONLY`
  - `NESTED_SWEEP_TRIGGER_BOS_RETEST_ONLY`
  - `NESTED_SWEEP_TRIGGER_FIRST_PULLBACK_ONLY`
- Kept existing Broad/ConditionFactorial/Nested branches intact.
- Added sweep/reclaim/retest diagnostics to nested signal/trade CSV rows:
  - `trigger_type`
  - `m15_sweep_level`
  - `m15_reclaim_confirmed`
  - `m15_bos_level`
  - `m15_retest_confirmed`
  - `m15_first_pullback_confirmed`
  - `entry_delay_bars_from_bos`
  - `entry_delay_bars_from_sweep`
- Added runner support with scenario set `SweepReclaimRetest`.
- Added analyzer: `scripts/analyze_sweep_reclaim_retest_2025_fx_only.py`.

## Verification

- Compile log: [`reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_compile.log`](../../reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_compile.log)
- Compile result: `0 errors, 0 warnings`
- Backtest scope: 2025.01.01 to 2025.12.31, FX-only symbols, BOTH directions.

## Evidence

- Summary: [`reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_summary.md`](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_summary.md)
- Comparison: [`reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_comparison.csv`](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_comparison.csv)
- Trades: [`reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_trades.csv`](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_trades.csv)
- By trigger: [`reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_by_trigger.csv`](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_by_trigger.csv)
- By failure type: [`reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_by_failure_type.csv`](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_by_failure_type.csv)

## Result

- `C_sweep_reclaim_only`: `1815` trades, PF `0.833`, avg_R `-0.069`, net `-6672.82`.
- `D_bos_retest_only`: `1635` trades, PF `0.798`, avg_R `-0.142`, net `-6856.00`.
- `E_first_pullback_after_reclaim_only`: `2888` trades, PF `0.837`, avg_R `-0.064`, net `-8188.47`.
- `F_combined_new_triggers`: `3897` trades, PF `0.818`, avg_R `-0.041`, net `-9190.93`.
- `G_combined_new_triggers_room_to_2r`: `2586` trades, PF `0.854`, avg_R `-0.033`, net `-4846.47`.

## Decision

- No fixed-BT candidate exists under the requested criteria.
- `sweep_reclaim` is the least bad trigger and is positive as a grouped trigger inside combined mode, but the full fixed scenario remains negative and both directions are not stable enough.
- `room_to_2r` remains useful as damage reduction, not sufficient edge.
- The main failure remains structural context quality rather than a missing M15 trigger variant.
