# Step 10 behavior-preserving testability refactor

## Result

The remaining ten deterministic SKIPs now execute production-callable domain
functions with the unchanged Step 3 fixtures and expected files. The suite
moved from `45 PASS / 19 SKIP` to `55 PASS / 9 SKIP`; no FAIL, XFAIL or XPASS
remains. The nine SKIPs still require external server/order/restart observation
and were not relabeled PASS.

This step changes structure, not strategy. Thresholds, RR 1.2, the 23-stop
grid, four strategies, scenario indices, strict global watermark, CSV schema,
commission input and the order-free research design are unchanged.

## Start gate

- branch base: `24e4f157230de327f59e51cb6426a5b48f6aad59`
- command: `powershell -NoProfile -ExecutionPolicy Bypass -File tools/tick_shock/run_all_tests.ps1 -TimeoutSeconds 45 -Phase post-fix`
- result before source edits: `PASS 45 / FAIL 0 / XFAIL 0 / XPASS 0 / SKIP 19`
- pre/post source, EX5 and terminal hashes:
  `reports/refactor/tick_shock/step10_source_hashes.txt`

## Extracted production responsibilities

- `TickShockRing.mqh`: bounded cursor mutation for tick/grid/detector rings.
- `TickShockGrid.mqh`: next boundary and the latest quote used to close it.
- `TickShockBaseline.mqh`: capacities, Type-7 percentile, histogram percentile,
  robust scale/noise floor/Z and inclusive baseline readiness.
- `TickShockMetrics.mqh`: directional efficiency and explicit commission result.
- `TickShockEventEngine.mqh`: active-key allocation, duplicate event key,
  symbol cluster and cross-symbol/cross-detector market cluster.
- `TickShockMergeSequencer.mqh`: pending tick repository, chronological key,
  strict-watermark release and diagnostics.
- `TickShockResearchEngine.mqh`: detector counter context.
- `TickShockEngine.mqh`: stable production/test facades.
- `TickShockMt5Adapter.mqh`: `OrderCalcProfit` commission adapter returning
  success/failure and derived R values.

Every module listed above is called by the research EA. The detector, execution
and multicurrency harnesses call the same production facades; expected values
continue to come from the Step 3 CSV oracle.

## Deterministic SKIP closure

| Test IDs | Production seam | Result |
|---|---|---|
| `TS-PCT-001` | linear percentile result | PASS |
| `TS-Z-001`, `TS-Z-002` | robust statistics/noise floor | PASS |
| `TS-EFF-001`, `TS-EFF-002` | directional efficiency | PASS |
| `TS-BASE-001`, `TS-BASE-002` | baseline readiness | PASS |
| `TS-COMM-001` | explicit commission result after one-lot loss | PASS |
| `TS-CLUSTER-002` | cross-detector/cross-symbol registration | PASS |
| `TS-DUP-001` | active event duplicate key | PASS |

The comparator was extended only to recognize the pre-existing numeric unit
labels `index`, `bins`, and `z`; neither fixture nor expected value changed.

## Validation

- research EA: 0 errors / 0 warnings;
- all ten harnesses: 0 errors / 0 warnings;
- post-refactor suite: `55 PASS / 0 FAIL / 0 XFAIL / 0 XPASS / 9 SKIP`;
- actual order sending: none; research EA still contains no OrderCheck/OrderSend;
- Step 7 comparison: 272,155 preservation-oracle values across 11,349 matching
  comparison rows, zero unintended difference rows;
- March REALIZABLE causal invariants: zero violations.

The historical execution-revision run differs in 54 expected reference rows;
those are labeled `REFERENCE_VERSION_DRIFT` and are not part of the immediate
pre-refactor preservation gate.

## March REALIZABLE replay

Run: `reports/backtest/runs/20260823_tickshock_step10_refactor_realizable_202503/`.
It reproduced raw candidates 62,577, event rows 19, valid pullbacks 14,
reacceleration 5, reversal signals 11, market clusters 15, every event identity,
policy-mask count, valid/invalid scenario status and scenario R. The runtime was
360.797 seconds; the research EA emitted 0 trade rows and no order.

## Remaining SKIP

`TS-SERVER-SL-LONG-001`, `TS-SERVER-SL-SHORT-001`,
`TS-SERVER-TP-LONG-001`, `TS-SERVER-TP-SHORT-001`,
`TS-TIME-CLOSE-LONG-001`, `TS-TIME-CLOSE-SHORT-001`, `TS-POSITION-001`,
`TS-RESTART-001`, and `TS-RESTART-002`. These require actual server deal,
position or process-restart injection and remain outside this order-free
research refactor.

## Step 11 inputs

- this document and the two Step 10 architecture/mapping documents;
- `reports/tests/tick_shock/step10_post_refactor_results.csv` and `step10_raw/`;
- `reports/refactor/tick_shock/step10_behavior_comparison.csv`;
- `reports/refactor/tick_shock/step10_source_hashes.txt`;
- the Step 10 REALIZABLE run directory and its `reconciliation.md`;
- the unchanged Step 3 registry, fixtures and expected directories.
