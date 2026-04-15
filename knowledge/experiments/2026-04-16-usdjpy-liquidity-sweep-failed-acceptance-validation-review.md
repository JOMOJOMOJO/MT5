# USDJPY Liquidity Sweep Failed Acceptance Validation Review

Date: 2026-04-16

## 1. Scope

- family: `USDJPY Dow Fractal Liquidity Sweep Failed Acceptance Engine`
- validation matrix:
  - `M30 context x M10 pattern x M3 execution`
  - `M15 context x M5 pattern x M3 execution`
  - `M15 context x M10 pattern x M3 execution`
- fixed slice:
  - `Tier A strict`
  - `short-only`
  - partial `38.2`
  - final `61.8`
  - hold `24`
  - EA managed exits
- trigger comparison:
  - `reclaim_close_confirm`
  - `retest_failure`
  - `recent_swing_breakdown`

## 2. Compile / Run

- compile: success
- runs: `27`
- train / OOS / actual all completed

Primary artifacts:

- results json:
  - `reports/backtest/sweeps/2026-04-16-usdjpy-liquidity-sweep-failed-acceptance-validation/results/results.json`
- summary:
  - `reports/backtest/sweeps/2026-04-16-usdjpy-liquidity-sweep-failed-acceptance-validation/results/summary.md`

## 3. High-Level Read

This family solved the previous inventory problem.

- OOS closed trades: `93`
- actual closed trades: `1117`

But the quality did not survive.

- actual pair PF:
  - `M30 x M10 x M3`: `0.46`
  - `M15 x M5 x M3`: `1.30` on OOS only, but actual `0.41`
  - `M15 x M10 x M3`: `0.32`
- actual trigger PF:
  - `reclaim_close_confirm`: `0.39`
  - `retest_failure`: `0.43`
  - `recent_swing_breakdown`: `0.39`

No actual pair or trigger produced repeatable `PF > 1`.

## 4. Priority Pair Read

### OOS

- best OOS run:
  - `M15 x M5 x M3`
  - `recent_swing_breakdown`
  - `8 trades`
  - `PF 2.61`
  - `net +58.91`
- second OOS positive:
  - `M15 x M10 x M3`
  - `retest_failure`
  - `3 trades`
  - `net +80.17`
  - all exits were `time_stop`

### Actual

- best actual run by PF:
  - `M30 x M10 x M3`
  - `retest_failure`
  - `36 trades`
  - `PF 0.49`
  - `net -208.31`
- highest actual inventory:
  - `M15 x M5 x M3`
  - `reclaim_close_confirm`
  - `334 trades`
  - `PF 0.43`
  - `net -1781.59`

## 5. Trigger Inventory

### OOS

- `reclaim_close_confirm`: `56 trades`, `PF 0.41`, `net -398.30`
- `retest_failure`: `10 trades`, `PF 1.72`, `net +64.22`
- `recent_swing_breakdown`: `27 trades`, `PF 0.65`, `net -88.35`

### Actual

- `reclaim_close_confirm`: `657 trades`, `PF 0.39`, `net -4172.32`
- `retest_failure`: `106 trades`, `PF 0.43`, `net -796.53`
- `recent_swing_breakdown`: `354 trades`, `PF 0.39`, `net -2354.08`

Inventory exists, but only OOS `retest_failure` is positive, and that does not repeat in actual.

## 6. OOS Inventory

- OOS `0 trades` problem is solved.
- actual enough-trades problem is also solved.
- therefore the family is not rejected for sparsity alone.

## 7. Subtype Collapse

There is still meaningful collapse at the winning edge.

- the profitable OOS runs are narrow:
  - `M15 x M5 x M3 x recent_swing_breakdown`
  - `M15 x M10 x M3 x retest_failure`
- the `M15 x M10 x M3 x retest_failure` run is only `3 trades`
- the `M15 x M5 x M3 x recent_swing_breakdown` run is only `8 trades`

The family does not collapse into `0 trades`, but the only positive windows still collapse into sparse trigger-pair slices.

## 8. Telemetry Read

### Best OOS winner

`M15 x M5 x M3 x recent_swing_breakdown`

- subtype:
  - only `short | liquidity_sweep_failed_acceptance | exec_recent_swing_breakdown`
- context:
  - mostly `ctx_range_top`
- pattern state:
  - `reclaimed_back_inside` did best
  - `breakdown_ready` was weak
- exit reason:
  - `7 / 8` exits were `time_stop`
  - only `1` trade ended at `stop_loss`

This is not the profile of a clean structural continuation. It is mostly a time-stop rescue profile.

### Best actual slice

`M30 x M10 x M3 x retest_failure`

- main loss reason:
  - `acceptance_back_above_failed_high` = `22` exits, `-374.53`
- positive bucket:
  - `time_stop` = `9` exits, `+177.95`
- `runner_target` exists, but only `2` exits

Again, the family looks better when time stop rescues the position, not when the pattern cleanly resolves.

## 9. Continue / Reject

Decision: `Reject`

### Why

- OOS inventory exists, but the positive OOS slices are sparse.
- actual does not repeat the positive OOS slices.
- all actual pair aggregates remain below `PF 1`.
- all actual trigger aggregates remain below `PF 1`.
- telemetry shows a large share of the apparent edge coming from `time_stop`, not from clean post-failure continuation.
- acceptance exit remains a dominant loss reason in the better actual slices.

## 10. Conclusion

Compared with the closed Dow HS family, this new family is better at creating inventory.

But it still fails the main requirement:

- durable edge that repeats in actual
- non-sparse winning path
- non-rescue-driven outcome profile

So this family should not be promoted. It can be recorded as:

- better inventory than Dow HS
- still not strong enough as a standalone family
