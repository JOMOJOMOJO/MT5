# Tick-shock Step 5 executable specification: pre-fix evidence

## Result

Step 5 is executable and has no unexpected FAIL, but it is not the originally
anticipated all-red baseline. The production modules present at the Step 4 base
commit already satisfy the seven defects that the Step 5 instruction expected
to reproduce. Those tests are therefore recorded as `XPASS`, not relabelled as
`XFAIL`. The only reproduced expected defect is the same-RunId CSV append
collision (`TS-CSV-001`). Unobserved broker/order lifecycle behavior remains
`SKIP` and is not counted as PASS.

- Base commit: `ba66f67aba53d447660aa157f4613c46dcf80742`
- Branch: `research/tickshock-testability-refactor-20260822`
- Test IDs: 64
- PASS: 24
- FAIL: 0
- XFAIL: 1
- XPASS: 16
- SKIP: 23
- Python checks: 10 passed, 0 failed
- MQL5 compile: seven harnesses, all 0 errors / 0 warnings
- Strategy Tester: seven harnesses executed; all emitted raw evidence CSVs

This result does not validate strategy edge, execution at a broker, partial
fills, server SL/TP, or restart recovery.

## Production source and SHA-256

| Source path | SHA-256 |
|---|---|
| `mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5` | `4A5BF40C024924C42375FB5EB1338B3A0EB1590FBCFA0E6CB3FCCC6FA0A26D8E` |
| `mql/Include/TickShock/TickShockTypes.mqh` | `8D1288FCCCD92C50981BB2922DFE6F972E65E04BFB998F05903F556922B4E82B` |
| `mql/Include/TickShock/TickShockConfig.mqh` | `4E90C3BDD9269816655E268A9569831E6A26B15D48EA68EC3DEB68659C4A4247` |
| `mql/Include/TickShock/TickShockDetector.mqh` | `A824700BFD279373277217A9C218DD0B3B3E61FD77FAD37A8B798E6BC24AA703` |
| `mql/Include/TickShock/TickShockStateMachine.mqh` | `9F50599E7100A35DC2D715310B10A21E17E63675AE6D247B1DE7D96AEB1DE3BE` |
| `mql/Include/TickShock/TickShockExecutionModel.mqh` | `75D995882B45AB98F466860A578AD46275B6552BED88F2E9F79FD0623B8CBC2E` |
| `mql/Include/TickShock/TickShockScenarioEngine.mqh` | `4860D99EBE4BEDBCCFA15F2771AD689045722747D025732F6D9C7D9B69A18090` |
| `mql/Include/TickShock/TickShockClusterer.mqh` | `567918B873EFED5FCFD66F8431C42E5C6D2A295AE2E4585D2A37136DA190F9CF` |
| `mql/Include/TickShock/TickShockCsvSerializer.mqh` | `EA3B84958A5B5AC177F156A56E8C0D69FDAF69E08E4EC0CC2E81E2A6EF4F7917` |
| `mql/Include/TickShock/TickShockEngine.mqh` | `14FEDF34BF672025135B4DB8BC505204472CFA103A86572662E32582E751866D` |
| `mql/Include/TickShock/TickShockMt5Adapter.mqh` | `AC4A0D12B17E897FAB52045E68AD233D5FDF219CE6E3FE5121F80871FFE2CBB9` |

Production source was not changed in Step 5.

## Specification and test inputs

- Test specification: `docs/research/tick_shock/03_test_specification.md`
- Traceability: `docs/research/tick_shock/03_requirements_traceability.md`
- Independent oracle: `docs/research/tick_shock/03_test_oracle_calculation.md`
- Registry: `tests/tick_shock/spec/test_cases.csv`
- Fixtures: `tests/tick_shock/fixtures/`
- Expected results: `tests/tick_shock/expected/`
- Production facade: `mql/Include/TickShock/TickShockEngine.mqh`
- Step 4 candidate events: `reports/refactor/tick_shock/step04_candidate_events.csv`
- Step 4 candidate summary: `reports/refactor/tick_shock/step04_candidate_summary.csv`

The MQL harness loads fixture/config/expected CSVs from MT5 `FILE_COMMON`, calls
the production modules, and compares observed fields with the independent
expected files. Missing production seams are not replaced with copied test-side
formulae.

## Test runners and commands

- MQL runner: `tools/tick_shock/run_mql_harnesses.ps1`
- Python runner: `tools/tick_shock/run_python_tests.py`
- Combined runner: `tools/tick_shock/run_all_tests.ps1`

Executed commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/tick_shock/run_mql_harnesses.ps1 -TimeoutSeconds 45
python tools/tick_shock/run_python_tests.py --repo-root .
```

Step 6 exact rerun command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/tick_shock/run_all_tests.ps1 -TimeoutSeconds 45
```

## Compile evidence

| Harness | Compile log | Result |
|---|---|---|
| Domain unit | `reports/compile/tick_shock/step05_ExpectedValue_TickShock_DomainUnitHarness.log` | 0 errors, 0 warnings |
| Detector | `reports/compile/tick_shock/step05_ExpectedValue_TickShock_DetectorHarness.log` | 0 errors, 0 warnings |
| State machine | `reports/compile/tick_shock/step05_ExpectedValue_TickShock_StateMachineHarness.log` | 0 errors, 0 warnings |
| Execution | `reports/compile/tick_shock/step05_ExpectedValue_TickShock_ExecutionHarness.log` | 0 errors, 0 warnings |
| Synthetic integration | `reports/compile/tick_shock/step05_ExpectedValue_TickShock_SyntheticIntegrationHarness.log` | 0 errors, 0 warnings |
| Multi-currency merge | `reports/compile/tick_shock/step05_ExpectedValue_TickShock_MultiCurrencyMergeHarness.log` | 0 errors, 0 warnings |
| Order lifecycle | `reports/compile/tick_shock/step05_ExpectedValue_TickShock_OrderLifecycleHarness.log` | 0 errors, 0 warnings |

Tester reports and raw observations are under
`reports/tests/tick_shock/tester/` and `reports/tests/tick_shock/raw/`.

## XFAIL difference

### TS-CSV-001 / TS-KD-012

- Expected: `silent_append_allowed=false`, second attempt status
  `RUN_ID_COLLISION`, zero mixed rows, one header.
- Actual: `silent_append_allowed=true`, second attempt status `APPENDED`, two
  mixed rows, one header.
- Production function: `TSMt5OpenAppendCsv()`.
- Evidence: `reports/tests/tick_shock/raw/domain_unit.csv`.
- Step 6 file: `mql/Include/TickShock/TickShockMt5Adapter.mqh`, plus EA wiring in
  `mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5`.

## Required seven defects: observed XPASS

The following tests were required to be XFAIL, but their observed production
outputs equal the independent desired outputs:

| Test ID | Production function(s) | Observed reason |
|---|---|---|
| `TS-TIME-001` | `TSResearchEntryEligibleMsc`, `TSResearchTryEntryClock` | entry 1600 is not before processing |
| `TS-DETECT-001` | `TSResearchTryEntryClock` | stale grid boundary does not fill; next real tick 1030 fills |
| `TS-REV-001` | `TSRegisterResearchSignal`, `TSResearchTryEntryClock` | invalidation time 3000 remains immutable |
| `TS-RET-001` | `TSResearchExactLogReturn` | 250/500/1000 ms returns are independent |
| `TS-CLUSTER-001` | `TSAssignResearchMarketCluster` | 1999/2000/2001 ms cross-symbol boundaries match oracle |
| `TS-RR-001` | `TSBuildResearchTarget` | outward rounding yields RR 1.333333333333 |
| `TS-BROKER-001` | `TSProtectiveOrderDistanceFeasible` | Bid/Ask reference sides match oracle |

They remain `XPASS` until Step 6 determines whether the defects were fixed
before this requested RED baseline, or whether only the extracted core is fixed
while another production wiring path remains defective. Relabelling them as
XFAIL would falsify the executable evidence.

## SKIP and observation truth

`TS-PARTIAL-001`, `TS-RESTART-001`, `TS-RESTART-002`, server SL/TP, time-close,
position recovery, and other order lifecycle cases are SKIP because no
controlled broker/Strategy Tester deal lifecycle was injected. No SKIP is
included in PASS.

Detector percentile/Z/efficiency/baseline, commission integration,
cross-detector symbol-cluster reconciliation, and dedup are also SKIP because
Step 4 did not expose a directly callable production seam. The harness did not
copy the production calculation into test code merely to create a green result.

## Step 6 production files

At minimum Step 6 must review or extend:

- `mql/Include/TickShock/TickShockMt5Adapter.mqh` — reject same-RunId metadata collision.
- `mql/Include/TickShock/TickShockDetector.mqh` — expose percentile, Z,
  efficiency and baseline readiness as production-callable operations.
- `mql/Include/TickShock/TickShockClusterer.mqh` — expose symbol-cluster and
  duplicate-event operations.
- `mql/Include/TickShock/TickShockScenarioEngine.mqh` — expose commission/net-R integration.
- `mql/Include/TickShock/TickShockEngine.mqh` — wire the missing domain seams.
- `mql/Include/TickShock/TickShockMt5Adapter.mqh` or a dedicated order lifecycle
  module — deal aggregation, partial/cancel resolution and restart snapshot adapter.
- `mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5` — integrate
  collision/provenance behavior and verify that the XPASS core is the actual EA path.

Step 6 must not treat the sixteen XPASS results as ordinary PASS without review.

## Step 6 required inputs

- `docs/research/tick_shock/00_artifact_manifest.md`
- `docs/research/tick_shock/03_test_specification.md`
- `docs/research/tick_shock/03_requirements_traceability.md`
- `docs/research/tick_shock/03_test_oracle_calculation.md`
- `tests/tick_shock/spec/test_cases.csv`
- `tests/tick_shock/fixtures/`
- `tests/tick_shock/expected/`
- `reports/refactor/tick_shock/step04_refactor_report.md`
- `reports/refactor/tick_shock/step04_candidate_events.csv`
- `reports/refactor/tick_shock/step04_candidate_summary.csv`
- `reports/tests/tick_shock/step05_pre_fix_results.csv`
- `reports/tests/tick_shock/step05_pre_fix_red_report.md`
- all seven Step 5 MQL harnesses and `TickShockStep5TestSupport.mqh`
- all files under `tests/tick_shock/python/`
- all three files under `tools/tick_shock/` created by Step 5

## Validation boundary

The status remains:

- `RESEARCH_PIPELINE_PARTIALLY_VALIDATED`
- `EXECUTION_MODEL_NOT_CAUSALLY_VALIDATED` at broker/order lifecycle level
- `STRATEGY_FEASIBILITY_NOT_ESTABLISHED`
- `EDGE_UNDETERMINED`
- no long OOS and no optimization
