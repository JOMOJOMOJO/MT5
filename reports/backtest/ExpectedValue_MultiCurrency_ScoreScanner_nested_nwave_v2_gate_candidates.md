# Nested N-Wave v2 Gate Candidates

These are fixed diagnostic candidates, not optimized parameters. They are derived from the four short-period Nested runs, the 2026-Q1 failure decomposition, and the gate safety check.

## Confirmed Diagnostics

- `breakout_close_strength` is direction-normalized.
  - LONG: close near the high is strong.
  - SHORT: close near the low is strong.
- The previous conclusion remains valid: 2026-Q1 failure is mainly M15 neckline-quality / false-break behavior.
- 2R distance is a secondary issue, not the first thing to tune.
- `clean_nested_nwave_entry` is only a coded stage-pass label, not a human-clean breakout label.

## Candidate Gates

1. **Retest Confirmation Branch**
   - Do not implement as a hindsight false-break exclusion.
   - Test as a separate delayed-entry branch that waits for return/reclaim or no-return follow-through behavior.
   - Rationale: immediate false-break removal had the strongest diagnostic effect, but simple return-inside exclusion is not live-safe.

2. **Breakout Close Strength Score**
   - `breakout_close_strength` is direction-normalized, but the fixed `>= 0.60` gate is not safe.
   - The safety check removed all 2025-10 winners in the short sample.
   - Keep it as a diagnostic ranking feature for now, not as the first hard gate.

3. **Entry Distance From Neckline Cap**
   - Fixed candidate `entry_close_distance_from_neckline_atr <= 0.40` was not consistently safe.
   - It removed 2025-10 winners and did not fix 2025-02.
   - Keep as secondary evidence, not as a first v2 gate.

4. **H4 Pullback Mid-Zone Preference**
   - Fixed diagnostic candidate: prefer `42-58` over the full `38.2-61.8` range.
   - Evidence is not strong enough by itself; it helped some 2026-Q1 rows but also removed winners.

5. **Max SL ATR Gate**
   - Fixed diagnostic candidate: `sl_atr < 2.0`.
   - Use only after neckline quality gates. Wide SL is a cost amplifier, not the primary failure source.

## Recommended v2 Order

1. Do not promote `breakout_close_strength_directional >= 0.60` as a hard v2 gate.
2. If a v2 is built, make it a retest-confirmation diagnostic branch rather than a same-bar neckline-break branch.
3. Keep RewardR, SL, timeframe, risk, spread guard, and symbol/direction universe unchanged.
4. Run the same short-period gate first.
5. If retest confirmation does not improve 2025-02 and 2026-Q1 without erasing 2025-10, park Nested.
