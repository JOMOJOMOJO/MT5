# Release Packet: `usdjpy_20260402_round_continuation_long-quality12b_smalllive150`

- Date: `2026-04-02`
- Status: `small-live staged`
- Family status: `first-capital preset for the quality12b branch`
- Owner: `CEO / repo operator`

## Candidate

- EA:
  - `mql/Experts/usdjpy_20260402_round_continuation_long.mq5`
- Preset:
  - `reports/presets/usdjpy_20260402_round_continuation_long-quality12b_smalllive150.set`
- Staged actual run:
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-163636-454435-usdjpy-20260402-round-continuati.json`

## Staged Long-Window Actual

- Window:
  - `2025-04-01` to `2025-12-31`
- Net profit:
  - `+1894.58`
- Profit factor:
  - `1.48`
- Trades:
  - `59`
- Max drawdown:
  - `6.74%`

## Risk Doctrine

- Sizing:
  - `1.5%` of current equity per trade.
- Micro-cap override:
  - disabled for the staged preset.
- Min-lot guard:
  - skip the trade if broker minimum lot would force more than `2.0%` effective risk.
- Daily hard stop:
  - `6.0%`
- Equity drawdown cap:
  - `12.0%`
- Daily trade cap:
  - `2`

## Promotion Route

- This preset must not be used until the guarded demo-forward packet passes.
- Required before first capital:
  - `quality12b_guarded` demo-forward gate is accepted,
  - `scripts/usdjpy-quality12b-small-live-preflight.ps1` returns `pass` or an explicitly accepted `review`,
  - lot-floor viability is reconfirmed on the target broker and account.

## Operator and Status Files

- Telemetry file:
  - `FILE_COMMON/mt5_company_usdjpy_20260402_round_continuation_long_quality12b_smalllive150.csv`
- Operator file:
  - `FILE_COMMON/mt5_company_usdjpy_20260402_round_continuation_long_smalllive150_operator.txt`
- Status file:
  - `FILE_COMMON/mt5_company_usdjpy_20260402_round_continuation_long_smalllive150_status.txt`

## Reproducibility

- Show the staged instructions:
  - `powershell -ExecutionPolicy Bypass -File scripts/prepare-usdjpy-quality12b-small-live.ps1`
- Run staged preflight:
  - `powershell -ExecutionPolicy Bypass -File scripts/usdjpy-quality12b-small-live-preflight.ps1`
- Start first capital:
  - `powershell -ExecutionPolicy Bypass -File scripts/start-usdjpy-quality12b-small-live.ps1`

## Notes

- This is intentionally smaller than the proving preset.
- The goal is capital survival first, then observation of real execution behavior.
