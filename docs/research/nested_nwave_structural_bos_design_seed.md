# Nested N-Wave Structural BOS Design Seed

Date: 2026-06-16

## Proposed Research Mode

`RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS`

This is a design seed only. No implementation is included in this cleanup.

## Reason For New Direction

The current Nested N-Wave family used M15 neckline break quality as the main trigger. That was useful for diagnostics, but it remained too close to candle routing:

- instant entries caught some strong moves but suffered false breaks;
- retest confirmation reduced losses but removed strong immediate breakouts;
- breakout/context routers reduced trades, but annual expectancy stayed weak;
- V3-style Friday avoidance improved drawdown but was not structural edge.

The next branch should move the trigger up one level: from M15 neckline appearance to H1 countertrend structure invalidation.

## Core Thesis

The tradable event is not "M15 closed beyond a neckline."

The tradable event is:

1. H4 has a valid impulse and correction candidate.
2. H1 forms a countertrend N-wave inside the H4 correction.
3. The H1 countertrend structure is invalidated.
4. M15 confirms that invalidation with a closed-bar BOS or small retest/reclaim.

The entry should represent failure of the opposing structure, not a standalone breakout candle.

## Long Model

1. H4 bullish impulse:
   - confirmed swing low to swing high;
   - HH/HL or equivalent Dow structure;
   - current price in a reasonable correction area;
   - H4 impulse origin not broken.
2. H1 countertrend down N-wave inside H4 correction:
   - lower high;
   - lower low;
   - clear corrective channel or two-leg decline;
   - latest push fails to extend cleanly.
3. H1 downtrend invalidation:
   - H1 lower-high structure is broken by close, or
   - M15 builds a base and breaks the H1 countertrend neckline.
4. M15 confirmation:
   - closed BOS;
   - optional retest/reclaim;
   - no entry if M15 has already consumed most of the available distance.
5. SL:
   - below the right-side low or below the price that invalidates the new bullish N-wave.
6. TP:
   - fixed R for first diagnostics only.

## Short Model

1. H4 bearish impulse:
   - confirmed swing high to swing low;
   - LL/LH or equivalent Dow structure;
   - current price in a reasonable return area;
   - H4 impulse origin not broken.
2. H1 countertrend up N-wave inside H4 return:
   - higher low;
   - higher high;
   - clear corrective channel or two-leg rally;
   - latest push fails to extend cleanly.
3. H1 uptrend invalidation:
   - H1 higher-low structure is broken by close, or
   - M15 builds a top and breaks the H1 countertrend neckline.
4. M15 confirmation:
   - closed BOS;
   - optional retest/rebreak;
   - no entry if M15 has already consumed most of the available distance.
5. SL:
   - above the right-side high or above the price that invalidates the new bearish N-wave.
6. TP:
   - fixed R for first diagnostics only.

## What To Avoid

- Do not add Friday/session filters as strategy edge.
- Do not use XAUUSD-only, FX-only, USDJPY-short-off, LONG-only, or SHORT-only as the promotion route.
- Do not start from RewardR or SL width tuning.
- Do not treat M15 candle quality as sufficient.
- Do not write every early failure as a raw CSV row.

## First Diagnostics

The first implementation should emit lightweight entry-candidate diagnostics:

- H4 swing state;
- H4 impulse start/end;
- H4 correction depth;
- H1 countertrend N-wave state;
- H1 BOS level;
- M15 confirmation type;
- distance from BOS to entry;
- SL price and SL ATR;
- result_R;
- MFE/MAE in R;
- symbol;
- direction;
- session;
- month;
- FX versus XAUUSD;
- rejection/block reason.

Early fail reasons should go to summary counters.

## Validation Ladder

1. Short diagnostic windows:
   - 2025-02;
   - 2025-08;
   - 2025-10;
   - 2026-Q1.
2. Compare against:
   - current Nested instant;
   - Retest Confirmation;
   - Breakout Quality Router;
   - Context Router V2 alias.
3. Annual tests only if short windows show:
   - sufficient trade count;
   - PF or avg_R improvement;
   - FX does not collapse;
   - result is not XAUUSD-only;
   - both long and short behavior is explainable.
4. Annual separation:
   - 2024;
   - 2025;
   - 2026YTD.

## Stop Conditions

Park Structural BOS if:

- H1 BOS labels do not separate winners and losers;
- entries are still mostly chasing by distance metrics;
- improvement is only XAUUSD or one direction;
- 2024/2025/2026YTD fail in at least two periods;
- trade count is too low to evaluate;
- false breaks remain the main failure type despite H1 BOS confirmation.
