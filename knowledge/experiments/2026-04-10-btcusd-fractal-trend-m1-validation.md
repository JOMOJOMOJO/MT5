# BTCUSD Fractal Trend M1 Validation

- Date: `2026-04-10`
- Roles:
  - `research-director`
  - `systematic-ea-trader`
  - `risk-manager`

## Scope

- Research the old EA method from:
  - `mql/Experts/wrriam_fractal_add_range_for_btcusd_20250818.mq5`
- Isolate only the `trend-follow` branch.
- Keep the original stop-first doctrine:
  - entry from `EMA stack + fractal + momentum filters`
  - stop anchored to the active EMA support / resistance line
  - target derived from the stop distance in `R`

## New Research Artifact

- EA:
  - `mql/Experts/btcusd_20260409_fractal_trend_research.mq5`
- Guard rails added:
  - explicit `risk %`
  - `daily loss cap`
  - `equity DD cap`
  - `max trades/day`
  - `consecutive-loss cooldown`
  - virtual stop fallback for broker stop-level constraints

## Decision

- `M1` does not clear the repo's operating gate.
- The method can be made to trade more often by relaxing `RSI`, but that did not survive long-window validation.
- Therefore the next correct step is not `M1 + M3 + M5 parallel`.
- The next correct step, if the family is continued, is:
  - either redesign the base edge on `M3` or `M5`,
  - or change the stop / entry structure materially enough that the `M1` edge is no longer just a looser copy of the old setup.

## Promotion Status

- Status: `research only`
- Not eligible for:
  - `demo-forward candidate`
  - `small-live staged`
  - `live-discussion ready`
