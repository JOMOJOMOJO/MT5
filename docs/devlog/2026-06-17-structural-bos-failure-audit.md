# 2026-06-17 - Structural BOS Failure Audit

## Summary

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Strategy reviewed: `RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS`
- Purpose: explain why the Structural BOS short-period diagnostic failed before designing a v2 branch.
- Scope: diagnostics only. No EA order logic, SL/TP, RewardR, risk, CTrade, spread guard, timeframe, symbol filter, direction filter, or annual BT changes.

## Inputs

The audit reads existing Structural BOS short-window artifacts for:

- `2025-02`
- `2025-08`
- `2025-10`
- `2026-Q1`

The analyzer also uses MT5 M15 rates to estimate time-to-R and SL reach where possible.

## Verification

- Compile log: [ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_failure_audit_compile.log](../../reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_failure_audit_compile.log)
- Compile result: `0 errors, 0 warnings`
- Code behavior changed: `No`
- Annual BT run: `No`

## Findings

- Structural BOS aggregate remained weak: `13` trades, `PF 0.367`, expected payoff `-26.38`, net `-342.94`.
- `2025-08` and `2025-10` had zero orders because most evaluations died before a usable H4/H1 setup. `no_h4_nwave` dominated both windows.
- `2025-10` had only three final blocked candidates, all blocked by spread guard after structural checks.
- `clean_structural_bos` was not genuinely clean. It produced `7` trades, `PF 0.339`, net `-197.00`; the label means close to BOS, not necessarily valid H4/H1 N-wave context.
- `chasing_entry` was also negative, but less bad than clean in the observed sample: `4` trades, `PF 0.664`, net `-49.43`.
- H1 BOS level audit split into `8` mechanically valid and `5` too-old levels. The current logs do not prove that the BOS level is a true H1 countertrend invalidation line.
- Pivot sequence audit shows the branch is still too close to latest-pivot comparison. It does not yet prove a full H4/H1 nested N-wave.

## Decision

Do not build another M15 confirmation or threshold branch yet. The next useful v2 work should first improve H4/H1 structure definition and logging:

- full H4/H1 pivot sequence,
- minimum wave size,
- countertrend N-wave depth and freshness,
- true invalidation line selection,
- room-to-target or next-obstacle diagnostics.

## Evidence

- Summary: [ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_failure_audit_summary.md](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_failure_audit_summary.md)
- By reason: [ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_failure_audit_by_reason.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_failure_audit_by_reason.csv)
- By label: [ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_failure_audit_by_label.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_failure_audit_by_label.csv)
- H1 BOS audit: [ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_h1_bos_level_audit.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_h1_bos_level_audit.csv)
- Pivot sequence audit: [ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_pivot_sequence_audit.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_pivot_sequence_audit.csv)
- Entry timing audit: [ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_entry_timing_audit.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_entry_timing_audit.csv)
- Rejection counter: [ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_rejection_counter.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_rejection_counter.csv)
- Clean losers sample: [ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_clean_losers_sample.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_clean_losers_sample.csv)
- 2025-10 no-trade sample: [ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_2025_10_no_trade_sample.csv](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_2025_10_no_trade_sample.csv)
