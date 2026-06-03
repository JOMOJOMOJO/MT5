# ThirdWave OOS Diagnostics Summary

The OOS runs reuse the same ThirdWave diagnostics settings without parameter optimization.

| period | scenario | trades | net_profit | profit_factor | expected_payoff | max_balance_dd_pct | long_net_profit | short_net_profit | xauusd_net_profit | usdjpy_short_net_profit | major_winning_symbols | major_losing_symbols |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2024 | ThirdWave_BOTH | 355 | -914.04 | 0.911 | -2.57 | 15.97 | -501.32 | -412.72 | -1000.83 | 266.88 | GBPJPY:500.64; USDJPY:355.73 | XAUUSD:-1000.83; GBPUSD:-301.61; EURJPY:-282.47 |
| 2024 | ThirdWave_LONG_ONLY | 201 | -134.0 | 0.977 | -0.67 | 9.21 | -134.0 | 0 | -134.76 | 0 | GBPJPY:160.93; USDJPY:160.81 | GBPUSD:-204.59; XAUUSD:-134.76; EURJPY:-116.39 |
| 2024 | ThirdWave_SHORT_ONLY | 172 | -298.73 | 0.94 | -1.74 | 8.79 | 0 | -298.73 | -677.4 | 492.15 | USDJPY:492.15; GBPJPY:318.31 | XAUUSD:-677.40; GBPUSD:-149.63; AUDJPY:-135.58 |
| 2026YTD | ThirdWave_BOTH | 188 | 962.24 | 1.194 | 5.12 | 6.89 | 177.27 | 784.97 | 1058.68 | -3.15 | XAUUSD:1058.68; EURUSD:135.14 | USDJPY:-103.85; GBPUSD:-74.23; GBPJPY:-53.50 |
| 2026YTD | ThirdWave_LONG_ONLY | 95 | 148.69 | 1.059 | 1.57 | 6.9 | 148.69 | 0 | 401.37 | 0 | XAUUSD:401.37 | USDJPY:-149.39; EURUSD:-52.87; GBPJPY:-50.42 |
| 2026YTD | ThirdWave_SHORT_ONLY | 100 | 783.85 | 1.304 | 7.84 | 5.19 | 0 | 783.85 | 672.41 | -3.15 | XAUUSD:672.41; EURUSD:188.82 | GBPUSD:-74.23; USDJPY:-3.15 |

- CSV: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_diag_oos_run_comparison.csv`
