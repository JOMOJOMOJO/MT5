# Nested N-Wave v2 Gate Candidates

These are fixed diagnostic candidates, not optimized parameters. They are derived from the four short-period Nested runs and especially the 2026-Q1 failure sample.

## 2026-Q1 Failure Evidence

Failure types:
- `false_breakout`: 30
- `target_too_far`: 10
- `late_breakout`: 3
- `no_follow_through`: 2

Failure layers:
- `M15_neckline_quality_problem`: 32
- `SL_TP_design_problem`: 10
- `entry_timing_problem`: 3

## Candidate Gates

1. **Breakout Close Strength Gate**
   - Minimum close-position strength on the breakout proxy bar.
   - Rationale: the current neckline check accepts weak closes that often return inside the neckline.
   - Minimal test: require `breakout_close_strength >= 0.60` as a single fixed rule.

2. **False-Break Guard**
   - Reject candidates where the next few M5 bars close back inside the neckline in diagnostic replay.
   - This cannot be known at entry without waiting, so the live version would need a retest-confirmation variant rather than a hindsight filter.
   - Minimal test: build a delayed-entry retest-confirmation branch, not a direct hindsight gate.

3. **Entry Distance From Neckline Cap**
   - Avoid entries already too far from the neckline.
   - Rationale: late breakouts have poor reward path and often fail before meaningful MFE.
   - Minimal test: fixed cap around `entry_close_distance_from_neckline_atr <= 0.40`.

4. **H4 Pullback Mid-Zone Preference**
   - Prefer mid-zone H4 pullbacks over edge-of-zone 38-42 or 58-62 cases.
   - Rationale: edge-zone samples were more often context-problem or poor follow-through candidates.
   - Minimal test: compare `42-58` zone against the full `38.2-61.8` zone without changing other logic.

5. **Max SL ATR Gate**
   - Block candidates with wide structure risk.
   - Rationale: wide SL cases require too much follow-through for the fixed 2R target.
   - Minimal test: fixed `sl_atr < 2.0` diagnostic branch.

## Recommendation

A v2 is worth a small diagnostic branch only if it starts with breakout-quality gates, not RewardR/SL tuning. The first implementation should combine no more than two rules: close strength and entry distance from neckline. If that only reduces trades without improving 2025-02 and 2026-Q1, park Nested and move to another pattern definition.
