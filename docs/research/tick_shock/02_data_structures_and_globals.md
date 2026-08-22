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
