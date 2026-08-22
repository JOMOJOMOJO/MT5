# REALIZABLE_EA independent reconciliation

## Inputs

- events: `reports/backtest/runs/20260822_tickshock_causal_realizable_202503/events.csv` (`722DF1673BFA91B5B80D21E0BC5E43AD3C7C2FFC3267AB8A5EB5C570D1B41F4A`)
- summary: `reports/backtest/runs/20260822_tickshock_causal_realizable_202503/summary.csv` (`97E1EF29D736FA832887521D3188FE85E85C8135D00A35BFD6AF29FA7571BDB6`)
- preset: `reports/backtest/runs/20260822_tickshock_causal_realizable_202503/ExpectedValue_MultiCurrency_TickShockResearch_step07_realizable_202503.set`
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

Formal violation total: **0**. IDEAL rows are diagnostic and are excluded from the formal total.

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
