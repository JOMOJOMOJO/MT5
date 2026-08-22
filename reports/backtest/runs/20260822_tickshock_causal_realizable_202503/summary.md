# Tick-shock Step 7 REALIZABLE_EA: March 2025

## Scope

- Driver: EURUSD,M1
- Symbols: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF
- Period: 2025-03-01 through 2025-04-01
- Model: MT5 real ticks (model 4), VantageTradingLtd-Live Build 6140
- RR: 1.2; thresholds and stop grid unchanged; research-only and no orders
- Formal edge eligibility: YES

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
| diagnostic scenario-grid ExpectancyR | -0.292362 |
| runtime seconds | 351.390 |
| average / max memory MB | 10.000 / 10 |
| events.csv bytes | 5149590 |
| summary.csv bytes | 214281 |
| trade.csv rows / bytes | 0 / 15 |
| formal causal violations | 0 |

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
| SL_GAP | 2820 |
| TIME_MARKET | 3081 |
| TP_LIMIT | 1227 |

| Strategy | Valid | TP | SL | TIME | ExpectancyR |
|---|---|---|---|---|---|
| detection_time_continuation | 2508 | 432 | 987 | 1089 | -0.319703 |
| failed_shock_reversal | 1452 | 174 | 507 | 771 | -0.196465 |
| post_burst_continuation | 2508 | 441 | 1047 | 1020 | -0.339913 |
| pullback_continuation | 660 | 180 | 279 | 201 | -0.218739 |

## Delay and processing

| Unique entry decisions | Actual delay mean | p50 | p95 | Processing-to-entry mean |
|---|---|---|---|---|
| 162 | 675.660 | 570.000 | 1159.100 | 92.420 |

## Long/Short, symbol, session, and HTF alignment

| Direction | Valid cells | ExpectancyR |
|---|---|---|
| LONG | 3564 | -0.053791 |
| SHORT | 3564 | -0.530932 |

| Symbol | Events | Valid cells | ExpectancyR |
|---|---|---|---|
| EURUSD | 5 | 1716 | -0.413752 |
| GBPUSD | 2 | 792 | -0.405817 |
| USDCAD | 8 | 3168 | -0.380519 |
| USDJPY | 4 | 1452 | 0.105327 |

| Session | Events | Valid cells | ExpectancyR |
|---|---|---|---|
| LONDON | 3 | 924 | -0.719375 |
| NEW_YORK | 9 | 3564 | -0.359239 |
| OTHER | 3 | 1056 | 0.072159 |
| OVERLAP | 3 | 1188 | -0.097168 |
| TOKYO | 1 | 396 | -0.251737 |

| HTF alignment | Events | Valid cells | ExpectancyR |
|---|---|---|---|
| BOTH_ALIGNED | 1 | 396 | -0.452126 |
| CONFLICT | 5 | 1980 | -0.606916 |
| H1_ONLY | 3 | 1188 | -0.295886 |
| M15_ONLY | 4 | 1188 | -0.074403 |
| NEUTRAL | 6 | 2376 | -0.110823 |

## Cluster-unit diagnostic

| Clusters | Mean of cluster means | Median | Min | Max | Positive cluster means |
|---|---|---|---|---|---|
| 15 | -0.242732 | -0.398433 | -1.054015 | 1.038895 | 3 |

## Policy mask and commission

Valid-cell policy masks: 0=2037; 1=4353; 2=717; 3=21. Policy is diagnostic and does not invalidate a broker-feasible barrier outcome.

Configured commission is `0.0` with source `ORDER_HARNESS_REQUIRED`. This is not verified live commission evidence.

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

REALIZABLE_EA is the only formal feasibility input. IDEAL_EVENT_STUDY exists only to quantify event-time/processing-time differences. No strategy cell was selected and no edge claim is made.
