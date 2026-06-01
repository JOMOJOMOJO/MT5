# ExpectedValue LongOnly BucketLab Final Check Results

Date: 2026-05-23

This phase was a shallow direction check before archiving the research. It was not an optimization pass.

## Compile

- Source: `mql/Experts/ExpectedValue_LongOnly_BucketLab.mq5`
- Compile log: `reports/compile/ExpectedValue_LongOnly_BucketLab_final_check_compile.log`
- Result: `0 errors, 0 warnings`

## Summary Table

Source CSV: `reports/backtest/runs/2026-05-23-bucketlab-final-check/final_check_variant_summary.csv`

| Variant | Trades | ExpectancyR | PF | MaxDD% | Max Losses | Stops | Margin Rejects |
|---|---:|---:|---:|---:|---:|---:|---:|
| ref_v2_5 | 76 | 0.2612 | 1.9043 | 8.21 | 3 | 0 | 0 |
| mid_range_family | 76 | 0.2687 | 1.9554 | 8.12 | 3 | 0 | 0 |
| sl_m1_swing | 72 | 0.2428 | 1.7931 | 8.76 | 3 | 0 | 0 |
| sl_m5_swing | 13 | 0.0598 | 1.2338 | 3.75 | 3 | 0 | 0 |
| tp_recent_high_or_r | 76 | 0.2612 | 1.9043 | 8.21 | 3 | 0 | 0 |
| hold_long_r135 | 60 | 0.2935 | 1.8086 | 10.08 | 6 | 1 | 0 |
| second_entry_conservative | 72 | 0.2329 | 1.8010 | 8.16 | 3 | 0 | 0 |
| one_position_control | 70 | 0.2361 | 1.7890 | 8.31 | 3 | 0 | 0 |

## Theme 1: Alternative Market-State Family

Implemented a disabled-by-default research bucket:

- `MID_RANGE_CONTINUATION_LONG`
- bucket type: `MID_RANGE_CONTINUATION`
- default: off
- tested variant: `mid_range_family`

2025 result:

- trades: `76`
- ExpectancyR: `+0.2687`
- PF: `1.9554`
- MaxDD: `8.12%`
- max consecutive losses: `3`
- stop conditions: `0`

Bucket-level result:

- `MID_RANGE_CONTINUATION`: `1` trade, `-0.4634R`

Interpretation: the new family did not materially increase frequency. The whole variant improved slightly versus reference because one existing-path outcome changed, not because the new bucket provided a meaningful sample. It should remain as a research stub, not a candidate.

Continue value: low as implemented. The broader idea, mid-range continuation, remains plausible only if redesigned from bar-data mining rather than threshold tweaking.

## Theme 2: Short-Side Applicability

No short prototype was implemented.

Reason: there is already a production short-only EA. A rushed short mirror inside the long BucketLab would create unclear ownership and a high risk of mixing research code with production assumptions.

Design notes:

- Mirrorable:
  - risk guards
  - event logging
  - candidate score logging
  - fixed lot / equity threshold / risk percent sizing
  - daily, weekly, drawdown, loss-streak stops
  - no averaging and no martingale rules
- Not safely mirrorable:
  - lower-wick reclaim logic
  - range-position interpretation
  - H4 bearish avoidance, which would become H4 strong bullish avoidance for shorts
  - recent-high/recent-low distance meanings
  - pressure definitions without validating downside behavior
- Short-side buckets worth future research:
  - `RALLY_REJECT_CONTINUATION_SHORT`
  - `UPPER_RANGE_FADE_RECLAIM_SHORT`
  - `EXPANSION_PULLBACK_SHORT`
  - `FAILED_BREAKOUT_REJECT_SHORT`
- Recommended structure:
  - separate short BucketLab EA first
  - only integrate long/short after both sides have fixed candidates with independent OOS evidence

Continue value: medium, but not inside this final check.

## Theme 3: SL/TP Comparison

Reference:

- `HYBRID SL + FIXED_R TP`: `76` trades, `+0.2612R`, PF `1.9043`, MaxDD `8.21%`

Comparisons:

- `M1 swing SL + FIXED_R TP`: `72` trades, `+0.2428R`, PF `1.7931`, MaxDD `8.76%`
- `M5 swing SL + FIXED_R TP`: `13` trades, `+0.0598R`, PF `1.2338`, MaxDD `3.75%`
- `HYBRID SL + RECENT_HIGH_OR_R TP`: identical to reference in this sample

Interpretation:

- HYBRID remains the best default for this family.
- M1 swing is usable but slightly weaker.
- M5 swing suppresses trades too aggressively and creates too many TIMEOUT outcomes.
- `RECENT_HIGH_OR_R` did not materially change exits in this setup.

Continue value: keep HYBRID/FIXED_R as reference. Do not spend more time on M5 swing for this family.

## Theme 4: M5/M15-Leaning Hold

Variant:

- `MaxHoldBars=45`
- `TargetRMultiple=1.35`
- `CooldownBars=6`

2025 result:

- trades: `60`
- ExpectancyR: `+0.2935`
- PF: `1.8086`
- MaxDD: `10.08%`
- max consecutive losses: `6`
- stop condition events: `1`

Interpretation: longer hold improves R per trade but reduces frequency and introduces loss-streak stress. It is not a production candidate, but it suggests a separate longer-hold family may be worth researching from a clean design.

Continue value: medium as a new family, not as a tweak to the current scalper.

## Theme 5: Second-Entry Throttle

Reference v2.5 already uses `MaxOpenPositions=2` with second-entry quality gates.

Comparison:

- `ref_v2_5`: `76` trades, `+0.2612R`, PF `1.9043`, MaxDD `8.21%`, stops `0`
- `second_entry_conservative`: `72` trades, `+0.2329R`, PF `1.8010`, MaxDD `8.16%`, stops `0`
- `one_position_control`: `70` trades, `+0.2361R`, PF `1.7890`, MaxDD `8.31%`, stops `0`

Interpretation: stricter second-entry gates reduce trades and expectancy. The current v2.5 second-entry throttle is already a reasonable research compromise. Earlier raw two-position research increased trade count but created loss-streak stops; v2.5 fixed that without requiring a stricter gate.

Continue value: low. Keep current second-entry gate if this family is reused.

## OOS Decision

No final-check variant qualified for a fresh 2026 Jan-Apr OOS run.

Reason: no variant solved the main weakness identified earlier: the current family can look good in 2025 while almost disappearing in 2026 Jan-Apr. Running OOS again would risk turning OOS into a tuning loop.

## Files Produced

- `final_check_plan.md`
- `final_check_variant_summary.csv`
- `bucket_analysis.csv`
- `exit_reason_analysis.csv`
- `entry_layer_counts.csv`
- `entry_block_analysis.csv`
- `run_final_check_variants.ps1`

