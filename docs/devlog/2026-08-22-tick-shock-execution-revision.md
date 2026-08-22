# Tick-shock execution-model revision

## Task

Repair the remaining research-model defects without relaxing shock thresholds, optimizing parameters, adding orders to the research EA, or starting long OOS.

## Code changes

- `mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5`
  - independent 250/500/1,000ms detectors;
  - same-millisecond tick groups;
  - execution based on same-symbol quote availability;
  - separate detection-time, post-burst, pullback, and reversal paths;
  - exhaustive 1.0x-12.0x stop grid;
  - one event row with compact scenario grid;
  - final-only funnel, mask, buffer, quality, and model summaries.
- `mql/Include/TickShockStateMachine.mqh`
  - broker-only barrier feasibility;
  - non-invalidating policy mask;
  - execution due time without merge floor;
  - TP-limit, SL-gap/slippage, and time-market exit rules.
- Both reachability harnesses were updated and rerun.

The research EA contains no `OrderCheck` or `OrderSend` call. The order lifecycle remains isolated in its tester-only harness.

## Validation

- All three changed MQL5 programs compile with 0 errors / 0 warnings.
- Research harness: 18/18 PASS.
- Order harness: 8/8 PASS.
- March 2025 real-tick rerun: completed in 380.828 seconds, 19 event rows / 17 independent clusters, zero event duplicates, zero global order violations.
- No multi-year OOS or optimization was run.

Evidence: [run report](../../reports/backtest/runs/20260822_tickshock_execution_revision/summary.md), [CSV schema](../research/tick_shock_scalper_csv_schema.md), [QA decision](../../.company/qa/2026-08-22-tick-shock-execution-revision.md).

## Result

The execution model is now testable, and 7,452 broker-feasible scenario outcomes were produced. They are not independent samples. Detection-time, post-burst, and reversal selected configurations were negative; the only positive pullback cell had n=5 and failed 100/250ms delay stress.

Current decision: `NO_EDGE_OBSERVED` for this month/configuration, with `insufficient statistical evidence`. Do not proceed to long OOS automatically.
