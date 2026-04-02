# Release Packet: `usdjpy_20260402_round_continuation_long-quality12b_stack_guarded`

- Date: `2026-04-02`
- Status: `demo-forward candidate`
- Family status: `turnover-biased long-only live-track sidecar`
- Owner: `CEO / repo operator`
- Reusable lessons:
  - `knowledge/patterns/2026-04-01-live-ready-definition.md`
  - `knowledge/patterns/2026-04-01-ea-improvement-cycle.md`

## Candidate

- EA:
  - `mql/Experts/usdjpy_20260402_round_continuation_long.mq5`
- Preset:
  - `reports/presets/usdjpy_20260402_round_continuation_long-quality12b_stack_guarded.set`
- Long-window actual run:
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-172525-816098-usdjpy-20260402-round-continuati.json`

## Long-Window Actual

- Window:
  - `2025-04-01` to `2025-12-31`
- Net profit:
  - `+372.93`
- Profit factor:
  - `1.21`
- Trades:
  - `125`
- Max drawdown:
  - `2.80%`

## Recent OOS Check

- Window:
  - `2026-01-01` to `2026-03-31`
- OOS run:
  - `reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-172525-792759-usdjpy-20260402-round-continuati.json`
- OOS metrics:
  - `net +124.05`
  - `PF 1.82`
  - `19` trades
  - `max DD 0.38%`
- Interpretation:
  - turnover improved materially versus `quality12b_guarded`,
  - but this branch is still below the stated `20 trades/month` business target.

## Strategy Shape

- Symbol / timeframe:
  - `USDJPY / M15`
- Direction:
  - `long-only`
- Buckets:
  - `round quality`: `EMA13 > EMA100`, higher highs / higher lows, 50-pip anti-chop, wick-dominant pullback
  - `EMA continuation sidecar`: `EMA13 > EMA100`, positive slow slope, low-ADX London dip continuation
- Exit idea:
  - bucket-specific fixed stop / R target with a time stop
  - round bucket: `22 pips stop`, `1.5R`, `18 bars hold max`
  - EMA sidecar: `15 pips stop`, `1.2R`, `12 bars hold max`

## Risk Doctrine

- Sizing:
  - `0.30%` of current equity per trade
- Micro-cap override:
  - allowed up to `1.50%` when balance is `<= 150 USD`
- Min-lot guard:
  - skip the trade if broker minimum lot would force more than `2.0%` effective risk
- Daily hard stop:
  - `4.0%` of equity, with protective flatten enabled
- Equity drawdown cap:
  - `12.0%`, with protective flatten enabled
- Daily trade cap:
  - `3`

## Telemetry and Operator Files

- Telemetry baseline:
  - `reports/telemetry/2026-04-02-usdjpy-quality12b-stack-guarded-baseline.json`
- Forward gate baseline:
  - `reports/forward/2026-04-02-usdjpy-quality12b-stack-guarded-forward-gate.json`
- Telemetry file:
  - `FILE_COMMON/mt5_company_usdjpy_20260402_round_continuation_long_quality12b_stack_guarded.csv`
- Operator file:
  - `FILE_COMMON/mt5_company_usdjpy_20260402_round_continuation_long_stack_operator.txt`
- Status file:
  - `FILE_COMMON/mt5_company_usdjpy_20260402_round_continuation_long_stack_status.txt`
- Heartbeat cadence:
  - `60 seconds` in demo/live runtime

## Reproducibility

- Compile:
  - `powershell -ExecutionPolicy Bypass -File scripts/compile.ps1 -MetaEditorPath "C:\Program Files\XMTrading MT5\MetaEditor64.exe" -Source mql\Experts\usdjpy_20260402_round_continuation_long.mq5`
- Re-run long-window actual:
  - `powershell -ExecutionPolicy Bypass -File scripts/backtest.ps1 -TerminalPath "C:\Program Files\XMTrading MT5\terminal64.exe" -ConfigPath reports/backtest/usdjpy_20260402_round_continuation_long-quality12b_stack_guarded-train-9m.ini`
- Re-run recent OOS:
  - `powershell -ExecutionPolicy Bypass -File scripts/backtest.ps1 -TerminalPath "C:\Program Files\XMTrading MT5\terminal64.exe" -ConfigPath reports/backtest/usdjpy_20260402_round_continuation_long-quality12b_stack_guarded-oos-3m.ini`
- Launch a demo-forward run:
  - `powershell -ExecutionPolicy Bypass -File scripts/start-usdjpy-quality12b-stack-demo-forward.ps1`
- Close the demo-forward run:
  - `powershell -ExecutionPolicy Bypass -File scripts/close-usdjpy-quality12b-stack-demo-forward.ps1 -ManifestPath <launch-manifest.json>`
- Run the live preflight:
  - `powershell -ExecutionPolicy Bypass -File scripts/usdjpy-quality12b-stack-live-preflight.ps1`

## Promotion Gate

- Required before any first-capital discussion:
  - compile stays clean,
  - long-window actual and latest OOS artifacts remain positive,
  - at least one real demo-forward review is written,
  - at least one non-self-check forward gate is written,
  - no unexpected rule violations,
  - realized spread / slippage stays close to the tested assumptions.

## Notes

- This is the first `USDJPY long-only` branch in this family that materially lifts turnover while still clearing the repo's drawdown gate.
- It does not replace `quality12b_guarded` as the quality anchor.
- It is the current `turnover-biased` demo-forward sidecar candidate.
