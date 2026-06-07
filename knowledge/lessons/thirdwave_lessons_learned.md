# ThirdWave Lessons Learned

Date: 2026-06-07

This file preserves reusable lessons from the ThirdWave / LowerTF SL research cycle. It is intended for future EA design and Codex reference, not for audience-facing publication.

## Core Lesson

The current ThirdWave family did not fail because one parameter was wrong. It failed because the implemented entry thesis did not match the intended market thesis.

The intended thesis was "enter near the beginning of wave 3." The measured behavior was "enter after structure confirmation, often after a meaningful part of the move has already happened."

## Rules To Keep

- Validate the strategy thesis with diagnostics before tuning.
- Label entry position explicitly when the strategy claims to trade a wave position.
- Track `result_R` and `avg_R`, not only net profit.
- Split results by symbol, direction, regime, session, month, and year.
- Use all-candidates mode during research to reveal discarded opportunities and hidden selection bias.
- Use lightweight diagnostics: detail rows only for final candidates, order attempts/results, and execution blocks.
- Keep early-fail detail as summary counters unless manual inspection needs a sample.
- Use shadow diagnostics before changing live SL/TP.
- Test short-period hypotheses before annual BT.
- Annual checks must include materially different market years.

## Rules To Avoid

- Do not assume a confirmed fractal reclaim/breakdown is early enough for a third-wave-initial strategy.
- Do not call a continuation/chasing model a third-wave-initial model unless the audit labels prove it.
- Do not repair a thesis mismatch with RewardR or SL tuning.
- Do not accept XAUUSD-only results as proof of a multi-currency strategy.
- Do not accept LONG_ONLY or SHORT_ONLY results as proof of a symmetrical strategy.
- Do not keep tightening filters if the trade count collapses and the thesis still fails.
- Do not let raw CSV logging become the bottleneck in research backtests.

## Reusable Components

- Multi-currency EA scaffolding.
- Direction mode and symbol research mode.
- Entry selection mode: best-only versus all score-passing candidates.
- Scan interval diagnostics.
- Structure filter counters.
- Regime classification fields.
- Wave Audit labels:
  - `third_wave_initial`
  - `third_wave_middle`
  - `late_entry`
  - `chasing_entry`
  - `invalid_structure`
  - `range_noise`
  - `unclear`
- Reversal signal taxonomy:
  - `confirmed_fractal_reclaim`
  - `early_higher_low`
  - `early_lower_high`
  - `momentum_turn`
  - `candle_reversal`
  - `micro_break`
  - `unclear`
- LowerTF versus MidTF SL comparison method.
- Shadow RewardR comparison method.
- Execution block diagnostics.

## Parking Decision

Park ThirdWave as a reference family.

Do not build ThirdWave v5 by adding another filter unless a future strategy explicitly needs it as a negative-control comparison. New work should start from a different thesis: neckline break after lower-timeframe countertrend invalidation.

## Reuse In Next Strategy

The next strategy should reuse:

- Data plumbing.
- Diagnostics.
- Validation gates.
- R-based aggregation.
- Reversal and wave-position labels.

The next strategy should not reuse as-is:

- Confirmed fractal reclaim/breakdown-only entry.
- Broad chasing-entry acceptance.
- RewardR/SL repair loop.
- Symbol/direction escape branches.

## Practical Heuristic

If the entry is meant to capture a new impulse, the diagnostic must answer:

- Which prior structure is being invalidated?
- Whose stop is likely being triggered?
- Where is the trade thesis invalidated?
- How far has price already moved from the reversal point?

If these answers are unclear, the strategy is not ready for parameter work.

