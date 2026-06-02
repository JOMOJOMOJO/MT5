# 2026-06-02 - Multi-Currency Score Scanner Failure Analysis

## Summary

- task: analyze why the 2025 multi-currency score scanner backtest had negative expectancy
- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- status: research no-stop backtest completed; no strategy logic or trade bridge changes were made

## Work

- Recompiled the EA and confirmed `0 errors, 0 warnings`.
- Added a research preset that disables hard daily, weekly, and drawdown stops by setting their thresholds to `100000.00`.
- Ran a second single MT5 Strategy Tester backtest for `2025.01.01` to `2025.12.31` with the real `CTrade` bridge.
- Parsed the stop-off MT5 report into trades and joined trades to `entry_score_ok` rows from the score CSV.
- Created aggregate CSVs by symbol, direction, month, hour, score band, and score counts.

## Main Finding

The no-stop run did not recover the strategy. It produced `1,692` trades, `PF 0.984`, `Expected Payoff -0.40`, `-672.91 USD`, and `35.44%` max balance drawdown.

The first losing branch to isolate is `SHORT`, especially `USDJPY SHORT`. Full-year `LONG` was positive, while `SHORT` was materially negative.

## Evidence

- Research report: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_failure_analysis.md`
- Stop-off MT5 report: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_no_stops_report.html`
- Stop-off trades: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_no_stops_trades.csv`
- Stop-off scores: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_no_stops_scores.csv`
- Comparison CSV: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_failure_run_comparison.csv`
- Analysis script: `scripts/analyze_multicurrency_score_scanner_2025.py`

## Next

- Test branch isolation before parameter search: `LONG-only`, `SHORT-only`, `XAUUSD-only`, and `non-XAU` diagnostics.
- Treat market-closed `retcode=10018` as an execution guard issue for the next implementation phase, not as an edge fix.
