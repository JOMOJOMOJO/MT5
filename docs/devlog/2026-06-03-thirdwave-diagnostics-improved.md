# 2026-06-03 - ThirdWave Diagnostics Improved

## Summary

- Split ThirdWave structure-stage failure diagnostics from final execution-block diagnostics.
- Added spread/ATR, max spread/ATR, spread pass/block flags, spread points, and ATR value to ThirdWave signal/trade diagnostics.
- Added stage pass counters for higher-timeframe trend, mid-timeframe pullback, lower-timeframe reversal, structure SL, RR, spread guard, and final entry, split by direction.
- Kept signal diagnostics at candidate level by logging lower-reversal-or-later rows plus execution-block rows; early-stage failures are summary counters.
- Ran 2025 diagnostics plus 2024 and 2026YTD OOS checks for BOTH, LONG_ONLY, and SHORT_ONLY.
- Compile result: 0 errors / 0 warnings.

## Evidence

- Summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_diag_summary.md`
- OOS summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_diag_oos_summary.md`
- Run comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_diag_run_comparison.csv`
- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_diagnostics_compile.txt`
