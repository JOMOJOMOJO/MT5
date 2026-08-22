# Tick-shock REALIZABLE_EA correction QA

## Decision

- `RESEARCH_PIPELINE_PARTIALLY_VALIDATED`
- `REALIZABLE_EA_MARCH_REPLAY_ACCEPTANCE_PASSED`
- `EXECUTION_MODEL_VALIDATED`: not approved
- `STRATEGY_FEASIBILITY_NOT_ESTABLISHED`
- `EDGE_UNDETERMINED / insufficient statistical evidence`

The research EA remains order-free. Only `REALIZABLE_EA` output may feed formal expectancy, and the March result contains 15 cross-symbol market clusters rather than 7,452 independent trades.

## Acceptance evidence

- Research production-path harness: 18/18 PASS.
- Independent event-CSV recount: all 13 checks PASS; 552 scenario groups match summary.
- Chronology: entry-before-eligible 0, entry-before-processing 0, stale-grid fill 0, reversal-clock overwrite 0, merge-order violation 0.
- Identity/geometry: duplicate events 0, realized RR below 1.2 count 0.
- Compile: research EA, research harness, and order harness each 0 errors / 0 warnings.
- March replay: 19 event rows / 17 symbol clusters / 15 market clusters; 7,128 valid and 324 broker-invalid labels.

## Order evidence boundary

The order harness recorded 40 observed PASS, 0 FAIL, 4 SKIP, and 1 unit-only PASS. Long server SL, actual partial fill, and injected process restart remain `NOT_OBSERVED`; they are not PASS. Position fields were recovered in ordinary cycles, but restart recovery was not injected.

## Promotion decision

Do not start long OOS, optimization, or trading-EA promotion. The March correlated-label mean is negative, market-cluster n is 15, GBPUSD has 0.5930% generated-tick fallback minutes, and the order observation gate is incomplete.

Evidence: [full run report](../../reports/backtest/runs/20260822_tickshock_realizable_execution/summary.md), [CSV recount](../../reports/backtest/runs/20260822_tickshock_realizable_execution/csv-recount-validation.csv), [research harness](../../reports/backtest/runs/20260822_tickshock_realizable_execution/research-reachability.csv), [order harness](../../reports/backtest/runs/20260822_tickshock_realizable_execution/order-reachability.csv).
