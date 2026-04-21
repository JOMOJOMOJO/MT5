# USDJPY Tokyo-London Session Box Breakout Engine Spec

Date: 2026-04-21

## 1. Close Memo

### Why The Old Families Are Closed

- `Dow Fractal Head-And-Shoulders Reversal Engine`
  - OOS repeatability stayed weak.
  - Fixed-TP diagnostics did not rescue the family.
  - The failure source was entry quality, not only exit design.
- `Liquidity Sweep + Failed Acceptance` families
  - Inventory existed, but actual aggregate stayed below `PF 1`.
  - Positive OOS slices were sparse and did not repeat in actual.
  - Losses were still dominated by acceptance-back-inside behavior and time-stop rescue.
- `N-Wave Third-Leg` family
  - `wave1 -> wave2 -> invalidation break` was structurally clear.
  - OOS and actual still failed to prove durable edge.

### What Is Reused

- risk sizing
- telemetry pipeline
- MFE / MAE / unrealized `R` tracking
- partial-first exit handling
- breakeven move after partial
- time-stop handling
- session / spread / max-position global guards
- ATR handle framework
- validator / summary workflow

### What Is Discarded

- head-and-shoulders setup logic
- sweep / failed-acceptance setup logic as the family core
- `wave1 / wave2 / wave3` setup logic
- complex subtype-first entry definitions
- rescue filters added only to prolong a weak family

## 2. Family Selection

### Selected Family

- `Session High/Low Breakout`

### Why This Family Comes First

- It is simpler than `ORB`.
  - `ORB` immediately adds opening-window length sensitivity.
- It is simpler than `session-driven continuation breakout`.
  - Continuation requires an extra directional state model before the breakout itself.
- It keeps the focus on obvious levels that market participants can see.
  - prior session high
  - prior session low
  - session transition
- It should create inventory faster than the recent structure/reversal families.

### Selected Session Concept

- `Tokyo range -> London breakout`

Meaning:

- Build a fixed Tokyo box from `00:00` to `07:00` broker/server time.
- Trade only London-side breaks from `07:00` to `16:00`.
- Do not trade inside the Tokyo build window.

This intentionally avoids reusing the failed Asia-session execution thesis.
The traded event is the London break of the already-completed Tokyo box, not an Asia-session breakout itself.

## 3. Minimal Family Definition

### Session Context

- session type label: `tokyo_range_london_break`
- range source:
  - `InpRangeTimeframe = M15 or M30`
- execution source:
  - `InpExecutionTimeframe = M5 or M3`
- box definition:
  - `box_high = highest high` during Tokyo build window
  - `box_low = lowest low` during Tokyo build window
  - `box_height = box_high - box_low`
- no-trade if:
  - Tokyo box is not complete yet
  - outside London trade window
  - box range is smaller than minimum threshold
  - box range is larger than maximum threshold
  - spread is too wide
  - one trade has already been taken for that session day

### Breakout Types

- `session_high_breakout`
- `session_low_breakout`

### Trigger Types

1. `EXEC_RANGE_CLOSE_CONFIRM`
   - execution bar closes outside the Tokyo box by a breakout buffer
2. `EXEC_RANGE_RETEST_CONFIRM`
   - breakout is seen first
   - a later retest of the broken box edge holds
   - the bar closes again in breakout direction
3. `EXEC_BREAKOUT_BAR_CONTINUATION`
   - breakout is seen first
   - a later bar breaks the breakout bar extreme in the breakout direction

### Stop / Invalidation / Target

#### Stop

- long:
  - below Tokyo box low minus stop buffer
- short:
  - above Tokyo box high plus stop buffer

#### Invalidation

- long:
  - execution close is accepted back inside the box below `box_high - acceptance buffer`
- short:
  - execution close is accepted back inside the box above `box_low + acceptance buffer`

#### Targets

- partial:
  - `0.382 * box_height` projected from broken box edge
  - fallback to a smaller `R`-based projection if the box target is already behind entry
- final:
  - default `session_extension_100`
    - `1.0 * box_height` projected from broken box edge
  - optional fallback `fixed_R`
- after partial:
  - mandatory breakeven move
- time stop:
  - framework remains available
  - initial validation fixes `24` execution bars

## 4. MQL5 Function Split

- `BuildSessionContext`
- `BuildBreakoutSetup`
- `BuildEntryTrigger`
- `BuildEntryPlan`
- `ManageOpenPositions`
- `LogTelemetry`

## 5. OnTick / OnNewBar Pseudocode

1. On every tick:
   - update open-trade excursion metrics
   - manage open positions
2. On each new execution bar:
   - pass global guards
   - build the completed Tokyo box for the current session day
   - reject the day if the box is invalid or already traded
   - build long and short breakout setups from the same box
   - stage or refresh pending breakout contexts
   - evaluate the selected trigger mode
   - if a trigger fires:
     - build entry plan
     - size position by risk
     - submit order
3. On trade transaction:
   - bind runtime telemetry to the position
   - log partial / final / time-stop / invalidation exits

## 6. Preset Candidates

### strict

- Tokyo box range filter tighter
- larger breakout confirmation buffer
- default validation base preset

### broad

- wider allowed Tokyo box range
- slightly looser breakout / retest tolerance
- used only after strict baseline exists

## 7. Minimal Matrix

### Pairs

1. `M15 range x M5 execution`
2. `M30 range x M5 execution`
3. `M15 range x M3 execution`

### Trigger Comparison

1. `EXEC_RANGE_CLOSE_CONFIRM`
2. `EXEC_RANGE_RETEST_CONFIRM`
3. `EXEC_BREAKOUT_BAR_CONTINUATION`

### Fixed Initial Slice

- trade bias: `both`
  - rationale: the family is symmetric and one-sided restriction would reduce sample without simplifying the rule set
- session concept: `Tokyo range -> London breakout`
- partial target: `box 38.2`
- final target: `session extension 100`
- hold bars: `24`
- EA-managed exits

### Windows

- train: `2025-04-01` to `2025-12-31`
- OOS: `2026-01-01` to `2026-04-01`
- actual: `2024-11-26` to `2026-04-01`

## 8. Continue / Reject

### Continue

- OOS has real inventory
- actual has enough trades
- telemetry can explain the path:
  - `tokyo box -> breakout trigger -> exit path`
- the result is not entirely carried by one trigger or one breakout side
- positive runs are not mostly time-stop rescue

### Reject

- OOS `0 trades`
- actual only has sparse survivors
- enough trades exist but aggregate `PF < 1`
- the family collapses into one trigger or one side only
- whatever looks acceptable is mostly time-stop rescue rather than breakout follow-through
