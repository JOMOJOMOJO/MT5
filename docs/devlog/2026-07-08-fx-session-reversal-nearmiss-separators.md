# FX Session Reversal Near-Miss Separator Diagnostics

## Task

`ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` の required-light M15 wave2 結果を崩さず、required-light reject の中にある near-miss winner を entry 前情報だけで分離できるか検証した。

## Code Changes

- Added `InpNearMissSeparatorMode` and `InpNearMissSeparatorCombineMask`.
- Added pre-entry separator diagnostics for:
  - M5 invalidation candle quality
  - post-break no-immediate-failure
  - retest rejection quality
  - M5 corrective exhaustion
  - M15 wave2 completion quality
  - target room
  - 75SMA / Granville context
- Added separator gate logic: active separator modes allow `m15RequiredLightPass OR separatorPass`.
- Added signal/trade CSV columns for the separator fields.
- Added run generation, batch execution, and analysis scripts for this experiment.

## Validation

- Compile: `reports/compile/metaeditor.log`
  - `Result: 0 errors, 0 warnings`
- Run root: `reports/backtest/runs/20260708_session_reversal_nearmiss_separators/`
- Batch runs:
  - Q1 quick: 14 runs completed.
  - Full 2025: 14 runs completed.
  - Best rows were regenerated using analyzer-selected `best_single=targetroom`, `best_two_mask=40`, then rerun.

## Key Results

- Baseline c10:
  - 318 trades, PF 0.59, avg_R -0.1582, net -1144.89
- Required-light:
  - 50 trades, PF 1.34, avg_R +0.1099, net +134.29
- Best separator single:
  - `targetroom`, 50 trades, PF 1.34, avg_R +0.1099
  - This did not expand beyond required-light; it reproduced the same candidate set.
- Best two mask:
  - `40` = corrective exhaustion + target room
  - 244 trades, PF 0.84, avg_R -0.0547, net -324.24
- No separator reached the 2025 shallow gate:
  - 200+ trades, PF >= 1.05, avg_R > 0, net > 0, no DD stop, no concentration dependence.

## Decision

Do not promote any near-miss separator from this cycle.

The required-light 50-trade slice remains the only quality-positive fragment, but it is below the 200-trade threshold. Expanding it with the tested pre-entry separators reintroduced losing population faster than it recovered trade count.

## Evidence

- Summary: `reports/backtest/runs/20260708_session_reversal_nearmiss_separators/summary.md`
- Comparison: `reports/backtest/runs/20260708_session_reversal_nearmiss_separators/full2025_comparison.csv`
- Separator candidates: `reports/backtest/runs/20260708_session_reversal_nearmiss_separators/separator_candidate_comparison.csv`
- Grouped trades: `reports/backtest/runs/20260708_session_reversal_nearmiss_separators/near_miss_grouped_trades.csv`
