# USDJPY Dow Fractal Liquidity Sweep Failed Acceptance Engine Spec

Date: 2026-04-16

## 1. Dow HS Family Closure Memo

### Why Close It

- OOS did not produce durable inventory.
- actual did not repeat with `PF > 1`.
- visible positives were sparse survivors, not a broad subtype.
- fixed-TP diagnostics did not rescue the family.
- the weakness was judged to be in the entry family, not in the exit weight.

### Reuse

- confirmed pivot / swing detection
- EMA / ATR handles
- `context -> pattern -> execution` three-layer structure
- risk sizing
- telemetry pipeline
- `MFE / MAE / max unrealized R / min unrealized R`
- partial-first / mandatory BE after partial
- time-stop comparison framework
- acceptance-exit concept

### Discard

- triple-top / inverse-triple-top setup definitions
- neckline-based reversal family assumptions
- head-and-shoulders specific naming
- Dow HS rescue logic

## 2. Family Definition

- family name: `USDJPY Dow Fractal Liquidity Sweep Failed Acceptance Engine`
- standalone family
- short-first validation, but long mirror is implemented from the start
- no flat additive score
- gated rule with Tier A strict first, Tier B optional
- objective: capture the fact that price swept liquidity, failed to hold outside, reclaimed inside, then rejected again

## 3. Allowed Timeframes

- context TF: `M15` or `M30`
- pattern TF: `M5` or `M10`
- execution TF: `M3`
- optional comparison: `M5` execution
- not allowed: `M1`, `H1+`

## 4. Context Definition

Context reads the parent-wave condition using confirmed pivots, EMA position, range position, and active-wave retracement.

- `CTX_UP_IMPULSE`
- `CTX_UP_EXHAUSTION`
- `CTX_RANGE_TOP`
- `CTX_RANGE_MIDDLE`
- `CTX_RANGE_BOTTOM`
- `CTX_DOWN_IMPULSE`
- `CTX_DOWN_EXHAUSTION`

Tier A short context:

- `CTX_UP_EXHAUSTION`
- `CTX_RANGE_TOP`

Tier A long context:

- `CTX_DOWN_EXHAUSTION`
- `CTX_RANGE_BOTTOM`

Tier B may later add:

- short: `CTX_UP_IMPULSE`
- long: `CTX_DOWN_IMPULSE`

## 5. Pattern State Machine

Pattern uses confirmed pivots on pattern TF and treats sweep failure as a state transition, not as a visual shape.

### Short Side

- reference level comes from a prior confirmed swing high
- a later confirmed high sweeps above that reference
- price fails to stay accepted above the reference and closes back inside
- a reclaim low and then a lower high define rejection structure
- entry is taken only after execution confirms continuation down

States:

- `SWEEP_UP`
- `FAILED_ACCEPTANCE_ABOVE`
- `RECLAIMED_BACK_INSIDE`
- `LOWER_HIGH_FORMED`
- `BREAKDOWN_READY`

### Long Side

- reference level comes from a prior confirmed swing low
- a later confirmed low sweeps below that reference
- price fails to stay accepted below the reference and closes back inside
- a reclaim high and then a higher low define rejection structure
- entry is taken only after execution confirms continuation up

States:

- `SWEEP_DOWN`
- `FAILED_ACCEPTANCE_BELOW`
- `RECLAIMED_BACK_INSIDE`
- `HIGHER_LOW_FORMED`
- `BREAKOUT_READY`

### Tier A Pattern Conditions

- sweep must exceed the reference by a minimum pips or ATR threshold
- reclaim close must return inside the reference band
- structure height must be meaningful relative to ATR / pips
- short lower high must fail below sweep high
- long higher low must hold above sweep low

## 6. Execution Trigger

Execution TF is `M3` by default.

### Short

- `EXEC_RECLAIM_CLOSE_CONFIRM`
  - execution close confirms back below the reclaimed-inside threshold
- `EXEC_RETEST_FAILURE`
  - execution retests the failed-acceptance zone and closes back below
- `EXEC_RECENT_SWING_BREAKDOWN`
  - execution closes below a recent execution swing low after the rejection structure exists

### Long

- `EXEC_RECLAIM_CLOSE_CONFIRM`
  - execution close confirms back above the reclaimed-inside threshold
- `EXEC_RETEST_FAILURE`
  - execution retests the failed-acceptance zone and closes back above
- `EXEC_RECENT_SWING_BREAKDOWN`
  - execution closes above a recent execution swing high after the rejection structure exists

## 7. Stop / Invalidation / Targets

### Stop

- short stop anchor:
  - `max(sweep high, failure pivot high)`
- long stop anchor:
  - `min(sweep low, failure pivot low)`
- ATR / minimum pip buffer stays enabled

### Invalidation

- short acceptance exit:
  - execution closes back above the failed high zone buffer
- long acceptance exit:
  - execution closes back below the failed low zone buffer

### Targets

- partial-first
- mandatory breakeven after partial
- runner final target
- time stop retained

Initial fixed validation:

- partial target: fib `38.2`
- final target: fib `61.8`
- hold bars: `24`
- exit execution: EA managed

Comparables kept in code:

- partial: fib `38.2` / `50.0`
- final: fib `61.8` / prior swing / fixed `R`
- hold bars: `16 / 24 / 32`

Pattern fib targets are measured from the structure height:

- short: `sweep high -> reclaim low`
- long: `reclaim high -> sweep low`

## 8. MQL5 Function Split

- `BuildContextPhase`
- `BuildSweepFailurePattern`
- `DetectShortSweepFailureSetup`
- `DetectLongSweepFailureSetup`
- `BuildExecutionTrigger`
- `BuildEntryPlan`
- `ManageOpenPositions`
- `LogTelemetry`

## 9. OnTick / OnNewBar Pseudocode

1. On every tick, update open-trade excursion statistics.
2. On every tick, manage open positions with partial / BE / acceptance / time-stop logic.
3. On new pattern bar:
   - pass global guards
   - build context phase
   - build pattern structure
   - detect short and long sweep-failure setups
   - choose the preferred valid setup
   - stage pending execution context
4. On new execution bar:
   - discard expired or invalidated pending setups
   - evaluate the selected execution trigger
   - build entry plan
   - size risk
   - submit market order
5. On trade transaction:
   - bind opened position to runtime telemetry
   - log entry / partial / exit events

## 10. Initial Tester Plan

### Priority Pairs

1. `M30 context x M10 pattern x M3 execution`
2. `M15 context x M5 pattern x M3 execution`
3. `M15 context x M10 pattern x M3 execution`

### Initial Fixed Slice

- `Tier A strict`
- `short-only`
- partial `38.2`
- final `61.8`
- hold `24`
- EA-managed exits

### Comparison Order

1. execution trigger comparison
2. pair comparison
3. only after that partial target / hold bars / final target
4. Tier A + B last

## 11. Continue / Reject

### Continue

- OOS has real inventory
- actual has enough trades
- telemetry explains the path:
  - `context phase -> pattern state -> execution trigger -> exit reason`
- the result is not carried by one trigger or one subtype only

### Reject

- OOS `0 trades`
- actual only shows sparse survivors
- subtype collapse is strong
- enough trades still produce `PF < 1`
- the shape only survives through time-stop rescue
