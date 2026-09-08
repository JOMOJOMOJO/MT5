# Step 15P Symmetric OCO / Micro-Profit Preregistration

## Research question and boundary

This development study asks whether frozen `TAIL_V1_PERSISTENT` shock episodes
contain a broad, executable Bid/Ask region where a direction-neutral symmetric
OCO entry can earn a small positive expectancy after friction. It does not use
ML, direction prediction, Cross-FX freshness, actual orders, or parameter
optimization.

- Period: `2025-04-01 00:00:00` to `2025-05-01 00:00:00`, end exclusive.
- Status: development reuse of April 2025; it is not OOS.
- Symbols: `EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,USDCHF`.
- Driver/model: `EURUSD,M1`, real ticks.
- Detector, persistence confirmation, episode rule, cooldown, thresholds and
  two-second market-cluster provenance remain frozen.
- Outcomes will not be used to add grid points or change the month.

## Causal OCO convention

At each episode's confirmed `t0`, use the latest completed M5 ATR14 whose source
time is not later than processing time. Three symmetric trigger pairs are armed
around the executable t0 mid:

```text
offset = 0.02, 0.05, 0.10 ATR
upper trigger = t0 mid + offset
lower trigger = t0 mid - offset
trigger deadline = t0 + 30 seconds
```

The upper buy-stop is touched by Ask and the lower sell-stop by Bid. Quotes
sharing one `time_msc` are grouped; the last quote closes the group. If both
sides are touched inside one group, or temporal order cannot be established,
the OCO is `AMBIGUOUS` and no direction is silently selected. If neither side
touches by the first quote at or after the deadline, it is `NO_ENTRY`.

A one-sided touch only arms the selected direction. Entry uses the first valid
real quote with `time_msc` strictly later than the completed trigger group.
Long enters at Ask; short enters at Bid. The opposite trigger is cancelled.
Fallback/generated quotes invalidate the affected path. The invariants are:

```text
trigger_quote_msc >= t0_msc
entry_quote_msc > trigger_quote_msc
entry_processing_msc >= entry_quote_msc
barrier_quote_msc > entry_quote_msc
```

No actual `OrderCheck` or `OrderSend` call is added.

## Frozen geometry

Every triggered entry is evaluated over the complete Cartesian surface:

- TP: `0.02, 0.03, 0.05, 0.075, 0.10, 0.15 ATR`.
- SL: `0.10, 0.20, 0.30, 0.50, 0.75, 1.00 ATR`.
- Deadline: entry time plus 300 seconds.

Barriers are redrawn from the executable entry using the t0 ATR. Long exits
are tested on Bid; short exits are tested on Ask. TP is limit-equivalent at the
barrier, SL uses the first tradable exit-side quote and therefore retains gap
loss, and timeout uses the first tradable quote at or after the deadline.
Simultaneous TP/SL evidence is retained as ambiguous and excluded from formal
expectancy.

## Cost and units

The real Bid/Ask path already contains spread friction and is the primary gross
execution evidence. The initial spread is reported separately as a diagnostic
fraction of TP distance and is never subtracted a second time.

Broker-observed round-turn commission is used only when evidence covers the
studied symbol. Otherwise formal actual commission is `NOT_OBSERVED`. Separate
round-trip stress deductions are frozen at `0.0, 0.1, 0.2, 0.5, 1.0 pip`.
Pip size is `10 * point` for three/five digit FX symbols and `point` otherwise.
Stress cost is subtracted once from each realized price outcome.

## Frozen evaluation

For every offset x TP x SL cell report eligible shocks, trigger outcomes,
trades/day, TP/SL/TIME counts, win rate, expectancy in price/pips/R, PF,
average win/loss, empirical and geometric break-even win rate, win-rate margin,
longest losing streak, fixed-1R equity/MaxDD and a market-cluster bootstrap 95%
interval. Bootstrap uses 10,000 cluster resamples with seed `20260908`.

All cells remain visible. A single best cell is descriptive only and cannot be
promoted. Positive feasibility requires a contiguous neighboring region with
positive net expectancy, non-extreme cluster uncertainty, resilience at both
0.1 and 0.2 pip stress, and adequate frequency. Otherwise the frozen verdict is
`MICRO_PROFIT_FEASIBILITY_NOT_FOUND`; the April grid will not be refined.

The strongest possible positive verdict is:

```text
MICRO_PROFIT_FEASIBILITY_FOUND
OOS_VALIDATION_REQUIRED
PRODUCTION_NOT_ELIGIBLE
```

## QA gates

- future quote usage: zero
- entry before or at trigger: zero
- TP/SL/TIME before entry: zero
- duplicate episode/offset/scenario: zero
- market-cluster provenance/split errors: zero
- ambiguous trigger silently selected: zero
- actual orders/trades: zero
- deterministic rerun hash mismatch: zero
- independent arithmetic/reconciliation mismatch: zero

