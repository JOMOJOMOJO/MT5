# Tick-shock Step 6 post-fix GREEN report

## Result

The Step 3 fixtures and expected values were not changed. Production behavior
and the executable harness now produce:

- PASS: 45
- FAIL: 0
- XFAIL: 0
- XPASS: 0
- SKIP: 19
- Python checks: 10 passed, 0 failed
- MQL5 compile: seven harnesses and the research EA, all 0 errors / 0 warnings

Formal deterministic GREEN conditions are satisfied:

- unexpected FAIL: 0;
- known XFAIL: 0;
- processing-before-entry: 0;
- stale detection fill: 0;
- reversal signal overwrite: 0;
- realized RR below requested: 0;
- compile errors/warnings: 0/0.

This validates the deterministic production-path clock and calculations. It
does not establish strategy edge or fully observe broker order lifecycle.

## Step 5 inputs

- Report: `reports/tests/tick_shock/step05_pre_fix_red_report.md`
- Results: `reports/tests/tick_shock/step05_pre_fix_results.csv`
- Base Step 5 commit: `78d5a94cfc7fda709b4e4e596a261a1e7754e289`

The unchanged pre-fix command was run before code changes and reproduced 24
PASS, 0 FAIL, 1 XFAIL, 16 XPASS, and 23 SKIP. Its sole XFAIL was
`TS-CSV-001`.

## Test to requirement/defect/function mapping

| Test ID | Requirement ID | Defect ID | Production function |
|---|---|---|---|
| `TS-CSV-001` | `REQ-CSV-001` | `TS-KD-012` | `TSMt5OpenAppendCsv` |
| `TS-PARTIAL-001` | `REQ-ORDER-001` | `TS-KD-009` | `TSResetOrderFillState`, `TSApplyEntryDeal` |
| `TS-TIME-001` | `REQ-TIME-001` | `TS-KD-001` | `TSResearchEntryEligibleMsc`, `TSResearchTryEntryClock` |
| `TS-DETECT-001` | `REQ-TIME-004` | `TS-KD-002` | `TSResearchTryEntryClock` |
| `TS-REV-001` | `REQ-TIME-005` | `TS-KD-003` | `TSRegisterResearchSignal`, `TSResearchTryEntryClock` |
| `TS-RET-001` | `REQ-DET-001` | `TS-KD-004` | `TSResearchExactLogReturn` |
| `TS-CLUSTER-001` | `REQ-MULTI-003` | `TS-KD-005` | `TSAssignResearchMarketCluster` |
| `TS-RR-001` | `REQ-EXEC-003` | `TS-KD-006` | `TSBuildResearchTarget` |
| `TS-BROKER-001` | `REQ-EXEC-008` | `TS-KD-007` | `TSProtectiveOrderDistanceFeasible` |

## Corrected and promoted Test IDs

| Test ID | Step 5 | Step 5 actual | Step 6 | Step 6 actual / expected |
|---|---|---|---|---|
| `TS-CSV-001` | XFAIL | silent append true; `APPENDED`; two mixed rows | PASS | silent append false; `RUN_ID_COLLISION`; zero mixed rows; one header |
| `TS-PARTIAL-001` | SKIP | `PARTIAL_FILL_NOT_OBSERVED` | PASS | remaining 0.06, 0.03, 0; average 1.10015; no first-deal close |
| `TS-ORDER-001` | SKIP | lifecycle not observed | PASS | full fill; remaining 0; average 1.1001; `WAIT_EXIT` |
| `TS-ORDER-002` | SKIP | lifecycle not observed | PASS | two deals; average 1.10012; no first-deal close |
| `TS-ORDER-003` | SKIP | lifecycle not observed | PASS | filled 0.06; cancelled 0.04; remaining 0; `WAIT_EXIT` |
| `TS-TIME-001` | XPASS | entry 1600; before-processing 0 | PASS | unchanged and equal to expected |
| `TS-DETECT-001` | XPASS | entry 1030; stale fill 0 | PASS | unchanged and equal to expected |
| `TS-REV-001` | XPASS | signal 3000; overwrite 0 | PASS | unchanged and equal to expected |
| `TS-RET-001` | XPASS | independent 250/500/1,000ms values | PASS | unchanged and equal to expected |
| `TS-CLUSTER-001` | XPASS | cross-symbol 2,000ms boundary correct | PASS | unchanged and equal to expected |
| `TS-RR-001` | XPASS | Long/Short RR at least 1.333333333333 | PASS | unchanged and equal to expected |
| `TS-BROKER-001` | XPASS | Bid/Ask StopsLevel basis correct | PASS | unchanged and equal to expected |

The seven XPASS rows were already correct in the Step 4 extracted production
core. Step 6 audited their actual EA wiring and promotes them to formal post-fix
PASS; no fixture or expected value was relabelled.

## Production files and functions

Changed production files:

- `mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5`
- `mql/Include/TickShock/TickShockTypes.mqh`
- `mql/Include/TickShock/TickShockOrderLifecycle.mqh`
- `mql/Include/TickShock/TickShockEngine.mqh`
- `mql/Include/TickShock/TickShockCsvSerializer.mqh`
- `mql/Include/TickShock/TickShockMt5Adapter.mqh`

Changed/new production functions:

- `TSRRunMetadataFingerprint`, `TSROpenCsv`;
- `TSMt5ReadRunMetadata`, `TSMt5WriteRunMetadata`,
  `TSMt5OpenAppendCsv`;
- `TSResetOrderFillState`, `TSApplyEntryDeal`,
  `TSResolveEntryRemainderCancel`;
- `TSCsvOpenStatusName`, `TSOrderEntryStateName`.

Audited unchanged causal functions:

- `TSRegisterResearchSignal`, `TSResearchEntryEligibleMsc`,
  `TSResearchTryEntryClock`, `TSResearchEntryInvariant`;
- `TSResearchExactLogReturn`;
- `TSAssignResearchMarketCluster`;
- `TSBuildResearchTarget`;
- `TSProtectiveOrderDistanceFeasible`,
  `TSProtectiveFreezeDistanceClear`.

Test wiring/runners were updated to call the new production seams and to treat
post-fix mismatch as FAIL:

- `mql/Experts/tests/TickShockStep5TestSupport.mqh`
- `mql/Experts/tests/ExpectedValue_TickShock_OrderLifecycleHarness.mq5`
- `tools/tick_shock/run_mql_harnesses.ps1`
- `tools/tick_shock/run_python_tests.py`
- `tools/tick_shock/run_all_tests.ps1`

Step 5 raw evidence remains under `reports/tests/tick_shock/raw/`. Step 6 raw
evidence is written separately under `reports/tests/tick_shock/step06_raw/` so
reruns cannot rewrite the historical RED observation.

## Compile evidence

| Target | Log | Result |
|---|---|---|
| Research EA | `reports/compile/tick_shock/step06_ExpectedValue_MultiCurrency_TickShockResearch.log` | 0 errors, 0 warnings |
| DomainUnit | `reports/compile/tick_shock/step06_ExpectedValue_TickShock_DomainUnitHarness.log` | 0 errors, 0 warnings |
| Detector | `reports/compile/tick_shock/step06_ExpectedValue_TickShock_DetectorHarness.log` | 0 errors, 0 warnings |
| StateMachine | `reports/compile/tick_shock/step06_ExpectedValue_TickShock_StateMachineHarness.log` | 0 errors, 0 warnings |
| Execution | `reports/compile/tick_shock/step06_ExpectedValue_TickShock_ExecutionHarness.log` | 0 errors, 0 warnings |
| SyntheticIntegration | `reports/compile/tick_shock/step06_ExpectedValue_TickShock_SyntheticIntegrationHarness.log` | 0 errors, 0 warnings |
| MultiCurrencyMerge | `reports/compile/tick_shock/step06_ExpectedValue_TickShock_MultiCurrencyMergeHarness.log` | 0 errors, 0 warnings |
| OrderLifecycle | `reports/compile/tick_shock/step06_ExpectedValue_TickShock_OrderLifecycleHarness.log` | 0 errors, 0 warnings |

MetaEditor returned process code 1 in this installation, while every canonical
compile log reported 0 errors and 0 warnings; `scripts/compile.ps1` recognized
the builds as successful.

## Remaining SKIP

The following 19 cases remain SKIP and are not counted as PASS:

- detector seams not yet extracted: `TS-PCT-001`, `TS-Z-001`, `TS-Z-002`,
  `TS-EFF-001`, `TS-EFF-002`, `TS-BASE-001`, `TS-BASE-002`;
- commission adapter not extracted: `TS-COMM-001`;
- cross-detector cluster/dedup seams not extracted: `TS-CLUSTER-002`,
  `TS-DUP-001`;
- server deal not observed: `TS-SERVER-SL-LONG-001`,
  `TS-SERVER-SL-SHORT-001`, `TS-SERVER-TP-LONG-001`,
  `TS-SERVER-TP-SHORT-001`;
- order lifecycle not observed in an actual terminal: `TS-TIME-CLOSE-LONG-001`,
  `TS-TIME-CLOSE-SHORT-001`, `TS-POSITION-001`;
- process restart not observed: `TS-RESTART-001`, `TS-RESTART-002`.

## Remaining risks

- The research EA contains no `OrderSend` path; broker partial fill, server
  SL/TP, time close, and restart recovery still require controlled terminal
  evidence.
- The RunId sidecar prevents metadata/schema mixing, but Step 7 must use a new
  unique RunId for its new evidence set.
- Detector helper seams listed above remain unexecuted by the MQL unit harness,
  although their integrated candidate CSV invariants continue to reconcile.
- No long OOS, optimization, or edge claim was performed.

## Step 7 handoff

Formal execution mode: `REALIZABLE_EA` only.

Mandatory inputs:

- `docs/research/tick_shock/00_artifact_manifest.md`
- `docs/research/tick_shock/06_causal_execution_fix.md`
- `reports/tests/tick_shock/step06_post_fix_results.csv`
- `reports/tests/tick_shock/step06_post_fix_green_report.md`
- `docs/research/tick_shock/03_test_specification.md`
- `tests/tick_shock/spec/test_cases.csv`
- `tests/tick_shock/fixtures/`
- `tests/tick_shock/expected/`
- `mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5`
- all modules under `mql/Include/TickShock/`, including
  `TickShockOrderLifecycle.mqh`
- `docs/research/tick_shock_scalper_csv_schema.md`
- baseline 2025-03 `events.csv`, `summary.csv`, `summary.md`, and
  `tick_quality.csv` registered in the artifact manifest.

Exact deterministic gate command for Step 7 before any market rerun:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/tick_shock/run_all_tests.ps1 -TimeoutSeconds 45 -Phase post-fix
```

A Step 7 market command must use its Step 7-specific tester config/preset and a
new RunId. It is intentionally not guessed or generated in Step 6.

## Validation status

- `RESEARCH_PIPELINE_PARTIALLY_VALIDATED`
- `DETERMINISTIC_CAUSAL_EXECUTION_PATH_VALIDATED`
- `BROKER_ORDER_LIFECYCLE_PARTIALLY_OBSERVED`
- `STRATEGY_FEASIBILITY_NOT_ESTABLISHED`
- `EDGE_UNDETERMINED`
- long OOS not performed
