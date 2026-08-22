# Tick-shock Step 2 As-Is completion

## Scope

- Step: 2
- Source checkpoint commit:
  <code>5f8387029766db54e4ced2329ae434b783cc2aab</code>
- Branch:
  <code>research/tickshock-testability-refactor-20260822</code>
- Activity: read-only analysis of production/test sources and baseline evidence;
  document and manifest changes only
- Strategy logic change: none
- Compile/backtest/long OOS: not run in this documentation step

## Inputs read and SHA-256

The manifest was treated as the path authority. All mandatory inputs existed,
and their current digest matched the Step 1 manifest before Step 2 editing.

| Input | SHA-256 | Use |
|---|---|---|
| <code>docs/research/tick_shock/00_artifact_manifest.md</code> | <code>80F5B589D19FD43C1FCAF0ADD9B874D5A82C9E4755EED26AE0E82752C45BBD53</code> | Step 1 path authority; digest before Step 2 append |
| <code>reports/checkpoints/tick_shock/step01_checkpoint.md</code> | <code>8614ABBFE67A0867962C0CB20AD408C8B94EC7AB4AA4E8F4B09BD1335996A3DC</code> | branch/HEAD/exclusion boundary |
| <code>reports/checkpoints/tick_shock/step01_file_inventory.csv</code> | <code>5EFC952B6FD8A430E4FABCC49D69356AD62C625577E9391C8569AECC0167ABBC</code> | unrelated/untracked ownership inventory |
| <code>mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5</code> | <code>976148D017E067728DC8827724516A076E7561C89D8D57BCD850D40DCB54A32C</code> | research EA |
| <code>mql/Include/TickShockStateMachine.mqh</code> | <code>3F943BA650A45A5C4D7CA587C342A1AFF00D9FDF3C5533BE7AFDB5E6E173A6ED</code> | state-machine dependency |
| <code>mql/Include/TickShockResearchExecution.mqh</code> | <code>14577A74598F7974DCDD87097E83A1E1152B02D204C69CD327B8ED61F4EBA660</code> | execution-clock/RR/cluster dependency registered by the manifest |
| <code>mql/Experts/tests/ExpectedValue_TickShock_ResearchReachabilityHarness.mq5</code> | <code>E352D902FE01F7B721045175DCF139AC0B3CA0F938E2D459785B569684CCD594</code> | research harness |
| <code>mql/Experts/tests/ExpectedValue_TickShock_OrderReachabilityHarness.mq5</code> | <code>164A5C89E976E66FED7EE1AA3557DB784C7E3A8990B244F673E0C5A421F8917C</code> | order harness |
| <code>docs/research/tick_shock_scalper_csv_schema.md</code> | <code>102FBD601D14986B056600C368FE612D62AD1BD7C5400A36D58BC5F48C3F5066</code> | CSV contract |
| <code>reports/backtest/runs/20260822_tickshock_execution_revision/summary.md</code> | <code>D5C3CA7D19B9C1158C5B8A1C57AC1AACB1F023D7EA68AC81731331AE04FE2967</code> | baseline narrative |
| <code>reports/backtest/runs/20260822_tickshock_execution_revision/events.csv</code> | <code>45F01B4F54CE45ACC94A08B48391A6CCB382110096FBAC9FE4B54741D10D9D14</code> | baseline event/scenario re-analysis |
| <code>reports/backtest/runs/20260822_tickshock_execution_revision/summary.csv</code> | <code>3CED2C22045F5911445E895BD2A55386BD8CB5DA28D6606AC7C283C5FEEFA17A</code> | baseline aggregate re-analysis |
| <code>reports/backtest/runs/20260822_tickshock_execution_revision/tick_quality.csv</code> | <code>ABE0DC22294F3D584329B9069F06FA5A1DCA7683D3BC78A53F2BF989A60635AC</code> | baseline real/generated quality |

No alternative filename was inferred and no required input was missing.

## Deliverables

| Artifact | Purpose |
|---|---|
| <code>docs/research/tick_shock/02_as_is_architecture.md</code> | component/lifecycle/merge/grid/detector/event/scenario/I/O architecture |
| <code>docs/research/tick_shock/02_function_catalog.md</code> | complete mechanically reconciled function catalog |
| <code>docs/research/tick_shock/02_data_structures_and_globals.md</code> | inputs/constants/enums/structs/globals/capacities/lifetimes |
| <code>docs/research/tick_shock/02_dataflow_and_state.md</code> | detector/event/scenario/order state and time/side dataflow |
| <code>docs/research/tick_shock/02_known_defects.md</code> | baseline defects, current guards, active gaps, Step 3 test IDs |
| <code>docs/research/tick_shock/02_refactor_targets.md</code> | testability seams, modules, adapters, safe extraction order |
| <code>reports/analysis/tick_shock/step02_as_is_completion.md</code> | Step 2 provenance, reconciliation, and handoff |

The seven artifacts are appended to
<code>docs/research/tick_shock/00_artifact_manifest.md</code>. The manifest is
updated after these artifacts are hashed.

## Function reconciliation

Definitions were extracted with a multiline MQL function-definition pattern and
then validated by brace-balanced body scanning. Control statements and
prototypes were excluded.

| Source | Extracted | Cataloged | Difference |
|---|---:|---:|---:|
| Research EA | 93 | 93 | 0 |
| TickShockStateMachine.mqh | 21 | 21 | 0 |
| TickShockResearchExecution.mqh | 14 | 14 | 0 |
| Research reachability harness | 8 | 8 | 0 |
| Order reachability harness | 29 | 29 | 0 |
| **Total** | **165** | **165** | **0** |

Catalog difference: **none**.

## Source and evidence differences

- Production/test source SHA values remained identical to the Step 1 manifest
  throughout documentation.
- The baseline summary reports research EA SHA
  <code>969AC03545D02BBD3DA67EF1213DA39D6AFEDACD9C16F6E479973E123A07E6CD</code>,
  which differs from current source SHA
  <code>976148D017E067728DC8827724516A076E7561C89D8D57BCD850D40DCB54A32C</code>.
- Therefore baseline-observed defects and current-source guards are documented
  separately. The baseline is not behavioral proof for current code.
- Baseline re-analysis found 19 event rows and 7,452 stress-scenario outcomes.
  They are repeated outcomes on shared events, not 7,452 independent samples.
- The baseline confirms detector-window return mislabeling, symbol-only
  clustering, delay-0 same-signal-time fills, and TP outcomes below requested
  1.2R. Current source contains guards/corrections but lacks a whole-production-
  path synthetic test.

## Unresolved issues for Step 3

1. The research harness invokes shared state/clock/math helpers but does not feed
   synthetic ticks through <code>TSRDispatcher → TSRProcessOneTick →
   TSRCloseGridBoundary → TSRDetectShock → event/scenario</code>.
2. Need explicit production-path tests for stale grid detection, a 600 ms
   processing lag, 0/100/250 ms delays, same-ms final quote, cross-watermark
   ordering, independent 250/500/1000 returns, market clusters, outward RR, and
   Bid/Ask StopsLevel.
3. Need proof that current invariant counters remain zero:
   entry-before-eligible, entry-before-processing, stale detection fills,
   reversal signal overwrite, global order violation, duplicates, RR below
   requested.
4. Same-RunId CSV append mixing remains active and needs a collision/resume test
   before a later behavior change.
5. Actual partial fill, process restart, and server SL/TP remain unobserved.
   They must stay SKIP/NOT_OBSERVED and outside PASS totals.
6. Global watermark wait is still embedded in signal processing time. Step 3
   must lock As-Is semantics before Step 4 separates adapters; a per-symbol
   decision model is a later intentional behavior change.
7. Scenario aggregate values must be reparsed from emitted CSV and compared
   exactly with summary reducers.
8. Source/evidence provenance must include code/commit hash, config/set hash,
   MT5 build, broker/server, run identity, and tester chart symbol.

## Step 3 handoff files

Primary specifications:

- <code>docs/research/tick_shock/02_as_is_architecture.md</code>
- <code>docs/research/tick_shock/02_function_catalog.md</code>
- <code>docs/research/tick_shock/02_data_structures_and_globals.md</code>
- <code>docs/research/tick_shock/02_dataflow_and_state.md</code>
- <code>docs/research/tick_shock/02_known_defects.md</code>
- <code>docs/research/tick_shock/02_refactor_targets.md</code>
- <code>reports/analysis/tick_shock/step02_as_is_completion.md</code>

Source/test contracts:

- <code>mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5</code>
- <code>mql/Include/TickShockStateMachine.mqh</code>
- <code>mql/Include/TickShockResearchExecution.mqh</code>
- <code>mql/Experts/tests/ExpectedValue_TickShock_ResearchReachabilityHarness.mq5</code>
- <code>mql/Experts/tests/ExpectedValue_TickShock_OrderReachabilityHarness.mq5</code>
- <code>docs/research/tick_shock_scalper_csv_schema.md</code>

Baseline evidence:

- <code>reports/backtest/runs/20260822_tickshock_execution_revision/summary.md</code>
- <code>reports/backtest/runs/20260822_tickshock_execution_revision/events.csv</code>
- <code>reports/backtest/runs/20260822_tickshock_execution_revision/summary.csv</code>
- <code>reports/backtest/runs/20260822_tickshock_execution_revision/tick_quality.csv</code>

## Validation stance

- RESEARCH_PIPELINE_PARTIALLY_VALIDATED
- EXECUTION_MODEL_NOT_CAUSALLY_VALIDATED
- STRATEGY_FEASIBILITY_NOT_ESTABLISHED
- EDGE_UNDETERMINED
- Long OOS not performed
