# 2026-06-07 - ThirdWave Research Closure

## Summary

- Task: close active ThirdWave / nested third-wave / LowerTF SL research and preserve reusable lessons for the next strategy family.
- No EA code changes were made.
- No backtests were run.
- No parameters were optimized.

## Files Added

- Research closure: `docs/research/thirdwave_research_closure.md`
- Lessons: `knowledge/lessons/thirdwave_lessons_learned.md`
- Next strategy seed: `docs/research/nested_nwave_neckline_break_design_seed.md`

## Placement Decision

- `docs/research/` was created for readable strategy research closure and design-seed documents. Existing `docs/` only had `devlog/`, and the user requested a durable research report path.
- `knowledge/lessons/` was used for reusable internal lessons because the repository knowledge rules identify it as the place for recurring rules and failure-prevention guidance.
- No repo-local Codex skill was added. Adding or changing shared skills would be a workflow/governance change; preserving the lesson in `knowledge/` is sufficient for future Codex reference without changing the skill roster.

## Closure Judgement

- Current ThirdWave is not a strict third-wave-initial strategy. Wave Audit showed `third_wave_initial` was only `1 / 109` trades and `chasing_entry` was `100 / 109`.
- v2/v3/v4 did not produce a robust, multi-year, multi-symbol repair.
- LowerTF SL + 1.2R was short-period promising but failed 2024 and tied the baseline on annual PF/avg_R.
- Signal/regime quality analysis showed the failure is a compound regime/signal/pullback problem, not a simple RewardR or SL-width problem.

## Decision

- Park ThirdWave as a research asset and negative-control family.
- Do not continue with ThirdWave v5 as the active path.
- Next family should be `Nested N-Wave Neckline Break`, focused on lower-timeframe countertrend invalidation and neckline breaks rather than predicting wave 3 directly.

## Evidence Links

- Phase2 summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_summary.md`
- Wave Audit: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_summary.md`
- v2 summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v2_short_period_summary.md`
- v3 summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v3_short_period_summary.md`
- v4 summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v4_short_period_summary.md`
- Signal shadow: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v4_signal_shadow_short_period_summary.md`
- LowerTF SL annual: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_lower_tf_sl_feasibility_annual_summary.md`
- Signal/regime quality: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_signal_regime_quality_v2_summary.md`
