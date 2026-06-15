# 2026-06-15 - Nested N-Wave Context Quality Diagnostic

## Summary

- Compared 2025-10 removed `dirty`/`weak` winners against 2026-Q1 avoided `dirty`/`weak` losers.
- Added diagnostic-only `context_quality_v0` labels from existing Router audit columns.
- No EA behavior, routing logic, SL/TP, RewardR, timeframe, spread guard, risk calculation, or CTrade code changed.

## Evidence

- Summary: [reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_summary.md](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_summary.md)
- Candidate rows: [reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_candidate_rows.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_candidate_rows.csv)
- Comparison CSV: [reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_comparison.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_comparison.csv)
- Bucket matrix: [reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_bucket_matrix.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_bucket_matrix.csv)
- Cohort diff: [reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_cohort_diff.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_cohort_diff.csv)
- Next router notes: [reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_next_router_notes.md](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_context_quality_diagnostic_next_router_notes.md)

## Decision

Router v2 threshold tuning is still premature. The next useful EA change is to emit a Context Quality diagnostic label before routing, then validate whether that label separates 2025-10 deleted winners from 2026-Q1 avoided losers.
