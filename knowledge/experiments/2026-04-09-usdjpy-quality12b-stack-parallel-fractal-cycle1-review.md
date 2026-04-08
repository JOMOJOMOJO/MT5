# USDJPY quality12b stack parallel fractal cycle1 review

- Date: `2026-04-09`
- Family: `usdjpy_20260402_round_continuation_long`
- Objective: add an old-EA-inspired `fractal + stochastic + EMA pullback` long bucket without damaging the active live-track branch
- Verdict: `guarded reject / loose non-material / active candidate unchanged`

## What changed

- Added a new independent bucket `fractal_trend_long` on `M5` into:
  - `mql/Experts/usdjpy_20260402_round_continuation_long.mq5`
- The new bucket requires:
  - `M15` environment still bullish (`EMA13 > EMA100`, HH/HL, close above slow EMA)
  - `M5` pullback into the EMA stack
  - recent pivot-low support
  - stochastic cross up from oversold
  - stop-first planning from EMA / pivot support with target derived from the prior pivot high

## Candidates tested

- Baseline current-code rerun:
  - preset: `reports/presets/usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_guarded.set`
  - `9m train`: `+563.86 / PF 1.28 / 145 trades / DD 3.06%`
  - `3m OOS`: `+160.27 / PF 2.06 / 20 trades / DD 0.38%`
- Fractal guarded:
  - preset: `reports/presets/usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_fractal_guarded.set`
  - `9m train`: `+472.87 / PF 1.23 / 148 trades / DD 3.36%`
  - `3m OOS`: `+165.85 / PF 2.14 / 20 trades / DD 0.32%`
- Fractal loose:
  - preset: `reports/presets/usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_fractal_loose.set`
  - `9m train`: `+564.45 / PF 1.28 / 148 trades / DD 2.98%`
  - `3m OOS`: `+165.85 / PF 2.14 / 20 trades / DD 0.32%`

## Run references

- Baseline rerun train:
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-09-013454-001141-usdjpy-20260402-round-continuati.json`
- Baseline rerun OOS:
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-09-013456-574460-usdjpy-20260402-round-continuati.json`
- Fractal guarded train:
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-09-013304-305923-usdjpy-20260402-round-continuati.json`
- Fractal guarded OOS:
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-09-013306-880056-usdjpy-20260402-round-continuati.json`
- Fractal loose train:
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-09-013309-436426-usdjpy-20260402-round-continuati.json`
- Fractal loose OOS:
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-09-013311-972889-usdjpy-20260402-round-continuati.json`

## Interpretation

- The guarded fractal bucket is not promotable.
  - It increases train trade count slightly, but it weakens the long-window train profile too much.
- The loose fractal bucket is not strong enough to replace the active candidate.
  - It is slightly better than the baseline on train and recent OOS, but the lift is small.
  - More importantly, it does not increase the latest executable OOS turnover at all.
- The bucket is not yet pulling its weight in the period that matters most.
  - `fractal_trend_long` fires in train, but it contributes `0` trades in the latest `2026-01-01` to `2026-03-31` OOS window.

## Promotion decision

- Keep the active turnover-biased live-track branch unchanged:
  - `reports/presets/usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_guarded.set`
- Do not promote either fractal variant into the release packet yet.

## Next step

- The next serious cycle should not be another looser long fractal sweep.
- The best next thesis is either:
  - a truly independent `short` bucket, or
  - a fresh `M5` long thesis outside the same continuation / pullback neighborhood.
