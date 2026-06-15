# 2026-06-15 - Nested N-Wave Router Decision Audit

## Summary

- Audited the existing Breakout Quality Router decisions without changing EA behavior.
- Replayed skipped or blocked Router candidates using logged `entry_price`, `sl`, and `tp`.
- Focused on whether `dirty_breakout`, `weak_breakout`, and blocked `strong_breakout` decisions actually removed bad trades.
- Preserved the next design direction as Breakout Quality plus Context Quality rather than Router v2 threshold tuning.

## What Did Not Change

- No EA source changes.
- No order bridge, SL/TP, RewardR, timeframe, spread guard, risk calculation, or CTrade changes.
- No new backtest run and no annual validation.

## Evidence

- Summary: [reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_summary.md](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_summary.md)
- Audit CSV: [reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit.csv)
- By decision: [reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_by_decision.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_by_decision.csv)
- 2025-10 removed winners: [reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_2025_10_removed_winners.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_2025_10_removed_winners.csv)
- 2026-Q1 avoided losers: [reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_2026_q1_avoided_losers.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_2026_q1_avoided_losers.csv)
- Context quality seed: [reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_context_quality_seed.md](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_router_decision_audit_context_quality_seed.md)

## Decision

Do not tune Router thresholds yet. The next useful implementation should be a diagnostic Context Quality layer that separates strong-but-overextended breakouts, weak-but-structurally-clean breakouts, and genuinely dirty breakouts.
