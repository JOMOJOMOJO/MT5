# USDJPY Failed Breakout Structure Engine Validation Review

- Date: 2026-04-14
- EA: `mql/Experts/usdjpy_20260413_failed_breakout_short_scaffold.mq5`
- Compile: `0 errors, 0 warnings`
- Matrix results: `reports/backtest/sweeps/2026-04-14-usdjpy-failed-breakout-validation/results/results.json`
- Matrix summary: `reports/backtest/sweeps/2026-04-14-usdjpy-failed-breakout-validation/results/summary.md`

## Matrix

- Tier A screen: `4 timeframe pairs x 4 target modes x train` = `16 runs`
- Tier A validation: `4 pairs x train/oos/actual` = `12 runs`
- Tier A+B matrix: `4 timeframe pairs x 4 target modes x train/oos/actual` = `48 runs`
- Finalist comparison: `2 finalists x 3 windows x 3 variants` = `18 runs`
- Total executed: `94 runs`

## Primary Findings

- `Tier A` is non-operable. It produced `0 trades` across the train screen and stayed `0 trades` in the validation/comparison follow-up.
- The only branch that produced a meaningful sample was `Tier A+B / M15 x M5`.
- Within `M15 x M5`, target ranking on actual was:
  - `fib`: `PF 1.69 / 8 trades / net +42.26`
  - `fixed_r`: `PF 1.40 / 8 trades / net +32.79`
  - `hybrid_partial`: `PF 1.29 / 10 trades / net +20.75`
  - `prior_swing`: `PF 1.06 / 8 trades / net +4.52`
- That branch failed OOS anyway:
  - `M15 x M5 fib`: `PF 0.00 / 1 trade / net -35.18`
  - `M15 x M5 fixed_r`: `PF 0.00 / 1 trade / net -35.18`
  - `M15 x M5 hybrid_partial`: `PF 0.00 / 1 trade / net -35.18`
  - `M15 x M5 prior_swing`: `PF 0.00 / 1 trade / net -35.18`
- `M30 x M5` generated a few trades but stayed negative across OOS and actual.
- `M15 x M1` showed only `1 trade` in OOS and `2 trades` in actual. This is a sparse survivor, not a promotable branch.
- `H1 x M5` produced `0 trades`.

## Structure Readout

- Traded inventory collapsed to a single path:
  - HTF phase buckets that mattered: `htf_range_top`, some `htf_up_exhaustion`, losing `htf_up_pullback`
  - LTF state: `reclaim_confirmed` only
  - Entry type: `entry_on_reclaim_failure` only
- The designed state machine did not materially supply `lower_high_breakdown` or `retest_failure` inventory.
- The actual edge-like behavior came from `range_top` / `up_exhaustion` cases. `up_pullback` was clearly toxic.
- Fib depth was not broadly robust:
  - `shallow` carried most trades and was negative in aggregate
  - `deep` looked good only because it was very sparse

## Stop / Exit Readout

- `stop_sweep_high` vs `stop_failure_pivot` made no difference on the finalists. The realized results were identical, which means the chosen trades shared the same effective stop anchor.
- Exit profile on the better `M15 x M5 fib` actual run:
  - `target`: `3`
  - `time_stop`: `3`
  - `acceptance_back_above`: `1`
  - `stop_loss`: `1`
- OOS failed as a single `stop_loss`.

## Decision

`Reject.`

Reason:

- `Tier A` is dead.
- The only tradable branch is `Tier A+B / M15 x M5`, but it remains a sparse survivor with `8-10 trades` over the actual window.
- The apparent winner collapses in OOS with only one trade and no supporting repeatability.
- The state machine does not generate diverse, independently-valid entry paths. In practice it reduces to one reclaim-failure branch.
- This is not a case for more rescue filters. The family is too sparse and too unstable to promote.
