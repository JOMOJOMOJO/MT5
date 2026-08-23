# Tick-shock Step 9 evidence and documentation correction

## Scope and immutability boundary

Step 9 corrects documentation, QA evidence indexes, and the artifact manifest
only. It does not change production source, test source, fixtures, expected
oracles, strategy thresholds, RR, stop grid, execution semantics, or any Step 7
run output. The work began on
`research/tickshock-testability-refactor-20260822` at
`3ab098cf5d47ca00f0c0be39d7cdd946e0a57980`; the required Step 8 commit
`06f616d7abda785d21bdc9a75de6ac6df4e9c844` is an ancestor.

The complete correction ledger is
`reports/qa/tick_shock/step09_documentation_corrections.csv`. The portable source
and test dependency rollup is
`reports/checkpoints/tick_shock/step09_source_dependency_inventory.csv`.

## Baseline source identity correction

The committed Step 1/2 baseline summary reports:

```text
EA SHA-256 = 969AC0350AA64EAA1AFFFFECCA660E8CB2FB3877F4280186215A0E89251455C3
```

That exact value is present in
`reports/backtest/runs/20260822_tickshock_execution_revision/summary.md` both at
the Step 1 and Step 2 commits. The Step 1/2 checkpoint research EA itself hashes
to `976148D017E067728DC8827724516A076E7561C89D8D57BCD850D40DCB54A32C`.
Both are complete 64-hex values. The wrong
`969AC03545D02BBD3DA67EF1213DA39D6AFEDACD9C16F6E479973E123A07E6CD`
was a documentation transcription error, not a shortened identifier.

The historical baseline EA source blob or binary matching the reported
`969AC...55C3` identity is not stored in the checkpoint. The baseline summary is
therefore authoritative for the run's reported identity, but binary/source
reconstruction remains unavailable.

## Current function and type reconciliation

A brace-balanced scan of top-level project definitions was rerun over the
current research EA, eleven canonical modules, two compatibility wrappers, and
the original research/order reachability harnesses. Step 5 harness functions are
outside this catalog scope, consistently with Step 8.

| Scope | Definitions | Catalog entries | Difference |
|---|---:|---:|---:|
| Current catalog scope | 216 | 216 | 0 |

The nine previously missing definitions are:

- `TSRRunMetadataFingerprint`
- `TSCsvOpenStatusName`
- `TSOrderEntryStateName`
- `TSMt5ReadRunMetadata`
- `TSMt5WriteRunMetadata`
- `TSMt5ExistingCsvHeaderMatches`
- `TSResetOrderFillState`
- `TSApplyEntryDeal`
- `TSResolveEntryRemainderCancel`

`02_function_catalog.md` now records exact signatures, argument units, return
values, responsibilities, globals, reference/struct side effects, production
callers, test callers, I/O boundaries, and testability for these definitions.
It also amends the current six-argument-plus-status-reference signature of
`TSMt5OpenAppendCsv` without counting that existing function twice.

`02_data_structures_and_globals.md` now records `ENUM_TS_CSV_OPEN_STATUS`,
`ENUM_TS_ORDER_ENTRY_STATE`, and `TickShockOrderFillState`. Capacity terminology
is normalized as follows:

- compile-time physical sample cap: 3,612;
- default logical 250 ms capacity: 3,610;
- default logical 500 ms capacity: 1,806;
- default logical 1,000 ms capacity: 904.

## RED/GREEN history correction

The Step 5 and Step 6 result CSVs establish one historical RED-to-GREEN
transition: `TS-CSV-001` moved from XFAIL to PASS. The seven required causal
tests (`TS-TIME-001`, `TS-DETECT-001`, `TS-REV-001`, `TS-RET-001`,
`TS-CLUSTER-001`, `TS-RR-001`, and `TS-BROKER-001`) were already XPASS at Step
5 and remained behaviorally unchanged at Step 6 PASS.

Consequently, the repository proves their desired behavior in the extracted and
wired current production paths, but it does not preserve historical
production-path RED evidence showing that Step 6 changed those seven defects.
Their fixes may predate Step 4. No fixture or expected value was changed in Step
9 to manufacture a transition.

## GBPUSD fallback-minute reconciliation

The two reported totals use different counters:

| Evidence field | Value | Meaning |
|---|---:|---|
| `tick_quality.csv:m1_minutes_seen` | 30,188 | EA-observed M1 minute counter |
| `tick_quality.csv:tester_reported_total_minutes` | 30,187 | Tester denominator for fallback reporting |
| `tick_quality.csv:tester_reported_discarded_minutes` | 179 | Tester-discarded/generated-fallback minutes |
| Tester journal | 179 / 30,187 | `real ticks discarded for 179 minutes of 30187 total minute bars` |

The formal fallback rate is therefore 179 / 30,187 = 0.5930%. The 30,188 EA
counter remains valid under its own definition and is not silently coerced to
the Tester denominator.

## Manifest rollup and ownership rule

Step 8 recalculated 393 artifact rows and 377 unique paths before appending the
four Step 8 QA artifacts. The checked-in post-Step-8 manifest consequently held
397 rows and 381 unique paths. Step 9 appends latest-hash rows for ten corrected
existing paths and three new artifacts, producing 410 rows and 384 unique paths.
Artifact ID duplicates remain zero.

The manifest header now records `manifest_revision`, `covered_steps`,
`last_audited_commit`, and `last_updated_at`. From Step 10 onward, each new row
must carry `owning_commit`; use a full 40-character commit when known. A row
created in the same commit may use `SELF`, defined as the first commit that
introduces that artifact path, and the next rollup must resolve it to the full
hash. Historical rows remain attributable through Git history and are not
rewritten merely to add a column.

## Source dependency inventory

The inventory contains 301 tracked dependencies:

- the research EA, reference scalper, all canonical/compatibility includes;
- ten MQL Tick-shock harnesses and their shared support include;
- the Step 3 test registry, all 128 fixture files, and all 64 expected files;
- all tracked Tick-shock `.set` presets and `.ini` tester/harness configs;
- Python tests, MQL/Python runners, comparison/reconciliation tools;
- canonical compile/backtest/validation scripts and the CSV schema.

Each row records path, role, SHA-256, owning Step, first-add commit, and whether
it is a current compile dependency or historical reproduction input. Relative
MQL directory structure must be retained when compiling in another environment.
Environment-specific MT5/MetaEditor executable paths are not repository
artifacts and must be supplied by that environment.

## Immutability and integrity verification

Before Step 9, all 26 tracked Tick-shock MQL production/test files were hashed
as sorted `path,SHA-256` rows. Their aggregate SHA-256 was:

`970AD6BB7DF09CD4FCB5BD1A6F6E1611441313C9A82DB415D0DF4433D70DC9EC`

The same 26 files and aggregate are required after Step 9. Git diff must show no
MQL path changes.

The Step 3 normative registry/oracle set contains 193 files: one registry, 128
fixtures, and 64 expected files. Its sorted path/hash aggregate is:

`FCFF2F3198DE2D83C70F27D52377ED7B78E936E881AD11D5C894E89F8D29B10A`

`git diff` from Step 3 commit
`672c18a85838e91f63c3247cccc82243037254ff` is empty for those paths.

Final Step 9 gates are:

- current definitions/catalog: 216/216;
- manifest duplicate artifact IDs: 0;
- manifest latest-path SHA mismatches: 0;
- Step 3 normative path changes: 0;
- production/test MQL path changes: 0.

## Unresolved matters and unchanged validation stance

- The reported baseline EA identity lacks a matching archived binary/source blob.
- The seven Step 5 XPASS causal tests lack preserved historical RED evidence.
- Actual broker partial fill, server SL/TP, restart recovery, and actual
  commission evidence remain outside this documentation correction.
- GBPUSD retains 179 generated-fallback minutes under the Tester's definition.
- Step 9 does not authorize long OOS, optimization, strategy promotion, or live
  trading. `EDGE_UNDETERMINED` and the Step 8 promotion blockers remain.

## Step 10 required reading

Control and corrections:

- `docs/research/tick_shock/00_artifact_manifest.md`
- `docs/research/tick_shock/09_evidence_and_documentation_correction.md`
- `reports/qa/tick_shock/step09_documentation_corrections.csv`
- `reports/checkpoints/tick_shock/step09_source_dependency_inventory.csv`

Corrected As-Is and QA records:

- `docs/research/tick_shock/02_as_is_architecture.md`
- `docs/research/tick_shock/02_known_defects.md`
- `docs/research/tick_shock/02_function_catalog.md`
- `docs/research/tick_shock/02_data_structures_and_globals.md`
- `reports/analysis/tick_shock/step02_as_is_completion.md`
- `reports/tests/tick_shock/step03_test_spec_review.md`
- `reports/tests/tick_shock/step05_pre_fix_red_report.md`
- `reports/tests/tick_shock/step05_pre_fix_results.csv`
- `reports/tests/tick_shock/step06_post_fix_green_report.md`
- `reports/tests/tick_shock/step06_post_fix_results.csv`
- `docs/research/tick_shock/08_final_qa.md`
- `reports/qa/tick_shock/step08_final_qa_findings.csv`
- `reports/qa/tick_shock/step08_traceability_audit.csv`
- `reports/qa/tick_shock/step08_recalculation.csv`

Normative tests and current source:

- `tests/tick_shock/spec/test_cases.csv`
- `tests/tick_shock/fixtures/`
- `tests/tick_shock/expected/`
- `mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5`
- `mql/Include/TickShock/`
- `mql/Include/TickShockStateMachine.mqh`
- `mql/Include/TickShockResearchExecution.mqh`
- `mql/Experts/tests/`

Formal Step 7 evidence:

- `reports/backtest/runs/20260822_tickshock_causal_ideal_202503/`
- `reports/backtest/runs/20260822_tickshock_causal_realizable_202503/`
- `reports/backtest/runs/20260822_tickshock_causal_comparison_202503/`
