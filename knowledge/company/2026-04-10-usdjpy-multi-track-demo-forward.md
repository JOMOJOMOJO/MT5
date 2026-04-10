# USDJPY Multi-Track Demo-Forward

## Decision

- Active quality-first operational mainline:
  - `quality12b_guarded`
- Active turnover-biased forward comparison track:
  - `quality12b_stack_parallel_guarded`
- Three-method integration doctrine:
  - keep the current combined-EA path on the proven `round quality + EMA continuation` pair,
  - require any third bucket to clear standalone actual MT5 before integrating it into the shared EA.

## Why

- Reusable lesson from `knowledge/patterns/2026-04-01-ea-improvement-cycle.md`:
  - do not force a quality-first branch to become a high-turnover branch.
- Reusable lesson from `knowledge/patterns/2026-04-09-old-ea-fractal-range-risk-lessons.md`:
  - distinct market-state methods should be validated independently before they are merged.
- Current repo evidence supports two useful `USDJPY` tracks with different roles:
  - `quality12b_guarded`
  - `quality12b_stack_parallel_guarded`
- Current repo evidence does not yet support a third bucket as an operating candidate.

## Current State

- Quality-first mainline:
  - `demo-forward candidate ready to launch`
  - actual MT5 rerun:
    - `net +914.94`
    - `PF 1.56`
    - `60 trades`
    - `balance DD 2.91%`
- Turnover-biased second track:
  - `forward comparison only`
  - current preflight result:
    - `fail`
  - reason:
    - long-window actual remains positive, but `PF 1.28` is still below the repo `1.30` live-ready floor
  - use:
    - observe real forward behavior,
    - do not treat it as equal to the quality-first mainline for first-capital routing.

## Active Launches

- Quality-first launch:
  - `reports/live/2026-04-10-usdjpy_20260402_round_continuation_long-quality12b_guarded-demo-forward-20260410-151127-launch.json`
- Turnover-biased launch:
  - `reports/live/2026-04-10-usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_guarded-demo-forward-20260410-151302-launch.json`

## Canonical Commands

- Quality-first preflight:
  - `powershell -ExecutionPolicy Bypass -File scripts/usdjpy-mainline-live-preflight.ps1`
- Quality-first start:
  - `powershell -ExecutionPolicy Bypass -File scripts/start-usdjpy-mainline-demo-forward.ps1`
- Turnover-biased preflight:
  - `powershell -ExecutionPolicy Bypass -File scripts/usdjpy-turnover-live-preflight.ps1`
- Turnover-biased start:
  - `powershell -ExecutionPolicy Bypass -File scripts/start-usdjpy-turnover-demo-forward.ps1`

## Integration Rule

- A third bucket can be integrated into the combined `USDJPY` EA only after:
  - it has a standalone release note or equivalent serious-validation note,
  - long-window actual stays positive with survivable drawdown,
  - latest `3 months OOS` stays positive,
  - it adds something materially different from the current `round quality` and `EMA continuation` pair.
