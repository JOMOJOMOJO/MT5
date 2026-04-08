# USDJPY quality12b stack parallel short and range-short cycle1 review

- Date: `2026-04-09`
- Family: `usdjpy_20260402_round_continuation_long`
- Active candidate before cycle:
  - `quality12b_stack_parallel_guarded`

## Objective

- Add one truly different `short` method to the active `USDJPY` long stack.
- Test the user's `trend / range` decomposition directly:
  - `trend-down short`
  - `range short`
- Promote only if turnover improves without losing the current live-track quality floor.

## Baseline Reference

- Preset:
  - `usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_guarded.set`
- Train `2025-04-01` to `2025-12-31`:
  - `net +563.86`
  - `PF 1.28`
  - `145 trades`
  - `max DD 3.06%`
- OOS `2026-01-01` to `2026-03-31`:
  - `net +160.27`
  - `PF 2.06`
  - `20 trades`
  - `max DD 0.38%`

## Tested Additions

### 1. `round_continuation_short`

- Thesis:
  - mirror the core `M15` continuation logic for bearish `LL / LH` structure,
  - allow it to run in parallel with the long stack.

#### `quality12b_stack_parallel_short_guarded`

- Train:
  - `net +148.77`
  - `PF 1.05`
  - `199 trades`
  - `max DD 5.15%`
- OOS:
  - `net +59.96`
  - `PF 1.20`
  - `28 trades`
  - `max DD 0.86%`

#### `roundshort_only_guarded`

- Train:
  - `net -423.63`
  - `PF 0.57`
  - `55 trades`
  - `max DD 5.43%`
- OOS:
  - `net -100.14`
  - `PF 0.33`
  - `8 trades`
  - `max DD 1.05%`

#### Verdict

- Reject `round_continuation_short` as an active promotion.
- It raises turnover, but it damages the long-window quality too much.
- The standalone short bucket is clearly not viable.

### 2. `range_reclaim_short`

- Thesis:
  - reuse the old low-ADX range-fade idea on the short side,
  - sell a brief breach above a recent `M5` range high when price closes back into the range.

#### `quality12b_stack_parallel_rangeshort_guarded`

- Train:
  - `net +563.86`
  - `PF 1.28`
  - `145 trades`
  - `max DD 3.06%`
- OOS:
  - `net +160.27`
  - `PF 2.06`
  - `20 trades`
  - `max DD 0.38%`

#### `rangeshort_only_guarded`

- Train:
  - `net +0.00`
  - `PF n/a`
  - `0 trades`
- OOS:
  - `net +0.00`
  - `PF n/a`
  - `0 trades`

#### Verdict

- Reject `range_reclaim_short` as a non-material addition.
- On the tested windows it does not fire in executable form, so it does not solve the turnover problem.

## Decision

- Keep `quality12b_stack_parallel_guarded` as the active turnover-biased demo-forward candidate.
- Do not promote:
  - `quality12b_stack_parallel_short_guarded`
  - `roundshort_only_guarded`
  - `quality12b_stack_parallel_rangeshort_guarded`
  - `rangeshort_only_guarded`

## What Changed Structurally

- The EA now supports bucket-specific `buy / sell` directions instead of being hard-wired to buy-only execution.
- Parallel buckets still work independently:
  - one open position per bucket,
  - multiple buckets can coexist when timing overlaps,
  - bucket-specific timeframes remain supported.

## Why This Still Matters

- `trend-down short` proved the architecture, but not the edge.
- `range short` proved that simply mirroring the old range reclaim idea is too sparse on the current broker feed.
- The repo now has the plumbing to add future `short` buckets without rewriting execution logic again.

## Next Action

1. Do not spend another immediate cycle on looser mirrored `round short` thresholds.
2. Do not spend another immediate cycle on the same `range reclaim short` idea.
3. The next serious `USDJPY` cycle should use one of these:
   - an event-study-informed `M5 short` thesis that is not just a mirror of the long bucket,
   - or a fresh `range` thesis with executable turnover on the recent OOS window.
