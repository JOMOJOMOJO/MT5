# Tick-shock validation invalidation (historical, superseded)

## Historical decision

The earlier `NO_EDGE_OBSERVED` decision was withdrawn because baseline/signal definitions, replay chronology, immediate-outcome validation, and execution feasibility were not aligned. The correct historical label was `VALIDATION_INVALID / EDGE_UNDETERMINED`.

The v4 repair improved the research pipeline but still used global merge time as an execution floor, allowed a final-burst post-hoc filter on the immediate strategy, changed the stop geometry under spread stress, and converted research policy gates into outcome invalidation. Its 252 scenario labels represented only seven independent events and yielded no executable outcome.

## Superseding evidence

The execution-model revision and March-only rerun are recorded in [the 2026-08-22 QA note](2026-08-22-tick-shock-execution-revision.md) and [run report](../../reports/backtest/runs/20260822_tickshock_execution_revision/summary.md).

This file remains as a historical audit trail. It must not be used as the current validation result.
