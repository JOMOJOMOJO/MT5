# Tick-shock Step 4 module mapping

## Source-to-module ownership

| Pre-refactor responsibility | Step 4 owner | Public production entry | Side effects |
|---|---|---|---|
| Common enums/machine/clocks | `TickShockTypes.mqh` | structs/enums | none |
| Input values and symbol metadata | `TickShockConfig.mqh` | `TickShockConfig`, `TickShockSymbolSpec` | none |
| Returns, anchors, robust scale, six gates | `TickShockDetector.mqh` | `TSEvaluateDetectorGates` | result struct only |
| Burst/pullback/reacceleration transitions | `TickShockStateMachine.mqh` | `TSStartBurst`, `TSAdvance` | supplied machine only |
| Signal/eligibility/rounding/broker/barriers | `TickShockExecutionModel.mqh` | clock, target, distance, exit functions | supplied results only |
| Scenario entry assembly | `TickShockScenarioEngine.mqh` | `TSBuildScenarioEntry` | supplied result only |
| Market cluster/same-ms/order key | `TickShockClusterer.mqh` | cluster and ordering functions | supplied clock only |
| Status names and CSV escaping | `TickShockCsvSerializer.mqh` | serializer functions | supplied string only |
| Test/EA facade | `TickShockEngine.mqh` | `TSEngine*` functions | supplied DTO/context only |
| Terminal infrastructure | `TickShockMt5Adapter.mqh` | `TSMt5*` functions | MT5/file/indicator side effects |
| Repository/orchestration/counters | research EA | existing `TSR*`, event handlers | globals and bounded arrays |

## Compatibility mapping

| Stable include | New implementation reached |
|---|---|
| `mql/Include/TickShockStateMachine.mqh` | detector, state machine, execution model, clusterer |
| `mql/Include/TickShockResearchExecution.mqh` | detector, execution model, clusterer |

Neither legacy path is deleted. Existing research/order harness imports compile
without source changes.

## Production wiring map

| EA function | Extracted call | Explicit values passed |
|---|---|---|
| `TSRDetectShock` | `TSEngineEvaluateDetector` | move, percentile, Z, efficiency, intensity, Move/Spread, spread ratio, config |
| event creation in `TSRDetectShock` | `TSEngineStartBurst` | machine, direction, detection time, start/current mid |
| `TSRProcessEventTick` | `TSEngineAdvanceState` | machine, synthetic-compatible quote, config |
| `TSRTryStartScenario` | `TSEngineBuildScenarioEntry` | signal/entry clocks, mode, delays, real quote, spread/stop grid, slippage, spec, RR, known range |
| `TSRInitializeSymbol` | `TSMt5LoadSymbolSpec`, `TSMt5CreateTrendHandles` | symbol |
| dispatcher | `TSMt5CopyInfoTicks`, `TSMt5VisibleQuote`, server clock | symbol cursor/count |
| CSV lifecycle | `TSMt5OpenAppendCsv`, write/flush/close/size | handle and already serialized line |
| `TSRTrend` | `TSMt5TrendLabel` | symbol, timeframe, handles |

## Type map and units

| Type | Important fields | Units/lifetime |
|---|---|---|
| `TickShockConfig` | detector/state/execution parameters | immutable per run after `OnInit`; ms, seconds, percent, R, ticks |
| `TickShockSymbolSpec` | point/tick/volume/stops/freeze | per symbol; price, lots, points |
| `TickShockQuote` | event time, processing time, Bid/Ask/Mid, real flag | one processing call; milliseconds and price |
| `TickShockDetectorResult` | six gates, mask, reject enum, accepted | one detector evaluation |
| `TickShockStateResult` | action/state/time/range/retracement | one quote transition |
| `TickShockExecutionRequest` | clocks, delay, quote, stress, stop, spec distances, RR | one scenario entry attempt |
| `TickShockExecutionResult` | status, clocks, stressed quote, entry/SL/TP/RR, broker/policy | one scenario entry attempt |
| `TickShockClusterAssignment` | cluster ID, overlap | one event |

## Requirement coverage

| Structural requirement | Implementation evidence |
|---|---|
| MT5 API isolated | production EA calls `TSMt5*` for symbol/tick/time/memory/trend/files/timer |
| Detector/counters separated | detector returns DTO; EA applies counters |
| Signal/fill separated | signal clock registration precedes scenario request/fill |
| Explicit execution inputs | `TickShockExecutionRequest` contains clocks, quote, spec distances, RR and policy range |
| State returns action/result | `TSEngineAdvanceState` fills `TickShockStateResult` |
| No config/spec globals in core | config/spec values are parameters/DTO fields |
| Synthetic quote injection | `TSBuildQuote` plus `TSEngine*` facade |
| Enum internal status | `ENUM_TS_SCENARIO_STATUS`, string only in serializer/write boundary |
| CSV separated | serializer has no File API; adapter owns File API |
| EA is wiring-oriented | retained repositories/merge plus facade/adapter composition |

## Known-defect boundary

No Step 3 expected value was changed. The old global watermark, processing-time
construction, current entry and exit semantics, cluster horizon, policy mask,
and append behavior remain. Fixing a known defect requires its Step 3 Test ID
and a later behavior-changing step.
