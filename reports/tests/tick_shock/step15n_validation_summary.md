# Step 15N validation summary

- Research EA compile: 0 errors, 0 warnings
- Delayed-decision harness compile: 0 errors, 0 warnings
- Harness: 11 PASS, 0 FAIL
- Analysis QA: 14 PASS, 0 FAIL
- Independent checkpoint recalculation: 4 PASS, 0 FAIL
- Deterministic CSV rerun: 23 PASS, 0 FAIL
- Formal run: 2025-03-01 through 2025-04-01, EURUSD M1 driver, six symbols, real-tick mode
- Orders/trades: 0/0
- Causal-clock violations: 0
- Fold/cluster/chronology violations: 0
- TP/SL frozen-R violations: 0/0
- Capacity/drop/stall violations: 0/0/0
- GBPUSD generated fallback: 179/30,187 minutes; interval map unavailable
- Result: DELAYED_ENTRY_TRADE_EDGE_NOT_FOUND; OOS_VALIDATION_NOT_JUSTIFIED; PRODUCTION_NOT_ELIGIBLE

Primary evidence is under `reports/analysis/tick_shock/step15n/` and
`reports/backtest/runs/20260906_ts15n_delayed_decision_r2_202503/`.
