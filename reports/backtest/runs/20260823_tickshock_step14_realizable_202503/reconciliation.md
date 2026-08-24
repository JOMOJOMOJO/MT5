# REALIZABLE_EA independent reconciliation

## Inputs

- events: `reports/backtest/runs/20260823_tickshock_step14_realizable_202503/events.csv` (`AF42D1452A7D336647B5F146DDC801A6A9ED1BF70392087FE57EFA5FBCF47ECB`)
- summary: `reports/backtest/runs/20260823_tickshock_step14_realizable_202503/summary.csv` (`5A7D3B107E10526B6EEB4B2787DBA48B40F6F8391EED812B5B9364E2FCCBD425`)
- preset: `reports/backtest/runs/20260823_tickshock_step14_realizable_202503/ExpectedValue_MultiCurrency_TickShockResearch_step14_realizable_202503.set`
- oracle: this Python parser reads event rows and encoded scenarios; it does not call MQL5 production functions.

## Reconciliation

| Metric | Independent | EA summary | Result |
|---|---|---|---|
| event rows | 19 | 19 | PASS |
| valid scenarios | 7128 | 7128 | PASS |
| invalid scenarios | 324 | 324 | PASS |
| ExpectancyR | -0.292362 | -0.292362 | PASS |
| funnel counters | event-field recount | summary FUNNEL | PASS |

## Causal invariants

| Invariant | Checked | Violations | Status | Formal |
|---|---|---|---|---|
| entry_quote_msc >= signal_event_msc + requested_delay_ms | 7128 | 0 | PASS | YES |
| entry_quote_msc >= signal_processing_msc + submit_latency_ms | 7128 | 0 | PASS | YES |
| entry_quote_msc >= entry_eligible_msc | 7128 | 0 | PASS | YES |
| entry_quote_msc > signal_event_msc | 7128 | 0 | PASS | YES |
| stale Detection boundary fill = 0 | 2508 | 0 | PASS | YES |
| reversal signal equals invalidation time | 1518 | 0 | PASS | YES |
| realized RR >= requested RR (1.2) | 7128 | 0 | PASS | YES |
| global order violation = 0 | 1 | 0 | PASS | YES |
| duplicate event = 0 | 19 | 0 | PASS | YES |
| market cluster integrity | 19 | 0 | PASS | YES |
| CSV and summary reconciliation | 8023 | 0 | PASS | YES |
| net R = gross R - commission R exactly once | 7128 | 0 | PASS | YES |
| broker StopsLevel distance is respected | 7128 | 0 | PASS | YES |
| FreezeLevel diagnostic is clear for valid scenarios | 7128 | 0 | PASS | YES |
| run integrity status is VALIDATION_OK | 1 | 1 | FAIL | YES |
| event_pool_exhaustions = 0 | 1 | 0 | PASS | YES |
| pending_capacity_hits = 0 | 1 | 0 | PASS | YES |
| dropped_ticks = 0 | 1 | 0 | PASS | YES |
| cursor_stalls = 0 | 1 | 0 | PASS | YES |
| global frontier complete with no stale symbols | 1 | 3 | FAIL | YES |
| run identity and writer metadata are consistent | 4 | 0 | PASS | YES |
| research EA order rows = 0 | 1 | 0 | PASS | YES |

Formal violation total: **4**. IDEAL rows are diagnostic and are excluded from the formal total.

## Strategy scenario recount

| Strategy | Valid cells | TP | SL | TIME | ExpectancyR |
|---|---|---|---|---|---|
| detection_time_continuation | 2508 | 432 | 987 | 1089 | -0.319703 |
| failed_shock_reversal | 1452 | 174 | 507 | 771 | -0.196465 |
| post_burst_continuation | 2508 | 441 | 1047 | 1020 | -0.339913 |
| pullback_continuation | 660 | 180 | 279 | 201 | -0.218739 |

## Independent sample boundary

- event rows: 19
- market clusters: 15
- correlated valid scenario cells: 7128
- statistical n is market clusters, not scenario cells.

## Tick quality

Generated fallback was observed for 1 symbol(s): GBPUSD.
