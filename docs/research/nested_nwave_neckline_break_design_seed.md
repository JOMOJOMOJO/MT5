# Nested N-Wave Neckline Break Design Seed

Date: 2026-06-07

## Purpose

This is the design seed for the next strategy family after closing active ThirdWave research.

The new strategy should not be implemented as ThirdWave v5. It should be a separate EA branch or research mode called `Nested N-Wave Neckline Break`.

## Core Thesis

A higher-timeframe wave is formed by multiple lower-timeframe N-waves.

Instead of predicting the beginning of wave 3 directly, the strategy waits for evidence that the lower-timeframe countertrend inside a higher-timeframe correction has failed.

The practical signal is not "this is wave 3." The practical signal is "the traders defending the correction have lost the neckline / stop cluster."

## Conceptual Flow

1. Higher timeframe identifies trend or impulse context.
2. Mid timeframe identifies correction or pullback candidate.
3. Lower timeframe tracks the countertrend inside that correction.
4. Entry waits for countertrend invalidation:
   - double bottom neckline break,
   - double top neckline break,
   - inverse head-and-shoulders neckline break,
   - head-and-shoulders neckline break,
   - simplified neckline break from lower-high/lower-low or higher-low/higher-high transition.
5. Entry occurs after closed-bar neckline break.
6. SL is placed where the reversal thesis is invalidated:
   - right-side low for long,
   - right-side high for short,
   - or the price that invalidates the new lower-timeframe N-wave.
7. TP starts as fixed R for measurement.

## Key Difference From ThirdWave

ThirdWave tried to align:

- higher timeframe trend,
- mid timeframe pullback,
- lower timeframe reclaim/breakdown.

The weakness was that confirmed-fractal reclaim/breakdown often arrived after the move had already expanded.

Nested N-Wave should instead align:

- higher timeframe correction context,
- lower timeframe countertrend structure,
- neckline break that invalidates that countertrend.

The trigger is the failure of the internal opposing structure, not a generic trend-continuation reclaim.

## Initial Long Setup

1. Higher timeframe is bullish or recovering from a bullish correction.
2. Mid timeframe shows a pullback that has not invalidated the higher-timeframe bullish structure.
3. Lower timeframe forms a bearish or sideways countertrend inside the pullback.
4. Lower timeframe prints one of:
   - double bottom,
   - inverse head-and-shoulders,
   - higher low after failed lower low,
   - local neckline from minor swing highs.
5. Long only after a closed bar breaks the neckline.
6. SL below right-side low or the low that invalidates the new N-wave.
7. TP initially fixed R.

## Initial Short Setup

1. Higher timeframe is bearish or recovering from a bearish correction.
2. Mid timeframe shows a return/rally that has not invalidated the higher-timeframe bearish structure.
3. Lower timeframe forms a bullish or sideways countertrend inside the return.
4. Lower timeframe prints one of:
   - double top,
   - head-and-shoulders,
   - lower high after failed higher high,
   - local neckline from minor swing lows.
5. Short only after a closed bar breaks the neckline.
6. SL above right-side high or the high that invalidates the new N-wave.
7. TP initially fixed R.

## Diagnostics To Build From Day One

- Pattern type:
  - double_bottom
  - double_top
  - inverse_head_shoulders
  - head_shoulders
  - simple_neckline_break
  - failed_break_reversal
- Neckline price.
- Break candle close distance from neckline.
- Bars from right-side low/high to break.
- Distance from right-side low/high to entry in ATR.
- SL ATR.
- TP ATR.
- Result R.
- Whether the break occurred in trend, range, transition, or exhaustion regime.
- Symbol, direction, session, month, day of week.
- FX versus XAUUSD.
- Entry selection mode: best-only versus all candidates.
- Execution block reasons.

## Reused Research Infrastructure

- Multi-currency framework.
- 5m/10m/15m scan interval comparison.
- All-candidates entry mode.
- Lightweight diagnostics and summary counters.
- Result R aggregation.
- Symbol/direction/regime/session/month reporting.
- Short-period gate before annual OOS.
- Shadow SL/TP diagnostics, only after entry thesis is validated.

## Initial Validation Plan

1. Code only detection diagnostics first if possible.
2. Run short periods:
   - 2025-02
   - 2025-08
   - 2025-10
   - 2026-Q1
3. Use all-candidates mode to expose symbol and direction behavior.
4. Require pattern-level metrics before annual BT.
5. Annual BT only if:
   - trade count is sufficient,
   - PF or avg_R improves versus baseline,
   - FX does not collapse,
   - improvement is not only XAUUSD,
   - both long and short are explainable even if one is parked later.

## Stop Conditions

Stop or redesign if:

- neckline breaks are mostly chasing entries by distance metrics,
- winners are only XAUUSD,
- one year explains all performance,
- LowerTF SL creates oversized lots or excessive invalid stops,
- the pattern taxonomy cannot separate good and bad cases,
- annual windows fail in at least two of 2024, 2025, and 2026YTD.

## First Implementation Boundary

Do not optimize parameters at first.

Implement only:

- pattern detection,
- neckline break confirmation,
- structure SL,
- fixed R TP,
- lightweight diagnostics,
- all-candidates research mode.

Exit design, trailing stops, session filters, and symbol filters should wait until the pattern thesis is proven.

