# 2026-06-04 - Regime-Aware ThirdWave

## Summary

- Added `RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_REGIME` as a separate ThirdWave branch.
- Added a simple higher-timeframe regime classifier using HH/HL or LL/LH, EMA slope, trend strength, ATR ratio, and range width.
- Regime branch permits long entries only in trend-up regimes and short entries only in trend-down regimes.
- Strengthened lower-timeframe reversal confirmation only for the regime branch.
- Preserved the existing Phase 2 score scanner and original ThirdWave branch.
- Ran original/regime comparisons for 2024, 2025, and 2026YTD.

## Evidence

- Summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_summary.md`
- Run comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_run_comparison.csv`
- By regime: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_by_regime.csv`
- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_compile.txt`
