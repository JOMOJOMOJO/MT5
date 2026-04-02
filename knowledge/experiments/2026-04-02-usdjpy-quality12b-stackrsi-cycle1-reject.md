# USDJPY quality12b stackrsi cycle 1 reject

## Objective

- Test whether an `RSI`-driven third long-only bucket can increase turnover inside the current `quality12b_stack_guarded` family.
- Keep the existing `round continuation` and `EMA continuation` buckets unchanged.
- Promote the new bucket only if it adds executable `3 months OOS` trades without degrading the current live-track baseline.

## Change

- Integrated `rsi_sidecar_long` into `usdjpy_20260402_round_continuation_long.mq5`.
- Kept bucket order as:
  - `round_continuation_long`
  - `ema_sidecar_long`
  - `rsi_sidecar_long`
- Candidate preset:
  - `reports/presets/usdjpy_20260402_round_continuation_long-quality12b_stackrsi_guarded.set`

## Test Window

- Train: `2025-04-01` to `2025-12-31`
- OOS: `2026-01-01` to `2026-03-31`
- Tester: actual MT5 `Model=4`, `USDJPY`, `M15`

## Results

### Candidate: `quality12b_stackrsi_guarded`

- Train:
  - `+401.06 / PF 1.22 / 126 trades / DD 2.81%`
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-190147-783946-usdjpy-20260402-round-continuati.json`
- OOS:
  - `+124.05 / PF 1.82 / 19 trades / DD 0.38%`
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-190214-515562-usdjpy-20260402-round-continuati.json`

### Baseline: `quality12b_stack_guarded`

- Train:
  - `+372.93 / PF 1.21 / 125 trades / DD 2.80%`
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-172525-816098-usdjpy-20260402-round-continuati.json`
- OOS:
  - `+124.05 / PF 1.82 / 19 trades / DD 0.38%`
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-172525-792759-usdjpy-20260402-round-continuati.json`

## Verdict

- Reject `quality12b_stackrsi_guarded` as a promotion candidate.
- Reason:
  - the RSI bucket improved the `9 months train` window only marginally,
  - but it added nothing to the executable `3 months OOS` window,
  - so it does not address the current blocker, which is live-relevant turnover.

## Decision

- Keep `quality12b_stack_guarded` as the active turnover-biased `USDJPY long-only` demo-forward candidate.
- Do not promote `quality12b_stackrsi_guarded`.

## Reusable lesson

- A bucket is not promotable just because the train window improves slightly.
- If the latest OOS trade count, net profit, and PF stay flat, the added complexity is not justified.

## Next

1. Do not retune this RSI sidecar further inside the current family.
2. If turnover must increase, test a genuinely different morphology instead of another momentum-flavored sidecar that behaves like the existing buckets.
