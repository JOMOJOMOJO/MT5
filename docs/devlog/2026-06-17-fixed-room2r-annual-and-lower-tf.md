# 2026-06-17 - Fixed Room2R Annual And Lower TF Check

## Summary

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Task: run annual BT for `RESEARCH_STRATEGY_NESTED_FIXED_ROOM2R`, then run a lower timeframe comparison if annual trade count is below 100 per year.
- H4-H1-M15 annual BT periods:
  - `2024-01-01` to `2024-12-31`
  - `2025-01-01` to `2025-12-31`
  - `2026-01-01` to `2026-06-17`
- Lower timeframe comparison:
  - `RESEARCH_STRATEGY_NESTED_FIXED_ROOM2R_LOWER_TF`
  - H1 bias, M15 pullback, M5 BOS trigger

## Constraints

- No Friday stop.
- No symbol exclusion.
- No direction-only mode.
- No RewardR, SL/TP, risk, CTrade, spread guard, or optimization changes.
- Lower TF branch changes only the timeframe stack and keeps the fixed Room2R idea.

## Verification

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_annual_compile.log`
- Compile result: `0 errors, 0 warnings`

## Evidence

- Annual summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_annual_summary.md`
- Annual comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_annual_comparison.csv`
- Annual by year: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_annual_by_year.csv`
- Annual trades: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_annual_trades.csv`
- Lower TF summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_lower_tf_summary.md`
- Lower TF comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_lower_tf_comparison.csv`
- TF comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_tf_comparison.md`

## Result

H4-H1-M15:

- Trades: `120`
- PF: `0.904`
- Avg R: `-0.052`
- Net: `-382.18`
- Max DD: `555.06` / `5.47%`
- FX net: `224.06`
- XAUUSD net: `-606.24`
- LONG net: `-563.31`
- SHORT net: `181.13`
- By-year trades: `2024:45`, `2025:46`, `2026:29`

H1-M15-M5:

- Trades: `199`
- PF: `0.936`
- Avg R: `-0.034`
- Net: `-426.8`
- Max DD: `1021.18` / `9.8%`
- FX net: `-124.77`
- XAUUSD net: `-302.03`
- LONG net: `-244.79`
- SHORT net: `-182.01`

## Decision

- `Nested_Fixed_Room2R` did not hold up in annual BT.
- H4-H1-M15 was not a live or next-phase candidate: PF stayed below `1.0`, avg_R was negative, and LONG/XAUUSD dragged the result.
- H1-M15-M5 increased trades from `120` to `199`, but did not improve expectancy. It also worsened max DD and made FX net negative.
- The short-window `room_to_2r` edge was not robust enough as a standalone annual gate.
- Next research should not promote fixed Room2R. The useful lesson is that room-to-target is a diagnostic feature, not a complete entry model.
