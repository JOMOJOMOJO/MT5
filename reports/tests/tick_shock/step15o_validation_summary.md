# Step 15O validation summary

- Research EA compile: 0 errors / 0 warnings
- Cross-FX harness compile: 0 errors / 0 warnings
- Production-module harness: 13 PASS / 0 FAIL
- Analysis QA: 18 PASS / 0 FAIL
- Deterministic analysis rerun: 20 PASS / 0 mismatch
- r1/r2 behavior comparison: 3 PASS / 0 mismatch
- Independent calculations: 12 PASS / 0 FAIL / 2 NOT_OBSERVED categories
- Actual orders/trades: 0 / 0
- Formal period: April 2025 development, not OOS
- Verdict: `CROSS_FX_TRADE_EDGE_NOT_FOUND`, `OOS_VALIDATION_NOT_JUSTIFIED`, `PRODUCTION_NOT_ELIGIBLE`

The two `NOT_OBSERVED` categories are one serialized-zero sign boundary and 58
actions whose separate 900-second excursion summaries were censored at the run
boundary. They are not counted as PASS.
