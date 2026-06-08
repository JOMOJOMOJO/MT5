# 2026-06-08 - Nested N-Wave Retest Confirmation

## Summary

- Added an independent `RESEARCH_STRATEGY_NESTED_NWAVE_RETEST_CONFIRMATION` branch.
- Existing ThirdWave, v2/v3/v4, Phase2, score scanner, and instant Nested branch behavior were left unchanged.
- Retest confirmation waits for a post-breakout M15 retest near the neckline before entering.

## Verification

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_retest_confirmation_compile.log`
- Compile result: `0 errors, 0 warnings`
- Short-period BT only:
  - `2025-02`
  - `2025-08`
  - `2025-10`
  - `2026-Q1`
- No annual BT was run.

## Evidence

- Summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_retest_confirmation_summary.md`
- Comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_retest_confirmation_comparison.csv`
- Retest quality: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_retest_confirmation_retest_quality.csv`
- MFE/MAE: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_retest_confirmation_retest_mfe_mae.csv`
