# Step 15B strategy conversion funnel specification

## Observation rows

One row is written per statistical event. Required booleans are:

```text
statistical_shock,direction_available,directional_burst,activity_elevated,
liquidity_normal,cost_feasible,common_strategy_eligible,
detection_continuation_reachable,post_burst_continuation_reachable,
pullback_continuation_reachable,failed_shock_reversal_reachable,strategy_signal
```

Rows also store event/detector/cluster identity, candidate and confirmed clocks,
representative flag, eligibility/pattern/entry clocks, execution feasibility,
first fail, ordered all fails, no-trade reason and overlap/cooldown status.

## First/all fail oracle

First fail uses the fixed observation order in the pre-analysis. All fail lists
every false predicate in that order, separated by `|`. A false strategy-specific
reachability flag does not mutate common eligibility. Parallel conditions stay
parallel in production.

For each aggregation slice:

```text
input = passed + excluded
strategy_signal + no_strategy_signal = input
representative + overlap = input
```

No row, scenario cell or overlapping event is silently discarded.

## Counterfactual evaluator

The evaluator calls the same production state-machine/action and causal-entry
primitives as the normal research path, but uses an isolated diagnostic
context. It independently observes the four frozen strategies for each market
cluster representative without bypassing any strategy-specific rule. It may
not allocate a production event, modify cooldown, start an order, or feed a
result back into the detector.

Pattern, causal entry, cost feasibility and outcome are separate columns.
Cluster counts are primary. Scenario-grid cell counts are labeled as cells,
not trades. Before/after overlap and cooldown are both retained. Diagnostic R
uses only the existing RR/SL/delay/spread grid and remains cost-incomplete.

## Formal interpretation

Low conversion alone is not evidence that a strategy is too strict. Unless a
detector passes the exact matched-control gate, the only allowed funnel status
is `DETECTOR_NOT_VALIDATED_FUNNEL_DIAGNOSTIC_ONLY`. No Step 15B funnel result
authorizes a new entry rule, tuning, OOS or production trading.

