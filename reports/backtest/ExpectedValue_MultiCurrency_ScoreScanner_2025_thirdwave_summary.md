# DowFractal ThirdWave Initial Backtest

## Scope

- Added as a separate research strategy branch via `InpResearchStrategyMode`.
- Existing score scanner and existing Dow/FractalStructureFilter logic are unchanged.
- Initial validation uses 2025 full-year runs: BOTH, LONG_ONLY, SHORT_ONLY.
- Hard-loss stops remain disabled with the same research thresholds used in Phase 2.
- No parameter optimization was performed.

## Logic

- Mode switch: `InpResearchStrategyMode=RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE`.
- Long setup: higher-timeframe HH/HL trend, mid-timeframe pullback that does not break the structural low, then closed-bar lower-timeframe minor-high reclaim.
- Short setup: higher-timeframe LL/LH trend, mid-timeframe pullback that does not break the structural high, then closed-bar lower-timeframe minor-low breakdown.
- SL: structure based, below the mid-timeframe pullback fractal low for longs and above the pullback fractal high for shorts, with spread/ATR buffer.
- TP: fixed `InpRewardR` multiple from the structure stop distance.
- Logs: `thirdwave_signal_diagnostics.csv`, `thirdwave_trade_diagnostics.csv`, and `thirdwave_summary.csv`; full non-candidate rows are summarized by counters.

## ThirdWave Results

| scenario | trades | net_profit | profit_factor | expected_payoff | max_balance_dd_pct | long_net_profit | short_net_profit | usdjpy_short_net_profit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ThirdWave_BOTH | 451 | -464.41 | 0.963 | -1.03 | 17.62 | -1051.26 | 586.85 | 206.22 |
| ThirdWave_LONG_ONLY | 271 | -1364.56 | 0.821 | -5.04 | 18.44 | -1364.56 | 0 | 0 |
| ThirdWave_SHORT_ONLY | 208 | 246.7 | 1.043 | 1.19 | 11.82 | 0 | 246.7 | -59.17 |

## Signal Diagnostics

| scenario | evaluations | setup_pass | entry_pass | orders_sent | top_skip_reason | top_skip_reason_rows |
| --- | --- | --- | --- | --- | --- | --- |
| ThirdWave_BOTH | 1031072 | 30164 | 1340 | 451 | spread_guard | 831344 |
| ThirdWave_LONG_ONLY | 515536 | 16675 | 748 | 271 | spread_guard | 415672 |
| ThirdWave_SHORT_ONLY | 515536 | 13489 | 592 | 208 | spread_guard | 415672 |

## Phase 2 Reference

| scenario | trades | net_profit | profit_factor | expected_payoff | max_balance_dd_pct |
| --- | --- | --- | --- | --- | --- |
| BOTH_5m_new_bar | 1690 | -750.91 | 0.982 | -0.44 | 36.06 |
| LONG_ONLY_5m_new_bar | 1184 | 3777.82 | 1.109 | 3.19 | 19.26 |
| SHORT_ONLY_5m_new_bar | 757 | -3428.37 | 0.817 | -4.53 | 37.3 |
| LONG_ONLY_DowFractal_5m_new_bar | 675 | 3349.91 | 1.159 | 4.96 | 6.64 |

## Artifacts

- Run comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_thirdwave_run_comparison.csv`
- By direction: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_thirdwave_by_direction.csv`
- By symbol: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_thirdwave_by_symbol.csv`
- By skip reason: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_thirdwave_by_skip_reason.csv`
- Signal diagnostics: `reports/backtest/*_thirdwave_signal_diagnostics.csv`
- Trade diagnostics: `reports/backtest/*_thirdwave_trade_diagnostics.csv`
- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_compile.txt`
