# Tick-shock Step 10: deterministic production seams

## Outcome

The research EA now exposes its baseline, detector metrics, event/cluster,
commission, grid, ring, and merge state through explicit production-callable
contexts. The refactor intentionally preserves the Step 7 REALIZABLE behavior;
it does not alter strategy thresholds, RR, stop grids, watermark semantics, CSV
schema, commission assumptions, or order behavior.

## Evidence

- Scope and call-site audit: [`docs/research/tick_shock/10_testability_refactor.md`](../research/tick_shock/10_testability_refactor.md)
- Runtime architecture: [`docs/research/tick_shock/10_to_be_runtime_architecture.md`](../research/tick_shock/10_to_be_runtime_architecture.md)
- Seam-to-test mapping: [`docs/research/tick_shock/10_module_and_test_seam_mapping.md`](../research/tick_shock/10_module_and_test_seam_mapping.md)
- Compile rollup: [`reports/refactor/tick_shock/step10_compile_results.txt`](../../reports/refactor/tick_shock/step10_compile_results.txt)
- Deterministic test results: [`reports/tests/tick_shock/step10_post_refactor_results.csv`](../../reports/tests/tick_shock/step10_post_refactor_results.csv)
- March behavior comparison: [`reports/refactor/tick_shock/step10_behavior_comparison.md`](../../reports/refactor/tick_shock/step10_behavior_comparison.md)
- Reproducible REALIZABLE run: [`reports/backtest/runs/20260823_tickshock_step10_refactor_realizable_202503/`](../../reports/backtest/runs/20260823_tickshock_step10_refactor_realizable_202503/)

## Validation decision

The suite moved from 45 PASS / 19 SKIP to 55 PASS / 9 SKIP by routing ten
previously deterministic-but-unreachable cases through the production modules.
All nine remaining SKIPs require external order/server/restart observation and
remain SKIP. The March preservation oracle compared 272,155 values and found
zero unintended differences. This Step establishes test seams only; it neither
fixes a known defect nor promotes the strategy.
