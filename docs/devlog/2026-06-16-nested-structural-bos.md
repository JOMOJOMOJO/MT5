# 2026-06-16 - Nested N-Wave Structural BOS Diagnostic

## Summary

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Added research mode: `RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS`
- Purpose: test whether replacing M15 neckline-break entry with H1 countertrend N-wave structure invalidation improves the Nested N-Wave family.
- Scope: fixed-rule diagnostic only. No parameter search, no Friday stop, no symbol exclusion, no direction-only promotion.

## Implementation

- Added `Nested_NWave_StructuralBOS` as an independent nested research branch.
- Kept existing Nested, Retest, Breakout Quality Router, Context Router, ThirdWave, Phase2, risk, spread guard, CTrade, TP, and SL behavior intact.
- Structural BOS branch requires:
  - H4 impulse and correction context from the existing Nested setup.
  - H1 countertrend N-wave shape.
  - H1 countertrend structure invalidation level.
  - M15 closed BOS confirmation.
- Added diagnostics for:
  - `structural_bos_state`
  - `m15_confirmation_type`
  - `h1_bos_level`
  - H1 countertrend high/low
  - distance from BOS to entry
  - `bars_since_bos`
  - `scan_driver_symbol`

## Verification

- Compile log: [ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_compile.log](../../reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_compile.log)
- Compile result: `0 errors, 0 warnings`

## Short Backtests

Short-window diagnostics only:

- `2025-02`
- `2025-08`
- `2025-10`
- `2026-Q1`

Comparison set:

- Nested instant all-candidates
- Retest confirmation all-candidates
- Breakout Quality Router all-candidates
- Context Router V2 all-candidates
- Structural BOS all-candidates

## Result

Aggregate Structural BOS result:

- Trades: `13`
- PF: `0.367`
- avg_R: `-0.543`
- Net: `-342.94`
- FX net: `-342.94`
- XAUUSD net: `0.00`
- LONG net: `-242.76`
- SHORT net: `-100.18`

Structural BOS did not trade in `2025-08` or `2025-10`. Its losses came from `2025-02` and `2026-Q1`, mostly FX. The label split did not support the intended thesis:

- `clean_structural_bos`: `7` trades, PF `0.339`, avg_R `-0.577`, net `-197.00`
- `chasing_entry`: `4` trades, PF `0.664`, avg_R `-0.254`, net `-49.43`
- `late_entry`: `2` trades, PF `0.000`, avg_R `-1.005`, net `-96.51`

## Gate Decision

Annual BT was not run.

Reasons:

- PF/avg_R did not beat the best baseline.
- FX net was negative.
- Direction balance was weak.
- `clean_structural_bos` did not beat `chasing_entry`.

## Evidence

- Summary: [ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_short_summary.md](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_short_summary.md)
- Comparison: [ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_short_comparison.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_short_comparison.csv)
- Trade rows: [ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_trade_rows.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_trade_rows.csv)
- By label: [ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_by_label.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_by_label.csv)
- FX vs XAUUSD: [ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_fx_vs_xauusd.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_fx_vs_xauusd.csv)
- MFE/MAE/R reach: [ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_mfe_mae_r_reach.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_mfe_mae_r_reach.csv)

## Decision

`RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS` is not promoted from the short diagnostic gate. The current fixed H1-BOS definition is too restrictive in favorable windows and still loses in adverse windows. Next work should diagnose the H4/H1 swing definitions before adding another M15 or time/session filter.
