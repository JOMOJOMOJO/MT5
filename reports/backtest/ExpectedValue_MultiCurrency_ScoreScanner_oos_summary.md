# Multi-Currency Score Scanner OOS Check

## Scope

- Existing Phase 2 D/E settings were reused without optimization.
- Hard-loss stops remain disabled with the same large research thresholds used in Phase 2.
- OOS windows: 2024-01-01 to 2024-12-31, and 2026-01-01 to 2026-06-02.
- No trade logic, score logic, Dow/fractal structure filter, TP/SL, CTrade bridge, or risk sizing was changed.

## 2025 Baseline

| year | scenario | trades | win_rate | net_profit | profit_factor | expected_payoff | max_balance_dd_pct | xauusd_trade_share_pct | xauusd_net_profit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2025 | LONG_ONLY_DowFractal_5m_new_bar | 675 | 44.15 | 3349.91 | 1.159 | 4.96 | 6.64 | 79.11 | 2874.71 |
| 2025 | XAUUSD_ONLY_LONG_ONLY_DowFractal_5m_new_bar | 549 | 44.44 | 2880.52 | 1.171 | 5.25 | 7.0 | 100.0 | 2880.52 |

## OOS Results

| year | scenario | trades | win_rate | net_profit | profit_factor | expected_payoff | max_balance_dd_pct | xauusd_trade_share_pct | xauusd_net_profit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2024 | LONG_ONLY_DowFractal_5m_new_bar | 510 | 38.43 | -1305.43 | 0.908 | -2.56 | 18.55 | 68.63 | -585.39 |
| 2024 | XAUUSD_ONLY_LONG_ONLY_DowFractal_5m_new_bar | 357 | 39.78 | -401.11 | 0.961 | -1.12 | 9.69 | 100.0 | -401.11 |
| 2026YTD | LONG_ONLY_DowFractal_5m_new_bar | 181 | 40.33 | 36.7 | 1.007 | 0.2 | 8.34 | 88.4 | 495.2 |
| 2026YTD | XAUUSD_ONLY_LONG_ONLY_DowFractal_5m_new_bar | 162 | 41.98 | 381.21 | 1.086 | 2.35 | 6.43 | 100.0 | 381.21 |

## Judgment

- LONG_ONLY + DowFractalStructureFilter OOS PF>1 across tested windows: no.
- XAUUSD_ONLY + LONG_ONLY + DowFractalStructureFilter OOS PF>1 across tested windows: no.
- Treat this as validation evidence only. No improvement or parameter search was performed.

## Artifacts

- Run comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_oos_run_comparison.csv`
- By symbol: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_oos_by_symbol.csv`
- By direction: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_oos_by_direction.csv`
- By month: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_oos_by_month.csv`
- By score band: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_oos_by_score_band.csv`
