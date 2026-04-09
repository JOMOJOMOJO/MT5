# USDJPY turnover cause analysis

- Date: `2026-04-09`
- Scope: why more timeframes / more methods did not automatically improve the `USDJPY` long family
- Decision owner roles:
  - `research-director`
  - `systematic-ea-trader`
  - `professional-trader`
  - `risk-manager`
  - `forward-live-ops`

## Main Answer

- Trade count does not increase usefully just because more labels are added.
- What matters is whether the added bucket is:
  - structurally different,
  - low enough correlation with the existing bucket,
  - still expectancy-positive after MT5 friction,
  - disciplined enough not to consume the daily risk budget with low-quality entries.

## What Actually Went Wrong

1. The lower-timeframe `M3` / `M1` expansion was not true diversification.
   It reused the same round-continuation idea on noisier bars, so it mostly added a faster version of the same losers.
2. The added buckets were cost-sensitive.
   Smaller stops and shorter targets made spread and local noise matter more.
3. `trend` vs `range` labels were too coarse by themselves.
   The worst losses often live in transition states, not in clean textbook trend or range blocks.
4. More buckets increased competition for the same daily risk budget.
   Even if the portfolio-level cap survived, low-quality extra trades diluted the expectancy of the base quality bucket.
5. Orthogonality mattered more than timeframe variety.
   The `EMA continuation` sidecar on the same `M15` chart survived much better than the lower-timeframe same-method clones.

## Evidence

- Rejected:
  - `reports/presets/usdjpy_20260409_round_quality_guarded-stack-m1m3.set`
  - `2025-04-01` to `2025-12-31`: `net -746.13`, `PF 0.65`, `178 trades`
  - `2026-01-01` to `2026-04-01`: `net -219.95`, `PF 0.55`, `50 trades`
- Rejected:
  - `reports/presets/usdjpy_20260409_round_quality_guarded-stack-m3-only.set`
  - `train net -653.63`, `PF 0.77`, `227 trades`
  - `OOS net -242.57`, `PF 0.46`, `37 trades`
- Still carry forward as research-only:
  - `reports/presets/usdjpy_20260409_round_quality_guarded-stack-sidecar.set`
  - `train net +92.00`, `PF 1.06`, `152 trades`
  - `OOS net +79.25`, `PF 1.53`, `20 trades`
- Current repo-best turnover-biased operational branch:
  - `mql/Experts/usdjpy_20260402_round_continuation_long.mq5`
  - `reports/presets/usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_guarded.set`
  - current actual long-window evidence in repo:
    - `net +563.86`
    - `PF 1.28`
    - `145 trades`
    - `DD 3.06%`
  - current actual OOS evidence in repo:
    - `net +160.27`
    - `PF 2.06`
    - `20 trades`
    - `DD 0.38%`

## Operating Decision

- Do not put `M1` / `M3` same-method buckets into the default operating path.
- Keep the `20260409` file as:
  - quality-first anchor,
  - experimentation shell,
  - guard-rail test bed.
- For actual demo-forward operation, use the existing proven branch:
  - `scripts/start-usdjpy-quality12b-stack-parallel-demo-forward.ps1`
  - `scripts/close-usdjpy-quality12b-stack-parallel-demo-forward.ps1`
  - `scripts/usdjpy-quality12b-stack-parallel-live-preflight.ps1`

## Practical Rule Going Forward

- Add turnover only when the new bucket is orthogonal in market behavior, not merely faster in sampling.
- Prefer:
  - `same timeframe, different edge`
- over:
  - `same edge, lower timeframe clone`

## Next Improvement Priority

1. Tighten the `M15 EMA sidecar` and other already-proven `M15` sidecars before opening another lower-timeframe branch.
2. Keep the quality anchor and turnover branch separate in naming and promotion.
3. Promote only after a real demo-forward review, not because the trade count looks higher on paper.
