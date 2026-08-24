# IDEAL_EVENT_STUDY independent reconciliation

## Inputs

- events: `reports/backtest/runs/20260823_tickshock_step14_ideal_202503/events.csv` (`4ED138DF6A05749FEB985D3EA7AAEF9AB8972CC75E1FB5AD5C95159CF7DD6850`)
- summary: `reports/backtest/runs/20260823_tickshock_step14_ideal_202503/summary.csv` (`F2DD660D7A1DD7D672082C8A35F55316CB694FE3362D08244067DD1541312CA4`)
- preset: `reports/backtest/runs/20260823_tickshock_step14_ideal_202503/ExpectedValue_MultiCurrency_TickShockResearch_step14_ideal_202503.set`
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
| entry_quote_msc >= signal_processing_msc + submit_latency_ms | 7128 | 6204 | FAIL | NO |
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
| run integrity status is VALIDATION_OK | 1 | 1 | FAIL | NO |
| event_pool_exhaustions = 0 | 1 | 0 | PASS | NO |
| pending_capacity_hits = 0 | 1 | 0 | PASS | NO |
| dropped_ticks = 0 | 1 | 0 | PASS | NO |
| cursor_stalls = 0 | 1 | 0 | PASS | NO |
| global frontier complete with no stale symbols | 1 | 3 | FAIL | NO |
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
