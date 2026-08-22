# Tick-shock Step 6 causal execution fix

## Scope and result

Step 6 fixes the production defects represented by the Step 5 executable
specification without changing any Step 3 fixture, expected value, strategy
threshold, detector threshold, stop grid, or RR. The post-fix result is 45
PASS, 0 FAIL, 0 XFAIL, 0 XPASS, and 19 SKIP. SKIP remains outside PASS.

The deterministic production path now satisfies the causal clock contract.
This is not evidence of strategy edge and does not replace broker observations
for server SL/TP, process restart, or time-close lifecycle.

## Clock definitions

- `signal_event_msc`: event-time instant at which the strategy condition first
  becomes true.
- `signal_processing_msc`: instant at which the EA can recognize that signal.
- `entry_eligible_msc`: earliest permitted submission/fill clock after mode,
  requested delay, and submission latency are applied.
- `entry_quote_msc`: timestamp of the actual same-symbol real quote used for
  entry.
- `detection_grid_msc`: detector grid boundary.
- `detection_quote_msc`: timestamp of the real quote supporting that grid
  boundary.
- `detection_quote_age_ms`: `detection_grid_msc - detection_quote_msc`.

For `REALIZABLE_EA`:

```text
entry_eligible_msc = max(
  signal_event_msc + requested_delay_ms,
  signal_processing_msc + submit_latency_ms
)
```

The accepted entry quote must be a real same-symbol quote and must satisfy all
of the following:

```text
entry_quote_msc >  signal_event_msc
entry_quote_msc >= entry_eligible_msc
entry_quote_msc >= signal_processing_msc
```

## IDEAL_EVENT_STUDY and REALIZABLE_EA

`IDEAL_EVENT_STUDY` uses event time plus requested delay and exists only for
idealized event research. It is not eligible for formal Expectancy or edge
claims.

`REALIZABLE_EA` includes recognition/merge lag and submission latency. Only
this mode is formal input to Step 7. Global merge may order events, form market
clusters, and report portfolio diagnostics, but a replayed quote before
processing can never become an entry.

## Detection correction

Detection arms a signal; it does not create a synthetic immediate fill. A grid
boundary and its supporting quote have separate timestamps and quote age. Even
at requested delay 0, a quote at the signal event time is rejected. The first
later real quote at or after eligibility is used.

Production functions:

- `TSRegisterResearchSignal`
- `TSResearchEntryEligibleMsc`
- `TSResearchTryEntryClock`
- `TSResearchEntryInvariant`

Evidence: `TS-TIME-001` and `TS-DETECT-001` are PASS with zero
processing-before-entry and zero stale detection fills.

## Reversal correction

Failed-shock reversal registers `continuation_invalidated_msc` as the immutable
signal event time. A later tick cannot overwrite the registered clock. The
100ms and 250ms requested delays are therefore measured from invalidation,
while `REALIZABLE_EA` still takes the maximum with processing plus submission
latency.

Evidence: `TS-REV-001` reports `reversal_signal_msc=3000`,
`entry_eligible_msc=3600`, and zero signal overwrites.

## Independent returns

The 250ms, 500ms, and 1,000ms values are calculated from their own exact
anchors through `TSResearchExactLogReturn`. Missing anchors are invalid and
serialize as absent rather than numeric zero. A shorter detector return is not
copied into `log_return_1000`.

Evidence: `TS-RET-001` observes three distinct oracle values.

## Market clusters

`TSAssignResearchMarketCluster` owns a global clock shared by all configured
symbols and detector windows. The first event is the cluster anchor. The
2,000ms boundary is inclusive; 2,001ms starts the next market cluster. Symbol
clusters remain separate diagnostics, while statistical n defaults to market
clusters.

Evidence: `TS-CLUSTER-001` assigns EURUSD/GBPUSD/USDJPY at 10,000/11,999/12,000
to cluster 1 and AUDUSD at 12,001 to cluster 2.

## RR and target rounding

`TSBuildResearchTarget` rounds targets outward on the symbol tick grid:

- Long target: ceiling;
- Short target: floor.

The function rejects a result whose tick-rounded `realized_rr` is below the
requested RR. `TS-RR-001` observes 1.333333333333 or higher for a requested
1.2R fractional-tick target.

## Broker distance and freeze distance

`TSProtectiveOrderDistanceFeasible` checks StopsLevel from current Bid for a
Long and current Ask for a Short. Entry price is not the broker-distance
reference. `TSProtectiveFreezeDistanceClear` evaluates FreezeLevel separately
as a modification/placement diagnostic and does not replace the initial
StopsLevel result.

Evidence: `TS-BROKER-001` passes equality and rejects the 0.00049 distance on
both directions.

## Order lifecycle and partial fills

`TickShockOrderLifecycle.mqh` adds `TickShockOrderFillState` with explicit
`requested_volume`, `filled_volume`, `remaining_volume`,
`cancelled_volume`, weighted fill value, average fill, deal count, resolution
flag, and enum state.

`TSApplyEntryDeal` keeps the request in `TS_ORDER_ENTRY_PENDING` until all
requested volume is filled. `TSResolveEntryRemainderCancel` resolves the request
only after the remaining quantity is confirmed cancelled. If any volume was
filled, the next state is `TS_ORDER_WAIT_EXIT`; a partial entry never becomes a
closed trade merely because the first `DEAL_ENTRY_IN` arrived.

Evidence:

- `TS-ORDER-001`: full fill resolves to `WAIT_EXIT`;
- `TS-ORDER-002`: two deals aggregate to weighted average 1.10012;
- `TS-PARTIAL-001`: remaining volume is 0.06, 0.03, then 0 and first-deal close
  is false;
- `TS-ORDER-003`: 0.06 fill plus 0.04 residual cancellation preserves the
  filled position and resolves to `WAIT_EXIT`.

Server SL/TP, process restart, time close, and terminal position recovery remain
SKIP until an actual tester/broker lifecycle is observed.

## Run identity and CSV isolation

`TSMt5OpenAppendCsv` now binds each CSV to a sidecar `.runmeta` record containing
RunId, deterministic source/config metadata fingerprint, and the exact header.
A non-empty CSV without matching metadata, a different fingerprint, or a
different header is rejected as `RUN_ID_COLLISION`. An exact identity may
resume and does not duplicate the header.

The research EA supplies a source revision plus all result-affecting inputs as
the metadata fingerprint. `TS-CSV-001` changed from silent mixed append to
`RUN_ID_COLLISION`, zero mixed rows, and one header.

## Validation boundary

- Deterministic production-path causal execution: validated by the Step 6
  fixture suite.
- Full broker/order lifecycle: not validated; observation-dependent cases are
  SKIP.
- Strategy feasibility and edge: undetermined.
- Long OOS and parameter optimization: not executed.
