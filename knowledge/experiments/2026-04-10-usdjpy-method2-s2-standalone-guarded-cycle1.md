# USDJPY Method2 S2 Standalone Guarded Cycle 1

- Date: `2026-04-10`
- Family: `usdjpy_20260410_method2_s2_short_guarded`
- Source logic:
  - extracted from `usdjpy_20260402_golden_method`
  - `Strategy 2 sell-only breakout`
- Objective:
  - turn the surviving `USDJPY short` thesis into a clean standalone EA,
  - keep the executable `exec22-tight` behavior,
  - add minimal live-safety guards before any coexistence work with Method 1

## Implementation

- New standalone EA:
  - `mql/Experts/usdjpy_20260410_method2_s2_short_guarded.mq5`
- Core thesis:
  - `USDJPY / M5`
  - bearish `EMA13 / EMA100` context plus Dow-style `LH/LL`
  - round-number downside breakout
  - short entry only after `EMA13` retest and bearish reclaim under the round level
- Default guarded controls:
  - per-trade risk `0.75%`
  - daily loss cap `3.0%`
  - equity kill switch `8.0%`
  - min-lot oversize guard `1.25%`
  - max spread `2.2 pips`
- Defaults intentionally match the previously surviving `exec22-tight` breakout-quality perimeter:
  - `min slow slope 2.5`
  - `min rejection close location 0.70`
  - `max round touches 2`
  - `breakout min body 9.0`
  - `breakout body/range 0.65`
  - `breakout vs avg body 1.70`
  - `expiry 36`
  - `target 1.2R`

## Validation

- Compile:
  - `0 errors, 0 warnings`
- Train actual MT5:
  - window: `2025-04-01` to `2025-12-31`
  - report: `reports/backtest/imported/usdjpy_20260410_method2_s2_short_guarded-train-9m-m5.htm`
  - result:
    - `net +268.16`
    - `3 trades`
    - `0 losing trades`
    - `max balance DD 0.00%`
    - `max equity DD 0.61%`
- Latest OOS actual MT5:
  - window: `2026-01-01` to `2026-04-01`
  - report: `reports/backtest/imported/usdjpy_20260410_method2_s2_short_guarded-oos-3m-m5.htm`
  - result:
    - `net +89.49`
    - `1 trade`
    - `0 losing trades`
    - `max balance DD 0.00%`
    - `max equity DD 0.19%`
- Longer actual MT5:
  - window: `2024-11-26` to `2026-04-01`
  - report: `reports/backtest/imported/usdjpy_20260410_method2_s2_short_guarded-actual-16m-m5.htm`
  - result:
    - `net +358.42`
    - `4 trades`
    - `0 losing trades`
    - `max balance DD 0.00%`
    - `max equity DD 0.61%`

## Interpretation

- The short-side thesis is not dead.
- Standalone extraction did not break the only surviving executable edge.
- The method behaves like a `quality-first secondary short branch`, not like a compounding engine:
  - quality is acceptable,
  - sample is still very thin,
  - the MT5 report prints `PF 0.00` only because there are no losing trades in the sample.

## Verdict

- Promote `usdjpy_20260410_method2_s2_short_guarded` to:
  - `serious validation`
  - `quality-first secondary short-side candidate`
  - `eligible for coexistence testing with Method 1`
- Do not call it:
  - `operational mainline`
  - `standalone demo-forward candidate`
  - `first-capital candidate`
- Reason:
  - the edge survives train, latest OOS, and a longer actual window,
  - but `4 trades over the longer actual window` is still too sparse for standalone promotion language.

## Next Step

1. Keep `quality12b_guarded` as the only operational mainline.
2. Use `usdjpy_20260410_method2_s2_short_guarded` as the short-only Method2 source of truth.
3. Open the next cycle as a coexistence comparison:
   - `Method 1 long quality`
   - plus this `Method 2 short guarded`
4. Do not widen this short family with loose spread or weak breakout quality just to force more trades.
