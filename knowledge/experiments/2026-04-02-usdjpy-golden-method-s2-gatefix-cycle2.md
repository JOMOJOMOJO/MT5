# USDJPY Golden Method S2 Gate-Fix Cycle 2

- Date: 2026-04-02
- Family: `usdjpy_20260402_golden_method`
- Scope: `Strategy 2 sell-only breakout`
- Objective: reconcile study vs EA execution, then verify whether executable OOS edge survives actual MT5 friction

## Root Cause Found

- The previous `0 trade` OOS result was not explained only by a missing breakout definition.
- `Strategy 2` state handling was structurally wrong:
  - the old `OnTick()` flow returned early on `CanOpenAnotherTrade()`
  - so temporary gates like spread/session prevented `Strategy 2` breakout state from being armed or refreshed
- This was fixed by separating:
  - breakout detection and state updates
  - execution-time gate checks just before `OpenPosition()`

## Reconciliation Result

- `reports/research/2026-04-02-023833-usdjpy-golden-s2-reconcile/summary.md`
- Reconciliation showed `4` OOS study events matching the active preset.
- Two were still rejected by rule quality.
- Two passed current logic in the replay tool.

## Model-4 Debug Finding

- Under the realistic `Model=4` tester path, the repaired EA now reaches `signal_fire`.
- But the active preset is still blocked at execution time by spread.
- Key debug evidence from tester log:
  - `2026.02.11 04:20 signal_fire golden_s2_sell`
  - `2026.02.11 04:20 signal_gate_block spread_blocked_2.20_limit_2.00`

## Actual MT5 Results

### Active preset, spread 2.0

- preset: `usdjpy_20260402_golden_method-s2-sell-breakout-active.set`
- train 9m:
  - `net +815.10 / PF 3.02 / trades 7 / DD 1.99%`
  - run: `reports/backtest/runs/usdjpy-20260402-golden-method/usdjpy/m5/2026-04-02-025251-788742-usdjpy-20260402-golden-method-s2.json`
- OOS 3m:
  - `net +0.00 / trades 0`
  - run: `reports/backtest/runs/usdjpy-20260402-golden-method/usdjpy/m5/2026-04-02-025405-223021-usdjpy-20260402-golden-method-s2.json`

### Spread-relaxed probe, spread 2.3

- preset: `usdjpy_20260402_golden_method-s2-sell-breakout-active-spread23.set`
- train 9m:
  - `net +815.10 / PF 3.02 / trades 7 / DD 1.99%`
  - run: `reports/backtest/runs/usdjpy-20260402-golden-method/usdjpy/m5/2026-04-02-030717-701853-usdjpy-20260402-golden-method-s2.json`
- OOS 3m:
  - `net -377.10 / PF 0.38 / trades 4 / DD 4.00%`
  - run: `reports/backtest/runs/usdjpy-20260402-golden-method/usdjpy/m5/2026-04-02-030717-697943-usdjpy-20260402-golden-method-s2.json`

## Interpretation

- `Strategy 2` is not failing because the event-study signal never reaches the EA.
- It is failing because:
  - at live-like spread discipline (`2.0 pips`) the signal is mostly non-executable
  - when spread is relaxed enough to execute (`2.3 pips`), the OOS edge is negative
- So the blocker has moved from `detection bug` to `edge quality under executable spread`.

## Decision

- Keep the gate-order fix.
- Keep the repaired `Strategy 2` instrumentation as a reusable lesson.
- Do not promote `Strategy 2`.
- Do not spend another immediate cycle on `Strategy 2` spread loosening alone.

## Next Action

- Treat `Strategy 2` as still research-only.
- The next USDJPY cycle should either:
  - run a plateau review on the Golden Method family, or
  - open a fresh USDJPY family from bar-data evidence and record any doctrine drift explicitly.
