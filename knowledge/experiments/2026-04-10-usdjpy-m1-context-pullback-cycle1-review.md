# USDJPY M1 Context Pullback Cycle 1 Review

- Date: `2026-04-10`
- Family: `usdjpy_20260410_m1_context_pullback`
- Objective: open a fresh `USDJPY` single-method research branch that uses proven `M15` trend context and `M1` pullback-reclaim execution, while staying compatible with later multi-timeframe stacking
- Decision owner roles:
  - `research-director`
  - `systematic-ea-trader`
  - `risk-manager`
  - `forward-live-ops`

## What Was Built

- EA:
  - `mql/Experts/usdjpy_20260410_m1_context_pullback.mq5`
- Structure:
  - `M15` bullish regime:
    - `EMA13 > EMA100`
    - `EMA100` positive slope
    - recent higher-high / higher-low scan
  - `M1` execution:
    - short pullback under fast EMA
    - touch into trigger EMA
    - low-RSI pullback
    - bullish reclaim close back above the fast / trigger EMA stack
  - stop-first sizing:
    - stop planned from recent pullback low or `M1 EMA50`
    - stop floor / cap in pips
    - target from explicit `R`
  - guards:
    - daily hard-loss cap
    - equity DD cap
    - max trades/day
    - consecutive-loss cooldown
    - min-lot risk guard

## Baseline Candidate

- Preset:
  - `reports/presets/usdjpy_20260410_m1_context_pullback-baseline.set`
- Shape:
  - London only
  - `pullbackBars=5`
  - `maxSignalRsi=36`
  - `stop floor/cap = 4 / 10`
  - `target = 1.2R`
- Actual MT5:
  - `9m train`: `+24.01 / PF 1.11 / 13 trades / DD 1.71%`
  - `3m OOS`: `-35.95 / PF 0.00 / 1 trade / DD 0.36%`
- Verdict:
  - quality is not obviously broken, but it is too sparse to treat as an operating candidate
  - the latest executable OOS sample is non-material

## Turnover Probes

### Active Probe

- Preset:
  - `reports/presets/usdjpy_20260410_m1_context_pullback-active.set`
- Intent:
  - extend to `London+NY`
  - shorten pullback requirement
  - loosen reclaim thresholds
  - reduce target to `1.0R`
- Actual MT5:
  - `9m train`: `-762.15 / PF 0.58 / 86 trades / DD 7.94%`
  - `3m OOS`: `-258.19 / PF 0.53 / 24 trades / DD 2.93%`
- Verdict:
  - turnover increased, but expectancy collapsed

### Balanced Probe

- Preset:
  - `reports/presets/usdjpy_20260410_m1_context_pullback-balanced.set`
- Intent:
  - keep the baseline structure mostly intact
  - open `London+NY`
  - loosen pullback / reclaim thresholds only slightly
- Actual MT5:
  - `9m train`: `-788.34 / PF 0.51 / 72 trades / DD 7.88%`
  - `3m OOS`: `-49.68 / PF 0.66 / 9 trades / DD 0.99%`
- Verdict:
  - the middle-ground loosened version also failed

## Main Answer

- The first fresh `M15 context + M1 execution` branch is not yet operable.
- The pattern is the same as earlier `USDJPY` turnover failures:
  - the tight version keeps some quality but is too sparse
  - the looser version raises trade count by admitting noise, then expectancy breaks

## Practical Interpretation

- `M1` execution is not automatically wrong.
- What failed here is the first reclaim specification, not the whole concept.
- The branch did prove something useful:
  - a higher-timeframe regime wrapper can keep `M1` losses contained,
  - but the current reclaim trigger is too fragile to survive when turnover is promoted.

## Operating Decision

- Do not parallelize this family across `M3 / M5` yet.
- Keep the current repo live-track branch unchanged:
  - `quality12b_guarded`
  - `quality12b_stack_parallel_guarded`
- Keep `usdjpy_20260410_m1_context_pullback` as research only.

## Next Best Step

1. Keep the `M15` regime wrapper.
2. Replace the current `M1 reclaim` trigger with a fresher micro-thesis rather than loosening this one further.
3. Candidate directions:
   - `M1` breakout-followthrough after a micro consolidation inside the bullish `M15` regime
   - `M1` trend-down short execution under bearish `M15` regime if event-study evidence supports it
   - `M3` execution as the new base branch if `M1` continues to be too sparse or too noisy
