# USDJPY Dow Fractal N-Wave Third-Leg Engine Spec

Date: 2026-04-20

## 1. Closure Memo

### Why Close Dow HS

- OOS repeatability was weak.
- fixed-TP diagnostics did not rescue it.
- the weakness was judged to be in the entry family, not in the exit design.

### Why Close Liquidity Sweep Failed Acceptance

- inventory existed, but actual aggregate stayed below `PF 1`.
- better OOS slices were sparse and leaned on `time_stop`.
- `acceptance_back_*` remained a dominant loss path.
- generic sweep failure did not prove a durable entry edge.

### Reuse

- confirmed pivot / swing detection
- `context -> pattern -> execution` three-layer structure
- ATR / EMA handle framework
- risk sizing
- telemetry pipeline
- `MFE / MAE / unrealized R`
- partial-first / mandatory BE after partial
- time-stop comparison framework
- acceptance-exit concept
- validator / summary framework

### Discard

- pattern names as the family center
- triple-top / inverse-triple-top as edge by themselves
- generic local sweep as the family center
- neckline-only thinking
- rescue-only filters

## 2. Family Definition

- family name: `USDJPY Dow Fractal N-Wave Third-Leg Engine`
- standalone family
- short-first validation, long mirror implemented from the start
- no flat additive score
- gated rule with Tier A strict first, Tier B optional
- objective:
  - detect `wave1`
  - detect `wave2`
  - define the `wave2 invalidation / stop-run line`
  - enter when that line breaks and `wave3` should start

## 3. Allowed Timeframes

- context TF: `M30` or `H1`
- pattern TF: `M5`, `M10`, or `M15`
- execution TF: `M3` or `M5`
- not allowed: `M1`, `H4+`, `D1+`

## 4. Core Hypothesis

- the useful move is not the visual reversal itself
- the useful move is the first release of `wave3`
- `double top`, `double bottom`, `head-and-shoulders`, and `inverse head-and-shoulders` are only ways that `wave2` may finish
- the real trigger is where the traders defending `wave2` get invalidated and their stops fuel the break

## 5. Context Definition

Base phases stay:

- `CTX_UP_IMPULSE`
- `CTX_UP_EXHAUSTION`
- `CTX_RANGE_TOP`
- `CTX_RANGE_MIDDLE`
- `CTX_RANGE_BOTTOM`
- `CTX_DOWN_IMPULSE`
- `CTX_DOWN_EXHAUSTION`

Additional candidates:

- `CTX_BULLISH_CORRECTION_CANDIDATE`
- `CTX_BEARISH_CORRECTION_CANDIDATE`

Minimal context construction:

- recent confirmed pivots
- active-wave high / low
- retracement ratio of the active wave
- `38.2 / 61.8` context bucket
- range position

Tier A short context:

- `CTX_UP_EXHAUSTION`
- `CTX_RANGE_TOP`
- `CTX_BEARISH_CORRECTION_CANDIDATE`

Tier A long context:

- `CTX_DOWN_EXHAUSTION`
- `CTX_RANGE_BOTTOM`
- `CTX_BULLISH_CORRECTION_CANDIDATE`

## 6. Pattern Structure

Pattern layer reads `wave1 / wave2 / invalidation line`, not a named pattern.

### Bullish States

- `WAVE1_UP_CONFIRMED`
- `WAVE2_PULLBACK_IN_PROGRESS`
- `WAVE2_LOW_HELD`
- `WAVE2_INVALIDATION_LINE_DEFINED`
- `WAVE3_BREAK_READY`

### Bearish States

- `WAVE1_DOWN_CONFIRMED`
- `WAVE2_PULLBACK_IN_PROGRESS`
- `WAVE2_HIGH_HELD`
- `WAVE2_INVALIDATION_LINE_DEFINED`
- `WAVE3_BREAK_READY`

### Subtype Labels

Subtype labels are secondary diagnostics only:

- bullish:
  - `double_bottom_wave2`
  - `inverse_hs_wave2`
  - `higher_low_wave2`
- bearish:
  - `double_top_wave2`
  - `hs_wave2`
  - `lower_high_wave2`

## 7. Invalidation Line Types

Bullish candidates:

- `wave1_high`
- `neckline_high`
- `recent_swing_high`

Bearish candidates:

- `wave1_low`
- `neckline_low`
- `recent_swing_low`

The line type is selected from the actual internal structure and saved to telemetry.

## 8. Execution Trigger

### Bullish

- `EXEC_INVALIDATION_CLOSE_BREAK`
- `EXEC_RETEST_HOLD`
- `EXEC_RECENT_SWING_BREAKOUT`

### Bearish

- `EXEC_INVALIDATION_CLOSE_BREAK`
- `EXEC_RETEST_REJECT`
- `EXEC_RECENT_SWING_BREAKDOWN`

## 9. Stop / Invalidation / Targets

### Stop

- bullish:
  - below `wave2 low / right-shoulder low / failure pivot low`
- bearish:
  - above `wave2 high / right-shoulder high / failure pivot high`
- ATR / minimum pip buffer remains enabled

### Invalidation

- bullish acceptance exit:
  - execution closes back below the broken invalidation line
- bearish acceptance exit:
  - execution closes back above the broken invalidation line

### Targets

Exit framework is reused unchanged:

- partial-first
- mandatory BE after partial
- runner final target
- time stop retained

Initial fixed validation:

- partial target: fib `38.2`
- final target: fib `61.8`
- hold bars: `24`
- exit execution: EA managed

## 10. MQL5 Function Split

- `BuildContextPhase`
- `BuildWaveStructure`
- `DetectBullishWave2CompletionSetup`
- `DetectBearishWave2CompletionSetup`
- `BuildExecutionTrigger`
- `BuildEntryPlan`
- `ManageOpenPositions`
- `LogTelemetry`

## 11. Initial Tester Plan

### Priority Pairs

1. `H1 context x M15 pattern x M5 execution`
2. `M30 context x M10 pattern x M5 execution`
3. `M15 context x M5 pattern x M3 execution`

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
3. only after survival: partial / hold / final target
4. Tier A + B last

## 12. Continue / Reject

### Continue

- OOS has real inventory
- actual has enough trades
- telemetry explains:
  - `context phase -> wave subtype -> invalidation line type -> execution trigger -> exit reason`
- results do not collapse into one trigger, one subtype, or one line type

### Reject

- OOS `0 trades`
- actual only shows sparse survivors
- subtype collapse is strong
- enough trades still produce `PF < 1`
- the family survives only through time-stop rescue
