# USDJPY quality12b stack parallel range cycle1 reject

- Date: `2026-04-09`
- Family: `usdjpy_20260402_round_continuation_long`
- Baseline candidate:
  - `quality12b_stack_parallel_guarded`
- Tested additions:
  - `quality12b_stack_parallel_range_guarded`
  - `quality12b_stack_parallel_range_loose`

## Objective

- Reuse the old EA's `low-ADX range fade` idea as a truly separate long-side bucket.
- Keep the active `M15` continuation stack intact.
- Add an `M5` `range reclaim long` that buys a sweep below a recent range floor and re-entry back into the range.

## New Bucket

- Bucket name:
  - `range_reclaim_long`
- Environment timeframe:
  - `M15`
- Signal timeframe:
  - `M5`
- Logic:
  - require `EMA13 > EMA100` and an `HH / HL` environment on `M15`,
  - require a narrow `M5` range with low `ADX`,
  - require a brief breach below the recent range low,
  - require the signal bar to reclaim and close back inside the range,
  - set the stop below the reclaim bar low,
  - target the recent range high minus a small buffer.

## Baseline Reference

- `quality12b_stack_parallel_guarded`
- Train `2025-04-01` to `2025-12-31`:
  - `net +563.31`
  - `PF 1.28`
  - `145 trades`
  - `max DD 3.06%`
- OOS `2026-01-01` to `2026-03-31`:
  - `net +160.12`
  - `PF 2.06`
  - `20 trades`
  - `max DD 0.38%`

## Candidate Results

### `quality12b_stack_parallel_range_guarded`

- Train:
  - `net +563.86`
  - `PF 1.28`
  - `145 trades`
  - `max DD 3.06%`
- OOS:
  - `net +165.85`
  - `PF 2.14`
  - `20 trades`
  - `max DD 0.32%`
- Bucket activity summary:
  - no meaningful additional `range_reclaim_long` activity on the latest windows.

### `quality12b_stack_parallel_range_loose`

- Train:
  - `net +577.53`
  - `PF 1.28`
  - `149 trades`
  - `max DD 3.06%`
- OOS:
  - `net +165.85`
  - `PF 2.14`
  - `20 trades`
  - `max DD 0.32%`
- Bucket activity summary:
  - the looser profile activated the bucket only lightly on train,
  - recent OOS turnover did not increase.

## Verdict

- Reject both range variants as active promotions.
- Keep `quality12b_stack_parallel_guarded` as the active turnover-biased demo-forward candidate.
- The old EA's `range fade` idea is structurally valid, but on this broker and recent USDJPY windows it is too sparse to solve the current turnover problem.

## Why Rejected

- Neither candidate increased the tested `3 months OOS` trade count over the active branch.
- The guarded profile effectively behaved like the baseline.
- The loose profile added almost no useful recent activity.
- This cycle did not move the family through the repo's live gate.

## Next Action

- Do not spend another immediate cycle on low-ADX `range reclaim` loosening.
- Keep the active candidate as:
  - `quality12b_stack_parallel_guarded`
- The next serious cycle should use one of these paths:
  - a fresh `fractal / stochastic pullback` long bucket from the old EA's trend method,
  - or a truly independent `short` bucket that can coexist with the long stack.
