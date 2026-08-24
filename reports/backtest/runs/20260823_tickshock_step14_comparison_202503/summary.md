# Tick-shock Step 14 March 2025 revalidation

## Formal judgement

- `RESEARCH_PIPELINE_PARTIALLY_VALIDATED`
- `EXECUTION_MODEL_CAUSALLY_VALIDATED_FOR_SHADOW_REPLAY`
- `VALIDATION_INVALID`
- `COST_MODEL_INCOMPLETE`
- `FORMAL_NET_EXPECTANCY_UNAVAILABLE`
- `STRATEGY_FEASIBILITY_NOT_ESTABLISHED`
- `EDGE_UNDETERMINED`
- `LONG_OOS_NOT_AUTHORIZED`

REALIZABLE_EA is the only formal feasibility input. Its causal clocks pass, but the run is fail-closed because three monitored symbols became stale relative to the global frontier. Therefore the scenario outcomes below are diagnostic only.

## Regression gate

| Metric | Step 7 | Step 14 | Status |
|---|---|---|---|
| raw_candidates | 62577 | 62577 | PASS |
| event_rows | 19 | 19 | PASS |
| valid_bursts | 19 | 19 | PASS |
| valid_pullbacks | 14 | 14 | PASS |
| reacceleration | 5 | 5 | PASS |
| reversal_signals | 11 | 11 | PASS |
| symbol_clusters | 17 | 17 | PASS |
| market_clusters | 15 | 15 | PASS |
| long_events | 10 | 10 | PASS |
| short_events | 9 | 9 | PASS |

Regression mismatches: **0**. Tick-quality comparison failures: **0**.

## IDEAL and REALIZABLE

| Metric | IDEAL | REALIZABLE |
|---|---|---|
| events | 19 | 19 |
| valid scenario cells | 7128 | 7128 |
| TP | 1301 | 1227 |
| SL gap | 2840 | 2820 |
| TIME | 2987 | 3081 |
| diagnostic gross/net grid mean R | -0.302408 | -0.292362 |
| validation status | VALIDATION_INVALID | VALIDATION_INVALID |

The configured commission is zero because Step 13 observed zero in MT5 Strategy Tester deal fields. That observation is not evidence that live Vantage commission is zero, so the numeric net R remains diagnostic and formal cost-after expectancy is unavailable.

## Causality and integrity

- causal clock violations: 0
- all formal validation violation instances: 4
- integrity fatal reason: `INCOMPLETE_GLOBAL_FRONTIER`
- stale symbols: 3
- event pool / pending capacity / dropped tick / cursor stall: 0 / 0 / 0 / 0
- global order violations: 0; duplicate events: 0; run identity mismatches: 0

## Independent sample and policy mask=3

- event rows: 19
- symbol clusters: 17
- market clusters / formal n: 15
- correlated valid scenario cells: 7128
- policy mask=3 cells: 21 across 1 events and 1 market clusters

Policy mask=3 means both stressed_spread/risk <= 0.20 and risk/burst_range <= 0.45. It is a diagnostic slice only; no strategy, symbol, direction, session, stop, delay, or spread cell was selected.

## Feasibility layers

| Layer | Observation | Formal status |
|---|---|---|
| broker-grid shadow feasible | 7128 barrier cells produced | DIAGNOSTIC_ONLY_RUN_INVALID |
| original cost/range policy feasible | policy mask=3 in 21 cells / 1 market cluster | DIAGNOSTIC_ONLY_RUN_INVALID |
| order lifecycle observed | Step 13 tester OrderCheck/OrderSend/fill/SL/TP/time-close | PARTIALLY_OBSERVED |
| deployable feasibility | global frontier integrity failed and live commission unavailable | NOT_ESTABLISHED |
| edge evidence | diagnostic grid only; no selected strategy | UNDETERMINED |
| statistical sufficiency | formal n would be 15 market clusters | INSUFFICIENT_AND_RUN_INVALID |

## Tick quality and resource evidence

- GBPUSD generated fallback: 179 / 30,187 tester minutes (0.5930%)
- other symbols: no discard warning observed; this is not proof of all-real coverage
- REALIZABLE average/max memory: 10.000 / 10 MB; tester process reported 513 MB including history and generated tick data
- events.csv: 19 rows / 5149476 bytes
- summary.csv: 1185 rows / 207602 bytes
- trades.csv: 0 rows / 15 bytes; research EA sent no orders
- no raw-tick CSV or per-second time-series CSV was emitted

## Decision

The March event funnel and scenario grid are exact Step 7 regressions, and the REALIZABLE causal execution clocks have zero violations. However, Step 12 correctly invalidated both runs when three symbols became stale under the global watermark, and actual live commission remains unobserved. This run cannot establish deployable feasibility or edge. Do not start long OOS, optimization, or positive-cell selection. The next gate is to diagnose and separately validate the stale/global-frontier policy without changing strategy thresholds.
