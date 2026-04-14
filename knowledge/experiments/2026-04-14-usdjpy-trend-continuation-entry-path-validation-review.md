# USDJPY Trend Continuation Entry Path Validation Review

## Scope

- family: `usdjpy_20260414_trend_continuation_pullback_engine`
- mode: long-only
- tier: `Tier A strict` only
- entry path isolation:
  - `ENTRY_ON_PULLBACK_RECLAIM`
  - `ENTRY_ON_HIGHER_LOW_BREAK`
  - `ENTRY_ON_RETEST_CONTINUATION`
- matrix:
  - timeframe pairs: `M15 x M5`, `M30 x M5`, `M15 x M1`, `H1 x M5`
  - target: `PRIOR_SWING`, `FIXED_R`, `FIB`
  - stop: `STOP_PULLBACK_LOW`, `STOP_HIGHER_LOW`
- windows:
  - train: `2025-04-01` to `2025-12-31`
  - OOS: `2026-01-01` to `2026-04-01`
  - actual: `2024-11-26` to `2026-04-01`

## Result

- `ENTRY_ON_PULLBACK_RECLAIM`: no inventory
- `ENTRY_ON_RETEST_CONTINUATION`: no inventory
- `ENTRY_ON_HIGHER_LOW_BREAK`: only path that traded

This already means the current Tier A continuation engine is not a 3-path engine in practice. It collapses to one traded path.

## Aggregate path result

### Train

- `higher_low_break`: `216 trades`, `PF 0.733`, `net -552.47`, `avg realized R -0.079`

### OOS

- `higher_low_break`: `24 trades`, `PF 3.138`, `net +221.97`, `avg realized R +0.264`

### Actual

- `higher_low_break`: `312 trades`, `PF 0.654`, `net -1249.52`, `avg realized R -0.118`

OOS is positive, but actual is decisively negative with enough trades. This is reject-side evidence, not promotion evidence.

## Best sparse survivors

- actual best:
  - `M15 x M5`, `FIB`, `STOP_HIGHER_LOW`: `3 trades`, `PF 2.56`, `net +62.28`
  - `M15 x M5`, `FIXED_R`, `STOP_PULLBACK_LOW`: `3 trades`, `PF 2.29`, `net +51.02`

These are sparse survivors and are not promotion candidates.

## Enough-trades runs

- actual `M15 x M1` family:
  - `42 trades` per run
  - PF range `0.53 - 0.67`
  - net range `-130.87` to `-264.21`

This is the strongest reject signal because it is not a low-sample artifact.

## Telemetry reading

Executed inventory is structurally narrow:
- phase: `htf_up_pullback` only
- fib depth: `natural` only
- entry type: `entry_on_higher_low_break` only

Exit profile on actual:
- `time_stop`: `236`
- `stop_loss`: `57`
- `target`: `16`
- `acceptance_back_below`: `3`

Average realized R on actual:
- all trades: `-0.118`
- wins: `+0.468`
- losses: `-0.640`
- target exits: about `+1.36R`
- time stops: about `+0.05R`
- stop losses: about `-1.19R`

Interpretation:
- the intended reward structure exists only when target is reached
- but target frequency is too low
- most inventory decays into weak time-stop exits before full continuation develops
- the losers are too heavy relative to the realized winners

## Decision

`Reject`.

Reason:
- enough trades in actual with `PF < 1`
- only one entry path creates inventory
- best positive runs are sparse survivors
- realized expectancy is negative even though the design target is around `1.2R+`

This family should not be rescued by adding filters before a new thesis is defined.
