# USDJPY quality12b stack parallel promotion

- Date: `2026-04-02`
- Family: `usdjpy_20260402_round_continuation_long`
- Candidate: `quality12b_stack_parallel_guarded`

## Objective

- Remove the one-position bottleneck that was suppressing turnover inside the `quality12b + EMA sidecar` stack.

## Change

- Keep the existing `round quality` bucket.
- Keep the existing `EMA continuation sidecar`.
- Allow parallel bucket entries:
  - up to `3` concurrent managed positions,
  - only `1` live position per bucket,
  - later buckets are allowed to enter even if an earlier bucket is already open.

## Why This Cycle Was Different

- The previous `stack_guarded` branch still evaluated multiple buckets, but it effectively allowed only one live position at a time.
- That meant a `3-4.5 hour` hold in bucket `1` could suppress bucket `2` signals that arrived later the same day.
- This cycle tested whether the missing turnover was partly a portfolio-construction problem rather than an entry-quality problem.

## Actual MT5 Result

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

## Comparison Versus Prior Candidate

- `quality12b_stack_guarded`:
  - train `+372.93 / PF 1.21 / 125 trades / DD 2.80%`
  - OOS `+124.05 / PF 1.82 / 19 trades / DD 0.38%`
- `quality12b_stack_parallel_guarded`:
  - train `+563.31 / PF 1.28 / 145 trades / DD 3.06%`
  - OOS `+160.12 / PF 2.06 / 20 trades / DD 0.38%`

## Verdict

- `quality12b_stack_parallel_guarded` is promoted over `quality12b_stack_guarded`.
- The gain is modest, but it is real:
  - higher long-window net,
  - higher long-window PF,
  - more long-window trades,
  - better recent OOS net and PF,
  - no deterioration in recent OOS drawdown.
- This branch is now the active turnover-biased `USDJPY long-only` demo-forward candidate.
- It is still not `live-ready pass` because:
  - the monthly turnover target is still materially missed,
  - real demo-forward evidence is still missing.
