# Tick-shock research EA: refactor targets

## Objective and constraints

Step 4 should make the Step 1 behavior injectable and observable before changing
strategy policy. It must not optimize thresholds, broaden event eligibility,
start live/order behavior in the research EA, or treat IDEAL_EVENT_STUDY as
formal execution evidence.

Two change classes must remain in separate commits and tests:

1. **behavior-preserving extraction** — move existing logic behind explicit
   contexts/adapters while golden outputs remain identical;
2. **known-defect correction** — intentionally change a documented behavior
   only after a Step 3 failing test exists.

## Testability assessment

| Area | As-Is rating | Reason | Target |
|---|---|---|---|
| TickShockMachine transitions | High | Deterministic struct-in/action-out include | Keep as pure domain module |
| Execution clock/RR/distance helpers | High for helper tests | Shared include is deterministic; not wired through full harness path | Keep shared and assert through production facade |
| Scenario outcome math | Medium | Mostly deterministic but reads symbol globals, inputs, and aggregate globals | Scenario engine with explicit config/spec/result |
| Grid/detector | Low | Mutates TSRSymbolContext and reads inputs/globals directly | Per-symbol detector object accepting TickQuote |
| Global merge | Low | CopyTicks, terminal clock, pending globals, and processing clock are combined | TickSource + MergeSequencer + ProcessingClock |
| Event lifecycle | Low/medium | 552-scenario embedded event plus global counters/CSV side effects | EventEngine and EventRepository |
| CSV/summary | Low | Formatting, aggregation, file handles, and lifecycle mixed | Record DTOs + writer/reducer |
| HTF/session metadata | Low | Indicator handles and server time are direct MT5 dependencies | TrendProvider and SessionLabeler |
| Research harness | Medium for helper checks, low for integration | Does not inject ticks into production dispatcher/detector | Synthetic production-path driver |
| Order harness | Low deterministic reproducibility | Direct terminal/order/history state | OrderGateway/PositionStore/DealStore/Clock adapters |

## Responsibility-heavy functions

| Function | Current responsibilities | Extraction target |
|---|---|---|
| <code>TSRDispatcher</code> | CopyTicks polling, duplicate cursor, queue allocation, sorting, watermark, processing clock, release diagnostics | <code>IMultiSymbolTickSource</code>, <code>MergeSequencer</code>, <code>IProcessingClock</code> |
| <code>TSRReleasePending</code> | Watermark calculation, same-ms group completeness, global order assertion, production tick dispatch | <code>MergeReleasePolicy</code> and injected tick consumer |
| <code>TSRProcessOneTick</code> | Grid advancement, quote/ring update, events, scenarios, detection, CSV release | <code>SymbolEngine.ProcessTick</code> orchestrating smaller domain services |
| <code>TSRCloseGridBoundary</code> | Quote selection, same-ms semantics, three samples, detector invocation | <code>GridBuilder</code> returning immutable boundary/sample records |
| <code>TSRDetectShock</code> | Prerequisites, baseline, gates, funnel, duplicate/pool, clusters, metadata, returns, machine, signals | <code>ShockDetector</code> + <code>EventFactory</code> |
| <code>TSRProcessEventTick</code> | MFE/MAE, state transitions, signals, scenario start/exit, event terminal state | <code>EventEngine</code> + <code>ScenarioCoordinator</code> |
| <code>TSRTryStartScenario</code> | Clock, stressed quote, stop grid, target rounding, broker feasibility, policy bits, counters | <code>ScenarioEntryEngine</code> with explicit inputs/result |
| <code>TSRWriteEvent</code> | Event serialization, nested scenario encoding, recount mutation, file write | <code>EventRecordMapper</code> + <code>IEventWriter</code> |
| <code>TSRWriteSummary</code> | All reducers, distributions, provenance/model narrative, CSV output | Incremental <code>SummaryAccumulator</code> + writer |
| Order harness <code>OnTick</code> | State control, quote checks, orders, timeouts, observations | <code>OrderHarnessController</code> |
| Order harness <code>CompleteCycle</code> | History selection, deal aggregation, assertion/reporting, next-cycle state | <code>DealAggregator</code> + result reporter |

## Global dependencies to replace

| Global family | Problem | Proposed explicit owner |
|---|---|---|
| g_symbols/g_events/g_pending_ticks | Domain state and infrastructure are globally mutable | <code>ResearchRuntime</code> composition root |
| all funnel/invariant/scenario counters | Functions cannot return a complete observable result | <code>ResearchMetrics</code> passed by reference or emitted events |
| g_event_file/... | Domain functions perform file I/O | writer interfaces at the edge |
| g_is_tester and terminal time | Hidden mode/clock branch | immutable <code>RuntimeEnvironment</code> |
| inputs referenced in helpers | Tests need terminal inputs instead of fixture config | immutable <code>ResearchConfig</code> |
| symbol specs and EMA handles | Market metadata/indicator I/O mixed with state | <code>SymbolSpec</code>, <code>ITrendProvider</code> |
| order harness globals | Controller cannot be replayed deterministically | <code>OrderHarnessContext</code> |

## Pure-function candidates

The function catalog's <code>pure</code> column is intentionally conservative:
any detected MQL built-in is treated as an adapter dependency, even deterministic
math such as <code>MathAbs</code>. These are the authoritative extraction
candidates after replacing trivial math/runtime calls:

- scenario/local/execution-group index encode/decode;
- long/short stressed Bid/Ask construction around Mid;
- outward tick rounding and realized RR calculation;
- broker StopsLevel feasibility from explicit Bid/Ask/spec;
- FreezeLevel diagnostic;
- policy bitmask calculation;
- long/short barrier classification and modeled exit price;
- commission-to-R conversion;
- percentile/median/MAD/histogram quantile calculation over explicit arrays;
- directional efficiency from an explicit tick slice;
- exact-window return and anchor-validity calculation;
- session and HTF-alignment label calculation from supplied values;
- state-machine transitions already in TickShockStateMachine.mqh;
- signal registration, eligibility, first-entry clock, and market-cluster clock
  already in TickShockResearchExecution.mqh;
- summary distribution metrics from immutable completed records.

Pure functions should return a value/result struct and must not increment global
counters. The orchestrator applies metrics based on the returned status.

## Adapter candidates

| Adapter | Production implementation | Test implementation |
|---|---|---|
| ITickSource | CopyTicks(COPY_TICKS_INFO) and duplicate ordinal | Ordered synthetic per-symbol tick arrays |
| IProcessingClock | TimeCurrent/latest visible quote policy | Scripted recognition times |
| ISymbolSpecProvider | SymbolInfo* calls | Fixed JPY/non-JPY/wide-spread specs |
| ITrendProvider | CopyRates/EMA handles on closed bars | Fixed UP/DOWN/NEUTRAL/UNAVAILABLE |
| IMemoryProbe | MQL terminal memory statistics | Deterministic sample stream |
| IEventWriter/ISummaryWriter | FileOpen/FileWrite/FileFlush | In-memory records with schema assertions |
| IOrderGateway | OrderCheck/OrderSend | Scripted accept/reject/partial/retcode |
| IPositionStore | PositionsTotal/PositionGet* | In-memory netting/hedging positions |
| IDealStore | HistorySelect/HistoryDealGet* | Scripted entry/exit deals and costs |
| IRunIdentity | RunId plus code/config/terminal metadata | Collision and resume fixtures |

## Proposed module split

| Module | Contents | MT5 dependency |
|---|---|---|
| TickShockTypes.mqh | enums, DTOs, units, statuses | none |
| TickShockConfig.mqh | validated immutable configuration | minimal input mapping only |
| TickShockRing.mqh | bounded generic tick/grid/sample rings | none |
| TickShockGrid.mqh | same-ms grouping and boundary records | none |
| TickShockDetector.mqh | baseline and six-gate evaluation | none |
| TickShockStateMachine.mqh | burst/pullback/reacceleration transitions | none; retain |
| TickShockExecution.mqh | clocks, quote stress, stop grid, barriers, R | none; expand current include |
| TickShockCluster.mqh | symbol and market clustering | none |
| TickShockEventEngine.mqh | event/scenario lifecycle | none |
| TickShockMetrics.mqh | funnel/invariant/scenario/summary reducers | none |
| TickShockCsv.mqh | schemas and record serialization | File adapter only |
| TickShockMt5Adapters.mqh | CopyTicks, symbol specs, indicators, clock/memory | MT5 |
| TickShockOrderAdapters.mqh | order/position/deal access | MT5; harness only |

The EA file becomes a composition root plus <code>OnInit</code>,
<code>OnTick</code>, <code>OnTimer</code>, and <code>OnDeinit</code>.

## Refactoring order

1. **Freeze Step 3 golden and invariant tests.** Capture current source SHA,
   schemas, exact function count, and minimal synthetic failure cases.
2. **Extract common types/config.** No field/constant/value change; preserve
   scenario index formula and CSV names.
3. **Extract run identity and writers.** Add in-memory writers while preserving
   current append behavior as a golden baseline; fix collision only later.
4. **Extract ring/grid with same-ms tests.** Preserve strict watermark and
   boundary ordering.
5. **Extract detector math and event factory.** Compare gate masks, raw events,
   return valid flags, and clusters byte-for-byte.
6. **Extract scenario engine and metrics.** Preserve all 552 cells and exact
   status/R encodings.
7. **Introduce production-path synthetic driver.** Feed the same per-symbol
   engine called by the EA; no tester-only strategy branch.
8. **Extract merge sequencer/processing clock.** First preserve global watermark
   semantics; only a later intentional change may separate per-symbol decision.
9. **Extract order gateway/controller.** Inject partial fills, barriers,
   rejects, time close, and restart snapshots.
10. **Apply known-defect fixes one at a time.** Each starts from a failing Step 3
    Test ID and updates schema/report evidence explicitly.

## Behavior-preserving boundary

The following must remain byte- or value-equivalent during extraction:

- detector windows and all threshold defaults;
- baseline exclusion and noise floor policy;
- CopyTicks duplicate cursor semantics;
- strict global watermark release and stable ordering;
- same-millisecond group final-quote grid closure;
- event state transition thresholds/timers;
- four strategy signal definitions;
- 23×3×2 scenario layout per strategy and index order;
- spread multipliers, requested delays, stop grid values, and 120-second hold;
- Bid/Ask sides and current SL-gap/time-exit model;
- one event row with compact scenario records;
- no OrderCheck/OrderSend in the research EA.

Any golden mismatch blocks an extraction commit unless the changed behavior is
explicitly assigned a defect ID and tested as a correction.

## Defect-fix boundary

The following are not “cleanup” and require separate deliberate changes:

- rejecting same-RunId append collisions;
- replacing global-watermark decision recognition with per-symbol recognition;
- changing processing clock construction;
- changing stop-grid membership or any shock threshold;
- changing commission assumptions;
- altering event clustering horizon;
- changing SL gap, TP limit, or time-exit fill rules;
- changing CSV schema/encoding;
- changing order-harness restart orchestration.

Current guards for later-real-quote entry, immutable reversal signal,
independent returns, market clusters, outward TP, and Bid/Ask broker distance
must first be locked by production-path tests. Step 4 should not silently
rewrite them while extracting modules.

## Step 3 interface requirements

Before refactoring, the test specification must define:

- a synthetic multi-symbol tick fixture including identical timestamps;
- an explicit processing-time stream independent from event time;
- observable event, signal, eligibility, entry, exit, gate-mask, cluster, and
  scenario records;
- Long/Short paired cases;
- assertions for no production/test shortcut;
- CSV record reparse and aggregate equality;
- order transactions for partial fill and barrier deals;
- a serializable position snapshot for restart injection;
- SKIP/NOT_OBSERVED semantics separate from PASS.

These interfaces are the acceptance contract for Step 4, not permission to
change strategy behavior.
