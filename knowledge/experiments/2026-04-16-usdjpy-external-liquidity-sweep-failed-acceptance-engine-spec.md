# USDJPY External Liquidity Sweep Failed Acceptance Engine Spec

Date: 2026-04-16

## 1. Closure Memo

### Why Close Dow HS

- OOS did not hold real inventory.
- actual did not repeat with `PF > 1`.
- fixed-TP diagnostics did not rescue the family.
- the weakness was judged to be in the entry family, not in the exit weight.

### Why Close Generic Local Sweep

- inventory existed, but actual aggregate stayed below `PF 1`.
- OOS positives were sparse slices and did not repeat in actual.
- better-looking runs leaned on `time_stop` rescue.
- `acceptance_back_above_failed_high` stayed the dominant failure reason.
- local pivot sweep alone was too generic to produce a durable edge.

### Reuse

- confirmed pivot / swing detection
- `context -> pattern -> execution` three-layer structure
- EMA / ATR handle framework
- risk sizing
- telemetry pipeline
- `MFE / MAE / max unrealized R / min unrealized R`
- partial-first / breakeven after partial
- time-stop comparison framework
- acceptance-exit concept
- validator / summary workflow

### Discard

- triple-top / inverse-triple-top setup definitions
- local-pivot-only sweep reference
- head-and-shoulders naming
- continuation-family naming
- rescue-only filters

## 2. Family Definition

- family name: `USDJPY External Liquidity Sweep Failed Acceptance Engine`
- standalone family
- short-first validation, long mirror implemented from the start
- no flat additive score
- gated rule with Tier A strict first, Tier B optional
- core objective:
  - sweep a participant-visible external level
  - fail to get accepted outside that level
  - reclaim back inside
  - reject the retest
  - continue back away from the failed sweep

## 3. Allowed Timeframes

- context TF: `M15` or `M30`
- pattern TF: `M5` or `M10`
- execution TF: `M3`
- optional later comparison: `M5` execution
- not allowed: `M1`, `H1+`

## 4. Core Hypothesis

The previous generic sweep family let any local pivot act as liquidity. That created inventory, but not enough quality. This family tightens the hypothesis:

- not every local pivot matters
- externally visible levels matter more:
  - context prior swing
  - recent `M30` swing
  - previous-day extreme
- a failed sweep of those levels should carry more information than a failed sweep of a small local pivot

The minimal family will therefore test only these three external level types:

- `context_prior_swing`
- `m30_prior_swing`
- `previous_day_extreme`

Deferred for later only if the family survives:

- pattern session high / low
- round number proximity

## 5. Context Definition

Context keeps the parent-wave classification:

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

## 6. External Liquidity Level Definition

### Short Candidates

- `context_prior_swing_high`
- `m30_prior_swing_high`
- `previous_day_high`

### Long Candidates

- `context_prior_swing_low`
- `m30_prior_swing_low`
- `previous_day_low`

### Level Rules

- the level must be known before the sweep candidate
- the sweep must exceed the level by a minimum pips or ATR threshold
- previous-day levels are computed from allowed intraday bars, not `D1`
- the minimal validator compares one level type at a time

## 7. Pattern State Machine

Pattern reads state transition around the chosen external level.

### Short

- `EXTERNAL_LEVEL_IDENTIFIED`
- `SWEEP_UP`
- `FAILED_ACCEPTANCE_ABOVE`
- `RECLAIMED_BACK_INSIDE`
- `RETEST_REJECTED`
- `BREAKDOWN_READY`

Short logic:

- an external high is identified
- a later pattern high sweeps above it
- pattern close fails to stay accepted above it
- price reclaims back below the level
- a lower retest high forms under the sweep high
- breakdown becomes eligible only after execution confirms continuation down

### Long

- `EXTERNAL_LEVEL_IDENTIFIED`
- `SWEEP_DOWN`
- `FAILED_ACCEPTANCE_BELOW`
- `RECLAIMED_BACK_INSIDE`
- `RETEST_HELD`
- `BREAKOUT_READY`

Long logic mirrors short.

## 8. Execution Trigger

Execution TF is `M3` by default.

### Short

- `EXEC_RECLAIM_CLOSE_CONFIRM`
  - execution close confirms back below the external level
- `EXEC_RETEST_FAILURE`
  - execution retests the external level / failed zone and closes back below
- `EXEC_RECENT_SWING_BREAKDOWN`
  - execution closes below a recent execution swing low after rejection exists

### Long

- `EXEC_RECLAIM_CLOSE_CONFIRM`
  - execution close confirms back above the external level
- `EXEC_RETEST_FAILURE`
  - execution retests the external level / failed zone and closes back above
- `EXEC_RECENT_SWING_BREAKDOWN`
  - execution closes above a recent execution swing high after rejection exists

## 9. Stop / Invalidation / Targets

### Stop

- short stop anchor:
  - `max(sweep high, failure pivot high)`
- long stop anchor:
  - `min(sweep low, failure pivot low)`
- ATR / minimum pip buffer remains enabled

### Invalidation

- short acceptance exit:
  - execution closes back above the failed external high buffer
- long acceptance exit:
  - execution closes back below the failed external low buffer

### Targets

The exit framework is reused unchanged:

- partial-first
- mandatory breakeven after partial
- runner final target
- time stop retained

Initial fixed validation:

- partial target: fib `38.2`
- final target: fib `61.8`
- hold bars: `24`
- exit execution: EA managed

## 10. MQL5 Function Split

- `BuildContextPhase`
- `BuildExternalLiquidityLevels`
- `BuildSweepFailurePattern`
- `DetectShortExternalSweepFailureSetup`
- `DetectLongExternalSweepFailureSetup`
- `BuildExecutionTrigger`
- `BuildEntryPlan`
- `ManageOpenPositions`
- `LogTelemetry`

## 11. OnTick / OnNewBar Pseudocode

1. On every tick, update open-trade excursion statistics.
2. On every tick, manage open positions with partial / BE / acceptance / time-stop logic.
3. On new pattern bar:
   - pass global guards
   - build context phase
   - build external liquidity levels
   - build pattern structure
   - detect short and long external-sweep-failure setups
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

## 12. Initial Tester Plan

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

### Minimal Matrix Order

1. execution trigger comparison
2. external level type comparison
3. pair comparison
4. only after survival: partial / hold / final target
5. Tier A + B last

## 13. Continue / Reject

### Continue

- OOS has real inventory
- actual has enough trades
- telemetry explains the path:
  - `context phase -> external level type -> pattern state -> execution trigger -> exit reason`
- the result is not carried by one trigger, one subtype, or one external level type only

### Reject

- OOS `0 trades`
- actual only shows sparse survivors
- subtype collapse is strong
- enough trades still produce `PF < 1`
- the shape survives only through time-stop rescue
