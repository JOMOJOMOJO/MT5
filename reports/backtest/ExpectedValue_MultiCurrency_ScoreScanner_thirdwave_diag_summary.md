# ThirdWave Diagnostics Improved Summary

## Scope

- Diagnostic-only change for the separate DowFractal ThirdWave branch.
- No optimization was performed.
- `InpRewardR`, `InpMaxSpreadATR`, timeframe inputs, SL/TP logic, CTrade bridge, and existing Phase 2 score scanner logic were not changed.
- Spread guard is now recorded separately from structure-stage failures.
- Signal detail rows are limited to lower-reversal-or-later candidates and execution-block candidates; earlier stage failures remain available through summary counters.

## Run Results

| period | scenario | trades | net_profit | profit_factor | expected_payoff | max_balance_dd_pct | long_net_profit | short_net_profit | xauusd_trade_share_pct | usdjpy_short_net_profit | top_structure_stage_fail_reason | top_execution_block_reason |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2025 | ThirdWave_BOTH | 451 | -464.41 | 0.963 | -1.03 | 17.62 | -1051.26 | 586.85 | 79.16 | 206.22 | no_higher_tf_trend | spread_guard |
| 2025 | ThirdWave_LONG_ONLY | 271 | -1364.56 | 0.821 | -5.04 | 18.44 | -1364.56 | 0 | 82.66 | 0 | no_higher_tf_trend | spread_guard |
| 2025 | ThirdWave_SHORT_ONLY | 208 | 246.7 | 1.043 | 1.19 | 11.82 | 0 | 246.7 | 72.6 | -59.17 | no_higher_tf_trend | spread_guard |
| 2024 | ThirdWave_BOTH | 355 | -914.04 | 0.911 | -2.57 | 15.97 | -501.32 | -412.72 | 74.65 | 266.88 | no_higher_tf_trend | spread_guard |
| 2024 | ThirdWave_LONG_ONLY | 201 | -134.0 | 0.977 | -0.67 | 9.21 | -134.0 | 0 | 77.61 | 0 | no_higher_tf_trend | spread_guard |
| 2024 | ThirdWave_SHORT_ONLY | 172 | -298.73 | 0.94 | -1.74 | 8.79 | 0 | -298.73 | 68.6 | 492.15 | no_higher_tf_trend | spread_guard |
| 2026YTD | ThirdWave_BOTH | 188 | 962.24 | 1.194 | 5.12 | 6.89 | 177.27 | 784.97 | 90.96 | -3.15 | no_higher_tf_trend | spread_guard |
| 2026YTD | ThirdWave_LONG_ONLY | 95 | 148.69 | 1.059 | 1.57 | 6.9 | 148.69 | 0 | 94.74 | 0 | no_higher_tf_trend | spread_guard |
| 2026YTD | ThirdWave_SHORT_ONLY | 100 | 783.85 | 1.304 | 7.84 | 5.19 | 0 | 783.85 | 87.0 | -3.15 | no_higher_tf_trend | spread_guard |

## 2025 Stage Breakdown

| scenario | direction | evaluations | higher_tf_trend_pass | mid_tf_pullback_pass | lower_tf_reversal_pass | structure_sl_pass | rr_pass | spread_guard_blocked | final_entry_pass | final_entry_rate_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ThirdWave_LONG_ONLY | LONG | 515536 | 144075 | 85451 | 11703 | 2716 | 2716 | 415672 | 748 | 0.1451 |
| ThirdWave_LONG_ONLY | SHORT | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0.0 |
| ThirdWave_SHORT_ONLY | LONG | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0.0 |
| ThirdWave_SHORT_ONLY | SHORT | 515536 | 120227 | 73599 | 8896 | 3025 | 3025 | 415672 | 592 | 0.1148 |

## Artifacts

- Run comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_diag_run_comparison.csv`
- 2025 stage breakdown: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_diag_2025_stage_breakdown.csv`
- OOS summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_diag_oos_summary.md`
- By spread/ATR band: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_diag_2025_by_spread_atr_band.csv`
- By SL/ATR band: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_diag_2025_by_sl_atr_band.csv`
- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_diagnostics_compile.txt`
