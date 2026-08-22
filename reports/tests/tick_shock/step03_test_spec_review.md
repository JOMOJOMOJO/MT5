# Tick-shock Step 3 test-spec review

## Scope

- Branch: <code>research/tickshock-testability-refactor-20260822</code>
- Input HEAD: <code>ebb123106b8d7059ec6fc0a416d73e61e697921a</code>
- Step purpose: independent test inputs and expected results only
- Production source changed: no
- Existing test source changed: no
- Tests/backtests executed: no; statuses below are planned current expectations

## Inputs read

| Path | SHA-256 |
|---|---|
| <code>docs/research/tick_shock/00_artifact_manifest.md</code> | <code>6EE4ACB1017273510C0B2D353C93883E7217595A67A32FDA04E7D55D76822B0E</code> |
| <code>reports/analysis/tick_shock/step02_as_is_completion.md</code> | <code>D8852C6EBBE545CB2C5AD2C06646F5E4AE6EE4D5003BD00D00EBF6DEB5A3C844</code> |
| <code>docs/research/tick_shock/02_as_is_architecture.md</code> | <code>73A3961343AA298663BB288E3F30090AAB51EB251E88CFD847F06AFDA084CD8B</code> |
| <code>docs/research/tick_shock/02_function_catalog.md</code> | <code>88971062E4FBE49D9852F2F19FA254F82348279B82B89F8D0ADD5B9C8F8F28F9</code> |
| <code>docs/research/tick_shock/02_data_structures_and_globals.md</code> | <code>807313A51C42077148938081C34FDF09ED14CB074DD916EA0B82FBE677BCDD53</code> |
| <code>docs/research/tick_shock/02_dataflow_and_state.md</code> | <code>19DB8BF09AE3E0B956C658F99FFB73F0FE3F736A5C4E0C933EA0718B19FC0A70</code> |
| <code>docs/research/tick_shock/02_known_defects.md</code> | <code>F7174D68DB9F72852ED08310DCF2EE84D2915A6DA0D70BFC3B3F058DA2B146C6</code> |
| <code>docs/research/tick_shock/02_refactor_targets.md</code> | <code>2CA081BB31A49224CC76A1CC63C7C0333E20D03A930328C88758AEA240AF2F73</code> |

All eight required paths existed. No alias or inferred replacement path was
used.

## Created inventory

| Item | Count |
|---|---:|
| Test IDs | 64 |
| Requirement IDs | 40 |
| Referenced Defect IDs | 14 / 14 |
| Tick fixture files | 64 |
| Config fixture files | 64 |
| Total fixture files | 128 |
| Expected files | 64 |
| Missing fixture/expected/config paths | 0 |
| Duplicate Test IDs | 0 |
| Unknown Function IDs in traceability | 0 |

Every tick fixture has the exact header:

<pre>
sequence,symbol,time_msc,bid,ask,processing_msc,note
</pre>

Every expected file has the exact header:

<pre>
field,expected_value,tolerance,unit,note
</pre>

Every config contains
<code>production_function_used_for_expected=false</code>.

## Planned current statuses

| Status | Count | Meaning in this review |
|---|---:|---|
| PASS | 31 | Current helper/definition is expected to match once Step 5 implements the test; not executed in Step 3 |
| XFAIL | 27 | Missing injectable production path or an active/guarded defect prevents present proof |
| SKIP | 6 | Actual server/process observation is required and may not be claimed as PASS |

### Current XFAIL plan

- TS-TIME-001
- TS-DETECT-001
- TS-MERGE-001
- TS-REV-001
- TS-RET-001
- TS-BASE-001
- TS-BASE-002
- TS-STATE-LONG-001
- TS-STATE-SHORT-001
- TS-EXEC-LONG-001
- TS-EXEC-SHORT-001
- TS-RR-001
- TS-COMM-001
- TS-BROKER-001
- TS-SAMEMSC-001
- TS-MULTI-001
- TS-MERGE-002
- TS-CLUSTER-002
- TS-DUP-001
- TS-CSV-001
- TS-PROV-001
- TS-ORDER-001
- TS-ORDER-002
- TS-PARTIAL-001
- TS-ORDER-003
- TS-POSITION-001
- TS-RESTART-002

### Current SKIP plan

- TS-SERVER-SL-LONG-001
- TS-SERVER-SL-SHORT-001
- TS-SERVER-TP-LONG-001
- TS-SERVER-TP-SHORT-001
- TS-TIME-CLOSE-LONG-001
- TS-TIME-CLOSE-SHORT-001

SKIP must include <code>NOT_OBSERVED</code> or the exact unmet precondition and
must not increment PASS.

## Hand-calculation review

The following expected values were independently recomputed using literal
arithmetic and standard natural logarithm only:

| Check | Result |
|---|---|
| REALIZABLE eligibility maximum | PASS |
| 250/500/1000 ms independent log returns | PASS |
| Type-7 percentile | PASS |
| Robust Z and noise-floor scale | PASS |
| Directional efficiency | PASS |
| Spread-stressed Bid/Ask | PASS |
| Adverse Long entry rounding | PASS |
| Outward realized RR | PASS |
| Commission R | PASS |
| TP limit R | PASS |
| Long/Short SL gap R | PASS |
| Time-exit R | PASS |
| Multiple-deal weighted fill | PASS |
| Partial-fill weighted fill | PASS |
| Broker Bid/Ask distance inequalities | PASS |
| Policy masks 0/1/2/3 | PASS |

Machine check result: 16/16 reviewed calculation groups matched their static
expected files. No production MQL function or baseline outcome was invoked.

## Review observations

- The suite separates correctness from edge. No PASS/XFAIL/SKIP is evidence of
  profitable expectancy.
- Boundary cases cover delay −1/equality/+1, quiet/max/timeout equality,
  pullback thresholds, detector thresholds, and 1,999/2,000/2,001 ms clusters.
- Long/Short paths use explicit Bid/Ask sides.
- Absence is represented as blank/invalid, never silently as zero.
- Same-RunId append isolation and current-run provenance remain explicit XFAILs.
- The Step 2 architecture document contains a shortened baseline SHA in one
  sentence; this review uses the full authoritative SHA from
  <code>02_known_defects.md</code> and <code>step02_as_is_completion.md</code>.
  Step 4 must use the full SHA shown in TS-PROV-001.

## Step 4 handoff

Normative Step 3 inputs:

- <code>docs/research/tick_shock/03_test_specification.md</code>
- <code>docs/research/tick_shock/03_requirements_traceability.md</code>
- <code>docs/research/tick_shock/03_test_oracle_calculation.md</code>
- <code>tests/tick_shock/spec/test_cases.csv</code>
- <code>tests/tick_shock/fixtures/</code>
- <code>tests/tick_shock/expected/</code>
- <code>reports/tests/tick_shock/step03_test_spec_review.md</code>

As-Is/refactor inputs:

- <code>docs/research/tick_shock/02_refactor_targets.md</code>
- <code>docs/research/tick_shock/02_known_defects.md</code>
- <code>mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5</code>
- <code>mql/Include/TickShockStateMachine.mqh</code>
- <code>mql/Include/TickShockResearchExecution.mqh</code>
- <code>mql/Experts/tests/ExpectedValue_TickShock_ResearchReachabilityHarness.mq5</code>
- <code>mql/Experts/tests/ExpectedValue_TickShock_OrderReachabilityHarness.mq5</code>

Step 4 must preserve every fixture/expected value while exposing the shared
production path. Defect corrections are separate from behavior-preserving
extraction.
