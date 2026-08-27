# Step 15B control/funnel executable specification

## Status and oracle rules

The fixture/expected CSVs are the independent oracle. Production functions may
not generate expected values. `PASS` means an observed production-path value
matches its frozen expected row. `XFAIL` is allowed only in the pre-implementation
RED record. `FAIL`, `XPASS`, `BLOCKED` and unexplained `SKIP` must be zero at
the final gate.

All time comparisons are integer milliseconds; exact matches have zero
tolerance. Floating outcomes use the tolerance declared in each expected CSV.
Blank means unavailable and is never coerced to zero.

## Requirements and tests

| Requirement | Tests | Independent oracle |
|---|---|---|
| TS15B-REQ-DIR-001 direction schema and causality | TS15B-DIR-SCHEMA-001, TS15B-DIR-POS-001, TS15B-DIR-NEG-001, TS15B-DIR-CONFLICT-001, TS15B-DIR-PERSIST-001, TS15B-DIR-FUTURE-001 | selected signed return at candidate time; ties use shorter horizon |
| TS15B-REQ-CTRL-001 bounded outcome completion | TS15B-CTRL-COMPLETE-001, TS15B-CTRL-INCOMPLETE-001, TS15B-CTRL-SAMEMSC-001, TS15B-CTRL-CAP-001, TS15B-CTRL-DROP-001 | explicit millisecond sequence and fixed capacity |
| TS15B-REQ-MATCH-001 exact closest-earlier match | TS15B-MATCH-EXCLUDE-001, TS15B-MATCH-CLOSEST-001, TS15B-MATCH-DIM-001, TS15B-MATCH-NORELAX-001, TS15B-MATCH-UNMATCHED-001, TS15B-MATCH-TIE-001, TS15B-MATCH-REUSE-001, TS15B-MATCH-DUP-001 | lexicographic exact key, strict >120000 ms, maximum timestamp below event |
| TS15B-REQ-FUNNEL-001 observed conversion | TS15B-FUNNEL-FIRST-001, TS15B-FUNNEL-ALL-001, TS15B-FUNNEL-RECON-001, TS15B-FUNNEL-ELIG-001 | frozen predicate order; production common eligibility unchanged |
| TS15B-REQ-CF-001 isolated four-strategy reachability | TS15B-CF-STATE-001, TS15B-CF-CAUSAL-001, TS15B-CF-OVERLAP-001, TS15B-CF-COUNT-001 | isolated context, entry clock inequalities, cluster not scenario-cell count |
| TS15B-REQ-REG-001 exact regression/provenance | TS15B-IDENTITY-001, TS15B-PROV-001 | Step 15A archived identity and fixed hashes |

## RED expectation

Before Step 15B production implementation, `TickShockControlStudy.mqh` and its
production-callable API do not exist and the feature header lacks `direction`.
The schema test and 28 production-path tests must therefore be observed as
XFAIL, not inferred PASS. The GREEN run compiles and executes the same harness
against the production module.

