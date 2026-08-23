# Tick-shock research EA: known defects and validation gaps

## Evidence boundary

The Step 1 source and the baseline evidence are not the same executable image.

- Current research EA SHA-256:
  <code>976148D017E067728DC8827724516A076E7561C89D8D57BCD850D40DCB54A32C</code>
- Baseline <code>summary.md</code> reports EA SHA-256:
  <code>969AC0350AA64EAA1AFFFFECCA660E8CB2FB3877F4280186215A0E89251455C3</code>

Both values are complete 64-hex SHA-256 values. The baseline identity is taken
from the committed Step 1/2 `summary.md`; the historical baseline EA binary or
matching source blob is not present in the checkpoint, so this identifies the
reported run source but does not independently reproduce that executable.

Consequently, a baseline-observed defect can be “guarded in current source”
without being considered fixed until Step 3 exercises the current production
path. Status terms:

- **ACTIVE**: still present in current source/design.
- **BASELINE_CONFIRMED_CURRENT_GUARD_UNVALIDATED**: directly visible in the
  baseline, guarded by current code, but not production-path proven.
- **NOT_AUDITABLE_CURRENT_GUARD_UNVALIDATED**: evidence lacks the necessary
  clock/price fields; current code has a guard that still needs a causal test.
- **OBSERVATION_GAP**: harness truthfully reports SKIP now, but the required
  external event has not been observed.

## Defect register

### TS-KD-001 — processing-before-entry causality

| Field | Description |
|---|---|
| Status | NOT_AUDITABLE_CURRENT_GUARD_UNVALIDATED |
| Files | Research EA; baseline events.csv |
| Functions | <code>TSRDispatcher</code>, <code>TSRProcessOneTick</code>, <code>TSRTryStartScenario</code>, <code>TSResearchTryEntryClock</code> |
| Cause | Historical global-merge replay did not preserve per-scenario processing and eligibility clocks. |
| Impact | A replayed historical quote could appear as an executable fill even though the EA had not recognized the signal then. Formal expectancy would be non-causal. |
| Reproduction input | A signal at event time 1000 ms, recognition/processing at 1600 ms, with real quotes at 1100, 1500, 1600, and 1601 ms. |
| Current actual output | Current helper rejects 1100/1500 and requires at least processing/eligibility; baseline scenario encoding cannot prove this because it lacks the separated clock fields. |
| Desired output | REALIZABLE_EA entry is the first same-symbol real quote satisfying both eligibility and processing invariants; invariant counters remain zero. |
| Step 3 Test ID | TS3-CLOCK-001, TS3-MERGE-001 |

### TS-KD-002 — Detection 0 ms synthetic/stale quote fill

| Field | Description |
|---|---|
| Status | BASELINE_CONFIRMED_CURRENT_GUARD_UNVALIDATED |
| Files | Research EA; baseline events.csv; ResearchExecution include |
| Functions | <code>TSRDetectShock</code>, <code>TSRArmStrategy</code>, <code>TSRTryStartScenario</code>, <code>TSResearchTryEntryClock</code> |
| Cause | Earlier detection scenarios used the grid/detection quote itself as a 0 ms fill even when that quote predated the grid boundary. |
| Impact | Stale or synthetic detection state becomes a tradable price; 0 ms results are optimistic and impossible to execute. |
| Reproduction input | A 1000 ms boundary supported by a 950 ms quote, followed by the next real quote at 1030 ms; requested delay 0. |
| Current actual output | Baseline has 2,484 delay-0 scenario cells encoded with entry time equal to signal time. Current shared clock requires <code>entry_quote_msc &gt; signal_event_msc</code> and stores quote age separately, but the full EA path is not harnessed. |
| Desired output | Signal only arms at detection; entry is 1030 ms. A stale boundary quote never fills a scenario. |
| Step 3 Test ID | TS3-CLOCK-002, TS3-GRID-001 |

### TS-KD-003 — reversal signal timestamp overwrite

| Field | Description |
|---|---|
| Status | NOT_AUDITABLE_CURRENT_GUARD_UNVALIDATED |
| Files | Research EA; StateMachine include; ResearchExecution include |
| Functions | <code>TSRProcessEventTick</code>, <code>TSRArmStrategy</code>, <code>TSRegisterResearchSignal</code> |
| Cause | Earlier logic shifted failed-shock reversal signal time from the invalidating tick to the next tick used for entry preparation. |
| Impact | Requested delay is measured from the wrong origin and the causal trail is lost. |
| Reproduction input | Continuation invalidates at 3000 ms; quotes arrive at 3000, 3100, 3250, and 3601 ms. |
| Current actual output | Current signal clock is immutable and should retain 3000 ms; baseline does not expose a distinct invalidation/signal clock to audit it. |
| Desired output | <code>reversal_signal_msc=continuation_invalidated_msc=3000</code>; even 0 ms fills only after the invalidating tick. |
| Step 3 Test ID | TS3-REV-001 |

### TS-KD-004 — log_return_1000 contains detector-window return

| Field | Description |
|---|---|
| Status | BASELINE_CONFIRMED_CURRENT_GUARD_UNVALIDATED |
| Files | Research EA; baseline events.csv |
| Functions | <code>TSRDetectShock</code>, <code>TSResearchExactLogReturn</code> |
| Cause | Earlier code copied <code>sample.signed_log_return</code> into the 1000 ms diagnostic regardless of detector window. |
| Impact | 250/500/1000 ms detector comparison is mislabeled and cannot support window selection. |
| Reproduction input | Any 500 ms-detected baseline event; compare event columns. |
| Current actual output | Every baseline 500 ms event has <code>log_return_1000=log_return_500</code>; the 250 ms event similarly matches 250 ms. Current source resolves all three anchors independently and has valid flags. |
| Desired output | Three independent returns, with blank plus false valid flag when an exact anchor is unavailable. |
| Step 3 Test ID | TS3-RET-001 |

### TS-KD-005 — symbol cluster used as statistical market cluster

| Field | Description |
|---|---|
| Status | BASELINE_CONFIRMED_CURRENT_GUARD_UNVALIDATED |
| Files | Research EA; ResearchExecution include; baseline events.csv |
| Functions | <code>TSRDetectShock</code>, <code>TSAssignResearchMarketCluster</code> |
| Cause | Earlier <code>cluster_id</code> sequencing was maintained independently per symbol. |
| Impact | One cross-FX market shock is counted multiple times, inflating statistical n. |
| Reproduction input | EURUSD and GBPUSD detections within two seconds. |
| Current actual output | Baseline assigns distinct symbol cluster IDs at shared/near timestamps. Current source writes both symbol and global market cluster IDs. |
| Desired output | Separate <code>event_rows</code>, <code>symbol_clusters</code>, and cross-symbol <code>market_clusters</code>; inference n uses market clusters. |
| Step 3 Test ID | TS3-CLUSTER-001 |

### TS-KD-006 — nearest-tick TP rounding below requested 1.2R

| Field | Description |
|---|---|
| Status | BASELINE_CONFIRMED_CURRENT_GUARD_UNVALIDATED |
| Files | Research EA; ResearchExecution include; baseline events.csv |
| Functions | <code>TSBuildResearchTarget</code>, <code>TSRTryStartScenario</code> |
| Cause | Earlier TP was rounded to the nearest tick rather than outward. |
| Impact | A nominal 1.2R setup can realize less than 1.2 gross R at TP. |
| Reproduction input | Entry/risk where <code>entry±1.2*risk</code> lies inside the nearest tick midpoint. |
| Current actual output | Of 1,380 baseline TP outcomes, 437 have gross TP R below 1.2; minimum is 1.176471. Current code rounds long up and short down and counts violations. |
| Desired output | Every valid TP has <code>realized_rr ≥ requested_rr=1.2</code>. |
| Step 3 Test ID | TS3-RR-001 |

### TS-KD-007 — broker protective distance measured from wrong price basis

| Field | Description |
|---|---|
| Status | NOT_AUDITABLE_CURRENT_GUARD_UNVALIDATED |
| Files | Research EA; ResearchExecution include |
| Functions | <code>TSProtectiveOrderDistanceFeasible</code>, <code>TSRTryStartScenario</code> |
| Cause | Earlier feasibility logic used entry-to-SL/TP distance instead of the broker's current Bid/Ask protection basis and conflated StopsLevel with FreezeLevel. |
| Impact | A shadow outcome may be labeled broker-feasible when a real protective order cannot be placed, or rejected unnecessarily. |
| Reproduction input | Wide spread where long entry Ask is far from Bid and SL is valid from entry but too close to current Bid; symmetric short case. |
| Current actual output | Current source checks long from stressed Bid and short from stressed Ask, while recording FreezeLevel separately. Baseline lacks enough side-price evidence to verify this. |
| Desired output | Exact Bid/Ask-based StopsLevel result and independent FreezeLevel modification diagnostic. |
| Step 3 Test ID | TS3-BROKER-001 |

### TS-KD-008 — research harness does not traverse production detector path

| Field | Description |
|---|---|
| Status | ACTIVE |
| Files | Research reachability harness; research EA |
| Functions | Harness <code>OnInit</code> and test helpers; production <code>TSRDispatcher</code>, <code>TSRProcessOneTick</code>, <code>TSRCloseGridBoundary</code>, <code>TSRDetectShock</code> |
| Cause | The harness directly calls shared clock/state/math helpers with local arrays rather than injecting a synthetic tick stream into the actual dispatcher/grid/detector/event/scenario pipeline. |
| Impact | Helper tests can pass while same-ms grouping, watermark processing, event allocation, signal arm, or scenario entry integration remains broken. |
| Reproduction input | Introduce a fault between grid closure and event signal arm; current helper-only tests remain green. |
| Current actual output | 18 checks exercise shared functions but do not invoke the four production pipeline functions listed above. |
| Desired output | A production-path facade accepts synthetic per-symbol ticks and produces normal event/scenario records without tester-only shortcuts. |
| Step 3 Test ID | TS3-PRODPATH-001 through TS3-PRODPATH-010 |

### TS-KD-009 — actual partial fill not observed

| Field | Description |
|---|---|
| Status | OBSERVATION_GAP |
| Files | Order reachability harness |
| Functions | <code>HarnessFillAdd</code>, <code>SendEntry</code>, <code>OnTradeTransaction</code>, <code>OnDeinit</code> |
| Cause | A unit sequence tests requested/filled/remaining bookkeeping, but the tester run did not necessarily deliver a real partial fill. |
| Impact | Transaction ordering and residual cancel behavior are not externally validated. |
| Reproduction input | Broker/test double returns multiple DEAL_ENTRY_IN records or DONE_PARTIAL for one requested volume. |
| Current actual output | Unit path is labeled UNIT_PASS; actual observation is PASS only when seen, otherwise SKIP/NOT_OBSERVED. |
| Desired output | Deterministic injected transaction test plus at least one separately labeled real observation where available. |
| Step 3 Test ID | TS3-ORDER-001 |

### TS-KD-010 — process restart not injected

| Field | Description |
|---|---|
| Status | OBSERVATION_GAP |
| Files | Order reachability harness |
| Functions | <code>RecoverPositionState</code>, <code>OnInit</code>, <code>OnDeinit</code> |
| Cause | One tester process runs continuously; no unload/reload with a live owned position is orchestrated. |
| Impact | Position reconstruction after actual process/EA restart is not validated. |
| Reproduction input | Open a harness-owned position, unload/reload the EA, then continue server/time exit tracking. |
| Current actual output | <code>actual_process_restart=SKIP, NOT_OBSERVED</code>. |
| Desired output | Injected two-phase run proves volume, direction, start time, SL, TP, deals, and safe management recovery. |
| Step 3 Test ID | TS3-ORDER-002 |

### TS-KD-011 — server SL/TP paths remain environment-dependent

| Field | Description |
|---|---|
| Status | OBSERVATION_GAP |
| Files | Order reachability harness |
| Functions | <code>BuildEntryRequest</code>, <code>OnTick</code>, <code>OnTradeTransaction</code>, <code>CompleteCycle</code> |
| Cause | A near barrier does not guarantee the market will hit the requested server SL/TP before timeout. |
| Impact | Accepted OrderCheck/OrderSend and time close do not prove server barrier execution or deal-reason attribution. |
| Reproduction input | Controlled Long and Short quote streams that cross the configured server barrier. |
| Current actual output | Unobserved barrier cases are SKIP/NOT_OBSERVED and excluded from PASS. |
| Desired output | Long/Short server SL and TP each observed and aggregated, or deterministic broker adapter tests plus separately labeled live/tester observation. |
| Step 3 Test ID | TS3-ORDER-003, TS3-ORDER-004 |

### TS-KD-012 — same RunId CSV append mixing

| Field | Description |
|---|---|
| Status | ACTIVE |
| Files | Research EA |
| Functions | <code>TSROpenCsv</code>, <code>TSROpenOutputs</code> |
| Cause | Files open with READ/WRITE/shared flags and seek to end when content already exists. RunId is the only filename partition. |
| Impact | Re-running the same RunId appends events and summaries from different code/config/processes, duplicates headers/summary scopes, and makes recount comparisons ambiguous. |
| Reproduction input | Run the EA twice with the same InpRunId and log folder. |
| Current actual output | The second run appends to the existing file. |
| Desired output | Fail on collision, create a unique attempt directory/file set, or validate a run metadata fingerprint before explicit resume. |
| Step 3 Test ID | TS3-CSV-001 |

### TS-KD-013 — baseline cannot validate current source

| Field | Description |
|---|---|
| Status | ACTIVE_EVIDENCE_GAP |
| Files | Current research EA; baseline summary.md/events.csv/summary.csv/tick_quality.csv |
| Functions | Whole program/version metadata |
| Cause | Baseline EA SHA differs from current source SHA, and the old CSV schema lacks new clock/invariant fields. |
| Impact | Current fixes cannot inherit the baseline's behavioral evidence. |
| Reproduction input | Compare the two SHA values and current event header with baseline event columns. |
| Current actual output | Source/evidence mismatch is detectable but the report does not constitute current-run validation. |
| Desired output | Step 3 tests and later same-period run capture commit/code SHA, set hash, terminal build, broker/server, execution mode, and complete schema. |
| Step 3 Test ID | TS3-PROVENANCE-001 |

### TS-KD-014 — watermark wait is embedded in execution recognition

| Field | Description |
|---|---|
| Status | ACTIVE_DESIGN_COUPLING |
| Files | Research EA |
| Functions | <code>TSRDispatcher</code>, <code>TSRReleasePending</code> |
| Cause | One global minimum symbol frontier gates release; dispatcher processing time is passed into every later signal path. |
| Impact | Quiet-symbol/chart-dispatch delay becomes recognition latency. This is conservative in REALIZABLE_EA but mixes event ordering, symbol decision, and portfolio coordination and is difficult to test independently. |
| Reproduction input | Active EURUSD ticks while another configured symbol's frontier remains 600 ms behind. |
| Current actual output | EURUSD is held until the watermark advances; its processing clock includes the wait. |
| Desired output | Preserve current behavior during extraction, then explicitly compare a per-symbol decision engine plus global risk/cluster controller in a bug-fix step. |
| Step 3 Test ID | TS3-MERGE-002 |

## Baseline quantitative observations supporting this register

- 19 event rows represent 19 detector events, not independent trades.
- The old evidence contains 7,452 scenario outcomes (19×4×23×3×2).
- Outcome labels are 1,380 TP_LIMIT, 3,111 SL_GAP, 2,961 TIME_MARKET, and
  3,036 NO_SIGNAL.
- Scenario labels are repeated stress conditions on shared market events; they
  are not independent statistical samples.
- The old summary contains no cross-currency market-cluster count and no
  per-scenario separated processing/eligible clock sufficient for causal audit.

## Step 3 gate

No item in a guarded/unvalidated state may be promoted to “fixed” merely because
a helper returns the desired value. Step 3 must prove zero entry-before-
processing, zero stale detection fill, zero reversal timestamp overwrite, zero
global order violation, zero duplicate event, exact scenario CSV recount, and
production-path Long/Short symmetry. Observation gaps must remain SKIP or
NOT_OBSERVED until actually injected or seen.
