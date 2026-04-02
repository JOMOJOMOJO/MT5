# USDJPY quality12b stackadx cycle 1 reject

## Objective

- Test a genuinely different third long-only bucket inside `quality12b_stack_guarded`.
- Use a `low ADX compression drift` idea instead of another round-distance widening.
- Promote it only if it improves executable turnover without materially weakening long-window train quality.

## Change

- Integrated `compression_sidecar_long` into `usdjpy_20260402_round_continuation_long.mq5`.
- Core idea:
  - low `ADX`
  - trend still up (`EMA13 > EMA100`, close above `EMA100`)
  - strong upper wick and very small lower wick
  - close still close enough to `EMA13`
- Candidate preset:
  - `reports/presets/usdjpy_20260402_round_continuation_long-quality12b_stackadx_guarded.set`

## Test Window

- Train: `2025-04-01` to `2025-12-31`
- OOS: `2026-01-01` to `2026-03-31`
- Tester: actual MT5 `Model=4`, `USDJPY`, `M15`

## Results

### Candidate: `quality12b_stackadx_guarded`

- Train:
  - `+300.03 / PF 1.15 / 140 trades / DD 3.54%`
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-191021-571592-usdjpy-20260402-round-continuati.json`
- OOS:
  - `+159.98 / PF 2.06 / 20 trades / DD 0.38%`
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-191046-616006-usdjpy-20260402-round-continuati.json`

### Baseline: `quality12b_stack_guarded`

- Train:
  - `+372.93 / PF 1.21 / 125 trades / DD 2.80%`
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-172525-816098-usdjpy-20260402-round-continuati.json`
- OOS:
  - `+124.05 / PF 1.82 / 19 trades / DD 0.38%`
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-172525-792759-usdjpy-20260402-round-continuati.json`

## Verdict

- Reject `quality12b_stackadx_guarded` as a promotion candidate.
- Reason:
  - it adds only one extra OOS trade (`19 -> 20`) and improves OOS net/PF,
  - but it dilutes the long-window train profile too much (`PF 1.21 -> 1.15`, `DD 2.80% -> 3.54%`),
  - so it is not strong enough to replace the current proving preset.

## Decision

- Keep `quality12b_stack_guarded` as the active turnover-biased `USDJPY long-only` demo-forward candidate.
- Do not promote `quality12b_stackadx_guarded`.

## Reusable lesson

- A new bucket must improve the latest OOS window by more than a token amount if it also weakens train quality.
- For this family, train dilution is not acceptable unless the OOS trade count and realized edge move clearly.

## Next

1. Do not spend another immediate cycle on this compression sidecar.
2. If more turnover is required, open a more independent third bucket or add a separately validated short-side family after the long proving track is stable.
