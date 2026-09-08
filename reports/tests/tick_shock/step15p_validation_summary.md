# Step 15P Validation Summary

## Scope

- Production research EA: `mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5`
- New production module: `mql/Include/TickShock/TickShockSymmetricOco.mqh`
- Deterministic harness: `mql/Experts/tests/ExpectedValue_TickShock_SymmetricOcoHarness.mq5`
- Actual orders: prohibited and observed count zero

## Compile and deterministic harness

- Research EA: 0 errors, 0 warnings
- Symmetric OCO harness: 0 errors, 0 warnings
- Symmetric OCO assertions: PASS 16, FAIL 0
- Existing full deterministic regression suite (`-Phase step15g`): PASS 407, FAIL 0, XFAIL 0, XPASS 0, SKIP 9, BLOCKED 0

The nine remaining SKIPs are terminal/server observations that did not occur.
They were not relabeled as PASS. The suite was invoked with `step15g` because
the shared runner does not yet accept a `step15p` phase name; this changes only
the evidence folder label, not the production functions exercised.

## Causality coverage

The new harness calls the same `TickShockSymmetricOco.mqh` functions used by
the research EA and checks Long and Short trigger selection, entry strictly
after the complete trigger timestamp group, ambiguous simultaneous triggers,
no-entry timeout, side-correct Bid/Ask barriers, SL gaps, the 300-second time
exit, and three/five-digit pip conversion.

## Formal-run reproducibility

The April development run and a distinct-RunId rerun each produced 428,436
scenario rows. After removing only RunId-bearing identifier text, both normalized
tables have SHA-256
`5BE622B6EC321366C98E8742275D0D4F09F25093911152497D47A473319ED4DD`.
All compared rows and fields matched.

Independent recalculation matched 108 of 108 geometry cells. Causality,
duplicate, ambiguity, cluster-provenance, arithmetic, and actual-order violation
counts were all zero.
