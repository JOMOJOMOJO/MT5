# USDJPY Dow Fractal N-Wave Third-Leg Validation Review

Date: 2026-04-20

## 1. Design Plan

### Why Close Prior Families

- Dow HS did not keep OOS repeatability and fixed-TP diagnostics did not rescue it.
- the generic local sweep family made inventory, but actual aggregate stayed below `PF 1`.
- both families produced sparse survivors instead of a durable standalone entry edge.

### Reuse

- confirmed pivots / swings
- `context -> pattern -> execution` structure
- ATR / EMA handle framework
- risk sizing
- telemetry pipeline
- `MFE / MAE / unrealized R`
- partial-first / mandatory BE after partial
- time-stop comparison framework
- acceptance-exit concept
- validator / summary workflow

### Discard

- triple-top / inverse-triple-top as the center of the family
- generic local sweep as the center of the family
- neckline-only thinking
- pattern names treated as edge by themselves
- rescue-only filters

### Core Hypothesis

- the useful move is not the visible reversal name
- the useful move is the first release of `wave3`
- `wave1 -> wave2 -> invalidation-line break` should capture stop-run fuel better than prior rejected families
- named subtypes such as `double_top_wave2` or `hs_wave2` are only diagnostics around `wave2` completion

### Minimal Matrix

- `H1 context x M15 pattern x M5 execution`
- `M30 context x M10 pattern x M5 execution`
- `M15 context x M5 pattern x M3 execution`
- `Tier A strict`
- `short-only`
- partial `38.2`
- final `61.8`
- hold `24`
- compare:
  - `invalidation_close_break`
  - `retest_reject`
  - `recent_swing_breakdown`

### Continue / Reject

Continue only if OOS has real inventory, actual has enough trades, telemetry explains the path, and the family does not collapse into one trigger / one subtype / one invalidation-line type.

Reject if OOS is empty, actual only shows sparse survivors, subtype collapse is strong, enough trades still produce `PF < 1`, or the family only survives through time-stop rescue.

## 2. Compile / Run

- compile: passed
- runs: `27`
- matrix: `3 pairs x 3 triggers x train/oos/actual`

## 3. Priority Pair Result

### OOS aggregate by pair

- `M15 x M5 x M3`: `14 trades`, `PF 0.20`, `net -102.79`, `avg realized R -0.2140`
- `M30 x M10 x M5`: `3 trades`, `PF 0.00`, `net -9.86`, `avg realized R -0.0957`
- `H1 x M15 x M5`: `0 trades`

### actual aggregate by pair

- `M15 x M5 x M3`: `273 trades`, `PF 0.23`, `net -1744.01`, `avg realized R -0.1960`
- `M30 x M10 x M5`: `212 trades`, `PF 0.51`, `net -821.04`, `avg realized R -0.1200`
- `H1 x M15 x M5`: `0 trades`

Interpretation:

- `H1 x M15 x M5` was dead on arrival.
- `M30 x M10 x M5` was the least bad actual pair, but OOS inventory was only `3` trades and still negative.
- `M15 x M5 x M3` created the inventory, but it was also the main source of actual damage.

## 4. Trigger Inventory

### OOS aggregate by trigger

- `invalidation_close_break`: `5 trades`, `PF 0.25`, `net -40.15`
- `retest_reject`: `0 trades`
- `recent_swing_breakdown`: `12 trades`, `PF 0.15`, `net -72.50`

### actual aggregate by trigger

- `invalidation_close_break`: `202 trades`, `PF 0.45`, `net -998.65`
- `retest_reject`: `9 trades`, `PF 0.15`, `net -76.42`
- `recent_swing_breakdown`: `274 trades`, `PF 0.26`, `net -1489.98`

Interpretation:

- `retest_reject` was functionally dead.
- actual inventory split between `close` and `swing`, but neither came close to `PF 1`.
- the idea did not collapse into one trigger only, but every meaningful trigger stayed negative.

## 5. Invalidation Line Inventory

### OOS aggregate by line type

- `neckline_low`: `15 trades`, `PF 0.21`, `net -96.63`
- `wave1_low`: `2 trades`, `PF 0.00`, `net -16.02`

### actual aggregate by line type

- `neckline_low`: `311 trades`, `PF 0.27`, `net -1824.27`
- `recent_swing_low`: `89 trades`, `PF 0.44`, `net -487.83`
- `wave1_low`: `85 trades`, `PF 0.53`, `net -267.39`

Interpretation:

- OOS practically collapsed into `neckline_low`.
- actual inventory broadened to three line types, but the best one, `wave1_low`, still stayed below `PF 1`.

## 6. Subtype Collapse

The family did not fail from zero inventory alone. It failed because the useful inventory clustered into weak subtypes.

### OOS subtype skew

- `hs_wave2`: `15 trades`, `PF 0.21`, `net -96.63`
- `lower_high_wave2`: `2 trades`, `PF 0.00`, `net -16.02`
- `double_top_wave2`: `0 trades`

### actual subtype skew

- `hs_wave2`: `322 trades`, `PF 0.27`, `net -1866.97`
- `double_top_wave2`: `105 trades`, `PF 0.63`, `net -347.85`
- `lower_high_wave2`: `58 trades`, `PF 0.17`, `net -364.67`

Interpretation:

- OOS was almost entirely `hs_wave2`.
- actual also leaned heavily to `hs_wave2`.
- `double_top_wave2` was the least bad subtype, but it still failed on enough trades.

## 7. Exit Path Diagnosis

The family again failed mainly through structural invalidation, not because the target framework was too ambitious.

### actual exit reason aggregate

- `acceptance_back_above_invalidation_line`: `318 trades`, `net -3449.09`
- `time_stop`: `70 trades`, `net +334.01`
- `breakeven_after_partial`: `39 trades`, `net +166.74`
- `runner_target`: `34 trades`, `net +638.37`
- `stop_loss`: `8 trades`, `net -284.19`

Interpretation:

- most of the inventory died by acceptance back above the broken line.
- positive outcomes existed, but they were too small relative to the acceptance failure load.
- this is not a clean `wave3 ignition` profile. It is still a structure that often gets re-accepted.

## 8. Verdict

`Reject`

### Reason

- OOS inventory existed, but it was small, negative, and concentrated in `M15 x M5 x M3`.
- `H1 x M15 x M5` produced no inventory at all.
- actual inventory existed, but every meaningful pair / trigger / line-type / subtype group stayed below `PF 1`.
- the best actual pair, `M30 x M10 x M5`, still did not repeat in OOS.
- acceptance-back-above-line remained the dominant failure path, while `time_stop` was again one of the few positive rescue paths.
- therefore the N-wave / third-leg framing clarified the structure, but it still did not prove a durable standalone edge.
