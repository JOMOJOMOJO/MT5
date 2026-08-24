# REALIZABLE_EA independent reconciliation

## Inputs

- events: `reports/backtest/runs/20260825_ts14r3_realizable_202503/events.csv` (`FCB7F26BA6862DFFB0E09B2AE2EB3A9FEC0DA79E6CEAC2EFD2B7DB0F2B759114`)
- summary: `reports/backtest/runs/20260825_ts14r3_realizable_202503/summary.csv` (`D65A3F63BA88BBD4A1872ADBBFD7EF296C0C016B8FBDD0255EE340BC73BECE74`)
- preset: `reports/backtest/runs/20260825_ts14r3_realizable_202503/step14r3_realizable.set`
- oracle: this Python parser reads event rows and encoded scenarios; it does not call MQL5 production functions.

## Reconciliation

| Metric | Independent | EA summary | Result |
|---|---|---|---|
| event rows | 19 | 19 | PASS |
| valid scenarios | 7128 | 7128 | PASS |
| invalid scenarios | 324 | 324 | PASS |
| ExpectancyR | -0.299635 | -0.299635 | PASS |
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
| run integrity status is VALIDATION_OK | 1 | 0 | PASS | YES |
| event_pool_exhaustions = 0 | 1 | 0 | PASS | YES |
| pending_capacity_hits = 0 | 1 | 0 | PASS | YES |
| dropped_ticks = 0 | 1 | 0 | PASS | YES |
| cursor_stalls = 0 | 1 | 0 | PASS | YES |
| global read-through frontier complete (quote staleness is diagnostic) | 1 | 0 | PASS | YES |
| run identity and writer metadata are consistent | 4 | 0 | PASS | YES |
| research EA order rows = 0 | 1 | 0 | PASS | YES |

Formal violation total: **0**. IDEAL rows are diagnostic and are excluded from the formal total.

## Strategy scenario recount

| Strategy | Valid cells | TP | SL | TIME | ExpectancyR |
|---|---|---|---|---|---|
| detection_time_continuation | 2508 | 447 | 1062 | 999 | -0.360237 |
| failed_shock_reversal | 1452 | 195 | 490 | 767 | -0.168752 |
| post_burst_continuation | 2508 | 451 | 1036 | 1021 | -0.352407 |
| pullback_continuation | 660 | 168 | 231 | 261 | -0.156758 |

## Independent sample boundary

- event rows: 19
- market clusters: 15
- correlated valid scenario cells: 7128
- statistical n is market clusters, not scenario cells.

## Tick quality

Generated fallback was observed for 1 symbol(s): GBPUSD.
