# 2026-06-03 - Multi-Currency Score Scanner OOS Check

## Summary

- Checked Phase 2 D/E branches out of sample without optimization.
- Windows: 2024 full year and 2026 YTD through 2026-06-02.
- Conditions match Phase 2 research runs: M5 new-bar scan, CTrade bridge, existing TP/SL, existing risk sizing, hard stops disabled.

## Results

| year | scenario | trades | net_profit | profit_factor | expected_payoff | max_balance_dd_pct | major_winning_symbols | major_losing_symbols |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2024 | LONG_ONLY_DowFractal_5m_new_bar | 510 | -1305.43 | 0.908 | -2.56 | 18.55 | EURJPY:310.35; GBPJPY:296.60 | USDJPY:-735.63; XAUUSD:-585.39; GBPUSD:-339.37 |
| 2024 | XAUUSD_ONLY_LONG_ONLY_DowFractal_5m_new_bar | 357 | -401.11 | 0.961 | -1.12 | 9.69 |  | XAUUSD:-401.11 |
| 2026YTD | LONG_ONLY_DowFractal_5m_new_bar | 181 | 36.7 | 1.007 | 0.2 | 8.34 | XAUUSD:495.20 | USDJPY:-193.77; EURUSD:-177.83; AUDJPY:-59.48 |
| 2026YTD | XAUUSD_ONLY_LONG_ONLY_DowFractal_5m_new_bar | 162 | 381.21 | 1.086 | 2.35 | 6.43 | XAUUSD:381.21 |  |

## Evidence

- Summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_oos_summary.md`
- Run comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_oos_run_comparison.csv`
