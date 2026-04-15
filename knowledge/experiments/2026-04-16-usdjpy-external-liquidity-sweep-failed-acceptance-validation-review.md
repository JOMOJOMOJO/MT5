# USDJPY External Liquidity Sweep Failed Acceptance Validation Review

Date: 2026-04-16

## 1. Design Plan

### Why Close Prior Families

- Dow HS did not keep OOS inventory and fixed-TP diagnostics did not rescue it.
- Generic local sweep made inventory, but actual aggregate stayed below `PF 1`.
- both families showed sparse survivors rather than a durable entry edge.

### Reuse

- confirmed pivots / swings
- `context -> pattern -> execution` structure
- EMA / ATR handles
- risk sizing
- telemetry
- `MFE / MAE / unrealized R`
- partial-first / BE / time stop / acceptance exit
- validator / summary workflow

### Core Hypothesis

- local pivots were too generic
- externally visible levels should matter more:
  - context prior swing
  - `M30` prior swing
  - previous-day extreme
- a sweep of those levels followed by failed acceptance and rejection should have higher quality than a sweep of a small local pivot

### Minimal Matrix

- `M30 context x M10 pattern x M3 execution`
- `M15 context x M5 pattern x M3 execution`
- `M15 context x M10 pattern x M3 execution`
- `Tier A strict`
- `short-only`
- partial `38.2`
- final `61.8`
- hold `24`
- compare:
  - `reclaim_close_confirm`
  - `retest_failure`
  - `recent_swing_breakdown`
  - `context_prior_swing`
  - `m30_prior_swing`
  - `previous_day_extreme`

### Continue / Reject

Continue only if OOS has real inventory, actual has enough trades, telemetry explains the path, and the family does not collapse into one trigger / one subtype / one external level.

Reject if OOS is empty, actual only keeps sparse survivors, subtype collapse is strong, or enough trades still produce `PF < 1`.

## 2. Compile / Run

- compile: passed
- runs: `81`
- matrix: `3 pairs x 3 level modes x 3 triggers x train/oos/actual`

## 3. Priority Pair Result

### OOS aggregate by pair

- `M15 x M5 x M3`: `9 trades`, `PF 1.23`, `net +12.30`, `avg realized R +0.0419`
- `M15 x M10 x M3`: `3 trades`, `PF 0.00`, `net +37.19`, `avg realized R +0.3570`
- `M30 x M10 x M3`: `2 trades`, `PF 0.00`, `net -21.28`, `avg realized R -0.3159`

### actual aggregate by pair

- `M15 x M5 x M3`: `146 trades`, `PF 0.45`, `net -1205.65`, `avg realized R -0.2416`
- `M30 x M10 x M3`: `86 trades`, `PF 0.18`, `net -856.49`, `avg realized R -0.2917`
- `M15 x M10 x M3`: `47 trades`, `PF 0.09`, `net -970.90`, `avg realized R -0.6094`

## 4. Trigger Inventory

### OOS aggregate by trigger

- `reclaim_close_confirm`: `7 trades`, `PF 1.02`, `net +0.89`
- `retest_failure`: `3 trades`, `PF 0.68`, `net -11.99`
- `recent_swing_breakdown`: `4 trades`, `PF 0.00`, `net +39.31`

### actual aggregate by trigger

- `reclaim_close_confirm`: `149 trades`, `PF 0.25`, `net -1887.86`
- `retest_failure`: `44 trades`, `PF 0.37`, `net -402.05`
- `recent_swing_breakdown`: `86 trades`, `PF 0.35`, `net -743.13`

## 5. External Level Inventory

### OOS aggregate by level

- `context_prior_swing`: `5 trades`, `net +50.25`
- `m30_prior_swing`: `5 trades`, `net +52.88`
- `previous_day_extreme`: `4 trades`, `net -74.92`

### actual aggregate by level

- `context_prior_swing`: `7 trades`, `PF 1.12`, `net +5.40`
- `m30_prior_swing`: `38 trades`, `PF 0.25`, `net -404.15`
- `previous_day_extreme`: `234 trades`, `PF 0.29`, `net -2634.29`

Interpretation:

- `context_prior_swing` stayed too sparse to promote.
- `previous_day_extreme` created the inventory, but it did not create quality.
- `m30_prior_swing` showed some OOS positives, but actual did not repeat.

## 6. Subtype Collapse

The family did not fail from zero inventory. It failed from collapse into a weak subtype.

- best OOS slice:
  - `M15 x M5 x M3 x m30_prior_swing x reclaim_close_confirm`
  - report `5 trades`, telemetry `3 closed trades`
  - exits: `time_stop 2`, `breakeven_after_partial 1`
- second OOS slice:
  - `M15 x M5 x M3 x m30_prior_swing x recent_swing_breakdown`
  - report `3 trades`, telemetry `2 closed trades`
  - exits: `time_stop 1`, `breakeven_after_partial 1`

That means the OOS positives were still small and leaned on `time_stop`, not on a clean runner path.

actual then collapsed into:

- `short | external_liquidity_sweep_failed_acceptance | previous_day_extreme | exec_reclaim_close_confirm`
- `short | external_liquidity_sweep_failed_acceptance | previous_day_extreme | exec_recent_swing_breakdown`

Those subtypes had enough trades, but stayed below `PF 1`.

## 7. Exit Path Diagnosis

The main failure reason remained structural invalidation, not target ambition.

Example:

- `M15 x M5 x M3 x previous_day_extreme x reclaim_close_confirm`
  - `54` closed trades
  - `acceptance_back_above_failed_high: 24`
  - `time_stop: 11`
  - `runner_target: 10`
  - `stop_loss: 5`

The family could reach partial and sometimes runner, but the acceptance failure remained too expensive and too frequent.

## 8. Verdict

`Reject`

### Reason

- OOS inventory existed, so the family was alive enough to test.
- actual inventory also existed, so the failure is not a mere sample-size issue.
- but actual aggregate stayed below `PF 1` for every meaningful pair / trigger / external-level group.
- OOS positives were sparse and leaned on `time_stop` rescue.
- the only positive actual level aggregate was `context_prior_swing`, and it had only `7 trades`.
- therefore externalizing the liquidity reference improved the idea definition, but still did not prove a durable standalone edge.
