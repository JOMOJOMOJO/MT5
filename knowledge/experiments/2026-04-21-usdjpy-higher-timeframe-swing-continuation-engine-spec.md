# USDJPY Higher-Timeframe Swing Continuation Engine Spec

Date: 2026-04-21

## 1. Why Prior Families Are Closed

- `Dow HS` produced weak OOS repeatability and fixed-TP diagnostics did not rescue it.
- `Local / External Liquidity Sweep` produced inventory, but actual aggregate stayed below `PF 1`.
- `N-wave third-leg` clarified `wave1 -> wave2 -> break`, but OOS and actual still failed to show a durable standalone edge.
- `Tokyo-London session box breakout` created inventory, but continuation failed and `acceptance_back_inside_box` dominated the loss path.

The next test should not rescue any of those families. It should change the price horizon.

## 2. Reuse

- confirmed pivots / swing detection
- `context -> pattern -> execution` layering
- ATR / EMA handle infrastructure
- position sizing
- telemetry pipeline
- `MFE / MAE / unrealized R`
- partial-first / BE after partial / runner / time stop
- spread / session / max-position guards
- validator / summary workflow

## 3. Discard

- reversal-first pattern families
- failed-acceptance as the family center
- neckline-centered design
- intraday-only breakout family
- pattern names treated as the edge

## 4. Core Hypothesis

The family should trade continuation from a larger wave rather than intraday reversal:

- context TF identifies `impulse / pullback / exhaustion / range`
- pattern TF waits for a pullback into `38.2 / 50 / 61.8` territory or nearby prior swing structure
- pattern TF then requires a `higher low` or `lower high` plus reclaim / reject progress
- execution TF triggers on reclaim-close, retest-hold/reject, or recent swing break

The family is still standalone. It is not a regime bundle or Method1 extension.

## 5. Minimal Implementation

Family:

- `USDJPY Higher-Timeframe Swing Continuation Engine`

Context phase:

- `CTX_UP_IMPULSE`
- `CTX_UP_PULLBACK`
- `CTX_UP_EXHAUSTION`
- `CTX_RANGE`
- `CTX_DOWN_IMPULSE`
- `CTX_DOWN_PULLBACK`
- `CTX_DOWN_EXHAUSTION`

Pattern state:

- bullish:
  - `PULLBACK_IN_PROGRESS`
  - `FIB_ZONE_REACHED`
  - `HIGHER_LOW_CANDIDATE`
  - `BULLISH_RECLAIM_READY`
  - `CONTINUATION_BREAK_READY`
- bearish:
  - `PULLBACK_IN_PROGRESS`
  - `FIB_ZONE_REACHED`
  - `LOWER_HIGH_CANDIDATE`
  - `BEARISH_REJECT_READY`
  - `CONTINUATION_BREAK_READY`

Execution trigger:

- bullish:
  - `EXEC_RECLAIM_CLOSE_CONFIRM`
  - `EXEC_RETEST_HOLD`
  - `EXEC_RECENT_SWING_BREAKOUT`
- bearish:
  - `EXEC_REJECT_CLOSE_CONFIRM`
  - `EXEC_RETEST_REJECT`
  - `EXEC_RECENT_SWING_BREAKDOWN`

Stop / invalidation / target:

- structure stop below `higher low / pullback low` for longs
- structure stop above `lower high / pullback high` for shorts
- acceptance exit below reclaimed level for longs
- acceptance exit above rejected level for shorts
- partial `38.2`
- final `61.8`
- hold `24`

## 6. Minimal Matrix

- `H1 context x M15 pattern x M5 execution`
- `M30 context x M15 pattern x M5 execution`
- `H1 context x M30 pattern x M15 execution`
- `Tier A strict`
- `long-only`
- trigger compare:
  - `reclaim_close_confirm`
  - `retest_hold_or_reject`
  - `recent_swing_break`

## 7. Promotion Rule

Continue only if:

- OOS has real inventory
- actual has enough trades
- telemetry can explain the win path
- the family does not collapse into one pair / one trigger / one pullback-depth bucket

Reject if:

- OOS is empty
- actual is empty or sparse-only
- trades exist but `PF < 1`
- positive paths survive only through time-stop rescue
