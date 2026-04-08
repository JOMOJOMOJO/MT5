# USDJPY quality12b stack parallel dow cycle1 reject

- Date: `2026-04-09`
- Family: `usdjpy_20260402_round_continuation_long`
- Baseline candidate: `quality12b_stack_parallel_guarded`
- Tested additions:
  - `quality12b_stack_parallel_dow_guarded`
  - `quality12b_stack_parallel_dowloose_guarded`

## Objective

- Add a truly separate `M5` entry bucket on top of the active `M15` parallel stack.
- Keep the existing `round quality` and `EMA continuation sidecar` buckets on `M15`.
- Test whether a `Dow-style support sweep and reclaim` long can lift turnover without breaking executable quality.

## New Bucket

- Bucket name:
  - `dow_sweep_long`
- Signal timeframe:
  - `M5`
- Environment timeframe:
  - `M15`
- Logic:
  - require `EMA13 > EMA100` plus higher-high / higher-low style trend on the `M15` environment,
  - identify a recent `M5` pullback low,
  - require a brief breach below that support,
  - require the same `M5` signal bar to reclaim and close back above support,
  - target the prior swing high minus a small buffer.

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

### `quality12b_stack_parallel_dow_guarded`

- Train `2025-04-01` to `2025-12-31`:
  - `net +548.45`
  - `PF 1.26`
  - `149 trades`
  - `max DD 3.07%`
- OOS `2026-01-01` to `2026-03-31`:
  - `net +165.85`
  - `PF 2.14`
  - `20 trades`
  - `max DD 0.32%`
- Bucket activity summary:
  - train: `dow_sweep_long` appeared, but only lightly
  - OOS: `dow_sweep_long` did not add meaningful new turnover

### `quality12b_stack_parallel_dowloose_guarded`

- Train `2025-04-01` to `2025-12-31`:
  - `net +542.67`
  - `PF 1.25`
  - `154 trades`
  - `max DD 3.10%`
- OOS `2026-01-01` to `2026-03-31`:
  - `net +135.81`
  - `PF 1.77`
  - `21 trades`
  - `max DD 0.59%`
- Bucket activity summary:
  - looser thresholds did create a little more `dow_sweep_long` activity,
  - but the extra activity came with weaker long-window quality and weaker OOS quality.

## Verdict

- Both `dow` variants are rejected as active live-track promotions.
- `quality12b_stack_parallel_guarded` remains the active turnover-biased demo-forward candidate.
- The new `M5` bucket is structurally valid and the code now supports mixed bucket timeframes, but this specific `dow_sweep_long` thesis did not add enough executable edge.

## Why Rejected

- The guarded `dow` branch did not improve the tested `3 months OOS` trade count over the active candidate.
- The looser `dow` branch did increase activity slightly, but it degraded both train quality and recent OOS quality.
- Neither branch moved the family through the repo's live gate.

## Next Action

- Do not spend another immediate cycle on looser `dow sweep` thresholds.
- Keep the active candidate as:
  - `quality12b_stack_parallel_guarded`
- Open the next cycle from one of these paths:
  - a truly independent `short` bucket, or
  - a fresh `M5` long bucket that is not another support-sweep variant.
