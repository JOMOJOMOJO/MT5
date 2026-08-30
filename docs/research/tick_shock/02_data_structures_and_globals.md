# Tick-shock research EA: data structures and globals (As-Is)

## Document boundary

This inventory describes the Step 1 checkpoint at commit
<code>5f8387029766db54e4ced2329ae434b783cc2aab</code>. It covers the research EA,
the two shared includes, and both harnesses. Values are price units unless a
different unit is stated. MQL event handlers are serialized on one EA event
queue; there is no application-created thread. Nevertheless, <code>OnTick</code>,
<code>OnTimer</code>, <code>OnTradeTransaction</code>, and <code>OnDeinit</code>
share globals, so their event ordering is part of observable behavior.

## Input parameters

### Research EA

| Input | Type/default | Unit | Purpose and validation boundary |
|---|---|---|---|
| InpSymbols | string / six FX symbols | CSV text | Exact broker symbols to select and scan. |
| InpGridMs | int / 250 | ms | Base grid cadence. Detector windows remain the fixed 250/500/1000 ms array. |
| InpBaselineMinutes | int / 15 | minutes | Rolling detector baseline horizon. |
| InpBaselineExcludeMs | int / 2000 | ms | Removes the most recent interval from baseline statistics. |
| InpMinBaselineSamples | int / 300 | samples | Minimum usable samples before shock evaluation. |
| InpShockPercentile | double / 99.5 | percentile | Absolute log-return threshold. |
| InpMinRobustZ | double / 3.5 | robust Z | Minimum robust standardized move. |
| InpMinEfficiency | double / 0.65 | ratio | Minimum path efficiency. |
| InpMinMoveSpreadRatio | double / 4.0 | ratio | Minimum price move/current spread. |
| InpMinTickIntensityRatio | double / 1.5 | ratio | Current tick count/baseline median. |
| InpMaxSpreadMedianRatio | double / 1.5 | ratio | Current spread/five-minute median ceiling. |
| InpMaxQuoteAgeMs | int / 500 | ms | Maximum grid quote age. |
| InpNoiseFloorTicks | double / 1.0 | ticks | MAD scale floor when observed dispersion collapses. |
| InpBurstQuietMs | int / 300 | ms | No-new-extreme interval that freezes a burst. |
| InpBurstMaxMs | int / 3000 | ms | Forced burst maximum. |
| InpPullbackMinPct | double / 15.0 | percent of burst | Continuation pullback lower bound. |
| InpPullbackMaxPct | double / 35.0 | percent of burst | Valid pullback upper bound. |
| InpContinuationInvalidPct | double / 50.0 | percent of burst | Continuation invalidation/reversal arm level. |
| InpPullbackWaitMs | int / 10000 | ms | Pullback/reacceleration waiting horizon. |
| InpReaccelerationConfirmTicks | int / 2 | ticks | Same-direction breakout confirmations. |
| InpRewardRisk | double / 1.2 | R | Requested TP multiple. |
| InpMaxHoldSeconds | int / 120 | seconds | Shadow hard holding limit. |
| InpShadowSlippageTicks | double / 1.0 | ticks | Entry-side shadow slippage. |
| InpShadowExitSlippageTicks | double / 1.0 | ticks | Stop gap/exit slippage increment. |
| InpCommissionPerLotRoundTurn | double / 0.0 | account currency/lot | Explicit round-turn commission assumption. |
| InpCommissionSource | string | label | Provenance label; default requires order-harness evidence. |
| InpExecutionMode | enum / REALIZABLE_EA | enum | IDEAL_EVENT_STUDY or REALIZABLE_EA clock rule. |
| InpSubmitLatencyMs | int / 0 | ms | Added to processing time for realizable eligibility. |
| InpTokyoStartHour / InpTokyoEndHour | int / 0, 9 | server hour | Session label interval. |
| InpLondonStartHour / InpLondonEndHour | int / 8, 17 | server hour | Session label interval. |
| InpNewYorkStartHour / InpNewYorkEndHour | int / 13, 22 | server hour | Session label interval. |
| InpRunId | string / research_v2 | identifier | CSV filename/run partition key. Reuse currently appends. |
| InpLogFolder | string / tick_shock_research | relative common-files path | CSV directory. |
| InpEnableDebug | bool / false | flag | Enables bounded debug output. |
| InpDebugSymbol | string / EURUSD | symbol | Debug scope. |
| InpDebugMaxMessages | int / 200 | messages | Debug cap. |

### Research reachability harness

| Input | Type/default | Unit | Purpose |
|---|---|---|---|
| InpRunId | string / research_v4_production_path | identifier | Harness log name. |
| InpLogFolder | string / tick_shock_research | relative common-files path | Harness CSV directory. |

### Order reachability harness

| Input | Type/default | Unit | Purpose |
|---|---|---|---|
| InpMagicNumber | long / 26082191 | identifier | Harness order ownership. |
| InpVolume | double / 0.01 | lots | Requested entry volume. |
| InpWaitTicksBeforeTimeClose | int / 5 | chart ticks | Delay before client time-close plan. |
| InpBarrierTimeoutTicks | int / 5000 | chart ticks | Maximum barrier-observation wait. |
| InpBarrierDistanceTicks | int / 2 | symbol ticks | Near server SL/TP distance request. |
| InpFarBarrierTicks | int / 1000 | symbol ticks | Opposite far barrier distance. |
| InpEarliestServerHour | int / 1 | server hour | Avoids rollover-sensitive start. |
| InpRunId | string / order_harness_v3_observation_truth | identifier | Order harness log name. |
| InpLogFolder | string / tick_shock_research | relative common-files path | Harness CSV directory. |

## Defines and immutable tables

| Name | Value | Meaning/capacity |
|---|---:|---|
| TSR_DETECTOR_COUNT | 3 | 250, 500, 1000 ms detectors. |
| TSR_SAMPLE_CAPACITY | 3612 | Physical ceiling per detector sample array. |
| TSR_MOVE_HIST_BINS | 2048 | Half-tick absolute-move histogram bins per detector. |
| TSR_TICK_HIST_BINS | 1024 | Tick-count histogram bins per detector. |
| TSR_SPREAD_HIST_BINS | 1024 | Half-tick spread histogram bins per detector. |
| TSR_TICK_CAPACITY | 8192 | Per-symbol short-tick ring physical capacity. |
| TSR_TICK_RETENTION_MS | 5000 | Wall-clock retention for short ticks. |
| TSR_GRID_CAPACITY | 64 | Per-symbol completed grid-point ring. |
| TSR_MAX_ACTIVE_EVENTS | 64 | Global concurrently retained event slots. |
| TSR_PENDING_CAPACITY | 65536 | Global merged-tick pending ceiling. |
| TSR_CHECKPOINT_COUNT | 6 | 5/10/20/30/60/120-second MFE/MAE checkpoints. |
| TSR_STRATEGY_COUNT | 4 | Detection, post-burst, pullback, reversal. |
| TSR_STOP_COUNT | 23 | Broker-valid stop grid choices. |
| TSR_DELAY_COUNT | 3 | 0/100/250 ms requested delays. |
| TSR_SPREAD_COUNT | 2 | 1.0/1.25 spread multipliers. |
| TSR_SCENARIO_COUNT | 138 | Per-strategy scenarios: 23×3×2. |
| TSR_ALL_SCENARIOS | 552 | Per-event scenarios: 4×138. |
| TSR_EXECUTION_GROUP_COUNT | 24 | Strategy×delay×spread groups. |
| TSR_MAX_COPY_TICKS | 8192 | One CopyTicks fetch ceiling. |
| TSR_PRE_SKIP_COUNT | 10 | Pre-candidate skip counters. |
| TSR_SESSION_COUNT | 5 | TOKYO/LONDON/NEW_YORK/OVERLAP/OTHER. |
| TSR_GATE_COUNT | 6 | Percentile, Z, efficiency, intensity, move/spread, spread gates. |
| TSR_GATE_MASK_COUNT | 64 | All six-gate truth masks. |

Immutable arrays are <code>TSR_CHECKPOINT_SECONDS={5,10,20,30,60,120}</code>,
<code>TSR_DETECTOR_MS={250,500,1000}</code>,
<code>TSR_DELAY_MS={0,100,250}</code>, and
<code>TSR_SPREAD_MULT={1.0,1.25}</code>. The EA name constant identifies the
research EA only.

Default logical sample capacities are computed, not all 3612: 3610 for 250 ms,
1806 for 500 ms, and 904 for 1000 ms. The formula is
<code>((15 minutes + 2000 ms) / detector_ms) + 2</code>, capped at 3612.

## Enums

| Enum | Values | Lifetime/use |
|---|---|---|
| ENUM_TSR_STRATEGY | DETECTION_CONTINUATION, POST_BURST_CONTINUATION, PULLBACK_CONTINUATION, FAILED_SHOCK_REVERSAL | Stored by scenario block/index and signal arrays. |
| ENUM_TS_STATE | SCANNING, BURST_ACTIVE, WAIT_PULLBACK, WAIT_REACCELERATION, POSITION_OPEN, EXPIRED, COOLDOWN | Per-event TickShockMachine state. |
| ENUM_TS_ACTION | NONE, BURST_FROZEN, PULLBACK_VALID, REACCELERATION, CONTINUATION_INVALIDATED, PULLBACK_TIMEOUT, NO_REACCELERATION | Return value from deterministic transition calls. |
| ENUM_TS_RESEARCH_EXECUTION_MODE | IDEAL_EVENT_STUDY, REALIZABLE_EA | Selects entry eligibility clock. |
| ENUM_HARNESS_EXIT_PLAN | SERVER_SL, SERVER_TP, TIME | One order-harness cycle plan. |
| ENUM_HARNESS_STATE | SEND_ENTRY, WAIT_ENTRY, WAIT_EXIT, WAIT_FLAT, DONE | Order-harness control state. |

## Structs

| Struct | Fields grouped by unit/responsibility | Lifetime and initialization | Principal update sites | Fixture injection |
|---|---|---|---|---|
| TSRShortTick | <code>time_msc</code> ms; Bid/Ask/Mid prices | Per-symbol 5-second ring; initialized in symbol setup | Tick ingestion/ring append | Yes after extraction of ring adapter |
| TSRGridPoint | boundary <code>time_msc</code>, source <code>quote_msc</code>, Bid/Ask/Mid, age ms, valid | Per-symbol 64-point ring | Grid boundary close | Yes |
| TSRSecondSample | end ms, start/end Mid, signed/absolute log return, price move, tick count, spread, quote age | Three per-symbol rolling arrays | Detector-grid sampling | Yes |
| TSRScenario | lifecycle flags; direction; signal/entry clocks; event/processing/eligible/quote/exit ms; spread/stop/risk/entry/SL/TP; requested/realized RR; Stops/Freeze distances; commission/gross/net R; exit gap/slippage; policy mask/status | 552 elements inside each event; reset at event allocation | Arm, entry, barrier evaluation, event finalization | Yes; presently coupled to event/global counters |
| TSREvent | identity, symbol/direction/detector/cluster; gate and detection evidence; independent returns; baseline statistics; state machine; burst/pullback/reversal state; HTF/session labels; four signal clocks; 552 scenarios; checkpoint arrays | Global pool of 64; reset/reused on new event, retained through 120-second tracking | Detection, tick event advancement, signal arm, scenario evaluation, CSV release | Yes after pool/CSV separation |
| TSRSymbolContext | symbol specification; CopyTicks cursor; tick/grid/sample rings; baseline caches and histograms; indicator handles; funnel/gate/quality counters; symbol-cluster clock | Dynamic array sized to configured symbols in OnInit | CopyTicks dispatcher, grid closure, baseline refresh, detector | Difficult without symbol/tick/indicator adapters |
| TSRMergedTick | symbol index, stable sequence, MqlTick | Dynamic global pending queue | Dispatcher append/sort/release | Yes |
| TickShockMachine | state/direction/timestamps; burst start/extreme/range; pullback extreme; max retracement; reacceleration count | Embedded per event; TSReset/TSStartBurst | TSAdvance and explicit expiry/cooldown helpers | Directly injectable |
| TSResearchSignalClock | registered, direction, event ms, processing ms | Embedded per strategy/scenario; reset before arm | Immutable first registration | Directly injectable |
| TSResearchEntryClock | filled, eligible ms, quote ms | Embedded scenario | Eligible calculation and first qualifying quote | Directly injectable |
| TSResearchClusterClock | sequence/current id/start/last ms | One global market clock | Cross-currency cluster assignment | Directly injectable |
| HarnessFillTracker | requested/filled/remaining volume and fill-weighted totals | One global tracker per order cycle | OnTradeTransaction | Needs injected transaction stream |

## Ring buffers and bounded retention

| Store | Scope | Physical/logical bound | Expiry/overwrite |
|---|---|---|---|
| <code>ticks[]</code> | symbol | 8192 | Entries older than newest tick minus 5000 ms are discarded; capacity wrap overwrites oldest. |
| <code>grid[]</code> | symbol | 64 | Circular overwrite of oldest completed boundary. |
| <code>samples250/500/1000[]</code> | symbol/detector | 3610/1806/904 default logical capacities | Circular overwrite after baseline+exclude horizon. |
| histograms | symbol/detector | fixed 3×bin-count arrays | Rebuilt/refreshed for cached baseline horizon; overflow is counted. |
| <code>g_events</code> | EA | 64 | Terminal/written slots are reusable; active tracking remains until completion. |
| <code>g_pending_ticks</code> | EA | 65536 | Released below watermark; capacity hits are counted. |
| event scenarios | event | 552 | Event lifetime; one record per complete scenario cell. |

No tick-level or one-row-per-second CSV is written. Tick and grid data stay in
memory; durable output is event/scenario/summary/specification evidence.

## Scenario indexing

For stop index <code>s</code>, delay index <code>d</code>, spread index
<code>p</code>, and strategy <code>k</code>:

<pre>
local_scenario = (s * TSR_DELAY_COUNT + d) * TSR_SPREAD_COUNT + p
               = (s * 3 + d) * 2 + p
all_scenario   = k * TSR_SCENARIO_COUNT + local_scenario
execution_group = (k * TSR_DELAY_COUNT + d) * TSR_SPREAD_COUNT + p
</pre>

Valid ranges are <code>s=0..22</code>, <code>d=0..2</code>,
<code>p=0..1</code>, and <code>k=0..3</code>. The index is stable only while
those constants and loop nesting remain unchanged.

## Research EA globals

All globals live from load to <code>OnDeinit</code>. Unless noted, initialization
is static zeroing followed by <code>OnInit</code>; updates occur on the serialized
MQL event queue.

| Globals | Type/shape | Role and update sites | Injection concern |
|---|---|---|---|
| g_symbols | TSRSymbolContext[] | Per-symbol state; OnInit and dispatcher/grid/detector/event paths | High; wrap in repository/context |
| g_events | TSREvent[64] | Active/terminal event pool | Medium |
| g_pre_skip | long[] | Symbol×detector×pre-skip counts | Low |
| g_scenario_valid, g_scenario_invalid, g_scenario_sum_r | [552] | Scenario aggregate counters updated at outcome/finalization | Medium |
| g_event_sequence | long | Event IDs | Low |
| g_symbol_cluster_sequence, g_symbol_overlap_events | long | Symbol-local cluster accounting | Low |
| g_market_cluster_clock | TSResearchClusterClock | Cross-symbol 2-second cluster state | Direct clock fixture possible |
| g_market_overlap_events | long | Cross-market overlap count | Low |
| g_duplicate_events, g_event_rows | long | Duplicate detector/event CSV diagnostics | Low |
| g_total_ticks, g_total_raw, g_total_events | long | Funnel totals | Low |
| g_valid_bursts, g_valid_pullbacks, g_reacceleration_signals | long | State funnel totals | Low |
| g_detection_signals, g_post_burst_signals, g_pullback_signals, g_reversal_signals | long | Strategy signal totals | Low |
| g_last_merged_processed_msc, g_merge_order_violations | long | Global order invariant | Clock adapter recommended |
| g_max_merged_batch, g_pending_capacity_hits, g_merge_sequence | long/int | Merge load and stable order | Low |
| g_same_msc_groups, g_same_msc_ticks, g_max_same_msc_group | long | Same-millisecond grouping diagnostics | Low |
| g_entry_before_eligible, g_entry_before_processing, g_stale_detection_fills, g_reversal_signal_overwrites, g_rr_below_requested | long | Causality/RR invariant counters | Must be assertions in Step 3 |
| g_scenario_csv_recount_valid, g_scenario_csv_recount_invalid, g_scenario_csv_recount_sum_r | long/double | Write-time recount for summary/CSV equality | Medium |
| g_pending_ticks | TSRMergedTick[] | Cross-symbol merge queue | High |
| g_memory_samples, g_memory_sum_mb, g_memory_max_mb, g_started_tick_count | counters | Runtime memory and tester timing telemetry | MT5 adapter |
| g_event_file, g_trade_file, g_summary_file, g_specs_file | int handles | CSV output streams | File adapter |
| g_debug_messages | int | Debug rate cap | Low |
| g_is_tester | bool | Environment branch selected in OnInit | Environment adapter |
| g_burst_spread_ratios | double[] | Distribution accumulator | Medium |
| g_scenario_status_counts | long[8] | Scenario status buckets | Low |

## Research harness globals

| Global | Type | Role |
|---|---|---|
| g_file | int | CSV handle. |
| g_passed / g_failed | int | Aggregate assertions. |

The harness can inject structs into shared state/execution helpers, but cannot
inject a CopyTicks stream through the actual research EA entry points.

## Order harness globals

| Globals | Type | Role/update |
|---|---|---|
| g_state | ENUM_HARNESS_STATE | OnTick/OnTradeTransaction control state. |
| g_file | int | Harness CSV handle. |
| g_cycle, g_wait_ticks, g_direction, g_plan | int/enum | Six-cycle sequence and current test case. |
| g_passed, g_failed, g_skipped, g_unit_passed | int | Observation truth totals; SKIP is distinct from PASS. |
| g_signal_msc, g_request_msc, g_first_fill_msc, g_close_msc | long ms | Execution timeline. |
| g_requested_price | price | Entry request evidence. |
| g_exit_volume, g_exit_value | lots and price×lots | Exit deal aggregation. |
| g_commission_total, g_fee_total, g_swap_total | account currency | Deal costs. |
| g_entry_order, g_entry_deal, g_exit_deal | ulong ticket IDs | Server identifiers. |
| g_order_retcode, g_order_retcode_external | uint | Request outcome. |
| g_exit_reason | ENUM_DEAL_REASON | Server/client exit provenance. |
| g_recovery_observed, g_cleanup_after_skip, g_partial_fill_observed | bool | Observation flags, not synthetic PASS evidence. |
| g_direction_time_complete | bool[2] | Long/Short time-close completion. |
| g_entry_fill | HarnessFillTracker | Requested/filled/remaining entry volume. |

The order harness is most tightly coupled to terminal state: it reads live symbol
specifications, positions, history, and transactions and sends actual tester
orders. A deterministic fixture requires order gateway, position repository,
deal history, and clock interfaces.

## Initialization and event-order notes

- <code>OnInit</code> validates inputs, selects symbols, allocates rings and
  histograms, obtains symbol specifications/EMA handles, opens CSVs, and starts
  the 50 ms timer.
- <code>OnTick</code> and <code>OnTimer</code> both dispatch research ticks; they
  do not run concurrently, but either can be delayed by the previous handler.
- The dispatcher-derived processing time is shared state, not the historical
  tick's event time.
- <code>OnDeinit</code> drains/releases eligible records, writes summary, closes
  handles, releases indicators, and stops the timer.
- Order-harness <code>OnTradeTransaction</code> may arrive between ticks and
  mutates the same fill/state globals that <code>OnTick</code> reads.
- Restart destroys all in-memory research event/ring state. CSV files reopen at
  end-of-file for the same RunId, so rows from multiple processes can mix.

## Test fixture readiness summary

Directly injectable today: state machine, signal/entry clock, cluster clock,
rounding/risk helper inputs. Injectable only with wrapper/extraction: tick
source, event pool, grid and detector context, M15/H1 indicators, terminal
memory/time, CSV streams. External-state integration required: CopyTicks
ordering semantics, SymbolInfo properties, OrderCheck/OrderSend, position and
deal history, actual server SL/TP and partial fills.

## Step 4 extracted types and dependency update

This section supersedes the As-Is ownership columns above for production code;
field values, array capacities, scenario indices, and units are unchanged.

### New enums

| Enum | Values/purpose | String boundary |
|---|---|---|
| `ENUM_TS_DETECTOR_REJECT` | accept plus percentile/Z/efficiency/intensity/Move-Spread/spread first rejection | `TSDetectorRejectName` |
| `ENUM_TS_SCENARIO_STATUS` | not-signaled, pending, active, TP/SL/time outcomes, explicit invalid reasons, no-signal/incomplete | `TSScenarioStatusName` |
| `ENUM_TS_ORDER_ENTRY_STATE` | `TS_ORDER_ENTRY_PENDING`, `TS_ORDER_WAIT_EXIT`, `TS_ORDER_ENTRY_CANCELLED`; one entry request from submission through complete fill or remainder resolution | `TSOrderEntryStateName` |
| `ENUM_TS_CSV_OPEN_STATUS` | `TS_CSV_OPEN_CREATED`, `TS_CSV_OPEN_RESUMED`, `TS_CSV_OPEN_RUN_ID_COLLISION`, `TS_CSV_OPEN_IO_ERROR`; explicit append/open result | `TSCsvOpenStatusName` |

Existing `ENUM_TS_STATE`, `ENUM_TS_ACTION`, and
`ENUM_TS_RESEARCH_EXECUTION_MODE` moved without value changes to
`mql/Include/TickShock/TickShockTypes.mqh`.

### New/extracted structs

| Struct | Owner | Lifetime | Mutation/injection |
|---|---|---|---|
| `TickShockConfig` | `TickShockConfig.mqh` | one run; loaded once from inputs | passed const to detector/state core; directly injectable |
| `TickShockSymbolSpec` | `TickShockConfig.mqh` | one symbol/run | adapter populates; tests can supply fixed specs |
| `TickShockQuote` | `TickShockTypes.mqh` | one tick call | built from real or fixture quote; carries event and processing ms |
| `TickShockDetectorResult` | `TickShockTypes.mqh` | one evaluation | core output: six gates, 0..63 mask, reject enum, accepted |
| `TickShockStateResult` | `TickShockTypes.mqh` | one transition | core output; action/state/time/range/retracement |
| `TickShockExecutionRequest` | `TickShockScenarioEngine.mqh` | one scenario attempt | fully explicit clocks/quote/config/spec-derived inputs |
| `TickShockExecutionResult` | `TickShockTypes.mqh` | one scenario attempt | core output; status, entry clock, stressed prices, entry/SL/TP/RR/policy |
| `TickShockClusterAssignment` | `TickShockTypes.mqh` | one event | core output; ID and overlap |
| `TickShockOrderFillState` | `TickShockTypes.mqh` | one order-entry request, reset before submission | directly injectable; `TSResetOrderFillState` initializes requested/remaining lots, `TSApplyEntryDeal` accumulates all entry deals and weighted price, and `TSResolveEntryRemainderCancel` resolves the residual without treating the first partial deal as a completed entry |

`TickShockOrderFillState` stores unitless `state` and `entry_resolved`, lot-valued
`requested_volume`, `filled_volume`, `remaining_volume`, and `cancelled_volume`,
price-times-lot `weighted_fill_value`, symbol-price `average_fill`, and unitless
`deal_count`. Its lifetime begins at `TSResetOrderFillState`; accepted deals and
the final remainder cancellation are the only update sites. It owns no global
state and is directly injectable from a deterministic transaction fixture.

`TickShockMachine`, `TSResearchSignalClock`, `TSResearchEntryClock`, and
`TSResearchClusterClock` retain their pre-refactor fields and semantics but now
live in `TickShockTypes.mqh`.

### Explicit config field units

| Fields | Unit |
|---|---|
| `grid_ms`, `baseline_exclude_ms`, `max_quote_age_ms`, burst/pullback timers, `submit_latency_ms` | milliseconds |
| `baseline_minutes` | minutes |
| `max_hold_seconds` | seconds |
| shock percentile, efficiency/ratio thresholds, RR | scalar |
| pullback/continuation thresholds | percent |
| entry/exit slippage, noise floor | tick-size multiples |
| commission | account currency per lot round turn |

### Capacity and index preservation

No capacity changed in Step 4 or Step 6: tick ring 8,192 with 5,000 ms
retention; grid 64; compile-time physical sample ceiling 3,612 with default
per-detector logical capacities 3,610/1,806/904 for 250/500/1,000 ms;
active events 64; pending merge 65,536; scenarios 552 per
event. The index formulas remain:

```text
local = (stop_index * 3 + delay_index) * 2 + spread_index
all   = strategy * 138 + local
group = (strategy * 3 + delay_index) * 2 + spread_index
```

### Global ownership after extraction

`g_core_config : TickShockConfig` is the only new EA global. `OnInit` maps the
unchanged inputs into it, after which core calls receive it as a const argument.
The existing `g_symbols`, `g_events`, bounded rings, merge queue, counters, and
file handles remain owned by the EA composition root. Core modules introduce no
module-level mutable globals.

### MT5/event-queue notes

All handlers still execute on the serialized MQL event queue. The adapter does
not add threads. `TickShockMt5Adapter.mqh` is the only new module that owns
SymbolInfo, CopyTicks, indicator, terminal clock/memory, timer, and file APIs.
Core DTOs are therefore constructible in a Step 5 fixture without terminal
state. The order-free research EA has no broker order lifecycle wiring;
`TickShockOrderLifecycle.mqh` is a deterministic production module exercised by
the harness, while actual `OnTradeTransaction`/server integration remains an
external observation requirement.

## Step 10 explicit runtime contexts

Step 10 preserves all physical/logical capacities and moves mutable cursor,
grid, event/cluster and merge bookkeeping into caller-owned contexts. No module
defines mutable global state.

| Struct | Owner | Fields / units | Lifetime and initialization | Production update sites | Fixture injection |
|---|---|---|---|---|---|
| `TickShockRingState` | `TickShockRing.mqh` | `head`, `count`, `capacity` (cells) | per symbol/ring; `TSRingReset` in symbol init | tick/grid/sample add/drop/find | direct |
| `TickShockGridRuntime` | `TickShockGrid.mqh` | `next_boundary_msc`, `quote_msc` (ms), Bid/Ask/Mid (price) | per symbol; `TSGridReset` | quote observation and grid close advancement | direct |
| `TickShockPercentileResult` | `TickShockBaseline.mqh` | valid, rank/index, lower/upper/value scalar | one calculation; zeroed in function | percentile core only | direct |
| `TickShockRobustStatistics` | same | raw/noise/robust scale and move/Z; floor/valid flags | one baseline/detector calculation | robust core | direct |
| `TickShockBaselineReadiness` | same | valid/minimum sample counts and ready flag | one readiness evaluation | baseline refresh | direct |
| `TickShockEfficiencyResult` | `TickShockMetrics.mqh` | net/path price, efficiency ratio, valid | one detector window | path efficiency core | direct |
| `TickShockCommissionResult` | same | calculation success; one-lot loss/commission account currency; gross/net/commission R; applications count | one scenario commission calculation | pure builder or MT5 adapter | direct builder; adapter integration |
| `TickShockEventKey` | `TickShockEventEngine.mqh` | symbol index, detector window ms, detection ms | one candidate | registration comparison | direct |
| `TickShockSymbolClusterClock` | same | current id, cluster start ms | one symbol/run; reset at symbol init | accepted event registration | direct |
| `TickShockEventRegistration` | same | accepted/duplicate, slot, event sequence, symbol/market cluster IDs and overlap flags | one candidate result | registration function | direct |
| `TickShockEventEngineContext` | same | dynamic active/key arrays bounded by 64; event/cluster/overlap/duplicate/row counters; market clock | one run; reset in `OnInit` | detect/register, event row write and release | direct |
| `TickShockMergedTick` | `TickShockMergeSequencer.mqh` | symbol index, sequence, `MqlTick` | pending until strict watermark release | CopyTicks collection and merge | synthetic `MqlTick` |
| `TickShockPendingRepository` | same | dynamic pending items capped 65,536; next sequence; max/capacity/group/order diagnostics | one run; reset in `OnInit` | collect/sort/release/process/flush | direct |
| `TickShockDetectorCounters` | `TickShockResearchEngine.mqh` | evaluable/raw/valid counts and six gate true/cumulative counters | one symbol+detector/run; reset in symbol init | detector evaluation | direct |

### Ownership changes in `TSRSymbolContext`

- `tick_head/tick_count`, `grid_head/grid_count`, and the three
  `sample_head/sample_count` pairs are represented by `TickShockRingState`.
- latest quote and next grid boundary are represented by
  `TickShockGridRuntime`.
- per-symbol cluster start/id are represented by
  `TickShockSymbolClusterClock`.
- each detector has an explicit `TickShockDetectorCounters` instance. Existing
  CSV-facing counters remain until a later schema-neutral cleanup; they are
  updated alongside the explicit context, and Step 10 output comparison proves
  no funnel drift.

### Composition-root globals after Step 10

`g_event_engine : TickShockEventEngineContext` owns active event keys,
allocation, dedup and cluster counters. `g_pending_repository :
TickShockPendingRepository` owns pending ticks and merge diagnostics. The
scenario/event records, per-symbol contexts, summary counters, file handles and
immutable input-derived `g_core_config` remain at the EA composition root.
Modules receive context/config explicitly and own no global input.

### Capacity preservation

- physical detector sample cap: 3,612 cells;
- default logical capacities: 3,610 / 1,806 / 904 cells for 250/500/1,000ms;
- tick ring: 8,192 cells with 5,000ms retention;
- grid ring: 64; active event slots: 64; pending repository: 65,536;
- strategies/stops/delays/spreads/scenarios remain 4/23/3/2/552.

MQL handlers remain serialized. The refactor adds no thread and does not alter
the strict global-watermark release condition.

## Step 12 integrity structures and globals

- `TickShockCommissionResult` adds validity, typed reason, symbol, source, and
  one-lot loss evidence.
- event registration and event-engine context distinguish pool exhaustion and
  retain its fatal validation flag; physical capacity remains 64.
- `TickShockPendingRepository` owns capacity hits, dropped ticks, cursor stalls,
  stale-symbol count, maximum frontier lag, incomplete-frontier flag and fatal
  reason. Capacity remains 65,536; watermark release is unchanged.
- `TickShockCursorProgress` is the explicit per-CopyTicks-page result.
- `TickShockRunIdentity` contains period, model, broker/server, terminal build,
  source commit, EX5 hash, schema and config.
- `TickShockCsvOpenRequest` separates fresh/resume and carries checkpoint, last
  event sequence and cursor milliseconds.
- `TickShockOrderFillState` adds request/order/position tickets, symbol, Magic,
  direction, seen deals, duplicate/rejection counters and distinct weighted
  entry/exit aggregates. It remains outside the order-free research EA.
- scenario enums distinguish invalid direction, tick size, RR, risk, target
  build and commission. Direction zero serializes as `NONE`.

No detector threshold, RR, stop/delay/spread grid, maximum hold, ring/grid cap,
or scenario index formula changed.

## Step 14R frontier, order and provenance state

`TickShockSymbolFrontierState` is caller-owned per symbol. It separates
`last_quote_msc` from `read_through_msc`, requested from/to milliseconds,
returned/page/copy result and error, history synchronization, current
incompleteness, historical read failure, quiet-range, cursor-stall, page-limit,
final-drain, current/ever stale episode and root-cause fields. It is initialized
by `TSResetSymbolFrontier`, updated only by collector/frontier functions and is
directly injectable by the merge harness.

`TickShockPendingRepository` retains the existing 65,536 tick cap and adds
run-level aggregates for ever-stale symbols, stale instances, incomplete
frontier instances, read failures, quiet ranges, copy pages and final drains.
Quote staleness is diagnostic. Current incomplete read-through blocks release;
unrecovered loss/stall/capacity failures remain validation-fatal.

`TickShockOrderFillState` adds `position_identifier`, last deal-order ticket,
separate entry/exit request and order tickets, and separate entry/exit local
operation IDs. Its lifetime is one harness order lifecycle or restored
snapshot. `TSApplyOrderDeal` updates the explicit state; the research EA neither
owns this state nor sends an order.

`ENUM_TS_COMMISSION_EVIDENCE_STATUS` has four values: unavailable,
tester-observed zero, explicit scenario assumption and broker verified. New EA
inputs also record symbol scope and unit. These values affect evidence/analysis
eligibility only; they do not alter the scenario commission arithmetic.

The implementation schema constant is `tickshock-research-step14r-v1`.
Physical/logical capacities remain: detector sample physical 3,612; default
logical 3,610/1,806/904 for 250/500/1,000ms; tick ring 8,192 with 5,000ms
retention; grid 64; active event slots 64; pending repository 65,536; scenario
grid 552 per event.

## Step 15C event-response additions

`TickShockResponseSnapshot` stores one causal horizon (target/boundary/real
quote time in ms, quote age, Bid/Ask/Mid, raw/directional/absolute log return,
spread and enum status). `TickShockEventResponseState` owns eleven snapshots,
three local-sigma first-passage pairs, online MFE/MAE and hit times, origin
recross, one pending same-ms quote, and drop/duplicate/censor/validation flags.
It is embedded once per active `TSRV1StatisticalTrack`; no unbounded tick list is
created. Constants are 11 horizons, 3 barriers, 1,000ms stale limit, and a
120,000ms response window.

`TSRV1StatisticalTrack.legacy_frozen` separates the original 120-second
detector/funnel lifetime from response-recording completion. Once true, raw
ticks update only the response state. This preserves Step 15B state, signal and
fill behavior while allowing a stale terminal horizon to use its first later
real quote. All fields are initialized by `ZeroMemory` plus `TS15CArmResponse`.

## Step 15E medium-horizon state

The new state is explicit, bounded and embedded once per `TSRSymbolContext` as
`TickShockMediumHorizonContext medium_horizon`. It is production-created and
directly injectable by the Step 15E harness; no unbounded global tick history
was added.

| type | capacity / lifetime | contents and update ownership |
|---|---|---|
| `TickShock15EM1Point` | one completed M1 close | boundary ms, Mid and fallback flag; written by `TS15EStoreM1`. |
| `TickShock15EM1State` | ring 16; latest 11 eligible closes feed 10 RMS returns | ring count/index and current incomplete close. `TS15EObserveMinuteQuote` closes it only after a later minute arrives. |
| `TickShock15ECheckpoint` | 9 per episode | target/quote/processing ms, lag/age/status, Bid/Ask/Mid, normalized moves and MFE/MAE. Written once by `TS15ECapture`. |
| `TickShock15EEntryPath` | 10 per episode: 5 clocks x 2 directions | causal signal/eligible/entry clocks, actual entry Bid/Ask and nine base/1.25x-spread outcomes. |
| `TickShock15EEpisode` | one active/cooldown episode per symbol | anchor/label, repeat metrics, MFE/MAE/recross/variance, counters, fixed arrays and one same-ms pending quote. Active life is 900,000ms plus 60,000ms quiet cooldown; unfinished EOD state is purged. |
| `TickShockMediumHorizonContext` | one per symbol for EA lifetime | M1 state, episode, monotonic sequence and completion/purge/cooldown counters; passed explicitly to domain functions. |

Constants are `TS15E_CHECKPOINTS=9`, `TS15E_ENTRY_CLOCKS=5`,
`TS15E_DIRECTIONS=2`, `TS15E_ENTRY_PATHS=10`, `TS15E_M1_CAPACITY=16`,
`TS15E_HORIZON_MS=900000`, `TS15E_QUIET_MS=60000`, with checkpoint seconds
`5,10,30,60,120,180,300,600,900`. Clocks use ms, Bid/Ask/moves use absolute
symbol price, log/RMS is dimensionless, and severity/counts are unitless. The
module calls no MT5 API and performs no file I/O.

EA-only globals add three handles and row counters for
`medium_horizon_episode_summary`, `medium_horizon_response`, and
`medium_horizon_entry_comparison`. They live from `OnInit` to `OnDeinit`; only
`TSR15EWritePending` serializes them. Schema is
`tickshock-medium-horizon-response-v1`. No all-tick or one-second CSV global
was added.
