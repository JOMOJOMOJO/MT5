# IDEAL_EVENT_STUDY independent reconciliation

## Inputs

- events: `reports/backtest/runs/20260825_ts14r3_ideal_202503/events.csv` (`9D6D94BECE315A0DD58C656E9641908A3C448A830EA8AE8607DD19A4336879E0`)
- summary: `reports/backtest/runs/20260825_ts14r3_ideal_202503/summary.csv` (`6B2EF9ACE1BC6427B8B7FC5E52C8AF608F2D75540B26177AD3C09EB0E89062A5`)
- preset: `reports/backtest/runs/20260825_ts14r3_ideal_202503/step14r3_ideal.set`
- oracle: this Python parser reads event rows and encoded scenarios; it does not call MQL5 production functions.

## Reconciliation

| Metric | Independent | EA summary | Result |
|---|---|---|---|
| event rows | 19 | 19 | PASS |
| valid scenarios | 7128 | 7128 | PASS |
| invalid scenarios | 324 | 324 | PASS |
| ExpectancyR | -0.302408 | -0.302408 | PASS |
| funnel counters | event-field recount | summary FUNNEL | PASS |

## Causal invariants

| Invariant | Checked | Violations | Status | Formal |
|---|---|---|---|---|
| entry_quote_msc >= signal_event_msc + requested_delay_ms | 7128 | 0 | PASS | NO |
| entry_quote_msc >= signal_processing_msc + submit_latency_ms | 7128 | 2376 | DIAGNOSTIC_NOT_APPLICABLE | NO |
| entry_quote_msc >= entry_eligible_msc | 7128 | 0 | PASS | NO |
| entry_quote_msc > signal_event_msc | 7128 | 0 | PASS | NO |
| stale Detection boundary fill = 0 | 2508 | 0 | PASS | NO |
| reversal signal equals invalidation time | 1518 | 0 | PASS | NO |
| realized RR >= requested RR (1.2) | 7128 | 0 | PASS | NO |
| global order violation = 0 | 1 | 0 | PASS | NO |
| duplicate event = 0 | 19 | 0 | PASS | NO |
| market cluster integrity | 19 | 0 | PASS | NO |
| CSV and summary reconciliation | 8023 | 0 | PASS | NO |
| net R = gross R - commission R exactly once | 7128 | 0 | PASS | NO |
| broker StopsLevel distance is respected | 7128 | 0 | PASS | NO |
| FreezeLevel diagnostic is clear for valid scenarios | 7128 | 0 | PASS | NO |
| run integrity status is VALIDATION_OK | 1 | 0 | PASS | NO |
| event_pool_exhaustions = 0 | 1 | 0 | PASS | NO |
| pending_capacity_hits = 0 | 1 | 0 | PASS | NO |
| dropped_ticks = 0 | 1 | 0 | PASS | NO |
| cursor_stalls = 0 | 1 | 0 | PASS | NO |
| global read-through frontier complete (quote staleness is diagnostic) | 1 | 0 | PASS | NO |
| run identity and writer metadata are consistent | 4 | 0 | PASS | NO |
| research EA order rows = 0 | 1 | 0 | PASS | NO |

Formal violation total: **0**. IDEAL rows are diagnostic and are excluded from the formal total.

## Strategy scenario recount

| Strategy | Valid cells | TP | SL | TIME | ExpectancyR |
|---|---|---|---|---|---|
| detection_time_continuation | 2508 | 427 | 1116 | 965 | -0.392150 |
| failed_shock_reversal | 1452 | 195 | 490 | 767 | -0.168752 |
| post_burst_continuation | 2508 | 497 | 1013 | 998 | -0.335052 |
| pullback_continuation | 660 | 182 | 221 | 257 | -0.131387 |

## Independent sample boundary

- event rows: 19
- market clusters: 15
- correlated valid scenario cells: 7128
- statistical n is market clusters, not scenario cells.

## Tick quality

Generated fallback was observed for 1 symbol(s): GBPUSD.
