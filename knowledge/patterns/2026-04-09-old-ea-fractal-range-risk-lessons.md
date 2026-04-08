# Old EA Lessons: Fractal + Range + Stop-First Risk

- Date: `2026-04-09`
- Source EA:
  - `mql/Experts/wrriam_fractal_add_range_for_btcusd_20250818.mq5`

## Extracted Methods

### Method 1: EMA + Fractal + Momentum Trend Follow

- Core shape:
  - stacked EMAs,
  - recent fractal support or resistance,
  - bullish or bearish impulse confirmation,
  - RSI and stochastic used as quality filters rather than standalone entry triggers.
- Reusable lesson:
  - this is a `trend continuation after pullback` method, not a breakout chase.
  - the fractal acts as a structurally meaningful stop anchor.

### Method 2: Low-ADX Range Fade

- Core shape:
  - detect a bounded recent range,
  - confirm the regime with `ATR` and low `ADX`,
  - fade near the range edge,
  - use ATR-based stop and reward.
- Reusable lesson:
  - this is structurally independent from the trend-follow branch.
  - if it survives MT5 friction, it is a natural second or third bucket because it tends to activate in different states.

## Money Management Lessons

- Stop-first design:
  - decide `SL` first from market structure or ATR.
  - derive `TP` from the stop distance using `R` or a target ratio.
- Position sizing:
  - lot size is calculated from account balance and stop distance.
  - the old EA does not choose lot size first and then force a stop.
- Execution guards:
  - min / max lot clamp,
  - consecutive-loss cooldown,
  - virtual SL/TP fallback when broker stop-level constraints block native placement.

## Reusable Doctrine

- Keep `stop distance`, `reward multiple`, and `position sizing` explicit.
- Prefer market-structure or volatility-derived stops over arbitrary fixed targets.
- If a new bucket is added only for turnover, it still has to survive actual MT5 friction.
- Distinct market-state methods should be kept as separate buckets so they can be validated independently.

## Application To Current USDJPY Family

- The current `quality12b_stack_parallel_guarded` branch already follows the multi-bucket idea.
- The next useful import from the old EA is:
  - a truly independent `range` bucket, or
  - a `fractal / stochastic pullback` bucket on a faster timeframe.
- Promotion must stay actual-first:
  - `9 months train`,
  - `3 months OOS`,
  - then demo-forward.
