# USDJPY Golden Method S2 Round Breakout Cycle 1

- Date: 2026-04-02
- Family: `usdjpy_20260402_golden_method`
- Scope: `Strategy 2 sell-only`
- Objective: fresh round-number breakout event study -> candidate preset -> actual MT5

## Research Source

- `reports/research/2026-04-02-020757-usdjpy-m5-golden-s2-event-study/summary.md`

## Event Study Findings

- History window: `2024-11-26 14:15` -> `2026-04-01 20:05`
- Event count: `1706`
- Candidate count: `676`
- Top cluster was not broad breakout trading.
- It was a sparse `sell-only` continuation cluster:
  - session `all`
  - prior touches `<= 3`
  - breakout body `>= 4-5 pips`
  - breakout close location `>= 0.60`
  - body/range `>= 0.60`
  - body vs average `>= 1.60`
  - retest delay `<= 48 bars`
  - retest close location `>= 0.70-0.80`
- Study-level result:
  - train around `13-15 trades`, expectancy `0.10-0.19R`
  - OOS around `3 trades`, expectancy about `1.0R`

## Actual MT5 Candidates

### Strict

- preset: `usdjpy_20260402_golden_method-s2-sell-breakout-strict.set`
- train 9m: `net +117.20 / PF 1.19 / trades 6 / DD 2.12%`
- OOS 3m: `net +0.00 / trades 0`

### Loose

- preset: `usdjpy_20260402_golden_method-s2-sell-breakout-loose.set`
- train 9m: `net +105.46 / PF 1.17 / trades 6 / DD 2.12%`
- OOS 3m: `net +0.00 / trades 0`

### Active

- preset: `usdjpy_20260402_golden_method-s2-sell-breakout-active.set`
- train 9m: `net +792.60 / PF 4.98 / trades 5 / DD 1.99%`
- OOS 3m: `net +0.00 / trades 0`

## Verdict

- Fresh `Strategy 2` study did find a real-looking `sell-only` breakout cluster.
- But the signal is extremely sparse.
- More importantly, the best study-side candidates did not convert into actual `3 months OOS` trades in MT5.
- So the immediate blocker is no longer "S2 has no signal at all".
- The blocker is "study signal and current EA expression are still too sparse or misaligned to survive actual OOS".

## Decision

- `Strategy 2` is no longer treated as completely dead.
- But it is still not promotable and not yet a viable frequency engine.
- Do not discuss live promotion from this result.

## Next Action

- Reconcile event-study breakout definition with EA-side breakout detection before more threshold tuning.
- If that reconciliation still leaves `0 trade` OOS, run plateau review for the Golden Method family instead of stretching the same logic further.
