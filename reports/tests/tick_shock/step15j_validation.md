# Step 15J validation

- Research EA compile: 0 errors / 0 warnings (`reports/backtest/runs/20260902_ts15j_post_shock_excursion_r2_202503/compile.log`)
- Post-shock production-path harness compile: 0 errors / 0 warnings
- Post-shock harness observations: 6 PASS / 0 FAIL
  - arm
  - processing-before-t0 rejection
  - same-millisecond final-quote entry
  - Bid/Ask MFE at 30 seconds
  - directional distance hit
  - production geometry call
- Full deterministic regression: 407 PASS / 0 FAIL / 9 terminal-only SKIP
- Formal run causal violations: 0
- Duplicate episode IDs: 0
- Invalid paths: 0
- Market-cluster spans above 2,000 ms: 0
- Orders and real trades: 0
- Independent oracle: 23 PASS / 0 FAIL
- Step 15H behavior comparison: detector 21,799/21,799 with 0 mismatched rows; persistent episodes 3,151/3,151 with 0 mismatched rows

The nine remaining SKIP are unchanged terminal-only observations. No SKIP was promoted to PASS by inference.
