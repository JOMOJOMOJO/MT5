# Tick-shock Step 5: executable specification baseline

Step 3 fixtures and independent expected outputs were converted into seven MQL
harnesses and ten Python evidence checks. All harnesses compile with zero errors
and zero warnings, and the combined 64-Test-ID result has no unexpected FAIL.

The important finding is that the requested seven pre-fix defects did not
reproduce in the Step 4 production core: they are XPASS. The same-RunId append
collision did reproduce as XFAIL. Missing detector and order lifecycle seams
remain SKIP rather than being replaced by copied test formulae or unobserved
PASS claims.

Evidence:

- `reports/tests/tick_shock/step05_pre_fix_results.csv`
- `reports/tests/tick_shock/step05_pre_fix_red_report.md`
- `reports/tests/tick_shock/raw/`
- `reports/compile/tick_shock/step05_*.log`

This is a testability result, not an edge result or broker execution validation.
