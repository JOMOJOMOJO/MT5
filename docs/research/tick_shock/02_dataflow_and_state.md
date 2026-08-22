# Tick-shock research EA: dataflow and state (As-Is)

## Scope and notation

This document freezes the behavior at Step 1 commit
<code>5f8387029766db54e4ced2329ae434b783cc2aab</code>. Times ending in
<code>_msc</code> are Unix-style milliseconds supplied or derived by MT5. Price
side matters: a shadow long enters on Ask and exits on Bid; a shadow short enters
on Bid and exits on Ask.

## End-to-end dataflow

~~~mermaid
flowchart LR
  A[OnTick or 50 ms OnTimer] --> B[TSRDispatcher]
  B --> C[CopyTicks INFO per symbol]
  C --> D[deduplicate same time_msc by ordinal]
  D --> E[global pending array]
  E --> F[stable sort: time, symbol, sequence]
  F --> G[watermark: minimum symbol frontier]
  G --> H[release complete same-ms groups below watermark]
  H --> I[TSRProcessOneTick]
  I --> J[short tick ring and quote]
  I --> K[existing event/state/scenarios]
  I --> L[grid boundary close]
  L --> M[250/500/1000 sample creation]
  M --> N[baseline cache and six gates]
  N --> O[event allocation and four strategy arms]
  O --> K
  K --> P[barrier outcome and MFE/MAE]
  P --> Q[event/scenario CSV]
  Q --> R[OnDeinit summary CSV]
~~~

The ordering inside one processed tick is material:

1. close grid boundaries strictly before the tick;
2. update the symbol quote, short-tick ring, and per-window tick counts;
3. advance already-existing events and scenarios;
4. if the tick is the last quote in its same-millisecond symbol group, close a
   boundary equal to that millisecond;
5. release event rows whose 120-second evidence is complete.

Thus a newly detected event is armed after existing-event processing for that
tick. Current entry-clock code requires a later real quote, but the reachability
harness does not exercise this whole path.

## Detector data state

Each symbol holds three detector streams.

~~~mermaid
stateDiagram-v2
  [*] --> NoQuote
  NoQuote --> GridWarmup: first valid quote
  GridWarmup --> BaselineWarmup: complete detector-window samples
  BaselineWarmup --> Evaluable: retained baseline samples >= minimum
  Evaluable --> Evaluable: each completed grid boundary
  Evaluable --> EventCreated: all six gates true and no duplicate
  Evaluable --> RejectedSample: one or more gates false
  RejectedSample --> Evaluable
  EventCreated --> Evaluable
~~~

At each 250 ms base-grid boundary, the EA can create 250, 500, and/or 1000 ms
samples when the corresponding detector boundary is due. The sample endpoint
uses the last real quote at or before the grid boundary and stores both
<code>detection_grid_msc</code> and the source <code>detection_quote_msc</code>.
The age is their difference.

For each detector:

- baseline observations end at least <code>InpBaselineExcludeMs</code> before
  the candidate boundary;
- the return definition matches the detector window;
- the current source separately resolves 250/500/1000 ms anchors for event
  columns and stores valid flags when an anchor is unavailable;
- percentile, robust Z, efficiency, intensity, move/spread, and spread-ratio
  truth are accumulated individually and as a six-bit mask;
- a candidate event exists only when all six bits are true and quote/baseline
  prerequisites hold.

## Event state machine

<code>TickShockMachine</code> is deterministic and direction-parameterized.

~~~mermaid
stateDiagram-v2
  [*] --> SCANNING
  SCANNING --> BURST_ACTIVE: TSStartBurst at detector event
  BURST_ACTIVE --> BURST_ACTIVE: new directional extreme
  BURST_ACTIVE --> WAIT_PULLBACK: quiet >= 300 ms or age >= 3000 ms / freeze range
  WAIT_PULLBACK --> WAIT_REACCELERATION: first 15..35 percent retracement
  WAIT_PULLBACK --> EXPIRED: retracement >= 50 percent / continuation invalidated
  WAIT_PULLBACK --> EXPIRED: wait timeout
  WAIT_REACCELERATION --> WAIT_REACCELERATION: breakout confirmation count < 2
  WAIT_REACCELERATION --> POSITION_OPEN: two valid reacceleration updates
  WAIT_REACCELERATION --> EXPIRED: retracement >= 50 percent
  WAIT_REACCELERATION --> EXPIRED: no-reacceleration timeout
  POSITION_OPEN --> COOLDOWN: explicit completion helper
  EXPIRED --> COOLDOWN: explicit completion helper
  COOLDOWN --> SCANNING: cooldown deadline
~~~

The research event remains in its global pool even when its machine becomes
terminal because scenarios and 120-second MFE/MAE still need later quotes.
<code>POSITION_OPEN</code> is a state-machine reachability label; the research
EA never submits an MT5 order.

### Burst

- Up: a higher Mid updates <code>burst_extreme</code> and
  <code>last_extreme_msc</code>.
- Down: a lower Mid does the symmetric update.
- Freeze occurs after the quiet interval or maximum burst age.
- <code>burst_start</code>, frozen extreme, and range are not later re-searched.
- Post-burst continuation is armed only at the freeze tick.

### Pullback

- Up retracement: <code>(burst_high-current_mid)/burst_range</code>.
- Down retracement: <code>(current_mid-burst_low)/burst_range</code>.
- First 15–35% observation freezes the pullback extreme/time and advances to
  reacceleration wait.
- More than 35% but below 50% remains diagnostic and not a new valid pullback.
- At 50% or more, continuation invalidates and reversal is armed.

### Reacceleration

- Up requires later price updates beyond the frozen high.
- Down requires later price updates below the frozen low.
- Two qualifying updates are required.
- The second confirmation arms pullback continuation.
- A 50% retracement or timeout invalidates the continuation path.

### Failed-shock reversal

The reversal signal event time is the real tick time at which continuation first
crosses the invalidation threshold:

<pre>
reversal_signal_msc = continuation_invalidated_msc
</pre>

The shared signal clock refuses a second registration. The current EA also
tracks <code>g_reversal_signal_overwrites</code>. Entry still requires a later
real same-symbol tick; it cannot consume the invalidating tick itself.

## Strategy signal generation

| Strategy | Arm/event time | Direction | Known information at arm | Later entry rule |
|---|---|---|---|---|
| Detection continuation | detector boundary event time | shock direction | detector-window shock only | First qualifying later quote; no final-burst policy invalidation |
| Post-burst continuation | burst freeze real tick | shock direction | frozen final burst | First qualifying later quote |
| Pullback continuation | second reacceleration-confirm tick | shock direction | frozen burst and valid pullback | First qualifying later quote |
| Failed-shock reversal | first 50% invalidation tick | opposite shock direction | frozen burst and invalidation | First qualifying later quote |

The signal is first “armed” in the event arrays, then each stop/delay/spread
scenario receives an immutable signal clock. Signal arm is not a fill.

## Time model

### Named clocks

| Clock | Meaning | Origin |
|---|---|---|
| detection_grid_msc | Ideal detector boundary | grid scheduler |
| detection_quote_msc | Real quote supporting the boundary | last same-symbol tick at/before boundary |
| detection_quote_age_ms | Grid minus supporting quote | derived |
| signal_event_msc | Market/state event timestamp | detector boundary or real transition tick |
| signal_processing_msc | Earliest recorded EA recognition time | dispatcher processing clock |
| entry_eligible_msc | Earliest submission-complete time | mode formula |
| entry_quote_msc | First real same-symbol quote accepted for entry | scenario tick evaluation |
| exit_msc | Barrier or hard-time exit quote time | scenario tick evaluation |

### Eligibility formulas

<pre>
IDEAL_EVENT_STUDY:
  entry_eligible_msc = signal_event_msc + requested_delay_ms

REALIZABLE_EA:
  entry_eligible_msc =
    max(signal_event_msc + requested_delay_ms,
        signal_processing_msc + submit_latency_ms)
</pre>

Current shared entry logic enforces:

<pre>
entry_quote_msc >  signal_event_msc
entry_quote_msc >= entry_eligible_msc
REALIZABLE_EA => entry_quote_msc >= signal_processing_msc
</pre>

The strict first comparison is what prevents 0 ms scenarios from filling on the
same real tick used to decide the signal.

### Global merge and processing time

The pending sort establishes event-time order across symbols. The watermark is
the minimum <code>last_time_msc</code> frontier of all configured symbols; only
ticks strictly below it are released. A same-symbol group sharing
<code>time_msc</code> is kept intact, and the last quote in the group closes an
equal grid boundary.

The dispatcher computes a processing lower bound from current terminal time and
latest observable symbol quote. If a quiet symbol delays the watermark, the
released historical tick's processing time can be much later than its event
time. In REALIZABLE_EA this wait becomes execution latency. IDEAL_EVENT_STUDY
does not include it and is therefore descriptive research only.

## Scenario state

Each event has 552 scenario cells.

~~~mermaid
stateDiagram-v2
  [*] --> Uninitialized
  Uninitialized --> Pending: strategy signal registered
  Pending --> Invalid: no broker-valid stop or invalid setup
  Pending --> Active: first real quote after eligibility
  Active --> DoneTP: tradable side reaches TP
  Active --> DoneSL: tradable side crosses SL
  Active --> DoneTime: 120-second deadline
  Active --> Invalid: event finalization without evaluable exit
  Invalid --> [*]
  DoneTP --> [*]
  DoneSL --> [*]
  DoneTime --> [*]
~~~

Stop-grid policy bits (for example risk/burst ≤ 0.45 and spread/risk ≤ 0.20)
are stored as diagnostic policy masks. Broker feasibility, price-grid validity,
and absent signal still determine whether a scenario can run.

### Entry construction

1. Widen Bid/Ask around the same Mid by the scenario spread multiplier.
2. Keep the precomputed absolute stop distance fixed; spread stress does not
   define a different stop strategy.
3. Long entry uses stressed Ask plus configured entry slippage; short uses
   stressed Bid minus entry slippage.
4. Long SL is below entry and TP is rounded upward to the tick grid; short SL is
   above entry and TP is rounded downward.
5. Compute <code>realized_rr=abs(tp-entry)/abs(entry-sl)</code>; reject/count an
   invariant failure if it is below requested RR.
6. Check StopsLevel from current Bid for a long and current Ask for a short.
   FreezeLevel is stored/evaluated separately.

### Exit construction

| Exit | Long observation | Short observation | Fill model |
|---|---|---|---|
| TP | Bid reaches/exceeds TP | Ask reaches/falls below TP | Limit-like at TP |
| SL | Bid reaches/falls below SL | Ask reaches/exceeds SL | First tradable quote beyond barrier plus exit slippage |
| Time | Bid at/after deadline | Ask at/after deadline | Market side at first eligible quote |

Gross R is based on actual modeled exit price, so a gapped stop may be below
-1R. Commission is converted to R separately, and net result is gross R minus
commission R.

## Checkpoint tracking

Detection-relative and burst-end-relative MFE/MAE are separate arrays at
5/10/20/30/60/120 seconds. Best and worst Mid are maintained after each
reference point, but the checkpoint price columns retain Bid/Ask. Missing
checkpoints remain explicitly unfinished until terminal event release.

## Event completion and CSV state

An event row is emitted after the state/scenarios/checkpoints have reached the
configured completion condition. One event row contains all checkpoints and
all compact scenario encodings; there is no tick-per-row or second-per-row
output. Summary counters are accumulated in memory and written during
<code>OnDeinit</code>. Opening a file with an existing RunId seeks to its end,
which creates a cross-run append-mixing risk.

## Order harness state

~~~mermaid
stateDiagram-v2
  [*] --> SEND_ENTRY
  SEND_ENTRY --> WAIT_ENTRY: OrderCheck and accepted OrderSend
  SEND_ENTRY --> SEND_ENTRY: reject recorded, next cycle
  WAIT_ENTRY --> WAIT_ENTRY: partial DEAL_ENTRY_IN, remaining volume exists
  WAIT_ENTRY --> WAIT_EXIT: full fill or residual cancel confirmed
  WAIT_EXIT --> WAIT_EXIT: wait for planned server barrier or time-close
  WAIT_EXIT --> WAIT_FLAT: exit request/server exit observed
  WAIT_FLAT --> SEND_ENTRY: flat, aggregate deals, complete cycle
  WAIT_FLAT --> DONE: sixth cycle complete
  DONE --> [*]
~~~

The intended six cases are Long/Short × server SL/server TP/time close. Entry
fills are aggregated using requested, filled, and remaining volume. Exit deals,
commission, fee, swap, reason, and timestamps are aggregated from transaction
and history APIs. Environment-dependent observations are reported SKIP or
NOT_OBSERVED, not counted as PASS. There is no injected terminal-process restart;
the “recovery” check can only observe state available in the running process.

## Normal and exceptional paths

| Path | Transition/outcome | Durable evidence |
|---|---|---|
| Insufficient baseline/stale quote/invalid scale | No event; increment pre-skip/funnel | summary only |
| One or more detector gates false | No event; truth count and six-bit mask | summary only |
| Duplicate detector event | No new event | duplicate counter |
| Event pool full/pending queue cap | Cannot retain normal work | capacity diagnostic/log |
| Burst frozen | Post-burst strategy arm; WAIT_PULLBACK | event fields |
| Valid pullback then breakout | Pullback strategy arm; POSITION_OPEN label | event fields/scenarios |
| Deep pullback | Continuation invalid; reversal arm | event fields/scenarios |
| Pullback/reacceleration timeout | EXPIRED | event status/skip |
| No qualifying entry quote | scenario invalid/no-signal | scenario status |
| Broker-invalid barrier | scenario invalid | exact scenario status |
| TP/SL/time | scenario done | entry/exit clocks, gross/net R |
| OnDeinit before natural completion | finalization path closes evidence as available | event/summary output |

## Long/Short symmetry audit

| Concept | Long | Short |
|---|---|---|
| Shock/burst extreme | maximum Mid | minimum Mid |
| Pullback | decline from high | rise from low |
| Reacceleration | break above frozen high | break below frozen low |
| Continuation entry | Ask | Bid |
| Reversal entry | Ask after failed down shock | Bid after failed up shock |
| Protective side check | current Bid | current Ask |
| TP rounding | ceil/outward | floor/outward |
| Exit observation | Bid | Ask |
| Stop gap | lower first Bid | higher first Ask |

No deliberate asymmetric threshold exists. Step 3 must verify symmetry through
the production dispatcher/detector/event/scenario path, not only through direct
state-helper calls.
