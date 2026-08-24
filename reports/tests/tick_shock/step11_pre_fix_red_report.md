# Step 11 pre-fix RED report

- Base commit: `f335fbbab0a14a13b4ced00bdf1cce6972900726`
- Production EA: `mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5`
- Production EA SHA-256: `D33CF37A0534F812112F29EC01F1463A6AFB816740BECC8DE23E561D7E17A539`
- Registry: `tests/tick_shock/spec/test_cases.csv`
- Oracle: `docs/research/tick_shock/11_test_oracle_addendum.md`
- Fixtures: `tests/tick_shock/fixtures/`
- Expected: `tests/tick_shock/expected/`
- Harness: `mql/Experts/tests/ExpectedValue_TickShock_IntegrityRegressionHarness.mq5`
- Raw evidence: `reports/tests/tick_shock/step11_raw/`
- Result: `reports/tests/tick_shock/step11_pre_fix_results.csv`

## Result

90 registered tests: PASS 55, FAIL 0, XFAIL 24, XPASS 1, SKIP 9,
BLOCKED 1. All eight MQL harnesses compiled with 0 errors and 0 warnings.

`TS-COMM-003` is XPASS: commission R 0.07 is already applied once, producing
net R 0.93. `TS-CURSOR-001` is BLOCKED by the absent production cursor seam.
The remaining 24 new cases reproduce their desired/actual differences in
`step11_pre_fix_results.csv`. Server SL/TP, time close, position recovery, and
process restart remain NOT_OBSERVED rather than PASS.

Step 12 must change production files only for config, metrics/commission, run
identity and CSV ownership, event/merge integrity, typed status/direction, order
lifecycle, and EA OnInit/summary/frontier/cursor wiring. Fixtures, expected CSVs,
Test IDs, and the oracle are immutable Step 12 inputs.
