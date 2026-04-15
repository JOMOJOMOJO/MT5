# USDJPY Dow Fractal Head-And-Shoulders Reversal Engine Spec

Date: 2026-04-14

## 1. Reuse / Discard

### Reuse

- confirmed pivot / swing detection
- context EMA / ATR handles
- fib helper
- risk sizing
- telemetry pipeline
- partial-first / breakeven runner framework
- time-stop comparison framework

### Discard

- continuation-family setup definitions
- `higher_low_break` / continuation-only naming
- `M1` execution dependency
- continuation-only HTF phase assumptions

## 2. Family Definition

- family name: `Dow Fractal Head-And-Shoulders Reversal Engine`
- standalone family
- context reads parent-wave condition with Dow structure
- pattern layer reads head-and-shoulders / inverse head-and-shoulders as structural exhaustion + neckline + failure
- execution layer is `M3` only
- default goal is to prove entry-family edge before broad optimization

## 3. Allowed Timeframes

- execution TF: `M3` only
- pattern TF: `M5` or `M15`
- context TF: `M15` or `H1`
- max higher timeframe: `H1`

## 4. Context Phase Model

Context engine returns parent-wave phase using recent confirmed pivots, EMA slope, range position, and active-wave retracement.

- `CTX_UP_IMPULSE`
- `CTX_UP_EXHAUSTION`
- `CTX_RANGE_TOP`
- `CTX_RANGE_MIDDLE`
- `CTX_RANGE_BOTTOM`
- `CTX_DOWN_IMPULSE`
- `CTX_DOWN_EXHAUSTION`

Short bias should come primarily from:

- `CTX_UP_EXHAUSTION`
- `CTX_RANGE_TOP`

Long bias should come primarily from:

- `CTX_DOWN_EXHAUSTION`
- `CTX_RANGE_BOTTOM`

Tier B may additionally allow:

- short: `CTX_UP_IMPULSE`
- long: `CTX_DOWN_IMPULSE`

## 5. Pattern Structure Model

Pattern layer uses confirmed pivot sequences on pattern TF.

### Triple-top / head-and-shoulders short

- sequence: `high -> low -> higher high -> low -> high`
- left shoulder, neckline point 1, head, neckline point 2, right shoulder
- head must be above shoulders in Tier A
- right shoulder must fail to exceed head
- neckline is defined from the two reaction lows
- structure is valid only if neckline depth is meaningful relative to ATR / pips
- pattern state progresses through:
  - `pattern_formed`
  - `pattern_break_ready`
  - `pattern_neck_broken`

### Inverse triple-top / inverse head-and-shoulders long

- sequence: `low -> high -> lower low -> high -> low`
- left shoulder, neckline point 1, head, neckline point 2, right shoulder
- head must be below shoulders in Tier A
- right shoulder must fail to break head
- neckline is defined from the two reaction highs
- structure is valid only if neckline depth is meaningful relative to ATR / pips
- pattern state progresses through:
  - `pattern_formed`
  - `pattern_break_ready`
  - `pattern_neck_broken`

## 6. Execution Model

Execution TF is `M3` only.

### Short triggers

- `EXEC_NECK_CLOSE_CONFIRM`
  - closed `M3` bar confirms below neckline
- `EXEC_NECK_RETEST_FAILURE`
  - neckline break is seen, then retest fails and closes back below
- `EXEC_RECENT_SWING_BREAK`
  - recent `M3` swing low is broken after structure completion

### Long triggers

- `EXEC_NECK_CLOSE_CONFIRM`
  - closed `M3` bar confirms above neckline
- `EXEC_NECK_RETEST_FAILURE`
  - neckline break is seen, then pullback hold closes back above
- `EXEC_RECENT_SWING_BREAK`
  - recent `M3` swing high is broken after structure completion

## 7. Invalidation / Stop / Target

### Invalidation

- hard stop anchor:
  - short: above head / right-shoulder invalidation cluster
  - long: below head / right-shoulder invalidation cluster
- acceptance exit:
  - short: `M3` closes back above neckline buffer
  - long: `M3` closes back below neckline buffer

### Targets

- partial target:
  - fib `38.2`
  - fib `50.0`
- final target:
  - fib `61.8`
  - prior swing on context TF
  - fixed `R`
- after partial:
  - mandatory breakeven move
- time stop:
  - compare `16 / 24 / 32` execution bars

Fib targets are measured from neckline using pattern height.

## 8. MQL5 Function Split

- `BuildContextPhase`
- `BuildPatternStructure`
- `DetectTripleTopSetup`
- `DetectInverseTripleTopSetup`
- `BuildExecutionTrigger`
- `BuildEntryPlan`
- `ManageOpenPositions`
- `LogTelemetry`

## 9. OnTick / OnNewBar Pseudocode

1. On every tick, update open-trade excursion metrics.
2. On new `M3` bar, manage open positions.
3. On new pattern bar:
   - pass global guards
   - build context phase
   - build pattern structure
   - detect short and long structural setups
   - choose one valid setup by bias and recency
   - stage pending execution context
4. On new `M3` bar:
   - if staged setup expired or invalidated, discard it
   - evaluate execution trigger
   - build entry plan
   - size volume by risk
   - submit market order
5. On trade transaction:
   - bind runtime telemetry to the opened position
   - log partial / exit / runner events

## 10. Initial Tester Plan

### Priority pairs

1. `H1 context x M15 pattern x M3 execution`
2. `M15 context x M5 pattern x M3 execution`

### Secondary pairs

3. `H1 context x M5 pattern x M3 execution`
4. `M15 context x M15 pattern x M3 execution`

### Initial comparison order

1. Tier A strict only
2. execution trigger comparison
3. partial target comparison
4. hold-bar comparison
5. final target comparison
6. only then Tier A + B

## 11. Continue / Reject

### Continue

- OOS has real inventory
- actual has enough trades
- telemetry explains the path:
  - `context phase -> pattern structure -> execution trigger -> exit path`
- winning path is not a sparse survivor

### Reject

- OOS `0 trades`
- OOS collapse
- actual inventory collapses into a single subtype
- enough trades with `PF < 1`
- only sparse survivors remain after slicing
