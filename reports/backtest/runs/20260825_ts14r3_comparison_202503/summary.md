# Tick-shock Step 14R March 2025 remediation revalidation

## Formal judgement

- `RESEARCH_PIPELINE_VALIDATED_FOR_MARCH_SHADOW_REPLAY`
- `EXECUTION_MODEL_CAUSALLY_VALIDATED_FOR_SHADOW_REPLAY`
- `VALIDATED`
- `COST_MODEL_INCOMPLETE`
- `FORMAL_NET_EXPECTANCY_UNAVAILABLE`
- `STRATEGY_FEASIBILITY_NOT_ESTABLISHED`
- `EDGE_UNDETERMINED`
- `LONG_OOS_NOT_AUTHORIZED`

REALIZABLE_EA is the only formal feasibility input. Its causal clocks and read-through integrity pass. Quote staleness remains a diagnostic and does not block a causally complete CopyTicks range.

## Regression gate

| Metric | Step 7 | Step 14R | Status |
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

Unintended regression failures: **0**. Tick-quality comparison failures: **0**. Execution-clock/outcome differences caused by the frontier correction are labeled `INTENTIONAL_EXECUTION_CHANGE`.

## IDEAL and REALIZABLE

| Metric | IDEAL | REALIZABLE |
|---|---|---|
| events | 19 | 19 |
| valid scenario cells | 7128 | 7128 |
| TP | 1301 | 1261 |
| SL gap | 2840 | 2819 |
| TIME | 2987 | 3048 |
| diagnostic gross/net grid mean R | -0.302408 | -0.299635 |
| validation status | VALIDATED | VALIDATED |

The configured commission is zero with evidence status `1` and source `STEP14R_TESTER_DEAL_FIELDS_OBSERVED_ZERO_LIVE_UNVALIDATED`. This is tester-observed zero for EURUSD, not evidence that live Vantage or the other five symbols charge zero commission; formal cost-after expectancy is unavailable.

## Causality and integrity

- causal clock violations: 0
- all formal validation violation instances: 0
- integrity fatal reason: ``
- quote-stale symbols observed (diagnostic): EURUSD|GBPUSD|USDJPY|AUDUSD|USDCAD|USDCHF
- read-through frontier incomplete / affected symbols: false / NONE
- event pool / pending capacity / dropped tick / cursor stall: 0 / 0 / 0 / 0
- global order violations: 0; duplicate events: 0; run identity mismatches: 0

## Independent sample and policy mask=3

- event rows: 19
- symbol clusters: 17
- market clusters / formal n: 15
- correlated valid scenario cells: 7128
- policy mask=3 cells: 12 across 2 events and 2 market clusters

Policy mask=3 means both stressed_spread/risk <= 0.20 and risk/burst_range <= 0.45. It is a diagnostic slice only; no strategy, symbol, direction, session, stop, delay, or spread cell was selected.

## Feasibility layers

| Layer | Observation | Formal status |
|---|---|---|
| broker-grid shadow feasible | 7128 barrier cells produced | OBSERVED_DIAGNOSTIC |
| original cost/range policy feasible | policy mask=3 in 12 cells / 2 market clusters | OBSERVED_DIAGNOSTIC_NO_SELECTION |
| causal shadow replay | read-through complete and causal violations zero | VALIDATED_FOR_MARCH_RESEARCH |
| order lifecycle observed | Step 14R tester OrderCheck/OrderSend/fill/SL/TP/time-close | PARTIALLY_OBSERVED |
| deployable feasibility | live/all-symbol commission unavailable; research EA has no order path | NOT_ESTABLISHED |
| edge evidence | diagnostic grid only; no selected strategy | UNDETERMINED |
| statistical sufficiency | n=15 market clusters | INSUFFICIENT_STATISTICAL_EVIDENCE |

## Tick quality and resource evidence

- GBPUSD generated fallback: 179 / 30,187 tester minutes (0.5930%)
- other symbols: no discard warning observed; this is not proof of all-real coverage
- REALIZABLE average/max memory: 10.000 / 10 MB; tester process reported 513 MB including history and generated tick data
- events.csv: 19 rows / 5150562 bytes
- summary.csv: 1186 rows / 223970 bytes
- trades.csv: 0 rows / 15 bytes; research EA sent no orders
- no raw-tick CSV or per-second time-series CSV was emitted

## Decision

The March detector funnel, event identity and scenario membership match Step 7. Corrected read-through processing intentionally changes scenario clocks and some barrier outcomes; those changes are not parameter optimization. REALIZABLE causal and integrity checks pass, but only 15 market clusters exist and live/all-symbol commission is unavailable. This establishes the March shadow-replay plumbing, not deployable feasibility or edge. Do not start long OOS, optimization, or positive-cell selection. The next promotion gate is an explicit decision after this QA evidence, commission coverage, and remaining order observations are reviewed.
