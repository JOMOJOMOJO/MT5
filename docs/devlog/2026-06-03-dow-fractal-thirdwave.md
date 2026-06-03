# 2026-06-03 - DowFractal ThirdWave Branch

## Summary

- Added `RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE` as a separate branch inside `ExpectedValue_MultiCurrency_ScoreScanner.mq5`.
- Kept the Phase 2 score scanner and Dow/fractal structure filter intact.
- Ran 2025 initial checks for BOTH, LONG_ONLY, and SHORT_ONLY.
- Compile result: 0 errors / 0 warnings.

## Results

| scenario | trades | net_profit | profit_factor | expected_payoff | max_balance_dd_pct | long_net_profit | short_net_profit |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ThirdWave_BOTH | 451 | -464.41 | 0.963 | -1.03 | 17.62 | -1051.26 | 586.85 |
| ThirdWave_LONG_ONLY | 271 | -1364.56 | 0.821 | -5.04 | 18.44 | -1364.56 | 0 |
| ThirdWave_SHORT_ONLY | 208 | 246.7 | 1.043 | 1.19 | 11.82 | 0 | 246.7 |

## Evidence

- Summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_thirdwave_summary.md`
- Run comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_thirdwave_run_comparison.csv`
- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_compile.txt`
