# ThirdWave Scan Interval And Entry Selection Summary

## Scope

- Added `InpEntrySelectionMode` with `BEST_ONLY` and research-only `ALL_SCORE_PASSING`.
- Added `InpDiagnosticsLevel`; these runs use `DIAG_ENTRY_ONLY` to keep scan diagnostics, entry candidates, execution blocks, order results, and summary counters while suppressing early-fail raw rows.
- Existing Phase 2 score scanner, original ThirdWave, regime ThirdWave rules, risk sizing, SL/TP, and CTrade bridge were not optimized or replaced.
- Primary comparison is 2025. OOS rows are included only when the corresponding reports exist.

## 2025 Results

| scenario | trades | net_profit | profit_factor | expected_payoff | max_balance_dd_pct | elapsed_seconds | avg_scan_elapsed_ms | diagnostic_csv_kb | xauusd_trade_share_pct | fx_net_profit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ThirdWave_regime_BOTH_best_5m | 247 | -567.02 | 0.92 | -2.3 | 11.74 | 639.7 | 0.3 | 6041.06 | 77.73 | -482.0 |
| ThirdWave_regime_BOTH_best_10m | 193 | -708.42 | 0.874 | -3.67 | 11.82 | 339.0 | 0.43 | 3061.21 | 82.38 | -809.87 |
| ThirdWave_regime_BOTH_best_15m | 142 | -220.24 | 0.946 | -1.55 | 6.27 | 238.4 | 0.54 | 2025.31 | 77.46 | -356.54 |
| ThirdWave_regime_BOTH_all_5m | 269 | -431.98 | 0.944 | -1.61 | 11.11 | 639.6 | 0.3 | 6078.77 | 75.84 | -410.82 |
| ThirdWave_regime_BOTH_all_10m | 202 | -762.63 | 0.87 | -3.78 | 12.33 | 339.0 | 0.42 | 3085.25 | 80.2 | -865.72 |
| ThirdWave_regime_BOTH_all_15m | 147 | -118.91 | 0.972 | -0.81 | 5.95 | 238.2 | 0.52 | 2039.29 | 76.87 | -334.44 |

## OOS Results

| period | scenario | trades | net_profit | profit_factor | expected_payoff | max_balance_dd_pct | elapsed_seconds |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2024 | ThirdWave_regime_BOTH_best_5m | 159 | 832.41 | 1.183 | 5.24 | 4.53 | 689.2 |
| 2024 | ThirdWave_regime_BOTH_best_10m | 122 | 584.68 | 1.17 | 4.79 | 4.37 | 358.3 |
| 2024 | ThirdWave_regime_BOTH_best_15m | 92 | -265.04 | 0.903 | -2.88 | 6.59 | 247.8 |
| 2024 | ThirdWave_regime_BOTH_all_5m | 178 | 714.25 | 1.139 | 4.01 | 6.23 | 689.2 |
| 2024 | ThirdWave_regime_BOTH_all_10m | 132 | 565.82 | 1.151 | 4.29 | 5.84 | 358.4 |
| 2024 | ThirdWave_regime_BOTH_all_15m | 99 | -243.35 | 0.917 | -2.46 | 5.64 | 247.8 |
| 2026YTD | ThirdWave_regime_BOTH_best_5m | 88 | 809.15 | 1.354 | 9.19 | 2.19 | 285.4 |
| 2026YTD | ThirdWave_regime_BOTH_best_10m | 61 | 604.94 | 1.399 | 9.92 | 2.48 | 164.9 |
| 2026YTD | ThirdWave_regime_BOTH_best_15m | 43 | 40.41 | 1.035 | 0.94 | 3.56 | 124.5 |
| 2026YTD | ThirdWave_regime_BOTH_all_5m | 92 | 758.63 | 1.314 | 8.25 | 2.65 | 285.2 |
| 2026YTD | ThirdWave_regime_BOTH_all_10m | 61 | 604.94 | 1.399 | 9.92 | 2.48 | 164.9 |
| 2026YTD | ThirdWave_regime_BOTH_all_15m | 43 | 40.41 | 1.035 | 0.94 | 3.56 | 124.5 |

## Initial Judgment

- 2025 best-only did not require 5m scans in this branch: 5m PF `0.92`, 10m PF `0.874`, 15m PF `0.946`. The 15m run had the smallest loss and DD, but all three remained negative.
- 2024 does not support moving straight to 15m: best 5m PF `1.183`, best 10m PF `1.17`, best 15m PF `0.903`.
- 2026YTD keeps positive expectancy at 5m/10m but gives up most edge at 15m: best 5m net `809.15`, best 10m net `604.94`, best 15m net `40.41`.
- All-candidates mode exposed more candidates but did not reveal a broad multi-symbol edge. In 2025, all 5m improved net from `-567.02` to `-431.98`, but FX remained negative and 10m worsened.
- The useful information from all-candidates is diagnostic: 2025 `REGIME_TREND_UP` remained the main loss source at 5m/10m, while 15m reduced that damage but did not produce a robust OOS edge.
- CSV reduction is effective for structure/regime raw rows: signal diagnostics are now hundreds of rows instead of per-scan all-symbol rows. The remaining large file is scan diagnostics, kept intentionally for elapsed-ms analysis.

## Artifacts

- Run comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_scan_interval_run_comparison.csv`
- Scan interval comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_scan_interval_scan_interval_comparison.csv`
- Entry selection comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_scan_interval_entry_selection_comparison.csv`
- Log size comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_scan_interval_log_size_comparison.csv`
- Trade join: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_scan_interval_trade_join.csv`
- By symbol: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_scan_interval_by_symbol.csv`
- By direction: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_scan_interval_by_direction.csv`
- By regime: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_scan_interval_by_regime.csv`
- By session: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_scan_interval_by_session.csv`

OOS report rows were generated for 2024 and 2026YTD scan-interval runs.
