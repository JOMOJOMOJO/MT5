# USDJPY quality12b stack3 cycle 1 reject

## Objective

- Test a truly independent third `long-only` bucket inside the current `quality12b_stack_guarded` live-track family.
- Keep the existing `round continuation` and `EMA continuation` buckets unchanged.
- Add `breakout-followthrough` only if it improves turnover without damaging the latest executable `3 months OOS` window.

## Change

- Integrated `breakout-followthrough long` into `usdjpy_20260402_round_continuation_long.mq5` as `SIGNAL_BREAKOUT`.
- Kept bucket order as:
  - `round_continuation_long`
  - `ema_sidecar_long`
  - `breakout_sidecar_long`
- Candidate preset:
  - `reports/presets/usdjpy_20260402_round_continuation_long-quality12b_stack3_guarded.set`

## Test Window

- Train: `2025-04-01` to `2025-12-31`
- OOS: `2026-01-01` to `2026-03-31`
- Tester: actual MT5 `Model=4`, `USDJPY`, `M15`

## Results

### Candidate: `quality12b_stack3_guarded`

- Train:
  - `+468.91 / PF 1.26 / 128 trades / DD 2.48%`
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-184822-795278-usdjpy-20260402-round-continuati.json`
- OOS:
  - `+124.05 / PF 1.82 / 19 trades / DD 0.38%`
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-184848-108172-usdjpy-20260402-round-continuati.json`

### Baseline: `quality12b_stack_guarded`

- Train:
  - `+372.93 / PF 1.21 / 125 trades / DD 2.80%`
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-172525-816098-usdjpy-20260402-round-continuati.json`
- OOS:
  - `+124.05 / PF 1.82 / 19 trades / DD 0.38%`
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-172525-792759-usdjpy-20260402-round-continuati.json`

## Verdict

- Reject `quality12b_stack3_guarded` as a promotion candidate.
- Reason:
  - the independent breakout bucket improved the `9 months train` window slightly,
  - but it added no value in the latest executable `3 months OOS` window,
  - so it does not solve the current blocker, which is live-relevant turnover.

## Decision

- Keep `quality12b_stack_guarded` as the active turnover-biased `USDJPY long-only` demo-forward candidate.
- Do not promote `quality12b_stack3_guarded`.
- Treat `breakout-followthrough` as a valid independent morphology, but not yet a proven live-track add-on inside this family.

## Next

1. If turnover must increase inside this family, test a different third bucket instead of another breakout retune.
2. If long-only turnover still stalls, consider opening the short side as a separate, explicitly independent bucket after the long-side proving work is complete.
