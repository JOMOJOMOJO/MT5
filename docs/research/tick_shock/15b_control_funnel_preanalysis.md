# Tick-shock Step 15B control/funnel pre-analysis addendum

## Document control

- Step: `15B`
- branch: `research/tickshock-step15b-control-funnel-20260827`
- base HEAD: `9df6825bc30e928048bd7f5e7fbec6f9608f9f44`
- frozen detector source commit: `ec1a65d8a37d573161bb96b4e91ffdd49e51ccff`
- frozen detector specification: `docs/research/tick_shock/15a_shock_definition_spec.md`
- specification SHA-256: `53DB75EEE4641D98F4917E74B9C26B84D07533CE8EA1A6689AF7F36BAAEA64EA`
- Step 15A formal EX5 SHA-256: `97BF63EF929EDE4B16DEA68DC827A3606F7D802B7A07BF4859DE45FAC173EA46`
- development window: `2025-03-01 through 2025-04-01`
- status at registration: `PREDECLARED_BEFORE_STEP15B_CONTROL_OUTCOMES`
- locked/long OOS and optimization: `NOT_AUTHORIZED`

This addendum was fixed after the Step 15A March counts were known but before
any non-event 120-second outcome was recorded or matched. The decisions below
that were absent from Step 15A are explicitly marked:

`ENGINEERING_ASSUMPTION_REGISTERED_AFTER_STEP15A_COUNTS_BUT_BEFORE_CONTROL_OUTCOMES`.

## 1. Evidence already known

The source, tests and exact March replay established the frozen detector math,
causal anchors, event/strategy separation and these development counts:

| detector | raw candidates | statistical events | market clusters | strategy events |
|---|---:|---:|---:|---:|
| STRICT_V0 | 62,577 | 19 | 15 | 19 |
| TAIL_V1_RAW | 173,869 | 56,674 | 29,180 | 40 |
| TAIL_V1_NOISE_ROBUST | 74,415 | 23,825 | 11,409 | 10 |
| TAIL_V1_PERSISTENT | 74,415 | 21,799 | 10,245 | 10 |

The formal status is `NO_DETECTOR_CANDIDATE_PASSED`, specifically
`FAIL_MATCHED_CONTROL_EVIDENCE_MISSING`. The synthetic Gaussian-null check
passed, but it is not evidence that event outcomes differ from real FX
non-events. Strategy diagnostics are cost-incomplete and do not establish an
edge.

## 2. Frozen detector and execution behavior

Step 15B does not change any detector ID, return horizon, Mid, robust kernel,
local scale, bipower formula, causal 15-minute pool ending at `t-2000`, 10,000
tail calibration, four-hour bucket, volatility regime, empirical rank, Holm
alpha, persistence, severity, clustering, burst/pullback/reacceleration/
reversal, four strategy definitions, RR, stop/delay/spread grids, barrier
ordering, 120-second exit or Bid/Ask/slippage model. The specification hash
therefore remains the Step 15A hash. Feature schema versioning is a serialization
change, not a detector revision.

## 3. Frozen matched-control rule

The matching unit is one deterministic representative event per market
cluster. The representative is the earliest confirmed event; equal timestamps
use symbol lexical order, then detector horizon ascending, then event ID.
The exact key is `(detector_id, symbol, four_hour_server_bucket,
trigger_horizon_ms, estimator, volatility_regime)`.

A control must:

1. be a real fixed-grid boundary earlier than the representative event;
2. have the exact key above;
3. have Holm-adjusted p greater than `0.01` (not over the adjusted 99.0
   boundary);
4. be more than 120,000 ms from every same-detector statistical market
   cluster;
5. have an integrity-valid, complete 120-second outcome;
6. be the closest eligible earlier boundary.

No dimension, p boundary or shock-distance constraint may be relaxed.
Closest-earlier ties use the smallest boundary timestamp, then the smallest
control candidate ID. The same control may be reused by later clusters; reuse
is reported and inferential effective sample size remains the number of unique
matched market clusters, with a sensitivity view using unique controls.

Control reuse and the final ID tie-break were not specified in Step 15A. They
are `ENGINEERING_ASSUMPTION_REGISTERED_AFTER_STEP15A_COUNTS_BUT_BEFORE_CONTROL_OUTCOMES`.

There is no statistical maximum time difference. The recorder is streaming:
after an outcome matures and passes the shock-exclusion rule, only the latest
eligible record per exact key plus explicit audit counters is retained in
memory. This preserves closest-earlier matching without an age relaxation or
an unbounded boundary log. If the needed exact-key state was evicted or lost,
the event is unmatched with a capacity/integrity reason and the run fails
closed. This implementation choice is also an assumption registered at the
same pre-outcome point.

## 4. Causal boundary and outcome calculation

At boundary `u`, only fields available at `u` may arm a potential control:
quote, signed returns, p-values, local scale, regime, spread, tick activity and
integrity. Future values never alter detector candidate/confirmed time,
direction, strategy state or entry.

At or after `u+120000`, the research-only outcome may mature. The first valid
fixed-grid observation at or after 1/3/10/30/120 seconds supplies each absolute
log return. Realized volatility is the square root of the sum of squared
successive valid 250-ms log returns through 120 seconds. MFE/MAE use the
control direction and Mid only as research outcomes. Spread change is final
Ask-Bid minus initial Ask-Bid; tick activity is the causal count over the
window; quote reversion is adverse signed displacement divided by the absolute
triggering displacement. The comparison value for cluster duration uses the
same elapsed-ms definition as the event cluster.

An end-of-period candidate without all required 120-second observations is
`INCOMPLETE_END_OF_RUN`, never a complete control. Capacity hit, duplicate ID,
drop and eviction are counted separately. Any unexplained loss sets
`VALIDATION_INVALID`.

## 5. Support and unmatched policy

Unmatched representatives remain in coverage evidence with one primary reason;
they are not imputed or removed from the match-rate denominator. A detector has
adequate support only when it has at least 30 matched representative clusters,
at least 80% match rate, at least 20 unique controls, no unexplained integrity
loss, and at least three symbols represented. These support constants are
`ENGINEERING_ASSUMPTION_REGISTERED_AFTER_STEP15A_COUNTS_BUT_BEFORE_CONTROL_OUTCOMES`.
Failure produces `CONTROL_SUPPORT_INSUFFICIENT`; matching is not loosened.

## 6. Strategy conversion funnel

The observation order used solely to assign `first_fail_reason` is:

1. `statistical_shock`
2. `direction_available`
3. `directional_burst`
4. `activity_elevated`
5. `liquidity_normal`
6. `cost_feasible`
7. `common_strategy_eligible`
8. any of the four strategy reachability flags
9. `strategy_signal`

`all_fail_reasons` lists every false predicate in this fixed order. This does
not turn parallel diagnostics into production gates. The production common
eligibility expression stays byte-for-byte behaviorally equivalent.

Rows retain candidate/confirmed/eligibility/pattern/causal-entry clocks,
representative status, execution feasibility, no-trade reason and overlap/
cooldown status. Counts reconcile at detector, cluster, event, symbol,
direction, severity, horizon, time bucket, volatility regime, spread,
efficiency and activity slices.

## 7. Counterfactual reachability

For every representative cluster, the production state-machine/action logic is
fed the same quotes in a research-only context for detection continuation,
post-burst continuation, pullback continuation and failed-shock reversal.
The common ingress result is observed but is not used to suppress these four
diagnostic paths. No counterfactual action mutates production event allocation,
cooldown, scenario or order state.

Pattern reachability, causal quote reachability, broker/cost feasibility and
outcome are separate. Multiple strategies may be reachable for one cluster.
Primary counts are unique market clusters; scenario cells are never called
trades. Potential trades are reported before and after the unchanged global
overlap/cooldown policy. Existing scenario-grid outcomes remain cells and are
reported only as diagnostic distributions.

## 8. Direction contract

Direction is the sign of the signed return for the horizon selected by minimum
Holm-adjusted p; exact adjusted-p ties select the shorter horizon, matching the
frozen Step 15A trigger rule. Positive is `LONG`, negative is `SHORT`, zero,
invalid or absent is `INVALID`. PERSISTENT retains the candidate direction and
does not infer or backdate direction at confirmation. Outcome or strategy data
cannot supply direction.

## 9. Statistical families

Primary outcomes are 1-second absolute return, 3-second absolute return and
120-second realized volatility. Secondary outcomes are 10/30/120-second
absolute return, MFE, MAE, spread change, tick activity, quote-reversion ratio
and cluster-duration difference. The chronological stationary bootstrap uses
10,000 replicates, mean block length four and seed `20260826`. The primary
family is the frozen detector x severity x three-outcome family and receives
Holm correction. Secondary hypotheses receive BH FDR at q=0.05. Every row
stores hypothesis/family IDs, raw/adjusted p, effect and 95% interval.

Synthetic null and real event-minus-control statuses remain distinct. Strategy
P/L is excluded from detector selection.

## 10. GBPUSD fallback sensitivity

The primary replay remains unchanged. Window-level overlap is recorded only
where the tester exposes exact fallback-minute provenance. Zero and unknown are
not conflated. Separate sensitivity rows exclude known-overlap pairs and all
GBPUSD pairs. If the platform exposes only the aggregate 179/30,187 minutes,
exact window exclusion is `NOT_OBSERVABLE` and cannot be fabricated; the
all-GBPUSD exclusion remains available.

## 11. Allowed decisions and claim boundary

Allowed detector statuses are `CONTROL_SUPPORT_INSUFFICIENT`,
`NO_DETECTOR_CANDIDATE_PASSED`, or—only after all frozen support, primary
effect, concentration and sensitivity gates pass—
`SHOCK_DEFINITION_STATISTICALLY_SUPPORTED_ON_DEVELOPMENT_DATA` together with
`DETECTOR_CANDIDATE_SELECTED_FOR_LOCKED_VALIDATION`.

The funnel may be called a bottleneck only when the detector is supported and
all stated funnel conditions pass. Otherwise it is
`DETECTOR_NOT_VALIDATED_FUNNEL_DIAGNOSTIC_ONLY`. All strategy outcomes remain
`DEVELOPMENT_DIAGNOSTIC_ONLY`, `COST_MODEL_INCOMPLETE`,
`FORMAL_NET_EXPECTANCY_UNAVAILABLE`, and `EDGE_UNDETERMINED`.

Unverified areas include actual commission completion, live broker execution,
locked/long OOS, production trading, threshold stability beyond March, exact
fallback windows if the tester does not expose them, and any new strategy.

## 12. Resource envelope

- No tick CSV and no unbounded boundary CSV.
- At most 512 active 250-ms outcome slots per symbol plus one latest mature
  control per exact key; all capacities and evictions are explicit.
- Six-symbol active-control memory target: below 16 MiB; hard validation limit:
  32 MiB incremental over Step 15A average.
- Control/match/funnel output target: below 250 MiB for the densest March run;
  hard disk limit: 500 MiB per run.
- Runtime target: no more than 3x the corresponding Step 15A run; hard stop and
  report if 5x is exceeded.
- A capacity/drop/duplicate/cursor/provenance integrity count above zero cannot
  be accepted as a formal detector result.

