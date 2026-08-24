# Tick-shock Step 14 IDEAL_EVENT_STUDY: March 2025

## Scope

- Driver: EURUSD,M1
- Symbols: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF
- Period: 2025-03-01 through 2025-04-01
- Model: MT5 real ticks (model 4), VantageTradingLtd-Live Build 6140
- RR: 1.2; thresholds and stop grid unchanged; research-only and no orders
- Formal edge eligibility: NO (ideal event-time diagnostic only)

## Result

| Metric | Value |
|---|---|
| raw shock candidates | 62577 |
| event rows | 19 |
| symbol clusters | 17 |
| market clusters / independent n | 15 |
| Long events | 10 |
| Short events | 9 |
| valid scenarios | 7128 |
| invalid scenarios | 324 |
| diagnostic scenario-grid ExpectancyR | -0.302408 |
| runtime seconds | 373.547 |
| average / max memory MB | 10.000 / 10 |
| events.csv bytes | 5159023 |
| summary.csv bytes | 203889 |
| trade.csv rows / bytes | 0 / 15 |
| formal validation violations | 0 |
| causal clock violations | 0 |
| run validation status | VALIDATION_INVALID |
| integrity fatal reason | INCOMPLETE_GLOBAL_FRONTIER |

The scenario count is a correlated stop/delay/spread grid, not independent trades. The formal sample count is 15 market clusters.

## Event funnel

| State/signal | Count |
|---|---|
| valid_bursts | 19 |
| valid_pullbacks | 14 |
| reacceleration_signals | 5 |
| detection_time_continuation_signals | 19 |
| post_burst_continuation_signals | 19 |
| pullback_continuation_signals | 5 |
| failed_shock_reversal_signals | 11 |

## Detector events

| Window ms | Events |
|---|---|
| 250 | 1 |
| 500 | 11 |
| 1000 | 7 |

## Scenario outcomes

| Status | Cells |
|---|---|
| INVALID_BROKER_STOP | 324 |
| SL_GAP | 2840 |
| TIME_MARKET | 2987 |
| TP_LIMIT | 1301 |

| Strategy | Valid | TP | SL | TIME | ExpectancyR |
|---|---|---|---|---|---|
| detection_time_continuation | 2508 | 427 | 1116 | 965 | -0.392150 |
| failed_shock_reversal | 1452 | 195 | 490 | 767 | -0.168752 |
| post_burst_continuation | 2508 | 497 | 1013 | 998 | -0.335052 |
| pullback_continuation | 660 | 182 | 221 | 257 | -0.131387 |

## Delay and processing

| Unique entry decisions | Actual delay mean | p50 | p95 | Processing-to-entry mean |
|---|---|---|---|---|
| 162 | 276.160 | 268.000 | 466.000 | -307.080 |

## Long/Short, symbol, session, and HTF alignment

| Direction | Valid cells | ExpectancyR |
|---|---|---|
| LONG | 3564 | -0.069643 |
| SHORT | 3564 | -0.535173 |

| Symbol | Events | Valid cells | ExpectancyR |
|---|---|---|---|
| EURUSD | 5 | 1716 | -0.538947 |
| GBPUSD | 2 | 792 | -0.439697 |
| USDCAD | 8 | 3168 | -0.360326 |
| USDJPY | 4 | 1452 | 0.178388 |

| Session | Events | Valid cells | ExpectancyR |
|---|---|---|---|
| LONDON | 3 | 924 | -0.758569 |
| NEW_YORK | 9 | 3564 | -0.336858 |
| OTHER | 3 | 1056 | 0.152075 |
| OVERLAP | 3 | 1188 | -0.220974 |
| TOKYO | 1 | 396 | -0.384246 |

| HTF alignment | Events | Valid cells | ExpectancyR |
|---|---|---|---|
| BOTH_ALIGNED | 1 | 396 | -0.445744 |
| CONFLICT | 5 | 1980 | -0.684112 |
| H1_ONLY | 3 | 1188 | -0.323061 |
| M15_ONLY | 4 | 1188 | 0.014045 |
| NEUTRAL | 6 | 2376 | -0.108333 |

## Cluster-unit diagnostic

| Clusters | Mean of cluster means | Median | Min | Max | Positive cluster means |
|---|---|---|---|---|---|
| 15 | -0.250144 | -0.384246 | -1.075541 | 1.066602 | 4 |

## Policy mask and commission

Valid-cell policy masks: 0=2048; 1=4362; 2=706; 3=12. Policy is diagnostic and does not invalidate a broker-feasible barrier outcome.

Configured commission is `0.0` with source `STEP13_TESTER_DEAL_FIELDS_OBSERVED_ZERO_LIVE_UNVALIDATED`. This is not verified live commission evidence.

## Tick quality and resource bounds

| Symbol | M1 minutes | Fallback minutes | Fallback rate | Status |
|---|---|---|---|---|
| EURUSD | 30192 |  | 0.0000 | NO_DISCARD_WARNING_OBSERVED |
| GBPUSD | 30188 | 179 | 0.5930 | GENERATED_TICK_FALLBACK_OBSERVED |
| USDJPY | 30195 |  | 0.0000 | NO_DISCARD_WARNING_OBSERVED |
| AUDUSD | 30193 |  | 0.0000 | NO_DISCARD_WARNING_OBSERVED |
| USDCAD | 30193 |  | 0.0000 | NO_DISCARD_WARNING_OBSERVED |
| USDCHF | 30191 |  | 0.0000 | NO_DISCARD_WARNING_OBSERVED |

- one-second ring buffer maximum: 904 samples per symbol
- tick ring buffer maximum: 8192 ticks per symbol
- tick discard rule: `older_than_5000ms_or_capacity_8192`
- global pending: `capacity=65536;max_observed=319;capacity_hits=0`
- no raw-tick or per-second time-series CSV was emitted; only event/trade/summary/spec evidence was collected.

## Interpretation

REALIZABLE_EA is the only formal feasibility input. IDEAL_EVENT_STUDY exists only to quantify event-time/processing-time differences. A fail-closed integrity status makes the run unusable for formal edge inference even when the causal clocks pass. No strategy cell was selected and no edge claim is made.
