# Independent implementation review

Verdict: **PASS**. No blocking trade-logic or causal-data finding. This is engineering review, not profitability validation.

- [Final source hashes and protected-file check](static_audit.json)
- [EA before/current diff](Wave33ChopDiagnostic.mq5.diff.txt)
- [Display adapter diff](ChopDisplay.mqh.diff.txt)
- [Independent native CSV recount](independent_native_recount.json)

All 12 protected original EA/shared engine, display, types, ledger and helper files match the pre-task SHA256 manifest. The chop formula is unchanged.

## Source review

1. PriorContext observes only the published Publish -> g_prior.Event pivot prefix. It does not fetch later internal engine state through GetObstacles. Later unpublished pivots cannot affect the current SIGNAL even with the same timestamp.
2. FeedClosed sorts by close time and larger timeframe first. Only accepted M15/H1 bars enter the source-close cache, one at a time before Drain. Later backlog bars are absent from earlier SIGNALs even when all known_at values equal the current tick. Forming/future bars are excluded in storage/evaluation.
3. Plan supplies executable quote, structural SL and final TP after W1 extension/obstacle cap. The new module does not change W1, Fib, chop, SL or TP calculations.
4. LONG uses pre-W1 M15/H1 HIGH, SHORT LOW, known by decision. Sources need not have been confirmed before W1 start. Band halfwidth uses the fixed directional span; entry, TP and source-TF close comparisons are mirrored with span*1e-12 tolerance.
5. All candidates are evaluated. Known BLOCKED wins before near/closest/H1/newest priorities. A nearer CLEAR/UNAVAILABLE candidate cannot hide a known blocker. M15/H1 observations of one move are not scored as independent touches.
6. Missing evidence allows UNAVAILABLE with reason. Invalid fraction rejects initialization. Filter ON forces observation even when diagnostic OFF.
7. Filter OFF only observes. ON and BLOCKED marks SIGNAL_RISK_REJECTED, suppressing green ENTRY in existing display code, then canonical SKIP occurs before submission. FinishUnordered releases the lane; stored setup ID prevents retry. Chop exclusion keeps precedence.
8. New inputs enter run hash/config. Tester-only guard, default orders OFF, filled trades and opposite-W1 profit exit remain intact.
9. New band/level begins at SIGNAL and ends 12 lower bars later. Trend rays are false. Retrospective source drawing cannot alter evaluation.

## Closed display finding

Final module SHA256: 909f116ab7bedc0695c8ae8fb30c0e247fcc854d6297da9eb87e060a534aa51d.

Historical connector now has its own explanatory tooltip; visible source caption explicitly says retrospective plus H1/M15/date/time/price. The initial low-severity display finding is closed. No decision calculation changed.

## Native evidence reviewed independently

Final batch run_8a9f584f: recounted 1,470 assertions from seven case CSVs; every assertion/summary is PASS. Exact fixed SIGNAL/context-SKIP/ORDER_DISABLED counts match for diagnostic ON/OFF, filter ON/OFF, blocked orders-ON and invalid fractions. No ORDER/FILL or order/fill timestamps exist. Current EA/context/harness source and harness EX5 hashes match the native manifest.

Found/reported an earlier parent-auditor typo: PRIOR_CONTEXT_FINISH_REJECTED versus actual CONTEXT_FINISH_REJECTED. Root reports corrected. Independent recount searches both, finds neither; direct lane assertions also pass. MQL assertion summaries contain unquoted semicolons in last-field detail; independent recount reconstructs that text from extra CSV fields rather than discarding it. Test/result fields and main event columns remain intact.

Harness source was independently read. It invokes actual HandleSignal on synthetic fixtures and replays stored classifier values. Orders-ON tests BLOCKED fixtures only to establish pre-submission stopping. It does not test allowed actual orders, annual profitability or complete historical FeedClosed replay. Green-arrow logic is checked in source/log state; full rendered chart/tooltip readback is outside this review. Assertion count is not market-case count.

## Limits

This is prior-level retest risk, not completed double top/bottom. Old consumed levels can remain eligible. History accrues prospectively after startup. The 5% halfwidth is an initial assumption, not optimized on the supplied image. Fixed-case skip success and QA PASS do not establish improved expectancy.
