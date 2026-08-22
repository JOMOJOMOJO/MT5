# Tick-shock Step 4 testable architecture

## Scope and preservation boundary

Step 4 changes ownership and dependency direction only. Detector thresholds,
baseline exclusion, state thresholds, four signal definitions, 23 x 3 x 2
scenario grid, spread stress, stop construction, RR 1.2, broker checks, exit
rules, merge/watermark semantics, and CSV schema remain unchanged. Known defects
listed in `02_known_defects.md` are deliberately not corrected here.

The research EA remains order-free. `OrderCheck` and `OrderSend` are not present
in the research production path; the order harness remains a separate terminal
integration artifact.

## Component boundary

```text
OnInit / OnTick / OnTimer / OnDeinit
                |
                v
ExpectedValue_MultiCurrency_TickShockResearch.mq5
  composition, bounded repositories, counters, dispatcher/watermark, mapping
        |                                  |
        | explicit DTO/config/spec         | MT5/file/indicator calls
        v                                  v
TickShockEngine.mqh                 TickShockMt5Adapter.mqh
  | detector facade                  SymbolInfo / CopyTicks / time / memory
  | state facade                     EMA closed-bar provider / CSV handle I/O
  | scenario facade
  | cluster facade
  +--> TickShockDetector.mqh
  +--> TickShockStateMachine.mqh
  +--> TickShockScenarioEngine.mqh --> TickShockExecutionModel.mqh
  +--> TickShockClusterer.mqh

TickShockCsvSerializer.mqh
  enum -> stable CSV string, escaping only

TickShockTypes.mqh + TickShockConfig.mqh
  dependency-free domain types and explicit configuration/symbol specification
```

The existing root includes are compatibility facades and preserve both include
paths and public function names:

- `mql/Include/TickShockStateMachine.mqh`
- `mql/Include/TickShockResearchExecution.mqh`

## Event flow

1. `OnInit` maps terminal inputs once into `TickShockConfig`, selects symbols
   through the adapter, loads `TickShockSymbolSpec`, allocates the existing
   bounded rings/histograms, creates indicator handles, and opens CSV sinks.
2. `OnTick` in Tester or `OnTimer` in production invokes the unchanged global
   dispatcher. The adapter supplies per-symbol `COPY_TICKS_INFO` batches.
3. The EA preserves the existing duplicate ordinal, same-millisecond grouping,
   stable `(time_msc, symbol_index, sequence)` order, and strict global
   watermark.
4. The existing grid/baseline repositories calculate explicit detector inputs.
   `TSEngineEvaluateDetector` returns gate booleans, bitmask, first reject enum,
   and accepted flag; counter mutation stays in the EA orchestrator.
5. An accepted detector result creates the existing event record and calls
   `TSEngineStartBurst`. Each real quote is converted to `TickShockQuote` and
   sent to `TSEngineAdvanceState`, which returns action/state/result data.
6. Signal activation stores `TSResearchSignalClock`. Scenario entry assembly
   creates a `TickShockExecutionRequest`; `TSEngineBuildScenarioEntry` returns a
   complete `TickShockExecutionResult`. No file or global counter is touched by
   the scenario core.
7. The EA applies outcome counters and maps enum statuses through
   `TickShockCsvSerializer` before writing the unchanged one-row event format.

## Explicit time model

`TickShockQuote` carries both `time_msc` (event/quote time) and
`processing_msc` (recognition time). `TSResearchSignalClock` owns signal event
and processing timestamps; `TSResearchEntryClock` owns eligibility and actual
quote timestamps. The preserved calculation is:

```text
IDEAL_EVENT_STUDY:
  eligible = signal_event + requested_delay

REALIZABLE_EA:
  eligible = max(signal_event + requested_delay,
                 signal_processing + submit_latency)
```

The entry core accepts only a real quote strictly later than the signal event
and, in REALIZABLE_EA, no earlier than both eligibility and processing time.
Step 4 preserves the current global-watermark recognition delay; replacing it
with per-symbol recognition remains a later defect-correction decision.

## Side-effect separation

| Concern | Domain input/output | Side-effect owner |
|---|---|---|
| Detector gates | scalar metrics + `TickShockConfig` -> `TickShockDetectorResult` | EA increments funnel counters |
| State transition | machine + quote + config -> `TickShockStateResult` | EA starts signals/checkpoints |
| Entry execution | `TickShockExecutionRequest` -> `TickShockExecutionResult` | EA increments invariants/scenario counters |
| Cluster | clock + event time -> assignment | EA stores IDs/overlap counts |
| CSV names/escaping | enum/value -> string | adapter owns handles/write/flush |
| Symbol/tick/trend/time | none | `TickShockMt5Adapter` |

## Synthetic Step 5 entry points

Step 5 must include `mql/Include/TickShock/TickShockEngine.mqh` and call the
same four facades used by the EA:

- `TSBuildQuote`
- `TSEngineEvaluateDetector`
- `TSEngineStartBurst` / `TSEngineAdvanceState`
- `TSEngineBuildScenarioEntry`

Tests provide `TickShockConfig`, `TickShockQuote`, signal clocks, and symbol
spec-derived distances directly. No Tester-only strategy shortcut is required.

## Remaining boundaries

Ring/grid/baseline repositories, event pool, merge repository, and summary
reducers remain in the EA composition file. They are observable through the
same production facade but are not yet independent objects. Step 5 can lock the
production-path math and causality interfaces now; any later extraction must
continue to use the Step 3 expected files without changing their values.
