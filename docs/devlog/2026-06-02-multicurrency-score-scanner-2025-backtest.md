# 2026-06-02 - Multi-Currency Score Scanner 2025 Backtest

## Summary

- task: run a non-optimized MT5 Strategy Tester backtest for `ExpectedValue_MultiCurrency_ScoreScanner`
- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- mode: `InpEnableTrading=true`, using the real `CTrade` execution bridge
- period: `2025.01.01` to `2025.12.31`
- result: completed with `0` order-send errors, but failed validation on expectancy and drawdown

## Evidence

- summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_summary.md`
- MT5 report: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_report.html`
- trades: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_trades.csv`
- scores: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_scores.csv`
- config: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025.ini`
- preset: `reports/presets/ExpectedValue_MultiCurrency_ScoreScanner_2025.set`
- compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner.log`

## Result

- total trades: `225`
- net profit: `-500.21 USD`
- profit factor: `0.93`
- expected payoff: `-2.22`
- max drawdown: `1,088.88 USD (10.28%)`
- first `max_drawdown_stop`: `2025.02.25 03:29:59`

## Decision

Do not promote this version toward demo or live. The execution bridge worked, but the current score model selected too many weak trades before the max drawdown guard stopped entries. No optimization or logic changes were made during this validation run.
