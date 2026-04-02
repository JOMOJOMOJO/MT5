# USDJPY quality12b stack parallel cap tuning reject

- Date: `2026-04-02`
- Family: `usdjpy_20260402_round_continuation_long`
- Baseline candidate: `quality12b_stack_parallel_guarded`

## Objective

- Check whether the new parallel-entry candidate can clear the repo's live PF floor by tightening execution capacity instead of adding another bucket.

## Tested Presets

- `quality12b_stack_parallel_guarded`
  - train `+563.31 / PF 1.28 / 145 trades / DD 3.06%`
- `quality12b_stack_parallel_guarded-p2`
  - `max open positions = 2`
  - train `+563.31 / PF 1.28 / 145 trades / DD 3.06%`
- `quality12b_stack_parallel_guarded-p2_ema18`
  - `max open positions = 2`
  - `EMA sidecar max EMA13 distance = 18 pips`
  - train `+563.31 / PF 1.28 / 145 trades / DD 3.06%`
- `quality12b_stack_parallel_guarded-p2_ema18_adx25`
  - `max open positions = 2`
  - `EMA sidecar max EMA13 distance = 18 pips`
  - `EMA sidecar max ADX = 25`
  - train `+454.15 / PF 1.27 / 119 trades / DD 3.22%`

## Reading

- The current branch is not actually being helped by allowing a third simultaneous position very often.
- Tightening the EMA sidecar slightly does not improve the realized train result.
- Tightening both EMA distance and ADX only removes trades and worsens the branch.

## Verdict

- Reject `p2`, `p2_ema18`, and `p2_ema18_adx25`.
- Keep `quality12b_stack_parallel_guarded` as the active turnover-biased candidate.
- The next live-ready cycle should not spend another immediate tuning pass on concurrency caps or mild EMA-sidecar tightening.
