# Tick-shock research CSV schema

## Output policy

- `events.csv`: one row per detected event. The row is finalized after its state and 120-second observation horizon complete.
- `trades.csv`: the research EA writes only the header because it cannot order. A trading EA would write one completed lifecycle per row.
- `summary.csv`: final aggregate counters only.
- `symbol_specs.csv`: one row per monitored symbol.
- Raw ticks, detector grids, 1-second samples, and timer callbacks are never written as time-series CSV.
- Pre-event gate failures are counts in `summary.csv`; post-event state failures are `state_skip_reason` in the event row.

## Run identity and append safety

Every output CSV has a sibling `<csv-path>.runmeta` sidecar containing the
RunId, deterministic source/config metadata fingerprint, and exact CSV header.
Appending is allowed only when all three values match. A non-empty CSV without
valid matching metadata, a reused RunId with different source/config metadata,
or a different header is rejected as `RUN_ID_COLLISION`. Exact restart/resume
does not write a duplicate header.

## events.csv

Core groups are:

- identity: `event_id`, `execution_mode`, `symbol`, `direction`, `detector_window_ms`, `symbol_cluster_id`, `market_cluster_id`, and separate overlap flags;
- gate result: `shock_gate_mask`;
- clocks: `detection_time_msc`, `detection_grid_msc`, `detection_quote_msc`, `detection_quote_age_ms`, `signal_processing_msc`, and `merge_lag_ms`;
- detection quote: Bid, Ask, Mid, start Mid, and detection shock range;
- detector diagnostics: 250/500/1,000ms log returns, percentile move, median/MAD/robust scale, floor flag, robust Z, efficiency, intensity, spread and ratio fields;
- frozen burst and pullback/reacceleration fields;
- M15/H1, alignment, session, and news labels;
- final state and post-event skip reason;
- signal-event and signal-processing clocks for each of four strategies;
- detection-anchor and burst-anchor Bid/Ask/MFE/MAE at 5, 10, 20, 30, 60 and 120 seconds;
- `scenario_grid_encoding` and `scenario_grid`.

In `REALIZABLE_EA`, merge/watermark recognition time is part of realizable latency. In `IDEAL_EVENT_STUDY`, it is excluded and the output is not eligible for formal edge claims.

## scenario_grid encoding

Every semicolon-separated item is:

`strategy|w<stop_multiple>|d<requested_delay_ms>|s<spread_pct>|status|key=value...`

Strategies:

- `detection_time_continuation`;
- `post_burst_continuation`;
- `pullback_continuation`;
- `failed_shock_reversal`.

Grid:

- stop width: 1.0x through 12.0x the unstressed fill spread, step 0.5x;
- delay: 0, 100, 250ms;
- spread: 100% and 125%;
- RR: 1.2.

Each item stores `signal_event_msc`, `signal_processing_msc`, `entry_eligible_msc`, and `entry_quote_msc`. In `REALIZABLE_EA`, eligibility is `max(signal_event + requested_delay, signal_processing + submit_latency)`. Entry is the first same-symbol real tick at or after eligibility and strictly later than the signal tick. Grid or synthetic detection quotes cannot fill a scenario.

Each scenario also stores `requested_rr` and tick-rounded `realized_rr`. A valid Long TP is rounded outward by ceiling and Short TP by floor, so `realized_rr >= requested_rr`. StopsLevel feasibility uses current Bid for Long and current Ask for Short; FreezeLevel is a separate diagnostic field.

The paired 100%/125% spread cases use the same absolute risk distance. TP is limit-filled at the barrier. SL uses the first tradable exit-side quote beyond the stop plus configured adverse exit slippage. Time exit uses the current tradable Bid/Ask.

Statuses include `TP_LIMIT`, `SL_GAP`, `TIME_MARKET`, `NO_SIGNAL`, and broker-grid invalidity. Policy mask bits are diagnostic: bit 1 means `spread/risk <= 0.20` passed; bit 2 means `risk/known_range <= 0.45` passed. A failed policy bit does not invalidate an outcome.

## summary.csv

`record_type` values:

- `OVERALL`: events, raw candidates, ticks, scenario counts, diagnostic grid mean, memory, file sizes, runtime;
- `FUNNEL`: burst, pullback, reacceleration and strategy-signal counts;
- `SYMBOL`: symbol event/raw/tick totals;
- `DETECTOR`: evaluable samples, missing grids, noise-floor use, refreshes, histogram overflow;
- `GATE`: per condition `true`, `cumulative`, and `evaluable` counts;
- `GATE_MASK`: complete condition bitmask frequencies;
- `PRE_SHOCK_SKIP`: pre-event count-only reasons;
- `SCENARIO`: strategy/stop/delay/spread results;
- `SCENARIO_STATUS`: exact outcome status counts;
- `DISTRIBUTION`: burst/spread quantiles;
- `CLUSTER`: separate event-row, symbol-cluster, market-cluster, overlap, and duplicate counts; statistical n defaults to market clusters;
- `INVARIANT`: chronological, stale-fill, reversal-clock, RR, and writer-recount violations;
- `BUFFER`: hard capacities, retention rule, and observed pending usage;
- `TICK_QUALITY`: M1 coverage counters and the requirement to parse tester journal fallback;
- `LOG_POLICY`: confirmation that tick/grid CSV is disabled;
- `MODEL`: return, execution, stop, stress, exit, merge and commission assumptions.

## symbol_specs.csv

One row per symbol records digits, point, tick size/value, contract size, stop/freeze levels, volume limits/step, filling mode, configured round-turn commission, and commission evidence source.

MT5 symbol properties do not reliably expose account commission. This run uses an explicit input backed by an order-harness observation; a zero observation must not be generalized to other accounts, symbols, or live conditions.

## Order lifecycle state used by a trading adapter

The research EA does not send orders, but the shared production lifecycle keeps
`requested_volume`, `filled_volume`, `remaining_volume`, `cancelled_volume`,
weighted/average fill, deal count, and resolution state. A partial entry remains
pending until either the requested volume is filled or the residual volume is
confirmed cancelled. If any volume filled, the resolved next state is
`WAIT_EXIT`; unobserved server SL/TP or restart behavior must remain SKIP rather
than PASS.
