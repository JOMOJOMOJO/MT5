# 2026-06-22 - Multi-Currency Research Asset Preservation

## Summary

- Task: close the current Phase2 / ThirdWave / Nested N-Wave / Structural BOS validation cycle and preserve the results as reusable assets.
- Code changes: none.
- Backtests: none.
- Purpose: stop incremental retuning of the current family and keep the findings available for the next EA design.

## New Artifacts

- [Research closure](../research/multicurrency_score_scanner_research_closure_2026-06-22.md)
- [Reusable lessons](../../knowledge/lessons/multicurrency_structure_research_lessons_2026-06-22.md)
- [Next EA idea bank](../research/next_ea_idea_bank_from_multicurrency_research.md)

## Evidence Reviewed

- [Phase2 summary](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_summary.md)
- [ThirdWave closure](../research/thirdwave_research_closure.md)
- [Nested cleanup decision](../research/nested_nwave_research_cleanup_decision.md)
- [Structural BOS v2 summary](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_short_summary.md)
- [Condition Factorial summary](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_summary.md)
- [Fixed Condition BT summary](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_bt_summary.md)
- [Relaxed FX-only summary](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_summary.md)
- [Broad FX-only summary](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_summary.md)
- [Sweep/Reclaim/Retest summary](../../reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_summary.md)

## Decision

The current research family is parked as a preserved asset.

Do not continue by adding:

- Friday or time filters;
- symbol exclusions;
- direction-only promotion;
- more M15 candle-quality thresholds;
- RewardR or SL-only repair loops.

Next EA work should start from a new context-first structural thesis, not from another ThirdWave or Nested Router version.

## Durable Lessons

- The useful asset is the research system: multi-currency scanning, all-candidates mode, lightweight diagnostics, R-based metrics, and structured validation gates.
- The weak part was the strategy thesis implementation: lower-timeframe triggers were repeatedly used before higher-timeframe context was defined strongly enough.
- `room_to_2R` is valuable as a diagnostic and candidate selector, but it is not a complete edge.
- XAUUSD-only, LONG_ONLY, SHORT_ONLY, or specific-symbol exclusions are decomposition tools, not promotion logic.

## Next Direction

The next EA should be a new family centered on:

- H4/H1 structure first;
- M15 execution second;
- true countertrend structure invalidation;
- obstacle-aware room-to-target diagnostics;
- no symbol, direction, or weekday escape filters.

The idea bank is saved at [next EA idea bank](../research/next_ea_idea_bank_from_multicurrency_research.md).
