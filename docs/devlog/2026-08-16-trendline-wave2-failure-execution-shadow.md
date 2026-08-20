# TRENDLINE_WAVE2_FAILURE execution connection and expiry shadow

## Change

- Protected-break detection/MA filtering and state/candidate progression were separated.
- `TW2FEvaluateM15()` now owns the explicit sequence from continuation failure to structure broken, execution candidate construction, entry ready, and final `candidate.valid` gate.
- Candidate creation emits a dedicated CSV milestone in addition to state transitions.
- The six pattern tests were renamed to pattern-classification reachability tests.
- Two Long/Short end-to-end state tests were added with candidate-field assertions.
- A non-trading 240-H1-bar shadow observer was added for setups closed by the unchanged H1 expiry.

## Locked validation

- Compile: [0 errors / 0 warnings](../../reports/compile/trendline_wave2_failure_execution_shadow.log)
- 2024 report: [final report](../../reports/backtest/runs/20260816_trendline_wave2_failure_execution_shadow/final-report.md)
- Strategy parameter changes: 0
- Pattern tests: 6/6
- End-to-end M15 path tests: 2/2
- Real trades/orders: 0/0
- 2026 rerun: not performed

## Shadow finding

The sole 2024 expired H1 reversal setup formed its first M15 counter-structure and shadow anchor 30 trading H1 bars after expiry, at 103 H1 bars after the H1 break. The H1 Wave-1 origin broke later. This is a useful expiry hypothesis, not sufficient evidence to change 72 because the sample size is one.

## Decision

Keep H1 expiry at 72. Collect more shadow observations before testing an expiry extension. The shadow remains diagnostic-only and has no order path.

