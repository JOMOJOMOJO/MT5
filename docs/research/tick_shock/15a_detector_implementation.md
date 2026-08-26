# Step 15A detector implementation and GREEN evidence

## Scope

This change adds the frozen `STAT_SHOCK_V1` family to the research-only EA.
It does not add `OrderCheck` or `OrderSend`, and it does not change burst,
pullback, reacceleration, reversal, stop-grid, delay-grid, spread-stress, RR,
or maximum-hold logic.

The selector defaults to `STRICT_V0`. The V0 branch still calls the original
`TSRDetectShock()` gate path. V1 branches call the statistical detector only
after the final quote for a 250 ms grid boundary is known.

## Production modules

- `mql/Include/TickShock/TickShockStatisticalDetector.mqh` contains pure,
  deterministic calculations used by production and the MQL harness.
- `mql/Include/TickShock/TickShockStatisticalCalibration.mqh` owns the bounded
  causal return ring, local bipower state, conditional calibration cells, and
  fixed-bin Fenwick histograms used by production.
- `mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5` wires the
  selector, causal boundary observation, event creation, persistence clock,
  event-level feature serialization, and summary counters.

Each symbol owns at most 3,612 V1 boundary records. Tail state is an expanding
bounded histogram keyed by estimator, horizon, four-hour server-time bucket,
and volatility regime; it does not retain unbounded ticks or raw time-series
CSV. `detector_features.csv` is exactly one row per completed event.

## Causal order

At boundary `t`, production first closes the same-millisecond quote group,
computes raw and causal pre-averaged Mid, advances the local pool only through
`t-2000`, inserts only scores whose timestamps are at most `t-2000`, and then
queries the current conditional empirical tail. Persistent candidates can
signal only at `t+250`; their signal time is never reassigned to the candidate
time.

## RED to GREEN

- RED: 1 PASS / 23 XFAIL / 0 unexpected FAIL. The V1 include/API was absent.
- GREEN detector contract: 25 PASS / 0 FAIL / 0 XFAIL / 0 XPASS / 0 SKIP.
- Full deterministic suite: 111 PASS / 0 FAIL / 0 XFAIL / 0 XPASS / 9 SKIP.
  The nine SKIP rows remain terminal-only observations and were not promoted.
- Compile: research EA and all 11 Tick-shock harnesses completed with
  0 errors / 0 warnings.

Fixtures and expected files were unchanged between the committed RED evidence
and GREEN execution. `reports/qa/tick_shock/step15a_green_hashes.csv` records
the source, fixture, expected, harness, and executable-specification hashes.

## Diagnostic separation

V1 tail acceptance is recorded as `statistical_shock`. Efficiency, activity,
liquidity, and cost feasibility are recorded independently and do not erase a
statistical event. Statistical outcome tracking uses a bounded lightweight
event record; the unchanged downstream state machine and 552-scenario grid are
allocated only when the independent strategy diagnostics are also satisfied.
This separation was added after the first V1 March attempt exhausted the heavy
event pool 2,742 times. `TS15A-SEPARATION-001` now exercises the production
eligibility function directly and proves that a tail event is retained without
allocating a strategy event. This changes research storage, not the frozen tail
formula, alpha, strategy gates, or strategy outcomes.

## Status boundary

This establishes implementation correctness against the predeclared oracle.
It does not establish detector suitability, trading expectancy, formal net
expectancy, or production readiness. Those decisions require the four
predeclared March development runs and the matched-control/cluster analysis.
