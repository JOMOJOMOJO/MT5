# 2026-06-16 - Nested N-Wave Research Cleanup

## Summary

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Task: review and clean research-only Nested N-Wave branches that had drifted toward short-window threshold fitting, symbol/direction escapes, or operational time filters.
- Goal: return the active research direction toward universal fractal structure, N-wave, and Dow-theory logic.

## Code Changes

- Removed the late-Friday Nested entry guard from strategy logic.
- Removed `weekend_entry_guard` from Nested failure accounting.
- Kept `RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER_V3` only as a deprecated compatibility alias to V2.
- Added code comments marking `SYMBOL_RESEARCH_XAUUSD_ONLY`, `SYMBOL_RESEARCH_FX_ONLY`, and `InpDisableUsdJpyShort` as research-only diagnostics.
- Added `scan_driver_symbol` to scan diagnostics so multi-currency scans can identify the chart symbol driving the new-bar clock.

## Research Decision

- Nested Neckline Break, Retest Confirmation, Breakout Quality Router, Context Quality Router, V2, and V3 remain useful research artifacts.
- They are not promotion candidates.
- Context Router and the old Friday guard are risk controls/diagnostics, not a demonstrated structural edge.
- Further M15 threshold tuning is not justified.
- The next mainline candidate should be `RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS`, where H1 countertrend structure invalidation is the trigger and M15 only confirms the BOS.

## Evidence

- Code review: `docs/research/nested_nwave_code_review.md`
- Cleanup decision: `docs/research/nested_nwave_research_cleanup_decision.md`
- Structural BOS seed: `docs/research/nested_nwave_structural_bos_design_seed.md`
- Previous closure context: `docs/research/thirdwave_research_closure.md`
- Previous Nested seed: `docs/research/nested_nwave_neckline_break_design_seed.md`
- RR 1.2 short evidence: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_context_router_r12_summary.md`
- RR 1.2 annual evidence: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_context_router_r12_annual_summary.md`

## Verification

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_nested_cleanup_compile.log`
- Compile result: `0 errors, 0 warnings`
- Backtest: not run. This task intentionally changed classification and removed a non-structural time filter; it did not introduce a new strategy edge or threshold to validate.
